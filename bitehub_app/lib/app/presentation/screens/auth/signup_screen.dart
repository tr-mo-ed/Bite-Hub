import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pinput/pinput.dart';
import 'package:provider/provider.dart';

import 'package:bitehub_app/app/core/theme/app_colors.dart';
import 'package:bitehub_app/app/core/widgets/bh_back_button.dart';
import 'package:bitehub_app/app/data/providers/auth_provider.dart';
import 'package:bitehub_app/app/data/providers/wallet_provider.dart';
import 'package:bitehub_app/app/data/services/api_service.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _codeController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  EmailLoginChallenge? _challenge;
  Timer? _resendTimer;
  int _resendSeconds = 0;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _resendTimer?.cancel();
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _handleSignup() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    FocusScope.of(context).unfocus();
    final authProvider = context.read<AuthProvider>();

    final challenge = await authProvider.signup(
      _nameController.text.trim(),
      _emailController.text.trim(),
      _phoneController.text.trim(),
      _passwordController.text,
    );

    if (!mounted) {
      return;
    }

    if (challenge == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            authProvider.errorMessage ?? 'فشل إنشاء الحساب. حاول مرة أخرى.',
          ),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _challenge = challenge;
      _codeController.clear();
    });
    _startResendTimer(challenge.resendAfter);
  }

  Future<void> _verifySignupCode() async {
    final challenge = _challenge;
    if (challenge == null) {
      return;
    }
    if (_codeController.text.trim().length != 6) {
      _showMessage('أدخل رمز التحقق المكوّن من 6 أرقام.');
      return;
    }

    FocusScope.of(context).unfocus();
    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.verifySignupCode(
      email: _emailController.text.trim(),
      requestId: challenge.requestId,
      code: _codeController.text.trim(),
    );
    if (!mounted) {
      return;
    }
    if (!success) {
      _showMessage(
        authProvider.errorMessage ?? 'تعذر تأكيد الرمز. حاول مرة أخرى.',
      );
      return;
    }

    final walletProvider = context.read<WalletProvider>();
    await walletProvider.fetchWalletData();
    if (!mounted) {
      return;
    }

    Navigator.of(context).pushNamedAndRemoveUntil('/main', (route) => false);
  }

  void _startResendTimer(int seconds) {
    _resendTimer?.cancel();
    setState(() => _resendSeconds = seconds);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _resendSeconds <= 1) {
        timer.cancel();
        if (mounted) {
          setState(() => _resendSeconds = 0);
        }
        return;
      }
      setState(() => _resendSeconds -= 1);
    });
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.danger,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLoading =
        context.watch<AuthProvider>().status == AuthStatus.authenticating;
    if (_challenge != null) {
      return _buildVerificationScreen(isLoading);
    }

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
              const SizedBox(height: 24),
              const _AuthHeader(
                title: 'إنشاء حساب',
                subtitle: 'أدخل بيانات الطالب الأساسية.',
              ),
              const SizedBox(height: 26),
              const _FieldLabel('اسم الطالب'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameController,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.name],
                decoration: _inputDecoration(
                  hintText: 'الاسم الكامل',
                  icon: Icons.person_outline_rounded,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'الرجاء إدخال اسم الطالب';
                  }
                  if (value.trim().length < 2) {
                    return 'اسم الطالب قصير جداً';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              const _FieldLabel('البريد الإلكتروني'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                textDirection: TextDirection.ltr,
                textAlign: TextAlign.right,
                autofillHints: const [AutofillHints.email],
                decoration: _inputDecoration(
                  hintText: 'example@gmail.com',
                  icon: Icons.alternate_email_rounded,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'الرجاء إدخال البريد الإلكتروني';
                  }
                  final email = value.trim();
                  final isValidEmail = RegExp(
                    r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                  ).hasMatch(email);
                  if (!isValidEmail) {
                    return 'الرجاء إدخال بريد إلكتروني صحيح';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              const _FieldLabel('رقم الهاتف'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                textDirection: TextDirection.ltr,
                textAlign: TextAlign.right,
                autofillHints: const [AutofillHints.telephoneNumber],
                decoration: _inputDecoration(
                  hintText: '0912345678',
                  icon: Icons.call_outlined,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'الرجاء إدخال رقم الهاتف';
                  }
                  final digits = value.replaceAll(RegExp(r'\D'), '');
                  final isValidPhone = RegExp(
                    r'^(?:218)?9\d{8}$|^09\d{8}$',
                  ).hasMatch(digits);
                  if (!isValidPhone) {
                    return 'استخدم رقم ليبي مثل 0912345678';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              const _FieldLabel('كلمة السر'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.newPassword],
                decoration: _inputDecoration(
                  hintText: '6 أحرف على الأقل',
                  icon: Icons.lock_outline_rounded,
                  trailing: IconButton(
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'الرجاء إدخال كلمة السر';
                  }
                  if (value.length < 6) {
                    return 'يجب أن تكون كلمة السر 6 أحرف على الأقل';
                  }
                  return null;
                },
                onFieldSubmitted: (_) {
                  if (!isLoading) {
                    _handleSignup();
                  }
                },
              ),
              const SizedBox(height: 26),
              SizedBox(
                height: 52,
                child: FilledButton(
                  onPressed: isLoading ? null : _handleSignup,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.brandBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'إنشاء الحساب',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 22),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.pushNamed(context, '/login'),
                  child: const Text('لديك حساب؟ تسجيل الدخول'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVerificationScreen(bool isLoading) {
    final challenge = _challenge!;
    final pinTheme = PinTheme(
      width: 48,
      height: 54,
      textStyle: const TextStyle(
        color: AppColors.textPrimary,
        fontSize: 20,
        fontWeight: FontWeight.w900,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: BhBackButton(
                onPressed: () {
                  if (isLoading) {
                    return;
                  }
                  _resendTimer?.cancel();
                  setState(() {
                    _challenge = null;
                    _resendSeconds = 0;
                    _codeController.clear();
                  });
                },
              ),
            ),
            const SizedBox(height: 24),
            const _AuthHeader(
              title: 'تأكيد البريد',
              subtitle: 'أدخل الرمز الذي أرسلناه لإكمال إنشاء الحساب.',
            ),
            const SizedBox(height: 24),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFEAF6F2), Color(0xFFFFFFFF)],
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                ),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0xFFB9DDD2)),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.brandBlue.withValues(alpha: .08),
                    blurRadius: 22,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: AppColors.brandBlue.withValues(alpha: .10),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(
                      Icons.mark_email_read_outlined,
                      color: AppColors.brandBlue,
                      size: 30,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'أدخل رمز التأكيد المرسل إلى بريدك',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    challenge.maskedEmail,
                    textDirection: TextDirection.ltr,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'إن لم يظهر الرمز، راجع الرسائل غير المرغوب فيها ثم أعد الإرسال.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      height: 1.45,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            Directionality(
              textDirection: TextDirection.ltr,
              child: Pinput(
                length: 6,
                controller: _codeController,
                autofocus: true,
                keyboardType: TextInputType.number,
                defaultPinTheme: pinTheme,
                focusedPinTheme: pinTheme.copyWith(
                  decoration: pinTheme.decoration!.copyWith(
                    border: Border.all(
                      color: AppColors.brandBlue,
                      width: 1.5,
                    ),
                  ),
                ),
                submittedPinTheme: pinTheme.copyWith(
                  decoration: pinTheme.decoration!.copyWith(
                    color: const Color(0xFFEAF6F2),
                    border: Border.all(color: AppColors.brandBlue),
                  ),
                ),
                onCompleted: (_) {
                  if (!isLoading) {
                    _verifySignupCode();
                  }
                },
              ),
            ),
            if (challenge.debugCode != null) ...[
              const SizedBox(height: 10),
              Text(
                'رمز التطوير: ${challenge.debugCode}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.warning,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              height: 52,
              child: FilledButton.icon(
                onPressed: isLoading ? null : _verifySignupCode,
                icon: isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.verified_user_outlined),
                label: const Text(
                  'تأكيد وإنشاء الحساب',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.brandBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(
                  onPressed: isLoading
                      ? null
                      : () {
                          _resendTimer?.cancel();
                          setState(() {
                            _challenge = null;
                            _resendSeconds = 0;
                            _codeController.clear();
                          });
                        },
                  child: const Text('تعديل البيانات'),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed:
                      isLoading || _resendSeconds > 0 ? null : _handleSignup,
                  child: Text(
                    _resendSeconds > 0
                        ? 'إعادة الإرسال بعد $_resendSeconds ث'
                        : 'إعادة إرسال الرمز',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'الرمز صالح لمدة 10 دقائق ويُستخدم مرة واحدة فقط.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
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
