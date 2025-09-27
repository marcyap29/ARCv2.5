#!/bin/bash

# Fix JournalEntry import issues across the codebase
# This script adds the missing JournalEntry import to files that need it

echo "🔧 Fixing JournalEntry import issues..."

# Files that need JournalEntry import added
files=(
    "lib/features/journal/journal_capture_cubit.dart"
    "lib/arc/core/journal_capture_cubit.dart"
    "lib/services/arcform_service.dart"
    "lib/insights/insight_service.dart"
    "lib/features/onboarding/onboarding_cubit.dart"
    "lib/mira/mira_service.dart"
    "lib/prism/mcp/import/mcp_import_service.dart"
    "lib/features/settings/mcp_settings_cubit.dart"
    "lib/mcp/export/mcp_export_service.dart"
    "lib/mcp/import/mcp_import_service.dart"
    "lib/prism/mcp/export/mcp_export_service.dart"
    "lib/prism/mcp/adapters/journal_entry_projector.dart"
    "lib/echo/models/data/context_provider.dart"
    "lib/lumara/data/context_provider.dart"
    "lib/services/data_export_service.dart"
    "lib/features/timeline/widgets/interactive_timeline_view.dart"
)

# Add JournalEntry import to each file
for file in "${files[@]}"; do
    if [ -f "$file" ]; then
        echo "📝 Fixing imports in $file"
        
        # Check if JournalEntry import already exists
        if ! grep -q "import.*journal_entry_model" "$file"; then
            # Add the import after the first import line
            sed -i '' '1a\
import '\''package:my_app/models/journal_entry_model.dart'\'';
' "$file"
        fi
    else
        echo "⚠️  File not found: $file"
    fi
done

echo "✅ JournalEntry import fixes completed!"
