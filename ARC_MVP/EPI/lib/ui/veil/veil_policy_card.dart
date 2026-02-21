import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

/// VeilPolicyCard
/// - Reads latest line from mcp/policies/veil/<YYYY-MM>.jsonl
/// - Displays readiness, cadence, and prompt weights
class VeilPolicyCard extends StatefulWidget {
  /// Root directory where `mcp/` lives. Defaults to current working dir.
  final Directory? root;

  /// Optional override for month key (e.g., "2025-10"). Defaults to UTC now.
  final String? monthKeyOverride;

  /// Optional header title
  final String title;

  /// If > 0, auto-refresh every [autoRefreshSeconds].
  final int autoRefreshSeconds;

  const VeilPolicyCard({
    super.key,
    this.root,
    this.monthKeyOverride,
    this.title = 'VEIL Policy',
    this.autoRefreshSeconds = 0,
  });

  @override
  State<VeilPolicyCard> createState() => _VeilPolicyCardState();
}

class _VeilPolicyCardState extends State<VeilPolicyCard> {
  Map<String, dynamic>? _policy;
  String? _error;
  Timer? _timer;
  bool _loading = false;
  Directory? _resolvedRoot;

  @override
  void initState() {
    super.initState();
    _resolveRoot();
  }

  Future<void> _resolveRoot() async {
    if (widget.root != null) {
      _resolvedRoot = widget.root;
      _load();
      return;
    }

    // Default to app documents directory where MCP files are typically stored
    try {
      final appDir = await getApplicationDocumentsDirectory();
      _resolvedRoot = Directory(appDir.path);
      _load();
      
      if (widget.autoRefreshSeconds > 0) {
        _timer = Timer.periodic(
          Duration(seconds: widget.autoRefreshSeconds),
          (_) => _load(),
        );
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to resolve MCP directory: $e';
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _monthKeyUtc() {
    if (widget.monthKeyOverride != null) return widget.monthKeyOverride!;
    final now = DateTime.now().toUtc();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}';
  }

  Future<void> _load() async {
    if (_resolvedRoot == null) {
      await _resolveRoot();
      if (_resolvedRoot == null) return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final monthKey = _monthKeyUtc();
      final file = File(_resolvedRoot!.uri
          .resolve('mcp/policies/veil/$monthKey.jsonl')
          .toFilePath());

      if (!await file.exists()) {
        setState(() {
          _policy = null;
          _error = 'No policy file for $monthKey';
          _loading = false;
        });
        return;
      }

      // Read last non-empty line efficiently
      final raf = await file.open(mode: FileMode.read);
      try {
        final length = await raf.length();
        const chunk = 8 * 1024;
        int offset = length;
        String carry = '';
        List<String> lines = [];

        while (offset > 0 && lines.length < 50) {
          final read = (offset - chunk) >= 0 ? chunk : offset;
          offset -= read;
          await raf.setPosition(offset);
          final data = await raf.read(read);
          final text = utf8.decode(data) + carry;
          final parts = const LineSplitter().convert(text);

          if (offset > 0) {
            // first part may be partial, keep as carry
            carry = parts.first;
            lines.addAll(parts.skip(1));
          } else {
            lines.addAll(parts);
          }

          final last = lines.where((l) => l.trim().isNotEmpty).toList();
          if (last.isNotEmpty) {
            final obj = jsonDecode(last.last) as Map<String, dynamic>;
            setState(() {
              _policy = obj;
              _loading = false;
            });
            return;
          }
        }

        setState(() {
          _policy = null;
          _error = 'Empty policy file';
          _loading = false;
        });
      } finally {
        await raf.close();
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Color _cadenceColor(String? cadence, BuildContext ctx) {
    switch (cadence) {
      case 'light':
        return Colors.greenAccent.withOpacity(0.8);
      case 'standard':
        return Theme.of(ctx).colorScheme.primary.withOpacity(0.85);
      case 'reflective':
        return Colors.amber.withOpacity(0.9);
      default:
        return Theme.of(ctx).colorScheme.secondaryContainer;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.all(12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: _loading
            ? const SizedBox(
                height: 120,
                child: Center(child: CircularProgressIndicator()))
            : _error != null
                ? _ErrorView(msg: _error!, onRetry: _load)
                : _policy == null
                    ? _ErrorView(msg: 'No policy found', onRetry: _load)
                    : _PolicyView(
                        policy: _policy!,
                        onRefresh: _load,
                        cadenceColor: _cadenceColor,
                      ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String msg;
  final VoidCallback onRetry;
  const _ErrorView({required this.msg, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('VEIL Policy',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(msg, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 12),
        OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry')),
      ],
    );
  }
}

class _PolicyView extends StatelessWidget {
  final Map<String, dynamic> policy;
  final VoidCallback onRefresh;
  final Color Function(String?, BuildContext) cadenceColor;

  const _PolicyView({
    required this.policy,
    required this.onRefresh,
    required this.cadenceColor,
  });

  @override
  Widget build(BuildContext context) {
    final readiness = (policy['readiness'] as num?)?.toInt() ?? 0;
    final cadence = policy['journal_cadence'] as String?;
    final weights = (policy['prompt_weights'] as Map?)
            ?.cast<String, num>() ??
        {};
    final nudges = (policy['nudges'] ??
            policy['coach_nudges'] ??
            const <dynamic>[]) as List;
    final dayKey = policy['day_key'] as String? ?? '—';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('VEIL Policy',
                style: Theme.of(context).textTheme.titleMedium),
            const Spacer(),
            IconButton(
                onPressed: onRefresh, icon: const Icon(Icons.refresh))
          ],
        ),
        const SizedBox(height: 4),
        Text('Day: $dayKey',
            style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 16),

        // Readiness gauge
        Row(
          children: [
            SizedBox(
              width: 68,
              height: 68,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: readiness / 100.0,
                    strokeWidth: 8,
                  ),
                  Text('$readiness',
                      style: Theme.of(context).textTheme.titleMedium),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: cadenceColor(cadence, context),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('Cadence: ${cadence ?? '—'}',
                  style: Theme.of(context)
                      .textTheme
                      .labelLarge
                      ?.copyWith(color: Colors.black87)),
            ),
          ],
        ),

        const SizedBox(height: 16),
        Text('Prompt Weights',
            style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        _WeightBar(label: 'Empathy', value: (weights['empathy'] ?? 0).toDouble()),
        _WeightBar(label: 'Depth', value: (weights['depth'] ?? 0).toDouble()),
        _WeightBar(label: 'Agency', value: (weights['agency'] ?? 0).toDouble()),

        if (nudges.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('Coach Nudges',
              style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: nudges.map((n) => Chip(label: Text(n.toString()))).toList(),
          ),
        ],
      ],
    );
  }
}

class _WeightBar extends StatelessWidget {
  final String label;
  final double value; // 0..1
  const _WeightBar({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final pct = (value.clamp(0.0, 1.0) * 100).toStringAsFixed(0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Expanded(child: Text(label)),
          Text('$pct%'),
        ]),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: value.clamp(0.0, 1.0),
            minHeight: 10,
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}
