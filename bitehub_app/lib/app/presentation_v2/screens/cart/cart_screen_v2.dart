import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:bitehub_app/app/data/models/cart_item_model.dart';
import 'package:bitehub_app/app/data/providers/cart_provider.dart';
import 'package:bitehub_app/app/data/services/api_service.dart';
import 'package:bitehub_app/app/data/services/nfc_card_service.dart';
import 'package:bitehub_app/app/presentation_v2/controllers/cart_v2_controller.dart';
import 'package:bitehub_app/app/presentation_v2/screens/orders/live_order_tracking_screen_v2.dart';
import 'package:bitehub_app/app/presentation_v2/widgets/custom_floating_snack_bar.dart';
import 'package:bitehub_app/app/presentation_v2/widgets/pressable_scale.dart';

class CartScreenV2 extends StatefulWidget {
  const CartScreenV2({super.key});

  @override
  State<CartScreenV2> createState() => _CartScreenV2State();
}

class _CartScreenV2State extends State<CartScreenV2> {
  late final CartV2Controller _controller;
  late final TextEditingController _notesController;
  final ApiService _apiService = ApiService();
  bool _isSubmittingOrder = false;

  @override
  void initState() {
    super.initState();
    _controller = CartV2Controller(cartProvider: context.read<CartProvider>());
    _notesController = TextEditingController();
  }

