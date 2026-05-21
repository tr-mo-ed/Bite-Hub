// lib/app/presentation/screens/auth/otp_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:pinput/pinput.dart';
import 'package:bitehub_app/app/presentation_v2/screens/main_shell_v2.dart';

// ???? ???? OTPScreen ???? ???? ????? ???? ?? ???? ????.
class OTPScreen extends StatefulWidget {
  // ??? ??????? phoneNumber ??? ?????? ???? ????? ????.
  final String phoneNumber;

  const OTPScreen({super.key, required this.phoneNumber});

  @override
  // ???? ???? createState ???? ??????? ?? ????? ???? ?????? ?????.
  State<OTPScreen> createState() => _OTPScreenState();
}

// ???? ???? _OTPScreenState ???? ???? ????? ???? ?? ???? ????.
class _OTPScreenState extends State<OTPScreen> {
  final _pinController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  // إدارة المؤقت
  Timer? _timer;
  int _start = 60;
  bool _canResend = false;

  @override
  // ???? ???? initState ???? ??????? ?? ????? ???? ?????? ?????.
  void initState() {
    super.initState();
    startTimer();
  }

  // ???? ???? startTimer ???? ??????? ?? ????? ???? ?????? ?????.
  void startTimer() {
    setState(() {
      _canResend = false;
      _start = 60;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_start == 0) {
        if (mounted) {
          setState(() {
            _canResend = true;
            timer.cancel();
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _start--;
          });
        }
      }
    });
  }

  @override
  // ???? ???? dispose ???? ??????? ?? ????? ???? ?????? ?????.
  void dispose() {
    _pinController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  // توحيد الأرقام
  String _normalizeDigits(String input) {
    final buffer = StringBuffer();
    for (final code in input.runes) {
      if (code >= 0x30 && code <= 0x39) {
        buffer.writeCharCode(code);
        continue;
      }
      if (code >= 0x0660 && code <= 0x0669) {
        buffer.write(code - 0x0660);
        continue;
      }
      if (code >= 0x06F0 && code <= 0x06F9) {
        buffer.write(code - 0x06F0);
      }
    }
    return buffer.toString();
  }

  // التحقق (5 أرقام)
  bool _isValidOtp(String value) {
    final normalized = _normalizeDigits(value);
    return RegExp(r'^\d{5}$').hasMatch(normalized);
  }

  // الدخول المباشر (تجاوز السيرفر)
  void _bypassAndGoHome() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم التحقق بنجاح'),
        backgroundColor: Color(0xFF24A8E0),
        duration: Duration(milliseconds: 500),
      ),
    );

    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const MainShellV2()),
        (route) => false,
      );
    });
  }

  @override
  // ???? ???? build ???? ??????? ?? ????? ???? ?????? ?????.
  Widget build(BuildContext context) {
    // 1. إعداد الثيم الافتراضي (الخانة العادية)
    const defaultPinTheme = PinTheme(
      width: 60,
      height: 60,
      textStyle: TextStyle(
        fontSize: 24,
        color: Colors.black,
        fontWeight: FontWeight.bold,
      ),
      decoration: BoxDecoration(
        color: Color(0xFFF0F0F0), // رمادي فاتح
        shape: BoxShape.circle, // دائري
      ),
    );

    // 2. إعداد ثيم التركيز (عند الكتابة) - تم تصحيح الخطأ هنا
    final focusedPinTheme = defaultPinTheme.copyWith(
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border:
            Border.all(color: const Color(0xFF24A8E0), width: 2), // إطار ملون
      ),
    );

    // 3. إعداد ثيم الخطأ
    final errorPinTheme = defaultPinTheme.copyWith(
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.redAccent, width: 2),
      ),
    );

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: SingleChildScrollView(
            padding:
                const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  // زر الرجوع
                  Align(
                    alignment: Alignment.centerRight,
                    child: InkWell(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.black, width: 2),
                        ),
                        child: const Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 20,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),

                  // الشعار (مؤقت)
                  Container(
                    width: 100,
                    height: 100,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                    ),
                    child: const Stack(
                      alignment: Alignment.center,
                      children: [
                        Icon(Icons.grid_view_rounded,
                            size: 80, color: Color(0xFFE87C3E)),
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),

                  // النصوص
                  const Text(
                    'أدخل رمز التأكيد',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'قم بإدخال الرمز الذي تم إرساله على الرقم',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.phoneNumber.isNotEmpty
                        ? widget.phoneNumber
                        : "090000000",
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                      letterSpacing: 1,
                    ),
                  ),

                  const SizedBox(height: 40),

                  // خانات الإدخال (5 خانات)
                  Pinput(
                    controller: _pinController,
                    length: 5,
                    defaultPinTheme: defaultPinTheme,
                    focusedPinTheme: focusedPinTheme,
                    errorPinTheme: errorPinTheme, // استخدام ثيم الخطأ المصحح
                    pinputAutovalidateMode: PinputAutovalidateMode.onSubmit,
                    showCursor: true,
                    keyboardType: TextInputType.number,
                    onCompleted: (pin) {
                      if (_isValidOtp(pin)) {
                        _bypassAndGoHome();
                      }
                    },
                  ),

                  const SizedBox(height: 30),

                  // إعادة الإرسال
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'لم يصلك الرمز؟ ',
                        style: TextStyle(color: Colors.grey[600], fontSize: 16),
                      ),
                      GestureDetector(
                        onTap: _canResend
                            ? () {
                                startTimer();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content:
                                          Text('تم إعادة إرسال الرمز (وهمي)')),
                                );
                              }
                            : null,
                        child: Text(
                          _canResend ? 'إعادة الإرسال' : ' انتظر $_start ث',
                          style: TextStyle(
                            color: _canResend
                                ? const Color(0xFF24A8E0)
                                : Colors.grey,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 40),

                  // زر المتابعة
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: () {
                        final rawValue = _pinController.text;
                        if (!_isValidOtp(rawValue)) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('الرجاء إدخال 5 أرقام'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }
                        _bypassAndGoHome();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF24A8E0),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                      ),
                      child: const Text(
                        'المتابعة',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
