import 'dart:ui';

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
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: Container(
          margin: const EdgeInsets.all(1),
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.glass,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.white.withValues(alpha: .9)),
            boxShadow: [
              BoxShadow(
                color: AppColors.brandNavy.withValues(alpha: .14),
                blurRadius: 30,
                offset: const Offset(0, 14),
              ),
              BoxShadow(
                color: Colors.white.withValues(alpha: .9),
                blurRadius: 1,
                offset: const Offset(0, -1),
              ),
            ],
          ),
          child: Row(
            children: List.generate(navBarConfig.items.length, (index) {
              final item = navBarConfig.items[index];
              final selected = navBarConfig.selectedIndex == index;

              return Expanded(
                child: Semantics(
                  selected: selected,
                  button: true,
                  label: item.title ?? '',
                  child: InkWell(
                    onTap: () => navBarConfig.onItemSelected(index),
                    borderRadius: BorderRadius.circular(22),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 320),
                      curve: Curves.easeOutCubic,
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      transform: Matrix4.translationValues(
                        0,
                        selected ? -3 : 0,
                        0,
                      ),
                      decoration: BoxDecoration(
                        gradient: selected
                            ? const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Color(0xFFFFFFFF),
                                  Color(0xFFEAF5F0),
                                ],
                              )
                            : null,
                        borderRadius: BorderRadius.circular(22),
                        border: selected
                            ? Border.all(
                                color:
                                    AppColors.brandBlue.withValues(alpha: .16),
                              )
                            : null,
                        boxShadow: selected
                            ? [
                                BoxShadow(
                                  color: AppColors.brandBlue
                                      .withValues(alpha: .18),
                                  blurRadius: 16,
                                  offset: const Offset(0, 7),
                                ),
                              ]
                            : null,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AnimatedScale(
                            duration: const Duration(milliseconds: 260),
                            curve: Curves.easeOutBack,
                            scale: selected ? 1.12 : 1,
                            child: ShaderMask(
                              blendMode: BlendMode.srcIn,
                              shaderCallback: (bounds) => (selected
                                      ? AppColors.accentGradient
                                      : const LinearGradient(
                                          colors: [
                                            AppColors.textSecondary,
                                            AppColors.textSecondary,
                                          ],
                                        ))
                                  .createShader(bounds),
                              child: IconTheme(
                                data: const IconThemeData(
                                  color: Colors.white,
                                  size: 22,
                                ),
                                child: selected ? item.icon : item.inactiveIcon,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 220),
                            style: item.textStyle.copyWith(
                              color: selected
                                  ? AppColors.brandBlue
                                  : AppColors.textSecondary,
                              fontSize: 10.5,
                              fontWeight:
                                  selected ? FontWeight.w900 : FontWeight.w700,
                            ),
                            child: Text(
                              item.title ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
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
        ),
      ),
    );
  }
}
