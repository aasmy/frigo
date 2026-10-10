import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/repositories/entitlement_repository.dart';
import '../../shared/widgets/frigo_banner_ad.dart';

import '../../core/routing/route_names.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/haptics.dart';

/// App shell: three shell branches (Home, Kitchen, Recipes) plus a raised
/// circular Scan button that pushes the full-screen scan flow.
class ScaffoldWithNav extends ConsumerWidget {
  const ScaffoldWithNav({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  void _goBranch(int index) {
    Haptics.tap();
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = navigationShell.currentIndex;
    final showAds = ref.watch(showAdsProvider);
    return Scaffold(
      body: navigationShell,
      // One banner for the whole shell, pinned above the nav bar. The scan,
      // confirm and cook flows are full-screen routes *above* this shell, so
      // they are ad-free without needing a rule anywhere else.
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showAds) const FrigoBannerAd(),
          Container(
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(top: BorderSide(color: AppColors.divider)),
            ),
            child: SafeArea(
              top: false,
              child: SizedBox(
                height: 64,
                child: Row(
                  children: [
                    _NavItem(
                      icon: Icons.home_outlined,
                      activeIcon: Icons.home_rounded,
                      label: 'Home',
                      selected: current == 0,
                      onTap: () => _goBranch(0),
                    ),
                    _NavItem(
                      icon: Icons.kitchen_outlined,
                      activeIcon: Icons.kitchen_rounded,
                      label: 'Kitchen',
                      selected: current == 1,
                      onTap: () => _goBranch(1),
                    ),
                    _ScanButton(
                      onTap: () {
                        Haptics.light();
                        context.push(Routes.scan);
                      },
                    ),
                    _NavItem(
                      icon: Icons.restaurant_menu_outlined,
                      activeIcon: Icons.restaurant_menu_rounded,
                      label: 'Recipes',
                      selected: current == 2,
                      onTap: () => _goBranch(2),
                    ),
                    _NavItem(
                      icon: Icons.person_outline_rounded,
                      activeIcon: Icons.person_rounded,
                      label: 'Profile',
                      selected: current == 3,
                      onTap: () => _goBranch(3),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : AppColors.textTertiary;
    return Expanded(
      child: InkResponse(
        onTap: onTap,
        radius: 46,
        highlightColor: Colors.transparent,
        splashColor: AppColors.primarySoft.withValues(alpha: 0.5),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedSwitcher(
              duration: AppMotion.fast,
              child: Icon(
                selected ? activeIcon : icon,
                key: ValueKey(selected),
                color: color,
                size: 25,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                letterSpacing: 0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScanButton extends StatefulWidget {
  const _ScanButton({required this.onTap});
  final VoidCallback onTap;

  @override
  State<_ScanButton> createState() => _ScanButtonState();
}

class _ScanButtonState extends State<_ScanButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 84,
      child: Center(
        child: GestureDetector(
          onTapDown: (_) => setState(() => _down = true),
          onTapCancel: () => setState(() => _down = false),
          onTapUp: (_) => setState(() => _down = false),
          onTap: widget.onTap,
          child: AnimatedScale(
            scale: _down ? 0.9 : 1,
            duration: AppMotion.fast,
            curve: Curves.easeOut,
            child: Container(
              height: 56,
              width: 56,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
                boxShadow: AppColors.floatingShadow,
              ),
              child: const Icon(
                Icons.document_scanner_outlined,
                color: AppColors.onPrimary,
                size: 25,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
