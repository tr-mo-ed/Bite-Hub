import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
// ✅ المسارات الصحيحة
import 'package:bitehub_app/app/data/models/user_model.dart';
import 'package:bitehub_app/app/data/services/api_service.dart';

enum AuthStatus {
  uninitialized,
  unauthenticated,
  authenticating,
  authenticated,
}

// ???? ???? AuthProvider ???? ???? ????? ???? ?? ???? ????.
class AuthProvider with ChangeNotifier {
  // ??? ??????? _apiService ??? ?????? ???? ????? ????.
  final ApiService _apiService = ApiService();

  AuthStatus _status = AuthStatus.uninitialized;
  User? _currentUser;
  String? _errorMessage;

  AuthStatus get status => _status;
  User? get currentUser => _currentUser;
  String? get errorMessage => _errorMessage;
  bool get isLoggedIn => _status == AuthStatus.authenticated;
  bool get hasCafeDashboardAccess =>
      _currentUser?.hasCafeDashboardAccess ?? false;

  AuthProvider() {
    _checkLoginStatus();
  }

  // ???? ???? _checkLoginStatus ???? ??????? ?? ????? ???? ?????? ?????.
  Future<void> _checkLoginStatus() async {
    final token = await _apiService.getToken();
    if (token != null) {
      _status = AuthStatus.authenticated;
      notifyListeners();
      await fetchUserProfile();
    } else {
      _status = AuthStatus.unauthenticated;
      notifyListeners();
    }
  }

  // ???? ???? fetchUserProfile ???? ??????? ?? ????? ???? ?????? ?????.
  Future<void> fetchUserProfile() async {
    try {
      if (_status != AuthStatus.authenticated) {
        _status = AuthStatus.authenticating;
        notifyListeners();
      }
      _currentUser = await _apiService.getUserProfile();
      await _persistUserData(_currentUser);

      _status = AuthStatus.authenticated;
      notifyListeners();
    } on ApiException catch (e) {
      if (e.statusCode == 401 || e.statusCode == 403) {
        await logout();
        _errorMessage = 'انتهت صلاحية الجلسة، يرجى تسجيل الدخول مجدداً';
        notifyListeners();
        return;
      }
      _errorMessage = e.message;
      if (_status != AuthStatus.authenticated) {
        _status = AuthStatus.authenticated;
      }
      notifyListeners();
    } catch (e) {
      _errorMessage = 'تعذر تحميل بيانات الحساب. حاول مرة أخرى.';
      if (_status != AuthStatus.authenticated) {
        _status = AuthStatus.authenticated;
      }
      notifyListeners();
    }
  }

  // ???? ???? login ???? ??????? ?? ????? ???? ?????? ?????.
  Future<bool> login(String email, String password) async {
    _status = AuthStatus.authenticating;
    _errorMessage = null;
    notifyListeners();

    try {
      await _apiService.login(email, password);
      // بعد تسجيل الدخول بنجاح، نجلب بيانات المستخدم
      await fetchUserProfile();
      return true;
    } catch (e) {
      _status = AuthStatus.unauthenticated;
      // تنظيف رسالة الخطأ لتظهر بشكل جميل للمستخدم
      _errorMessage = _cleanError(e);
      notifyListeners();
      return false;
    }
  }

  Future<EmailLoginChallenge?> requestEmailLoginCode(String email) async {
    _status = AuthStatus.authenticating;
    _errorMessage = null;
    notifyListeners();

    try {
      final challenge = await _apiService.requestEmailLoginCode(email);
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return challenge;
    } catch (error) {
      _status = AuthStatus.unauthenticated;
      _errorMessage = _cleanError(error);
      notifyListeners();
      return null;
    }
  }

  Future<bool> verifyEmailLoginCode({
    required String email,
    required String requestId,
    required String code,
  }) async {
    _status = AuthStatus.authenticating;
    _errorMessage = null;
    notifyListeners();

    try {
      await _apiService.verifyEmailLoginCode(
        email: email,
        requestId: requestId,
        code: code,
      );
      await fetchUserProfile();
      return true;
    } catch (error) {
      _status = AuthStatus.unauthenticated;
      _errorMessage = _cleanError(error);
      notifyListeners();
      return false;
    }
  }

  // ???? ???? signup ???? ??????? ?? ????? ???? ?????? ?????.
  Future<EmailLoginChallenge?> signup(
      String fullName, String email, String phone, String password) async {
    _status = AuthStatus.authenticating;
    _errorMessage = null;
    notifyListeners();

    try {
      final challenge =
          await _apiService.signup(fullName, email, phone, password);
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return challenge;
    } catch (e) {
      _status = AuthStatus.unauthenticated;
      _errorMessage = _cleanError(e);
      notifyListeners();
      return null;
    }
  }

  Future<bool> verifySignupCode({
    required String email,
    required String requestId,
    required String code,
  }) async {
    _status = AuthStatus.authenticating;
    _errorMessage = null;
    notifyListeners();

    try {
      await _apiService.verifySignupCode(
        email: email,
        requestId: requestId,
        code: code,
      );
      await fetchUserProfile();
      return true;
    } catch (error) {
      _status = AuthStatus.unauthenticated;
      _errorMessage = _cleanError(error);
      notifyListeners();
      return false;
    }
  }

  // ???? ???? logout ???? ??????? ?? ????? ???? ?????? ?????.
  Future<void> logout() async {
    await _apiService.removeToken();
    await _clearPersistedUserData();
    _currentUser = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  Future<void> deleteAccount() async {
    await _apiService.deleteCurrentUser();
    await _clearPersistedUserData();
    _currentUser = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  // ???? ???? _persistUserData ???? ??????? ?? ????? ???? ?????? ?????.
  Future<void> _persistUserData(User? user) async {
    if (user == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_name', user.fullName);
    await prefs.setString('user_email', user.email);
    if (user.profileImage != null && user.profileImage!.isNotEmpty) {
      await prefs.setString('user_image', user.profileImage!);
    } else {
      await prefs.remove('user_image');
    }
  }

  // ???? ???? _clearPersistedUserData ???? ??????? ?? ????? ???? ?????? ?????.
  Future<void> _clearPersistedUserData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_name');
    await prefs.remove('user_email');
    await prefs.remove('user_image');
  }

  String _cleanError(Object error) {
    if (error is ApiException) {
      return error.message;
    }
    return 'تعذر تنفيذ العملية. تأكد من الإنترنت ثم حاول مرة أخرى.';
  }
}
