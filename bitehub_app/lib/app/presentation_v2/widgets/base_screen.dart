import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:persistent_bottom_nav_bar_v2/persistent_bottom_nav_bar_v2.dart';
import 'package:provider/provider.dart';

import 'package:bitehub_app/app/core/theme/app_colors.dart';
import 'package:bitehub_app/app/data/providers/notification_provider.dart';
import 'package:bitehub_app/app/core/widgets/bh_back_button.dart';
import 'package:bitehub_app/app/presentation_v2/widgets/magic_bottom_nav.dart';
import 'package:bitehub_app/app/presentation_v2/widgets/notification_center_sheet.dart';

class BaseScreenTab {
  const BaseScreenTab({
    required this.title,
    required this.screen,
    required this.icon,
    required this.activeIcon,
  });

  final String title;
  final Widget screen;
  final IconData icon;
  final IconData activeIcon;
}

class BaseScreen extends StatefulWidget {
  const BaseScreen({
    super.key,
    required this.tabs,
    required this.currentIndex,
    required this.onTabChanged,
    this.drawer,
    this.actions = const [],
  });

  final List<BaseScreenTab> tabs;
  final int currentIndex;
  final ValueChanged<int> onTabChanged;
  final Widget? drawer;
  final List<Widget> actions;

  @override
  State<BaseScreen> createState() => _BaseScreenState();
}

class _BaseScreenState extends State<BaseScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late final PersistentTabController _tabController;
  late final List<GlobalKey<NavigatorState>> _navigatorKeys;
  late final List<bool> _canPopPerTab;

  @override
  void initState() {
    super.initState();
    _tabController = PersistentTabController(initialIndex: widget.currentIndex);
    _navigatorKeys = List.generate(
      widget.tabs.length,
      (_) => GlobalKey<NavigatorState>(),
    );
    _canPopPerTab = List<bool>.filled(widget.tabs.length, false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshCurrentCanPop();
      context.read<NotificationProvider>().startAutoRefresh();
    });
  }

  @override
  void didUpdateWidget(covariant BaseScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_tabController.index != widget.currentIndex) {
      _tabController.jumpToTab(widget.currentIndex);
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _refreshCurrentCanPop());
    }
  }

  Future<void> _handleBack() async {
    final navigator = _navigatorKeys[widget.currentIndex].currentState;
    if (navigator == null || !navigator.canPop()) {
      return;
    }
    await navigator.maybePop();
    _refreshCanPop(widget.currentIndex);
  }

  void _handleTabChanged(int index) {
    widget.onTabChanged(index);
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshCanPop(index));
  }

  Future<void> _openNotificationCenter() async {
    await context.read<NotificationProvider>().refreshFromServer();
    if (!mounted) {
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => NotificationCenterSheet(
        hostContext: context,
      ),
    );
  }

  void _refreshCurrentCanPop() {
    _refreshCanPop(widget.currentIndex);
  }

  void _refreshCanPop(int index) {
    if (!mounted || index < 0 || index >= _navigatorKeys.length) {
      return;
    }
    final navigator = _navigatorKeys[index].currentState;
    final nextValue = navigator?.canPop() ?? false;
    if (_canPopPerTab[index] == nextValue) {
      return;
    }
    setState(() {
      _canPopPerTab[index] = nextValue;
    });
  }

  List<PersistentTabConfig> _buildTabs() {
    return List.generate(widget.tabs.length, (index) {
      final tab = widget.tabs[index];
      return PersistentTabConfig(
        screen: tab.screen,
        item: ItemConfig(
          icon: Icon(tab.activeIcon),
          inactiveIcon: Icon(tab.icon),
          title: tab.title,
          activeForegroundColor: const Color(0xFF3559C7),
          inactiveForegroundColor: AppColors.textSecondary,
          activeColorSecondary: const Color(0xFFEFF6FF),
          textStyle: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
        navigatorConfig: NavigatorConfig(
          navigatorKey: _navigatorKeys[index],
          navigatorObservers: [
            _BaseScreenNavigatorObserver(
                onChanged: () => _refreshCanPop(index)),
          ],
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentTab = widget.tabs[widget.currentIndex];
    final canPop = _canPopPerTab[widget.currentIndex];

    return Scaffold(
      key: _scaffoldKey,
      extendBody: true,
      drawer: widget.drawer,
      appBar: AppBar(
        backgroundColor: Colors.white.withValues(alpha: .78),
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: AppColors.border.withValues(alpha: .7),
                  ),
                ),
              ),
            ),
          ),
        ),
        automaticallyImplyLeading: false,
        leading: canPop
            ? BhBackButton(
                onPressed: _handleBack,
                tooltip: 'رجوع',
              )
            : widget.drawer != null
                ? IconButton(
                    onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                    icon: const Icon(Icons.menu_rounded),
                    tooltip: 'القائمة',
                  )
                : null,
        title: Text(
          currentTab.title,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          ...widget.actions,
          Selector<NotificationProvider, int>(
            selector: (_, provider) => provider.unreadCount,
            builder: (context, unreadCount, _) {
              return _NotificationBellButton(
                unreadCount: unreadCount,
                onPressed: _openNotificationCenter,
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: PersistentTabView(
        controller: _tabController,
        tabs: _buildTabs(),
        onTabChanged: _handleTabChanged,
        screenTransitionAnimation: const ScreenTransitionAnimation(
          duration: Duration(milliseconds: 360),
          curve: Curves.easeOutCubic,
        ),
        navBarBuilder: (navBarConfig) => SafeArea(
          minimum: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          child: MagicBottomNav(
            navBarConfig: navBarConfig,
          ),
        ),
      ),
    );
  }
}

class _NotificationBellButton extends StatelessWidget {
  const _NotificationBellButton({
    required this.unreadCount,
    required this.onPressed,
  });

  final int unreadCount;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 4),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onPressed,
              borderRadius: BorderRadius.circular(14),
              child: Ink(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: unreadCount > 0
                      ? const Color(0xFFEFF6FF)
                      : AppColors.neutral50,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: unreadCount > 0
                        ? const Color(0xFFBFDBFE)
                        : AppColors.border,
                  ),
                ),
                child: Icon(
                  unreadCount > 0
                      ? Icons.notifications_active_outlined
                      : Icons.notifications_none_rounded,
                  size: 20,
                  color: unreadCount > 0
                      ? AppColors.brandBlue
                      : AppColors.textSecondary,
                ),
              ),
            ),
          ),
          if (unreadCount > 0)
            PositionedDirectional(
              top: -4,
              end: -4,
              child: Container(
                constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.danger,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: Text(
                  unreadCount > 9 ? '9+' : '$unreadCount',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _BaseScreenNavigatorObserver extends NavigatorObserver {
  _BaseScreenNavigatorObserver({required this.onChanged});

  final VoidCallback onChanged;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    onChanged();
    super.didPush(route, previousRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    onChanged();
    super.didPop(route, previousRoute);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    onChanged();
    super.didRemove(route, previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    onChanged();
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
  }
}
