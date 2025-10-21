#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Llama.cpp XCFramework Builder for iOS
# =============================================================================
# Builds llama.cpp as a universal XCFramework for iOS device and simulator
# with Metal acceleration and modern C API support.
#
# Requirements:
# - Xcode 15.0+
# - iOS 15.0+ deployment target
# - Apple Silicon Mac (for arm64 simulator build)
#
# Usage: bash ios/scripts/build_llama_xcframework_final.sh
# =============================================================================

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Logging functions
log_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }
log_step() { echo -e "${PURPLE}🔧 $1${NC}"; }
log_build() { echo -e "${CYAN}📦 $1${NC}"; }

# Configuration
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
LLAMA_DIR="$ROOT/third_party/llama.cpp"
OUT_DIR="$ROOT/ios/Runner/Vendor"
BUILD_DIR="$ROOT/build/llama"

# Validate environment
validate_environment() {
    log_info "Validating build environment..."
    
    # Check if llama.cpp exists
    if [[ ! -d "$LLAMA_DIR" ]]; then
        log_error "llama.cpp directory not found at: $LLAMA_DIR"
        log_info "Please ensure llama.cpp is cloned in third_party/"
        exit 1
    fi
    
    # Check if we're in the right directory
    if [[ ! -f "$ROOT/pubspec.yaml" ]]; then
        log_error "Not in Flutter project root. Expected pubspec.yaml at: $ROOT"
        exit 1
    fi
    
    # Check Xcode version
    if ! command -v xcodebuild &> /dev/null; then
        log_error "xcodebuild not found. Please install Xcode."
        exit 1
    fi
    
    local xcode_version=$(xcodebuild -version | head -n1 | cut -d' ' -f2)
    log_info "Using Xcode version: $xcode_version"
    
    log_success "Environment validation passed"
}

# Clean previous builds
clean_build() {
    log_info "Cleaning previous builds..."
    rm -rf "$BUILD_DIR" "$OUT_DIR/llama.xcframework"
    mkdir -p "$BUILD_DIR" "$OUT_DIR"
    log_success "Clean completed"
}

# Build for iOS device (arm64)
build_ios_device() {
    log_step "Building llama.cpp for iOS Device (arm64)..."
    
    local build_dir="$BUILD_DIR/ios-device"
    mkdir -p "$build_dir"
    
    cmake -S "$LLAMA_DIR" -B "$build_dir" \
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
        -DBUILD_SHARED_LIBS=OFF \
        -DGGML_BLAS_DEFAULT=OFF
    
    cmake --build "$build_dir" --config Release --parallel
    
    # Verify build output
    local lib_path="$build_dir/src/libllama.a"
    if [[ ! -f "$lib_path" ]]; then
        log_error "iOS device build failed - libllama.a not found at: $lib_path"
        exit 1
    fi
    
    local lib_size=$(du -h "$lib_path" | cut -f1)
    log_success "iOS device build completed (${lib_size})"
}

# Build for iOS simulator (arm64)
build_ios_simulator() {
    log_step "Building llama.cpp for iOS Simulator (arm64)..."
    
    local build_dir="$BUILD_DIR/ios-sim"
    mkdir -p "$build_dir"
    
    cmake -S "$LLAMA_DIR" -B "$build_dir" \
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
        -DBUILD_SHARED_LIBS=OFF \
        -DGGML_BLAS_DEFAULT=OFF
    
    cmake --build "$build_dir" --config Release --parallel
    
    # Verify build output
    local lib_path="$build_dir/src/libllama.a"
    if [[ ! -f "$lib_path" ]]; then
        log_error "iOS simulator build failed - libllama.a not found at: $lib_path"
        exit 1
    fi
    
    local lib_size=$(du -h "$lib_path" | cut -f1)
    log_success "iOS simulator build completed (${lib_size})"
}

