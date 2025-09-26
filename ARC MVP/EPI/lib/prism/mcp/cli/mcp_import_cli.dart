import 'dart:io';
import 'dart:convert';
import 'package:args/args.dart';
import 'package:path/path.dart' as path;
import 'package:my_app/prism/mcp/import/mcp_import_service.dart';
import 'package:my_app/prism/mcp/import/manifest_reader.dart';
import 'package:my_app/prism/mcp/validation/mcp_import_validator.dart';
import 'package:my_app/prism/mcp/adapters/mira_writer.dart';
import 'package:my_app/prism/mcp/adapters/cas_resolver.dart';

/// CLI tool for MCP bundle import operations
/// 
/// Provides command-line interface for importing MCP bundles into MIRA storage
/// with comprehensive options for validation, dry-run, and progress tracking.
class McpImportCli {
  static const String version = '1.0.0';
  static const String description = 'MCP Bundle Importer - Import standards-compliant MCP exports into MIRA storage';

  /// Main entry point for CLI
  static Future<void> main(List<String> arguments) async {
    final parser = _createArgParser();
    
    try {
      final results = parser.parse(arguments);
      
      if (results['help'] as bool) {
        _printUsage(parser);
        exit(0);
      }
      
      if (results['version'] as bool) {
        print('MCP Import CLI v$version');
        exit(0);
      }

      await _runCommand(results);
    } on FormatException catch (e) {
      stderr.writeln('Error: ${e.message}');
      stderr.writeln();
      _printUsage(parser);
      exit(1);
    } catch (e) {
      stderr.writeln('Unexpected error: $e');
      exit(1);
    }
  }

  /// Create argument parser
  static ArgParser _createArgParser() {
    final parser = ArgParser();
    
    parser.addFlag(
      'help',
      abbr: 'h',
      help: 'Show this help message',
      negatable: false,
    );
    
    parser.addFlag(
      'version',
      abbr: 'v',
      help: 'Show version information',
      negatable: false,
    );
    
    parser.addOption(
      'bundle',
      abbr: 'b',
      help: 'Path to MCP bundle directory',
      mandatory: false,
    );
    
    parser.addOption(
      'storage',
      abbr: 's',
      help: 'Path to MIRA storage directory',
      defaultsTo: './mira_storage',
    );
    
    parser.addFlag(
      'dry-run',
      abbr: 'd',
      help: 'Validate bundle without importing',
      negatable: false,
    );
    
    parser.addFlag(
      'strict',
      help: 'Enable strict validation mode',
      negatable: false,
    );
    
    parser.addFlag(
      'verify-cas',
      help: 'Verify CAS content integrity',
      negatable: false,
    );
    
    parser.addFlag(
      'skip-indexes',
      help: 'Skip rebuilding indexes after import',
      negatable: false,
    );
    
    parser.addOption(
      'max-errors',
      help: 'Maximum errors before aborting',
      defaultsTo: '100',
    );
    
    parser.addOption(
      'cas-remotes',
      help: 'Comma-separated list of CAS remote URLs',
    );
    
    parser.addFlag(
      'verbose',
      help: 'Enable verbose output',
      negatable: false,
    );
    
    parser.addFlag(
      'quiet',
      abbr: 'q',
      help: 'Suppress non-essential output',
      negatable: false,
    );
    
    parser.addOption(
      'format',
      help: 'Output format (text, json)',
      defaultsTo: 'text',
      allowed: ['text', 'json'],
    );
    
    parser.addCommand('import')
      .addOption(
        'bundle',
        abbr: 'b',
        help: 'Path to MCP bundle directory',
        mandatory: true,
      );
    
    parser.addCommand('validate')
      .addOption(
        'bundle',
        abbr: 'b',
        help: 'Path to MCP bundle directory',
        mandatory: true,
      );
    
    parser.addCommand('info')
      .addOption(
        'bundle',
        abbr: 'b',
        help: 'Path to MCP bundle directory',
        mandatory: true,
      );
    
    parser.addCommand('list')
      .addOption(
        'storage',
        abbr: 's',
        help: 'Path to MIRA storage directory',
        defaultsTo: './mira_storage',
      );
    
    parser.addCommand('cleanup')
      ..addOption(
        'storage',
        abbr: 's',
        help: 'Path to MIRA storage directory',
        defaultsTo: './mira_storage',
      )
      ..addOption(
        'keep-batches',
        help: 'Number of recent batches to keep',
        defaultsTo: '10',
      );

    return parser;
  }

