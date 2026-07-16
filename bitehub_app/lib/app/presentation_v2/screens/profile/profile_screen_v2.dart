import 'dart:io';

import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';
import 'package:provider/provider.dart';

import 'package:bitehub_app/app/core/localization/app_strings.dart';
import 'package:bitehub_app/app/core/theme/app_colors.dart';
import 'package:bitehub_app/app/data/models/user_model.dart';
import 'package:bitehub_app/app/data/models/wallet_model.dart';
import 'package:bitehub_app/app/data/providers/auth_provider.dart';
import 'package:bitehub_app/app/data/providers/locale_provider.dart';
import 'package:bitehub_app/app/data/providers/navigation_provider.dart';
import 'package:bitehub_app/app/presentation_v2/controllers/profile_v2_controller.dart';
import 'package:bitehub_app/app/presentation_v2/screens/legal/usage_policy_screen.dart';
import 'package:bitehub_app/app/presentation_v2/widgets/network_state_panel.dart';

class ProfileScreenV2 extends StatefulWidget {
  const ProfileScreenV2({
    super.key,
    this.controller,
    this.initializeController = true,
  });

  final ProfileV2Controller? controller;
  final bool initializeController;

  @override
  State<ProfileScreenV2> createState() => _ProfileScreenV2State();
}

