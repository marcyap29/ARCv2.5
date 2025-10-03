#!/bin/bash
# Setup script: Copy MLX models to Application Support directory
# This allows the Flutter app to access models without bundling them (2.6GB is too large)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
MODELS_SOURCE="$PROJECT_ROOT/assets/models/MLX"
MODELS_DEST="$HOME/Library/Application Support/Models"

echo "🚀 Setting up MLX models for local development..."
echo ""
echo "Source: $MODELS_SOURCE"
echo "Destination: $MODELS_DEST"
echo ""

# Create destination directory
mkdir -p "$MODELS_DEST"

# Copy Qwen3-1.7B-MLX-4bit model
if [ -d "$MODELS_SOURCE/Qwen3-1.7B-MLX-4bit" ]; then
    echo "📦 Copying Qwen3-1.7B-MLX-4bit (this may take a minute)..."

    if [ -d "$MODELS_DEST/Qwen3-1.7B-MLX-4bit" ]; then
        echo "   ⚠️  Model already exists, skipping..."
    else
        cp -R "$MODELS_SOURCE/Qwen3-1.7B-MLX-4bit" "$MODELS_DEST/"
        echo "   ✅ Copied successfully"
    fi
else
    echo "   ❌ Source model not found: $MODELS_SOURCE/Qwen3-1.7B-MLX-4bit"
    exit 1
fi

echo ""
echo "✅ Model setup complete!"
echo ""
echo "Models installed at: $MODELS_DEST"
echo "Total size: $(du -sh "$MODELS_DEST" | cut -f1)"
echo ""
echo "You can now run the app with:"
echo "  flutter run -d macos --dart-define=GEMINI_API_KEY=your_key"