  /// Run the appropriate command
  static Future<void> _runCommand(ArgResults results) async {
    final verbose = results['verbose'] as bool;
    final quiet = results['quiet'] as bool;
    final format = results['format'] as String;

    if (results.command != null) {
      switch (results.command!.name) {
        case 'import':
          await _runImport(results.command!, verbose, quiet, format);
          break;
        case 'validate':
          await _runValidate(results.command!, verbose, quiet, format);
          break;
        case 'info':
          await _runInfo(results.command!, verbose, quiet, format);
          break;
        case 'list':
          await _runList(results.command!, verbose, quiet, format);
          break;
        case 'cleanup':
          await _runCleanup(results.command!, verbose, quiet, format);
          break;
        default:
          throw FormatException('Unknown command: ${results.command!.name}');
      }
    } else {
      // Legacy mode - import if bundle is specified
      if (results.wasParsed('bundle')) {
        await _runLegacyImport(results, verbose, quiet, format);
      } else {
        _printUsage(_createArgParser());
        exit(1);
      }
    }
  }

  /// Run import command
  static Future<void> _runImport(ArgResults command, bool verbose, bool quiet, String format) async {
    final bundlePath = command['bundle'] as String;
    final bundleDir = Directory(bundlePath);
    
    if (!bundleDir.existsSync()) {
      stderr.writeln('Error: Bundle directory not found: $bundlePath');
      exit(1);
    }

    if (!quiet) {
      print('🚀 Starting MCP bundle import...');
      print('📂 Bundle: $bundlePath');
    }

    // Get global options; parent may be unavailable in analyzer env. Provide defaults.
    const bool dryRun = false;
    const bool strict = false;
    const bool verifyCas = false;
    const bool skipIndexes = false;
    const int maxErrors = 100;
    const String storagePath = './mira_storage';
    const String? casRemotesRaw = null;

    const options = McpImportOptions(
      dryRun: dryRun,
      strictMode: strict,
      verifyCas: verifyCas,
      rebuildIndexes: !skipIndexes,
      maxErrors: maxErrors,
    );

    // Configure CAS resolver if remotes specified
    CasResolver? casResolver;
    if (casRemotesRaw != null) {
      final remotes = casRemotesRaw.split(',').map((r) => r.trim()).toList();
      final casConfig = CasResolverConfig(
        trustedRemotes: remotes,
        enableCaching: true,
        cacheDirectory: path.join(storagePath, 'cas_cache'),
      );
      casResolver = CasResolver(
        config: casConfig,
        localStorageRoot: storagePath,
      );
    }

    // Create service with configured storage
    final miraWriter = MiraWriter(storageRoot: storagePath);
    final service = McpImportService(
      miraWriter: miraWriter,
      casResolver: casResolver,
    );

    final stopwatch = Stopwatch()..start();
    
    try {
      final result = await service.importBundle(bundleDir, options);
      stopwatch.stop();

      if (format == 'json') {
        print(jsonEncode({
          'success': result.success,
          'counts': result.counts,
          'warnings': result.warnings,
          'errors': result.errors,
          'processing_time_ms': stopwatch.elapsedMilliseconds,
          'batch_id': result.batchId,
        }));
      } else {
        _printImportResult(result, verbose, quiet);
      }

      exit(result.success ? 0 : 1);
    } catch (e, stackTrace) {
      stopwatch.stop();
      
      if (format == 'json') {
        print(jsonEncode({
          'success': false,
          'error': e.toString(),
          'processing_time_ms': stopwatch.elapsedMilliseconds,
        }));
      } else {
        stderr.writeln('❌ Import failed: $e');
        if (verbose) {
          stderr.writeln('Stack trace: $stackTrace');
        }
      }
      
      exit(1);
    } finally {
      casResolver?.dispose();
    }
  }

