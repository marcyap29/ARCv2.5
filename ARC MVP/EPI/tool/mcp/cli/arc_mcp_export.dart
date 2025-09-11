#!/usr/bin/env dart

/// ARC MCP Export CLI
/// 
/// Command-line tool for exporting EPI memory to MCP Memory Bundle format.
/// Supports various scopes and storage profiles.

import 'dart:io';
import 'dart:convert';
import 'package:args/args.dart';
import 'package:my_app/mcp/export/mcp_export_service.dart';
import 'package:my_app/mcp/models/mcp_schemas.dart';
import 'package:my_app/mcp/validation/mcp_validator.dart';

void main(List<String> arguments) async {
  final parser = ArgParser()
    ..addOption('scope',
        abbr: 's',
        help: 'Export scope: last-30-days, last-90-days, last-year, all, custom',
        allowed: ['last-30-days', 'last-90-days', 'last-year', 'all', 'custom'],
        defaultsTo: 'last-30-days')
    ..addOption('storage-profile',
        abbr: 'p',
        help: 'Storage profile: minimal, space_saver, balanced, hi_fidelity',
        allowed: ['minimal', 'space_saver', 'balanced', 'hi_fidelity'],
        defaultsTo: 'balanced')
    ..addOption('out',
        abbr: 'o',
        help: 'Output directory for MCP bundle',
        defaultsTo: './epi_mcp_export')
    ..addOption('start-date',
        help: 'Start date for custom scope (ISO 8601 format)')
    ..addOption('end-date',
        help: 'End date for custom scope (ISO 8601 format)')
    ..addMultiOption('tags',
        help: 'Tags to filter by for custom scope')
    ..addFlag('validate',
        abbr: 'v',
        help: 'Validate the exported bundle',
        defaultsTo: true)
    ..addFlag('verbose',
        help: 'Enable verbose output',
        defaultsTo: false)
    ..addFlag('help',
        abbr: 'h',
        help: 'Show this help message',
        negatable: false);

  try {
    final results = parser.parse(arguments);

    if (results['help'] as bool) {
      printUsage(parser);
      exit(0);
    }

    final scope = McpExportScope.values.firstWhere(
      (s) => s.value == results['scope'] as String,
      orElse: () => McpExportScope.last30Days,
    );

    final storageProfile = McpStorageProfile.values.firstWhere(
      (p) => p.value == results['storage-profile'] as String,
      orElse: () => McpStorageProfile.balanced,
    );

    final outputDir = Directory(results['out'] as String);
    final validate = results['validate'] as bool;
    final verbose = results['verbose'] as bool;

    // Parse custom scope if provided
    Map<String, dynamic>? customScope;
    if (scope == McpExportScope.custom) {
      customScope = <String, dynamic>{};
      
      if (results['start-date'] != null) {
        customScope['start_date'] = DateTime.parse(results['start-date'] as String);
      }
      if (results['end-date'] != null) {
        customScope['end_date'] = DateTime.parse(results['end-date'] as String);
      }
      if (results['tags'] != null) {
        customScope['tags'] = results['tags'] as List<String>;
      }
    }

    if (verbose) {
      print('Starting MCP export...');
      print('Scope: ${scope.value}');
      print('Storage Profile: ${storageProfile.value}');
      print('Output Directory: ${outputDir.path}');
    }

    // Create export service
    final exportService = McpExportService(
      storageProfile: storageProfile,
      notes: 'Exported via ARC MCP CLI on ${DateTime.now().toIso8601String()}',
    );

    // Load journal entries (this would integrate with your data layer)
    final journalEntries = await loadJournalEntries();
    final mediaFiles = await loadMediaFiles();

    if (verbose) {
      print('Loaded ${journalEntries.length} journal entries');
      print('Loaded ${mediaFiles.length} media files');
    }

    // Export to MCP
    final result = await exportService.exportToMcp(
      outputDir: outputDir,
      scope: scope,
      journalEntries: journalEntries,
      mediaFiles: mediaFiles,
      customScope: customScope,
    );

    if (!result.success) {
      print('Export failed: ${result.error}');
      exit(1);
    }

    print('✅ MCP export completed successfully!');
    print('Bundle ID: ${result.bundleId}');
    print('Output Directory: ${result.outputDir.path}');
    
    if (result.counts != null) {
      print('\nExport Summary:');
      print('  Nodes: ${result.counts!.nodes}');
      print('  Edges: ${result.counts!.edges}');
      print('  Pointers: ${result.counts!.pointers}');
      print('  Embeddings: ${result.counts!.embeddings}');
    }

    if (result.encoderRegistry != null && result.encoderRegistry!.isNotEmpty) {
      print('\nEncoder Registry:');
      for (final encoder in result.encoderRegistry!) {
        print('  ${encoder.modelId} v${encoder.embeddingVersion} (${encoder.dim}D)');
      }
    }

    // Validate bundle if requested
    if (validate) {
      print('\n🔍 Validating exported bundle...');
      final validationResult = await McpValidator.validateBundle(outputDir);
      
      if (validationResult.isValid) {
        print('✅ Bundle validation passed');
      } else {
        print('❌ Bundle validation failed:');
        for (final error in validationResult.errors) {
          print('  - $error');
        }
        exit(1);
      }
    }

    // Show file checksums
    if (result.ndjsonFiles != null) {
      print('\n📁 Generated Files:');
      for (final entry in result.ndjsonFiles!.entries) {
        final file = entry.value;
        if (await file.exists()) {
          final size = await file.length();
          print('  ${entry.key}.jsonl: ${_formatBytes(size)}');
        }
      }
      
      if (result.manifestFile != null && await result.manifestFile!.exists()) {
        final size = await result.manifestFile!.length();
        print('  manifest.json: ${_formatBytes(size)}');
      }
    }

    print('\n🎉 Export complete! Bundle ready for sharing or import.');

  } catch (e) {
    print('Error: $e');
    exit(1);
  }
}

