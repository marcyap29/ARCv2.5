#!/usr/bin/env dart
// Test script to verify MCP export creates proper journal_entry nodes
// Usage: dart test_mcp_export.dart

import 'dart:io';
import 'dart:convert';

void main() async {
  print('🧪 Testing MCP Export Structure');

  // Look for existing MCP export directories
  final appDocuments = Directory('/Users/mymac/Documents');
  final mcpExportsDir = Directory('${appDocuments.path}/mcp_exports');

  if (!await mcpExportsDir.exists()) {
    print('❌ No MCP exports directory found at ${mcpExportsDir.path}');
    print('Please export some data from the app first.');
    return;
  }

  // Find the most recent export
  final exports = await mcpExportsDir
      .list()
      .where((entity) => entity is Directory)
      .cast<Directory>()
      .toList();

  if (exports.isEmpty) {
    print('❌ No export directories found');
    print('Please export some data from the app first.');
    return;
  }

  // Sort by name (timestamp-based) to get the most recent
  exports.sort((a, b) => b.path.compareTo(a.path));
  final latestExport = exports.first;

  print('🔍 Examining latest export: ${latestExport.path}');

  // Check for expected files
  final manifestFile = File('${latestExport.path}/manifest.json');
  final nodesFile = File('${latestExport.path}/nodes.jsonl');
  final edgesFile = File('${latestExport.path}/edges.jsonl');

  print('📋 Manifest exists: ${await manifestFile.exists()}');
  print('📄 Nodes file exists: ${await nodesFile.exists()}');
  print('🔗 Edges file exists: ${await edgesFile.exists()}');

  if (!await nodesFile.exists()) {
    print('❌ nodes.jsonl not found');
    return;
  }

  // Examine the nodes.jsonl file
  final nodeLines = await nodesFile.readAsLines();
  print('📊 Total nodes in file: ${nodeLines.length}');

  int journalEntries = 0;
  int otherNodes = 0;

  for (int i = 0; i < nodeLines.length; i++) {
    try {
      final nodeJson = jsonDecode(nodeLines[i]);
      final nodeType = nodeJson['type'] as String?;

      if (nodeType == 'journal_entry') {
        journalEntries++;
        if (journalEntries <= 3) {  // Show details for first 3 journal entries
          print('\n📝 Journal Entry ${journalEntries}:');
          print('  ID: ${nodeJson['id']}');
          print('  Type: ${nodeJson['type']}');
          print('  Has contentSummary: ${nodeJson['contentSummary'] != null}');

          if (nodeJson['contentSummary'] != null) {
            final content = nodeJson['contentSummary'] as String;
            print('  Content length: ${content.length} chars');
            print('  Content preview: ${content.length > 100 ? "${content.substring(0, 100)}..." : content}');
          }

          print('  Has metadata: ${nodeJson['metadata'] != null}');
          if (nodeJson['metadata'] != null) {
            final metadata = nodeJson['metadata'] as Map<String, dynamic>;
            print('  Metadata keys: ${metadata.keys.toList()}');

            if (metadata.containsKey('journal_entry')) {
              final journalMeta = metadata['journal_entry'] as Map<String, dynamic>?;
              print('  Journal metadata keys: ${journalMeta?.keys.toList()}');
              if (journalMeta?['content'] != null) {
                final backupContent = journalMeta!['content'] as String;
                print('  Backup content length: ${backupContent.length} chars');
              }
            }
          }

          print('  Has narrative: ${nodeJson['narrative'] != null}');
          print('  Keywords: ${nodeJson['keywords']}');
          print('  Emotions: ${nodeJson['emotions']}');
        }
      } else {
        otherNodes++;
      }
    } catch (e) {
      print('❌ Error parsing node at line ${i + 1}: $e');
    }
  }

  print('\n📈 Summary:');
  print('  Total nodes: ${nodeLines.length}');
  print('  Journal entries: $journalEntries');
  print('  Other nodes: $otherNodes');

  // Check manifest for expected counts
  if (await manifestFile.exists()) {
    try {
      final manifestContent = await manifestFile.readAsString();
      final manifest = jsonDecode(manifestContent);
      print('\n📋 Manifest Summary:');
      print('  Bundle ID: ${manifest['bundle_id']}');
      print('  Schema version: ${manifest['schema_version']}');
      if (manifest['counts'] != null) {
        final counts = manifest['counts'] as Map<String, dynamic>;
        print('  Expected nodes: ${counts['nodes']}');
        print('  Expected edges: ${counts['edges']}');
        print('  Expected pointers: ${counts['pointers']}');
        print('  Expected embeddings: ${counts['embeddings']}');
      }
    } catch (e) {
      print('❌ Error reading manifest: $e');
    }
  }

  print('\n✅ Export structure analysis complete');
}