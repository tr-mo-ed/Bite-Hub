import 'package:flutter/foundation.dart';
import 'package:bitehub_app/app/data/models/nfc_card_model.dart';
import 'package:bitehub_app/app/data/models/wallet_model.dart';
import 'package:bitehub_app/app/data/services/api_service.dart';

// ???? ???? WalletV2Controller ???? ???? ????? ???? ?? ???? ????.
class WalletV2Controller extends ChangeNotifier {
  WalletV2Controller({ApiService? apiService})
      : _apiService = apiService ?? ApiService();

  // ??? ??????? _apiService ??? ?????? ???? ????? ????.
  final ApiService _apiService;

  bool _isLoading = true;
  bool _isPerformingAction = false;
  String? _errorMessage;
  WalletModel? _wallet;

  bool get isLoading => _isLoading;
  bool get isPerformingAction => _isPerformingAction;
  String? get errorMessage => _errorMessage;
  WalletModel? get wallet => _wallet;

  // ???? ???? initialize ???? ??????? ?? ????? ???? ?????? ?????.
  Future<void> initialize() async {
    await refresh();
  }

  // ???? ???? refresh ???? ??????? ?? ????? ???? ?????? ?????.
  Future<void> refresh() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _wallet = await _apiService.getWallet();
    } catch (error) {
      _errorMessage = error.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ???? ???? transfer ???? ??????? ?? ????? ???? ?????? ?????.
  Future<bool> transfer({
    required String walletCode,
    required double amount,
    String? recipientName,
    String? note,
  }) async {
    return _runAction(
      () => _apiService.transferWallet(
        walletCode: walletCode,
        amount: amount,
        recipientName: recipientName,
        note: note,
      ),
      successMessage: 'تم إرسال التحويل بنجاح.',
    );
  }

  Future<bool> linkNfcCard(String cardUid) {
    return _runAction(
      () => _apiService.linkNfcCard(cardUid),
      successMessage: 'تم ربط بطاقة NFC بمحفظتك بنجاح.',
    );
  }

  Future<NfcCardModel> lookupNfcCard(String cardUid) {
    return _apiService.lookupNfcCard(cardUid);
  }

  Future<bool> respondToDebitRequest({
    required String requestId,
    required bool approve,
  }) {
    return _runAction(
      () => _apiService.respondWalletDebitRequest(
        requestId: requestId,
        approve: approve,
      ),
      successMessage: approve
          ? 'تمت الموافقة وخصم المبلغ من محفظتك.'
          : 'تم رفض طلب الخصم ولن يتغير رصيدك.',
    );
  }

  Future<bool> transferToNfcCard({
    required String cardUid,
    required double amount,
    String? note,
  }) {
    return _runAction(
      () => _apiService.transferWalletToNfc(
        cardUid: cardUid,
        amount: amount,
        note: note,
      ),
      successMessage: 'تم تحويل الرصيد إلى بطاقة NFC بنجاح.',
    );
  }

  // ???? ???? _runAction ???? ??????? ?? ????? ???? ?????? ?????.
  Future<bool> _runAction(
    // ???? ???? Function ???? ??????? ?? ????? ???? ?????? ?????.
    Future<bool> Function() action, {
    required String successMessage,
  }) async {
    if (_isPerformingAction) {
      return false;
    }

    _isPerformingAction = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final success = await action();
      if (success) {
        await refresh();
        _errorMessage = successMessage;
        notifyListeners();
        return true;
      }
      _errorMessage = 'تعذر تنفيذ العملية.';
      notifyListeners();
      return false;
    } catch (error) {
      _errorMessage = error.toString();
      notifyListeners();
      return false;
    } finally {
      _isPerformingAction = false;
      notifyListeners();
    }
  }
}
