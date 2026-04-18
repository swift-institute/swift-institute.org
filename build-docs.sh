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
cp -R dashboard /tmp/si-docs/dashboard

# Fetch live manifests from sibling repos. We do not commit snapshots in
# this repo. Locally the sibling repos sit next to swift-institute.org/;
# if they are present, copy from there; otherwise fetch from origin.
if [ -f ../Research/_index.json ]; then
    cp ../Research/_index.json /tmp/si-docs/dashboard/research.json
else
    curl -fsSL https://raw.githubusercontent.com/swift-institute/Research/main/_index.json \
        -o /tmp/si-docs/dashboard/research.json
fi
if [ -f ../Experiments/_index.json ]; then
    cp ../Experiments/_index.json /tmp/si-docs/dashboard/experiments.json
else
    curl -fsSL https://raw.githubusercontent.com/swift-institute/Experiments/main/_index.json \
        -o /tmp/si-docs/dashboard/experiments.json
fi

echo "Built to /tmp/si-docs"