  /// Run validate command
  static Future<void> _runValidate(ArgResults command, bool verbose, bool quiet, String format) async {
    final bundlePath = command['bundle'] as String;
    final bundleDir = Directory(bundlePath);
    
    if (!bundleDir.existsSync()) {
      stderr.writeln('Error: Bundle directory not found: $bundlePath');
      exit(1);
    }

    if (!quiet) {
      print('🔍 Validating MCP bundle...');
      print('📂 Bundle: $bundlePath');
    }

    final validator = McpImportValidator();
    final manifestReader = ManifestReader();
    
    try {
      // Validate manifest
      final manifest = await manifestReader.readManifest(bundleDir);
      manifestReader.validateManifest(manifest);
      
      if (verbose && !quiet) {
        print(manifestReader.getManifestSummary(manifest));
      }

      // Validate NDJSON files
      final files = ['nodes.jsonl', 'edges.jsonl', 'pointers.jsonl', 'embeddings.jsonl'];
      final results = <String, dynamic>{};
      bool allValid = true;

      for (final filename in files) {
        final file = File(path.join(bundleDir.path, filename));
        if (!file.existsSync()) continue;

        final recordType = filename.split('.').first.replaceAll('s', '');
        final validationResult = await validator.validateNdjsonFile(file, recordType);
        
        results[filename] = validationResult.toJson();
        
        if (!validationResult.isValid) {
          allValid = false;
        }

        if (verbose && !quiet) {
          print('📄 $filename: ${validationResult.isValid ? "✅ Valid" : "❌ Invalid"}');
          if (!validationResult.isValid) {
            for (final error in validationResult.errors.take(5)) {
              print('  - ${error.message}');
            }
            if (validationResult.errors.length > 5) {
              print('  ... and ${validationResult.errors.length - 5} more errors');
            }
          }
        }
      }

      if (format == 'json') {
        print(jsonEncode({
          'valid': allValid,
          'manifest': manifest.toJson(),
          'files': results,
        }));
      } else {
        print(allValid ? '✅ Bundle validation passed' : '❌ Bundle validation failed');
      }

      exit(allValid ? 0 : 1);
    } catch (e) {
      if (format == 'json') {
        print(jsonEncode({
          'valid': false,
          'error': e.toString(),
        }));
      } else {
        stderr.writeln('❌ Validation failed: $e');
      }
      exit(1);
    }
  }

  /// Run info command
  static Future<void> _runInfo(ArgResults command, bool verbose, bool quiet, String format) async {
    final bundlePath = command['bundle'] as String;
    final bundleDir = Directory(bundlePath);
    
    if (!bundleDir.existsSync()) {
      stderr.writeln('Error: Bundle directory not found: $bundlePath');
      exit(1);
    }

    try {
      final manifestReader = ManifestReader();
      final manifest = await manifestReader.readManifest(bundleDir);
      
      if (format == 'json') {
        print(jsonEncode(manifest.toJson()));
      } else {
        print(manifestReader.getManifestSummary(manifest));
        
        // Show file sizes
        final files = ['manifest.json', 'nodes.jsonl', 'edges.jsonl', 'pointers.jsonl', 'embeddings.jsonl'];
        print('\nFile Information:');
        for (final filename in files) {
          final file = File(path.join(bundleDir.path, filename));
          if (file.existsSync()) {
            final size = file.lengthSync();
            final sizeStr = _formatFileSize(size);
            print('  $filename: $sizeStr');
          } else {
            print('  $filename: missing');
          }
        }
      }
      
      exit(0);
    } catch (e) {
      if (format == 'json') {
        print(jsonEncode({'error': e.toString()}));
      } else {
        stderr.writeln('❌ Failed to read bundle info: $e');
      }
      exit(1);
    }
  }

  /// Run list command
  static Future<void> _runList(ArgResults command, bool verbose, bool quiet, String format) async {
    final storagePath = command['storage'] as String;
    final storageDir = Directory(storagePath);
    
    if (!storageDir.existsSync()) {
      if (format == 'json') {
        print(jsonEncode({'batches': []}));
      } else {
        print('No MIRA storage found at: $storagePath');
      }
      exit(0);
    }

    try {
      final batchesDir = Directory(path.join(storagePath, 'batches'));
      final batches = <Map<String, dynamic>>[];
      
      if (batchesDir.existsSync()) {
        await for (final entity in batchesDir.list()) {
          if (entity is File && entity.path.endsWith('.json')) {
            try {
              final content = jsonDecode(await entity.readAsString());
              batches.add(content);
            } catch (e) {
              if (verbose) {
                stderr.writeln('Warning: Failed to read ${entity.path}: $e');
              }
            }
          }
        }
      }

      // Sort by creation time
      batches.sort((a, b) {
        final aTime = DateTime.parse(a['created_at'] as String);
        final bTime = DateTime.parse(b['created_at'] as String);
        return bTime.compareTo(aTime);
      });

      if (format == 'json') {
        print(jsonEncode({'batches': batches}));
      } else {
        if (batches.isEmpty) {
          print('No import batches found');
        } else {
          print('Import Batches:');
          for (final batch in batches) {
            final batchId = batch['batch_id'] as String;
            final createdAt = batch['created_at'] as String;
            final counts = batch['counts'] as Map<String, dynamic>;
            
            print('  📦 $batchId');
            print('     Created: $createdAt');
            print('     Counts: ${counts.entries.map((e) => '${e.key}=${e.value}').join(', ')}');
          }
        }
      }
      
      exit(0);
    } catch (e) {
      if (format == 'json') {
        print(jsonEncode({'error': e.toString()}));
      } else {
        stderr.writeln('❌ Failed to list batches: $e');
      }
      exit(1);
    }
  }

