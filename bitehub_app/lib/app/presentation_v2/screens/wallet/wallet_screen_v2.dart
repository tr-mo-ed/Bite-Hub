import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:bitehub_app/app/core/theme/app_colors.dart';
import 'package:bitehub_app/app/data/providers/notification_provider.dart';
import 'package:bitehub_app/app/data/models/transaction_model.dart';
import 'package:bitehub_app/app/data/models/wallet_model.dart';
import 'package:bitehub_app/app/data/services/nfc_card_service.dart';
import 'package:bitehub_app/app/presentation_v2/controllers/wallet_v2_controller.dart';
import 'package:bitehub_app/app/presentation_v2/widgets/bh_design.dart';
import 'package:bitehub_app/app/presentation_v2/widgets/network_state_panel.dart';
import 'package:bitehub_app/app/presentation_v2/widgets/wallet_ui.dart';

class WalletScreenV2 extends StatefulWidget {
  const WalletScreenV2({super.key});

  @override
  State<WalletScreenV2> createState() => _WalletScreenV2State();
}

class _WalletScreenV2State extends State<WalletScreenV2> {
  late final WalletV2Controller _controller;

  @override
  void initState() {
    super.initState();
    _controller = WalletV2Controller();
    _controller.initialize();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        if (_controller.isLoading && _controller.wallet == null) {
          return const Center(child: CircularProgressIndicator());
        }

        if (_controller.errorMessage != null && _controller.wallet == null) {
          return NetworkStatePanel(
            title: 'تعذر تحميل المحفظة',
            message: _controller.errorMessage!,
            actionLabel: 'إعادة المحاولة',
            onRetry: _controller.refresh,
          );
        }

        final wallet = _controller.wallet;
        if (wallet == null) {
          return const Center(
              child: Text('لا توجد بيانات محفظة متاحة حالياً.'));
        }

        return DecoratedBox(
          decoration: const BoxDecoration(color: AppColors.background),
          child: RefreshIndicator(
            color: AppColors.brandBlue,
            onRefresh: _controller.refresh,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
              children: [
                _BalancePanel(wallet: wallet),
                const SizedBox(height: BhSpacing.md),
                _NfcWalletPanel(
                  wallet: wallet,
                  isBusy: _controller.isPerformingAction,
                  onLink: _linkNfcCard,
                ),
                const SizedBox(height: BhSpacing.lg),
                _WalletActions(
                  isBusy: _controller.isPerformingAction,
                  onTransfer: _showTransferDialog,
                  onNfcTransfer: _showNfcTransfer,
                  onNfc: _linkNfcCard,
                  hasNfcCard: wallet.hasNfcCard,
                  onRefresh: _controller.refresh,
                ),
                const SizedBox(height: BhSpacing.lg),
                _TransactionsPanel(transactions: wallet.transactions),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _linkNfcCard() async {
    if (_controller.isPerformingAction) {
      return;
    }

    try {
      final cardUid = await _scanNfcCard();
      final success = await _controller.linkNfcCard(cardUid);
      if (mounted) {
        _showResult(success);
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString()),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  Future<String> _scanNfcCard() async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _NfcScanningDialog(),
    );
    try {
      return await NfcCardService.instance.scanCard();
    } finally {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    }
  }

  Future<void> _showNfcTransfer() async {
    if (_controller.isPerformingAction) {
      return;
    }

    try {
      final cardUid = await _scanNfcCard();
      final card = await _controller.lookupNfcCard(cardUid);
      if (!mounted) {
        return;
      }
      if (card.isOwner) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('لا يمكن التحويل إلى بطاقتك أنت.'),
            backgroundColor: AppColors.danger,
          ),
        );
        return;
      }

      final details = [
        if (card.college.isNotEmpty) card.college,
        if (card.email.isNotEmpty) card.email,
        if (card.cardLast4.isNotEmpty) 'البطاقة •••• ${card.cardLast4}',
      ].join('  •  ');
      final data = await _showAmountDialog(
        title: 'تحويل إلى ${card.studentName}',
        primaryLabel: 'تأكيد التحويل',
        showWalletCode: false,
        helperText: details,
      );
      if (data == null) {
        return;
      }

      final success = await _controller.transferToNfcCard(
        cardUid: cardUid,
        amount: data.amount,
        note: data.note,
      );
      if (success && mounted) {
        await context.read<NotificationProvider>().refreshFromServer(
              silent: true,
            );
      }
      if (mounted) {
        _showResult(success);
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString()),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  Future<void> _showTransferDialog() async {
    final data = await _showAmountDialog(
      title: 'تحويل إلى محفظة',
      primaryLabel: 'تحويل',
      showWalletCode: true,
      showRecipientName: true,
    );
    if (data == null) {
      return;
    }

    final success = await _controller.transfer(
      walletCode: data.walletCode,
      amount: data.amount,
      recipientName: data.recipientName,
      note: data.note,
    );
    if (success && mounted) {
      await context.read<NotificationProvider>().refreshFromServer(
            silent: true,
          );
    }
    if (mounted) {
      _showResult(success);
    }
  }

  Future<_WalletActionInput?> _showAmountDialog({
    required String title,
    required String primaryLabel,
    required bool showWalletCode,
    bool showRecipientName = false,
    String? helperText,
  }) {
    final codeController = TextEditingController();
    final recipientNameController = TextEditingController();
    final amountController = TextEditingController();
    final noteController = TextEditingController();

    return showDialog<_WalletActionInput>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (helperText != null && helperText.trim().isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(BhSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.neutral50,
                  borderRadius: BorderRadius.circular(BhRadius.sm),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(
                  helperText,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: BhSpacing.md),
            ],
            if (showWalletCode) ...[
              TextField(
                controller: codeController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'كود المحفظة'),
              ),
              const SizedBox(height: BhSpacing.md),
            ],
            if (showRecipientName) ...[
              TextField(
                controller: recipientNameController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'اسم المستلم'),
              ),
              const SizedBox(height: BhSpacing.md),
            ],
            TextField(
              controller: amountController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'المبلغ'),
            ),
            const SizedBox(height: BhSpacing.md),
            TextField(
              controller: noteController,
              decoration: const InputDecoration(labelText: 'ملاحظة'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () {
              final amount = double.tryParse(amountController.text.trim()) ?? 0;
              Navigator.of(context).pop(
                _WalletActionInput(
                  amount: amount,
                  note: noteController.text.trim(),
                  recipientName: recipientNameController.text.trim(),
                  walletCode: codeController.text.trim(),
                ),
              );
            },
            child: Text(primaryLabel),
          ),
        ],
      ),
    );
  }

  void _showResult(bool success) {
    final message = success
        ? (_controller.errorMessage ?? 'تمت العملية بنجاح.')
        : (_controller.errorMessage ?? 'تعذر تنفيذ العملية.');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: success ? AppColors.success : AppColors.danger,
      ),
    );
  }
}

