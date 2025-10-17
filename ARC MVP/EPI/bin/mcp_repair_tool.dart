#!/usr/bin/env dart

/// CLI tool for analyzing and repairing MCP files
/// Usage: dart run bin/mcp_repair_tool.dart <command> <file_path>

import 'dart:io';
import 'package:my_app/mcp/utils/mcp_file_repair.dart';

void main(List<String> arguments) async {
  if (arguments.length < 2) {
    print('Usage: dart run bin/mcp_repair_tool.dart <command> <file_path>');
    print('Commands:');
    print('  analyze  - Analyze MCP file for corruption');
    print('  repair   - Repair MCP file and separate chat/journal data');
    print('  help     - Show this help message');
    exit(1);
  }

  final command = arguments[0];
  final filePath = arguments[1];

  switch (command) {
    case 'analyze':
      await analyzeFile(filePath);
      break;
    case 'repair':
      await repairFile(filePath);
      break;
    case 'help':
      printHelp();
      break;
    default:
      print('Unknown command: $command');
      print('Use "help" to see available commands.');
      exit(1);
  }
}

Future<void> analyzeFile(String filePath) async {
  print('🔍 Analyzing MCP file: $filePath');
  print('─' * 50);
  
  try {
    final result = await McpFileRepair.analyzeMcpFile(filePath);
    
    print('📊 Analysis Results:');
    print('  Total Nodes: ${result.totalNodes}');
    print('  Chat Nodes: ${result.chatNodes}');
    print('  Journal Nodes: ${result.journalNodes}');
    print('  Corrupted Nodes: ${result.corruptedNodes}');
    print('  Has Corruption: ${result.hasCorruption ? "❌ YES" : "✅ NO"}');
    
    if (result.error != null) {
      print('  Error: ${result.error}');
    }
    
    if (result.manifest != null) {
      print('\n📋 Manifest Info:');
      print('  Version: ${result.manifest!.version}');
      print('  Created: ${result.manifest!.createdAt}');
      print('  Bundle ID: ${result.manifest!.bundleId}');
    }
    
    print('\n💡 Recommendation:');
    if (result.hasCorruption) {
      print('  This file has corruption and should be repaired.');
      print('  Run: dart run bin/mcp_repair_tool.dart repair "$filePath"');
    } else {
      print('  This file appears to be clean and properly structured.');
    }
    
  } catch (e) {
    print('❌ Error analyzing file: $e');
    exit(1);
  }
}

Future<void> repairFile(String filePath) async {
  print('🔧 Repairing MCP file: $filePath');
  print('─' * 50);
  
  try {
    // First analyze the original file
    print('📊 Original file analysis:');
    final originalResult = await McpFileRepair.analyzeMcpFile(filePath);
    print('  Total Nodes: ${originalResult.totalNodes}');
    print('  Chat Nodes: ${originalResult.chatNodes}');
    print('  Journal Nodes: ${originalResult.journalNodes}');
    print('  Corrupted Nodes: ${originalResult.corruptedNodes}');
    print('  Has Corruption: ${originalResult.hasCorruption ? "❌ YES" : "✅ NO"}');
    
    // Repair the file
    print('\n🔧 Repairing file...');
    final repairedPath = await McpFileRepair.repairMcpFile(filePath);
    
    print('✅ File repaired successfully!');
    print('📁 Repaired file saved to: $repairedPath');
    
    // Analyze the repaired file
    print('\n📊 Repaired file analysis:');
    final repairedResult = await McpFileRepair.analyzeMcpFile(repairedPath);
    print('  Total Nodes: ${repairedResult.totalNodes}');
    print('  Chat Nodes: ${repairedResult.chatNodes}');
    print('  Journal Nodes: ${repairedResult.journalNodes}');
    print('  Corrupted Nodes: ${repairedResult.corruptedNodes}');
    print('  Has Corruption: ${repairedResult.hasCorruption ? "❌ YES" : "✅ NO"}');
    
    print('\n🎉 Repair completed successfully!');
    print('   Chat and journal data have been properly separated.');
    
  } catch (e) {
    print('❌ Error repairing file: $e');
    exit(1);
  }
}

void printHelp() {
  print('MCP Repair Tool');
  print('===============');
  print('');
  print('This tool helps analyze and repair MCP (Memory Capture Protocol) files');
  print('by separating chat messages from journal entries.');
  print('');
  print('Commands:');
  print('  analyze <file_path>  - Analyze MCP file for corruption');
  print('  repair <file_path>   - Repair MCP file and separate chat/journal data');
  print('  help                 - Show this help message');
  print('');
  print('Examples:');
  print('  dart run bin/mcp_repair_tool.dart analyze "path/to/file.zip"');
  print('  dart run bin/mcp_repair_tool.dart repair "path/to/file.zip"');
  print('');
  print('The repair command will create a new file with "_repaired_" in the name.');
}
