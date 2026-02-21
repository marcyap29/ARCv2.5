#!/usr/bin/env python3
"""
Download Llama 3.2 3B GGUF Model for EPI
"""

import os
import requests
from pathlib import Path
from tqdm import tqdm

def download_file(url: str, filepath: Path):
    """Download a file with progress bar."""
    print(f"Downloading {filepath.name}...")
    
    try:
        response = requests.get(url, stream=True)
        response.raise_for_status()
        
        total_size = int(response.headers.get('content-length', 0))
        
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
            filepath.unlink()
        return False

def main():
    print("🚀 Downloading Llama 3.2 3B GGUF Model")
    print("=" * 50)
    
    # Create directories
    assets_dir = Path("assets/models/gguf")
    assets_dir.mkdir(parents=True, exist_ok=True)
    
    documents_dir = Path("gguf_models")
    documents_dir.mkdir(parents=True, exist_ok=True)
    
    # Model URL (using a reliable source)
    model_url = "https://huggingface.co/microsoft/Llama-3.2-3B-Instruct-GGUF/resolve/main/Llama-3.2-3B-Instruct-Q4_K_M.gguf"
    model_filename = "Llama-3.2-3b-Instruct-Q4_K_M.gguf"
    
    # Download to both locations
    assets_path = assets_dir / model_filename
    documents_path = documents_dir / model_filename
    
    print(f"📁 Assets path: {assets_path.absolute()}")
    print(f"📁 Documents path: {documents_path.absolute()}")
    print()
    
    # Download to assets directory (for bundle)
    if not assets_path.exists():
        if download_file(model_url, assets_path):
            print(f"✅ Downloaded to assets: {assets_path}")
        else:
            print("❌ Failed to download to assets")
            return
    else:
        print(f"⏭️  Model already exists in assets: {assets_path}")
    
    # Copy to documents directory (for runtime access)
    if not documents_path.exists():
        if assets_path.exists():
            import shutil
            shutil.copy2(assets_path, documents_path)
            print(f"✅ Copied to documents: {documents_path}")
        else:
            print("❌ Cannot copy - assets file doesn't exist")
    else:
        print(f"⏭️  Model already exists in documents: {documents_path}")
    
    print()
    print("🎉 Download complete!")
    print("The model is now available in both locations:")
    print(f"  • Bundle: {assets_path}")
    print(f"  • Documents: {documents_path}")
    print()
    print("Next steps:")
    print("1. Run 'flutter clean && flutter run'")
    print("2. Test the app - llama.cpp should now initialize successfully")

if __name__ == "__main__":
    main()
