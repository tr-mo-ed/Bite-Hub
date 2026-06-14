import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'package:bitehub_app/app/auth_widget_builder.dart';
import 'package:bitehub_app/app/data/providers/auth_provider.dart';
import 'package:bitehub_app/app/data/providers/cart_provider.dart';
import 'package:bitehub_app/app/data/providers/navigation_provider.dart';
import 'package:bitehub_app/app/data/providers/locale_provider.dart';
import 'package:bitehub_app/app/data/providers/notification_provider.dart';
import 'package:bitehub_app/app/data/providers/theme_provider.dart';
import 'package:bitehub_app/app/data/providers/wallet_provider.dart';
import 'package:bitehub_app/app/data/services/notification_service.dart';
import 'package:bitehub_app/app/core/theme/app_colors.dart';
import 'package:bitehub_app/app/core/theme/app_theme.dart';
import 'package:bitehub_app/app/presentation/screens/auth/login_screen.dart';
import 'package:bitehub_app/app/presentation/screens/auth/signup_screen.dart';
import 'package:bitehub_app/app/presentation_v2/screens/cafe/cafe_dashboard_screen_v2.dart';
import 'package:bitehub_app/app/presentation_v2/screens/legal/usage_policy_screen.dart';
import 'package:bitehub_app/app/presentation_v2/screens/main_shell_v2.dart';
import 'package:bitehub_app/app/presentation_v2/widgets/notification_banner_host.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.instance.initialize();
  await NotificationService.instance.requestPermissionIfNeeded();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => WalletProvider()),
        ChangeNotifierProvider(create: (_) => CartProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()..load()),
        ChangeNotifierProvider(create: (_) => NavigationProvider()),
        ChangeNotifierProvider(create: (_) => LocaleProvider()..load()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()..loadTheme()),
      ],
      child: Consumer2<ThemeProvider, LocaleProvider>(
        builder: (context, themeProvider, localeProvider, _) {
          return MaterialApp(
            title: 'Bite Hub',
            debugShowCheckedModeBanner: false,
            locale: localeProvider.locale,
            supportedLocales: const [Locale('ar'), Locale('en')],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            builder: (context, child) {
              return NotificationBannerHost(child: child!);
            },
            theme: AppTheme.light(context),
            darkTheme: ThemeData(
              brightness: Brightness.dark,
              colorScheme: const ColorScheme.dark(
                primary: AppColors.brandBlue,
                secondary: AppColors.brandSky,
                surface: Color(0xFF1B2128),
              ),
              scaffoldBackgroundColor: const Color(0xFF0F1116),
              cardColor: const Color(0xFF1B2128),
              fontFamily: 'Tajawal',
              appBarTheme: const AppBarTheme(
                backgroundColor: Color(0xFF12161C),
                elevation: 0,
                centerTitle: true,
                iconTheme: IconThemeData(color: Colors.white),
                titleTextStyle: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Tajawal',
                ),
              ),
              bottomNavigationBarTheme: const BottomNavigationBarThemeData(
                backgroundColor: Color(0xFF12161C),
                selectedItemColor: Color(0xFFF4A259),
                unselectedItemColor: Colors.white70,
                showUnselectedLabels: true,
              ),
              elevatedButtonTheme: ElevatedButtonThemeData(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brandBlue,
                  foregroundColor: Colors.white,
                ),
              ),
              textTheme: ThemeData.dark().textTheme.apply(
                    fontFamily: 'Tajawal',
                    bodyColor: Colors.white,
                    displayColor: Colors.white,
                  ),
            ),
            themeMode: themeProvider.themeMode,
            home: const AuthWidgetBuilder(),
            routes: {
              '/main': (context) => const MainShellV2(),
              '/cafe-dashboard': (context) => const CafeDashboardScreenV2(),
              '/usage-policy': (context) => const UsagePolicyScreen(),
              '/login': (context) => const LoginScreen(),
              '/signup': (context) => const SignupScreen(),
            },
          );
        },
      ),
    );
  }
}
