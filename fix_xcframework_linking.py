#!/usr/bin/env python3
"""
Fix XCFramework linking in Xcode project.
Adds proper LIBRARY_SEARCH_PATHS for llama.xcframework.
"""

import re
import sys

project_path = "ARC MVP/EPI/ios/Runner.xcodeproj/project.pbxproj"

# Read the project file
with open(project_path, 'r') as f:
    content = f.read()

# Pattern to find LIBRARY_SEARCH_PATHS array with only $(inherited)
# We want to add the XCFramework path to it
old_pattern = r'LIBRARY_SEARCH_PATHS = \(\s*"\$\(inherited\)",\s*\);'
new_value = '''LIBRARY_SEARCH_PATHS = (
					"$(inherited)",
					"$(PROJECT_DIR)/Runner/Vendor/llama.xcframework/ios-arm64",
				);'''

# Replace all occurrences
content_new = re.sub(old_pattern, new_value, content)

# Count changes
changes = content.count(old_pattern)

# Write back if changes were made
if content_new != content:
    with open(project_path, 'w') as f:
        f.write(content_new)
    print(f"✅ Updated LIBRARY_SEARCH_PATHS in {changes} configurations")
else:
    print("⚠️ No changes needed - LIBRARY_SEARCH_PATHS already configured")

print("\n✅ XCFramework linking configuration complete!")
