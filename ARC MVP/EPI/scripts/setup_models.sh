#!/bin/bash

# EPI MLX Model Setup Script
# Copies models from assets to Application Support directory for MLX loading

set -e

echo "🚀 EPI MLX Model Setup"
echo "======================"

# Check if we're in the right directory
if [ ! -f "pubspec.yaml" ]; then
    echo "❌ Error: Run this script from the EPI project root directory"
    exit 1
fi

# Define paths
ASSETS_DIR="assets/models/MLX"
APP_SUPPORT_DIR="$HOME/Library/Application Support/Models"
MODEL_NAME="Qwen3-1.7B-MLX-4bit"

echo "📁 Source: $ASSETS_DIR/$MODEL_NAME"
echo "📁 Target: $APP_SUPPORT_DIR/$MODEL_NAME"

# Check if source exists
if [ ! -d "$ASSETS_DIR/$MODEL_NAME" ]; then
    echo "❌ Error: Model directory not found at $ASSETS_DIR/$MODEL_NAME"
    echo ""
    echo "💡 Solutions:"
    echo "1. Extract the ZIP file: unzip $ASSETS_DIR/$MODEL_NAME.zip -d $ASSETS_DIR/"
    echo "2. Or download a compatible MLX model from:"
    echo "   - https://huggingface.co/ml-explore/Qwen2.5-1.5B-Instruct-4bit-MLX"
    echo "   - https://huggingface.co/ml-explore/Qwen2.5-3B-Instruct-4bit-MLX"
    exit 1
fi

# Create Application Support directory
echo "📂 Creating Application Support directory..."
mkdir -p "$APP_SUPPORT_DIR"

# Copy model files
echo "📋 Copying model files..."
if [ -d "$APP_SUPPORT_DIR/$MODEL_NAME" ]; then
    echo "⚠️  Model already exists, removing old version..."
    rm -rf "$APP_SUPPORT_DIR/$MODEL_NAME"
fi

cp -R "$ASSETS_DIR/$MODEL_NAME" "$APP_SUPPORT_DIR/"

# Set proper permissions
echo "🔒 Setting permissions..."
chmod -R 755 "$APP_SUPPORT_DIR/$MODEL_NAME"

# Verify installation
echo "✅ Verifying installation..."
if [ -f "$APP_SUPPORT_DIR/$MODEL_NAME/config.json" ] && [ -f "$APP_SUPPORT_DIR/$MODEL_NAME/model.safetensors" ]; then
    echo "🎉 Model setup complete!"
    echo "📊 Model size: $(du -sh "$APP_SUPPORT_DIR/$MODEL_NAME" | cut -f1)"
    echo ""
    echo "🚀 You can now run the app:"
    echo "   flutter run -d macos"
else
    echo "❌ Error: Model files not found after installation"
    exit 1
fi