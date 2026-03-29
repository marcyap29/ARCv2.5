import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:my_app/shared/ui/home/home_cubit.dart';
import 'package:my_app/shared/ui/home/home_state.dart';

import 'output_detail_screen.dart';
import 'output_model.dart';
import 'outputs_storage.dart';

class OutputsScreen extends StatefulWidget {
  const OutputsScreen({super.key, this.initialDetailOutput});

  /// When set (e.g. after a workflow run), opens this item’s detail on top of the list.
  final WorkflowOutput? initialDetailOutput;

  @override
  State<OutputsScreen> createState() => _OutputsScreenState();
}

class _OutputsScreenState extends State<OutputsScreen> {
  List<WorkflowOutput> _outputs = [];
  bool _loading = true;
  bool _openedInitialDetail = false;

  @override
  void initState() {
    super.initState();
    _loadOutputs();
  }

  Future<void> _clearAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF14142A),
        title: Text(
          'Clear all outputs?',
          style: GoogleFonts.inter(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'This will permanently remove all saved outputs from this device.',
          style: GoogleFonts.inter(
            color: const Color(0xFF9090B0),
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(color: const Color(0xFF7A7A9A)),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'Clear all',
              style: GoogleFonts.inter(
                color: const Color(0xFFFF6B6B),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await OutputsStorage.clearAll();
    if (!mounted) return;
    setState(() => _outputs = []);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '✓ Cleared all outputs',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        backgroundColor: const Color(0xFF1A3A1A),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _loadOutputs() async {
    final outputs = await OutputsStorage.loadAll();
    if (!mounted) return;
    setState(() {
      _outputs = outputs;
      _loading = false;
    });
    _maybeOpenInitialDetail();
  }

  void _maybeOpenInitialDetail() {
    final initial = widget.initialDetailOutput;
    if (initial == null || _openedInitialDetail || !mounted) return;
    _openedInitialDetail = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.push<void>(
        context,
        MaterialPageRoute<void>(
          builder: (_) => OutputDetailScreen(output: initial),
        ),
      );
    });
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'competitor':
        return const Color(0xFF2D1E5F);
      case 'writing':
        return const Color(0xFF2D2D5E);
      case 'plugins':
        return const Color(0xFF1E3D2F);
      default:
        return const Color(0xFF1E3A5F);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<HomeCubit, HomeState>(
      listenWhen: (prev, curr) {
        if (curr is! HomeLoaded || curr.selectedIndex != 2) return false;
        if (prev is HomeLoaded) return prev.selectedIndex != 2;
        return true;
      },
      listener: (context, state) {
        _loadOutputs();
      },
      child: Theme(
        data: Theme.of(context).copyWith(
          textTheme: GoogleFonts.interTextTheme(Theme.of(context).textTheme),
        ),
        child: Scaffold(
          backgroundColor: const Color(0xFF0F0F1A),
          body: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Outputs',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      if (!_loading && _outputs.isNotEmpty)
                        TextButton(
                          onPressed: _clearAll,
                          child: Text(
                            'Clear all',
                            style: GoogleFonts.inter(
                              color: const Color(0xFFFF6B6B),
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: _loading
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFF5B5BD6),
                          ),
                        )
                      : _outputs.isEmpty
                          ? RefreshIndicator(
                              color: const Color(0xFF5B5BD6),
                              onRefresh: _loadOutputs,
                              child: ListView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                children: [
                                  SizedBox(
                                    height: MediaQuery.of(context).size.height * 0.6,
                                    child: Center(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text('📭', style: GoogleFonts.inter(fontSize: 48)),
                                          const SizedBox(height: 16),
                                          Text(
                                            'No outputs yet',
                                            style: GoogleFonts.inter(
                                              color: Colors.white,
                                              fontSize: 18,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            'Run a workflow from the Agents tab\nto see results here.',
                                            textAlign: TextAlign.center,
                                            style: GoogleFonts.inter(
                                              color: const Color(0xFF5A5A7A),
                                              fontSize: 14,
                                              height: 1.4,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : RefreshIndicator(
                              color: const Color(0xFF5B5BD6),
                              onRefresh: _loadOutputs,
                              child: ListView.builder(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                                itemCount: _outputs.length,
                                itemBuilder: (context, index) {
                                  final output = _outputs[index];
                                  return Dismissible(
                                    key: Key(output.id),
                                    direction: DismissDirection.endToStart,
                                    background: Container(
                                      alignment: Alignment.centerRight,
                                      padding: const EdgeInsets.only(right: 20),
                                      color: const Color(0xFF3A1515),
                                      child: const Icon(
                                        Icons.delete_outline,
                                        color: Color(0xFFFF6B6B),
                                      ),
                                    ),
                                    onDismissed: (_) async {
                                      await OutputsStorage.delete(output.id);
                                      if (!mounted) return;
                                      setState(() {
                                        _outputs.removeWhere((o) => o.id == output.id);
                                      });
                                    },
                                    child: GestureDetector(
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute<void>(
                                            builder: (_) => OutputDetailScreen(output: output),
                                          ),
                                        );
                                      },
                                      child: Container(
                                        margin: const EdgeInsets.only(bottom: 12),
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF14142A),
                                          borderRadius: BorderRadius.circular(16),
                                          border: Border.all(color: const Color(0xFF1C1C30)),
                                        ),
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Container(
                                              width: 44,
                                              height: 44,
                                              decoration: BoxDecoration(
                                                borderRadius: BorderRadius.circular(12),
                                                color: _typeColor(output.type),
                                              ),
                                              alignment: Alignment.center,
                                              child: Text(
                                                output.typeEmoji,
                                                style: GoogleFonts.inter(fontSize: 20),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    children: [
                                                      Expanded(
                                                        child: Text(
                                                          output.title,
                                                          maxLines: 1,
                                                          overflow: TextOverflow.ellipsis,
                                                          style: GoogleFonts.inter(
                                                            color: Colors.white,
                                                            fontSize: 14,
                                                            fontWeight: FontWeight.w700,
                                                          ),
                                                        ),
                                                      ),
                                                      const SizedBox(width: 10),
                                                      Text(
                                                        output.typeLabel,
                                                        style: GoogleFonts.robotoMono(
                                                          color: const Color(0xFF5B5BD6),
                                                          fontSize: 10,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    output.preview,
                                                    maxLines: 2,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: GoogleFonts.inter(
                                                      color: const Color(0xFF5A5A7A),
                                                      fontSize: 12,
                                                      height: 1.4,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 6),
                                                  Text(
                                                    _formatDate(output.createdAt),
                                                    style: GoogleFonts.inter(
                                                      color: const Color(0xFF33334A),
                                                      fontSize: 11,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
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
}

