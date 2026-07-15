#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

echo "🔨 Building WAYD native macOS Menu Bar App..."

# Check if Xcode Command Line Tools are installed (check if swiftc exists)
if ! command -v swiftc &> /dev/null; then
    echo "❌ Error: 'swiftc' compiler not found."
    echo "Please install Xcode Command Line Tools first by running:"
    echo "  xcode-select --install"
    echo "Then try running this script again."
    exit 1
fi

# Define directories
APP_NAME="WAYD"
APP_DIR="${APP_NAME}.app"
CONTENTS_DIR="${APP_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"

echo "📂 Creating App Bundle structure..."
mkdir -p "${MACOS_DIR}"
mkdir -p "${RESOURCES_DIR}"

# Copy Info.plist and Resources
echo "📄 Copying Info.plist and Resources..."
cp Resources/Info.plist "${CONTENTS_DIR}/Info.plist"
if [ -f "Resources/AppIcon.icns" ]; then
    cp Resources/AppIcon.icns "${RESOURCES_DIR}/AppIcon.icns"
fi

# List of source files
SOURCES=(
    "Sources/main.swift"
    "Sources/AppDelegate.swift"
    "Sources/LogManager.swift"
    "Sources/Views/PromptView.swift"
    "Sources/Views/HistoryView.swift"
    "Sources/Views/AboutView.swift"
)

# Find macOS SDK path
SDK_PATH=$(xcrun --show-sdk-path --sdk macosx)

echo "c Compiling Swift code..."
swiftc -sdk "${SDK_PATH}" -O -o "${MACOS_DIR}/${APP_NAME}" "${SOURCES[@]}"

echo "✅ App built successfully!"
echo "🚀 Run the app by running: open ${APP_DIR}"
