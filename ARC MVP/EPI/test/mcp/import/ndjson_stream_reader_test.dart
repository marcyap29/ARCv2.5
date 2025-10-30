import 'dart:io';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/core/mcp/import/ndjson_stream_reader.dart';

void main() {
  group('NdjsonStreamReader', () {
    late NdjsonStreamReader reader;
    late Directory tempDir;

    setUp(() async {
      reader = NdjsonStreamReader();
      tempDir = await Directory.systemTemp.createTemp('ndjson_test');
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    group('readStream', () {
      test('should read valid NDJSON lines', () async {
        // Arrange
        final file = File('${tempDir.path}/test.jsonl');
        await file.writeAsString([
          '{"id":"1","type":"test","name":"first"}',
          '{"id":"2","type":"test","name":"second"}',
          '{"id":"3","type":"test","name":"third"}',
        ].join('\n'));

        // Act
        final lines = <String>[];
        await for (final line in reader.readStream(file)) {
          lines.add(line);
        }

        // Assert
        expect(lines, hasLength(3));
        expect(lines[0], contains('"id":"1"'));
        expect(lines[1], contains('"id":"2"'));
        expect(lines[2], contains('"id":"3"'));
      });

      test('should handle empty lines when skipEmptyLines is true', () async {
        // Arrange
        final file = File('${tempDir.path}/test.jsonl');
        await file.writeAsString([
          '{"id":"1","type":"test"}',
          '',
          '{"id":"2","type":"test"}',
          '   ',
          '{"id":"3","type":"test"}',
        ].join('\n'));

        // Act
        final lines = <String>[];
        await for (final line in reader.readStream(file)) {
          lines.add(line);
        }

        // Assert
        expect(lines, hasLength(3));
        expect(lines.every((line) => line.isNotEmpty), isTrue);
      });

      test('should include empty lines when skipEmptyLines is false', () async {
        // Arrange
        const config = NdjsonStreamConfig(skipEmptyLines: false);
        reader = NdjsonStreamReader(config: config);
        
        final file = File('${tempDir.path}/test.jsonl');
        await file.writeAsString([
          '{"id":"1","type":"test"}',
          '',
          '{"id":"2","type":"test"}',
        ].join('\n'));

        // Act
        final lines = <String>[];
        await for (final line in reader.readStream(file)) {
          lines.add(line);
        }

        // Assert
        expect(lines, hasLength(3));
        expect(lines[1], isEmpty);
      });

      test('should handle different line endings', () async {
        // Arrange
        final file = File('${tempDir.path}/test.jsonl');
        const content = '{"id":"1"}\r\n{"id":"2"}\n{"id":"3"}\r\n';
        await file.writeAsBytes(utf8.encode(content));

        // Act
        final lines = <String>[];
        await for (final line in reader.readStream(file)) {
          lines.add(line);
        }

        // Assert
        expect(lines, hasLength(3));
        expect(lines[0], equals('{"id":"1"}'));
        expect(lines[1], equals('{"id":"2"}'));
        expect(lines[2], equals('{"id":"3"}'));
      });

      test('should enforce maximum line length', () async {
        // Arrange
        const config = NdjsonStreamConfig(maxLineLength: 50);
        reader = NdjsonStreamReader(config: config);
        
        final file = File('${tempDir.path}/test.jsonl');
        final longLine = '{"id":"1","data":"${'x' * 100}"}';
        await file.writeAsString(longLine);

        // Act & Assert
        expect(
          () async {
            await for (final line in reader.readStream(file)) {
              // Should not reach here
            }
          },
          throwsA(isA<NdjsonStreamException>()),
        );
      });

      test('should validate JSON object format', () async {
        // Arrange
        final file = File('${tempDir.path}/test.jsonl');
        await file.writeAsString([
          '{"id":"1","type":"test"}',
          'invalid json line',
          '{"id":"2","type":"test"}',
        ].join('\n'));

        // Act & Assert
        expect(
          () async {
            await for (final line in reader.readStream(file)) {
              // Will throw on invalid line
            }
          },
          throwsA(isA<NdjsonStreamException>()),
        );
      });

      test('should handle file not found', () async {
        // Arrange
        final file = File('${tempDir.path}/nonexistent.jsonl');

        // Act & Assert
        expect(
          () async {
            await for (final line in reader.readStream(file)) {
              // Should not reach here
            }
          },
          throwsA(isA<NdjsonStreamException>()),
        );
      });

      test('should handle large files efficiently', () async {
        // Arrange
        final file = File('${tempDir.path}/large.jsonl');
        const lineCount = 10000;
        
        final buffer = StringBuffer();
        for (int i = 0; i < lineCount; i++) {
          buffer.writeln('{"id":"$i","index":$i,"data":"test_data_$i"}');
        }
        await file.writeAsString(buffer.toString());

        // Act
        final stopwatch = Stopwatch()..start();
        int count = 0;
        await for (final line in reader.readStream(file)) {
          count++;
          // Verify first and last lines
          if (count == 1) {
            expect(line, contains('"id":"0"'));
          }
          if (count == lineCount) {
            expect(line, contains('"id":"${lineCount - 1}"'));
          }
        }
        stopwatch.stop();

        // Assert
        expect(count, equals(lineCount));
        expect(stopwatch.elapsedMilliseconds, lessThan(5000)); // Should complete in under 5 seconds
      });

      test('should trim whitespace when configured', () async {
        // Arrange
        const config = NdjsonStreamConfig(trimLines: true);
        reader = NdjsonStreamReader(config: config);
        
        final file = File('${tempDir.path}/test.jsonl');
        await file.writeAsString([
          '  {"id":"1","type":"test"}  ',
          '\t{"id":"2","type":"test"}\t',
          '{"id":"3","type":"test"}',
        ].join('\n'));

        // Act
        final lines = <String>[];
        await for (final line in reader.readStream(file)) {
          lines.add(line);
        }

        // Assert
        expect(lines, hasLength(3));
        expect(lines[0], equals('{"id":"1","type":"test"}'));
        expect(lines[1], equals('{"id":"2","type":"test"}'));
        expect(lines[2], equals('{"id":"3","type":"test"}'));
      });
    });

    group('readAllLines', () {
      test('should read all lines into memory', () async {
        // Arrange
        final file = File('${tempDir.path}/test.jsonl');
        await file.writeAsString([
          '{"id":"1","type":"test"}',
          '{"id":"2","type":"test"}',
          '{"id":"3","type":"test"}',
        ].join('\n'));

        // Act
        final lines = await reader.readAllLines(file);

        // Assert
        expect(lines, hasLength(3));
        expect(lines[0], contains('"id":"1"'));
        expect(lines[1], contains('"id":"2"'));
        expect(lines[2], contains('"id":"3"'));
      });
    });

    group('countLines', () {
      test('should count lines without loading content', () async {
        // Arrange
        final file = File('${tempDir.path}/test.jsonl');
        await file.writeAsString([
          '{"id":"1","type":"test"}',
          '{"id":"2","type":"test"}',
          '{"id":"3","type":"test"}',
        ].join('\n'));

        // Act
        final count = await reader.countLines(file);

        // Assert
        expect(count, equals(3));
      });

      test('should count empty file as zero lines', () async {
        // Arrange
        final file = File('${tempDir.path}/empty.jsonl');
        await file.writeAsString('');

        // Act
        final count = await reader.countLines(file);

        // Assert
        expect(count, equals(0));
      });
    });

    group('validateStructure', () {
      test('should validate well-formed NDJSON', () async {
        // Arrange
        final file = File('${tempDir.path}/test.jsonl');
        await file.writeAsString([
          '{"id":"1","type":"test","valid":true}',
          '{"id":"2","type":"test","valid":true}',
          '{"id":"3","type":"test","valid":true}',
        ].join('\n'));

        // Act
        final result = await reader.validateStructure(file);

        // Assert
        expect(result.isValid, isTrue);
        expect(result.totalLines, equals(3));
        expect(result.validLines, equals(3));
        expect(result.invalidLines, equals(0));
        expect(result.errors, isEmpty);
      });

      test('should detect invalid JSON lines', () async {
        // Arrange
        final file = File('${tempDir.path}/test.jsonl');
        await file.writeAsString([
          '{"id":"1","type":"test"}',
          'invalid json line',
          '{"id":"2","type":"test"}',
          '{"incomplete":',
          '{"id":"3","type":"test"}',
        ].join('\n'));

        // Act
        final result = await reader.validateStructure(file);

        // Assert
        expect(result.isValid, isFalse);
        expect(result.totalLines, equals(5));
        expect(result.validLines, equals(3));
        expect(result.invalidLines, equals(2));
        expect(result.errors, hasLength(2));
      });

      test('should limit error reporting', () async {
        // Arrange
        final file = File('${tempDir.path}/test.jsonl');
        final buffer = StringBuffer();
        // Add 105 invalid lines to test error limit
        for (int i = 0; i < 105; i++) {
          buffer.writeln('invalid json line $i');
        }
        await file.writeAsString(buffer.toString());

        // Act
        final result = await reader.validateStructure(file);

        // Assert
        expect(result.isValid, isFalse);
        expect(result.errors.length, equals(101)); // 100 errors + 1 "too many errors" message
        expect(result.errors.last, contains('Too many errors'));
      });
    });

    group('readBatches', () {
      test('should read lines in batches', () async {
        // Arrange
        final file = File('${tempDir.path}/test.jsonl');
        await file.writeAsString([
          '{"id":"1"}',
          '{"id":"2"}',
          '{"id":"3"}',
          '{"id":"4"}',
          '{"id":"5"}',
        ].join('\n'));

        // Act
        final batches = <List<String>>[];
        await for (final batch in reader.readBatches(file, 2)) {
          batches.add(batch);
        }

        // Assert
        expect(batches, hasLength(3));
        expect(batches[0], hasLength(2));
        expect(batches[1], hasLength(2));
        expect(batches[2], hasLength(1)); // Remaining lines
        
        expect(batches[0][0], contains('"id":"1"'));
        expect(batches[0][1], contains('"id":"2"'));
        expect(batches[2][0], contains('"id":"5"'));
      });
    });

    group('NdjsonStreamConfig', () {
      test('should use default configuration values', () async {
        // Arrange
        const config = NdjsonStreamConfig();

        // Assert
        expect(config.maxLineLength, equals(10 * 1024 * 1024));
        expect(config.bufferSize, equals(64 * 1024));
        expect(config.maxBufferedLines, equals(1000));
        expect(config.skipEmptyLines, isTrue);
        expect(config.trimLines, isTrue);
      });

      test('should allow custom configuration', () async {
        // Arrange
        const config = NdjsonStreamConfig(
          maxLineLength: 1024,
          bufferSize: 512,
          maxBufferedLines: 100,
          skipEmptyLines: false,
          trimLines: false,
        );

        // Assert
        expect(config.maxLineLength, equals(1024));
        expect(config.bufferSize, equals(512));
        expect(config.maxBufferedLines, equals(100));
        expect(config.skipEmptyLines, isFalse);
        expect(config.trimLines, isFalse);
      });
    });

    group('NdjsonStreamStats', () {
      test('should calculate performance metrics', () async {
        // Arrange
        final stats = NdjsonStreamStats();
        stats.linesRead = 1000;
        stats.bytesRead = 50000;
        stats.processingTime = const Duration(milliseconds: 500);

        // Act & Assert
        expect(stats.linesPerSecond, greaterThan(0));
        expect(stats.mbPerSecond, greaterThan(0));
        expect(stats.toString(), contains('lines: 1000'));
        expect(stats.toString(), contains('MB'));
      });

      test('should handle zero processing time', () async {
        // Arrange
        final stats = NdjsonStreamStats();
        stats.linesRead = 100;
        stats.bytesRead = 5000;
        stats.processingTime = Duration.zero;

        // Act & Assert
        expect(stats.linesPerSecond, equals(0.0));
        expect(stats.mbPerSecond, equals(0.0));
      });
    });
  });
}