import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:bitehub_app/app/core/theme/app_colors.dart';
import 'package:bitehub_app/app/core/widgets/bh_back_button.dart';
import 'package:bitehub_app/app/data/providers/auth_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isPasswordVisible = false;

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _onLoginPressed() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    FocusScope.of(context).unfocus();
    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.login(
      _identifierController.text.trim(),
      _passwordController.text.trim(),
    );

    if (!mounted) {
      return;
    }

    if (success) {
      Navigator.of(context).pushNamedAndRemoveUntil('/main', (route) => false);
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(authProvider.errorMessage ?? 'فشل تسجيل الدخول'),
        backgroundColor: AppColors.danger,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = context.select<AuthProvider, bool>(
      (provider) => provider.status == AuthStatus.authenticating,
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
            children: [
              const Align(
                alignment: Alignment.centerLeft,
                child: BhBackButton(),
              ),
              const SizedBox(height: 28),
              const _AuthHeader(
                title: 'تسجيل الدخول',
                subtitle: 'استخدم البريد الإلكتروني أو رقم الهاتف.',
              ),
              const SizedBox(height: 28),
              const _FieldLabel('البريد الإلكتروني أو رقم الهاتف'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _identifierController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                textDirection: TextDirection.ltr,
                textAlign: TextAlign.right,
                autofillHints: const [
                  AutofillHints.email,
                  AutofillHints.telephoneNumber,
                ],
                decoration: _inputDecoration(
                  hintText: 'example@gmail.com أو 0912345678',
                  icon: Icons.alternate_email_rounded,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'الرجاء إدخال البريد الإلكتروني أو رقم الهاتف';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 18),
              const _FieldLabel('كلمة السر'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _passwordController,
                obscureText: !_isPasswordVisible,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.password],
                decoration: _inputDecoration(
                  hintText: 'أدخل كلمة السر',
                  icon: Icons.lock_outline_rounded,
                  trailing: IconButton(
                    onPressed: () {
                      setState(() {
                        _isPasswordVisible = !_isPasswordVisible;
                      });
                    },
                    icon: Icon(
                      _isPasswordVisible
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'الرجاء إدخال كلمة السر';
                  }
                  return null;
                },
                onFieldSubmitted: (_) {
                  if (!isLoading) {
                    _onLoginPressed();
                  }
                },
              ),
              const SizedBox(height: 28),
              SizedBox(
                height: 52,
                child: FilledButton(
                  onPressed: isLoading ? null : _onLoginPressed,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.brandBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: isLoading
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'دخول',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pushNamed(context, '/signup'),
                    child: const Text('إنشاء حساب جديد'),
                  ),
                  const Text(
                    'ليس لديك حساب؟',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AuthHeader extends StatelessWidget {
  const _AuthHeader({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 74,
          height: 74,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Image.asset('assets/images/bitehub_app_icon.png'),
        ),
        const SizedBox(height: 18),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 28,
            fontWeight: FontWeight.w900,
            height: 1,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 15,
            fontWeight: FontWeight.w700,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w900,
        fontSize: 14,
      ),
    );
  }
}

InputDecoration _inputDecoration({
  required String hintText,
  required IconData icon,
  Widget? trailing,
}) {
  return InputDecoration(
    hintText: hintText,
    hintTextDirection: TextDirection.rtl,
    filled: true,
    fillColor: AppColors.surface,
    prefixIcon: Icon(icon, color: AppColors.brandBlue),
    suffixIcon: trailing,
    contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.brandBlue, width: 1.4),
    ),
  );
}
