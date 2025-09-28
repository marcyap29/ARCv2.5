#!/usr/bin/env dart
// tool/mcp_check.dart
// MCP Bundle Doctor CLI Tool
// Usage: dart run tool/mcp_check.dart [options] < bundle.json

import 'dart:convert';
import 'dart:io';
import 'package:args/args.dart';
import 'package:my_app/mcp/bundle_doctor/bundle_doctor.dart';

void main(List<String> arguments) async {
  final parser = ArgParser()
    ..addFlag('help', abbr: 'h', help: 'Show help message', negatable: false)
    ..addFlag('validate-only', abbr: 'v', help: 'Only validate, do not repair', negatable: false)
    ..addFlag('quiet', abbr: 'q', help: 'Only output errors and final result', negatable: false)
    ..addFlag('repair-log', abbr: 'r', help: 'Show repair log in output', negatable: false)
    ..addOption('format', abbr: 'f', help: 'Output format', allowed: ['json', 'text'], defaultsTo: 'json')
    ..addOption('input', abbr: 'i', help: 'Input file (default: stdin)')
    ..addOption('output', abbr: 'o', help: 'Output file (default: stdout)');

  late ArgResults results;
  try {
    results = parser.parse(arguments);
  } catch (e) {
    _printError('Error parsing arguments: $e');
    _printUsage(parser);
    exit(1);
  }

  if (results['help'] as bool) {
    _printUsage(parser);
    exit(0);
  }

  try {
    await _processBundle(results);
  } catch (e, stackTrace) {
    _printError('Fatal error: $e');
    if (!results['quiet']) {
      _printError('Stack trace: $stackTrace');
    }
    exit(1);
  }
}

Future<void> _processBundle(ArgResults results) async {
  final quiet = results['quiet'] as bool;
  final validateOnly = results['validate-only'] as bool;
  final showRepairLog = results['repair-log'] as bool;
  final format = results['format'] as String;

  // Read input
  String input;
  if (results['input'] != null) {
    final file = File(results['input'] as String);
    if (!file.existsSync()) {
      _printError('Input file not found: ${results['input']}');
      exit(1);
    }
    input = await file.readAsString();
  } else {
    if (!quiet) {
      stderr.writeln('Reading from stdin...');
    }
    input = await _readStdin();
  }

  if (input.trim().isEmpty) {
    _printError('No input provided');
    exit(1);
  }

  // Parse JSON
  Map<String, dynamic> bundleData;
  try {
    bundleData = jsonDecode(input) as Map<String, dynamic>;
  } catch (e) {
    _printError('Invalid JSON input: $e');
    exit(1);
  }

  // Process bundle
  if (validateOnly) {
    await _validateOnly(bundleData, results);
  } else {
    await _repairAndValidate(bundleData, results);
  }
}

Future<void> _validateOnly(Map<String, dynamic> bundleData, ArgResults results) async {
  final quiet = results['quiet'] as bool;
  final format = results['format'] as String;

  if (!quiet) {
    stderr.writeln('Validating bundle (no repairs)...');
  }

  // Try to create bundle without repair (just parse)
  try {
    final bundle = BundleDoctor.repair(bundleData); // Still need to create bundle object
    final validation = BundleDoctor.validate(bundle);

    if (format == 'json') {
      _writeOutput(results, jsonEncode({
        'valid': validation.isValid,
        'errors': validation.errors,
        'warnings': validation.warnings,
        'operation': 'validate-only'
      }));
    } else {
      if (validation.isValid) {
        if (!quiet) print('✅ Bundle is valid');
      } else {
        print('❌ Bundle validation failed:');
        for (final error in validation.errors) {
          print('  ERROR: $error');
        }
      }

      if (validation.warnings.isNotEmpty) {
        print('⚠️  Warnings:');
        for (final warning in validation.warnings) {
          print('  WARN: $warning');
        }
      }
    }

    exit(validation.isValid ? 0 : 1);
  } catch (e) {
    _printError('Validation failed: $e');
    exit(1);
  }
}

