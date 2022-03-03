# Supercenter App

This is an iOS application that displays a list of products. But it's buggy and doesn't work right now. Your job is to fix it.

## Mock Server

There is an accompanying mock server in the folder "mock-server". See the [ReadMe](mock-server/ReadMe.md) for instructions on setting up and running it.

## Ways to break it

1. Remove `DispatchQueue.main.async {}` wrapping from `SupercenterAPIClient`. This wreaks major havok as the app tries to update the UI from a background thread.
2. Remove `image = nil` for `ready`/`loading`/`failed` cases in `RemoteImageView.applyImageState`. This leaves the old images visible when cells are recycled.
3. Make `RawProduct.inStock` a required field. It's missing from the 7th product, which will cause the second get-products request to fail.
4. Remove `sourceURL` from `RawProduct` => `Product` conversion. The image URLs are relative, so they will not load.
5. Change `(loadedPageCount * pageSize)` to `products.count` in `ProductListData.canLoadMore`. This causes the spinner to remain at the end of the list even when all products are loaded.

## Ways to enhance it

1. Add pull to refresh.
2. Add a try-again button to the "error" cell.
3. Add a detail view for the products.
