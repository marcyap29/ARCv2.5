// lib/shared/ui/chronicle/dual_chronicle_view.dart
//
// Dual Chronicle settings screen: User's timeline vs LUMARA's learning,
// pending "Add to Timeline" offers, and summary counts.

import 'package:flutter/material.dart';
import 'package:my_app/chronicle/dual/services/dual_chronicle_services.dart';
import 'package:my_app/chronicle/dual/services/promotion_service.dart';
import 'package:my_app/services/firebase_auth_service.dart';
import 'package:my_app/shared/app_colors.dart';
import 'package:my_app/shared/text_style.dart';

class DualChronicleView extends StatefulWidget {
  const DualChronicleView({super.key});

  @override
  State<DualChronicleView> createState() => _DualChronicleViewState();
}

class _DualChronicleViewState extends State<DualChronicleView> {
  String get _userId => FirebaseAuthService.instance.currentUser?.uid ?? 'default_user';

  List<PromotionOffer> _pendingOffers = [];
  int _annotationCount = 0;
  int _gapFillCount = 0;
  bool _loading = true;
  String? _error;

  static const double _bodyFontSize = 13;
  static const double _sectionTitleFontSize = 14;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final userRepo = DualChronicleServices.userChronicle;
      final lumaraRepo = DualChronicleServices.lumaraChronicle;
      final offers = DualChronicleServices.promotionService.getPendingOffers(_userId);
      final annotations = await userRepo.loadAnnotations(_userId);
      final gapFills = await lumaraRepo.loadGapFillEvents(_userId);
      if (mounted) {
        setState(() {
          _pendingOffers = offers;
          _annotationCount = annotations.length;
          _gapFillCount = gapFills.length;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _approvePromotion(String gapFillEventId) async {
    try {
      await DualChronicleServices.promotionService.approvePromotion(_userId, gapFillEventId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Added to timeline')),
        );
        _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    }
  }

  Future<void> _dismissPromotion(String gapFillEventId) async {
    await DualChronicleServices.promotionService.dismissPromotion(_userId, gapFillEventId);
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kcBackgroundColor,
      appBar: AppBar(
        backgroundColor: kcBackgroundColor,
        elevation: 0,
        leading: const BackButton(color: kcPrimaryTextColor),
        title: Text(
          'Timeline & Learning',
          style: heading3Style(context).copyWith(
            color: kcPrimaryTextColor,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: kcAccentColor))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildExplanation(),
                  if (_error != null) _buildError(),
                  if (_pendingOffers.isNotEmpty) _buildPendingOffers(),
                  _buildSummary(),
                ],
              ),
            ),
    );
  }

  Widget _buildExplanation() {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Two chronicles',
            style: bodyStyle(context).copyWith(
              color: kcPrimaryTextColor,
              fontWeight: FontWeight.w600,
              fontSize: _sectionTitleFontSize,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "Your timeline contains only what you've written or explicitly approved. "
            "LUMARA's learning lives in a separate space. When something is worth adding, "
            "you'll see an offer here and can choose Add to Timeline or Dismiss.",
            style: bodyStyle(context).copyWith(
              color: kcSecondaryTextColor,
              height: 1.35,
              fontSize: _bodyFontSize,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        _error!,
        style: bodyStyle(context).copyWith(
          color: kcDangerColor,
          fontSize: _bodyFontSize,
        ),
      ),
    );
  }

  Widget _buildPendingOffers() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lightbulb_outline, color: kcWarningColor, size: 18),
              const SizedBox(width: 6),
              Text(
                'Timeline update available',
                style: bodyStyle(context).copyWith(
                  color: kcPrimaryTextColor,
                  fontWeight: FontWeight.w600,
                  fontSize: _sectionTitleFontSize,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ..._pendingOffers.map((offer) => _buildOfferCard(offer)),
        ],
      ),
    );
  }

  Widget _buildOfferCard(PromotionOffer offer) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kcWarningColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            offer.suggestedContent,
            style: bodyStyle(context).copyWith(
              color: kcPrimaryTextColor,
              fontSize: _bodyFontSize,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () => _dismissPromotion(offer.gapFillEventId),
                child: Text(
                  'Dismiss',
                  style: bodyStyle(context).copyWith(
                    color: kcSecondaryTextColor,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: kcAccentColor,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () => _approvePromotion(offer.gapFillEventId),
                child: Text(
                  'Add to Timeline',
                  style: bodyStyle(context).copyWith(fontSize: 13),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummary() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Summary',
            style: bodyStyle(context).copyWith(
              color: kcPrimaryTextColor,
              fontWeight: FontWeight.w600,
              fontSize: _sectionTitleFontSize,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _summaryChip('Approved on timeline', _annotationCount),
              const SizedBox(width: 8),
              _summaryChip('Learning events', _gapFillCount),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryChip(String label, int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$count',
            style: bodyStyle(context).copyWith(
              color: kcAccentColor,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: bodyStyle(context).copyWith(
              color: kcSecondaryTextColor,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
