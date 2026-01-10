# EPI MVP - Evolving Personal Intelligence

**Version:** 3.1
**Last Updated:** January 9, 2026
**Status:** ✅ Production Ready with Enhanced Privacy System

---

## Overview

EPI (Evolving Personal Intelligence) is a sophisticated Flutter-based personal intelligence application that combines journaling, AI-powered reflection, phase tracking, and voice interaction into a comprehensive personal development ecosystem. Built with privacy-first architecture, EPI provides intelligent insights while maintaining complete user data sovereignty.

---

## Key Features

### 🤖 LUMARA AI Assistant
- **Intelligent Classification System (v2.1.85)**: Automatically classifies entry types for optimal response generation
- **Enhanced Privacy Processing (v2.1.86)**: Classification-aware PRISM system preserves semantic content for technical questions while maintaining full privacy for personal entries
- **Companion-First Persona Selection (v3.0)**: Personal reflections default to warm, conversational Companion mode with enforced word limits and pattern recognition
- **User Prompt System (v3.0)**: User prompts now reinforce master prompt constraints, ensuring word limits, dated examples, and banned phrases are properly enforced
- **Persona-Based Responses**: 4 adaptive personas (Companion, Strategist, Challenger, Therapist) based on context and user state
- **Health-Integrated Responses**: Sleep quality and energy levels influence AI interaction style
- **Voice Chat Mode**: Full duplex voice conversations with push-to-talk and hands-free modes
- **On-Device Processing**: All personal data remains local with cloud API proxy for model access

### 📝 Advanced Journaling
- **Multimodal Entries**: Text, voice recordings, photos, health data integration
- **Smart Categorization**: Automatic tagging and organization
- **Phase-Aware Context**: Entries linked to detected life phases and emotional states
- **Real-Time Analytics**: Keyword extraction, sentiment analysis, pattern recognition

### 🌊 Phase Detection (RIVET System)
- **Automatic Life Phase Detection**: AI-powered analysis of journal patterns
- **Adaptive Configuration (v3.1)**: Automatically adjusts RIVET parameters based on user journaling cadence (power user, frequent, weekly, sporadic)
- **Interactive 3D Visualization**: ARCForm spherical representations of emotional states
- **Timeline Navigation**: Explore life phases with entry-level granularity
- **Phase Regime Tracking**: 10-day rolling windows for trend analysis

### 🔒 Privacy Protection (PRISM System)
- **Classification-Aware Privacy (v2.1.86)**: Enhanced semantic summarization system
  - Technical/factual content: Preserves semantic meaning after PII scrubbing
  - Personal/emotional content: Full correlation-resistant transformation
  - On-device processing for maximum privacy protection
- **PII Scrubbing**: Automatic removal of personally identifiable information
- **Correlation-Resistant Transformation**: Advanced privacy techniques for cloud processing
- **Local Data Sovereignty**: All personal data stored locally on device

### 🎯 Adaptive Framework (v3.1)
- **User Cadence Detection**: Automatically detects journaling patterns (daily, weekly, sporadic)
- **Adaptive RIVET**: Phase detection parameters adjust to user cadence
- **Adaptive Sentinel**: Emotional density calculation adapts to writing style and frequency
- **Smooth Transitions**: Configuration changes gradually over 5 entries to prevent sudden shifts
- **Psychological Time**: Algorithms measure in journal entries, not calendar days

### 🎯 Health Integration
- **HealthKit Integration**: Sleep quality, energy levels, activity data
- **Health-Aware AI**: LUMARA responses adapt to physical and mental state
- **Holistic Wellness Tracking**: Journal entries enriched with health context
- **Privacy-First Health Data**: All health information processed locally

### 📊 Analytics & Insights
- **Advanced Analytics**: Pattern recognition across multiple data dimensions
- **Keyword Analysis**: Automatic extraction and trending
- **Sentiment Tracking**: Emotional pattern analysis over time
- **Export Capabilities**: ARCX and ZIP formats with comprehensive data preservation

### 🔐 Authentication & Subscription
- **Firebase Authentication**: Anonymous, Google, and email/password options
- **Enhanced Google Sign-in (v2.1.89)**: Robust authentication for subscription access
- **Tiered Access System**: Free tier with upgrade options
- **Stripe Integration**: Secure payment processing with improved authentication flow
- **Rate Limiting**: Per-entry and per-chat usage controls

---

## Technical Architecture

