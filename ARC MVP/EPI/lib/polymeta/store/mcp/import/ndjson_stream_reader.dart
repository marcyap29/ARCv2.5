import 'dart:io';
import 'dart:convert';
import 'dart:async';

/// Configuration for NDJSON stream reading
class NdjsonStreamConfig {
  /// Maximum line length to prevent memory issues
  final int maxLineLength;
  
  /// Buffer size for reading chunks
  final int bufferSize;
  
  /// Maximum number of lines to buffer before applying back-pressure
  final int maxBufferedLines;
  
  /// Whether to skip empty lines
  final bool skipEmptyLines;
  
  /// Whether to trim whitespace from lines
  final bool trimLines;

  const NdjsonStreamConfig({
    this.maxLineLength = 10 * 1024 * 1024, // 10MB per line
    this.bufferSize = 64 * 1024, // 64KB buffer
    this.maxBufferedLines = 1000,
    this.skipEmptyLines = true,
    this.trimLines = true,
  });
}

/// Exception thrown during NDJSON stream reading
class NdjsonStreamException implements Exception {
  final String message;
  final int? lineNumber;
  final dynamic cause;

  const NdjsonStreamException(this.message, {this.lineNumber, this.cause});

  @override
  String toString() {
    final lineInfo = lineNumber != null ? ' at line $lineNumber' : '';
    final causeInfo = cause != null ? ' (caused by: $cause)' : '';
    return 'NdjsonStreamException: $message$lineInfo$causeInfo';
  }
}

/// Statistics for NDJSON stream reading
class NdjsonStreamStats {
  int linesRead = 0;
  int bytesRead = 0;
  int emptyLinesSkipped = 0;
  int invalidLinesSkipped = 0;
  Duration processingTime = Duration.zero;
  
  double get linesPerSecond => 
    processingTime.inMicroseconds > 0 
      ? linesRead / (processingTime.inMicroseconds / 1000000.0)
      : 0.0;
      
  double get mbPerSecond => 
    processingTime.inMicroseconds > 0 
      ? (bytesRead / 1024 / 1024) / (processingTime.inMicroseconds / 1000000.0)
      : 0.0;

  @override
  String toString() {
    return 'NdjsonStreamStats(lines: $linesRead, bytes: ${(bytesRead / 1024 / 1024).toStringAsFixed(2)}MB, '
           'speed: ${linesPerSecond.toStringAsFixed(0)} lines/sec, ${mbPerSecond.toStringAsFixed(2)} MB/sec)';
  }
}

/// Back-pressure aware NDJSON stream reader
/// 
/// Efficiently reads large NDJSON files line by line with memory management,
/// back-pressure control, and error recovery.
class NdjsonStreamReader {
  final NdjsonStreamConfig config;
  
  NdjsonStreamReader({NdjsonStreamConfig? config}) 
    : config = config ?? const NdjsonStreamConfig();

  /// Read NDJSON file as a stream of JSON strings
  /// 
  /// Returns a stream that yields one JSON string per line.
  /// Implements back-pressure to prevent memory exhaustion.
  Stream<String> readStream(File file) async* {
    if (!file.existsSync()) {
      throw NdjsonStreamException('File does not exist: ${file.path}');
    }

    final stats = NdjsonStreamStats();
    final stopwatch = Stopwatch()..start();
    
    RandomAccessFile? raf;
    try {
      raf = await file.open(mode: FileMode.read);
      final fileSize = await raf.length();
      
      final buffer = <int>[];
      final chunk = List<int>.filled(config.bufferSize, 0);
      int lineNumber = 0;
      int position = 0;
      
      // Stream controller with back-pressure
      StreamController<String>? controller;
      bool isPaused = false;
      
      while (position < fileSize) {
        // Check for back-pressure
        if (controller != null && controller.isPaused) {
          isPaused = true;
          await Future.delayed(const Duration(milliseconds: 1));
          continue;
        }
        
        if (isPaused) {
          isPaused = false;
          // Small delay after resuming to prevent tight loops
          await Future.delayed(const Duration(microseconds: 100));
        }

        // Read chunk
        final bytesRead = await raf.readInto(chunk, 0, config.bufferSize);
        if (bytesRead == 0) break;
        
        stats.bytesRead += bytesRead;
        
        // Process bytes looking for newlines
        for (int i = 0; i < bytesRead; i++) {
          final byte = chunk[i];
          
          if (byte == 0x0A) { // \n
            // Found line ending
            lineNumber++;
            
            if (buffer.isNotEmpty) {
              try {
                final line = _processLine(buffer, lineNumber, stats);
                if (line != null) {
                  yield line;
                  stats.linesRead++;
                }
              } catch (e) {
                throw NdjsonStreamException(
                  'Failed to process line', 
                  lineNumber: lineNumber, 
                  cause: e
                );
              }
              buffer.clear();
            } else if (!config.skipEmptyLines) {
              yield '';
              stats.linesRead++;
            } else {
              stats.emptyLinesSkipped++;
            }
          } else if (byte != 0x0D) { // Skip \r
            buffer.add(byte);
            
            // Check line length limit
            if (buffer.length > config.maxLineLength) {
              throw NdjsonStreamException(
                'Line exceeds maximum length of ${config.maxLineLength} bytes',
                lineNumber: lineNumber + 1,
              );
            }
          }
        }
        
        position += bytesRead;
        
        // Yield control periodically for back-pressure
        if (lineNumber % config.maxBufferedLines == 0) {
          await Future.delayed(Duration.zero);
        }
      }
      
      // Process final line if buffer has content
      if (buffer.isNotEmpty) {
        lineNumber++;
        final line = _processLine(buffer, lineNumber, stats);
        if (line != null) {
          yield line;
          stats.linesRead++;
        }
      }
      
    } catch (e) {
      throw NdjsonStreamException('Error reading file: ${file.path}', cause: e);
    } finally {
      await raf?.close();
      stopwatch.stop();
      stats.processingTime = stopwatch.elapsed;
      
      // Log final statistics
      print('NDJSON stream completed: $stats');
    }
  }