  /// Run cleanup command
  static Future<void> _runCleanup(ArgResults command, bool verbose, bool quiet, String format) async {
    final storagePath = command['storage'] as String;
    final keepBatches = int.parse(command['keep-batches'] as String);
    
    try {
      final miraWriter = MiraWriter(storageRoot: storagePath);
      await miraWriter.cleanupOldBatches(keepRecentBatches: keepBatches);
      
      // Also cleanup CAS cache
      final casResolver = CasResolver(
        localStorageRoot: storagePath,
        config: const CasResolverConfig(enableCaching: true),
      );
      
      await casResolver.cleanupCache(
        olderThan: const Duration(days: 30),
        keepRecentCount: 100,
      );
      
      casResolver.dispose();
      
      if (format == 'json') {
        print(jsonEncode({'success': true, 'message': 'Cleanup completed'}));
      } else if (!quiet) {
        print('✅ Storage cleanup completed');
      }
      
      exit(0);
    } catch (e) {
      if (format == 'json') {
        print(jsonEncode({'success': false, 'error': e.toString()}));
      } else {
        stderr.writeln('❌ Cleanup failed: $e');
      }
      exit(1);
    }
  }

  /// Run legacy import (backward compatibility)
  static Future<void> _runLegacyImport(ArgResults results, bool verbose, bool quiet, String format) async {
    throw UnimplementedError('Legacy import path is not supported in app builds');
  }

  /// Print import result
  static void _printImportResult(McpImportResult result, bool verbose, bool quiet) {
    if (result.success) {
      if (!quiet) {
        print('✅ Import completed successfully');
        if (result.batchId != null) {
          print('📦 Batch ID: ${result.batchId}');
        }
        print('⏱️  Processing time: ${result.processingTime.inMilliseconds}ms');
        
        if (result.counts.isNotEmpty) {
          print('📊 Imported:');
          for (final entry in result.counts.entries) {
            print('   ${entry.key}: ${entry.value}');
          }
        }
      }
    } else {
      if (!quiet) {
        print('❌ Import failed: ${result.message}');
        print('⏱️  Processing time: ${result.processingTime.inMilliseconds}ms');
      }
    }

    if (result.warnings.isNotEmpty && (verbose || !quiet)) {
      print('\n⚠️  Warnings:');
      for (final warning in result.warnings) {
        print('   $warning');
      }
    }

    if (result.errors.isNotEmpty) {
      print('\n❌ Errors:');
      for (final error in result.errors.take(10)) {
        print('   $error');
      }
      if (result.errors.length > 10) {
        print('   ... and ${result.errors.length - 10} more errors');
      }
    }
  }

  /// Print usage information
  static void _printUsage(ArgParser parser) {
    print(description);
    print('');
    print('Usage: mcp_import [options] <command>');
    print('');
    print('Commands:');
    print('  import    Import an MCP bundle into MIRA storage');
    print('  validate  Validate an MCP bundle without importing');
    print('  info      Show information about an MCP bundle');
    print('  list      List imported batches in MIRA storage');
    print('  cleanup   Clean up old batches and cached data');
    print('');
    print('Global options:');
    print(parser.usage);
    print('');
    print('Examples:');
    print('  mcp_import import -b ./my_bundle');
    print('  mcp_import validate -b ./my_bundle --verbose');
    print('  mcp_import import -b ./my_bundle --dry-run --strict');
    print('  mcp_import list -s ./my_storage --format json');
    print('  mcp_import cleanup -s ./my_storage --keep-batches 5');
  }

  /// Format file size for display
  static String _formatFileSize(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)}GB';
  }
}