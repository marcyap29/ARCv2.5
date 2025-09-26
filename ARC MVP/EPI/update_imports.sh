#!/bin/bash

# EPI Modular Architecture Import Update Script
# This script updates import paths to match the new modular structure

echo "🔄 Updating import paths for EPI modular architecture..."

# Update journal-related imports
echo "📝 Updating journal imports..."
find lib -name "*.dart" -exec sed -i '' 's|package:my_app/features/journal/|package:my_app/arc/core/|g' {} \;
find lib -name "*.dart" -exec sed -i '' 's|package:my_app/repositories/journal_repository|package:my_app/arc/core/journal_repository|g' {} \;
find lib -name "*.dart" -exec sed -i '' 's|package:my_app/models/journal_entry_model|package:my_app/arc/models/journal_entry_model|g' {} \;

# Update RIVET/ATLAS imports
echo "🎯 Updating RIVET/ATLAS imports..."
find lib -name "*.dart" -exec sed -i '' 's|package:my_app/core/rivet/|package:my_app/atlas/rivet/|g' {} \;
find lib -name "*.dart" -exec sed -i '' 's|package:my_app/features/atlas/|package:my_app/atlas/phase_detection/|g' {} \;

# Update insights imports
echo "🔍 Updating insights imports..."
find lib -name "*.dart" -exec sed -i '' 's|package:my_app/features/insights/|package:my_app/atlas/phase_detection/|g' {} \;

# Update MCP imports
echo "📦 Updating MCP imports..."
find lib -name "*.dart" -exec sed -i '' 's|package:my_app/mcp/|package:my_app/prism/mcp/|g' {} \;

# Update media imports
echo "🎨 Updating media imports..."
find lib -name "*.dart" -exec sed -i '' 's|package:my_app/media/|package:my_app/prism/processors/|g' {} \;

# Update keyword extraction imports
echo "🔤 Updating keyword extraction imports..."
find lib -name "*.dart" -exec sed -i '' 's|package:my_app/features/keyword_extraction/|package:my_app/prism/extractors/|g' {} \;

# Update privacy imports
echo "🔐 Updating privacy imports..."
find lib -name "*.dart" -exec sed -i '' 's|package:my_app/services/privacy/|package:my_app/privacy_core/|g' {} \;
find lib -name "*.dart" -exec sed -i '' 's|package:my_app/features/privacy/|package:my_app/arc/privacy/|g' {} \;

echo "✅ Import path updates completed!"
echo "🔍 Checking for any remaining old import patterns..."

# Check for any remaining old patterns
echo "Remaining journal imports:"
grep -r "features/journal" lib --include="*.dart" | head -5

echo "Remaining RIVET imports:"
grep -r "core/rivet" lib --include="*.dart" | head -5

echo "Remaining MCP imports:"
grep -r "import.*mcp/" lib --include="*.dart" | head -5

echo "🎉 Import update script completed!"
