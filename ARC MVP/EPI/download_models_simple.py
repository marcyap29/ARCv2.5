#!/usr/bin/env python3
"""
Simple Gemma Model Download Guide

This script provides instructions for manually downloading Gemma models.
"""

import os
from pathlib import Path

def main():
    print("🚀 LUMARA Gemma Model Download Guide")
    print("=" * 50)
    
    # Create models directory
    models_dir = Path("assets/models")
    models_dir.mkdir(parents=True, exist_ok=True)
    
    print(f"📁 Models directory: {models_dir.absolute()}")
    print()
    
    print("📥 MANUAL DOWNLOAD INSTRUCTIONS:")
    print()
    
    print("1. GEMMA 3 1B-INSTRUCT (Recommended)")
    print("   • Size: ~700MB")
    print("   • URL: https://huggingface.co/google/gemma-2-9b-it")
    print("   • File: Download 'model.safetensors'")
    print("   • Rename to: gemma3_1b_instruct.safetensors")
    print("   • Place in: assets/models/")
    print()
    
    print("2. GEMMA 3 4B-INSTRUCT (Best Performance)")
    print("   • Size: ~2.5GB")
    print("   • URL: https://huggingface.co/google/gemma-2-9b-it")
    print("   • File: Download 'model.safetensors'")
    print("   • Rename to: gemma3_4b_instruct.safetensors")
    print("   • Place in: assets/models/")
    print()
    
    print("3. EMBEDDINGGEMMA (Text Embeddings)")
    print("   • Size: ~100MB")
    print("   • URL: https://huggingface.co/google/embedding-gecko-003")
    print("   • File: Download 'model.tflite'")
    print("   • Rename to: embeddinggemma_mrl_512.tflite")
    print("   • Place in: assets/models/")
    print()
    
    print("🔧 AFTER DOWNLOADING:")
    print("1. Run: flutter pub get")
    print("2. Uncomment MediaPipe dependencies in build files")
    print("3. Run: flutter clean && flutter run")
    print()
    
    print("📱 TESTING:")
    print("1. Open LUMARA in the app")
    print("2. Ask: 'Summarize my last 7 days'")
    print("3. Check logs for 'GemmaAdapter: Using XB model'")
    print()
    
    print("💡 TIPS:")
    print("• Start with 1B model for testing")
    print("• Use 4B model if you have 8GB+ RAM")
    print("• Check MODEL_DOWNLOAD_GUIDE.md for detailed steps")
    print()
    
    # Check if any models already exist
    existing_models = []
    for file in models_dir.glob("*.safetensors"):
        existing_models.append(file.name)
    for file in models_dir.glob("*.tflite"):
        existing_models.append(file.name)
    
    if existing_models:
        print("✅ FOUND EXISTING MODELS:")
        for model in existing_models:
            print(f"   • {model}")
        print()
    else:
        print("❌ NO MODELS FOUND")
        print("   Download models using the instructions above")
        print()

if __name__ == "__main__":
    main()
