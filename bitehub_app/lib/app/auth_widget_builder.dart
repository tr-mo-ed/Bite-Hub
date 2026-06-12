import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:bitehub_app/app/data/providers/auth_provider.dart';
import 'package:bitehub_app/app/presentation/screens/auth/login_screen.dart';
import 'package:bitehub_app/app/presentation_v2/screens/main_shell_v2.dart';

class AuthWidgetBuilder extends StatelessWidget {
  const AuthWidgetBuilder({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        if (authProvider.status == AuthStatus.uninitialized) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (authProvider.isLoggedIn) {
          return const MainShellV2();
        }

        return const LoginScreen();
      },
    );
  }
}