Future<void> _repairAndValidate(Map<String, dynamic> bundleData, ArgResults results) async {
  final quiet = results['quiet'] as bool;
  final showRepairLog = results['repair-log'] as bool;
  final format = results['format'] as String;

  if (!quiet) {
    stderr.writeln('Repairing and validating bundle...');
  }

  // Repair bundle
  final bundle = BundleDoctor.repair(bundleData);
  final validation = BundleDoctor.validate(bundle);

  if (format == 'json') {
    final output = {
      'valid': validation.isValid,
      'errors': validation.errors,
      'warnings': validation.warnings,
      'operation': 'repair-and-validate',
      'bundle': bundle.toJson(),
    };

    if (showRepairLog && bundle.repairLog.isNotEmpty) {
      output['repairLog'] = bundle.repairLog;
    }

    _writeOutput(results, jsonEncode(output));
  } else {
    // Text format output
    if (bundle.repairLog.isNotEmpty) {
      if (showRepairLog || !quiet) {
        stderr.writeln('🔧 Repairs made:');
        for (final repair in bundle.repairLog) {
          stderr.writeln('  - $repair');
        }
      }
    }

    if (validation.isValid) {
      if (!quiet) stderr.writeln('✅ Bundle repaired and validated successfully');
    } else {
      stderr.writeln('❌ Bundle validation failed after repair:');
      for (final error in validation.errors) {
        stderr.writeln('  ERROR: $error');
      }
    }

    if (validation.warnings.isNotEmpty) {
      stderr.writeln('⚠️  Warnings:');
      for (final warning in validation.warnings) {
        stderr.writeln('  WARN: $warning');
      }
    }

    // Output repaired bundle
    _writeOutput(results, BundleDoctor.toJson(bundle));
  }

  exit(validation.isValid ? 0 : 1);
}

void _writeOutput(ArgResults results, String content) {
  if (results['output'] != null) {
    final file = File(results['output'] as String);
    file.writeAsStringSync(content);
  } else {
    stdout.write(content);
  }
}

Future<String> _readStdin() async {
  final buffer = StringBuffer();
  await for (final line in stdin.transform(utf8.decoder).transform(const LineSplitter())) {
    buffer.writeln(line);
  }
  return buffer.toString();
}

void _printError(String message) {
  stderr.writeln('mcp-check: $message');
}

void _printUsage(ArgParser parser) {
  print('''
MCP Bundle Doctor CLI Tool

USAGE:
  dart run tool/mcp_check.dart [OPTIONS] < bundle.json
  dart run tool/mcp_check.dart -i bundle.json -o repaired.json

DESCRIPTION:
  Validates and optionally repairs MCP (Memory Container Protocol) bundles.
  Reads JSON from stdin or file, validates structure, repairs common issues,
  and outputs the result.

OPTIONS:
${parser.usage}

EXAMPLES:
  # Validate and repair from stdin
  echo '{"nodes":[], "edges":[]}' | dart run tool/mcp_check.dart

  # Validate only, no repairs
  dart run tool/mcp_check.dart --validate-only < bundle.json

  # Repair with detailed logging
  dart run tool/mcp_check.dart --repair-log --format text < bundle.json

  # Use in pre-commit hook
  dart run tool/mcp_check.dart --quiet < exported_bundle.json

EXIT CODES:
  0 - Bundle is valid (after repair if needed)
  1 - Bundle validation failed or other error

BUNDLE REPAIRS:
  - Adds missing schemaVersion (defaults to mcp-1.0)
  - Generates missing bundleId with b- prefix
  - Generates missing node IDs with n- prefix
  - Adds missing timestamps (current UTC time)
  - Removes edges that reference missing nodes
  - Preserves all custom fields in metadata

VALIDATION RULES:
  - Schema version must start with "mcp-"
  - Bundle ID should start with "b-" (warning if not)
  - Node IDs should start with "n-" (warning if not)
  - All node IDs must be unique
  - Timestamps must be valid ISO 8601
  - Edge references must point to existing nodes
''');
}