  /// Process a single line from the buffer
  String? _processLine(List<int> buffer, int lineNumber, NdjsonStreamStats stats) {
    try {
      String line = utf8.decode(buffer);
      
      if (config.trimLines) {
        line = line.trim();
      }
      
      if (line.isEmpty && config.skipEmptyLines) {
        stats.emptyLinesSkipped++;
        return null;
      }
      
      // Basic JSON validation - check if line starts and ends with { }
      if (line.isNotEmpty && (!line.startsWith('{') || !line.endsWith('}'))) {
        stats.invalidLinesSkipped++;
        throw const NdjsonStreamException('Line does not appear to be valid JSON object');
      }
      
      return line;
    } catch (e) {
      stats.invalidLinesSkipped++;
      rethrow;
    }
  }

  /// Read entire NDJSON file into memory (for smaller files)
  Future<List<String>> readAllLines(File file) async {
    final lines = <String>[];
    await for (final line in readStream(file)) {
      lines.add(line);
    }
    return lines;
  }

  /// Count lines in NDJSON file without loading content
  Future<int> countLines(File file) async {
    int count = 0;
    await for (final _ in readStream(file)) {
      count++;
    }
    return count;
  }

  /// Validate NDJSON file structure without processing content
  Future<NdjsonValidationResult> validateStructure(File file) async {
    final result = NdjsonValidationResult();
    final stopwatch = Stopwatch()..start();
    
    try {
      await for (final line in readStream(file)) {
        result.totalLines++;
        
        // Try to parse as JSON to validate structure
        try {
          jsonDecode(line);
          result.validLines++;
        } catch (e) {
          result.invalidLines++;
          result.errors.add('Line ${result.totalLines}: Invalid JSON - $e');
          
          // Stop after too many errors
          if (result.errors.length > 100) {
            result.errors.add('Too many errors, stopping validation...');
            break;
          }
        }
      }
    } catch (e) {
      result.errors.add('File reading error: $e');
    }
    
    stopwatch.stop();
    result.processingTime = stopwatch.elapsed;
    
    return result;
  }

  /// Read NDJSON with progress callback
  Stream<String> readStreamWithProgress(
    File file,
    void Function(double progress, NdjsonStreamStats stats) onProgress,
  ) async* {
    final fileSize = await file.length();
    final stats = NdjsonStreamStats();
    
    await for (final line in readStream(file)) {
      yield line;
      
      // Calculate progress based on bytes read
      final progress = fileSize > 0 ? (stats.bytesRead / fileSize).clamp(0.0, 1.0) : 0.0;
      onProgress(progress, stats);
    }
  }

  /// Batch process NDJSON with configurable batch size
  Stream<List<String>> readBatches(File file, int batchSize) async* {
    final batch = <String>[];
    
    await for (final line in readStream(file)) {
      batch.add(line);
      
      if (batch.length >= batchSize) {
        yield List.from(batch);
        batch.clear();
      }
    }
    
    // Yield remaining lines
    if (batch.isNotEmpty) {
      yield batch;
    }
  }
}

/// Result of NDJSON structure validation
class NdjsonValidationResult {
  int totalLines = 0;
  int validLines = 0;
  int invalidLines = 0;
  List<String> errors = [];
  Duration processingTime = Duration.zero;
  
  bool get isValid => invalidLines == 0 && errors.isEmpty;
  double get validPercent => totalLines > 0 ? (validLines / totalLines) * 100 : 0.0;
  
  @override
  String toString() {
    return 'NdjsonValidationResult(total: $totalLines, valid: $validLines, '
           'invalid: $invalidLines, valid%: ${validPercent.toStringAsFixed(1)}%, '
           'errors: ${errors.length}, time: ${processingTime.inMilliseconds}ms)';
  }
}