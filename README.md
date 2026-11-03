# swift-institute.org

[swift-institute.org](https://swift-institute.org) is closed: every path on the domain redirects to the [Swift Institute](https://github.com/swift-institute) GitHub organization.

## What's here

| Path | Contents |
|------|----------|
| [`.github/workflows/deploy-docs.yml`](.github/workflows/deploy-docs.yml) | GitHub Actions workflow that deploys the redirect pages to GitHub Pages on every push to `main`, keeping the domain's HTTPS certificate valid |
| [`Swift Institute.docc/`](Swift%20Institute.docc) | The DocC catalog the former site was built from — articles, blog, theme |
| [`Sources/`](Sources) | Stub Swift target used to generate the DocC symbol graph |
| [`Package.swift`](Package.swift) | Package manifest declaring the `Swift Institute` target |
| [`build-docs.sh`](build-docs.sh) | Local build script for the former site — produces a static site under `/tmp/si-docs` |

Org-level community files (CONTRIBUTING, CODE_OF_CONDUCT, SECURITY, issue templates, profile) live in [swift-institute/.github](https://github.com/swift-institute/.github).

## Building locally

```sh
./build-docs.sh
```

Requires Swift 6.3+ and Xcode 26+ (for `xcrun docc`).

For a live preview server:

```sh
swift build --target "Swift Institute" \
    -Xswiftc -emit-symbol-graph \
    -Xswiftc -emit-symbol-graph-dir \
    -Xswiftc "$(pwd)/.build/symbol-graphs"

xcrun docc preview "Swift Institute.docc" \
    --additional-symbol-graph-dir .build/symbol-graphs
```

## Deferred articles

Articles temporarily removed from the live catalog live on `deferred/{name}` branches: `deferred/architecture`, `deferred/embedded-swift`, `deferred/getting-started`, `deferred/platform`, `deferred/principles`. Cherry-pick into `main` when ready to reintroduce.

## License

[Apache 2.0](LICENSE.md).
