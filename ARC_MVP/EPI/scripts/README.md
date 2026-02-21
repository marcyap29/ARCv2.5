# Development Scripts

## setup_models.sh

**Purpose:** Installs MLX model files to local Application Support directory for development.

**Why is this needed?**
- Model files are 2.6GB (too large for app bundle or Git repository)
- Models are excluded via `.gitignore: ARC MVP/EPI/assets/models/**`
- Flutter doesn't bundle Git-ignored files into the app
- Solution: Copy models to `~/Library/Application Support/Models/` for local access

**Usage:**
```bash
./scripts/setup_models.sh
```

**What it does:**
1. Creates `~/Library/Application Support/Models/` directory
2. Copies `assets/models/MLX/Qwen3-1.7B-MLX-4bit/` to Application Support
3. Skips if models already installed
4. Reports success and total size

**When to run:**
- First time setting up the project
- After cleaning Application Support directory
- If model files are updated

**Output:**
```
🚀 Setting up MLX models for local development...
📦 Copying Qwen3-1.7B-MLX-4bit (this may take a minute)...
   ✅ Copied successfully
✅ Model setup complete!
Total size: 3.8G
```

**Troubleshooting:**
- **Source not found:** Ensure `assets/models/MLX/Qwen3-1.7B-MLX-4bit/` exists locally
- **Already exists:** Models are already installed, no action needed
- **Permission denied:** Check write access to `~/Library/Application Support/`

## Future Production Approach

For production releases, models should be:
1. Hosted on CDN (S3, Firebase Storage, etc.)
2. Downloaded on first app launch with progress UI
3. Cached in Application Support directory
4. Similar to ChatGPT, Claude, and other ML apps
