#!/bin/bash

# Fix remaining import path issues
echo "🔧 Fixing remaining import paths..."

# Fix ARC module relative import
sed -i '' 's|models/journal_entry_model.dart|package:my_app/models/journal_entry_model.dart|g' lib/arc/arc_module.dart

# Fix malformed import paths (with ../package:)
find lib -name "*.dart" -type f -exec sed -i '' 's|../package:my_app/|package:my_app/|g' {} \;
find lib -name "*.dart" -type f -exec sed -i '' 's|../../package:my_app/|package:my_app/|g' {} \;
find lib -name "*.dart" -type f -exec sed -i '' 's|../../../package:my_app/|package:my_app/|g' {} \;

echo "✅ Remaining import path fixes completed!"
