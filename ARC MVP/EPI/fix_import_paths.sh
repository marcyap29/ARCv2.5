#!/bin/bash

# Fix incorrect import paths across the codebase
echo "🔧 Fixing import paths..."

# Fix JournalEntry import paths
find lib -name "*.dart" -type f -exec sed -i '' 's|package:my_app/arc/models/journal_entry_model.dart|package:my_app/models/journal_entry_model.dart|g' {} \;

# Fix other common import path issues
find lib -name "*.dart" -type f -exec sed -i '' 's|package:my_app/atlas/rivet/|package:my_app/rivet/validation/|g' {} \;

echo "✅ Import path fixes completed!"
