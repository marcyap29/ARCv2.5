import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'dart:io';
import 'dart:convert';
import 'package:archive/archive_io.dart';
import '../../prism/mcp/bundle_doctor/bundle_doctor.dart';
import '../../prism/mcp/bundle_doctor/mcp_models.dart';

// States
abstract class McpValidationState extends Equatable {
  const McpValidationState();

  @override
  List<Object?> get props => [];
}

class McpValidationInitial extends McpValidationState {
  const McpValidationInitial();
}

class McpValidationLoading extends McpValidationState {
  final String message;

  const McpValidationLoading(this.message);

  @override
  List<Object?> get props => [message];
}

class McpValidationSuccess extends McpValidationState {
  final BundleValidationResult result;
  final String bundlePath;
  final bool autoRepaired;

  const McpValidationSuccess({
    required this.result,
    required this.bundlePath,
    this.autoRepaired = false,
  });

  @override
  List<Object?> get props => [result, bundlePath, autoRepaired];
}

class McpValidationError extends McpValidationState {
  final String message;

  const McpValidationError(this.message);

  @override
  List<Object?> get props => [message];
}

// Cubit
class McpValidationCubit extends Cubit<McpValidationState> {
  McpValidationCubit() : super(const McpValidationInitial());

  /// Validate an MCP bundle from a file or directory
  Future<void> validateBundle({
    required String path,
    bool autoRepair = true,
  }) async {
    try {
      emit(const McpValidationLoading('Loading bundle...'));

      final file = File(path);
      final directory = Directory(path);

      Map<String, dynamic> bundleData;
      String bundlePath = path;

      if (await file.exists() && path.endsWith('.zip')) {
        // Handle ZIP file
        emit(const McpValidationLoading('Extracting ZIP archive...'));
        bundleData = await _extractAndReadZip(file);
      } else if (await directory.exists()) {
        // Handle directory with manifest.json
        emit(const McpValidationLoading('Reading bundle directory...'));
        bundleData = await _readBundleFromDirectory(directory);
      } else if (await file.exists() && path.endsWith('.json')) {
        // Handle single JSON file
        emit(const McpValidationLoading('Reading JSON file...'));
        final content = await file.readAsString();
        bundleData = jsonDecode(content) as Map<String, dynamic>;
      } else {
        throw Exception('Invalid bundle path. Expected .zip file, directory with manifest.json, or .json file.');
      }

      emit(const McpValidationLoading('Validating bundle structure...'));

      if (autoRepair) {
        // Repair and validate
        final repairedBundle = BundleDoctor.repair(bundleData);
        final validationResult = BundleDoctor.validate(repairedBundle);

        emit(McpValidationSuccess(
          result: validationResult,
          bundlePath: bundlePath,
          autoRepaired: repairedBundle.repairLog.isNotEmpty,
        ));
      } else {
        // Validate only (still need to create bundle object)
        final bundle = BundleDoctor.repair(bundleData);
        final validationResult = BundleDoctor.validate(bundle);

        emit(McpValidationSuccess(
          result: validationResult,
          bundlePath: bundlePath,
          autoRepaired: false,
        ));
      }
    } catch (e) {
      emit(McpValidationError('Validation failed: $e'));
    }
  }

