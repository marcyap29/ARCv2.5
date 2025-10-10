#!/usr/bin/env dart

/// Recovery script for ARC MVP app
/// Run this if the app fails to start after restart
/// 
/// Usage: dart recovery_script.dart

import 'dart:io';

void main() async {
  print('🔄 ARC MVP Recovery Script');
  print('========================');
  print('');
  
  print('This script will help recover your app if it fails to start.');
  print('It handles issues from:');
  print('  • Phone restart');
  print('  • App force-quit (swipe up)');
  print('  • Database corruption');
  print('  • Widget lifecycle errors');
  print('');
  print('It will clear corrupted data and reset the app to a clean state.');
  print('');
  
  stdout.write('Do you want to proceed? (y/N): ');
  final input = stdin.readLineSync();
  
  if (input?.toLowerCase() != 'y') {
    print('Recovery cancelled.');
    exit(0);
  }
  
  print('');
  print('🔍 Checking for Flutter...');
  
  try {
    final result = await Process.run('flutter', ['--version']);
    if (result.exitCode == 0) {
      print('✅ Flutter found');
    } else {
      print('❌ Flutter not found. Please install Flutter first.');
      exit(1);
    }
  } catch (e) {
    print('❌ Flutter not found. Please install Flutter first.');
    exit(1);
  }
  
  print('');
  print('🧹 Cleaning Flutter build cache...');
  
  try {
    await Process.run('flutter', ['clean']);
    print('✅ Build cache cleaned');
  } catch (e) {
    print('⚠️  Warning: Could not clean build cache: $e');
  }
  
  print('');
  print('📱 Cleaning app data...');
  
  // Clean iOS simulator data
  try {
    final homeDir = Platform.environment['HOME'];
    if (homeDir != null) {
      final simulatorDir = '$homeDir/Library/Developer/CoreSimulator/Devices';
      final dir = Directory(simulatorDir);
      if (await dir.exists()) {
        await for (final device in dir.list()) {
          if (device is Directory) {
            final appDir = Directory('${device.path}/data/Containers/Data/Application');
            if (await appDir.exists()) {
              await for (final app in appDir.list()) {
                if (app is Directory) {
                  final documentsDir = Directory('${app.path}/Documents');
                  if (await documentsDir.exists()) {
                    await documentsDir.delete(recursive: true);
                    print('✅ Cleared app data for device: ${device.path.split('/').last}');
                  }
                }
              }
            }
          }
        }
      }
    }
  } catch (e) {
    print('⚠️  Warning: Could not clean app data: $e');
  }
  
  print('');
  print('🔧 Getting Flutter dependencies...');
  
  try {
    await Process.run('flutter', ['pub', 'get']);
    print('✅ Dependencies updated');
  } catch (e) {
    print('❌ Failed to get dependencies: $e');
    exit(1);
  }
  
  print('');
  print('🚀 Attempting to run the app...');
  
  try {
    final process = await Process.start('flutter', ['run', '--debug']);
    
    // Wait a bit to see if the app starts successfully
    await Future.delayed(const Duration(seconds: 10));
    
    print('❌ App failed to start. Exit code: ${process.exitCode}');
    print('Check the error messages above for more details.');
    } catch (e) {
    print('❌ Failed to run app: $e');
    exit(1);
  }
  
  print('');
  print('🎉 Recovery script completed!');
}
