# EPI MVP - Update Log

**Version:** 1.0.4  
**Last Updated:** January 2025

---

## Update History

### Version 2.1.22 (January 2025)

#### Enhanced Phase Transition Guidance
- ✅ Added specific 99% messaging - users now see exactly what's missing when very close
- ✅ Improved plain language explanations - replaced technical terms with clear, actionable guidance
- ✅ Context-aware messages - different guidance based on which requirement is close
- ✅ Visual enhancements - amber theme and celebration icons when 95%+ ready
- ✅ Current state visibility - shows exact percentages and gaps
- ✅ Actionable tips - specific suggestions for what to write about

### Version 2.1.21 (January 2025)

#### Phase Regime Import Fix
- ✅ Fixed import order - Phase regimes now imported BEFORE entries
- ✅ Fixed service instance usage - Entry conversion uses existing service with imported regimes
- ✅ Added service re-initialization after importing regimes to refresh PhaseIndex
- ✅ Entries from ARCX files now correctly tagged based on imported phase regimes
- ✅ Resolved issue where entries defaulted to "Discovery" instead of correct phase

### Version 2.1.20 (January 2025)

#### Automatic Phase Hashtag System
- ✅ Phase hashtags now automatically added based on Phase Regimes (date-based system)
- ✅ No manual tagging required - users no longer need to type `#phase` hashtags
- ✅ Phase changes happen at regime level, not per-entry, preventing oscillation
- ✅ Imported entries from ARCX files automatically receive phase hashtags
- ✅ Entry colors automatically update when phase hashtags change
- ✅ Phase Legend enhanced with "NO PHASE" indicator for entries without hashtags
- ✅ Phase change integration - when regimes change, all affected entries' hashtags update automatically

### Version 2.1.19 (November 2025)

#### Journal Timeline & ARCForm UX Refresh
- ✅ Phase-colored rail now opens a full-height ARCForm preview by collapsing the top chrome (Timeline | LUMARA | Settings + search/filter row).
- ✅ Phase legend dropdown mounts only when the ARCForm preview is visible, bringing context on demand instead of clutter.
- ✅ Added swipe and tap affordances plus “ARC ✨” hint on the rail to signal interactivity.
- ✅ Docs updated across architecture, status, bug tracker, guides, and reports to describe the new flow.

### Version 2.1.17 (January 2025)

#### Voiceover Mode & Favorites UI Improvements
- ✅ Voiceover mode toggle in Settings → LUMARA section
- ✅ Automatic TTS for AI responses when voiceover enabled
- ✅ Voiceover icon (volume_up) in chat and journal responses for manual playback
- ✅ Text cleaning (markdown removal) before speech
- ✅ Removed long-press menu for favorites (simplified to star icon only)
- ✅ Reduced favorites title font to 24px
- ✅ Added explainer text above favorites count
- ✅ Added + button for manually adding favorites
- ✅ Confirmed LUMARA Favorites export/import in MCP bundles

### Version 2.1.16 (January 2025)

#### LUMARA Favorites Style System
- ✅ Favorites system for style adaptation (up to 25 favorites)
- ✅ Star icon on all LUMARA answers (chat and journal)
- ✅ Long-press menu for quick access
- ✅ Settings integration with management screen
- ✅ Capacity management with popup and navigation
- ✅ First-time snackbar with explanation
- ✅ Prompt integration (3-7 examples per turn)
- ✅ Style adaptation rules preserve SAGE/Echo structure

#### Bug Fixes
- ✅ Journal tab bar text cutoff fixed (added padding, increased height)

### Version 2.1.9 (January 2025)

#### LUMARA Memory Attribution & Weighted Context
- ✅ Specific attribution excerpts showing exact 2-3 sentences from memory entries
- ✅ Context-based attribution from memory nodes actually used
- ✅ Three-tier weighted context prioritization (current entry → recent responses → other entries)
- ✅ Draft entry support for unsaved content
- ✅ Journal integration with attribution display

#### PRISM Data Scrubbing & Restoration
- ✅ Comprehensive PII scrubbing before cloud API calls
- ✅ Reversible restoration of PII in responses
- ✅ Dart/Flutter and iOS parity

### Version 1.0.0 (January 2025)

#### Major Updates

**Architecture Consolidation**
- ✅ Consolidated from 8+ modules to 5 clean modules
- ✅ ARC: Journaling, chat (LUMARA), arcform visualization
- ✅ PRISM: Multimodal perception with ATLAS integration
- ✅ POLYMETA: Memory graph with MCP and ARCX
- ✅ AURORA: Circadian orchestration with VEIL
- ✅ ECHO: Response control with safety and privacy

**LUMARA v2.0 Multimodal Reflective Engine**
- ✅ Transformed from placeholder responses to true multimodal reflective partner
- ✅ ReflectiveNode models with semantic similarity engine
- ✅ Phase-aware prompts with MCP bundle integration
- ✅ Visual distinction with sparkle icons
- ✅ Comprehensive settings interface

**On-Device AI Integration**
- ✅ Qwen 2.5 1.5B Instruct model integration
- ✅ llama.cpp XCFramework with Metal acceleration
- ✅ Native Swift bridge for on-device inference
- ✅ Visual status indicators in LUMARA Settings

**MCP Export/Import System**
- ✅ Ultra-simplified single-file format (.zip only)
- ✅ Direct photo handling with standardized manifest
- ✅ Legacy cleanup (2,816 lines removed)
- ✅ Timeline refresh fix after import

**Phase Detection & Analysis**
- ✅ Real-time Phase Detector Service
- ✅ Enhanced ARCForm 3D visualizations
- ✅ RIVET Sweep integration
- ✅ SENTINEL risk monitoring
- ✅ Phase timeline UI

**Bug Fixes**
- ✅ ARCX import date preservation
- ✅ Timeline infinite rebuild loop
- ✅ Hive initialization order
- ✅ Photo duplication in view entry
- ✅ MediaItem adapter registration
- ✅ Draft creation when viewing entries
- ✅ Timeline ordering and timestamp fixes
- ✅ Comprehensive app hardening

---

### Version 0.2.6-alpha (September 2025)

**LUMARA MCP Memory System**
- ✅ Automatic chat persistence
- ✅ Memory Container Protocol implementation
- ✅ Cross-session continuity
- ✅ Rolling summaries every 10 messages
- ✅ Memory commands (/memory show, forget, export)
- ✅ Privacy protection with PII redaction

**Repository Hygiene**
- ✅ Clean Git workflow
- ✅ MIRA-MCP architecture alignment
- ✅ Insights system fixes

---

### Version 0.2.5-alpha (September 2025)

**MCP Integration**
- ✅ Memory Container Protocol v1
- ✅ Standards-compliant export/import
- ✅ Bidirectional data portability

---

### Version 0.2.4-alpha (August 2025)

**Initial MVP Release**
- ✅ Core journaling functionality
- ✅ Basic AI integration
- ✅ Timeline and insights
- ✅ Initial architecture

---

## Update Categories

### Architecture Updates
- Module consolidation
- Import path updates
- Directory structure changes

### Feature Updates
- New features and capabilities
- Enhanced existing features
- UI/UX improvements

### Bug Fixes
- Critical bug resolutions
- Performance improvements
- Stability enhancements

### Documentation Updates
- Architecture documentation
- User guides
- Developer documentation

---

## Future Updates

### Planned for Next Version
- Vision-language model integration
- Advanced analytics features
- Additional on-device models
- Enhanced constellation geometry
- Performance optimizations

---

**Last Updated:** November 17, 2025  
**Version:** 1.0.1

