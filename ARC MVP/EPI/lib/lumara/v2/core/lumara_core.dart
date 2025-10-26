// lib/lumara/v2/core/lumara_core.dart
// LUMARA v2.0 - Complete Reconstruction
// Simplified, unified access to all LUMARA capabilities

import 'dart:async';
import 'package:flutter/foundation.dart';
import '../data/lumara_context.dart';
import '../data/lumara_media.dart';
import '../services/lumara_service.dart';
import '../ui/lumara_interface.dart';
import '../config/lumara_config.dart';

/// LUMARA v2.0 Core - Single entry point for all LUMARA functionality
class LumaraCore {
  static LumaraCore? _instance;
  static LumaraCore get instance => _instance ??= LumaraCore._();
  
  LumaraCore._();
  
  // Core services
  late final LumaraService _service;
  late final LumaraConfig _config;
  late final LumaraContext _context;
  late final LumaraMedia _media;
  
  // State
  bool _isInitialized = false;
  LumaraInterface? _currentInterface;
  
  /// Initialize LUMARA v2.0
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      debugPrint('LUMARA v2.0: Initializing core...');
      
      // Initialize configuration
      _config = LumaraConfig();
      await _config.initialize();
      
      // Initialize services
      _service = LumaraService(_config);
      await _service.initialize();
      
      // Initialize context and media access
      _context = LumaraContext(_service);
      _media = LumaraMedia(_service);
      
      _isInitialized = true;
      debugPrint('LUMARA v2.0: Core initialized successfully');
    } catch (e) {
      debugPrint('LUMARA v2.0: Initialization failed: $e');
      rethrow;
    }
  }
  
  /// Get the unified LUMARA interface
  LumaraInterface get interface {
    if (!_isInitialized) {
      throw StateError('LUMARA v2.0 not initialized. Call initialize() first.');
    }
    return _currentInterface ??= LumaraInterface(_service, _context, _media);
  }
  
  /// Check if LUMARA is ready to use
  bool get isReady => _isInitialized && _service.isReady;
  
  /// Get current configuration
  LumaraConfig get config => _config;
  
  /// Get context access
  LumaraContext get context => _context;
  
  /// Get media access
  LumaraMedia get media => _media;
  
  /// Shutdown LUMARA
  Future<void> shutdown() async {
    if (!_isInitialized) return;
    
    try {
      await _service.shutdown();
      _isInitialized = false;
      _currentInterface = null;
      debugPrint('LUMARA v2.0: Shutdown complete');
    } catch (e) {
      debugPrint('LUMARA v2.0: Shutdown error: $e');
    }
  }
}
