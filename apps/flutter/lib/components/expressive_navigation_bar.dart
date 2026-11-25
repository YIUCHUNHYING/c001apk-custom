import 'package:flutter/material.dart';

/// Keeps Material navigation semantics, focus and touch targets while adding
/// a compact tonal surface and a small spring response to selection.
class ExpressiveNavigationBar extends StatelessWidget {
  const ExpressiveNavigationBar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final reduced = MediaQuery.disableAnimationsOf(context);
    const icons = [
      Icons.home_outlined,
      Icons.feed_outlined,
      Icons.person_outline
    ];
    const selectedIcons = [Icons.home, Icons.feed, Icons.person];
    const labels = ['主页', '关注', '我的'];
    // 白底 + 顶部一根极细分隔线；内容居中并限宽，避免宽屏上三个入口被
    // 拉得过散。选中项用品牌色胶囊与实心图标，整体更精致克制。
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(
          top: BorderSide(
            color: colors.outlineVariant.withValues(alpha: .55),
            width: .5,
          ),
        ),
      ),
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: NavigationBarTheme(
            data: NavigationBarThemeData(
              height: 64 +
                  (MediaQuery.textScalerOf(context).scale(12) - 12)
                      .clamp(0, 32),
              backgroundColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              indicatorColor: colors.primaryContainer,
              indicatorShape: const StadiumBorder(),
              labelTextStyle: WidgetStateProperty.resolveWith((states) {
                final selected = states.contains(WidgetState.selected);
                return TextStyle(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? colors.primary : colors.onSurfaceVariant,
                );
              }),
              iconTheme: WidgetStateProperty.resolveWith((states) {
                final selected = states.contains(WidgetState.selected);
                return IconThemeData(
                  size: 24,
                  color: selected
                      ? colors.onPrimaryContainer
                      : colors.onSurfaceVariant,
                );
              }),
            ),
            child: NavigationBar(
              selectedIndex: selectedIndex,
              onDestinationSelected: onDestinationSelected,
              animationDuration:
                  reduced ? Duration.zero : const Duration(milliseconds: 400),
              labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
              destinations: [
                for (var i = 0; i < labels.length; i++)
                  NavigationDestination(
                    label: labels[i],
                    icon: AnimatedScale(
                      scale: selectedIndex == i ? 1.12 : 1,
                      duration: reduced
                          ? Duration.zero
                          : const Duration(milliseconds: 400),
                      curve: Curves.easeOutBack,
                      child: Icon(
                          selectedIndex == i ? selectedIcons[i] : icons[i]),
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
