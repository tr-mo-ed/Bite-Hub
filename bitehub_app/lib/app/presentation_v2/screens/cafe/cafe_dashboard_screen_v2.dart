import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:bitehub_app/app/core/theme/app_colors.dart';
import 'package:bitehub_app/app/data/providers/auth_provider.dart';
import 'package:bitehub_app/app/data/services/api_service.dart';

class CafeDashboardScreenV2 extends StatefulWidget {
  const CafeDashboardScreenV2({super.key});

  @override
  State<CafeDashboardScreenV2> createState() => _CafeDashboardScreenV2State();
}

class _CafeDashboardScreenV2State extends State<CafeDashboardScreenV2> {
  final ApiService _apiService = ApiService();

  CafeOrderStatus? _status;
  bool _isLoadingStatus = true;
  bool _isSavingStatus = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadCafeStatus();
  }

  Future<void> _loadCafeStatus() async {
    setState(() {
      _isLoadingStatus = true;
      _errorMessage = null;
    });

    try {
      final status = await _apiService.getManagedCafeOrderStatus();
      if (!mounted) return;
      setState(() => _status = status);
    } catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = error.toString());
    } finally {
      if (mounted) {
        setState(() => _isLoadingStatus = false);
      }
    }
  }

  Future<void> _setAcceptingOrders(bool value) async {
    if (_isSavingStatus) return;

    setState(() {
      _isSavingStatus = true;
      _errorMessage = null;
    });

    try {
      final status = await _apiService.setManagedCafeAcceptingOrders(value);
      if (!mounted) return;
      setState(() => _status = status);
      await context.read<AuthProvider>().fetchUserProfile();
      if (!mounted) return;
      _showMessage(
          value ? 'تم فتح استقبال الطلبات.' : 'تم إغلاق استقبال الطلبات.');
    } catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = error.toString());
      _showMessage(error.toString());
    } finally {
      if (mounted) {
        setState(() => _isSavingStatus = false);
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.currentUser;
    final cafeName = _status?.name ?? user?.managedCafeName ?? 'مقهى Bite Hub';
    final cafeCode = _status?.code ?? user?.managedCafeCode ?? '--';
    final isAcceptingOrders = _status?.isAcceptingOrders ??
        user?.managedCafeIsAcceptingOrders ??
        true;
    final isActive = _status?.isActive ?? user?.managedCafeIsActive ?? true;
    final canAcceptOrders = isActive && isAcceptingOrders;

    return Scaffold(
      appBar: AppBar(
        title: const Text('لوحة تحكم المقهى'),
      ),
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFF5F8FF),
              Color(0xFFFFFFFF),
            ],
          ),
        ),
        child: RefreshIndicator(
          onRefresh: _loadCafeStatus,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            children: [
              _CafeHeroCard(
                cafeName: cafeName,
                cafeCode: cafeCode,
                canAcceptOrders: canAcceptOrders,
              ),
              const SizedBox(height: 18),
              _OrderAcceptanceCard(
                isActive: isActive,
                isAcceptingOrders: isAcceptingOrders,
                isLoading: _isLoadingStatus,
                isSaving: _isSavingStatus,
                errorMessage: _errorMessage,
                onRefresh: _loadCafeStatus,
                onChanged: _setAcceptingOrders,
              ),
              const SizedBox(height: 20),
              const _ActionCard(
                icon: Icons.receipt_long_rounded,
                title: 'إدارة الطلبات',
                subtitle:
                    'تابع الطلبات الجديدة والجاهزة والملغاة من شاشة واحدة.',
              ),
              const SizedBox(height: 12),
              const _ActionCard(
                icon: Icons.inventory_2_rounded,
                title: 'المنتجات والمخزون',
                subtitle:
                    'يمكنك تعطيل المنتجات غير المتوفرة بدون إغلاق المقهى كاملًا.',
              ),
              const SizedBox(height: 12),
              const _ActionCard(
                icon: Icons.account_balance_wallet_rounded,
                title: 'محفظة المقهى',
                subtitle:
                    'عمليات المحفظة والخصم تبقى منفصلة عن حالة استقبال الطلبات.',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CafeHeroCard extends StatelessWidget {
  const _CafeHeroCard({
    required this.cafeName,
    required this.cafeCode,
    required this.canAcceptOrders,
  });

  final String cafeName;
  final String cafeCode;
  final bool canAcceptOrders;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            AppColors.brandNavy,
            Color(0xFF1C75BC),
            Color(0xFFF0B429),
          ],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1C75BC).withValues(alpha: 0.18),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.storefront_rounded,
                  color: Colors.white,
                  size: 30,
                ),
              ),
              const Spacer(),
              _StatusChip(isOpen: canAcceptOrders),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            cafeName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'رمز المقهى: $cafeCode',
            style: const TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            canAcceptOrders
                ? 'المقهى يستقبل الطلبات الآن من الطلاب.'
                : 'المقهى مغلق للطلبات حاليًا. الطلاب سيشاهدون الحالة ولن يستطيعوا إنشاء طلب جديد.',
            style: const TextStyle(
              color: Colors.white,
              height: 1.55,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderAcceptanceCard extends StatelessWidget {
  const _OrderAcceptanceCard({
    required this.isActive,
    required this.isAcceptingOrders,
    required this.isLoading,
    required this.isSaving,
    required this.errorMessage,
    required this.onRefresh,
    required this.onChanged,
  });

  final bool isActive;
  final bool isAcceptingOrders;
  final bool isLoading;
  final bool isSaving;
  final String? errorMessage;
  final Future<void> Function() onRefresh;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final canToggle = isActive && !isLoading && !isSaving;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isAcceptingOrders
              ? const Color(0xFFE6F4F1)
              : const Color(0xFFFEE2E2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.045),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isAcceptingOrders
                    ? Icons.check_circle_rounded
                    : Icons.pause_circle_filled_rounded,
                color: isAcceptingOrders ? AppColors.success : AppColors.danger,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isAcceptingOrders
                      ? 'استقبال الطلبات مفتوح'
                      : 'استقبال الطلبات مغلق',
                  style: const TextStyle(
                    color: AppColors.brandNavy,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (isLoading || isSaving)
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                )
              else
                Switch(
                  value: isAcceptingOrders,
                  onChanged: canToggle ? onChanged : null,
                  activeThumbColor: AppColors.success,
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            !isActive
                ? 'المقهى موقوف من السوبر أدمن، لذلك لا يمكن فتح الطلبات من هنا.'
                : isAcceptingOrders
                    ? 'عند الإغلاق، تظهر حالة مغلق للطلاب ويتم رفض أي طلب جديد من السيرفر.'
                    : 'يمكنك إعادة فتح الطلبات في أي وقت عندما يكون المقهى جاهزًا.',
            style: TextStyle(
              color: Colors.blueGrey.shade700,
              height: 1.45,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (errorMessage != null) ...[
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(errorMessage!),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.isOpen});

  final bool isOpen;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isOpen ? Icons.radio_button_checked : Icons.lock_clock_rounded,
            color: Colors.white,
            size: 15,
          ),
          const SizedBox(width: 6),
          Text(
            isOpen ? 'مفتوح' : 'مغلق',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF4D6),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(
              icon,
              color: AppColors.brandNavy,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    color: AppColors.brandNavy,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.blueGrey.shade700,
                    height: 1.45,
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
