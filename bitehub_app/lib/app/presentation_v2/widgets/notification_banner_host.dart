import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:bitehub_app/app/data/models/notification_model.dart';
import 'package:bitehub_app/app/data/providers/notification_provider.dart';
import 'package:bitehub_app/app/presentation_v2/widgets/custom_floating_snack_bar.dart';
import 'package:bitehub_app/app/presentation_v2/widgets/order_status_ui.dart';

class NotificationBannerHost extends StatefulWidget {
  const NotificationBannerHost({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  State<NotificationBannerHost> createState() => _NotificationBannerHostState();
}

class _NotificationBannerHostState extends State<NotificationBannerHost> {
  int _lastBannerSequence = 0;

  @override
  Widget build(BuildContext context) {
    return Consumer<NotificationProvider>(
      builder: (context, provider, _) {
        final pendingBanner = provider.pendingBanner;
        if (pendingBanner != null &&
            provider.bannerSequence != _lastBannerSequence) {
          _lastBannerSequence = provider.bannerSequence;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showBanner(context, provider, pendingBanner);
          });
        }
        return widget.child;
      },
    );
  }

  Future<void> _showBanner(
    BuildContext context,
    NotificationProvider provider,
    NotificationItem item,
  ) async {
    final status = BhOrderStatusSpec.fromStatus(item.status);

    provider.clearPendingBanner();
    await CustomFloatingSnackBar.show(
      context,
      title: item.title,
      message: item.body,
      icon: status.icon,
      accentColor: status.foregroundColor,
    );
  }
}
