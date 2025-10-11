# EPI Documentation

**Last Updated:** January 8, 2025
**Status:** Production Ready ✅

This directory contains comprehensive documentation for the EPI (Evolving Personal Intelligence) project - an 8-module intelligent journaling system built with Flutter.

## 🆕 Latest Updates (January 8, 2025)

**Native iOS Photos Framework Integration + Universal Media Opening System**

Production-ready native iOS Photos framework integration for all media types:
- **Native iOS Photos Integration** - Direct media opening in iOS Photos app for all media types
- **Universal Media Support** - Photos, videos, and audio files with native iOS framework
- **Smart Media Detection** - Automatic media type detection and appropriate handling
- **Broken Link Recovery** - Comprehensive broken media detection and recovery system
- **Multi-Method Opening** - Native search, ID extraction, direct file, and search fallbacks
- **Cross-Platform Support** - iOS native methods with Android fallbacks
- **Method Channels** - Flutter ↔ Swift communication for media operations
- **PHAsset Search** - Native iOS Photos library search by filename

**Previous: Complete Multimodal Processing System + Thumbnail Caching**

Production-ready multimodal processing with comprehensive photo analysis:
- **iOS Vision Integration** - Pure on-device processing using Apple's Core ML + Vision Framework
- **Thumbnail Caching System** - Memory + file-based caching with automatic cleanup
- **Clickable Photo Thumbnails** - Direct photo opening in iOS Photos app
- **Keypoints Visualization** - Interactive display of feature analysis details
- **MCP Format Integration** - Structured data storage with pointer references
- **Cross-Platform UI** - Works in both journal screen and timeline editor

## 📚 Documentation Structure

### 📋 [Project](./project/)
Core project documentation and briefs
- **PROJECT_BRIEF.md** - Main project overview and current status
- **README.md** - Project-level documentation
- **Status_Update.md** - Project status snapshots
- **ChatGPT_Mobile_Optimizations.md** - Mobile optimization documentation
- **Model_Recognition_Fixes.md** - Model detection fixes
- **Speed_Optimization_Guide.md** - Performance optimization guide
- **MCP_Multimodal_Expansion_Status.md** - Multimodal MCP expansion plan
  - Chat message model enhancements
  - MCP export/import for multimodal content
  - llama.cpp multimodal integration
  - UI/UX enhancements for media attachments

### 🏗️ [Architecture](./architecture/)
System architecture and design documentation
- **EPI_Architecture.md** - Complete 8-module EPI system architecture
  - ARC (Journaling), PRISM (Multi-Modal), ECHO (Response Layer)
  - ATLAS (Phase Detection), MIRA (Narrative Intelligence), AURORA (Circadian)
  - VEIL (Self-Pruning), RIVET (Risk Validation)
  - On-Device LLM Architecture (llama.cpp + Metal)
  - Navigation & UI Architecture
- **MIRA_Basics.md** - Instant phase & themes answers without LLM
  - Quick Answers System (sub-second responses)
  - Phase Detection & Geometry Mapping
  - Streak Tracking & Recent Entry Summaries
  - MMCO (Minimal MIRA Context Object)
- **Constellation_Arcform_Renderer.md** - Polar coordinate visualization system
  - Phase-Specific Layouts (spiral, flower, weave, glow core, fractal, branch)
  - k-NN Edge Weaving Algorithm
  - 3-Controller Animation System
  - 8-Color Emotion Palette

