import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:bitehub_app/app/core/theme/app_colors.dart';
import 'package:bitehub_app/app/data/providers/notification_provider.dart';
import 'package:bitehub_app/app/data/models/transaction_model.dart';
import 'package:bitehub_app/app/data/models/wallet_debit_request_model.dart';
import 'package:bitehub_app/app/data/models/wallet_model.dart';
import 'package:bitehub_app/app/presentation_v2/controllers/wallet_v2_controller.dart';
import 'package:bitehub_app/app/presentation_v2/widgets/bh_design.dart';
import 'package:bitehub_app/app/presentation_v2/widgets/network_state_panel.dart';
import 'package:bitehub_app/app/presentation_v2/widgets/wallet_ui.dart';

class WalletScreenV2 extends StatefulWidget {
  const WalletScreenV2({super.key});

  @override
  State<WalletScreenV2> createState() => _WalletScreenV2State();
}

String _displayWalletOwnerName(String value) {
  final normalized = value.trim();
  if (normalized.toLowerCase().contains('super admin')) {
    return '';
  }
  return normalized;
}

String _displayWalletCode(String value) {
  final normalized = value.trim();
  final digits = normalized.replaceAll(RegExp(r'\D'), '');
  if (digits.length >= 5) {
    return digits.substring(digits.length - 5);
  }
  if (digits.length >= 4) {
    return digits;
  }
  return normalized;
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
                if (wallet.pendingDebitRequests.isNotEmpty) ...[
                  const SizedBox(height: BhSpacing.md),
                  _DebitRequestsPanel(
                    requests: wallet.pendingDebitRequests,
                    isBusy: _controller.isPerformingAction,
                    onRespond: _respondToDebitRequest,
                  ),
                ],
                const SizedBox(height: BhSpacing.lg),
                _WalletActions(
                  isBusy: _controller.isPerformingAction,
                  onTransfer: _showTransferDialog,
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

  Future<void> _respondToDebitRequest(
    WalletDebitRequestModel requestItem,
    bool approve,
  ) async {
    if (_controller.isPerformingAction) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(approve ? 'تأكيد الموافقة' : 'تأكيد الرفض'),
        content: Text(
          approve
              ? 'سيتم خصم ${requestItem.amount.toStringAsFixed(2)} د.ل لصالح ${requestItem.cafeName}. هل توافق؟'
              : 'سيتم رفض طلب خصم ${requestItem.amount.toStringAsFixed(2)} د.ل من ${requestItem.cafeName} ولن يتغير رصيدك.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('رجوع'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: approve ? AppColors.success : AppColors.danger,
            ),
            child: Text(approve ? 'نعم، أوافق' : 'رفض الطلب'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }

    final success = await _controller.respondToDebitRequest(
      requestId: requestItem.id,
      approve: approve,
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
                keyboardType: TextInputType.number,
                maxLength: 5,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'كود المحفظة',
                  counterText: '',
                ),
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

class _DebitRequestsPanel extends StatelessWidget {
  const _DebitRequestsPanel({
    required this.requests,
    required this.isBusy,
    required this.onRespond,
  });

  final List<WalletDebitRequestModel> requests;
  final bool isBusy;
  final Future<void> Function(
    WalletDebitRequestModel requestItem,
    bool approve,
  ) onRespond;

  @override
  Widget build(BuildContext context) {
    return BhSurface(
      color: const Color(0xFFFFFBF2),
      borderColor: const Color(0xFFF1D9A8),
      padding: const EdgeInsets.all(BhSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.verified_user_outlined,
                color: AppColors.warning,
              ),
              SizedBox(width: BhSpacing.sm),
              Expanded(
                child: Text(
                  'طلبات خصم تحتاج موافقتك',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: BhSpacing.md),
          ...requests.map(
            (requestItem) => Padding(
              padding: const EdgeInsets.only(bottom: BhSpacing.sm),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(BhSpacing.md),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(BhRadius.sm),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      requestItem.cafeName,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'يريد هذا المقهى خصم ${requestItem.amount.toStringAsFixed(2)} د.ل من محفظتك. هل توافق؟',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        height: 1.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (requestItem.note.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        'ملاحظة: ${requestItem.note}',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                    const SizedBox(height: BhSpacing.md),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: isBusy
                                ? null
                                : () => onRespond(requestItem, true),
                            icon: const Icon(Icons.check_rounded),
                            label: const Text('موافقة'),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.success,
                            ),
                          ),
                        ),
                        const SizedBox(width: BhSpacing.sm),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: isBusy
                                ? null
                                : () => onRespond(requestItem, false),
                            icon: const Icon(Icons.close_rounded),
                            label: const Text('رفض'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.danger,
                              side: const BorderSide(
                                color: AppColors.danger,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BalancePanel extends StatelessWidget {
  const _BalancePanel({required this.wallet});

  final WalletModel wallet;

  @override
  Widget build(BuildContext context) {
    final ownerName = _displayWalletOwnerName(wallet.userFullName);
    final walletCode = _displayWalletCode(wallet.linkCode);

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
                      ownerName.isEmpty ? 'محفظة الطالب' : ownerName,
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
                  walletCode.isEmpty ? '---' : walletCode,
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

class _WalletActions extends StatelessWidget {
  const _WalletActions({
    required this.isBusy,
    required this.onTransfer,
    required this.onRefresh,
  });

  final bool isBusy;
  final VoidCallback onTransfer;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final actions = [
      _ActionSpec(Icons.swap_horiz_rounded, 'تحويل', onTransfer),
      _ActionSpec(Icons.refresh_rounded, 'تحديث', onRefresh),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 520 ? 2 : 2;
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
