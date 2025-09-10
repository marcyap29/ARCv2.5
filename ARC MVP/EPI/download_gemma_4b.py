#!/usr/bin/env python3
"""
Download Gemma 3 4B Instruct Model Files

This script provides direct download links for the split model files.
"""

import os
from pathlib import Path

def main():
    print("🚀 Gemma 3 4B Instruct Download Guide")
    print("=" * 50)
    
    # Create models directory
    models_dir = Path("assets/models")
    models_dir.mkdir(parents=True, exist_ok=True)
    
    print(f"📁 Models directory: {models_dir.absolute()}")
    print()
    
    print("📥 DOWNLOAD THESE FILES:")
    print()
    
    print("1. MAIN MODEL FILES (Required):")
    print("   • model-00001-of-00002.safetensors (4.96 GB)")
    print("   • model-00002-of-00002.safetensors (3.64 GB)")
    print("   • Download from: https://huggingface.co/google/gemma-3-4b-it")
    print()
    
    print("2. CONFIGURATION FILES (Required):")
    print("   • config.json (855 Bytes)")
    print("   • tokenizer.json (33.4 MB)")
    print("   • tokenizer_config.json (1.16 MB)")
    print("   • generation_config.json (215 Bytes)")
    print()
    
    print("3. OPTIONAL FILES (Recommended):")
    print("   • chat_template.json (1.62 kB)")
    print("   • special_tokens_map.json (662 Bytes)")
    print()
    
    print("🔧 DOWNLOAD STEPS:")
    print("1. Go to: https://huggingface.co/google/gemma-3-4b-it")
    print("2. Click the download button for each file")
    print("3. Place all files in: assets/models/")
    print("4. Run: flutter pub get")
    print("5. Uncomment MediaPipe dependencies")
    print("6. Run: flutter clean && flutter run")
    print()
    
    print("💡 TIPS:")
    print("• The model is split because it's too large for a single file")
    print("• MediaPipe will automatically handle the split files")
    print("• You need BOTH model files for it to work")
    print("• Total download size: ~8.6 GB")
    print()
    
    print("🎯 ALTERNATIVE: Try 1B Model First")
    print("If 4B is too large, try the 1B model:")
    print("• Go to: https://huggingface.co/google/gemma-2-9b-it")
    print("• Look for a single model.safetensors file")
    print("• Rename to: gemma3_1b_instruct.safetensors")
    print("• Place in: assets/models/")
    print()
    
    # Check if any files already exist
    existing_files = []
    for file in models_dir.glob("*.safetensors"):
        existing_files.append(file.name)
    for file in models_dir.glob("*.json"):
        existing_files.append(file.name)
    
    if existing_files:
        print("✅ FOUND EXISTING FILES:")
        for file in existing_files:
            print(f"   • {file}")
        print()
    else:
        print("❌ NO FILES FOUND")
        print("   Download the files using the instructions above")
        print()

if __name__ == "__main__":
    main()
