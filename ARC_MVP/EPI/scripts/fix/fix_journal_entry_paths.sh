#!/bin/bash

# Fix remaining JournalEntry import paths
echo "🔧 Fixing JournalEntry import paths..."

# Fix incorrect JournalEntry import paths
find lib -name "*.dart" -type f -exec sed -i '' 's|../arc/models/journal_entry_model.dart|package:my_app/models/journal_entry_model.dart|g' {} \;
find lib -name "*.dart" -type f -exec sed -i '' 's|../../arc/models/journal_entry_model.dart|package:my_app/models/journal_entry_model.dart|g' {} \;
find lib -name "*.dart" -type f -exec sed -i '' 's|../../../arc/models/journal_entry_model.dart|package:my_app/models/journal_entry_model.dart|g' {} \;
find lib -name "*.dart" -type f -exec sed -i '' 's|../../../../arc/models/journal_entry_model.dart|package:my_app/models/journal_entry_model.dart|g' {} \;

echo "✅ JournalEntry import path fixes completed!"