### 🐛 [Bug Tracker](./bugtracker/)
Bug tracking and resolution documentation
- **Bug_Tracker.md** - Current bug tracker (main file)
- **Bug_Tracker Files/** - Historical bug tracker snapshots
  - Bug_Tracker-1.md through Bug_Tracker-8.md (chronological)
  - Tracks all resolved issues from critical to enhancement-level

### 📊 [Status](./status/)
Current status and session documentation
- **STATUS.md** - Current project status
- **STATUS_UPDATE.md** - Status updates and progress
- **SESSION_SUMMARY.md** - Development session summaries

### 📝 [Changelog](./changelog/)
Version history and change documentation
- **CHANGELOG.md** - Main changelog
- **Changelogs/** - Historical changelog files
  - CHANGELOG1.md - Earlier version history

### 📖 [Guides](./guides/)
User and developer guides
- **Arc_Prompts.md** - ARC journaling prompts and templates
- **MVP_Install.md** - Installation and setup guide
- **MULTIMODAL_INTEGRATION_GUIDE.md** - Complete multimodal processing system guide
- **Model_Download_System.md** - On-device AI model management
  - Python CLI Download Manager
  - Flutter Download State Service
  - Resumable Downloads & Checksum Verification
  - Model Manifest & Metadata

### 📄 [Reports](./reports/)
Success reports and technical achievements
- **LLAMA_CPP_MODERNIZATION_SUCCESS_REPORT.md** - Modern C API integration
- **LLAMA_CPP_UPGRADE_STATUS_REPORT.md** - Upgrade progress tracking
- **LLAMA_CPP_UPGRADE_SUCCESS_REPORT.md** - Complete upgrade documentation
- **MEMORY_MANAGEMENT_SUCCESS_REPORT.md** - Memory management fixes
- **ROOT_CAUSE_FIXES_SUCCESS_REPORT.md** - Root cause analysis and fixes

### 🗄️ [Archive](./archive/)
Archived documentation and historical records
- **ARCHIVE_ANALYSIS.md** - Archive organization documentation
- **Archive/** - Historical project documentation
  - ARC MVP Implementation reports
  - Reference documents (LUMARA, MCP, Memory Features)
  - Development tools and configuration

## 🎯 Quick Start

1. **New to EPI?** Start with [PROJECT_BRIEF.md](./project/PROJECT_BRIEF.md)
2. **Understanding Architecture?** Read [EPI_Architecture.md](./architecture/EPI_Architecture.md)
3. **Troubleshooting?** Check [Bug_Tracker.md](./bugtracker/Bug_Tracker.md)
4. **Installation?** Follow [MVP_Install.md](./guides/MVP_Install.md)
5. **Status Updates?** See [STATUS.md](./status/STATUS.md)

## 🏆 Current Status

**Production Ready** - October 10, 2025

### Latest Achievements
- ✅ MIRA Basics (Instant phase/themes without LLM)
- ✅ Constellation Arcform Renderer (Polar Coordinate System)
- ✅ Model Download System (Resumable downloads with verification)
- ✅ Multimodal MCP Expansion (In Progress on `multimodal` branch)
- ✅ Branch Consolidation (52 commits merged, 88% repo cleanup)
- ✅ On-Device LLM (llama.cpp + Metal)
- ✅ All Critical Issues Resolved
- ✅ Modern C API Integration Complete
- ✅ Memory Management Fixes Complete

### Key Features
- Complete 8-module architecture (ARC→PRISM→ECHO→ATLAS→MIRA→AURORA→VEIL→RIVET)
- On-device AI inference with llama.cpp + Metal acceleration
- MIRA Basics: Quick answers without LLM (300x faster)
- Constellation visualization with 6 phase-specific layouts
- Model download system with resumable downloads
- Privacy-first design with local processing
- MCP Memory System for conversation persistence
- Advanced prompt engineering system

## 📖 Reading Path

### For Developers
1. [PROJECT_BRIEF.md](./project/PROJECT_BRIEF.md) - Get project context
2. [EPI_Architecture.md](./architecture/EPI_Architecture.md) - Understand system design
3. [Bug_Tracker.md](./bugtracker/Bug_Tracker.md) - Learn from issues
4. [Reports](./reports/) - Review technical achievements

### For Users
1. [PROJECT_BRIEF.md](./project/PROJECT_BRIEF.md) - Overview and current status
2. [MVP_Install.md](./guides/MVP_Install.md) - Installation instructions
3. [Arc_Prompts.md](./guides/Arc_Prompts.md) - Journaling guidance

### For Contributors
1. [STATUS.md](./status/STATUS.md) - Current project state
2. [CHANGELOG.md](./changelog/CHANGELOG.md) - Version history
3. [Bug_Tracker.md](./bugtracker/Bug_Tracker.md) - Known issues and resolutions
4. [EPI_Architecture.md](./architecture/EPI_Architecture.md) - System architecture

## 🔧 Technical Documentation

### MIRA Basics System
- **Quick Answers**: [MIRA_Basics.md](./architecture/MIRA_Basics.md)
- **MMCO Building**: Minimal MIRA Context Object construction
- **Phase Detection**: Automatic phase determination from history
- **Streak Tracking**: Daily journaling streak computation
- **Performance**: 300-500x faster than LLM for common queries

### On-Device LLM System
- **llama.cpp Integration**: [EPI_Architecture.md](./architecture/EPI_Architecture.md#on-device-llm-architecture)
- **Model Download**: [Model_Download_System.md](./guides/Model_Download_System.md)
- **Metal Acceleration**: Lines 13-51 in EPI_Architecture.md
- **Model Management**: Lines 138-175 in EPI_Architecture.md
- **Provider Selection**: Lines 176-206 in EPI_Architecture.md

### Constellation Visualization
- **Complete System**: [Constellation_Arcform_Renderer.md](./architecture/Constellation_Arcform_Renderer.md)
- **Polar Layout Algorithm**: Phase-specific coordinate generation
- **k-NN Edge Weaving**: Graph-based connection system
- **Animation System**: Three independent controllers (twinkle, fade-in, selection pulse)
- **ATLAS Phase Integration**: 6 phases with geometric mapping (spiral, flower, weave, glow core, fractal, branch)
- **Emotion Palette**: 8-color emotional visualization system

### Multimodal MCP System
- **Expansion Plan**: [MCP_Multimodal_Expansion_Status.md](./project/MCP_Multimodal_Expansion_Status.md)
- **Chat Message Enhancement**: Adding multimodal attachments support
- **MCP Export/Import**: Handling images, audio, video in bundles
- **llama.cpp Integration**: Multimodal model support

### Privacy Architecture
- **On-Device Processing**: All inference happens locally
- **PII Detection**: Automatic redaction of sensitive data
- **Privacy Guardrails**: Module-specific privacy adaptations
- **MCP Export**: Privacy-preserving data export

## 📞 Support

- **Issues**: Check [Bug_Tracker.md](./bugtracker/Bug_Tracker.md) for known issues
- **Status**: See [STATUS.md](./status/STATUS.md) for current project state
- **Updates**: Follow [CHANGELOG.md](./changelog/CHANGELOG.md) for version history

---

**Project**: EPI (Evolving Personal Intelligence)
**Framework**: Flutter (Cross-platform iOS/Android)
**Architecture**: 8-Module System with On-Device AI
**Status**: Production Ready ✅
