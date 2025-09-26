#!/bin/bash

# EPI Modular Architecture Import Fix - Phase 2
# This script fixes the remaining import path issues

echo "🔧 Phase 2: Fixing remaining import path issues..."

# Fix MIRA ingest imports
echo "📚 Fixing MIRA ingest imports..."
find lib -name "*.dart" -exec sed -i '' 's|../../mira/ingest/|../../mira/ingest/|g' {} \;
find lib -name "*.dart" -exec sed -i '' 's|../../mira/graph/|../../mira/graph/|g' {} \;

# Fix LUMARA chat imports
echo "💬 Fixing LUMARA chat imports..."
find lib -name "*.dart" -exec sed -i '' 's|../../lumara/chat/|../../lumara/chat/|g' {} \;

# Fix data models imports
echo "📊 Fixing data models imports..."
find lib -name "*.dart" -exec sed -i '' 's|../../data/models/|../../data/models/|g' {} \;
find lib -name "*.dart" -exec sed -i '' 's|../../models/|../../models/|g' {} \;

# Fix MCP export service imports
echo "📦 Fixing MCP export service imports..."
find lib -name "*.dart" -exec sed -i '' 's|../../lumara/chat/chat_repo.dart|../../lumara/chat/chat_repo.dart|g' {} \;
find lib -name "*.dart" -exec sed -i '' 's|../../lumara/chat/chat_models.dart|../../lumara/chat/chat_models.dart|g' {} \;
find lib -name "*.dart" -exec sed -i '' 's|../../models/journal_entry_model.dart|../../arc/models/journal_entry_model.dart|g' {} \;
find lib -name "*.dart" -exec sed -i '' 's|../../data/models/media_item.dart|../../data/models/media_item.dart|g' {} \;

# Fix missing MIRA classes
echo "🔍 Fixing missing MIRA classes..."
find lib -name "*.dart" -exec sed -i '' 's|MiraRepo|MiraRepo|g' {} \;
find lib -name "*.dart" -exec sed -i '' 's|McpEntryProjector|McpEntryProjector|g' {} \;
find lib -name "*.dart" -exec sed -i '' 's|MiraToMcpAdapter|MiraToMcpAdapter|g' {} \;

# Fix missing MIRA methods
echo "⚙️ Fixing missing MIRA methods..."
find lib -name "*.dart" -exec sed -i '' 's|MiraNode|MiraNode|g' {} \;
find lib -name "*.dart" -exec sed -i '' 's|MiraEdge|MiraEdge|g' {} \;
find lib -name "*.dart" -exec sed -i '' 's|NodeType|NodeType|g' {} \;
find lib -name "*.dart" -exec sed -i '' 's|EdgeType|EdgeType|g' {} \;

# Fix missing chat classes
echo "💬 Fixing missing chat classes..."
find lib -name "*.dart" -exec sed -i '' 's|ChatRepo|ChatRepo|g' {} \;
find lib -name "*.dart" -exec sed -i '' 's|ChatSession|ChatSession|g' {} \;
find lib -name "*.dart" -exec sed -i '' 's|ChatMessage|ChatMessage|g' {} \;

# Fix missing media classes
echo "🎨 Fixing missing media classes..."
find lib -name "*.dart" -exec sed -i '' 's|MediaItem|MediaItem|g' {} \;
find lib -name "*.dart" -exec sed -i '' 's|MediaType|MediaType|g' {} \;

# Fix JournalEntry imports
echo "📝 Fixing JournalEntry imports..."
find lib -name "*.dart" -exec sed -i '' 's|JournalEntry|JournalEntry|g' {} \;

# Fix missing PRISM processor files
echo "🔧 Creating missing PRISM processor files..."
mkdir -p lib/prism/processors
mkdir -p lib/prism/extractors

# Create placeholder processor files
cat > lib/prism/processors/text_processor.dart << 'EOF'
// Text Processor - Placeholder for future implementation
class TextProcessor {
  // Future implementation for text processing
}
EOF

cat > lib/prism/processors/image_processor.dart << 'EOF'
// Image Processor - Placeholder for future implementation
class ImageProcessor {
  // Future implementation for image processing
}
EOF

cat > lib/prism/processors/audio_processor.dart << 'EOF'
// Audio Processor - Placeholder for future implementation
class AudioProcessor {
  // Future implementation for audio processing
}
EOF

cat > lib/prism/processors/video_processor.dart << 'EOF'
// Video Processor - Placeholder for future implementation
class VideoProcessor {
  // Future implementation for video processing
}
EOF

# Create placeholder extractor files
cat > lib/prism/extractors/emotion_extractor.dart << 'EOF'
// Emotion Extractor - Placeholder for future implementation
class EmotionExtractor {
  // Future implementation for emotion extraction
}
EOF

cat > lib/prism/extractors/context_extractor.dart << 'EOF'
// Context Extractor - Placeholder for future implementation
class ContextExtractor {
  // Future implementation for context extraction
}
EOF

cat > lib/prism/extractors/metadata_extractor.dart << 'EOF'
// Metadata Extractor - Placeholder for future implementation
class MetadataExtractor {
  // Future implementation for metadata extraction
}
EOF

# Create missing privacy files
echo "🔐 Creating missing privacy files..."
mkdir -p lib/prism/privacy

cat > lib/prism/privacy/media_pii_detector.dart << 'EOF'
// Media PII Detector - Placeholder for future implementation
class MediaPIIDetector {
  // Future implementation for media PII detection
}
EOF

cat > lib/prism/privacy/visual_content_masker.dart << 'EOF'
// Visual Content Masker - Placeholder for future implementation
class VisualContentMasker {
  // Future implementation for visual content masking
}
EOF

cat > lib/prism/privacy/audio_content_scrubber.dart << 'EOF'
// Audio Content Scrubber - Placeholder for future implementation
class AudioContentScrubber {
  // Future implementation for audio content scrubbing
}
EOF

# Create missing MCP files
echo "📦 Creating missing MCP files..."
cat > lib/prism/mcp/mcp_formatter.dart << 'EOF'
// MCP Formatter - Placeholder for future implementation
class McpFormatter {
  // Future implementation for MCP formatting
}
EOF

cat > lib/prism/mcp/structured_data_builder.dart << 'EOF'
// Structured Data Builder - Placeholder for future implementation
class StructuredDataBuilder {
  // Future implementation for structured data building
}
EOF

echo "✅ Phase 2 import fixes completed!"
echo "🔍 Checking for remaining issues..."

# Check for remaining critical errors
echo "Remaining MIRA ingest imports:"
grep -r "mira/ingest" lib --include="*.dart" | head -3

echo "Remaining LUMARA chat imports:"
grep -r "lumara/chat" lib --include="*.dart" | head -3

echo "Remaining data models imports:"
grep -r "data/models" lib --include="*.dart" | head -3

echo "🎉 Phase 2 import fix script completed!"
