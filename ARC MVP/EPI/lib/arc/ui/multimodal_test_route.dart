import 'package:flutter/material.dart';
import 'package:my_app/polymeta/store/mcp/orchestrator/multimodal_integration_service.dart';

/// Test route for multimodal functionality
class MultimodalTestRoute extends StatelessWidget {
  const MultimodalTestRoute({super.key});

  @override
  Widget build(BuildContext context) {
    return const MultimodalTestWidget();
  }
}

/// Add this route to your main app routes
class AppRoutes {
  static const String multimodalTest = '/multimodal-test';
  
  static Map<String, WidgetBuilder> get routes => {
    multimodalTest: (context) => const MultimodalTestRoute(),
  };
}

