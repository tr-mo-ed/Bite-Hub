import 'package:flutter/material.dart';
import 'package:bitehub_app/app/core/enums/view_state.dart';
import 'package:bitehub_app/app/data/models/wallet_model.dart';
import 'package:bitehub_app/app/data/services/api_service.dart';

// ???? ???? WalletProvider ???? ???? ????? ???? ?? ???? ????.
class WalletProvider extends ChangeNotifier {
  // ??? ??????? _apiService ??? ?????? ???? ????? ????.
  final ApiService _apiService = ApiService();

  WalletModel? _wallet;
  ViewState _state = ViewState.idle;
  String? _errorMessage;

  WalletModel? get wallet => _wallet;
  ViewState get state => _state;
  String? get errorMessage => _errorMessage;

  Future<void> _handleApiError(ApiException error) async {
    if (error.statusCode == 401) {
      await _apiService.removeToken();
      _wallet = null;
      _errorMessage = 'انتهت الجلسة. يرجى تسجيل الدخول مرة أخرى.';
      return;
    }
    _errorMessage = error.message;
  }

  Future<bool> _runWalletAction({
    required Future<bool> Function() action,
    required String genericMessage,
  }) async {
    _state = ViewState.busy;
    _errorMessage = null;
    notifyListeners();

    try {
      final success = await action();
      if (!success) {
        _state = ViewState.error;
        _errorMessage = genericMessage;
        notifyListeners();
        return false;
      }

      _wallet = await _apiService.getWallet();
      _state = ViewState.retrieved;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      await _handleApiError(e);
      _state = ViewState.error;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = genericMessage;
      _state = ViewState.error;
      notifyListeners();
      return false;
    }
  }

  // ???? ???? fetchWalletData ???? ??????? ?? ????? ???? ?????? ?????.
  Future<void> fetchWalletData() async {
    _state = ViewState.busy;
    _errorMessage = null;
    notifyListeners();

    try {
      _wallet = await _apiService.getWallet();
      _state = ViewState.retrieved;
    } on ApiException catch (e) {
      await _handleApiError(e);
      _state = ViewState.error;
    } catch (e) {
      _errorMessage = 'تعذر تحميل المحفظة. تأكد من الإنترنت ثم حاول مرة أخرى.';
      _state = ViewState.error;
    }

    notifyListeners();
  }

  // ???? ???? linkWallet ???? ??????? ?? ????? ???? ?????? ?????.
  Future<bool> linkWallet(String code) async {
    return _runWalletAction(
      action: () => _apiService.linkWalletWithCode(code),
      genericMessage: 'تعذر ربط المحفظة. حاول مرة أخرى.',
    );
  }

  // ???? ???? updateLocalBalance ???? ??????? ?? ????? ???? ?????? ?????.
  void updateLocalBalance(double newBalance) {
    if (_wallet == null) return;
    _wallet = WalletModel(
      id: _wallet!.id,
      balance: newBalance,
      currency: _wallet!.currency,
      college: _wallet!.college,
      linkCode: _wallet!.linkCode,
      userFullName: _wallet!.userFullName,
      hasNfcCard: _wallet!.hasNfcCard,
      nfcCardLast4: _wallet!.nfcCardLast4,
      transactions: _wallet!.transactions,
    );
    notifyListeners();
  }

  // ???? ???? transferToWallet ???? ??????? ?? ????? ???? ?????? ?????.
  Future<bool> transferToWallet({
    required String walletCode,
    required double amount,
    String? recipientName,
    String? note,
  }) async {
    return _runWalletAction(
      action: () => _apiService.transferWallet(
        walletCode: walletCode,
        amount: amount,
        recipientName: recipientName,
        note: note,
      ),
      genericMessage: 'تعذر تنفيذ التحويل. حاول مرة أخرى.',
    );
  }
}
