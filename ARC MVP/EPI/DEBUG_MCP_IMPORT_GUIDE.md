# MCP Import Debug Guide

## Debugging Enhancements Added

### 1. Enhanced Import Service Logging (`lib/mcp/import/mcp_import_service.dart`)
- **File Existence Check**: Detailed logging to verify nodes.jsonl is found
- **File Size Reporting**: Shows byte size of nodes.jsonl file
- **Line-by-line Processing**: Tracks total lines read vs. nodes processed
- **Node Type Detection**: Logs each node's ID and type as it's processed
- **Journal Entry Analysis**: Detailed inspection of journal_entry nodes including:
  - ContentSummary presence and length
  - Metadata structure and keys
  - Content extraction from multiple locations
  - Conversion success/failure tracking

### 2. Enhanced Bundle Path Resolution (`lib/features/settings/mcp_settings_view.dart`)
- **ZIP Contents Listing**: Shows all files in the extracted ZIP
- **Bundle Structure Verification**: Checks for manifest.json, nodes.jsonl, edges.jsonl
- **File Size Reporting**: Shows sizes of critical files
- **Path Resolution Tracking**: Full path debugging for bundle root discovery

## Expected Debug Output

When you run an MCP import, you should now see:

```
📦 ZIP contains X files:
  file1.json (123 bytes, isFile: true)
  ...

🔍 DEBUG: Looking for manifest.json in: /path/to/extracted_12345
📄 FILE: manifest.json (456 bytes)
📁 DIR:  some_folder
✅ DEBUG: Found manifest.json at root: /path/to/manifest.json
🔍 DEBUG: Root bundle structure check:
  manifest.json: EXISTS
  nodes.jsonl: EXISTS
  edges.jsonl: EXISTS

📋 Reading manifest...
🔐 Verifying bundle integrity...
📥 Starting NDJSON ingest...

🔍 DEBUG: Checking for nodes.jsonl at: /path/to/nodes.jsonl
✅ DEBUG: Found nodes.jsonl, size: 12345 bytes
📝 Importing nodes...

🔍 DEBUG: Processing node entry_2024_01_15_abc123 of type "journal_entry"
📄 DEBUG: Found journal_entry node: entry_2024_01_15_abc123
📄 DEBUG: Node has contentSummary: true
📄 DEBUG: Node has metadata: true
📄 DEBUG: Metadata keys: [journal_entry, export_info, ...]
📄 DEBUG: Journal metadata has content: true

🔄 DEBUG: Converting node entry_2024_01_15_abc123 to journal entry
🔄 DEBUG: Node metadata keys: [journal_entry, export_info]
🔄 DEBUG: Got content from journal_entry metadata: 1234 chars
🔄 DEBUG: Got title from journal_entry metadata: My Journal Entry
✅ DEBUG: Successfully extracted content: 1234 chars, title: My Journal Entry
✅ DEBUG: Successfully imported journal entry: My Journal Entry

✅ DEBUG: Total lines read from nodes.jsonl: 10
✅ Imported 10 nodes (5 journal entries)
```

## Troubleshooting Guide

### Issue: "0 nodes" imported
**Likely causes:**
1. **Bundle path wrong**: Check ZIP extraction logs for correct structure
2. **Empty nodes.jsonl**: Check file size in debug logs
3. **Node type mismatch**: Verify nodes have `type: "journal_entry"`

### Issue: Nodes found but 0 journal entries converted
**Likely causes:**
1. **No contentSummary**: Export may not be preserving content correctly
2. **Missing metadata**: Journal data not in expected metadata structure
3. **Conversion failure**: Check detailed conversion logs for specific issues

### Issue: Journal entries converted but don't appear on timeline
**Likely causes:**
1. **Hive storage failure**: Check `_importJournalEntry()` logs
2. **Timeline not refreshing**: Try pull-to-refresh on timeline
3. **Repository issue**: Verify journal entries are actually stored

## Testing Steps

1. **Export Data**: Create an MCP export from the app
2. **Import with Debug**: Import the ZIP file and watch console logs
3. **Check Timeline**: Verify entries appear after import
4. **Verify Content**: Ensure imported entries have full content

## Key Files Modified

- `lib/mcp/import/mcp_import_service.dart` - Enhanced import debugging
- `lib/features/settings/mcp_settings_view.dart` - Bundle path debugging
- `lib/mcp/export/mcp_export_service.dart` - Already preserves full content

## Next Steps

1. Use the app to create an MCP export
2. Import that same export while watching debug logs
3. Based on the logs, identify exactly where the process is failing
4. Apply targeted fixes to the identified issue

The debug logs will now provide complete visibility into the import process, making it easy to identify exactly where the "0 nodes" issue is occurring.