class _BalancePanel extends StatelessWidget {
  const _BalancePanel({required this.wallet});

  final WalletModel wallet;

  @override
  Widget build(BuildContext context) {
    return BhSurface(
      padding: const EdgeInsets.all(BhSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF4EF),
                  borderRadius: BorderRadius.circular(BhRadius.md),
                ),
                child: const Icon(
                  Icons.account_balance_wallet_outlined,
                  color: AppColors.brandBlue,
                ),
              ),
              const SizedBox(width: BhSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      wallet.userFullName.isEmpty
                          ? 'محفظة الطالب'
                          : wallet.userFullName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      wallet.college.isEmpty ? 'Bite Hub' : wallet.college,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const BhStatusPill(
                label: 'نشطة',
                foreground: AppColors.success,
                background: Color(0xFFE6F4F1),
              ),
            ],
          ),
          const SizedBox(height: BhSpacing.xl),
          const Text(
            'الرصيد المتاح',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${wallet.balance.toStringAsFixed(2)} ${wallet.currency}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 32,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
          const SizedBox(height: BhSpacing.lg),
          Container(
            padding: const EdgeInsets.all(BhSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.neutral50,
              borderRadius: BorderRadius.circular(BhRadius.sm),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.qr_code_2_rounded,
                  color: AppColors.textSecondary,
                  size: 20,
                ),
                const SizedBox(width: BhSpacing.sm),
                const Text(
                  'كود المحفظة',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                SelectableText(
                  wallet.linkCode.isEmpty ? '---' : wallet.linkCode,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
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

class _NfcWalletPanel extends StatelessWidget {
  const _NfcWalletPanel({
    required this.wallet,
    required this.isBusy,
    required this.onLink,
  });

  final WalletModel wallet;
  final bool isBusy;
  final VoidCallback onLink;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: AppColors.walletGradient,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppColors.brandBlue.withValues(alpha: .25),
            blurRadius: 30,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Stack(
        children: [
          PositionedDirectional(
            top: -46,
            end: -28,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: .10),
                border: Border.all(
                  color: Colors.white.withValues(alpha: .16),
                  width: 18,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(22),
            child: Row(
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: .86, end: 1),
                  duration: const Duration(milliseconds: 700),
                  curve: Curves.easeOutBack,
                  builder: (context, value, child) => Transform.scale(
                    scale: value,
                    child: child,
                  ),
                  child: Container(
                    width: 66,
                    height: 66,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .16),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: .3),
                      ),
                    ),
                    child: const Icon(
                      Icons.nfc_rounded,
                      size: 36,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        wallet.hasNfcCard
                            ? 'بطاقة NFC مرتبطة'
                            : 'فعّل الدفع ببطاقتك',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        wallet.hasNfcCard
                            ? 'تنتهي بالرمز •••• ${wallet.nfcCardLast4}'
                            : 'قرّب البطاقة من خلف الهاتف لربطها بمحفظتك.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: .78),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 14),
                      FilledButton.icon(
                        onPressed: isBusy ? null : onLink,
                        icon: const Icon(Icons.contactless_rounded, size: 18),
                        label: Text(
                          wallet.hasNfcCard
                              ? 'استبدال البطاقة'
                              : 'مسح وربط البطاقة',
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppColors.brandNavy,
                          minimumSize: const Size(0, 42),
                        ),
                      ),
                    ],
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

class _NfcScanningDialog extends StatelessWidget {
  const _NfcScanningDialog();

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(26),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: AppColors.brandNavy.withValues(alpha: .18),
                blurRadius: 40,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: .82, end: 1.08),
                duration: const Duration(milliseconds: 900),
                curve: Curves.easeInOut,
                builder: (context, value, child) =>
                    Transform.scale(scale: value, child: child),
                child: Container(
                  width: 94,
                  height: 94,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppColors.accentGradient,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.brandBlue.withValues(alpha: .3),
                        blurRadius: 28,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.nfc_rounded,
                    color: Colors.white,
                    size: 48,
                  ),
                ),
              ),
              const SizedBox(height: 22),
              const Text(
                'بانتظار بطاقة NFC',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'قرّب البطاقة من الجزء الخلفي للهاتف وثبّتها لثانية.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w700,
                  height: 1.55,
                ),
              ),
              const SizedBox(height: 20),
              const LinearProgressIndicator(
                minHeight: 5,
                borderRadius: BorderRadius.all(Radius.circular(99)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WalletActions extends StatelessWidget {
  const _WalletActions({
    required this.isBusy,
    required this.onTransfer,
    required this.onNfcTransfer,
    required this.onNfc,
    required this.hasNfcCard,
    required this.onRefresh,
  });

  final bool isBusy;
  final VoidCallback onTransfer;
  final VoidCallback onNfcTransfer;
  final VoidCallback onNfc;
  final bool hasNfcCard;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final actions = [
      _ActionSpec(Icons.swap_horiz_rounded, 'تحويل', onTransfer),
      _ActionSpec(
        Icons.contactless_rounded,
        'تحويل إلى بطاقة',
        onNfcTransfer,
      ),
      _ActionSpec(
        Icons.nfc_rounded,
        hasNfcCard ? 'تغيير البطاقة' : 'ربط بطاقة',
        onNfc,
      ),
      _ActionSpec(Icons.refresh_rounded, 'تحديث', onRefresh),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 520 ? 4 : 2;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: actions.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisExtent: 76,
            crossAxisSpacing: BhSpacing.sm,
            mainAxisSpacing: BhSpacing.sm,
          ),
          itemBuilder: (context, index) {
            final action = actions[index];
            return _ActionButton(
              icon: action.icon,
              label: action.label,
              onTap: isBusy ? null : action.onTap,
            );
          },
        );
      },
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return BhSurface(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      color: onTap == null ? AppColors.neutral50 : AppColors.surface,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color:
                onTap == null ? AppColors.textSecondary : AppColors.brandBlue,
            size: 20,
          ),
          const SizedBox(height: 6),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: onTap == null
                  ? AppColors.textSecondary
                  : AppColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _TransactionsPanel extends StatelessWidget {
  const _TransactionsPanel({required this.transactions});

  final List<TransactionModel> transactions;

  @override
  Widget build(BuildContext context) {
    return BhSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BhSectionHeader(
            title: 'آخر العمليات',
            subtitle: transactions.isEmpty
                ? 'لا توجد معاملات بعد'
                : 'آخر ${transactions.length} عملية في المحفظة',
          ),
          const SizedBox(height: BhSpacing.md),
          if (transactions.isEmpty)
            const _EmptyTransactions()
          else
            ...transactions.map(
              (transaction) => Padding(
                padding: const EdgeInsets.only(bottom: BhSpacing.sm),
                child: _TransactionRow(transaction: transaction),
              ),
            ),
        ],
      ),
    );
  }
}

