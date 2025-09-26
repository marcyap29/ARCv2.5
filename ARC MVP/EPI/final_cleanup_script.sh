#!/bin/bash

# EPI Modular Architecture - Final Cleanup Script
# Software Architect Review & Resolution

echo "🔧 EPI Final Cleanup - Software Architect Review"
echo "Current Status: 213 errors, 2,446 total issues"
echo "Target: <50 errors for production-ready system"
echo ""

# 1. Fix remaining import path issues
echo "📁 Fixing import path issues..."
find lib -name "*.dart" -exec sed -i '' 's|../mira/core/|../../mira/core/|g' {} \;
find lib -name "*.dart" -exec sed -i '' 's|../atlas/|../../atlas/|g' {} \;
find lib -name "*.dart" -exec sed -i '' 's|../arc/|../../arc/|g' {} \;
find lib -name "*.dart" -exec sed -i '' 's|../prism/|../../prism/|g' {} \;

# 2. Fix relative import depth issues
echo "🔄 Fixing relative import depth..."
find lib -name "*.dart" -exec sed -i '' 's|../../mira/core/|../../../mira/core/|g' {} \;
find lib -name "*.dart" -exec sed -i '' 's|../../atlas/|../../../atlas/|g' {} \;
find lib -name "*.dart" -exec sed -i '' 's|../../arc/|../../../arc/|g' {} \;
find lib -name "*.dart" -exec sed -i '' 's|../../prism/|../../../prism/|g' {} \;

# 3. Clean up duplicate model references
echo "🧹 Cleaning up duplicate models..."
find lib -name "*.dart" -exec sed -i '' 's|models/journal_entry_model|arc/models/journal_entry_model|g' {} \;
find lib -name "*.dart" -exec sed -i '' 's|repositories/journal_repository|arc/core/journal_repository|g' {} \;

# 4. Fix package import consistency
echo "📦 Fixing package imports..."
find lib -name "*.dart" -exec sed -i '' 's|package:my_app/arc/arc/|package:my_app/arc/|g' {} \;
find lib -name "*.dart" -exec sed -i '' 's|package:my_app/atlas/atlas/|package:my_app/atlas/|g' {} \;
find lib -name "*.dart" -exec sed -i '' 's|package:my_app/prism/prism/|package:my_app/prism/|g' {} \;

# 5. Remove old unused directories
echo "🗑️ Removing old unused directories..."
rm -rf lib/old_models/ 2>/dev/null || true
rm -rf lib/old_repositories/ 2>/dev/null || true
rm -rf lib/old_services/ 2>/dev/null || true

# 6. Fix common type issues
echo "🔧 Fixing common type issues..."
find lib -name "*.dart" -exec sed -i '' 's|List<JournalEntry>|List<JournalEntry>|g' {} \;
find lib -name "*.dart" -exec sed -i '' 's|JournalRepository\?|JournalRepository|g' {} \;

echo "✅ Final cleanup completed!"
echo "🔍 Running analysis..."

# Run analysis to check progress
flutter analyze --no-fatal-infos | grep -E "error" | wc -l | xargs -I {} echo "Errors remaining: {}"
flutter analyze --no-fatal-infos | grep -E "(error|warning)" | wc -l | xargs -I {} echo "Total issues: {}"

echo "🎯 Cleanup script completed!"
