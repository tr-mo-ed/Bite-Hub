import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:bitehub_app/app/core/localization/app_strings.dart';
import 'package:bitehub_app/app/data/models/college_model.dart';
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
  final GlobalKey<HomeScreenV2State> _homeKey = GlobalKey<HomeScreenV2State>();

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

  Future<void> _handleCafeSelection(CollegeModel cafe) async {
    context.read<NavigationProvider>().setIndex(0);
    await _homeKey.currentState?.selectCafeById(cafe.id);
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
        activeIcon: Icons.home_rounded,
        screen: HomeScreenV2(key: _homeKey),
      ),
      BaseScreenTab(
        title: strings.orders,
        icon: Icons.receipt_long_outlined,
        activeIcon: Icons.receipt_long_rounded,
        screen: const OrdersScreenV2(),
      ),
      BaseScreenTab(
        title: strings.cart,
        icon: Icons.shopping_cart_outlined,
        activeIcon: Icons.shopping_cart_rounded,
        screen: const CartScreenV2(),
      ),
      BaseScreenTab(
        title: strings.wallet,
        icon: Icons.account_balance_wallet_outlined,
        activeIcon: Icons.account_balance_wallet_rounded,
        screen: const WalletScreenV2(),
      ),
      BaseScreenTab(
        title: strings.profile,
        icon: Icons.person_outline,
        activeIcon: Icons.person_rounded,
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
            final currentIndex = navigation.currentIndex;
            return BaseScreen(
              tabs: _buildTabs(),
              currentIndex: currentIndex,
              onTabChanged: navigation.setIndex,
              drawer: ShellDrawerV2(
                controller: _controller,
                onSelectIndex: navigation.setIndex,
                onSelectCafe: _handleCafeSelection,
                onOpenCafeDashboard: _openCafeDashboard,
              ),
              actions: [
                if (currentIndex == 0)
                  IconButton(
                    onPressed: () => _homeKey.currentState?.refresh(),
                    icon: const Icon(
                      Icons.refresh_rounded,
                      color: Color(0xFFE0B42C),
                    ),
                    tooltip: 'تحديث المقاهي',
                  ),
              ],
            );
          },
        );
      },
    );
  }
}
