// lib/mcp/bundle/reader.dart
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import '../../mira/core/mira_repo.dart';
import 'manifest.dart';
import 'validate.dart';

class McpBundleReader {
  final MiraRepo repo;
  final McpValidator validator;

  McpBundleReader(this.repo, {McpValidator? validator})
      : validator = validator ?? McpValidatorV1();

  Future<ImportResult> importBundle({
    required Directory bundleDir,
    bool validateChecksums = true,
    bool skipExisting = true,
  }) async {
    final manifestFile = File('${bundleDir.path}/manifest.json');
    if (!await manifestFile.exists()) {
      throw ImportError('manifest.json not found in bundle directory');
    }

    final manifestContent = await manifestFile.readAsString();
    final manifest = jsonDecode(manifestContent) as Map<String, dynamic>;

    final errors = <String>[];
    if (!validator.validateManifest(manifest, errors)) {
      throw ImportError('Invalid manifest: ${errors.join(', ')}');
    }

    final result = ImportResult();

    // Import in dependency order: nodes, edges, pointers, embeddings
    await _importJsonlFile(
      bundleDir: bundleDir,
      filename: 'nodes.jsonl',
      kind: 'node',
      manifest: manifest,
      validateChecksums: validateChecksums,
      skipExisting: skipExisting,
      result: result,
    );

    await _importJsonlFile(
      bundleDir: bundleDir,
      filename: 'edges.jsonl',
      kind: 'edge',
      manifest: manifest,
      validateChecksums: validateChecksums,
      skipExisting: skipExisting,
      result: result,
    );

    await _importJsonlFile(
      bundleDir: bundleDir,
      filename: 'pointers.jsonl',
      kind: 'pointer',
      manifest: manifest,
      validateChecksums: validateChecksums,
      skipExisting: skipExisting,
      result: result,
    );

    await _importJsonlFile(
      bundleDir: bundleDir,
      filename: 'embeddings.jsonl',
      kind: 'embedding',
      manifest: manifest,
      validateChecksums: validateChecksums,
      skipExisting: skipExisting,
      result: result,
    );

    return result;
  }

  Future<void> _importJsonlFile({
    required Directory bundleDir,
    required String filename,
    required String kind,
    required Map<String, dynamic> manifest,
    required bool validateChecksums,
    required bool skipExisting,
    required ImportResult result,
  }) async {
    final file = File('${bundleDir.path}/$filename');
    if (!await file.exists()) return; // Skip missing files

    // Validate checksum if requested
    if (validateChecksums) {
      final expectedChecksum = manifest['checksums']['${filename}'] as String?;
      if (expectedChecksum != null) {
        final actualChecksum = await _calculateFileChecksum(file);
        if (actualChecksum != expectedChecksum) {
          throw ImportError('Checksum mismatch for $filename: expected $expectedChecksum, got $actualChecksum');
        }
      }
    }

    // Stream import JSONL line by line
    final stream = file.openRead().transform(utf8.decoder).transform(const LineSplitter());
    var lineNo = 0;

    final records = <Map<String, dynamic>>[];
    await for (final line in stream) {
      lineNo++;
      if (line.trim().isEmpty) continue;

      try {
        final record = jsonDecode(line) as Map<String, dynamic>;

        // Validate record structure
        final errors = <String>[];
        if (!validator.validateLine(kind, record, lineNo, errors)) {
          result.addError('$filename:$lineNo validation failed: ${errors.join(', ')}');
          continue;
        }

        // Check if record already exists
        if (skipExisting && await _recordExists(kind, record)) {
          result.addSkipped(kind);
          continue;
        }

        records.add(record);
      } catch (e) {
        result.addError('$filename:$lineNo JSON parse error: $e');
      }
    }

    // Batch import all valid records
    if (records.isNotEmpty) {
      await repo.importAll(records);
      result.addImported(kind, records.length);
    }
  }

  Future<String> _calculateFileChecksum(File file) async {
    final input = file.openRead();
    final digest = await sha256.bind(input).first;
    return 'sha256:$digest';
  }

  Future<bool> _recordExists(String kind, Map<String, dynamic> record) async {
    switch (kind) {
      case 'node':
        final node = await repo.getNode(record['id'] as String);
        return node != null;
      case 'edge':
        // Edges don't have IDs in our current schema, check by source/target/relation
        final edges = await repo.edgesBetween(
          record['source'] as String,
          record['target'] as String,
        );
        return edges.any((e) => e.relation.toString().split('.').last == record['relation']);
      case 'pointer':
        final pointer = await repo.getPointer(record['id'] as String);
        return pointer != null;
      case 'embedding':
        final embedding = await repo.getEmbedding(record['id'] as String);
        return embedding != null;
      default:
        return false;
    }
  }
}

class ImportResult {
  final Map<String, int> _imported = {};
  final Map<String, int> _skipped = {};
  final List<String> _errors = [];

  void addImported(String kind, int count) {
    _imported[kind] = (_imported[kind] ?? 0) + count;
  }

  void addSkipped(String kind) {
    _skipped[kind] = (_skipped[kind] ?? 0) + 1;
  }

  void addError(String error) {
    _errors.add(error);
  }

  Map<String, int> get imported => Map.unmodifiable(_imported);
  Map<String, int> get skipped => Map.unmodifiable(_skipped);
  List<String> get errors => List.unmodifiable(_errors);

  bool get hasErrors => _errors.isNotEmpty;

  int get totalImported => _imported.values.fold(0, (sum, count) => sum + count);
  int get totalSkipped => _skipped.values.fold(0, (sum, count) => sum + count);

  @override
  String toString() {
    final buffer = StringBuffer();
    buffer.writeln('Import Results:');
    buffer.writeln('  Imported: $_imported (total: $totalImported)');
    buffer.writeln('  Skipped: $_skipped (total: $totalSkipped)');
    if (hasErrors) {
      buffer.writeln('  Errors: ${_errors.length}');
      for (final error in _errors.take(5)) {
        buffer.writeln('    - $error');
      }
      if (_errors.length > 5) {
        buffer.writeln('    ... and ${_errors.length - 5} more');
      }
    }
    return buffer.toString();
  }
}

class ImportError extends Error {
  final String message;
  ImportError(this.message);

  @override
  String toString() => 'ImportError: $message';
}