  /// Extract and read bundle from ZIP file
  Future<Map<String, dynamic>> _extractAndReadZip(File zipFile) async {
    try {
      final bytes = await zipFile.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes, verify: true);

      // Look for manifest.json in the archive
      ArchiveFile? manifestFile;
      for (final file in archive.files) {
        if (file.name.endsWith('manifest.json') && file.isFile) {
          manifestFile = file;
          break;
        }
      }

      if (manifestFile == null) {
        throw Exception('No manifest.json found in ZIP archive');
      }

      final manifestContent = utf8.decode(manifestFile.content as List<int>);
      final manifestData = jsonDecode(manifestContent) as Map<String, dynamic>;

      // Build complete bundle data structure
      final bundleData = <String, dynamic>{
        'schemaVersion': manifestData['schema_version'] ?? 'mcp-1.0',
        'bundleId': manifestData['bundle_id'],
        'pointers': <Map<String, dynamic>>[],
        'nodes': <Map<String, dynamic>>[],
        'edges': <Map<String, dynamic>>[],
      };

      // Read nodes.jsonl if exists
      for (final file in archive.files) {
        if (file.name.endsWith('nodes.jsonl') && file.isFile) {
          final content = utf8.decode(file.content as List<int>);
          final lines = content.split('\n').where((line) => line.trim().isNotEmpty);
          for (final line in lines) {
            try {
              final node = jsonDecode(line) as Map<String, dynamic>;
              bundleData['nodes'].add(node);
            } catch (e) {
              // Skip malformed lines
            }
          }
          break;
        }
      }

      // Read edges.jsonl if exists
      for (final file in archive.files) {
        if (file.name.endsWith('edges.jsonl') && file.isFile) {
          final content = utf8.decode(file.content as List<int>);
          final lines = content.split('\n').where((line) => line.trim().isNotEmpty);
          for (final line in lines) {
            try {
              final edge = jsonDecode(line) as Map<String, dynamic>;
              bundleData['edges'].add(edge);
            } catch (e) {
              // Skip malformed lines
            }
          }
          break;
        }
      }

      // Read pointers.jsonl if exists
      for (final file in archive.files) {
        if (file.name.endsWith('pointers.jsonl') && file.isFile) {
          final content = utf8.decode(file.content as List<int>);
          final lines = content.split('\n').where((line) => line.trim().isNotEmpty);
          for (final line in lines) {
            try {
              final pointer = jsonDecode(line) as Map<String, dynamic>;
              bundleData['pointers'].add(pointer);
            } catch (e) {
              // Skip malformed lines
            }
          }
          break;
        }
      }

      return bundleData;
    } catch (e) {
      throw Exception('Failed to extract ZIP: $e');
    }
  }

  /// Read bundle from directory structure
  Future<Map<String, dynamic>> _readBundleFromDirectory(Directory dir) async {
    final manifestFile = File('${dir.path}/manifest.json');
    if (!await manifestFile.exists()) {
      throw Exception('No manifest.json found in directory: ${dir.path}');
    }

    final manifestContent = await manifestFile.readAsString();
    final manifestData = jsonDecode(manifestContent) as Map<String, dynamic>;

    // Build complete bundle data structure
    final bundleData = <String, dynamic>{
      'schemaVersion': manifestData['schema_version'] ?? 'mcp-1.0',
      'bundleId': manifestData['bundle_id'],
      'pointers': <Map<String, dynamic>>[],
      'nodes': <Map<String, dynamic>>[],
      'edges': <Map<String, dynamic>>[],
    };

    // Read nodes.jsonl if exists
    final nodesFile = File('${dir.path}/nodes.jsonl');
    if (await nodesFile.exists()) {
      final content = await nodesFile.readAsString();
      final lines = content.split('\n').where((line) => line.trim().isNotEmpty);
      for (final line in lines) {
        try {
          final node = jsonDecode(line) as Map<String, dynamic>;
          bundleData['nodes'].add(node);
        } catch (e) {
          // Skip malformed lines
        }
      }
    }

    // Read edges.jsonl if exists
    final edgesFile = File('${dir.path}/edges.jsonl');
    if (await edgesFile.exists()) {
      final content = await edgesFile.readAsString();
      final lines = content.split('\n').where((line) => line.trim().isNotEmpty);
      for (final line in lines) {
        try {
          final edge = jsonDecode(line) as Map<String, dynamic>;
          bundleData['edges'].add(edge);
        } catch (e) {
          // Skip malformed lines
        }
      }
    }

    // Read pointers.jsonl if exists
    final pointersFile = File('${dir.path}/pointers.jsonl');
    if (await pointersFile.exists()) {
      final content = await pointersFile.readAsString();
      final lines = content.split('\n').where((line) => line.trim().isNotEmpty);
      for (final line in lines) {
        try {
          final pointer = jsonDecode(line) as Map<String, dynamic>;
          bundleData['pointers'].add(pointer);
        } catch (e) {
          // Skip malformed lines
        }
      }
    }

    return bundleData;
  }

  /// Reset to initial state
  void reset() {
    emit(const McpValidationInitial());
  }
}
