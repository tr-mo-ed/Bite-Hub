import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:bitehub_app/app/core/localization/app_strings.dart';
import 'package:bitehub_app/app/data/providers/auth_provider.dart';
import 'package:bitehub_app/app/data/providers/navigation_provider.dart';
import 'package:bitehub_app/app/presentation_v2/controllers/shell_v2_controller.dart';
import 'package:bitehub_app/app/presentation_v2/screens/cart/cart_screen_v2.dart';
import 'package:bitehub_app/app/presentation_v2/screens/home/home_screen_v2.dart';
import 'package:bitehub_app/app/presentation_v2/screens/orders/orders_screen_v2.dart';
import 'package:bitehub_app/app/presentation_v2/screens/profile/profile_screen_v2.dart';
import 'package:bitehub_app/app/presentation_v2/screens/wallet/wallet_screen_v2.dart';
import 'package:bitehub_app/app/presentation_v2/widgets/base_screen.dart';
import 'package:bitehub_app/app/presentation_v2/widgets/shell_drawer_v2.dart';

class MainShellV2 extends StatefulWidget {
  const MainShellV2({super.key});

  @override
  State<MainShellV2> createState() => _MainShellV2State();
}

class _MainShellV2State extends State<MainShellV2> {
  late final ShellV2Controller _controller;

  @override
  void initState() {
    super.initState();
    _controller = ShellV2Controller(
      authProvider: context.read<AuthProvider>(),
    );
    _controller.initialize();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _openCafeDashboard() {
    Navigator.of(context).pushNamed('/cafe-dashboard');
  }

  List<BaseScreenTab> _buildTabs() {
    final strings = AppStrings.of(context);
    return [
      BaseScreenTab(
        title: strings.home,
        icon: Icons.home_outlined,
        activeIcon: Icons.home_outlined,
        screen: const HomeScreenV2(),
      ),
      BaseScreenTab(
        title: strings.orders,
        icon: Icons.receipt_long_outlined,
        activeIcon: Icons.receipt_long_outlined,
        screen: const OrdersScreenV2(),
      ),
      BaseScreenTab(
        title: strings.cart,
        icon: Icons.shopping_cart_outlined,
        activeIcon: Icons.shopping_cart_outlined,
        screen: const CartScreenV2(),
      ),
      BaseScreenTab(
        title: strings.wallet,
        icon: Icons.account_balance_wallet_outlined,
        activeIcon: Icons.account_balance_wallet_outlined,
        screen: const WalletScreenV2(),
      ),
      BaseScreenTab(
        title: strings.profile,
        icon: Icons.person_outline,
        activeIcon: Icons.person_outline,
        screen: const ProfileScreenV2(),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Consumer<NavigationProvider>(
          builder: (context, navigation, __) {
            return BaseScreen(
              tabs: _buildTabs(),
              currentIndex: navigation.currentIndex,
              onTabChanged: navigation.setIndex,
              drawer: ShellDrawerV2(
                controller: _controller,
                onSelectIndex: navigation.setIndex,
                onOpenCafeDashboard: _openCafeDashboard,
              ),
            );
          },
        );
      },
    );
  }
}