class _TransactionRow extends StatelessWidget {
  const _TransactionRow({required this.transaction});

  final TransactionModel transaction;

  @override
  Widget build(BuildContext context) {
    final color = transaction.isDebit ? AppColors.danger : AppColors.success;
    final background =
        transaction.isDebit ? const Color(0xFFFEE2E2) : const Color(0xFFE6F4F1);
    final sign = transaction.isDebit ? '-' : '+';
    final metaPrimary = transactionTypeLabel(transaction);
    final metaSecondary = transactionSourceLabel(transaction);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.neutral50,
        borderRadius: BorderRadius.circular(BhRadius.sm),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: background,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  transaction.isDebit
                      ? Icons.arrow_upward_rounded
                      : Icons.arrow_downward_rounded,
                  color: color,
                  size: 17,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  transaction.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: BhSpacing.sm),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: background,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$sign${transaction.amount.toStringAsFixed(2)}',
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  _transactionSubtitle(transaction),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _TransactionMetaPill(label: metaPrimary),
              if (metaSecondary.isNotEmpty)
                _TransactionMetaPill(label: metaSecondary),
            ],
          ),
        ],
      ),
    );
  }
}

class _TransactionMetaPill extends StatelessWidget {
  const _TransactionMetaPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          height: 1,
        ),
      ),
    );
  }
}

class _EmptyTransactions extends StatelessWidget {
  const _EmptyTransactions();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(BhSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.neutral50,
        borderRadius: BorderRadius.circular(BhRadius.sm),
        border: Border.all(color: AppColors.border),
      ),
      child: const Text(
        'ستظهر عمليات الشحن والدفع والتحويل هنا.',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ActionSpec {
  const _ActionSpec(this.icon, this.label, this.onTap);

  final IconData icon;
  final String label;
  final VoidCallback onTap;
}

class _WalletActionInput {
  const _WalletActionInput({
    required this.amount,
    required this.note,
    required this.recipientName,
    required this.walletCode,
  });

  final double amount;
  final String note;
  final String recipientName;
  final String walletCode;
}

String _transactionSubtitle(TransactionModel transaction) {
  final parts = [
    if (transaction.subtitle.trim().isNotEmpty) transaction.subtitle.trim(),
    if (transaction.date.trim().isNotEmpty) transaction.date.trim(),
  ];
  return parts.isEmpty ? 'عملية مالية' : parts.join('  •  ');
}
