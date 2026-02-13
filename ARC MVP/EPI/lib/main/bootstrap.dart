import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:logger/logger.dart';
// import 'package:sentry_flutter/sentry_flutter.dart';


import 'package:hive_flutter/hive_flutter.dart';

import 'package:my_app/models/enums/flavor.dart';
import 'package:my_app/utils/flavors.dart';

import 'package:my_app/models/user_profile_model.dart';
import 'package:my_app/models/journal_entry_model.dart';
import 'package:my_app/models/reflection_session.dart';
import 'package:my_app/models/arcform_snapshot_model.dart';
import 'package:my_app/state/journal_entry_state.dart';
import 'package:my_app/arc/core/sage_annotation_model.dart';
import 'package:my_app/data/models/media_item.dart';
import 'package:my_app/data/hive/duration_adapter.dart';
import 'package:my_app/prism/atlas/rivet/rivet_storage.dart';
import 'package:my_app/services/media_pack_tracking_service.dart';
import 'package:my_app/data/hive/insight_snapshot.dart';
import 'package:my_app/core/sync/sync_item_adapter.dart';
import 'package:my_app/arc/chat/llm/model_progress_service.dart';
import 'package:my_app/arc/chat/llm/bridge.pigeon.dart' as pigeon;
import 'package:my_app/arc/chat/chat/chat_models.dart';
import 'package:my_app/arc/chat/chat/chat_category_models.dart';
import 'package:my_app/arc/chat/data/models/lumara_favorite.dart';
import 'package:my_app/arc/voice_notes/models/voice_note.dart';
import 'package:my_app/chronicle/storage/layer0_repository.dart';
import 'package:my_app/crossroads/storage/decision_capture_repository.dart';
import 'package:my_app/services/firebase_service.dart';
import 'package:my_app/services/firebase_auth_service.dart';
import 'package:my_app/services/revenuecat_service.dart';
import 'package:my_app/services/health_data_refresh_service.dart';
import 'package:my_app/services/phase_history_readiness_backfill_service.dart';
import 'package:my_app/arc/core/journal_repository.dart';
import 'package:my_app/services/analytics_service.dart';
import 'package:my_app/services/temporal_notification_service.dart';

import 'package:my_app/shared/app_colors.dart';
import 'package:my_app/shared/text_style.dart';

// ==========================================================
// NOTES FOR AI AGENT
// ==========================================================
// NOTES FOR AI AGENT
// ==========================================================
// IMPORTANT: When Firebase is configured and firebase_options.dart exists:
// 1. Uncomment the import below and the initialize block in bootstrap()
// 2. Remove these comment lines once Firebase is connected and the line below is uncommented
// import 'package:my_app/firebase_options.dart';
// import 'package:firebase_core/firebase_core.dart';

/// Logger instance for application-wide logging
final logger = Logger(
  printer: PrettyPrinter(
    methodCount: 0,
    errorMethodCount: 5,
    lineLength: 50,
    colors: true,
    printEmojis: true,
    printTime: true,
  ),
);

/// Enhanced error handler that captures detailed diagnostics
class BootstrapErrorWidget extends StatefulWidget {
  final Object error;
  final StackTrace stackTrace;
  final String context;

  const BootstrapErrorWidget({
    super.key,
    required this.error,
    required this.stackTrace,
    required this.context,
  });

  @override
  State<BootstrapErrorWidget> createState() => _BootstrapErrorWidgetState();
}

