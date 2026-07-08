import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pinput/pinput.dart';
import 'package:provider/provider.dart';

import 'package:bitehub_app/app/core/theme/app_colors.dart';
import 'package:bitehub_app/app/core/widgets/bh_back_button.dart';
import 'package:bitehub_app/app/data/providers/auth_provider.dart';
import 'package:bitehub_app/app/data/services/api_service.dart';

enum _LoginMethod { emailCode, password }

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  final _codeController = TextEditingController();

  _LoginMethod _method = _LoginMethod.emailCode;
  EmailLoginChallenge? _challenge;
  Timer? _resendTimer;
  int _resendSeconds = 0;
  bool _isPasswordVisible = false;

  @override
  void dispose() {
    _resendTimer?.cancel();
    _identifierController.dispose();
    _passwordController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  bool get _isValidEmail {
    final email = _identifierController.text.trim();
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
  }

  Future<void> _requestCode() async {
    if (!_isValidEmail) {
      _showMessage('أدخل بريداً إلكترونياً صحيحاً.');
      return;
    }

    FocusScope.of(context).unfocus();
    final challenge = await context
        .read<AuthProvider>()
        .requestEmailLoginCode(_identifierController.text.trim());
    if (!mounted) return;
    if (challenge == null) {
      _showProviderError();
      return;
    }

    setState(() {
      _challenge = challenge;
      _codeController.clear();
    });
    _startResendTimer(challenge.resendAfter);
  }

  Future<void> _verifyCode() async {
    final challenge = _challenge;
    if (challenge == null) return;
    if (_codeController.text.trim().length != 6) {
      _showMessage('أدخل رمز التحقق المكوّن من 6 أرقام.');
      return;
    }

    FocusScope.of(context).unfocus();
    final success = await context.read<AuthProvider>().verifyEmailLoginCode(
          email: _identifierController.text.trim(),
          requestId: challenge.requestId,
          code: _codeController.text,
        );
    if (!mounted) return;
    if (success) {
      Navigator.of(context).pushNamedAndRemoveUntil('/main', (route) => false);
    } else {
      _showProviderError();
    }
  }

  Future<void> _passwordLogin() async {
    if (_identifierController.text.trim().isEmpty ||
        _passwordController.text.isEmpty) {
      _showMessage('أدخل البريد أو الهاتف وكلمة السر.');
      return;
    }

    FocusScope.of(context).unfocus();
    final success = await context.read<AuthProvider>().login(
          _identifierController.text.trim(),
          _passwordController.text,
        );
    if (!mounted) return;
    if (success) {
      Navigator.of(context).pushNamedAndRemoveUntil('/main', (route) => false);
    } else {
      _showProviderError();
    }
  }

  void _startResendTimer(int seconds) {
    _resendTimer?.cancel();
    setState(() => _resendSeconds = seconds);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _resendSeconds <= 1) {
        timer.cancel();
        if (mounted) setState(() => _resendSeconds = 0);
        return;
      }
      setState(() => _resendSeconds -= 1);
    });
  }

  void _showProviderError() {
    _showMessage(
      context.read<AuthProvider>().errorMessage ?? 'تعذر تسجيل الدخول.',
    );
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

  void _changeMethod(_LoginMethod method) {
    _resendTimer?.cancel();
    setState(() {
      _method = method;
      _challenge = null;
      _resendSeconds = 0;
      _codeController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = context.select<AuthProvider, bool>(
      (provider) => provider.status == AuthStatus.authenticating,
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
          children: [
            const Align(
              alignment: Alignment.centerLeft,
              child: BhBackButton(),
            ),
            const SizedBox(height: 12),
            _AuthHeader(
              subtitle: _method == _LoginMethod.emailCode
                  ? 'سنرسل رمزاً من 6 أرقام إلى بريدك.'
                  : 'استخدم البريد أو الهاتف وكلمة السر.',
            ),
            const SizedBox(height: 22),
            _LoginMethodSwitch(
              value: _method,
              onChanged: isLoading ? null : _changeMethod,
            ),
            const SizedBox(height: 22),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: _method == _LoginMethod.emailCode
                  ? _buildEmailCodeLogin(isLoading)
                  : _buildPasswordLogin(isLoading),
            ),
            const SizedBox(height: 20),
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                TextButton(
                  onPressed: () => Navigator.pushNamed(context, '/signup'),
                  child: const Text('إنشاء حساب'),
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
    );
  }

  Widget _buildEmailCodeLogin(bool isLoading) {
    final challenge = _challenge;
    if (challenge == null) {
      return Column(
        key: const ValueKey('email-request'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _FieldLabel('البريد الإلكتروني'),
          const SizedBox(height: 8),
          TextField(
            controller: _identifierController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            textDirection: TextDirection.ltr,
            textAlign: TextAlign.right,
            autofillHints: const [AutofillHints.email],
            decoration: _inputDecoration(
              hintText: 'example@gmail.com',
              icon: Icons.alternate_email_rounded,
            ),
            onSubmitted: (_) {
              if (!isLoading) _requestCode();
            },
          ),
          const SizedBox(height: 18),
          _PrimaryButton(
            label: 'إرسال رمز التحقق',
            icon: Icons.mark_email_read_outlined,
            isLoading: isLoading,
            onPressed: _requestCode,
          ),
          const SizedBox(height: 12),
          const _SecurityNote(
            text: 'الرمز صالح لمدة 10 دقائق ويُستخدم مرة واحدة فقط.',
          ),
        ],
      );
    }

    final pinTheme = PinTheme(
      width: 50,
      height: 58,
      textStyle: const TextStyle(
        color: AppColors.textPrimary,
        fontSize: 22,
        fontWeight: FontWeight.w900,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.brandBlue.withValues(alpha: .06),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
    );

    return Column(
      key: const ValueKey('email-verify'),
      children: [
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
                  size: 28,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'أدخل رمز التحقق المرسل إلى بريدك',
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
                'إن لم يظهر في البريد الوارد، راجع الرسائل غير المرغوب فيها.',
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
        const SizedBox(height: 20),
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
                border: Border.all(color: AppColors.brandBlue, width: 1.5),
              ),
            ),
            submittedPinTheme: pinTheme.copyWith(
              decoration: pinTheme.decoration!.copyWith(
                color: const Color(0xFFEAF6F2),
                border: Border.all(color: AppColors.brandBlue),
              ),
            ),
            onCompleted: (_) {
              if (!isLoading) _verifyCode();
            },
          ),
        ),
        if (challenge.debugCode != null) ...[
          const SizedBox(height: 10),
          Text(
            'رمز التطوير: ${challenge.debugCode}',
            style: const TextStyle(
              color: AppColors.warning,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
        const SizedBox(height: 20),
        _PrimaryButton(
          label: 'تأكيد والدخول',
          icon: Icons.login_rounded,
          isLoading: isLoading,
          onPressed: _verifyCode,
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton(
              onPressed: isLoading
                  ? null
                  : () {
                      setState(() {
                        _challenge = null;
                        _codeController.clear();
                      });
                    },
              child: const Text('تغيير البريد'),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: isLoading || _resendSeconds > 0 ? null : _requestCode,
              child: Text(
                _resendSeconds > 0
                    ? 'إعادة الإرسال بعد $_resendSeconds ث'
                    : 'إعادة إرسال الرمز',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPasswordLogin(bool isLoading) {
    return Column(
      key: const ValueKey('password-login'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _FieldLabel('البريد الإلكتروني أو رقم الهاتف'),
        const SizedBox(height: 8),
        TextField(
          controller: _identifierController,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.right,
          decoration: _inputDecoration(
            hintText: 'example@gmail.com أو 0912345678',
            icon: Icons.person_outline_rounded,
          ),
        ),
        const SizedBox(height: 16),
        const _FieldLabel('كلمة السر'),
        const SizedBox(height: 8),
        TextField(
          controller: _passwordController,
          obscureText: !_isPasswordVisible,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.password],
          decoration: _inputDecoration(
            hintText: 'أدخل كلمة السر',
            icon: Icons.lock_outline_rounded,
            trailing: IconButton(
              onPressed: () => setState(
                () => _isPasswordVisible = !_isPasswordVisible,
              ),
              icon: Icon(
                _isPasswordVisible
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
              ),
            ),
          ),
          onSubmitted: (_) {
            if (!isLoading) _passwordLogin();
          },
        ),
        const SizedBox(height: 20),
        _PrimaryButton(
          label: 'دخول بكلمة السر',
          icon: Icons.login_rounded,
          isLoading: isLoading,
          onPressed: _passwordLogin,
        ),
      ],
    );
  }
}

class _LoginMethodSwitch extends StatelessWidget {
  const _LoginMethodSwitch({
    required this.value,
    required this.onChanged,
  });

  final _LoginMethod value;
  final ValueChanged<_LoginMethod>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.neutral100,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          _MethodButton(
            label: 'رمز البريد',
            selected: value == _LoginMethod.emailCode,
            onPressed: () => onChanged?.call(_LoginMethod.emailCode),
          ),
          _MethodButton(
            label: 'كلمة السر',
            selected: value == _LoginMethod.password,
            onPressed: () => onChanged?.call(_LoginMethod.password),
          ),
        ],
      ),
    );
  }
}

class _MethodButton extends StatelessWidget {
  const _MethodButton({
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(11),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: .06),
                      blurRadius: 10,
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? AppColors.brandBlue : AppColors.textSecondary,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    required this.icon,
    required this.isLoading,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final bool isLoading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: FilledButton.icon(
        onPressed: isLoading ? null : onPressed,
        icon: isLoading
            ? const SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : Icon(icon),
        label: Text(
          isLoading ? 'يرجى الانتظار...' : label,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.brandBlue,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}

class _AuthHeader extends StatelessWidget {
  const _AuthHeader({required this.subtitle});

  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 66,
          height: 66,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Image.asset(
            'assets/images/bitehub_app_icon.png',
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'تسجيل الدخول',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 26,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 14,
            fontWeight: FontWeight.w700,
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

class _SecurityNote extends StatelessWidget {
  const _SecurityNote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(
          Icons.shield_outlined,
          color: AppColors.textSecondary,
          size: 16,
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
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
    contentPadding: const EdgeInsets.symmetric(vertical: 15, horizontal: 14),
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
