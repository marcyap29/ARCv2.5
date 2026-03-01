// lib/lumara/agents/screens/plugin_catalog_screen.dart
//
// SwarmSpace plugin catalog: shows all plugins with description, status, and example query.
// Unavailable plugins are greyed out. Used for discovery and transparency.

import 'package:flutter/material.dart';
import 'package:my_app/services/swarmspace/swarmspace_client.dart';
import 'package:my_app/shared/app_colors.dart';
import 'package:my_app/shared/text_style.dart';

/// Human-readable display name for plugin IDs.
String _pluginDisplayName(String pluginId) {
  const names = {
    'gemini-flash': 'Gemini Flash',
    'brave-search': 'Brave Search',
    'semantic-scholar': 'Semantic Scholar',
    'weather': 'Weather',
    'wikipedia': 'Wikipedia',
    'currency': 'Currency',
    'news': 'News',
    'url-reader': 'URL Reader',
    'tavily-search': 'Tavily Search',
    'exa-search': 'Exa Search',
    'perplexity-sonar': 'Perplexity Sonar',
  };
  return names[pluginId] ?? pluginId;
}

/// Icon for each plugin type.
IconData _pluginIcon(String pluginId) {
  if (pluginId.contains('search')) return Icons.search;
  if (pluginId.contains('weather')) return Icons.wb_sunny;
  if (pluginId.contains('currency')) return Icons.attach_money;
  if (pluginId.contains('news')) return Icons.newspaper;
  if (pluginId.contains('wikipedia')) return Icons.menu_book;
  if (pluginId.contains('url')) return Icons.link;
  if (pluginId.contains('gemini') || pluginId.contains('perplexity')) return Icons.auto_awesome;
  if (pluginId.contains('scholar')) return Icons.school;
  return Icons.extension;
}

/// SwarmSpace plugin catalog screen.
class PluginCatalogScreen extends StatefulWidget {
  const PluginCatalogScreen({super.key});

  @override
  State<PluginCatalogScreen> createState() => _PluginCatalogScreenState();
}

class _PluginCatalogScreenState extends State<PluginCatalogScreen> {
  PluginCatalogResult? _catalog;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCatalog();
  }

  Future<void> _loadCatalog() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final catalog = await SwarmSpaceClient.instance.getPluginCatalog();
    if (mounted) {
      setState(() {
        _catalog = catalog;
        _loading = false;
        if (catalog == null) {
          _error = 'Sign in to view SwarmSpace capabilities.';
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kcBackgroundColor,
      appBar: AppBar(
        backgroundColor: kcBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
          color: kcPrimaryTextColor,
        ),
        title: Text(
          'SwarmSpace Capabilities',
          style: heading2Style(context).copyWith(
            color: kcPrimaryTextColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _loadCatalog,
            tooltip: 'Refresh',
            color: kcPrimaryTextColor,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.cloud_off, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                _error!,
                style: bodyStyle(context).copyWith(color: kcSecondaryTextColor),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }
    final plugins = _catalog?.plugins ?? [];
    if (plugins.isEmpty) {
      return Center(
        child: Text(
          'No plugins available.',
          style: bodyStyle(context).copyWith(color: kcSecondaryTextColor),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadCatalog,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: plugins.length,
        itemBuilder: (context, index) {
          final plugin = plugins[index];
          return _PluginCatalogCard(
            entry: plugin,
            displayName: _pluginDisplayName(plugin.pluginId),
            icon: _pluginIcon(plugin.pluginId),
            upgradeUrl: _catalog?.upgradeUrl,
          );
        },
      ),
    );
  }
}

class _PluginCatalogCard extends StatelessWidget {
  final PluginCatalogEntry entry;
  final String displayName;
  final IconData icon;
  final String? upgradeUrl;

  const _PluginCatalogCard({
    required this.entry,
    required this.displayName,
    required this.icon,
    this.upgradeUrl,
  });

  @override
  Widget build(BuildContext context) {
    final isAvailable = entry.available;
    final opacity = isAvailable ? 1.0 : 0.5;

    return Opacity(
      opacity: opacity,
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        color: kcSurfaceAltColor,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: (isAvailable ? kcPrimaryColor : Colors.grey)
                          .withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      icon,
                      color: isAvailable ? kcPrimaryColor : Colors.grey,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: kcPrimaryTextColor,
                              ),
                        ),
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _tierColor(entry.requiredTier).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            entry.requiredTier.toUpperCase(),
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: _tierColor(entry.requiredTier),
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    isAvailable ? Icons.check_circle : Icons.lock_outline,
                    color: isAvailable ? kcSuccessColor : Colors.grey,
                    size: 24,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                entry.description,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: kcSecondaryTextColor,
                    ),
              ),
              if (entry.exampleQuery.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: kcSurfaceColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.lightbulb_outline,
                        size: 16,
                        color: kcPrimaryColor.withOpacity(0.8),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '"${entry.exampleQuery}"',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: kcSecondaryTextColor,
                                fontStyle: FontStyle.italic,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (!isAvailable && upgradeUrl != null) ...[
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: () {
                    // Could launch URL: url_launcher
                  },
                  icon: const Icon(Icons.upgrade, size: 18),
                  label: const Text('Upgrade to access'),
                  style: TextButton.styleFrom(
                    foregroundColor: kcPrimaryColor,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Color _tierColor(String tier) {
    switch (tier) {
      case 'free':
        return kcSuccessColor;
      case 'standard':
        return kcPrimaryColor;
      case 'premium':
        return kcAccentColor;
      default:
        return kcSecondaryTextColor;
    }
  }
}