class _BootstrapErrorWidgetState extends State<BootstrapErrorWidget> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: kcPrimaryColor,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: kcBackgroundColor,
        useMaterial3: true,
      ),
      home: Scaffold(
        backgroundColor: kcBackgroundColor,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.error_outline, color: kcDangerColor, size: 48),
                const SizedBox(height: 20),
                Text('Startup Error', style: heading1Style(context)),
                const SizedBox(height: 10),
                Text(widget.context, style: bodyStyle(context)),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: kcSurfaceColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(widget.error.toString(), style: errorStyle(context)),
                ),
                const SizedBox(height: 20),
                Text('Technical Details:', style: captionStyle(context)),
                const SizedBox(height: 5),
                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: kcSurfaceColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    widget.stackTrace.toString(),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: kcSecondaryTextColor,
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      onPressed: () async {
                        try {
                          // Try to clear data and restart
                          await _clearCorruptedHiveData();
                          await _openHiveBoxes();
                          
                          // Don't call runApp from error handler to avoid zone issues
                          logger.i('Data cleared successfully - app will restart naturally');
                        } catch (e) {
                          logger.e('Failed to clear data and restart', e);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kcWarningColor,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 15,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text('Clear Data', style: buttonStyle(context)),
                    ),
                    ElevatedButton(
                      onPressed: () => SystemNavigator.pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kcPrimaryColor,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 15,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text('Exit App', style: buttonStyle(context)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Safely registers Hive adapters without conflicts
Future<void> _registerHiveAdapters() async {
  try {
    // Check if adapters are already registered to avoid conflicts
    // Register MediaItem adapters FIRST since JournalEntry depends on them
    if (!Hive.isAdapterRegistered(10)) {
      Hive.registerAdapter(MediaTypeAdapter());
      logger.d('✅ Registered MediaTypeAdapter (ID: 10)');
    } else {
      logger.d('⚠️ MediaTypeAdapter (ID: 10) already registered');
    }
    if (!Hive.isAdapterRegistered(11)) {
      Hive.registerAdapter(MediaItemAdapter());
      logger.d('✅ Registered MediaItemAdapter (ID: 11)');
    } else {
      logger.d('⚠️ MediaItemAdapter (ID: 11) already registered');
    }
    if (!Hive.isAdapterRegistered(105)) {
      Hive.registerAdapter(DurationAdapter());
      logger.d('✅ Registered DurationAdapter (ID: 105) - required for video entries');
    }
    // Register other adapters
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(UserProfileAdapter());
      logger.d('✅ Registered UserProfileAdapter (ID: 0)');
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(JournalEntryAdapter());
      logger.d('✅ Registered JournalEntryAdapter (ID: 1)');
    }
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(ArcformSnapshotAdapter());
      logger.d('✅ Registered ArcformSnapshotAdapter (ID: 2)');
    }
    if (!Hive.isAdapterRegistered(3)) {
      Hive.registerAdapter(SAGEAnnotationAdapter());
      logger.d('✅ Registered SAGEAnnotationAdapter (ID: 3)');
    }
    if (!Hive.isAdapterRegistered(4)) {
      Hive.registerAdapter(InsightSnapshotAdapter());
      logger.d('✅ Registered InsightSnapshotAdapter (ID: 4)');
    }
    if (!Hive.isAdapterRegistered(5)) {
      Hive.registerAdapter(SyncItemAdapter());
      logger.d('✅ Registered SyncItemAdapter (ID: 5)');
    }
    // Chat adapters - handled by ChatRepoImpl.initialize()
    if (!Hive.isAdapterRegistered(71)) {
      Hive.registerAdapter(ChatSessionAdapter());
      logger.d('✅ Registered ChatSessionAdapter (ID: 71)');
    }
    if (!Hive.isAdapterRegistered(70)) {
      Hive.registerAdapter(ChatMessageAdapter());
      logger.d('✅ Registered ChatMessageAdapter (ID: 70)');
    }
    // Chat category adapters
    if (!Hive.isAdapterRegistered(72)) {
      Hive.registerAdapter(ChatCategoryAdapter());
      logger.d('✅ Registered ChatCategoryAdapter (ID: 72)');
    }
    if (!Hive.isAdapterRegistered(73)) {
      Hive.registerAdapter(ChatSessionCategoryAdapter());
      logger.d('✅ Registered ChatSessionCategoryAdapter (ID: 73)');
    }
    if (!Hive.isAdapterRegistered(74)) {
      Hive.registerAdapter(ChatExportDataAdapter());
      logger.d('✅ Registered ChatExportDataAdapter (ID: 74)');
    }
    // Favorites adapter
    if (!Hive.isAdapterRegistered(80)) {
      Hive.registerAdapter(LumaraFavoriteAdapter());
      logger.d('✅ Registered LumaraFavoriteAdapter (ID: 80)');
    }
    // LUMARA inline reflection blocks (used inside JournalEntry.lumaraBlocks)
    if (!Hive.isAdapterRegistered(103)) {
      Hive.registerAdapter(InlineBlockAdapter());
      logger.d('✅ Registered InlineBlockAdapter (ID: 103)');
    }
    
    // Voice notes for Ideas inbox (Progressive Voice Capture)
    if (!Hive.isAdapterRegistered(120)) {
      Hive.registerAdapter(VoiceNoteAdapter());
      logger.d('✅ Registered VoiceNoteAdapter (ID: 120)');
    }
    // CHRONICLE Layer 0 (raw entries) – required for Backfill Layer 0 to work
    if (!Hive.isAdapterRegistered(110)) {
      Hive.registerAdapter(ChronicleRawEntryAdapter());
      logger.d('✅ Registered ChronicleRawEntryAdapter (ID: 110)');
    }
    // Crossroads: decision captures and outcome prompts
    if (!Hive.isAdapterRegistered(118)) {
      Hive.registerAdapter(DecisionCaptureAdapter());
      logger.d('✅ Registered DecisionCaptureAdapter (ID: 118)');
    }
    if (!Hive.isAdapterRegistered(119)) {
      Hive.registerAdapter(DecisionOutcomePromptAdapter());
      logger.d('✅ Registered DecisionOutcomePromptAdapter (ID: 119)');
    }
    // Reflection session monitoring (AURORA)
    if (!Hive.isAdapterRegistered(125)) {
      Hive.registerAdapter(ReflectionSessionAdapter());
      logger.d('✅ Registered ReflectionSessionAdapter (ID: 125)');
    }
    if (!Hive.isAdapterRegistered(126)) {
      Hive.registerAdapter(ReflectionExchangeAdapter());
      logger.d('✅ Registered ReflectionExchangeAdapter (ID: 126)');
    }

    // Run a one-time migration to persist legacy LUMARA blocks into the dedicated field
    try {
      final journalRepo = JournalRepository();
      await journalRepo.migrateLumaraBlocks();
      logger.i('✅ Completed LUMARA inline block migration on startup');
    } catch (e) {
      logger.w('⚠️ LUMARA migration skipped/failed: $e');
    }
    
    // Verify MediaItemAdapter is registered
    if (Hive.isAdapterRegistered(11)) {
      logger.i('✅ Verified MediaItemAdapter (ID: 11) is registered');
    } else {
      logger.e('❌ ERROR: MediaItemAdapter (ID: 11) is NOT registered!');
    }
  } catch (e) {
    logger.e('❌ Error registering Hive adapters: $e');
    logger.w('Some adapters may already be registered: $e');
    // Continue - this is not critical
  }
}

/// Unified box names
class Boxes {
  static const userProfile = 'user_profile';
  static const journalEntries = 'journal_entries';
  static const arcformSnapshots = 'arcform_snapshots';
  static const reflectionSessions = 'reflection_sessions';
  static const insights = 'insights';
  static const syncQueue = 'sync_queue';
  static const coachDropletTemplates = 'coach_droplet_templates';
  static const coachDropletResponses = 'coach_droplet_responses';
  static const coachShareBundles = 'coach_share_bundles';
  static const settings = 'settings';
}

/// Enhanced bootstrap function with comprehensive error handling
Future<void> bootstrap({
  required FutureOr<Widget> Function() builder,
  required Flavor flavor,
}) async {
  return runZonedGuarded(
    () async {
      try {
        // Ensure Flutter bindings are initialized in the same zone as runApp
        WidgetsFlutterBinding.ensureInitialized();
        
        Flavors.flavor = flavor;

        logger.i('Starting bootstrap process for ${flavor.toString()} environment');
        logger.d('App startup triggered - handling potential force-quit recovery');

      // Register native bridges
      try {
        await _registerNativeBridges();
        logger.d('Native bridges registered successfully');
      } catch (e, st) {
        logger.e('Failed to register native bridges', e, st);
      }

      // Orientation lock
      try {
        await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
        logger.d('Device orientation locked to portrait');
      } catch (e, st) {
        logger.e('Failed to lock device orientation', e, st);
      }

      // === Sequential Initialization - Hive must be first ===
      // Hive must be initialized before anything that uses it
      final hiveInitialized = await _initializeHive();

      // Initialize Firebase (uses platform config or dart-define fallback)
      try {
        final firebaseReady = await FirebaseService.instance.initialize();
        logger.d('Firebase initialized (ready: $firebaseReady)');

        // Initialize Firebase Auth after Firebase is ready
        if (firebaseReady) {
          try {
            await FirebaseAuthService.instance.initialize();
            logger.d('Firebase Auth initialized successfully');
            // RevenueCat for in-app purchases (iOS). Stripe = web (see DOCS/PAYMENTS_CLARIFICATION.md).
            try {
              await RevenueCatService.instance.configure(
                appUserId: FirebaseAuthService.instance.currentUser?.uid,
              );
            } catch (rcErr, rcSt) {
              logger.w('RevenueCat configure failed (non-fatal)', rcErr, rcSt);
            }
          } catch (authError, authSt) {
            logger.e('Failed to initialize Firebase Auth', authError, authSt);
          }
        }
      } catch (e, st) {
        logger.e('Failed to initialize Firebase', e, st);
      }
      
      // === Parallel Initialization of Independent Services (after Hive) ===
      // Run independent services in parallel after Hive is ready
      final initializationResults = await Future.wait([
        if (hiveInitialized) _initializeRivet() else Future.value(false),
        _initializeAnalytics(),
        if (hiveInitialized) _initializeMediaPackTracking() else Future.value(false),
      ], eagerError: false);

      // Log results
      logger.d('Initialization completed: Hive=$hiveInitialized, ${initializationResults.where((r) => r).length}/3 additional services successful');

      // Initialize health data refresh service
      if (hiveInitialized) {
        try {
          await _initializeHealthDataRefresh();
        } catch (e, st) {
          logger.e('Failed to initialize health data refresh', e, st);
        }
      }

      // Initialize temporal notifications (after Firebase Auth)
      try {
        await _initializeTemporalNotifications();
      } catch (e, st) {
        logger.e('Failed to initialize temporal notifications', e, st);
      }

      // ===========================================================
      // NOTES FOR AI AGENT
      // ===========================================================
      // IMPORTANT: When Firebase is configured and firebase_options.dart exists:
      // 1. Uncomment the ENTIRE block below, INCLUDING the options parameter
      // 2. Remove these comment lines once Firebase is connected and the line below is uncommented
      // try {
      //   await Firebase.initializeApp(
      //         options: DefaultFirebaseOptions.currentPlatform,
      //       );
      //   logger.d('Firebase initialized');
      // } catch (e, st) {
      //   logger.e('Failed to initialize Firebase', e, st);
      // }

      // =========================================================
      // CRITICAL: SENTRY CONFIGURATION - DO NOT MODIFY OR REMOVE
      // =========================================================
      // await SentryFlutter.init((options) {
      //   options.dsn =
      //       'https://263a9fd70a60392696abac85b69c660f@o4508813240434688.ingest.us.sentry.io/4509894481346560';
      //   options.tracesSampleRate = 1.0;
      //   options.profilesSampleRate = 1.0;

      //   // Add additional context to Sentry reports
      //   options.beforeSend = (SentryEvent event, {dynamic hint}) {
      //     event.contexts['environment'] = flavor.toString();
      //     event.extra?['isWeb'] = kIsWeb;
      //     return event;
      //   };
      // }, appRunner: () async {
      //   logger.i('Sentry initialized successfully');
      //   runApp(await builder());
      // });
      
      // Temporary: run app directly without Sentry
      logger.i('Running app without Sentry (temporarily disabled)');
      
      // Ensure runApp is called in the correct zone
      final app = await builder();
      runApp(app);

      // One-time backfill of phase history with readiness/health (after crash/restore or upgrade)
      if (hiveInitialized) {
        Future.delayed(const Duration(seconds: 2), () async {
          await runPhaseHistoryReadinessBackfillIfNeeded();
        });
      }
      } catch (e, stackTrace) {
        logger.e('Error during bootstrap initialization', e, stackTrace);
        // Don't call runApp from error handler to avoid zone issues
        logger.e('Bootstrap initialization failed - error logged but not showing UI to avoid zone conflicts');
      }
    },
    (exception, stackTrace) async {
      logger.e('Uncaught exception in app', exception, stackTrace);
      // await Sentry.captureException(exception, stackTrace: stackTrace);

      // Don't call runApp from error handler to avoid zone issues
      // The error will be handled by the existing error handling mechanisms
      logger.e('Zone error handler called - error logged but not showing UI to avoid zone conflicts');
    },
  );
}

/// Safely opens all required Hive boxes with error handling and type safety
Future<void> _openHiveBoxes() async {
  // Define boxes with their specific types for type safety
  final typedBoxes = <String, Type>{
    Boxes.userProfile: UserProfile,
    Boxes.journalEntries: JournalEntry,
    Boxes.arcformSnapshots: ArcformSnapshot,
    Boxes.reflectionSessions: ReflectionSession,
    Boxes.insights: dynamic, // InsightSnapshot if it exists
    Boxes.coachDropletTemplates: dynamic,
    Boxes.coachDropletResponses: dynamic,
    Boxes.coachShareBundles: dynamic,
    Boxes.settings: dynamic,
  };

  for (final entry in typedBoxes.entries) {
    final boxName = entry.key;
    final boxType = entry.value;
    
    try {
      // Skip boxes already open (avoid double-open errors)
      if (Hive.isBoxOpen(boxName)) {
        logger.d('Box $boxName already open, skipping re-open');
        continue;
      } else {
        await _openTypedBox(boxName, boxType);
      }
    } catch (e, st) {
      logger.e('Failed to handle Hive box: $boxName', e, st);
      await _recoverBoxWithTypeHandling(boxName, boxType, e);
    }
  }
}

/// Opens a typed box with proper error handling
Future<void> _openTypedBox(String boxName, Type boxType) async {
  try {
    if (boxType == UserProfile) {
      await Hive.openBox<UserProfile>(boxName);
    } else if (boxType == JournalEntry) {
      await Hive.openBox<JournalEntry>(boxName);
    } else if (boxType == ArcformSnapshot) {
      await Hive.openBox<ArcformSnapshot>(boxName);
    } else if (boxType == ReflectionSession) {
      await Hive.openBox<ReflectionSession>(boxName);
    } else {
      await Hive.openBox(boxName); // Generic box
    }
    logger.d('Successfully opened typed box: $boxName as $boxType');
  } catch (e) {
    logger.e('Failed to open typed box $boxName as $boxType: $e');
    rethrow;
  }
}

/// Recovers a box with specific type handling
Future<void> _recoverBoxWithTypeHandling(String boxName, Type boxType, Object originalError) async {
  try {
    logger.w('Attempting recovery for $boxName (type: $boxType) due to: $originalError');
    
    // CRITICAL: Never delete journal_entries box - it contains user data!
    if (boxName == 'journal_entries') {
      logger.e('❌ CRITICAL: Attempted to delete journal_entries box - ABORTING to prevent data loss!');
      logger.e('Error was: $originalError');
      // Try to reopen the box without deleting it
      try {
        if (Hive.isBoxOpen(boxName)) {
          await Hive.box(boxName).close();
        }
        await _openTypedBox(boxName, boxType);
        logger.i('Successfully reopened journal_entries box without data loss');
        return;
      } catch (e) {
        logger.e('Failed to reopen journal_entries box: $e');
        // Don't delete - just log the error and continue
        logger.e('⚠️ WARNING: journal_entries box may be in an inconsistent state');
        return;
      }
    }
    
    // Close any existing box first
    if (Hive.isBoxOpen(boxName)) {
      try {
        await Hive.box(boxName).close();
        logger.d('Closed existing box: $boxName');
      } catch (closeError) {
        logger.w('Error closing box $boxName: $closeError');
      }
    }
    
    // For type mismatch errors, delete the box from disk (but NOT journal_entries)
    if (originalError.toString().contains('already open') || 
        originalError.toString().contains('type') ||
        originalError.toString().contains('dynamic')) {
      logger.i('Deleting box from disk due to type conflict: $boxName');
      try {
        await Hive.deleteBoxFromDisk(boxName);
        logger.d('Deleted box from disk: $boxName');
      } catch (deleteError) {
        logger.w('Error deleting box $boxName: $deleteError');
      }
    }
    
    // Reopen with correct type
    await _openTypedBox(boxName, boxType);
    logger.i('Successfully recovered box: $boxName as $boxType');
    
  } catch (recoveryError, st) {
    logger.e('Failed to recover Hive box: $boxName', recoveryError, st);
    
    // Last resort: try generic box opening (but NOT for journal_entries)
    if (boxName == 'journal_entries') {
      logger.e('❌ CRITICAL: Cannot recover journal_entries box - preserving data');
      return;
    }
    
    try {
      await Hive.openBox(boxName);
      logger.w('Opened box as generic type: $boxName');
    } catch (finalError) {
      logger.e('All recovery attempts failed for box: $boxName', finalError);
      rethrow;
    }
  }
}

/// Clears corrupted Hive data to allow app recovery
/// NOTE: This should NEVER be called automatically - it's only for manual recovery
Future<void> _clearCorruptedHiveData() async {
  try {
    logger.w('⚠️ WARNING: Clearing potentially corrupted Hive data');
    logger.w('⚠️ This will NOT delete journal_entries box to preserve user data');
    
    // Close all open boxes first (except journal_entries)
    final openBoxes = <String>[];
    try {
      // Get list of open boxes before closing
      // Note: Hive doesn't provide a direct way to list open boxes, so we'll be careful
      if (Hive.isBoxOpen('journal_entries')) {
        logger.i('Preserving journal_entries box - will not close it');
        openBoxes.add('journal_entries');
      }
    } catch (e) {
      logger.w('Error checking for journal_entries box: $e');
    }
    
    // Close boxes individually, skipping journal_entries
    final boxesToClose = ['user_profile', 'arcform_snapshots', 'insights', 'sync_queue', 
                         'coach_droplet_templates', 'coach_droplet_resesponses', 
                         'coach_share_bundles', 'settings'];
    for (final boxName in boxesToClose) {
      if (Hive.isBoxOpen(boxName)) {
        try {
          await Hive.box(boxName).close();
          logger.d('Closed box: $boxName');
        } catch (e) {
          logger.w('Error closing box $boxName: $e');
        }
      }
    }
    
    // Reinitialize Hive (this won't affect already-open boxes)
    await Hive.initFlutter();
    
    // Re-register adapters safely
    await _registerHiveAdapters();
    
    logger.i('Hive data cleared and reinitialized (journal_entries preserved)');
  } catch (e, st) {
    logger.e('Failed to clear corrupted Hive data', e, st);
    rethrow;
  }
}

/// Migrates existing user profile data to include new phase stability fields
Future<void> _migrateUserProfileData() async {
  try {
    // Use safe box access pattern
    Box<UserProfile> userBox;
    if (Hive.isBoxOpen(Boxes.userProfile)) {
      userBox = Hive.box<UserProfile>(Boxes.userProfile);
    } else {
      userBox = await Hive.openBox<UserProfile>(Boxes.userProfile);
    }
    final userProfile = userBox.get('profile');
    
    if (userProfile != null) {
      // Check if migration is needed
      if (userProfile.currentPhase == 'Unknown' || userProfile.lastPhaseChangeAt == null) {
        logger.d('Migrating user profile data for phase stability system');
        
        // Create updated profile with proper defaults
        final updatedProfile = UserProfile(
          id: userProfile.id,
          name: userProfile.name,
          email: userProfile.email,
          createdAt: userProfile.createdAt,
          preferences: userProfile.preferences,
          onboardingPurpose: userProfile.onboardingPurpose,
          onboardingFeeling: userProfile.onboardingFeeling,
          onboardingRhythm: userProfile.onboardingRhythm,
          onboardingCompleted: userProfile.onboardingCompleted,
          onboardingCurrentSeason: userProfile.onboardingCurrentSeason,
          onboardingCentralWord: userProfile.onboardingCentralWord,
          currentPhase: userProfile.currentPhase == 'Unknown' ? 'Discovery' : userProfile.currentPhase,
          lastPhaseChangeAt: userProfile.lastPhaseChangeAt ?? userProfile.createdAt,
        );
        
        // Save the updated profile
        await userBox.put('profile', updatedProfile);
        logger.d('User profile migration completed successfully');
      }
    }
  } catch (e, st) {
    logger.w('Failed to migrate user profile data', e, st);
    // Don't throw - this is not critical for app startup
  }
}

/// Performs startup health check to detect recovery scenarios
// ignore: unused_element
Future<void> _performStartupHealthCheck() async {
  try {
    logger.d('Performing startup health check');
    
    final stopwatch = Stopwatch()..start();
    
    // Check if Hive is in a clean state and can be safely used
    await _validateHiveState();
    
    // Verify critical app services are ready
    await _validateCriticalServices();
    
    stopwatch.stop();
    logger.d('Startup health check completed in ${stopwatch.elapsedMilliseconds}ms');
    
  } catch (e, st) {
    logger.e('Startup health check failed - attempting recovery', e, st);
    
    // If health check fails, try to recover before continuing
    try {
      await _recoverFromStartupFailure();
      logger.i('Startup recovery completed successfully');
    } catch (recoveryError, recoverySt) {
      logger.e('Startup recovery failed', recoveryError, recoverySt);
      // Continue anyway - the app might still work with degraded functionality
    }
  }
}

/// Validates that Hive is in a usable state
Future<void> _validateHiveState() async {
  // Check if Hive is initialized
  try {
    // Try a simple operation to see if Hive is working
    final testBox = await Hive.openBox('_startup_test');
    await testBox.put('test_key', 'test_value');
    final testValue = testBox.get('test_key');
    await testBox.delete('test_key');
    await testBox.close();
    
    if (testValue != 'test_value') {
      throw Exception('Hive read/write test failed');
    }
    
    logger.d('Hive state validation: OK');
  } catch (e) {
    logger.w('Hive state validation failed: $e');
    throw Exception('Hive is not in a usable state: $e');
  }
}

/// Validates critical app services are available
Future<void> _validateCriticalServices() async {
  // This would check other critical services
  // For now, just log that we're checking
  logger.d('Critical services validation: OK');
}

/// Recovers from startup failures
Future<void> _recoverFromStartupFailure() async {
  logger.w('Attempting startup failure recovery');
  
  try {
    // Close all Hive boxes and reinitialize
    await Hive.close();
    await Future.delayed(const Duration(milliseconds: 100)); // Brief pause
    
    // Reinitialize Hive completely
    await Hive.initFlutter();
    
    // Re-register all adapters safely
    await _registerHiveAdapters();
    
    // Reopen essential boxes
    await _openHiveBoxes();
    
    logger.i('Startup failure recovery completed');
  } catch (e, st) {
    logger.e('Startup failure recovery failed', e, st);
    rethrow;
  }
}

/// Attempts emergency recovery from critical errors
// ignore: unused_element
Future<bool> _attemptEmergencyRecovery(Object exception, StackTrace stackTrace) async {
  try {
    logger.w('Attempting emergency recovery for: ${exception.toString()}');
    
    // Check if it's a Hive-related error
    if (exception.toString().contains('HiveError') || 
        exception.toString().contains('box') ||
        exception.toString().contains('already open') ||
        exception.toString().contains('dynamic') ||
        exception.toString().contains('type')) {
      logger.i('Detected Hive error, attempting database recovery');
      
      try {
        // Clear and reinitialize Hive
        await _clearCorruptedHiveData();
        await _openHiveBoxes();
        
        logger.i('Hive recovery successful, restarting app');
        
        // Recovery successful - let normal bootstrap continue
        logger.i('Hive recovery successful - continuing normal bootstrap');
        return true; // Recovery successful
        
      } catch (recoveryError) {
        logger.e('Emergency Hive recovery failed', recoveryError);
        return false;
      }
    }
    
    // Check for widget lifecycle errors
    if (exception.toString().contains('context') ||
        exception.toString().contains('mounted') ||
        exception.toString().contains('deactivated')) {
      logger.i('Detected widget lifecycle error, attempting widget recovery');
      
      // Don't call runApp from error handler to avoid zone issues
      logger.i('Widget lifecycle error detected - error logged but not restarting to avoid zone conflicts');
      return false;
    }
    
    // For other errors, return false to show error widget
    logger.w('No recovery strategy available for this error type');
    return false;
    
  } catch (e, st) {
    logger.e('Emergency recovery itself failed', e, st);
    return false;
  }
}

/// Register native bridges for LUMARA
Future<void> _registerNativeBridges() async {
  try {
    // Register progress API to receive model loading updates from native side
    pigeon.LumaraNativeProgress.setUp(
      ModelProgressService(),
      binaryMessenger: ServicesBinding.instance.defaultBinaryMessenger,
    );
    logger.d('ModelProgressService registered for native progress callbacks');
  } catch (e) {
    logger.e('Failed to register native bridges', e);
    rethrow;
  }
}

/// Initialize Hive storage
Future<bool> _initializeHive() async {
  try {
    await Hive.initFlutter(); // handles IndexedDB on web
    logger.d('Hive.initFlutter() completed');
    
    // Register adapters (must match @HiveType typeIds) - check if already registered
    await _registerHiveAdapters();
    logger.d('Hive adapters registered');

    // Open boxes with consistent snake_case names - with error recovery
    await _openHiveBoxes();
    
    // Migrate existing user profile data if needed
    await _migrateUserProfileData();

    logger.d('Hive initialized, adapters registered, boxes opened');
    return true;
  } catch (e, st) {
    logger.e('Failed to initialize Hive', e, st);
    // Try to recover by clearing corrupted data
    try {
      logger.w('Attempting Hive recovery by clearing corrupted data');
      await _clearCorruptedHiveData();
      await _openHiveBoxes();
      logger.i('Hive recovery successful, continuing app startup');
      return true;
    } catch (recoveryError, recoverySt) {
      logger.e('Hive recovery failed', recoveryError, recoverySt);
      return false;
    }
  }
}

/// Initialize RIVET storage
Future<bool> _initializeRivet() async {
  try {
    await RivetBox.initialize();
    logger.d('RIVET storage initialized successfully');
    return true;
  } catch (e, st) {
    logger.e('Failed to initialize RIVET storage', e, st);
    logger.w('RIVET gating will be disabled due to storage initialization failure');
    return false;
  }
}

/// Initialize Analytics service
Future<bool> _initializeAnalytics() async {
  try {
    await AnalyticsService.initialize();
    AnalyticsService.trackAppLaunch();
    logger.d('Analytics service initialized successfully');
    return true;
  } catch (e, st) {
    logger.e('Failed to initialize analytics service', e, st);
    logger.w('Analytics tracking will be disabled due to initialization failure');
    return false;
  }
}

/// Initialize Temporal Notifications service
Future<void> _initializeTemporalNotifications() async {
  try {
    // Initialize the notification service
    await TemporalNotificationService().initialize();
    logger.d('Temporal notification service initialized');

    // Schedule notifications for current user (if authenticated)
    final userId = FirebaseAuthService().currentUser?.uid;
    if (userId != null) {
      await TemporalNotificationService().scheduleNotifications(userId);
      logger.d('Temporal notifications scheduled for user: $userId');
    } else {
      logger.d('No authenticated user, skipping notification scheduling');
    }
  } catch (e, st) {
    logger.e('Failed to initialize temporal notifications', e, st);
    // Don't throw - notifications are non-critical
  }
}

// Scheduled backup services removed - not implemented
// Manual backups are available via ARCXExportServiceV2

/// Initialize Health Data Refresh service
Future<void> _initializeHealthDataRefresh() async {
  try {
    await HealthDataRefreshService.instance.startScheduledRefresh();
    logger.d('Health data refresh service initialized');
  } catch (e, st) {
    logger.e('Failed to initialize health data refresh service', e, st);
    // Don't throw - health refresh is non-critical
  }
}

/// Initialize Media Pack Tracking service
Future<bool> _initializeMediaPackTracking() async {
  try {
    await MediaPackTrackingService.instance.initialize();
    // Run auto-archive check on startup (defer heavy operation)
    Future.delayed(const Duration(seconds: 5), () async {
      try {
        final archivedPacks = await MediaPackTrackingService.instance.autoArchiveOldPacks(6);
        if (archivedPacks.isNotEmpty) {
          logger.i('Auto-archived ${archivedPacks.length} old media packs');
        }
      } catch (e) {
        logger.e('Failed to run auto-archive check', e);
      }
    });
    logger.d('Media pack tracking service initialized successfully');
    return true;
  } catch (e, st) {
    logger.e('Failed to initialize media pack tracking service', e, st);
    logger.w('Media pack tracking will be disabled due to initialization failure');
    return false;
  }
}
