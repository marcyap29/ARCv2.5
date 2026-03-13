// lib/services/swarmspace/prism_service.dart
//
// PRISM client-side pipeline: classify plugin calls by sensitivity,
// show tiered consent UI, and invoke only after authorisation.
// STRUCTURED_PERSONAL always prompts (no persistent approval).

import 'package:flutter/material.dart';
import 'package:my_app/services/swarmspace/plugin_activity_log_service.dart';
import 'package:my_app/services/swarmspace/swarmspace_client.dart';
import 'package:my_app/services/swarmspace/swarmspace_plugin_approval_store.dart';
import 'package:my_app/shared/app_colors.dart';

/// Sensitivity tier for PRISM consent.
enum PrismTier {
  /// No personal data; call proceeds without consent UI.
  anonymous,

  /// User-generated content (URL, text); lightweight consent once per plugin, persisted.
  userContent,

  /// Sensitive personal data (image, document); full modal every time, never persisted.
  structuredPersonal,
}

/// Result of authoriseAndCall: either success with [SwarmSpaceResult] or user denied.
sealed class PrismCallResult {
  const PrismCallResult();
  bool get isDenied;
  SwarmSpaceResult? get result;
}

class PrismSuccessResult extends PrismCallResult {
  const PrismSuccessResult(this.result);
  @override
  final SwarmSpaceResult result;
  @override
  bool get isDenied => false;
}

class PrismDeniedResult extends PrismCallResult {
  const PrismDeniedResult();
  @override
  SwarmSpaceResult? get result => null;
  @override
  bool get isDenied => true;
}

/// Singleton PRISM service: classify, show consent, then invoke.
class PrismService {
  PrismService._();
  static final PrismService instance = PrismService._();

  final SwarmSpaceClient _client = SwarmSpaceClient.instance;
  final SwarmSpacePluginApprovalStore _store = SwarmSpacePluginApprovalStore.instance;

  /// Keys in params that indicate sensitive payloads (router-aligned).
  static const List<String> _sensitiveImageKeys = [
    'image_b64',
    'image_url',
    'image_base64',
  ];
  static const List<String> _sensitiveUserContentKeys = [
    'url',
    'urls',
  ];
  static const List<String> _sensitiveDocumentKeys = [
    'document_b64',
    'file_b64',
    'pdf_b64',
  ];

  /// Classifies a plugin call into a consent tier from manifest + payload.
  PrismTier classify({
    required String pluginId,
    required Map<String, dynamic> params,
    required bool privacyDataRequired,
  }) {
    if (!privacyDataRequired) return PrismTier.anonymous;

    final hasImage = _sensitiveImageKeys.any((k) => params.containsKey(k) && params[k] != null);
    final hasDocument = _sensitiveDocumentKeys.any((k) => params.containsKey(k) && params[k] != null);
    if (hasImage || hasDocument) return PrismTier.structuredPersonal;

    final hasUserContent = _sensitiveUserContentKeys.any((k) => params.containsKey(k) && params[k] != null);
    if (hasUserContent) return PrismTier.userContent;

    return PrismTier.anonymous;
  }

  /// Single pipeline: consent (if needed) then invoke. Adds _prism_consent when user approves.
  /// [context] can be null for ANONYMOUS; required for USER_CONTENT and STRUCTURED_PERSONAL to show UI.
  /// Returns [PrismDeniedResult] when user denies or when consent UI needed but context is null.
  Future<PrismCallResult> authoriseAndCall({
    required String pluginId,
    required Map<String, dynamic> params,
    BuildContext? context,
  }) async {
    final catalog = await _client.getPluginCatalog();
    PluginCatalogEntry? entry;
    if (catalog != null) {
      for (final p in catalog.plugins) {
        if (p.pluginId == pluginId) {
          entry = p;
          break;
        }
      }
    }

    final privacyRequired = entry?.privacyDataRequired ?? false;
    final tier = classify(
      pluginId: pluginId,
      params: params,
      privacyDataRequired: privacyRequired,
    );

    switch (tier) {
      case PrismTier.anonymous:
        final res = await _client.invoke(pluginId, params);
        await PluginActivityLogService.instance.logActivity(pluginId);
        return PrismSuccessResult(res);

      case PrismTier.userContent:
        final approved = await _store.isApproved(pluginId);
        if (approved) {
          final withConsent = Map<String, dynamic>.from(params)..['_prism_consent'] = true;
          final res = await _client.invoke(pluginId, withConsent);
          await PluginActivityLogService.instance.logActivity(pluginId);
          return PrismSuccessResult(res);
        }
        if (context == null || !context.mounted) return const PrismDeniedResult();
        final allow = await _showUserContentConsent(context, pluginId);
        if (!allow || !context.mounted) return const PrismDeniedResult();
        await _store.setApproved(pluginId);
        final withConsent = Map<String, dynamic>.from(params)..['_prism_consent'] = true;
        final res = await _client.invoke(pluginId, withConsent);
        await PluginActivityLogService.instance.logActivity(pluginId);
        return PrismSuccessResult(res);

      case PrismTier.structuredPersonal:
        if (context == null || !context.mounted) return const PrismDeniedResult();
        final allow = await _showStructuredPersonalConsent(context, pluginId);
        if (!allow || !context.mounted) return const PrismDeniedResult();
        final withConsent = Map<String, dynamic>.from(params)..['_prism_consent'] = true;
        final res = await _client.invoke(pluginId, withConsent);
        await PluginActivityLogService.instance.logActivity(pluginId);
        return PrismSuccessResult(res);
    }
  }

  /// USER_CONTENT: dismissible bottom sheet, "Allow" / "Not now". Persist on Allow.
  Future<bool> _showUserContentConsent(BuildContext context, String pluginId) async {
    final name = SwarmSpaceClient.pluginDisplayName(pluginId);
    final ok = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Allow $name?',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: kcPrimaryTextColor,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'This plugin will receive content you provide (e.g. a URL). Allow to continue once; you can revoke in Settings.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: kcSecondaryTextColor,
                    ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Not now'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: FilledButton.styleFrom(backgroundColor: kcPrimaryColor),
                    child: const Text('Allow'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    return ok ?? false;
  }

  /// STRUCTURED_PERSONAL: full modal every time. No persistence.
  Future<bool> _showStructuredPersonalConsent(BuildContext context, String pluginId) async {
    final name = SwarmSpaceClient.pluginDisplayName(pluginId);
    String dataDescription;
    if (pluginId == 'vision-ocr') {
      dataDescription = 'Your image is sent to SwarmSpace (Vision API + Gemini) to extract text or describe content.';
    } else {
      dataDescription = 'This plugin will receive sensitive personal data. It will be processed by SwarmSpace.';
    }
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text('Share data with $name?'),
        content: Text(
          dataDescription,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: kcPrimaryColor),
            child: const Text('I understand, continue'),
          ),
        ],
      ),
    );
    return ok ?? false;
  }
}