# Create XCFramework (device only for now)
create_xcframework() {
    log_build "Creating XCFramework (device only)..."

    local ios_llama_lib="$BUILD_DIR/ios-device/src/libllama.a"
    local ios_ggml_base_lib="$BUILD_DIR/ios-device/ggml/src/libggml-base.a"
    local ios_ggml_cpu_lib="$BUILD_DIR/ios-device/ggml/src/libggml-cpu.a"
    local ios_ggml_metal_lib="$BUILD_DIR/ios-device/ggml/src/ggml-metal/libggml-metal.a"
    local ios_ggml_blas_lib="$BUILD_DIR/ios-device/ggml/src/ggml-blas/libggml-blas.a"
    local ios_ggml_lib="$BUILD_DIR/ios-device/ggml/src/libggml.a"
    local combined_lib="$BUILD_DIR/ios-device/libllama_combined.a"

    # Verify libraries exist
    [[ -f "$ios_llama_lib" ]] || { log_error "Missing iOS device libllama.a"; exit 1; }
    [[ -f "$ios_ggml_base_lib" ]] || { log_error "Missing iOS device libggml-base.a"; exit 1; }
    [[ -f "$ios_ggml_cpu_lib" ]] || { log_error "Missing iOS device libggml-cpu.a"; exit 1; }
    [[ -f "$ios_ggml_metal_lib" ]] || { log_error "Missing iOS device libggml-metal.a"; exit 1; }
    [[ -f "$ios_ggml_blas_lib" ]] || { log_error "Missing iOS device libggml-blas.a"; exit 1; }
    [[ -f "$ios_ggml_lib" ]] || { log_error "Missing iOS device libggml.a"; exit 1; }

    # Combine all llama.cpp and GGML libraries into a single library using libtool
    log_info "Combining all libraries using libtool (preserves all object files)..."

    # Use libtool to combine libraries - this properly handles duplicate filenames
    libtool -static -o "$combined_lib" \
        "$ios_llama_lib" \
        "$ios_ggml_base_lib" \
        "$ios_ggml_cpu_lib" \
        "$ios_ggml_metal_lib" \
        "$ios_ggml_blas_lib" \
        "$ios_ggml_lib"

    # Verify combined library was created
    [[ -f "$combined_lib" ]] || { log_error "Failed to create combined library"; exit 1; }

    local combined_size=$(du -h "$combined_lib" | cut -f1)
    log_success "Combined library created (${combined_size})"

    # Create XCFramework with combined library
    # First, create a combined headers directory
    local combined_headers="$BUILD_DIR/combined_headers"
    mkdir -p "$combined_headers"

    # Copy llama headers
    cp -r "$LLAMA_DIR/include"/* "$combined_headers/"

    # Copy GGML headers
    cp -r "$LLAMA_DIR/ggml/include"/* "$combined_headers/"

    xcodebuild -create-xcframework \
        -library "$combined_lib" -headers "$combined_headers" \
        -output "$OUT_DIR/llama.xcframework"

    # Verify XCFramework structure
    if [[ ! -d "$OUT_DIR/llama.xcframework" ]]; then
        log_error "XCFramework creation failed"
        exit 1
    fi

    log_success "XCFramework created successfully (device only)"
}

# Verify XCFramework structure
verify_xcframework() {
    log_info "Verifying XCFramework structure..."
    
    local xcframework_path="$OUT_DIR/llama.xcframework"
    
    # Check directory structure (device only for now)
    if [[ ! -d "$xcframework_path/ios-arm64" ]]; then
        log_error "Missing ios-arm64 slice in XCFramework"
        exit 1
    fi
    
    if [[ ! -f "$xcframework_path/Info.plist" ]]; then
        log_error "Missing Info.plist in XCFramework"
        exit 1
    fi
    
    # Check library files (device only for now) - looking for any .a file
    local lib_file=$(find "$xcframework_path/ios-arm64" -name "*.a" | head -1)
    if [[ -z "$lib_file" ]]; then
        log_error "Missing static library in ios-arm64 slice"
        exit 1
    fi
    
    # Display structure
    log_info "XCFramework structure:"
    tree "$xcframework_path" || find "$xcframework_path" -type f | sort
    
    # Get file sizes (device only for now)
    local device_size=$(du -h "$lib_file" | cut -f1)
    
    log_success "XCFramework verification passed"
    log_info "Device library size: $device_size"
}

# Display next steps
show_next_steps() {
    log_info "Next steps to complete the integration:"
    echo ""
    echo "1. 📱 Add XCFramework to Xcode:"
    echo "   • Open ios/Runner.xcworkspace in Xcode"
    echo "   • Drag ios/Runner/Vendor/llama.xcframework into the project"
    echo "   • Set to 'Embed & Sign'"
    echo ""
    echo "2. 🧹 Clean and rebuild:"
    echo "   • Product → Clean Build Folder"
    echo "   • Build and run on simulator"
    echo ""
    echo "3. 🔍 Verify Metal acceleration:"
    echo "   • Look for 'ggml_metal_init' in console logs"
    echo "   • Test with debug smoke test"
    echo ""
    echo "4. 🧪 Test token streaming:"
    echo "   • Run 'Hello, my name is' prompt"
    echo "   • Verify tokens appear in real-time"
    echo ""
    log_success "XCFramework build completed successfully!"
    log_info "Location: $OUT_DIR/llama.xcframework"
}

# Main execution
main() {
    echo "🚀 Starting llama.cpp XCFramework build..."
    echo "================================================"
    
    validate_environment
    clean_build
    build_ios_device
    # build_ios_simulator  # Skip for now due to identifier conflict
    create_xcframework
    verify_xcframework
    show_next_steps
    
    echo "================================================"
    log_success "Build process completed successfully!"
}

# Run main function
main "$@"
