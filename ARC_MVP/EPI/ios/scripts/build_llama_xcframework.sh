#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
LLAMA_DIR="$ROOT/third_party/llama.cpp"
OUT_DIR="$ROOT/ios/Runner/Vendor"
BUILD_DIR="$ROOT/build/llama"

rm -rf "$BUILD_DIR" "$OUT_DIR/llama.xcframework"
mkdir -p "$BUILD_DIR" "$OUT_DIR"

echo "🔧 Building llama.cpp for iOS Device (arm64)..."
cmake -S "$LLAMA_DIR" -B "$BUILD_DIR/ios-device" \
  -DCMAKE_SYSTEM_NAME=iOS \
  -DCMAKE_OSX_ARCHITECTURES=arm64 \
  -DCMAKE_OSX_DEPLOYMENT_TARGET=15.0 \
  -DGGML_METAL=ON \
  -DGGML_ACCELERATE=ON \
  -DCMAKE_BUILD_TYPE=Release \
  -DLLAMA_BUILD_EXAMPLES=OFF \
  -DLLAMA_BUILD_TESTS=OFF \
  -DLLAMA_BUILD_SERVER=OFF \
  -DLLAMA_CURL=OFF \
  -DBUILD_SHARED_LIBS=OFF
cmake --build "$BUILD_DIR/ios-device" --config Release

echo "🔧 Building llama.cpp for iOS Simulator (arm64)..."
cmake -S "$LLAMA_DIR" -B "$BUILD_DIR/ios-sim" \
  -DCMAKE_SYSTEM_NAME=iOS \
  -DCMAKE_OSX_ARCHITECTURES=arm64 \
  -DCMAKE_OSX_DEPLOYMENT_TARGET=15.0 \
  -DGGML_METAL=ON \
  -DGGML_ACCELERATE=ON \
  -DCMAKE_BUILD_TYPE=Release \
  -DLLAMA_BUILD_EXAMPLES=OFF \
  -DLLAMA_BUILD_TESTS=OFF \
  -DLLAMA_BUILD_SERVER=OFF \
  -DLLAMA_CURL=OFF \
  -DBUILD_SHARED_LIBS=OFF
cmake --build "$BUILD_DIR/ios-sim" --config Release

IOS_LIB="$BUILD_DIR/ios-device/src/libllama.a"
SIM_LIB="$BUILD_DIR/ios-sim/src/libllama.a"

[[ -f "$IOS_LIB" ]] || { echo "❌ Missing iOS device libllama.a"; exit 1; }
[[ -f "$SIM_LIB" ]] || { echo "❌ Missing iOS simulator libllama.a"; exit 1; }

echo "📦 Creating XCFramework..."
xcodebuild -create-xcframework \
  -library "$IOS_LIB" -headers "$LLAMA_DIR/include" \
  -library "$SIM_LIB" -headers "$LLAMA_DIR/include" \
  -output "$OUT_DIR/llama.xcframework"

echo "✅ XCFramework created at: $OUT_DIR/llama.xcframework"