class _ProfileScreenV2State extends State<ProfileScreenV2> {
  late final ProfileV2Controller _controller;
  late final bool _ownsController;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller = widget.controller ??
        ProfileV2Controller(
          authProvider: context.read<AuthProvider>(),
        );
    if (widget.initializeController) {
      _controller.initialize();
    }
  }

  @override
  void dispose() {
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  Future<void> _handlePickImage() async {
    final success = await _controller.pickLocalImage();
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'تم تحديث صورة الحساب.'
              : (_controller.errorMessage ?? 'لم يتم تغيير الصورة.'),
        ),
        backgroundColor: success ? AppColors.success : AppColors.danger,
      ),
    );
  }

  Future<void> _showEditDialog() async {
    final user = _controller.user;
    if (user == null) {
      return;
    }

    final nameController = TextEditingController(text: user.fullName);
    final emailController = TextEditingController(text: user.email);
    final phoneController = TextEditingController(text: user.phoneNumber);
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _EditProfileSheet(
        nameController: nameController,
        emailController: emailController,
        phoneController: phoneController,
      ),
    );

    if (confirmed != true) {
      nameController.dispose();
      emailController.dispose();
      phoneController.dispose();
      return;
    }

    final success = await _controller.saveProfile(
      fullName: nameController.text.trim(),
      email: emailController.text.trim(),
      phoneNumber: phoneController.text.trim(),
    );
    nameController.dispose();
    emailController.dispose();
    phoneController.dispose();

    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'تم حفظ بيانات الحساب.'
              : (_controller.errorMessage ?? 'تعذر حفظ البيانات.'),
        ),
        backgroundColor: success ? AppColors.success : AppColors.danger,
      ),
    );
  }

  Future<void> _handleDeleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(
          Ionicons.warning_outline,
          color: AppColors.danger,
          size: 32,
        ),
        title: const Text('حذف الحساب نهائياً؟'),
        content: const Text(
          'سيتم حذف حساب الطالب ولن تتمكن من استعادته. راجع طلباتك ومحفظتك قبل المتابعة.',
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('رجوع'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('حذف الحساب'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    final success = await _controller.deleteAccount();
    if (!mounted) {
      return;
    }
    if (success) {
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_controller.errorMessage ?? 'تعذر حذف الحساب.'),
        backgroundColor: AppColors.danger,
      ),
    );
  }

  void _openPolicy() {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(builder: (_) => const UsagePolicyScreen()),
    );
  }

  void _openCafeDashboard() {
    Navigator.of(context).pushNamed('/cafe-dashboard');
  }

  void _selectTab(int index) {
    context.read<NavigationProvider>().setIndex(index);
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final localeProvider = context.watch<LocaleProvider>();

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        if (_controller.isLoading && _controller.user == null) {
          return const Center(child: CircularProgressIndicator());
        }

        if (_controller.errorMessage != null && _controller.user == null) {
          return NetworkStatePanel(
            title: 'تعذر تحميل الحساب',
            message: _controller.errorMessage!,
            actionLabel: 'إعادة المحاولة',
            onRetry: _controller.refresh,
          );
        }

        final user = _controller.user;
        if (user == null) {
          return const Center(child: Text('لا توجد بيانات حساب متاحة.'));
        }

        return RefreshIndicator(
          color: AppColors.brandBlue,
          onRefresh: _controller.refresh,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 124),
            children: [
              _ProfileIdentity(
                user: user,
                wallet: _controller.wallet,
                localImagePath: _controller.localImagePath,
                onPickImage: _handlePickImage,
              ),
              const SizedBox(height: 18),
              _QuickActions(
                onOrders: () => _selectTab(1),
                onWallet: () => _selectTab(3),
                onEdit: _showEditDialog,
              ),
              const SizedBox(height: 26),
              _SettingsGroup(
                title: 'الحساب',
                children: [
                  _SettingsRow(
                    icon: Ionicons.person_outline,
                    title: 'البيانات الشخصية',
                    subtitle: 'الاسم والبريد ورقم الهاتف',
                    onTap: _showEditDialog,
                  ),
                  _SettingsRow(
                    icon: Ionicons.language_outline,
                    title: strings.language,
                    subtitle: localeProvider.isArabic ? 'العربية' : 'English',
                    onTap: localeProvider.toggle,
                  ),
                ],
              ),
              const SizedBox(height: 22),
              _SettingsGroup(
                title: 'الدعم والقانون',
                children: [
                  _SettingsRow(
                    icon: Ionicons.document_text_outline,
                    title: 'سياسة الاستخدام والإلغاء',
                    subtitle: 'الطلبات والدفع والاسترداد والخصوصية',
                    onTap: _openPolicy,
                  ),
                  const _SettingsRow(
                    icon: Ionicons.information_circle_outline,
                    title: 'عن Bite Hub',
                    subtitle: 'منصة طلب ودفع للمقاهي الجامعية',
                  ),
                ],
              ),
              if (user.hasCafeDashboardAccess) ...[
                const SizedBox(height: 22),
                _SettingsGroup(
                  title: 'إدارة المقهى',
                  children: [
                    _SettingsRow(
                      icon: Ionicons.storefront_outline,
                      title: user.managedCafeName ?? 'لوحة تحكم المقهى',
                      subtitle: 'فتح منظومة التشغيل الخاصة بالمقهى',
                      iconColor: AppColors.warning,
                      onTap: _openCafeDashboard,
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 22),
              _SettingsGroup(
                title: 'الجلسة',
                children: [
                  _SettingsRow(
                    icon: Ionicons.log_out_outline,
                    title: 'تسجيل الخروج',
                    subtitle: 'إنهاء الجلسة على هذا الجهاز',
                    onTap: _controller.logout,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TextButton(
                onPressed: _controller.isSaving ? null : _handleDeleteAccount,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.danger,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text(
                  'حذف الحساب نهائياً',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ProfileIdentity extends StatelessWidget {
  const _ProfileIdentity({
    required this.user,
    required this.wallet,
    required this.localImagePath,
    required this.onPickImage,
  });

  final User user;
  final WalletModel? wallet;
  final String? localImagePath;
  final VoidCallback onPickImage;

  ImageProvider<Object>? _resolveImage() {
    if (localImagePath != null && File(localImagePath!).existsSync()) {
      return FileImage(File(localImagePath!));
    }
    final profileImage = user.profileImage?.trim() ?? '';
    return profileImage.isEmpty
        ? null
        : ResizeImage(
            NetworkImage(profileImage),
            width: 180,
            height: 180,
          );
  }

  @override
  Widget build(BuildContext context) {
    final image = _resolveImage();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .04),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  CircleAvatar(
                    radius: 38,
                    backgroundColor: const Color(0xFFEFF6FF),
                    backgroundImage: image,
                    child: image == null
                        ? const Icon(
                            Ionicons.person_outline,
                            color: AppColors.brandBlue,
                            size: 34,
                          )
                        : null,
                  ),
                  PositionedDirectional(
                    bottom: -2,
                    end: -2,
                    child: Material(
                      color: AppColors.textPrimary,
                      shape: const CircleBorder(),
                      child: InkWell(
                        onTap: onPickImage,
                        customBorder: const CircleBorder(),
                        child: const Padding(
                          padding: EdgeInsets.all(8),
                          child: Icon(
                            Ionicons.camera_outline,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.fullName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      user.email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (user.phoneNumber.trim().isNotEmpty) ...[
                      const SizedBox(height: 9),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Text(
                          user.phoneNumber,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Ionicons.wallet_outline,
                    color: AppColors.brandBlue,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'الرصيد المتاح',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  wallet == null
                      ? '--'
                      : '${wallet!.balance.toStringAsFixed(2)} ${wallet!.currency}',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({
    required this.onOrders,
    required this.onWallet,
    required this.onEdit,
  });

  final VoidCallback onOrders;
  final VoidCallback onWallet;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _QuickAction(
            icon: Ionicons.receipt_outline,
            label: 'طلباتي',
            onTap: onOrders,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _QuickAction(
            icon: Ionicons.wallet_outline,
            label: 'المحفظة',
            onTap: onWallet,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _QuickAction(
            icon: Ionicons.create_outline,
            label: 'تعديل',
            onTap: onEdit,
          ),
        ),
      ],
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              Icon(icon, color: AppColors.textPrimary, size: 22),
              const SizedBox(height: 7),
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 4, bottom: 10),
          child: Text(
            title,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: List.generate(children.length, (index) {
              return Column(
                children: [
                  children[index],
                  if (index != children.length - 1)
                    const Divider(
                      height: 1,
                      indent: 62,
                      endIndent: 16,
                      color: AppColors.border,
                    ),
                ],
              );
            }),
          ),
        ),
      ],
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.iconColor = AppColors.brandBlue,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color iconColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: .09),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 19),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (onTap != null)
                const Icon(
                  Ionicons.chevron_back_outline,
                  color: AppColors.textSecondary,
                  size: 17,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EditProfileSheet extends StatelessWidget {
  const _EditProfileSheet({
    required this.nameController,
    required this.emailController,
    required this.phoneController,
  });

  final TextEditingController nameController;
  final TextEditingController emailController;
  final TextEditingController phoneController;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Material(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'تعديل البيانات الشخصية',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 21,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: nameController,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'الاسم الكامل',
                      prefixIcon: Icon(Ionicons.person_outline),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'البريد الإلكتروني',
                      prefixIcon: Icon(Ionicons.mail_outline),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(
                      labelText: 'رقم الهاتف',
                      prefixIcon: Icon(Ionicons.call_outline),
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text('حفظ التغييرات'),
                    ),
                  ),
                  Center(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('إلغاء'),
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
