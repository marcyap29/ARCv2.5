// lib/lumara/social/late_profile_service.dart
// Phase 7: Late.com profile and accounts via social-publisher worker.

import 'package:flutter/material.dart';
import 'package:my_app/lumara/profile/user_profile_service.dart';
import 'package:my_app/services/swarmspace/prism_service.dart';
import 'package:my_app/services/swarmspace/swarmspace_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Test-only: when set, used instead of SwarmSpaceClient.instance.invoke.
typedef LateProfileInvoker = Future<SwarmSpaceResult> Function(
  String pluginId,
  Map<String, dynamic> params,
);

const String _keyProfileId = 'late_profile_id';

class SocialAccount {
  final String id;
  final String platform;
  final String username;
  final String profileId;

  const SocialAccount({
    required this.id,
    required this.platform,
    required this.username,
    required this.profileId,
  });

  factory SocialAccount.fromJson(Map<String, dynamic> json) {
    return SocialAccount(
      id: json['id'] as String? ?? json['_id'] as String? ?? '',
      platform: json['platform'] as String? ?? '',
      username: json['username'] as String? ?? json['handle'] as String? ?? '',
      profileId: json['profileId'] as String? ?? json['profile_id'] as String? ?? '',
    );
  }
}

class LateProfileService {
  LateProfileService._();
  static final LateProfileService instance = LateProfileService._();

  /// Test-only: override to mock plugin responses. Set to null in production.
  static LateProfileInvoker? testInvoker;

  Future<SwarmSpaceResult> _invoke(String pluginId, Map<String, dynamic> params) async {
    if (testInvoker != null) return testInvoker!(pluginId, params);
    return SwarmSpaceClient.instance.invoke(pluginId, params);
  }

  /// When [context] is provided, uses PrismService so the user sees consent once; required for social-publisher (privacy_data_required).
  Future<String> getOrCreateProfileId([BuildContext? context]) async {
    final prefs = await SharedPreferences.getInstance();
    String? profileId = prefs.getString(_keyProfileId);
    if (profileId != null && profileId.isNotEmpty) return profileId;

    final preferredName = await UserProfileService.instance.getField('preferred_name');
    final name = preferredName != null && preferredName.trim().isNotEmpty
        ? 'LUMARA — $preferredName'
        : 'LUMARA';

    SwarmSpaceResult result;
    if (context != null && context.mounted) {
      final prism = await PrismService.instance.authoriseAndCall(
        pluginId: 'social-publisher',
        params: {
          '_action': 'createProfile',
          'name': name,
          'description': 'LUMARA social publishing',
        },
        context: context,
      );
      if (prism.isDenied) throw Exception('Plugin skipped by user');
      if (prism.result == null || !prism.result!.success) {
        throw Exception(prism.result?.error ?? 'Failed to create Late profile');
      }
      result = prism.result!;
    } else {
      result = await _invoke('social-publisher', {
        '_action': 'createProfile',
        'name': name,
        'description': 'LUMARA social publishing',
      });
    }

    if (!result.success || result.data == null) {
      throw Exception(result.error ?? 'Failed to create Late profile');
    }

    final data = result.data!;
    final profile = data['profile'] as Map<String, dynamic>?;
    final id = profile?['_id'] as String? ?? data['_id'] as String?;
    if (id == null || id.isEmpty) {
      throw Exception('Late profile created but no _id returned');
    }

    await prefs.setString(_keyProfileId, id);
    return id;
  }

  /// When [context] is provided, uses PrismService so the user sees consent once (required for social-publisher).
  Future<List<SocialAccount>> getConnectedAccounts([BuildContext? context]) async {
    final profileId = await getOrCreateProfileId(context);
    SwarmSpaceResult result;
    if (context != null && context.mounted) {
      final prism = await PrismService.instance.authoriseAndCall(
        pluginId: 'social-publisher',
        params: {'_action': 'accounts', 'profileId': profileId},
        context: context,
      );
      if (prism.isDenied) return [];
      if (prism.result == null || !prism.result!.success) return [];
      result = prism.result!;
    } else {
      result = await _invoke('social-publisher', {
        '_action': 'accounts',
        'profileId': profileId,
      });
    }

    if (!result.success || result.data == null) return [];

    final data = result.data!;
    final list = data['accounts'] as List<dynamic>? ?? data as List<dynamic>? ?? [];
    return list
        .map((e) => SocialAccount.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  /// When [context] is provided, uses PrismService so the user sees consent once (required for social-publisher).
  Future<String> getConnectUrl(String platform, [BuildContext? context]) async {
    final profileId = await getOrCreateProfileId(context);
    SwarmSpaceResult result;
    if (context != null && context.mounted) {
      final prism = await PrismService.instance.authoriseAndCall(
        pluginId: 'social-publisher',
        params: {'_action': 'connectUrl', 'platform': platform, 'profileId': profileId},
        context: context,
      );
      if (prism.isDenied) throw Exception('Plugin skipped by user');
      if (prism.result == null || !prism.result!.success) {
        throw Exception(prism.result?.error ?? 'Failed to get connect URL');
      }
      result = prism.result!;
    } else {
      result = await _invoke('social-publisher', {
        '_action': 'connectUrl',
        'platform': platform,
        'profileId': profileId,
      });
    }

    if (!result.success || result.data == null) {
      throw Exception(result.error ?? 'Failed to get connect URL');
    }

    final connectUrl = result.data!['connectUrl'] as String?;
    if (connectUrl == null || connectUrl.isEmpty) {
      throw Exception('No connect URL returned');
    }
    return connectUrl;
  }
}
