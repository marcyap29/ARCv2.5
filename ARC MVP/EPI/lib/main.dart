import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:my_app/main/bootstrap.dart';
import 'package:my_app/models/enums/flavor.dart';
import 'package:my_app/app/app.dart';
import 'package:my_app/shared/app_colors.dart';

void main() async {
  // Set up global error handling
  _setupGlobalErrorHandling();
  
  // Automatically detect environment: debug = development, release = production
  const flavor = kDebugMode ? Flavor.development : Flavor.production;
  
  await bootstrap(
    builder: () => const App(),
    flavor: flavor,
  );
}

/// Sets up global error handling for the entire app
void _setupGlobalErrorHandling() {
  // Handle Flutter framework errors
  FlutterError.onError = (FlutterErrorDetails details) {
    // Log the error
    if (kDebugMode) {
      FlutterError.presentError(details);
    }
    
    // In production, log to our logger (imported via bootstrap.dart)
    logger.e(
      'Flutter Error: ${details.exception}',
      details.exception,
      details.stack,
    );
  };
  
  // Handle errors in widget build methods
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return _buildErrorWidget(details);
  };
  
  // Handle platform-specific errors
  PlatformDispatcher.instance.onError = (error, stack) {
    logger.e('Platform Error: $error', error, stack);
    return true; // Indicates the error was handled
  };
}

/// Builds a user-friendly error widget
Widget _buildErrorWidget(FlutterErrorDetails details) {
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
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: kcWarningColor,
                size: 48,
              ),
              const SizedBox(height: 20),
              const Text(
                'Something went wrong',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: kcPrimaryTextColor,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              const Text(
                'The app encountered an error. Please restart the app.',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  color: kcSecondaryTextColor,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              if (kDebugMode) ...[
                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: kcSurfaceColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    details.toString(),
                    style: const TextStyle(
                      fontSize: 12,
                      color: kcSecondaryTextColor,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
              ElevatedButton(
                onPressed: () async {
                  // Try to rebuild the app through bootstrap
                  await bootstrap(
                    builder: () => const App(),
                    flavor: kDebugMode ? Flavor.development : Flavor.production,
                  );
                },
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
                child: const Text(
                  'Retry',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}