### Core Modules
- **ARC**: Adaptive Reflective Computing - Core journaling and reflection engine
- **PRISM**: Privacy-preserving processing with classification-aware semantics
- **MIRA**: Memory and Intelligence Reasoning Architecture - Data persistence and analytics
- **ECHO**: Event-driven Communication Hub - Real-time processing and notifications
- **AURORA**: Advanced User-interface and Responsive Operations - UI/UX layer

### Technology Stack
- **Frontend**: Flutter (iOS/Android)
- **Backend**: Firebase Cloud Functions
- **Database**: Hive (local) + Firebase Firestore (metadata)
- **AI Models**: Google Gemini Pro via secure proxy
- **Authentication**: Firebase Auth
- **Payments**: Stripe
- **Voice**: Flutter Sound + Speech Recognition
- **Health**: HealthKit (iOS) integration

### Privacy Architecture
- **On-Device Processing**: All personal data analysis happens locally
- **Cloud API Proxy**: Secure Firebase functions protect API keys
- **Classification-Aware PRISM**: Intelligent privacy processing based on content type
- **PII Protection**: Automatic scrubbing of personally identifiable information
- **Local Storage**: Hive database for complete data sovereignty

---

## Recent Enhancements (v2.1.86)

### PRISM Privacy System Enhancement
- **Enhanced Semantic Summarization**: Technical content detection for mathematics, physics, computer science, engineering
- **Classification-Aware Processing**: Different privacy strategies based on content type
- **Improved Context Preservation**: Technical questions maintain semantic meaning while personal entries get full privacy protection
- **On-Device Intelligence**: Enhanced pattern recognition without compromising privacy

### LUMARA Classification System (v2.1.85)
- **Entry Type Classification**: 5 types (Factual, Reflective, Analytical, Conversational, Meta-Analysis)
- **Response Optimization**: Appropriate response lengths and styles for each entry type
- **Transparent Processing**: Classification happens in background without UI changes
- **Context Preservation**: Technical questions receive direct answers, personal entries get full reflection

---

## Getting Started

### Prerequisites
- Flutter SDK 3.x
- iOS 14+ / Android API 21+
- Firebase project with authentication enabled
- Gemini API access for AI features

### Installation

1. **Clone Repository**
   ```bash
   git clone [repository-url]
   cd "ARC MVP/EPI"
   ```

2. **Install Dependencies**
   ```bash
   flutter pub get
   ```

3. **Configure Firebase**
   - Add `GoogleService-Info.plist` (iOS) and `google-services.json` (Android)
   - Set up Firebase Authentication and Cloud Functions

4. **Deploy Cloud Functions**
   ```bash
   cd functions
   npm install
   npm run deploy
   ```

5. **Run Application**
   ```bash
   flutter run
   ```

---

## Documentation

### Core Documentation
- **[Architecture Guide](docs/ARCHITECTURE.md)** - System design and module interactions
- **[Features Documentation](docs/FEATURES.md)** - Comprehensive feature list
- **[Backend Setup](docs/backend.md)** - Firebase configuration and deployment
- **[UI/UX Guide](docs/UI_UX.md)** - Interface patterns and user experience
- **[Changelog](docs/CHANGELOG.md)** - Version history and updates

### Development Resources
- **[Bug Tracker](docs/bugtracker/)** - Known issues and resolutions
- **[Git History](docs/git.md)** - Commit history and branch management
- **[Voice Mode Guide](docs/VOICE_MODE_USER_GUIDE.md)** - Voice interaction documentation

---

## Privacy & Security

### Data Protection
- **Local Processing**: All personal data analysis happens on-device
- **PII Scrubbing**: Automatic removal of sensitive information
- **Correlation-Resistant Transformation**: Advanced privacy techniques for necessary cloud operations
- **Classification-Aware Privacy**: Technical content preserves semantics, personal content gets full protection
- **No Data Collection**: App doesn't collect, store, or transmit personal information to third parties

### Security Features
- **Firebase Authentication**: Industry-standard authentication with multiple providers
- **API Key Protection**: All API keys secured in Firebase Cloud Functions
- **Local Encryption**: Device-level encryption for all stored data
- **Rate Limiting**: Protection against abuse and excessive usage

---

## Support & Contributing

### Getting Help
- Review [documentation](docs/) for setup and usage guides
- Check [bug tracker](docs/bugtracker/) for known issues
- Submit issues via GitHub

### Privacy Notice
EPI is designed with privacy-first principles. All personal data remains on your device, with only anonymized, processed summaries used for AI interactions when necessary. For more details, see our [Privacy Architecture](docs/backend.md#privacy-protection).

---

## License

Copyright 2025-2026 EPI Development Team. All rights reserved.

---

*Last Updated: January 7, 2026 | Version: 2.1.86*