#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build
xcrun swiftc Sources/Model.swift Tests/ModelTests.swift -o build/model-tests
build/model-tests
plutil -lint Info.plist
xcrun swiftc -swift-version 5 -D TESTING Sources/*.swift Tests/AppTests.swift -o build/app-tests -framework AppKit -framework SwiftUI -framework ScreenCaptureKit
build/app-tests
