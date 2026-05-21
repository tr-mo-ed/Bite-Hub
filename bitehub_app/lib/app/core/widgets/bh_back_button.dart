import 'package:flutter/material.dart';

import 'package:bitehub_app/app/core/theme/app_colors.dart';

class BhBackButton extends StatelessWidget {
  const BhBackButton({
    super.key,
    this.onPressed,
    this.tooltip = 'رجوع',
    this.dark = false,
  });

  final VoidCallback? onPressed;
  final String tooltip;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final foreground = dark ? Colors.white : AppColors.textPrimary;
    final background = dark
        ? Colors.white.withValues(alpha: 0.14)
        : Colors.white.withValues(alpha: 0.92);
    final borderColor =
        dark ? Colors.white.withValues(alpha: 0.16) : AppColors.border;

    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed ?? () => Navigator.of(context).maybePop(),
      icon: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: dark ? 0.12 : 0.05),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Icon(
          Icons.arrow_back_ios_new_rounded,
          size: 18,
          color: foreground,
        ),
      ),
    );
  }
}
