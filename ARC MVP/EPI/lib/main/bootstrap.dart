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
import 'package:my_app/models/arcform_snapshot_model.dart';
import 'package:my_app/features/journal/sage_annotation_model.dart';
import 'package:my_app/core/rivet/rivet_storage.dart';
import 'package:my_app/services/analytics_service.dart';
import 'package:my_app/data/hive/insight_snapshot.dart';
import 'package:my_app/core/sync/sync_item_adapter.dart';
import 'package:my_app/core/services/audio_service.dart';

import 'package:my_app/shared/app_colors.dart';
import 'package:my_app/shared/text_style.dart';

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
                Center(
                  child: ElevatedButton(
                    onPressed: () => SystemNavigator.pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kcPrimaryColor,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 30,
                        vertical: 15,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text('Restart App', style: buttonStyle(context)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Unified box names
class Boxes {
  static const userProfile = 'user_profile';
  static const journalEntries = 'journal_entries';
  static const arcformSnapshots = 'arcform_snapshots';
  static const insights = 'insights';
  static const syncQueue = 'sync_queue';
}

/// Enhanced bootstrap function with comprehensive error handling
Future<void> bootstrap({
  required FutureOr<Widget> Function() builder,
  required Flavor flavor,
}) async {
  return runZonedGuarded(
    () async {
      Flavors.flavor = flavor;
      WidgetsFlutterBinding.ensureInitialized();

      logger.i('Starting bootstrap process for ${flavor.toString()} environment');

      // Orientation lock
      try {
        await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
        logger.d('Device orientation locked to portrait');
      } catch (e, st) {
        logger.e('Failed to lock device orientation', e, st);
      }

      // === Hive init (portable across mobile, desktop, web) ===
      try {
        await Hive.initFlutter(); // handles IndexedDB on web
        logger.d('Hive.initFlutter() completed');
        
        // Register adapters (must match @HiveType typeIds)
        Hive
          ..registerAdapter(UserProfileAdapter())
          ..registerAdapter(JournalEntryAdapter())
          ..registerAdapter(ArcformSnapshotAdapter())
          ..registerAdapter(SAGEAnnotationAdapter())
          ..registerAdapter(InsightSnapshotAdapter())
          ..registerAdapter(SyncItemAdapter());
        logger.d('Hive adapters registered');

        // Open boxes with consistent snake_case names - with error recovery
        await _openHiveBoxes();
        
        // Migrate existing user profile data if needed
        await _migrateUserProfileData();

        logger.d('Hive initialized, adapters registered, boxes opened');
      } catch (e, st) {
        logger.e('Failed to initialize Hive', e, st);
        // Try to recover by clearing corrupted data
        try {
          logger.w('Attempting Hive recovery by clearing corrupted data');
          await _clearCorruptedHiveData();
          await _openHiveBoxes();
          logger.i('Hive recovery successful, continuing app startup');
        } catch (recoveryError, recoverySt) {
          logger.e('Hive recovery failed', recoveryError, recoverySt);
          runApp(
            BootstrapErrorWidget(
              error: e,
              stackTrace: st,
              context: 'Failed to initialize data storage system and recovery failed',
            ),
          );
          return;
        }
      }

      // === RIVET Storage Initialization ===
      try {
        await RivetBox.initialize();
        logger.d('RIVET storage initialized successfully');
      } catch (e, st) {
        logger.e('Failed to initialize RIVET storage', e, st);
        // RIVET failure is non-critical - continue app startup
        logger.w('RIVET gating will be disabled due to storage initialization failure');
      }

      // === Analytics Initialization ===
      try {
        await AnalyticsService.initialize();
        AnalyticsService.trackAppLaunch();
        logger.d('Analytics service initialized successfully');
      } catch (e, st) {
        logger.e('Failed to initialize analytics service', e, st);
        // Analytics failure is non-critical - continue app startup
        logger.w('Analytics tracking will be disabled due to initialization failure');
      }

      // === Audio Service Initialization (P22 - Ethereal Music) ===
      try {
        await AudioService().initialize();
        logger.d('Audio service initialized successfully');
      } catch (e, st) {
        logger.e('Failed to initialize audio service', e, st);
        // Audio failure is non-critical - continue app startup
        logger.w('Ethereal music will be disabled due to initialization failure');
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
      runApp(await builder());
    },
    (exception, stackTrace) async {
      logger.e('Uncaught exception in app', exception, stackTrace);
      // await Sentry.captureException(exception, stackTrace: stackTrace);

      // Show error widget in both development and production for better debugging
      runApp(
        BootstrapErrorWidget(
          error: exception,
          stackTrace: stackTrace,
          context: 'An unexpected error occurred during startup',
        ),
      );
    },
  );
}

/// Safely opens all required Hive boxes with error handling
Future<void> _openHiveBoxes() async {
  final boxNames = [
    Boxes.userProfile,
    Boxes.journalEntries,
    Boxes.arcformSnapshots,
    Boxes.insights,
  ];

  for (final boxName in boxNames) {
    try {
      if (!Hive.isBoxOpen(boxName)) {
        await Hive.openBox(boxName);
        logger.d('Opened Hive box: $boxName');
      } else {
        logger.d('Hive box already open: $boxName');
      }
    } catch (e, st) {
      logger.e('Failed to open Hive box: $boxName', e, st);
      // Try to delete and recreate the box
      try {
        await Hive.deleteBoxFromDisk(boxName);
        await Hive.openBox(boxName);
        logger.w('Recovered Hive box by recreating: $boxName');
      } catch (recoveryError) {
        logger.e('Failed to recover Hive box: $boxName', recoveryError);
        rethrow;
      }
    }
  }
}

/// Clears corrupted Hive data to allow app recovery
Future<void> _clearCorruptedHiveData() async {
  try {
    logger.w('Clearing potentially corrupted Hive data');
    
    // Close all open boxes first
    await Hive.close();
    
    // Reinitialize Hive
    await Hive.initFlutter();
    
    // Re-register adapters
    Hive
      ..registerAdapter(UserProfileAdapter())
      ..registerAdapter(JournalEntryAdapter())
      ..registerAdapter(ArcformSnapshotAdapter())
      ..registerAdapter(SAGEAnnotationAdapter())
      ..registerAdapter(InsightSnapshotAdapter())
      ..registerAdapter(SyncItemAdapter());
    
    logger.i('Hive data cleared and reinitialized');
  } catch (e, st) {
    logger.e('Failed to clear corrupted Hive data', e, st);
    rethrow;
  }
}

/// Migrates existing user profile data to include new phase stability fields
Future<void> _migrateUserProfileData() async {
  try {
    final userBox = Hive.box<UserProfile>(Boxes.userProfile);
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
