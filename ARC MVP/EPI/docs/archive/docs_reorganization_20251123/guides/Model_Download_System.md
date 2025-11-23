# Model Download System - On-Device AI Model Management

**Last Updated:** October 10, 2025
**Status:** Production Ready ✅
**Module:** LUMARA (On-Device LLM)
**Location:** `scripts/download/download_qwen_models.py`, `lib/lumara/services/download_state_service.dart`

## Overview

The **Model Download System** provides automated download, verification, and management of GGUF models for on-device AI inference. It supports multiple model types (chat, vision-language, embedding) with resumable downloads, checksum verification, and persistent progress tracking.

## Table of Contents

1. [Architecture](#architecture)
2. [Python Download Manager](#python-download-manager)
3. [Flutter Download State Service](#flutter-download-state-service)
4. [Model Manifest](#model-manifest)
5. [Usage Examples](#usage-examples)
6. [Technical Reference](#technical-reference)

---

## Architecture

### Component Overview

```
Model Download System
├── Python CLI (scripts/download/)
│   ├── download_qwen_models.py    # Main download manager
│   ├── download_llama_gguf.py     # Llama model downloader
│   ├── download_gemma_4b.py       # Gemma model downloader
│   └── download_models.py         # Legacy/generic downloader
└── Flutter Services (lib/lumara/services/)
    ├── download_state_service.dart # Persistent state management
    ├── model_progress_service.dart # Progress tracking
    └── iOS Native (ios/Runner/)
        └── ModelDownloadService.swift # iOS download integration
```

### Key Features

- **Resumable Downloads**: Partial downloads preserved across sessions
- **Checksum Verification**: SHA-256 integrity checking
- **Progress Tracking**: Real-time download progress with byte tracking
- **Model Metadata**: JSON metadata for each downloaded model
- **Default Profiles**: Pre-configured model sets for common use cases
- **Multi-Model Support**: Chat, vision-language, and embedding models

---

## Python Download Manager

### Location
`scripts/download/download_qwen_models.py`

### Supported Models

#### Chat Models (Text Generation)

1. **Llama 3.2 3B Instruct (Q4_K_M)** - DEFAULT
   - Size: 1900 MB
   - Min RAM: 4 GB
   - Quantization: 4-bit (Q4_K_M)
   - Description: Fast, efficient, recommended for most users
   - Repo: `hugging-quants/Llama-3.2-3B-Instruct-Q4_K_M-GGUF`

2. **Qwen3 4B Instruct (Q4_K_S)**
   - Size: 2500 MB
   - Min RAM: 6 GB
   - Quantization: 4-bit (Q4_K_S)
   - Description: Multilingual, excellent reasoning capabilities
   - Repo: `unsloth/Qwen3-4B-Instruct-2507-GGUF`


#### Vision-Language Models (Image + Text)

4. **Qwen2.5-VL 3B Instruct** - DEFAULT
   - Size: 2000 MB
   - Min RAM: 6 GB
   - Quantization: Q5_K_M
   - Description: Vision-language model for image understanding
   - Repo: `bartowski/Qwen2.5-VL-3B-Instruct-GGUF`

5. **Qwen2-VL 2B Instruct**
   - Size: 1600 MB
   - Min RAM: 4 GB
   - Quantization: Q6_K_L
   - Description: Compact vision-language model
   - Repo: `bartowski/Qwen2-VL-2B-Instruct-GGUF`

#### Embedding Models (Semantic Search)

6. **Qwen3 Embedding 0.6B** - DEFAULT
   - Size: 400 MB
   - Min RAM: 2 GB
   - Quantization: INT4
   - Description: Compact embedding model for semantic search and RAG
   - Repo: `Qwen/Qwen3-Embedding-0.6B-GGUF`

### CLI Usage

#### List Available Models

```bash
python3 scripts/download/download_qwen_models.py list
```

Output:
```
🤖 Available Qwen Models for LUMARA
============================================================

📱 Chat Models (Text Generation):
  llama3_2_3b_instruct: Llama 3.2 3B Instruct (Q4_K_M) ✅ DEFAULT
    Size: 1900MB | Min RAM: 4GB
    Recommended: Fast, efficient, 4-bit quantized

  qwen3_4b_instruct_2507: Qwen3 4B Instruct (Q4_K_S)
    Size: 2500MB | Min RAM: 6GB
    Multilingual, 4-bit quantized, excellent reasoning capabilities

🔍 Vision-Language Models (Image + Text):
  qwen2p5_vl_3b_instruct: Qwen2.5-VL 3B Instruct ✅ DEFAULT
    Size: 2000MB | Min RAM: 6GB
    Vision-language model for image understanding

  qwen2_vl_2b_instruct: Qwen2-VL 2B Instruct
    Size: 1600MB | Min RAM: 4GB
    Compact vision-language model

🧠 Embedding Models (Semantic Search):
  qwen3_embedding_0p6b: Qwen3 Embedding 0.6B ✅ DEFAULT
    Size: 400MB | Min RAM: 2GB
    Compact embedding model for semantic search and RAG
```

#### Download Single Model

```bash
python3 scripts/download/download_qwen_models.py download llama3_2_3b_instruct
```

Output:
```
📥 Downloading Llama 3.2 3B Instruct (Q4_K_M)
📁 Size: 1900MB | Min RAM: 4GB
💾 Recommended: Fast, efficient, 4-bit quantized

llama-3.2-3b-instruct-q4_k_m.gguf:  45%|████████▌        | 855MB/1900MB [02:15<02:55, 5.95MB/s]
```

#### Download All Default Models

```bash
python3 scripts/download/download_qwen_models.py download-defaults
```

Output:
```
📦 Downloading default Qwen models for LUMARA...
This includes: Chat + Vision + Embeddings models

📊 Total download size: 4300MB (~4.2GB)

Proceed with download? [y/N]: y

📥 Downloading Llama 3.2 3B Instruct (Q4_K_M)
✅ Downloaded llama-3.2-3b-instruct-q4_k_m.gguf

📥 Downloading Qwen2.5-VL 3B Instruct
✅ Downloaded qwen2p5_vl_3b_instruct_q5_k_m.gguf

📥 Downloading Qwen3 Embedding 0.6B
✅ Downloaded qwen3_embedding_0p6b_int4.gguf

🎉 Successfully downloaded all 3 default models!
📁 Models saved to: assets/models/qwen

🚀 Next steps:
1. Build your Flutter app with Qwen integration
2. Test inference performance on your device
3. Adjust model selection based on device capabilities
```

### Python API

#### QwenModelManifest

```python
@dataclass
class QwenModelManifest:
    model_id: str           # Unique identifier
    display_name: str       # Human-readable name
    filename: str           # GGUF filename
    size_mb: int           # Size in megabytes
    min_ram_gb: int        # Minimum RAM requirement
    description: str        # Model description
    repo_id: str           # HuggingFace repo ID
    is_default: bool       # Default model flag
    sha256: str            # SHA-256 checksum
    download_url: str      # Direct download URL
```

#### QwenModelDownloader

```python
class QwenModelDownloader:
    def __init__(self):
        self.models_dir = Path("assets/models/qwen")

    def list_available_models(self) -> None:
        """Display all available models"""

    def download_file_with_progress(self, url: str, filepath: Path, expected_size: int) -> bool:
        """Download file with progress bar and resumable downloads"""

    def verify_checksum(self, filepath: Path, expected_hash: str) -> bool:
        """Verify file integrity using SHA256"""

    def download_model(self, model_id: str) -> bool:
        """Download a specific model by ID"""

    def download_default_models(self) -> bool:
        """Download all default models"""
```

### Resumable Downloads

The download system supports **automatic resume** for interrupted downloads:

```python
# Check if file already exists and get its size
resume_pos = 0
if filepath.exists():
    resume_pos = filepath.stat().st_size
    if resume_pos >= expected_size * 1024 * 1024:
        print(f"✅ {filepath.name} already downloaded")
        return True

headers = {}
if resume_pos > 0:
    headers['Range'] = f'bytes={resume_pos}-'
    print(f"🔄 Resuming download from {resume_pos // (1024*1024)}MB")

# Open file in append mode if resuming
mode = 'ab' if resume_pos > 0 else 'wb'
```

---

## Flutter Download State Service

### Location
`lib/lumara/services/download_state_service.dart`

### ModelDownloadState

```dart
class ModelDownloadState {
  final String modelId;
  final bool isDownloading;
  final bool isDownloaded;
  final double progress;           // 0.0 to 1.0
  final String statusMessage;
  final String? errorMessage;
  final int? bytesDownloaded;      // Bytes downloaded so far
  final int? totalBytes;           // Total bytes to download

  // Human-readable download size
  String get downloadSizeText {
    if (bytesDownloaded == null) return '';

    final downloadedMB = bytesDownloaded! / 1048576;

    if (totalBytes == null || totalBytes == 0) {
      return '${downloadedMB.toStringAsFixed(1)} MB';
    }

    final totalMB = totalBytes! / 1048576;

    if (totalMB >= 1000) {
      // Show in GB
      final downloadedGB = downloadedMB / 1024;
      final totalGB = totalMB / 1024;
      return '${downloadedGB.toStringAsFixed(2)} / ${totalGB.toStringAsFixed(2)} GB';
    } else {
      // Show in MB
      return '${downloadedMB.toStringAsFixed(1)} / ${totalMB.toStringAsFixed(1)} MB';
    }
  }
}
```

### DownloadStateService (Singleton)

```dart
class DownloadStateService extends ChangeNotifier {
  static final DownloadStateService _instance = DownloadStateService._internal();
  static DownloadStateService get instance => _instance;

  final Map<String, ModelDownloadState> _downloadStates = {};

  // Get download state for a specific model
  ModelDownloadState? getState(String modelId);

  // Get all download states
  Map<String, ModelDownloadState> get allStates;

  // Update download state
  void updateState(String modelId, ModelDownloadState state);

  // Update progress with byte information
  void updateProgress({
    required String modelId,
    required double progress,
    required String statusMessage,
    int? bytesDownloaded,
    int? totalBytes,
  });

  // Mark download as started
  void startDownload(String modelId, {String? modelName});

  // Mark download as completed
  void completeDownload(String modelId);

  // Mark download as failed
  void failDownload(String modelId, String error);

  // Mark download as cancelled
  void cancelDownload(String modelId);

  // Update model availability
  void updateAvailability(String modelId, bool isAvailable);

  // Clear all download states
  void clearAll();

  // Clear state for specific model
  void clearModelState(String modelId);

  // Force refresh all states
  void refreshAllStates();
}
```

---

## Model Manifest

Each downloaded model includes a JSON metadata file:

### Metadata Structure

```json
{
  "model_id": "llama3_2_3b_instruct",
  "display_name": "Llama 3.2 3B Instruct (Q4_K_M)",
  "filename": "Llama-3.2-3b-Instruct-Q4_K_M.gguf",
  "size_mb": 1900,
  "min_ram_gb": 4,
  "description": "Recommended: Fast, efficient, 4-bit quantized",
  "download_date": "1728576000.0",
  "is_default": true
}
```

---

## Usage Examples

### Python CLI

#### Download Single Model

```bash
# Download Llama 3.2 3B
python3 scripts/download/download_qwen_models.py download llama3_2_3b_instruct

# Download Qwen3 4B
python3 scripts/download/download_qwen_models.py download qwen3_4b_instruct_2507

# Download vision model
python3 scripts/download/download_qwen_models.py download qwen2p5_vl_3b_instruct
```

#### Download All Defaults

```bash
python3 scripts/download/download_qwen_models.py download-defaults
```

### Flutter Integration

#### Track Download Progress

```dart
import 'package:my_app/lumara/services/download_state_service.dart';

// Get service instance
final downloadService = DownloadStateService.instance;

// Listen to download state changes
downloadService.addListener(() {
  final state = downloadService.getState('Llama-3.2-3b-Instruct-Q4_K_M.gguf');

  if (state != null) {
    print('Progress: ${state.progress * 100}%');
    print('Downloaded: ${state.downloadSizeText}');
    print('Status: ${state.statusMessage}');

    if (state.isDownloaded) {
      print('✅ Download complete!');
    } else if (state.errorMessage != null) {
      print('❌ Error: ${state.errorMessage}');
    }
  }
});
```

#### Update Download Progress (from iOS)

```dart
// Called from iOS native download service
void updateDownloadProgress({
  required String modelId,
  required int bytesDownloaded,
  required int totalBytes,
}) {
  final progress = totalBytes > 0 ? bytesDownloaded / totalBytes : 0.0;

  DownloadStateService.instance.updateProgress(
    modelId: modelId,
    progress: progress,
    statusMessage: 'Downloading...',
    bytesDownloaded: bytesDownloaded,
    totalBytes: totalBytes,
  );
}
```

#### UI Widget

```dart
import 'package:flutter/material.dart';
import 'package:my_app/lumara/services/download_state_service.dart';

class ModelDownloadCard extends StatelessWidget {
  final String modelId;

  const ModelDownloadCard({required this.modelId});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: DownloadStateService.instance,
      builder: (context, _) {
        final state = DownloadStateService.instance.getState(modelId);

        if (state == null) {
          return Text('Model not found');
        }

        return Card(
          child: Column(
            children: [
              Text(state.statusMessage),
              if (state.isDownloading)
                LinearProgressIndicator(value: state.progress),
              Text(state.downloadSizeText),
              if (state.errorMessage != null)
                Text('Error: ${state.errorMessage}', style: TextStyle(color: Colors.red)),
            ],
          ),
        );
      },
    );
  }
}
```

---

## Technical Reference

### Download Locations

- **Default Directory**: `assets/models/qwen/`
- **Metadata Files**: `<model_filename>.json`
- **GGUF Files**: `<model_filename>.gguf`

### Performance Characteristics

| Model Type | Size | Download Time (10 Mbps) | RAM Usage |
|-----------|------|------------------------|-----------|
| Llama 3.2 3B (Q4_K_M) | 1.9 GB | ~25 min | 4 GB |
| Qwen3 4B (Q4_K_S) | 2.5 GB | ~33 min | 6 GB |
| Qwen2.5-VL 3B | 2.0 GB | ~27 min | 6 GB |
| Qwen2-VL 2B | 1.6 GB | ~21 min | 4 GB |
| Qwen3 Embedding 0.6B | 0.4 GB | ~5 min | 2 GB |

### Checksum Verification

```python
def verify_checksum(filepath: Path, expected_hash: str) -> bool:
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
```

---

## Related Documentation

- **EPI Architecture**: `docs/architecture/EPI_Architecture.md`
- **LUMARA LLM System**: `lib/lumara/llm/`
- **Model Management Cubit**: `lib/lumara/bloc/model_management_cubit.dart`
- **iOS Model Download Service**: `ios/Runner/ModelDownloadService.swift`

---

**Status:** Production Ready ✅
**Version:** 1.0.0
**Last Updated:** October 10, 2025
**Maintainer:** EPI Development Team
