# MCP Check CLI Tool

A command-line tool for validating and repairing MCP (Memory Container Protocol) bundles.

## Installation

Ensure you have Dart SDK installed and dependencies resolved:

```bash
cd "ARC MVP/EPI"
dart pub get
```

## Usage

### Basic Usage

```bash
# Validate and repair from stdin
echo '{"nodes":[], "edges":[]}' | dart run tool/mcp_check.dart

# From file
dart run tool/mcp_check.dart -i bundle.json -o repaired.json

# Validate only (no repairs)
dart run tool/mcp_check.dart --validate-only < bundle.json
```

### Options

- `-h, --help` - Show help message
- `-v, --validate-only` - Only validate, do not repair
- `-q, --quiet` - Only output errors and final result
- `-r, --repair-log` - Show repair log in output
- `-f, --format` - Output format (json|text, default: json)
- `-i, --input` - Input file (default: stdin)
- `-o, --output` - Output file (default: stdout)

### Examples

#### Pre-commit Hook
```bash
#!/bin/bash
# .git/hooks/pre-commit
if find . -name "*.mcp.json" | xargs -I {} dart run tool/mcp_check.dart --quiet < {}; then
  echo "✅ All MCP bundles valid"
else
  echo "❌ MCP bundle validation failed"
  exit 1
fi
```

#### Repair with Detailed Logging
```bash
dart run tool/mcp_check.dart --repair-log --format text < broken_bundle.json
```

#### Batch Processing
```bash
for file in *.mcp.json; do
  echo "Processing $file..."
  dart run tool/mcp_check.dart -i "$file" -o "repaired_$file" --quiet
done
```

## Bundle Repairs

The tool automatically repairs common issues:

1. **Missing schemaVersion** → Adds `mcp-1.0`
2. **Missing bundleId** → Generates `b-<uuid>`
3. **Missing node IDs** → Generates `n-<uuid>`
4. **Missing timestamps** → Adds current UTC time
5. **Invalid edge references** → Removes edges pointing to non-existent nodes
6. **Custom fields** → Preserved in metadata

## Validation Rules

- Schema version must start with "mcp-"
- Bundle ID should start with "b-" (warning if not)
- Node IDs should start with "n-" (warning if not)
- All node IDs must be unique
- Timestamps must be valid ISO 8601
- Edge references must point to existing nodes

## Exit Codes

- `0` - Bundle is valid (after repair if needed)
- `1` - Bundle validation failed or other error

## JSON Schema

The tool validates against the schema at `lib/mcp/schema/mcp_bundle.schema.json`.

## Testing

Run the test suite:

```bash
dart test test/mcp/bundle_doctor/
```

Test with the golden bundle:

```bash
dart run tool/mcp_check.dart < testdata/golden_bundle.json
```