void printUsage(ArgParser parser) {
  print('ARC MCP Export CLI');
  print('');
  print('Export EPI memory to MCP Memory Bundle format.');
  print('');
  print('Usage: dart run tool/mcp/cli/arc_mcp_export.dart [options]');
  print('');
  print('Options:');
  print(parser.usage);
  print('');
  print('Examples:');
  print('  # Export last 30 days with balanced profile');
  print('  dart run tool/mcp/cli/arc_mcp_export.dart --scope=last-30-days');
  print('');
  print('  # Export all data with high fidelity profile');
  print('  dart run tool/mcp/cli/arc_mcp_export.dart --scope=all --storage-profile=hi_fidelity');
  print('');
  print('  # Export custom date range');
  print('  dart run tool/mcp/cli/arc_mcp_export.dart --scope=custom --start-date=2024-01-01 --end-date=2024-12-31');
  print('');
  print('  # Export with specific tags');
  print('  dart run tool/mcp/cli/arc_mcp_export.dart --scope=custom --tags=work,personal');
  print('');
  print('  # Export to specific directory');
  print('  dart run tool/mcp/cli/arc_mcp_export.dart --out=/path/to/export');
  print('');
  print('Storage Profiles:');
  print('  minimal     - Summaries and light embeddings only');
  print('  space_saver - Plus sparse keyframes or chunked spans');
  print('  balanced    - Default balanced approach');
  print('  hi_fidelity - Dense sampling, more spans, more keyframes');
  print('');
  print('Validation:');
  print('  The exported bundle is automatically validated unless --no-validate is specified.');
  print('  Use ajv to validate individual files:');
  print('    ajv validate -s schemas/node.v1.json -d nodes.jsonl --spec=draft2020');
}

/// Load journal entries from your data layer
Future<List<JournalEntry>> loadJournalEntries() async {
  // This would integrate with your existing journal repository
  // For now, return sample data
  return [
    JournalEntry(
      id: 'entry_001',
      content: 'Today I learned about MCP export and how it can help preserve my journal memories in a portable format.',
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
      tags: {'learning', 'technology', 'memory'},
      userId: 'user_001',
      metadata: {'phase': 'Discovery'},
    ),
    JournalEntry(
      id: 'entry_002',
      content: 'I realized that having a standardized way to export my thoughts and experiences is really valuable for long-term preservation.',
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
      tags: {'insight', 'preservation', 'value'},
      userId: 'user_001',
      metadata: {'phase': 'Growth'},
    ),
  ];
}

/// Load media files from your data layer
Future<List<MediaFile>> loadMediaFiles() async {
  // This would integrate with your existing media repository
  // For now, return empty list
  return [];
}

/// Format bytes as human-readable string
String _formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
}
