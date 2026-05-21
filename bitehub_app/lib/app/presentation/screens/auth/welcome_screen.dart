import 'package:flutter/material.dart';

// ???? ???? WelcomeScreen ???? ???? ????? ???? ?? ???? ????.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  // ???? ???? createState ???? ??????? ?? ????? ???? ?????? ?????.
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

// ???? ???? _WelcomeScreenState ???? ???? ????? ???? ?? ???? ????.
class _WelcomeScreenState extends State<WelcomeScreen> {
  bool isDarkMode = false;

  @override
  // ???? ???? build ???? ??????? ?? ????? ???? ?????? ?????.
  Widget build(BuildContext context) {
    // ??? ??????? _lightColors ??? ?????? ???? ????? ????.
    final colors = isDarkMode ? _darkColors : _lightColors;

    return Scaffold(
      backgroundColor: colors['background'],
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: _buildContent(context, colors),
        ),
      ),
    );
  }

  // ???? ???? _buildContent ???? ??????? ?? ????? ???? ?????? ?????.
  Widget _buildContent(BuildContext context, Map<String, Color> colors) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Spacer(flex: 2),
        _buildLogo(colors),
        const SizedBox(height: 32),
        _buildWelcomeText(colors),
        const SizedBox(height: 48),
        _buildAuthButtons(context, colors),
        const Spacer(flex: 3),
        _buildSettingsButtons(colors),
        const SizedBox(height: 24),
      ],
    );
  }

  // ???? ???? _buildLogo ???? ??????? ?? ????? ???? ?????? ?????.
  Widget _buildLogo(Map<String, Color> colors) {
    return Image.asset(
      'assets/images/logo.png',
      height: 180,
      errorBuilder: (context, error, stackTrace) {
        return Icon(Icons.fastfood, size: 100, color: colors['icon']);
      },
    );
  }

  // ???? ???? _buildWelcomeText ???? ??????? ?? ????? ???? ?????? ?????.
  Widget _buildWelcomeText(Map<String, Color> colors) {
    return Column(
      children: [
        Text(
          'مرحباً بك في بايت هوب',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: colors['primaryText'],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'اطلب وجبتك أو مشروبك بسرعة، وتابع حالة طلبك مباشرة من التطبيق.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            color: colors['secondaryText'],
          ),
        ),
      ],
    );
  }

  // ???? ???? _buildAuthButtons ???? ??????? ?? ????? ???? ?????? ?????.
  Widget _buildAuthButtons(BuildContext context, Map<String, Color> colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton(
          onPressed: () => Navigator.pushNamed(context, '/login'),
          style: ElevatedButton.styleFrom(
            backgroundColor: colors['loginButton'],
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          ),
          child: const Text(
            'تسجيل الدخول',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: () => Navigator.pushNamed(context, '/signup'),
          style: ElevatedButton.styleFrom(
            backgroundColor: colors['signupButton'],
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          ),
          child: const Text(
            'إنشاء حساب جديد',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ),
      ],
    );
  }

  // ???? ???? _buildSettingsButtons ???? ??????? ?? ????? ???? ?????? ?????.
  Widget _buildSettingsButtons(Map<String, Color> colors) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        TextButton.icon(
          onPressed: () => setState(() => isDarkMode = !isDarkMode),
          icon: Icon(
            isDarkMode ? Icons.wb_sunny_outlined : Icons.nightlight_round,
            color: colors['icon'],
            size: 20,
          ),
          label: Text(
            isDarkMode ? 'الوضع: ليلي' : 'الوضع: نهاري',
            style: TextStyle(color: colors['secondaryText']),
          ),
          style: TextButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: colors['border'] ?? Colors.grey),
            ),
          ),
        ),
        const SizedBox(width: 16),
        TextButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.language, size: 20, color: Color(0xFF24A8E0)),
          label: Text(
            'اللغة: العربية',
            style: TextStyle(color: colors['secondaryText']),
          ),
          style: TextButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: colors['border'] ?? Colors.grey),
            ),
          ),
        ),
      ],
    );
  }

  // ??? ??????? _lightColors ??? ?????? ???? ????? ????.
  static const Map<String, Color> _lightColors = {
    'background': Colors.white,
    'primaryText': Color(0xFF333333),
    'secondaryText': Color(0xFF666666),
    'icon': Color(0xFFFF8A00),
    'border': Color(0xFFDDDDDD),
    'loginButton': Color(0xFF24A8E0),
    'signupButton': Color(0xFFFF8A00),
  };

  // ??? ??????? _darkColors ??? ?????? ???? ????? ????.
  static const Map<String, Color> _darkColors = {
    'background': Color(0xFF121212),
    'primaryText': Colors.white,
    'secondaryText': Color(0xFFBBBBBB),
    'icon': Color(0xFFFF8A00),
    'border': Color(0xFF444444),
    'loginButton': Color(0xFF24A8E0),
    'signupButton': Color(0xFFFF8A00),
  };
}
