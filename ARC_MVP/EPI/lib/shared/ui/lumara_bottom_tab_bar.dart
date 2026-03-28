import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:my_app/app/app.dart' show navigatorKey;
import 'package:my_app/core/feature_flags.dart' as core_flags;
import 'package:my_app/shared/tab_bar.dart';
import 'package:my_app/shared/ui/home/home_cubit.dart';

/// Bottom tabs matching the main shell: LUMARA | Agents | Outputs | Settings.
/// Use on pushed screens (e.g. output detail, writing) so users can exit without being trapped.
class LumaraUnifiedBottomBar extends StatelessWidget {
  const LumaraUnifiedBottomBar({
    super.key,
    required this.currentIndex,
  });

  /// 0 = LUMARA, 1 = Agents, 2 = Outputs, 3 = Settings
  final int currentIndex;

  void _goToTab(BuildContext context, int index) {
    HomeCubit? cubit;
    try {
      cubit = context.read<HomeCubit>();
    } catch (_) {
      final ctx = navigatorKey.currentContext;
      if (ctx != null) {
        try {
          cubit = ctx.read<HomeCubit>();
        } catch (_) {}
      }
    }
    if (cubit == null) return;
    final nav = Navigator.of(context);
    nav.popUntil((route) => route.isFirst);
    cubit.changeTab(index);
  }

  @override
  Widget build(BuildContext context) {
    if (!core_flags.FeatureFlags.USE_UNIFIED_FEED) {
      return const SizedBox.shrink();
    }
    return CustomTabBar(
      tabs: const [
        TabItem(icon: Icons.auto_awesome, text: 'LUMARA'),
        TabItem(icon: Icons.smart_toy, text: 'Agents'),
        TabItem(icon: Icons.folder, text: 'Outputs'),
        TabItem(icon: Icons.settings, text: 'Settings'),
      ],
      selectedIndex: currentIndex,
      onTabSelected: (i) => _goToTab(context, i),
      showCenterButton: false,
    );
  }
}
