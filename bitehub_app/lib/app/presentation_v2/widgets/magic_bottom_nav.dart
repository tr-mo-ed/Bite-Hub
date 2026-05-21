import 'package:flutter/material.dart';
import 'package:persistent_bottom_nav_bar_v2/persistent_bottom_nav_bar_v2.dart';

import 'package:bitehub_app/app/core/theme/app_colors.dart';

class MagicBottomNav extends StatelessWidget {
  const MagicBottomNav({
    super.key,
    required this.navBarConfig,
  });

  final NavBarConfig navBarConfig;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white,
            Color(0xFFF8FBFF),
          ],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: List.generate(navBarConfig.items.length, (index) {
          final item = navBarConfig.items[index];
          final selected = navBarConfig.selectedIndex == index;
          final activeColor = item.activeForegroundColor;
          final inactiveColor = item.inactiveForegroundColor;

          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: InkWell(
                onTap: () => navBarConfig.onItemSelected(index),
                borderRadius: BorderRadius.circular(20),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 240),
                  curve: Curves.easeOutCubic,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: selected
                        ? const LinearGradient(
                            begin: Alignment.topRight,
                            end: Alignment.bottomLeft,
                            colors: [
                              Color(0xFF1E40AF),
                              Color(0xFF2563EB),
                              Color(0xFF38BDF8),
                            ],
                          )
                        : null,
                    color: selected ? null : Colors.transparent,
                    boxShadow: selected
                        ? [
                            BoxShadow(
                              color: activeColor.withValues(alpha: 0.26),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ]
                        : const [],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 240),
                        curve: Curves.easeOutCubic,
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: selected
                              ? Colors.white.withValues(alpha: 0.18)
                              : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: selected
                                ? Colors.white.withValues(alpha: 0.18)
                                : AppColors.border,
                          ),
                        ),
                        child: IconTheme(
                          data: IconThemeData(
                            color: selected ? Colors.white : inactiveColor,
                            size: item.iconSize - 3,
                          ),
                          child: Center(
                            child: selected ? item.icon : item.inactiveIcon,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        item.title ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: item.textStyle.copyWith(
                          fontSize: 11,
                          fontWeight:
                              selected ? FontWeight.w800 : FontWeight.w600,
                          color: selected ? Colors.white : inactiveColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
