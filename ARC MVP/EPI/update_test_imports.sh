#!/bin/bash

# EPI Modular Architecture Test Import Update Script
# This script updates test files to use the new modular structure

echo "🧪 Updating test files for EPI modular architecture..."

# Update journal-related test imports
echo "📝 Updating journal test imports..."
find test -name "*.dart" -exec sed -i '' 's|package:my_app/features/journal/|package:my_app/arc/core/|g' {} \;
find test -name "*.dart" -exec sed -i '' 's|package:my_app/repositories/journal_repository|package:my_app/arc/core/journal_repository|g' {} \;
find test -name "*.dart" -exec sed -i '' 's|package:my_app/models/journal_entry_model|package:my_app/arc/models/journal_entry_model|g' {} \;

# Update RIVET/ATLAS test imports
echo "🎯 Updating RIVET/ATLAS test imports..."
find test -name "*.dart" -exec sed -i '' 's|package:my_app/core/rivet/|package:my_app/atlas/rivet/|g' {} \;
find test -name "*.dart" -exec sed -i '' 's|package:my_app/features/atlas/|package:my_app/atlas/phase_detection/|g' {} \;

# Update insights test imports
echo "🔍 Updating insights test imports..."
find test -name "*.dart" -exec sed -i '' 's|package:my_app/features/insights/|package:my_app/atlas/phase_detection/|g' {} \;

# Update MCP test imports
echo "📦 Updating MCP test imports..."
find test -name "*.dart" -exec sed -i '' 's|package:my_app/mcp/|package:my_app/prism/mcp/|g' {} \;

# Update media test imports
echo "🎨 Updating media test imports..."
find test -name "*.dart" -exec sed -i '' 's|package:my_app/media/|package:my_app/prism/processors/|g' {} \;

# Update keyword extraction test imports
echo "🔤 Updating keyword extraction test imports..."
find test -name "*.dart" -exec sed -i '' 's|package:my_app/features/keyword_extraction/|package:my_app/prism/extractors/|g' {} \;

# Update privacy test imports
echo "🔐 Updating privacy test imports..."
find test -name "*.dart" -exec sed -i '' 's|package:my_app/services/privacy/|package:my_app/privacy_core/|g' {} \;
find test -name "*.dart" -exec sed -i '' 's|package:my_app/features/privacy/|package:my_app/arc/privacy/|g' {} \;

# Update relative imports in test files
echo "🔄 Updating relative imports in test files..."
find test -name "*.dart" -exec sed -i '' 's|../lib/features/journal/|../lib/arc/core/|g' {} \;
find test -name "*.dart" -exec sed -i '' 's|../lib/core/rivet/|../lib/atlas/rivet/|g' {} \;
find test -name "*.dart" -exec sed -i '' 's|../lib/features/atlas/|../lib/atlas/phase_detection/|g' {} \;
find test -name "*.dart" -exec sed -i '' 's|../lib/features/insights/|../lib/atlas/phase_detection/|g' {} \;
find test -name "*.dart" -exec sed -i '' 's|../lib/mcp/|../lib/prism/mcp/|g' {} \;
find test -name "*.dart" -exec sed -i '' 's|../lib/media/|../lib/prism/processors/|g' {} \;
find test -name "*.dart" -exec sed -i '' 's|../lib/features/keyword_extraction/|../lib/prism/extractors/|g' {} \;
find test -name "*.dart" -exec sed -i '' 's|../lib/services/privacy/|../lib/privacy_core/|g' {} \;
find test -name "*.dart" -exec sed -i '' 's|../lib/features/privacy/|../lib/arc/privacy/|g' {} \;

# Update deeper relative imports
echo "🔄 Updating deeper relative imports..."
find test -name "*.dart" -exec sed -i '' 's|../../lib/features/journal/|../../lib/arc/core/|g' {} \;
find test -name "*.dart" -exec sed -i '' 's|../../lib/core/rivet/|../../lib/atlas/rivet/|g' {} \;
find test -name "*.dart" -exec sed -i '' 's|../../lib/features/atlas/|../../lib/atlas/phase_detection/|g' {} \;
find test -name "*.dart" -exec sed -i '' 's|../../lib/features/insights/|../../lib/atlas/phase_detection/|g' {} \;
find test -name "*.dart" -exec sed -i '' 's|../../lib/mcp/|../../lib/prism/mcp/|g' {} \;
find test -name "*.dart" -exec sed -i '' 's|../../lib/media/|../../lib/prism/processors/|g' {} \;
find test -name "*.dart" -exec sed -i '' 's|../../lib/features/keyword_extraction/|../../lib/prism/extractors/|g' {} \;
find test -name "*.dart" -exec sed -i '' 's|../../lib/services/privacy/|../../lib/privacy_core/|g' {} \;
find test -name "*.dart" -exec sed -i '' 's|../../lib/features/privacy/|../../lib/arc/privacy/|g' {} \;

echo "✅ Test import updates completed!"
echo "🔍 Checking for remaining test import issues..."

# Check for remaining old patterns in test files
echo "Remaining journal imports in tests:"
grep -r "features/journal" test --include="*.dart" | head -3

echo "Remaining RIVET imports in tests:"
grep -r "core/rivet" test --include="*.dart" | head -3

echo "Remaining MCP imports in tests:"
grep -r "import.*mcp/" test --include="*.dart" | head -3

echo "🎉 Test import update script completed!"
