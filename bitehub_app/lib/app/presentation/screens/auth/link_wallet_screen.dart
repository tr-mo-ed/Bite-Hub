// lib/app/presentation/screens/auth/link_wallet_screen.dart

import 'package:flutter/material.dart';
// import 'package:bitehub_app/app/data/services/api_service.dart'; // لا نحتاجه في التجاوز
import 'package:bitehub_app/app/core/widgets/bh_back_button.dart';
import 'package:bitehub_app/app/presentation_v2/screens/main_shell_v2.dart';

// ???? ???? LinkWalletScreen ???? ???? ????? ???? ?? ???? ????.
class LinkWalletScreen extends StatefulWidget {
  const LinkWalletScreen({super.key});

  @override
  // ???? ???? createState ???? ??????? ?? ????? ???? ?????? ?????.
  State<LinkWalletScreen> createState() => _LinkWalletScreenState();
}

// ???? ???? _LinkWalletScreenState ???? ???? ????? ???? ?? ???? ????.
class _LinkWalletScreenState extends State<LinkWalletScreen> {
  final _codeController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String? _errorMessage;
  // final ApiService _apiService = ApiService(); // تم التعطيل

  @override
  // ???? ???? dispose ???? ??????? ?? ????? ???? ?????? ?????.
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  // ???? ???? _handleLinkWallet ???? ??????? ?? ????? ???? ?????? ?????.
  Future<void> _handleLinkWallet() async {
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // === منطقة التعديل (Bypass) ===
    try {
      // محاكاة تأخير بسيط وكأنه يتصل بالسيرفر
      await Future.delayed(const Duration(seconds: 1));

      // بدلاً من الاتصال بالسيرفر، نعتبر العملية ناجحة فوراً
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("تم ربط المحفظة بنجاح!"),
            backgroundColor: Color(0xFF3559C7),
          ),
        );

        // الانتقال للشاشة الرئيسية مباشرة
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const MainShellV2()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = "حدث خطأ غير متوقع");
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  // ???? ???? build ???? ??????? ?? ????? ???? ?????? ?????.
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BhBackButton(),
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 40),
                const Icon(Icons.wallet_membership_outlined,
                    size: 80, color: Color(0xFF3559C7)),
                const SizedBox(height: 20),
                const Text(
                  'ربط المحفظة',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                const Text(
                  'الرجاء إدخال كود الربط لتفعيل المحفظة.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 40),
                TextFormField(
                  controller: _codeController,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 20, letterSpacing: 2),
                  decoration: InputDecoration(
                    hintText: 'XXX-XXX',
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  validator: (v) => v!.isEmpty ? 'أدخل الكود' : null,
                ),
                if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                const SizedBox(height: 30),
                SizedBox(
                  height: 55,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleLinkWallet,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3559C7),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            'تأكيد وربط',
                            style: TextStyle(fontSize: 18, color: Colors.white),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
