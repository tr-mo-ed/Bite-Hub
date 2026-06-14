import 'dart:async';
import 'package:flutter/material.dart';

import 'package:bitehub_app/app/core/theme/app_colors.dart';

class CustomFloatingSnackBar {
  static Future<void> show(
    BuildContext context, {
    required String title,
    required String message,
    IconData icon = Icons.notifications_active_rounded,
    Color accentColor = AppColors.brandBlue,
    Duration duration = const Duration(seconds: 4),
    VoidCallback? onTap,
  }) async {
    final overlay = Overlay.maybeOf(context);
    if (overlay == null) {
      return;
    }

    late final OverlayEntry entry;
    var removed = false;
    void dismiss() {
      if (removed) {
        return;
      }
      removed = true;
      entry.remove();
    }

    entry = OverlayEntry(
      builder: (context) {
        return _FloatingTopBanner(
          title: title,
          message: message,
          icon: icon,
          accentColor: accentColor,
          onTap: onTap == null
              ? null
              : () {
                  dismiss();
                  onTap();
                },
        );
      },
    );

    overlay.insert(entry);
    await Future<void>.delayed(duration);
    dismiss();
  }
}

class _FloatingTopBanner extends StatefulWidget {
  const _FloatingTopBanner({
    required this.title,
    required this.message,
    required this.icon,
    required this.accentColor,
    this.onTap,
  });

  final String title;
  final String message;
  final IconData icon;
  final Color accentColor;
  final VoidCallback? onTap;

  @override
  State<_FloatingTopBanner> createState() => _FloatingTopBannerState();
}

class _FloatingTopBannerState extends State<_FloatingTopBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _offset;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _offset = Tween<Offset>(
      begin: const Offset(0, -0.16),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _opacity = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    unawaited(_controller.forward());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
          child: FadeTransition(
            opacity: _opacity,
            child: SlideTransition(
              position: _offset,
              child: Material(
                color: Colors.white,
                elevation: 0,
                borderRadius: BorderRadius.circular(18),
                child: InkWell(
                  onTap: widget.onTap,
                  borderRadius: BorderRadius.circular(18),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppColors.border),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 24,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.asset(
                            'assets/images/bitehub_app_icon.png',
                            width: 44,
                            height: 44,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  const Text(
                                    'Bite Hub',
                                    style: TextStyle(
                                      color: AppColors.brandBlue,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    width: 5,
                                    height: 5,
                                    decoration: BoxDecoration(
                                      color: widget.accentColor,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                widget.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                widget.message,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  height: 1.35,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 34,
                          height: 34,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: widget.accentColor.withValues(alpha: .10),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            widget.icon,
                            color: widget.accentColor,
                            size: 18,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
