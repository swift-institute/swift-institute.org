#!/bin/bash
set -euo pipefail

# Build symbol graph
swift build --target "Swift Institute" \
    -Xswiftc -emit-symbol-graph \
    -Xswiftc -emit-symbol-graph-dir \
    -Xswiftc "$(pwd)/.build/symbol-graphs"

# Convert to static site
xcrun docc convert "Swift Institute.docc" \
    --additional-symbol-graph-dir .build/symbol-graphs \
    --transform-for-static-hosting \
    --output-path /tmp/si-docs

# Post-process: nav title
sed -i '' 's/VUE_APP_TITLE:"Documentation"/VUE_APP_TITLE:"Swift Institute"/g' /tmp/si-docs/js/index.*.js
sed -i '' 's/"documentation":{"title":"Documentation"/"documentation":{"title":"Swift Institute"/g' /tmp/si-docs/js/index.*.js

# Post-process: OG meta into DocC shell
sed -i '' 's|<title>Documentation</title>|<title>Swift Institute</title><meta property="og:title" content="Swift Institute"/><meta property="og:description" content="The integrated Swift package ecosystem. Primitives, standards, and foundations."/><meta property="og:type" content="website"/><meta property="og:url" content="https://swift-institute.org/documentation/swift_institute/"/><meta name="twitter:card" content="summary"/><meta name="twitter:title" content="Swift Institute"/><meta name="twitter:description" content="The integrated Swift package ecosystem. Primitives, standards, and foundations."/><meta name="description" content="The integrated Swift package ecosystem. Primitives, standards, and foundations."/>|g' /tmp/si-docs/documentation/swift_institute/index.html

# Copy dashboard/ into the built site, matching the deploy workflow.
# The dashboard fetches Research and Experiments manifests directly from
# raw.githubusercontent.com at page-load time; nothing to copy here.
cp -R dashboard /tmp/si-docs/dashboard

echo "Built to /tmp/si-docs"
