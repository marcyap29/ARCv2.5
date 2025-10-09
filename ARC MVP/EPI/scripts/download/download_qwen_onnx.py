#!/usr/bin/env python3
"""
Download Qwen2.5 ONNX models for mobile deployment
Supports multiple model sizes and quantization levels
"""

import os
import sys
import requests
from pathlib import Path
from tqdm import tqdm
import subprocess

# Model configurations
MODELS = {
    "qwen2.5-0.5b": {
        "repo": "onnx-community/Qwen2.5-0.5B-Instruct-onnx-web",
        "size": "~500MB",
        "description": "Ultra-lightweight model, fastest inference"
    },
    "qwen2.5-1.5b": {
        "repo": "onnx-community/Qwen2.5-1.5B-Instruct-onnx-web", 
        "size": "~1.5GB",
        "description": "Best balance of performance and size"
    },
    "qwen2.5-3b": {
        "repo": "onnx-community/Qwen2.5-3B-Instruct-onnx-web",
        "size": "~3GB", 
        "description": "Higher quality responses, needs more RAM"
    }
}

def download_file(url, filename, chunk_size=8192):
    """Download file with progress bar"""
    response = requests.get(url, stream=True)
    response.raise_for_status()
    
    total_size = int(response.headers.get('content-length', 0))
    
    with open(filename, 'wb') as f, tqdm(
        desc=filename.name,
        total=total_size,
        unit='iB',
        unit_scale=True,
        unit_divisor=1024,
    ) as bar:
        for chunk in response.iter_content(chunk_size=chunk_size):
            size = f.write(chunk)
            bar.update(size)

def download_model_files(model_name, repo_path):
    """Download model files using git-lfs or direct download"""
    models_dir = Path("assets/models/qwen")
    models_dir.mkdir(parents=True, exist_ok=True)
    
    model_dir = models_dir / model_name
    model_dir.mkdir(exist_ok=True)
    
    print(f"📥 Downloading {model_name} to {model_dir}")
    
    # Try using git-lfs first (more reliable for large files)
    try:
        cmd = [
            "git", "clone", "--depth=1",
            f"https://huggingface.co/{repo_path}",
            str(model_dir)
        ]
        result = subprocess.run(cmd, check=True, capture_output=True, text=True)
        print(f"✅ Successfully downloaded {model_name} using git")
        
        # Pull LFS files
        lfs_cmd = ["git", "lfs", "pull"]
        subprocess.run(lfs_cmd, cwd=model_dir, check=True)
        print(f"✅ Downloaded LFS files for {model_name}")
        
        return True
        
    except (subprocess.CalledProcessError, FileNotFoundError) as e:
        print(f"⚠️  Git download failed: {e}")
        print("💡 Trying direct download via HuggingFace Hub...")
        return download_via_hub(model_name, repo_path, model_dir)

def download_via_hub(model_name, repo_path, model_dir):
    """Download using HuggingFace Hub API"""
    try:
        from huggingface_hub import snapshot_download
        snapshot_download(
            repo_id=repo_path,
            local_dir=str(model_dir),
            local_dir_use_symlinks=False
        )
        print(f"✅ Successfully downloaded {model_name} via HuggingFace Hub")
        return True
    except ImportError:
        print("❌ HuggingFace Hub not available. Install with: pip install huggingface-hub")
        return False
    except Exception as e:
        print(f"❌ HuggingFace Hub download failed: {e}")
        return False

def main():
    print("🤖 Qwen2.5 ONNX Model Downloader")
    print("=" * 50)
    
    # Show available models
    print("\nAvailable models:")
    for key, info in MODELS.items():
        print(f"  {key}: {info['description']} ({info['size']})")
    
    # Get user choice
    if len(sys.argv) > 1:
        model_choice = sys.argv[1].lower()
    else:
        model_choice = input("\nEnter model name (default: qwen2.5-1.5b): ").lower() or "qwen2.5-1.5b"
    
    if model_choice not in MODELS:
        print(f"❌ Unknown model: {model_choice}")
        print(f"Available: {', '.join(MODELS.keys())}")
        sys.exit(1)
    
    model_info = MODELS[model_choice]
    print(f"\n📋 Selected: {model_choice}")
    print(f"📦 Size: {model_info['size']}")
    print(f"📝 {model_info['description']}")
    
    # Download model
    success = download_model_files(model_choice, model_info['repo'])
    
    if success:
        print(f"\n✅ Model {model_choice} downloaded successfully!")
        print(f"📁 Location: assets/models/qwen/{model_choice}")
        print("\n🚀 Next steps:")
        print("1. Update your Flutter app to use the ONNX model")
        print("2. Test inference on your device")
        print("3. Consider quantization for even smaller size")
    else:
        print(f"\n❌ Failed to download {model_choice}")
        print("💡 Try installing git-lfs or huggingface-hub:")
        print("   brew install git-lfs  # macOS")
        print("   pip install huggingface-hub")

if __name__ == "__main__":
    main()