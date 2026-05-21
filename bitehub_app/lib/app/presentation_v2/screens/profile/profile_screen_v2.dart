import 'dart:io';

import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';
import 'package:provider/provider.dart';

import 'package:bitehub_app/app/data/models/user_model.dart';
import 'package:bitehub_app/app/data/models/wallet_model.dart';
import 'package:bitehub_app/app/data/providers/auth_provider.dart';
import 'package:bitehub_app/app/presentation_v2/controllers/profile_v2_controller.dart';
import 'package:bitehub_app/app/presentation_v2/widgets/network_state_panel.dart';

class ProfileScreenV2 extends StatefulWidget {
  const ProfileScreenV2({super.key});

  @override
  State<ProfileScreenV2> createState() => _ProfileScreenV2State();
}

class _ProfileScreenV2State extends State<ProfileScreenV2> {
  late final ProfileV2Controller _controller;

  @override
  void initState() {
    super.initState();
    _controller = ProfileV2Controller(
      authProvider: context.read<AuthProvider>(),
    );
    _controller.initialize();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handlePickImage() async {
    await _controller.pickLocalImage();
  }

  Future<void> _showEditDialog() async {
    final nameController =
        TextEditingController(text: _controller.user?.fullName ?? '');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تعديل الملف الشخصي'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(labelText: 'الاسم الكامل'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    final success =
        await _controller.saveProfile(fullName: nameController.text.trim());
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'تم تحديث البيانات بنجاح.'
              : (_controller.errorMessage ?? 'تعذر تحديث البيانات.'),
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: success ? const Color(0xFF3559C7) : Colors.redAccent,
      ),
    );
  }

  Future<void> _handleLogout() async {
    await _controller.logout();
  }

  Future<void> _handleDeleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف الحساب'),
        content: const Text(
          'سيتم حذف حسابك من التطبيق نهائياً. لا يمكن التراجع عن هذه العملية.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.redAccent,
            ),
            onPressed: () => Navigator.of(context).pop(true),
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
        content: Text(
          _controller.errorMessage ?? 'تعذر حذف الحساب.',
        ),
        backgroundColor: Colors.redAccent,
      ),
    );
  }

  void _openCafeDashboard() {
    Navigator.of(context).pushNamed('/cafe-dashboard');
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        if (_controller.isLoading && _controller.user == null) {
          return const Center(child: CircularProgressIndicator());
        }

        if (_controller.errorMessage != null && _controller.user == null) {
          return NetworkStatePanel(
            title: 'تعذر تحميل الملف الشخصي',
            message: _controller.errorMessage!,
            actionLabel: 'إعادة المحاولة',
            onRetry: _controller.refresh,
          );
        }

        final user = _controller.user;
        if (user == null) {
          return const Center(child: Text('لا توجد بيانات مستخدم متاحة.'));
        }

        return RefreshIndicator(
          onRefresh: _controller.refresh,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
            children: [
              ProfileHeader(
                user: user,
                wallet: _controller.wallet,
                localImagePath: _controller.localImagePath,
                onPickImage: _handlePickImage,
              ),
              const SizedBox(height: 18),
              ProfileMenu(
                title: 'الحساب',
                items: [
                  ProfileMenuItem(
                    icon: Ionicons.create_outline,
                    title: 'تعديل البيانات',
                    subtitle: 'تحديث الاسم الظاهر في حسابك',
                    onTap: _showEditDialog,
                  ),
                  ProfileMenuItem(
                    icon: Ionicons.refresh_outline,
                    title: 'تحديث البيانات',
                    subtitle: 'إعادة جلب آخر بياناتك من الخادم',
                    onTap: _controller.refresh,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ProfileMenu(
                title: 'المعلومات',
                items: [
                  ProfileMenuItem(
                    icon: Ionicons.mail_outline,
                    title: user.email,
                    subtitle: 'البريد الإلكتروني',
                  ),
                  ProfileMenuItem(
                    icon: Ionicons.call_outline,
                    title: user.phoneNumber,
                    subtitle: 'رقم الهاتف',
                  ),
                  ProfileMenuItem(
                    icon: Ionicons.qr_code_outline,
                    title: _controller.wallet?.linkCode.isNotEmpty == true
                        ? _controller.wallet!.linkCode
                        : 'غير متوفر',
                    subtitle: 'كود الربط',
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (user.hasCafeDashboardAccess) ...[
                ProfileMenu(
                  title: 'إدارة المقهى',
                  items: [
                    ProfileMenuItem(
                      icon: Ionicons.storefront_outline,
                      title: user.managedCafeName ?? 'لوحة تحكم المقهى',
                      subtitle: 'الدخول إلى المنظومة الصغيرة الخاصة بالمقهى',
                      iconColor: const Color(0xFF123C7A),
                      textColor: const Color(0xFF123C7A),
                      tileColor: const Color(0xFFFFF4D6),
                      tileBorderColor: const Color(0xFFF0B429),
                      onTap: _openCafeDashboard,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
              ProfileMenu(
                title: 'الجلسة',
                items: [
                  ProfileMenuItem(
                    icon: Ionicons.log_out_outline,
                    title: 'تسجيل الخروج',
                    subtitle: 'إنهاء الجلسة الحالية على هذا الجهاز',
                    iconColor: Colors.redAccent,
                    textColor: Colors.redAccent,
                    onTap: _handleLogout,
                  ),
                  ProfileMenuItem(
                    icon: Ionicons.trash_outline,
                    title: 'حذف الحساب',
                    subtitle: 'حذف حساب الطالب من التطبيق بشكل نهائي',
                    iconColor: const Color(0xFFB91C1C),
                    textColor: const Color(0xFFB91C1C),
                    onTap: _handleDeleteAccount,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class ProfileHeader extends StatelessWidget {
  const ProfileHeader({
    super.key,
    required this.user,
    required this.wallet,
    required this.localImagePath,
    required this.onPickImage,
  });

  final User user;
  final WalletModel? wallet;
  final String? localImagePath;
  final VoidCallback onPickImage;

  ImageProvider<Object> _resolveImage() {
    if (localImagePath != null && File(localImagePath!).existsSync()) {
      return FileImage(File(localImagePath!));
    }
    final profileImage = user.profileImage?.trim() ?? '';
    if (profileImage.isNotEmpty) {
      return NetworkImage(profileImage);
    }
    return const AssetImage('assets/images/logo.png');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF3559C7), Color(0xFF24A8E0)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              CircleAvatar(
                radius: 46,
                backgroundColor: Colors.white,
                backgroundImage: _resolveImage(),
              ),
              Positioned(
                bottom: -4,
                left: -4,
                child: Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  child: InkWell(
                    onTap: onPickImage,
                    borderRadius: BorderRadius.circular(18),
                    child: const Padding(
                      padding: EdgeInsets.all(10),
                      child: Icon(
                        Ionicons.camera_outline,
                        color: Color(0xFF3559C7),
                        size: 18,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            user.fullName,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            user.email,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _HeaderStat(
                  label: 'الرصيد',
                  value: wallet == null
                      ? '--'
                      : '${wallet!.balance.toStringAsFixed(2)} ${wallet!.currency}',
                  icon: Ionicons.wallet_outline,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _HeaderStat(
                  label: 'الهاتف',
                  value: user.phoneNumber,
                  icon: Ionicons.call_outline,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeaderStat extends StatelessWidget {
  const _HeaderStat({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
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

class ProfileMenu extends StatelessWidget {
  const ProfileMenu({
    super.key,
    required this.title,
    required this.items,
  });

  final String title;
  final List<ProfileMenuItem> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 14),
          ...List.generate(items.length, (index) {
            final item = items[index];
            return Padding(
              padding:
                  EdgeInsets.only(bottom: index == items.length - 1 ? 0 : 10),
              child: _ProfileMenuTile(item: item),
            );
          }),
        ],
      ),
    );
  }
}

class ProfileMenuItem {
  const ProfileMenuItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.iconColor,
    this.textColor,
    this.tileColor,
    this.tileBorderColor,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color? iconColor;
  final Color? textColor;
  final Color? tileColor;
  final Color? tileBorderColor;
  final VoidCallback? onTap;
}

class _ProfileMenuTile extends StatelessWidget {
  const _ProfileMenuTile({required this.item});

  final ProfileMenuItem item;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: item.tileColor ?? const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(20),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: item.tileBorderColor == null
            ? BorderSide.none
            : BorderSide(color: item.tileBorderColor!, width: 1.1),
      ),
      child: InkWell(
        onTap: item.onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0x140F766E),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  item.icon,
                  color: item.iconColor ?? const Color(0xFF3559C7),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: item.textColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.subtitle,
                      style: TextStyle(
                        color: (item.textColor ?? Colors.grey.shade600)
                            .withValues(
                                alpha: item.textColor == null ? 1 : 0.85),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Ionicons.chevron_back_outline,
                size: 18,
                color: item.textColor ?? const Color(0xFF64748B),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
