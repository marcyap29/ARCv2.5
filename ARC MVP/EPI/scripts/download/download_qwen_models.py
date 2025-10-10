#!/usr/bin/env python3
"""
Qwen Model Download Manager for LUMARA
Downloads GGUF models optimized for mobile deployment via llama.cpp
"""

import os
import sys
import json
import hashlib
import requests
from pathlib import Path
from typing import Dict, List, Optional, Tuple
from dataclasses import dataclass
import subprocess
from tqdm import tqdm

@dataclass
class QwenModelManifest:
    """Model configuration with download URLs and verification"""
    model_id: str
    display_name: str
    filename: str
    size_mb: int
    min_ram_gb: int
    description: str
    repo_id: str
    is_default: bool
    sha256: str
    download_url: str

# Official Qwen model manifest
QWEN_MODELS = [
    QwenModelManifest(
        model_id="llama3_2_3b_instruct",
        display_name="Llama 3.2 3B Instruct (Q4_K_M)",
        filename="Llama-3.2-3b-Instruct-Q4_K_M.gguf",
        size_mb=1900,
        min_ram_gb=4,
        description="Recommended: Fast, efficient, 4-bit quantized",
        repo_id="hugging-quants/Llama-3.2-3B-Instruct-Q4_K_M-GGUF",
        is_default=True,
        sha256="",
        download_url="https://huggingface.co/hugging-quants/Llama-3.2-3B-Instruct-Q4_K_M-GGUF/resolve/main/llama-3.2-3b-instruct-q4_k_m.gguf?download=true"
    ),
    QwenModelManifest(
        model_id="qwen3_4b_instruct_2507",
        display_name="Qwen3 4B Instruct (Q4_K_S)",
        filename="Qwen3-4B-Instruct-2507-Q4_K_S.gguf",
        size_mb=2500,
        min_ram_gb=6,
        description="Multilingual, 4-bit quantized, excellent reasoning capabilities",
        repo_id="unsloth/Qwen3-4B-Instruct-2507-GGUF",
        is_default=False,
        sha256="",
        download_url="https://huggingface.co/unsloth/Qwen3-4B-Instruct-2507-GGUF/resolve/main/Qwen3-4B-Instruct-2507-Q4_K_S.gguf?download=true"
    ),
    QwenModelManifest(
        model_id="qwen2p5_vl_3b_instruct",
        display_name="Qwen2.5-VL 3B Instruct",
        filename="qwen2p5_vl_3b_instruct_q5_k_m.gguf",
        size_mb=2000,
        min_ram_gb=6,
        description="Vision-language model for image understanding",
        repo_id="bartowski/Qwen2.5-VL-3B-Instruct-GGUF",
        is_default=True,
        sha256="",
        download_url="https://huggingface.co/bartowski/Qwen2.5-VL-3B-Instruct-GGUF/resolve/main/Qwen2.5-VL-3B-Instruct-Q5_K_M.gguf"
    ),
    QwenModelManifest(
        model_id="qwen2_vl_2b_instruct",
        display_name="Qwen2-VL 2B Instruct",
        filename="qwen2_vl_2b_instruct_q6_k_l.gguf",
        size_mb=1600,
        min_ram_gb=4,
        description="Compact vision-language model",
        repo_id="bartowski/Qwen2-VL-2B-Instruct-GGUF",
        is_default=False,
        sha256="",
        download_url="https://huggingface.co/bartowski/Qwen2-VL-2B-Instruct-GGUF/resolve/main/Qwen2-VL-2B-Instruct-Q6_K_L.gguf"
    ),
    QwenModelManifest(
        model_id="qwen3_embedding_0p6b",
        display_name="Qwen3 Embedding 0.6B",
        filename="qwen3_embedding_0p6b_int4.gguf",
        size_mb=400,
        min_ram_gb=2,
        description="Compact embedding model for semantic search and RAG",
        repo_id="Qwen/Qwen3-Embedding-0.6B-GGUF",
        is_default=True,
        sha256="",
        download_url="https://huggingface.co/Qwen/Qwen3-Embedding-0.6B-GGUF/resolve/main/qwen3-embedding-0.6b-int4.gguf"
    ),
]