  @override
  void dispose() {
    _notesController.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        if (_controller.isEmpty) {
          return _buildEmptyState();
        }

        return Stack(
          children: [
            Positioned.fill(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 240),
                children: [
                  _buildCafeSummary(),
                  const SizedBox(height: 18),
                  ..._controller.items.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: _CartItemCard(
                        item: item,
                        onIncrement: () => _controller.incrementItem(item.id),
                        onDecrement: () => _controller.decrementItem(item.id),
                        onRemove: () => _controller.removeItem(item.id),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildPaymentSelector(),
                  const SizedBox(height: 14),
                  _buildNotesField(),
                ],
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: SafeArea(
                top: false,
                child: _buildCheckoutPanel(),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 112,
              height: 112,
              decoration: BoxDecoration(
                color: const Color(0x140F766E),
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 18,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: const Icon(
                Icons.shopping_bag_outlined,
                size: 48,
                color: Color(0xFF3559C7),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'السلة فارغة',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              'أضف منتجاتك من الشاشة الرئيسية ثم عد هنا لإتمام الطلب.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade600,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCafeSummary() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF3559C7), Color(0xFF24A8E0)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3559C7).withValues(alpha: 0.18),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(Icons.storefront_rounded, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'السلة الحالية',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  _controller.cafeName ?? 'المقهى',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          PressableScale(
            onTap: _showClearDialog,
            borderRadius: BorderRadius.circular(18),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.delete_outline_rounded, color: Colors.white),
                  SizedBox(width: 6),
                  Text(
                    'مسح',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentSelector() {
    return _FloatingSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'طريقة الدفع',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _PaymentMethodChip(
                  icon: Icons.account_balance_wallet_rounded,
                  label: 'المحفظة',
                  selected: _controller.paymentMethod == 'WALLET',
                  onTap: () => _controller.selectPaymentMethod('WALLET'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _PaymentMethodChip(
                  icon: Icons.nfc_rounded,
                  label: 'بطاقة NFC',
                  selected: _controller.paymentMethod == 'NFC',
                  onTap: () => _controller.selectPaymentMethod('NFC'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            child: Text(
              _controller.paymentMethod == 'NFC'
                  ? 'سيُطلب منك تقريب البطاقة المرتبطة بمحفظتك قبل تأكيد الطلب.'
                  : 'سيتم الخصم مباشرة من رصيد محفظتك.',
              key: ValueKey(_controller.paymentMethod),
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckoutPanel() {
    final isBusy = _controller.isSubmitting || _isSubmittingOrder;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 28,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 54,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_controller.itemCount} عناصر',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${_controller.totalAmount.toStringAsFixed(2)} د.ل',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF3559C7),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: PressableScale(
                  onTap: isBusy ? null : _handleCheckout,
                  borderRadius: BorderRadius.circular(22),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    height: 60,
                    decoration: BoxDecoration(
                      color: isBusy
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF3559C7),
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: isBusy
                          ? const []
                          : [
                              BoxShadow(
                                color: const Color(0xFF3559C7)
                                    .withValues(alpha: 0.24),
                                blurRadius: 18,
                                offset: const Offset(0, 8),
                              ),
                            ],
                    ),
                    child: Center(
                      child: isBusy
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: Colors.white,
                              ),
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'إتمام الطلب',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                SizedBox(width: 8),
                                Icon(
                                  Icons.arrow_forward_rounded,
                                  color: Colors.white,
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _handleCheckout() async {
    try {
      setState(() => _isSubmittingOrder = true);
      String? nfcCardUid;
      if (_controller.paymentMethod == 'NFC') {
        nfcCardUid = await _scanNfcForPayment();
        if (nfcCardUid == null) {
          return;
        }
      }
      final orderItems = _controller.items
          .map(
            (item) => <String, dynamic>{
              'product_id': item.productId,
              'quantity': item.quantity,
              'options': item.options,
            },
          )
          .toList();
      final order = await _apiService.createOrder(
        _controller.totalAmount,
        orderItems,
        _controller.items.first.collegeId,
        paymentMethod: _controller.paymentMethod,
        orderNote: _notesController.text.trim(),
        nfcCardUid: nfcCardUid,
      );
      if (!mounted) {
        return;
      }
      _controller.clear();
      _notesController.clear();
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => LiveOrderTrackingScreenV2(
            initialOrder: order,
            initialOrderId: order.id,
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      final message = error.toString().trim().isNotEmpty
          ? error.toString()
          : (_controller.errorMessage ?? 'تعذر إرسال الطلب.');
      await CustomFloatingSnackBar.show(
        context,
        title: 'تعذر إتمام الطلب',
        message: message,
        icon: Icons.error_outline_rounded,
        accentColor: const Color(0xFFDC2626),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmittingOrder = false);
      }
    }
  }

  Future<String?> _scanNfcForPayment() async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(26),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(30),
            ),
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.contactless_rounded,
                  size: 72,
                  color: Color(0xFF3157F5),
                ),
                SizedBox(height: 18),
                Text(
                  'قرّب بطاقة الدفع',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'استخدم البطاقة المرتبطة بمحفظتك لتأكيد العملية.',
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 20),
                LinearProgressIndicator(
                  minHeight: 5,
                  borderRadius: BorderRadius.all(Radius.circular(99)),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final uid = await NfcCardService.instance.scanCard();
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      return uid;
    } catch (error) {
      if (!mounted) {
        return null;
      }
      Navigator.of(context, rootNavigator: true).pop();
      await CustomFloatingSnackBar.show(
        context,
        title: 'تعذر قراءة البطاقة',
        message: error.toString(),
        icon: Icons.nfc_rounded,
        accentColor: const Color(0xFFDC2626),
      );
      return null;
    }
  }

  Widget _buildNotesField() {
    return _FloatingSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ملاحظات إضافية',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notesController,
            maxLines: 3,
            textInputAction: TextInputAction.newline,
            decoration: InputDecoration(
              hintText: 'أضف أي تفاصيل تريد إرسالها مع الطلب...',
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(
                  color: Color(0xFF24A8E0),
                  width: 1.4,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showClearDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('مسح السلة'),
        content: const Text('سيتم حذف جميع العناصر من السلة الحالية.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('مسح'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      _controller.clear();
    }
  }
}

class _FloatingSurface extends StatelessWidget {
  const _FloatingSurface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _CartItemCard extends StatelessWidget {
  const _CartItemCard({
    required this.item,
    required this.onIncrement,
    required this.onDecrement,
    required this.onRemove,
  });

  final CartItem item;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            _CartItemImage(imageUrl: item.imageUrl),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (item.options.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      item.options,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Text(
                    '${item.totalItemPrice.toStringAsFixed(2)} د.ل',
                    style: const TextStyle(
                      color: Color(0xFF3559C7),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              children: [
                _FloatingIconButton(
                  onTap: onRemove,
                  icon: Icons.close_rounded,
                  iconColor: Colors.grey.shade700,
                  backgroundColor: Colors.grey.shade100,
                ),
                const SizedBox(height: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    children: [
                      _FloatingIconButton(
                        onTap: onDecrement,
                        icon: Icons.remove_rounded,
                        iconColor: Colors.grey.shade700,
                        backgroundColor: Colors.white,
                        compact: true,
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          '${item.quantity}',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                      _FloatingIconButton(
                        onTap: onIncrement,
                        icon: Icons.add_rounded,
                        iconColor: const Color(0xFF3559C7),
                        backgroundColor: Colors.white,
                        compact: true,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CartItemImage extends StatelessWidget {
  const _CartItemImage({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    final isNetwork = imageUrl.startsWith('http');
    final hasAsset = imageUrl.isNotEmpty && !isNetwork;

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 88,
        height: 88,
        color: const Color(0xFFF3F4F6),
        child: imageUrl.isEmpty
            ? const Icon(Icons.fastfood_rounded, color: Color(0xFF94A3B8))
            : isNetwork
                ? Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.high,
                    isAntiAlias: true,
                    gaplessPlayback: true,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.fastfood_rounded,
                      color: Color(0xFF94A3B8),
                    ),
                  )
                : File(imageUrl).existsSync()
                    ? Image.file(
                        File(imageUrl),
                        fit: BoxFit.cover,
                        filterQuality: FilterQuality.high,
                        isAntiAlias: true,
                      )
                    : hasAsset
                        ? Image.asset(
                            imageUrl,
                            fit: BoxFit.cover,
                            filterQuality: FilterQuality.high,
                            isAntiAlias: true,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.fastfood_rounded,
                              color: Color(0xFF94A3B8),
                            ),
                          )
                        : const Icon(
                            Icons.fastfood_rounded,
                            color: Color(0xFF94A3B8),
                          ),
      ),
    );
  }
}

class _PaymentMethodChip extends StatelessWidget {
  const _PaymentMethodChip({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: selected ? const Color(0x140F766E) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? const Color(0xFF3559C7) : Colors.grey.shade200,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: selected ? const Color(0xFF3559C7) : Colors.grey.shade600,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color:
                    selected ? const Color(0xFF3559C7) : Colors.grey.shade800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FloatingIconButton extends StatelessWidget {
  const _FloatingIconButton({
    required this.onTap,
    required this.icon,
    required this.iconColor,
    required this.backgroundColor,
    this.compact = false,
  });

  final VoidCallback onTap;
  final IconData icon;
  final Color iconColor;
  final Color backgroundColor;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final size = compact ? 34.0 : 38.0;
    return PressableScale(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Icon(icon, color: iconColor, size: compact ? 18 : 20),
      ),
    );
  }
}
