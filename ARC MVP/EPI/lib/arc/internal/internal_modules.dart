/// ARC Internal Modules
/// 
/// Barrel export for all internal modules (PRISM, MIRA, AURORA, ECHO)
/// 
/// ARC internally mirrors the EPI 5-module architecture:
/// - PRISM (Internal): Analysis of text and media
/// - MIRA (Internal): Memory and security of files
/// - AURORA (Internal): Handles time when user is active
/// - ECHO (Internal): Provides PII and security

export 'prism/prism_internal.dart';
export 'mira/mira_internal.dart';
export 'aurora/aurora_internal.dart';
export 'echo/echo_internal.dart';