class QwenModelDownloader:
    def __init__(self):
        self.models_dir = Path("assets/models/qwen")
        self.models_dir.mkdir(parents=True, exist_ok=True)
        
    def list_available_models(self) -> None:
        """Display all available Qwen models"""
        print("🤖 Available Qwen Models for LUMARA")
        print("=" * 60)
        
        print("\n📱 Chat Models (Text Generation):")
        for model in QWEN_MODELS:
            if "instruct" in model.model_id and "vl" not in model.model_id:
                status = "✅ DEFAULT" if model.is_default else ""
                print(f"  {model.model_id}: {model.display_name} {status}")
                print(f"    Size: {model.size_mb}MB | Min RAM: {model.min_ram_gb}GB")
                print(f"    {model.description}\n")
        
        print("🔍 Vision-Language Models (Image + Text):")
        for model in QWEN_MODELS:
            if "vl" in model.model_id:
                status = "✅ DEFAULT" if model.is_default else ""
                print(f"  {model.model_id}: {model.display_name} {status}")
                print(f"    Size: {model.size_mb}MB | Min RAM: {model.min_ram_gb}GB")
                print(f"    {model.description}\n")
                
        print("🧠 Embedding Models (Semantic Search):")
        for model in QWEN_MODELS:
            if "embedding" in model.model_id:
                status = "✅ DEFAULT" if model.is_default else ""
                print(f"  {model.model_id}: {model.display_name} {status}")
                print(f"    Size: {model.size_mb}MB | Min RAM: {model.min_ram_gb}GB")
                print(f"    {model.description}\n")
    
    def download_file_with_progress(self, url: str, filepath: Path, expected_size: int) -> bool:
        """Download file with progress bar and resumable downloads"""
        
        # Check if file already exists and get its size
        resume_pos = 0
        if filepath.exists():
            resume_pos = filepath.stat().st_size
            if resume_pos >= expected_size * 1024 * 1024:  # Convert MB to bytes
                print(f"✅ {filepath.name} already downloaded")
                return True
                
        headers = {}
        if resume_pos > 0:
            headers['Range'] = f'bytes={resume_pos}-'
            print(f"🔄 Resuming download from {resume_pos // (1024*1024)}MB")
        
        try:
            response = requests.get(url, headers=headers, stream=True, timeout=30)
            response.raise_for_status()
            
            total_size = int(response.headers.get('content-length', 0)) + resume_pos
            
            mode = 'ab' if resume_pos > 0 else 'wb'
            
            with open(filepath, mode) as f, tqdm(
                desc=filepath.name,
                total=total_size,
                unit='iB',
                unit_scale=True,
                unit_divisor=1024,
                initial=resume_pos,
            ) as pbar:
                for chunk in response.iter_content(chunk_size=8192):
                    if chunk:
                        size = f.write(chunk)
                        pbar.update(size)
                        
            print(f"✅ Downloaded {filepath.name}")
            return True
            
        except Exception as e:
            print(f"❌ Download failed: {e}")
            if filepath.exists():
                filepath.unlink()  # Clean up partial download
            return False
    
    def verify_checksum(self, filepath: Path, expected_hash: str) -> bool:
        """Verify file integrity using SHA256"""
        if not expected_hash:
            print("⚠️  No checksum available, skipping verification")
            return True
            
        print(f"🔍 Verifying {filepath.name}...")
        sha256_hash = hashlib.sha256()
        
        with open(filepath, "rb") as f:
            for chunk in iter(lambda: f.read(4096), b""):
                sha256_hash.update(chunk)
                
        calculated_hash = sha256_hash.hexdigest()
        
        if calculated_hash.lower() == expected_hash.lower():
            print("✅ Checksum verified")
            return True
        else:
            print(f"❌ Checksum mismatch:")
            print(f"  Expected: {expected_hash}")
            print(f"  Got:      {calculated_hash}")
            return False
    
    def download_model(self, model_id: str) -> bool:
        """Download a specific model by ID"""
        model = None
        for m in QWEN_MODELS:
            if m.model_id == model_id:
                model = m
                break
                
        if not model:
            print(f"❌ Model '{model_id}' not found")
            return False
            
        print(f"📥 Downloading {model.display_name}")
        print(f"📁 Size: {model.size_mb}MB | Min RAM: {model.min_ram_gb}GB")
        print(f"💾 {model.description}")
        print()
        
        filepath = self.models_dir / model.filename
        
        # Download the model
        success = self.download_file_with_progress(
            model.download_url, 
            filepath, 
            model.size_mb
        )
        
        if not success:
            return False
            
        # Verify checksum if available
        if not self.verify_checksum(filepath, model.sha256):
            filepath.unlink()  # Delete corrupted file
            return False
            
        # Save model metadata
        metadata = {
            'model_id': model.model_id,
            'display_name': model.display_name,
            'filename': model.filename,
            'size_mb': model.size_mb,
            'min_ram_gb': model.min_ram_gb,
            'description': model.description,
            'download_date': str(Path(filepath).stat().st_mtime),
            'is_default': model.is_default
        }
        
        with open(filepath.with_suffix('.json'), 'w') as f:
            json.dump(metadata, f, indent=2)
            
        print(f"✅ Successfully downloaded {model.display_name}")
        return True
    
    def download_default_models(self) -> bool:
        """Download all default models for a complete LUMARA setup"""
        print("📦 Downloading default Qwen models for LUMARA...")
        print("This includes: Chat + Vision + Embeddings models\n")
        
        default_models = [m for m in QWEN_MODELS if m.is_default]
        total_size = sum(m.size_mb for m in default_models)
        
        print(f"📊 Total download size: {total_size}MB (~{total_size/1024:.1f}GB)")
        
        confirm = input("\nProceed with download? [y/N]: ").lower()
        if confirm != 'y':
            print("❌ Download cancelled")
            return False
            
        success_count = 0
        for model in default_models:
            if self.download_model(model.model_id):
                success_count += 1
            print()  # Add spacing between downloads
            
        if success_count == len(default_models):
            print(f"🎉 Successfully downloaded all {success_count} default models!")
            print(f"📁 Models saved to: {self.models_dir}")
            print("\n🚀 Next steps:")
            print("1. Build your Flutter app with Qwen integration")
            print("2. Test inference performance on your device")
            print("3. Adjust model selection based on device capabilities")
            return True
        else:
            print(f"⚠️  Downloaded {success_count}/{len(default_models)} models")
            return False

def main():
    downloader = QwenModelDownloader()
    
    if len(sys.argv) < 2:
        print("🤖 Qwen Model Manager for LUMARA")
        print("Usage:")
        print("  python3 download_qwen_models.py list")
        print("  python3 download_qwen_models.py download <model_id>")
        print("  python3 download_qwen_models.py download-defaults")
        print()
        downloader.list_available_models()
        return
        
    command = sys.argv[1]
    
    if command == "list":
        downloader.list_available_models()
    elif command == "download" and len(sys.argv) > 2:
        model_id = sys.argv[2]
        downloader.download_model(model_id)
    elif command == "download-defaults":
        downloader.download_default_models()
    else:
        print("❌ Invalid command. Use 'list', 'download <model_id>', or 'download-defaults'")

if __name__ == "__main__":
    main()