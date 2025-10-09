#!/usr/bin/env python3
"""
Gemma Model Download Script for LUMARA

This script downloads the required Gemma model files for on-device AI inference.
Run this script to download the models to the assets/models/ directory.
"""

import os
import sys
import requests
import hashlib
from pathlib import Path
from urllib.parse import urlparse
from tqdm import tqdm

# Model configurations
MODELS = {
    "gemma3_1b_instruct": {
        "url": "https://huggingface.co/google/gemma-2-9b-it/resolve/main/model.safetensors",
        "filename": "gemma3_1b_instruct.safetensors",
        "size": "~700MB",
        "description": "Gemma 3 1B-Instruct - Balanced performance"
    },
    "gemma3_4b_instruct": {
        "url": "https://huggingface.co/google/gemma-2-9b-it/resolve/main/model.safetensors",
        "filename": "gemma3_4b_instruct.safetensors", 
        "size": "~2.5GB",
        "description": "Gemma 3 4B-Instruct - Best performance"
    },
    "embeddinggemma_mrl_512": {
        "url": "https://huggingface.co/google/embedding-gecko-003/resolve/main/model.tflite",
        "filename": "embeddinggemma_mrl_512.tflite",
        "size": "~100MB",
        "description": "EmbeddingGemma - Text embeddings"
    }
}

def download_file(url: str, filepath: Path, expected_size: int = None):
    """Download a file with progress bar and error handling."""
    print(f"Downloading {filepath.name}...")
    
    try:
        response = requests.get(url, stream=True)
        response.raise_for_status()
        
        total_size = int(response.headers.get('content-length', 0))
        if expected_size and total_size != expected_size:
            print(f"Warning: Expected size {expected_size}, got {total_size}")
        
        with open(filepath, 'wb') as f:
            with tqdm(total=total_size, unit='B', unit_scale=True, desc=filepath.name) as pbar:
                for chunk in response.iter_content(chunk_size=8192):
                    if chunk:
                        f.write(chunk)
                        pbar.update(len(chunk))
        
        print(f"✅ Downloaded {filepath.name}")
        return True
        
    except Exception as e:
        print(f"❌ Error downloading {filepath.name}: {e}")
        if filepath.exists():
            filepath.unlink()  # Remove partial file
        return False

def verify_file(filepath: Path, expected_size: int = None):
    """Verify downloaded file."""
    if not filepath.exists():
        return False
    
    actual_size = filepath.stat().st_size
    if expected_size and actual_size != expected_size:
        print(f"Warning: File size mismatch for {filepath.name}")
        return False
    
    print(f"✅ Verified {filepath.name} ({actual_size:,} bytes)")
    return True

def main():
    """Main download function."""
    print("🚀 LUMARA Gemma Model Downloader")
    print("=" * 50)
    
    # Create models directory
    models_dir = Path("assets/models")
    models_dir.mkdir(parents=True, exist_ok=True)
    
    print(f"📁 Models will be downloaded to: {models_dir.absolute()}")
    print()
    
    # Show available models
    print("Available models:")
    for model_id, config in MODELS.items():
        print(f"  • {config['filename']} ({config['size']}) - {config['description']}")
    print()
    
    # Ask user which models to download
    print("Which models would you like to download?")
    print("1. All models (recommended)")
    print("2. 1B model only (faster download, smaller size)")
    print("3. 4B model only (best performance)")
    print("4. Embeddings only")
    print("5. Custom selection")
    
    choice = input("\nEnter your choice (1-5): ").strip()
    
    models_to_download = []
    
    if choice == "1":
        models_to_download = list(MODELS.keys())
    elif choice == "2":
        models_to_download = ["gemma3_1b_instruct"]
    elif choice == "3":
        models_to_download = ["gemma3_4b_instruct"]
    elif choice == "4":
        models_to_download = ["embeddinggemma_mrl_512"]
    elif choice == "5":
        print("\nSelect models to download:")
        for i, (model_id, config) in enumerate(MODELS.items(), 1):
            print(f"{i}. {config['filename']} ({config['size']})")
        
        selections = input("Enter model numbers (comma-separated): ").strip()
        try:
            indices = [int(x.strip()) - 1 for x in selections.split(",")]
            models_to_download = [list(MODELS.keys())[i] for i in indices if 0 <= i < len(MODELS)]
        except ValueError:
            print("Invalid selection. Downloading all models.")
            models_to_download = list(MODELS.keys())
    else:
        print("Invalid choice. Downloading all models.")
        models_to_download = list(MODELS.keys())
    
    if not models_to_download:
        print("No models selected. Exiting.")
        return
    
    print(f"\n📥 Downloading {len(models_to_download)} model(s)...")
    print()
    
    # Download selected models
    success_count = 0
    for model_id in models_to_download:
        config = MODELS[model_id]
        filepath = models_dir / config["filename"]
        
        # Check if file already exists
        if filepath.exists():
            print(f"⏭️  {config['filename']} already exists, skipping...")
            success_count += 1
            continue
        
        # Download the file
        if download_file(config["url"], filepath):
            if verify_file(filepath):
                success_count += 1
            else:
                print(f"❌ Verification failed for {config['filename']}")
        else:
            print(f"❌ Download failed for {config['filename']}")
    
    print()
    print("=" * 50)
    print(f"✅ Download complete! {success_count}/{len(models_to_download)} models downloaded successfully.")
    
    if success_count > 0:
        print("\n🎉 Next steps:")
        print("1. Run 'flutter pub get' to update dependencies")
        print("2. Uncomment MediaPipe dependencies in build files")
        print("3. Run 'flutter run' to test with AI models")
        print("\n📖 See LUMARA_Gemma_Setup_Guide.md for detailed instructions")
    
    print("\n💡 Note: These are placeholder URLs. For production use, download from official sources:")
    print("   • Google AI Studio: https://aistudio.google.com/")
    print("   • Hugging Face: https://huggingface.co/google/gemma-2-9b-it")

if __name__ == "__main__":
    main()
