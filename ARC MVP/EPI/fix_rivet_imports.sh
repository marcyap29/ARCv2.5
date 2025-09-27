#!/bin/bash

# Fix RIVET import paths
echo "🔧 Fixing RIVET import paths..."

# Fix RIVET models import paths
find lib -name "*.dart" -type f -exec sed -i '' 's|package:my_app/rivet/validation/rivet_models.dart|package:my_app/rivet/models/rivet_models.dart|g' {} \;

echo "✅ RIVET import path fixes completed!"
