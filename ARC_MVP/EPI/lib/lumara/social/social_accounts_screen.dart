// lib/lumara/social/social_accounts_screen.dart
// Phase 7: Connect social accounts via Late.com OAuth.

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:my_app/lumara/social/late_profile_service.dart';

const List<String> _platforms = [
  'linkedin',
  'bluesky',
  'threads',
  'twitter',
  'instagram',
  'facebook',
  'tiktok',
  'reddit',
];

String _platformLabel(String key) {
  switch (key) {
    case 'linkedin':
      return 'LinkedIn';
    case 'bluesky':
      return 'Bluesky';
    case 'threads':
      return 'Threads';
    case 'twitter':
      return 'Twitter/X';
    case 'instagram':
      return 'Instagram';
    case 'facebook':
      return 'Facebook';
    case 'tiktok':
      return 'TikTok';
    case 'reddit':
      return 'Reddit';
    default:
      return key[0].toUpperCase() + key.substring(1);
  }
}

class SocialAccountsScreen extends StatefulWidget {
  const SocialAccountsScreen({super.key});

  @override
  State<SocialAccountsScreen> createState() => _SocialAccountsScreenState();
}

class _SocialAccountsScreenState extends State<SocialAccountsScreen> {
  List<SocialAccount> _accounts = [];
  bool _loading = true;
  String? _error;

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final accounts = await LateProfileService.instance.getConnectedAccounts();
      if (mounted) {
        setState(() {
          _accounts = accounts;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _accounts = [];
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _connectPlatform(String platform) async {
    try {
      final url = await LateProfileService.instance.getConnectUrl(platform);
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Complete sign-in in your browser, then tap Done to refresh.'),
              duration: Duration(seconds: 4),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not open: $url')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to get connect URL: $e')),
        );
      }
    }
  }

  void _disconnectStub() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Disconnect — Coming soon')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final connectedPlatforms = _accounts.map((a) => a.platform.toLowerCase()).toSet();
    final unconnected = _platforms.where((p) => !connectedPlatforms.contains(p)).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Connected Accounts'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Connect your social accounts to publish directly from LUMARA',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 20),
                    if (_error != null) ...[
                      Text(
                        _error!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.error,
                            ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    const Text(
                      'Connected',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_accounts.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Text(
                          'No accounts connected yet. Use the chips below to connect.',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      )
                    else
                      ..._accounts.map((a) => Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: CircleAvatar(
                                child: Text(
                                  _platformLabel(a.platform).substring(0, 1),
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                              title: Text(_platformLabel(a.platform)),
                              subtitle: Text(a.username.isNotEmpty ? a.username : a.id),
                              trailing: TextButton(
                                onPressed: _disconnectStub,
                                child: const Text('Disconnect'),
                              ),
                            ),
                          )),
                    const SizedBox(height: 24),
                    const Text(
                      'Connect a platform',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: unconnected
                          .map((p) => ActionChip(
                                label: Text(_platformLabel(p)),
                                onPressed: () => _connectPlatform(p),
                              ))
                          .toList(),
                    ),
                    const SizedBox(height: 24),
                    OutlinedButton.icon(
                      onPressed: _load,
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Done — refresh list'),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
