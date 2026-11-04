# swift-institute.org

Use this repository only to change what swift-institute.org serves. The site is closed: every path on the domain redirects to the [Swift Institute](https://github.com/swift-institute) GitHub organization. For the Institute itself, start from that page.

## Laws

- Each push to `main` deploys the redirect pages to GitHub Pages, which keeps the domain's HTTPS certificate valid. Removing the deployment lets the certificate lapse.
- Nothing in `Swift Institute.docc/` is published. It is the former site's catalog, and `build-docs.sh` only builds it locally.
