//
//  SupercenterAPIClient.swift
//  Supercenter
//
//  Created by Alex Johnson on 7/10/19.
//  Copyright © 2019 Supercenter. All rights reserved.
//

import Foundation

class SupercenterAPIClient {
    
    let queue = DispatchQueue(label: "background",qos: .background)
    
    
    static let shared: SupercenterAPIClient = {
        // Use a separate session for API calls so we image loads don't block API calls.
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForResource = 5
        let session = URLSession(configuration: configuration)

        return SupercenterAPIClient(baseURL: Environment.current.supercenterAPIBaseURL, session: session)
    }()

    private let baseURL: URL
    private let session: URLSession

    init(baseURL: URL, session: URLSession) {
        self.baseURL = baseURL
        self.session = session
    }
}

extension SupercenterAPIClient: ProductCatalogService {
    enum ResponseError: Error {
        case badResponseStatusCode(Int)
        case noProducts
        case unableToConnect(Error)
        case unknown
    }

    @discardableResult
    func getProducts(_ request: ProductsRequest, completion: @escaping (Result<ProductsResponse, Error>) -> Void) -> Cancellable {
        let url = URL(string: "products/\(request.page)/\(request.pageSize)", relativeTo: baseURL)!

        let task = session.dataTask(with: url) { data, urlResponse, error in
            let result: Result<ProductsResponse, Error>

            do {
                if let error = error as NSError?, error.domain == NSURLErrorDomain, error.code == NSURLErrorCannotConnectToHost {
                    // Special case for mock server not running
                    throw ResponseError.unableToConnect(error)
                }

                guard let urlResponse = urlResponse as? HTTPURLResponse else {
                    throw error ?? ResponseError.unknown
                }

                guard (200 ..< 300).contains(urlResponse.statusCode) else {
                    throw ResponseError.badResponseStatusCode(urlResponse.statusCode)
                }

                let response = try JSONDecoder().decode(RawProductsResponse.self, from: data ?? Data())

                guard response.totalProducts > 0 else {
                    throw ResponseError.noProducts
                }

                result = .success(ProductsResponse(response, sourceURL: url))
            } catch {
                result = .failure(error)
            }

            DispatchQueue.main.async {
                completion(result)
            }
        }

        task.resume()

        return task
    }
}

// MARK: - Network Models

private struct RawProductsResponse: Decodable {
    let products: [RawProduct?]
    let totalProducts: Int
}

private struct RawProduct: Decodable {
    let productId: String?
    let productName: String?
    let shortDescription: String?
    let price: Double?
    let productImage: String?
    let reviewRating: Double?
    let reviewCount: Int?
    let inStock: Bool?
}

// MARK: - Network Model => App Model Conversion

private extension ProductCatalogService.ProductsResponse {
    init(_ response: RawProductsResponse, sourceURL: URL) {
        self.init(
            totalCount: response.totalProducts,
            products: response.products.compactMap({ $0 }).compactMap({ Product($0, sourceURL: sourceURL) })
        )
    }
}

private extension Product {
    convenience init?(_ product: RawProduct, sourceURL: URL) {
        guard
            let id = product.productId,
            let name = product.productName,
            let price = product.price.flatMap({ Decimal($0, precision: 2) })
        else {
            return nil
        }

        self.init(
            id: id,
            name: name,
            price: price,
            detailedDescription: product.shortDescription ?? "",
            imageURL: product.productImage.flatMap({ URL(string: $0, relativeTo: sourceURL) }),
            averageRating: product.reviewRating.map({ Rating(rawValue: $0) }),
            reviewCount: product.reviewCount ?? 0,
            isInStock: product.inStock ?? false
        )
    }
}
