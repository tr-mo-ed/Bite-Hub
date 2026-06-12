import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:bitehub_app/app/data/models/user_model.dart';
import 'package:bitehub_app/app/data/models/wallet_model.dart';
import 'package:bitehub_app/app/data/providers/auth_provider.dart';
import 'package:bitehub_app/app/data/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ???? ???? ProfileV2Controller ???? ???? ????? ???? ?? ???? ????.
class ProfileV2Controller extends ChangeNotifier {
  ProfileV2Controller({
    required AuthProvider authProvider,
    ApiService? apiService,
    ImagePicker? imagePicker,
  })  : _authProvider = authProvider,
        _apiService = apiService ?? ApiService(),
        _imagePicker = imagePicker ?? ImagePicker();

  // ??? ??????? _authProvider ??? ?????? ???? ????? ????.
  final AuthProvider _authProvider;
  // ??? ??????? _apiService ??? ?????? ???? ????? ????.
  final ApiService _apiService;
  // ??? ??????? _imagePicker ??? ?????? ???? ????? ????.
  final ImagePicker _imagePicker;

  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;
  User? _user;
  WalletModel? _wallet;
  String? _localImagePath;

  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get errorMessage => _errorMessage;
  User? get user => _user;
  WalletModel? get wallet => _wallet;
  String? get localImagePath => _localImagePath;

  // ???? ???? initialize ???? ??????? ?? ????? ???? ?????? ?????.
  Future<void> initialize() async {
    await _loadPersistedImage();
    await refresh();
  }

  // ???? ???? refresh ???? ??????? ?? ????? ???? ?????? ?????.
  Future<void> refresh() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _user = await _apiService.getUserProfile();
      try {
        _wallet = await _apiService.getWallet();
      } catch (_) {
        _wallet = null;
      }
    } catch (error) {
      _errorMessage = error.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ???? ???? pickLocalImage ???? ??????? ?? ????? ???? ?????? ?????.
  Future<bool> pickLocalImage() async {
    final image = await _imagePicker.pickImage(source: ImageSource.gallery);
    if (image == null) {
      return false;
    }

    final directory = await getApplicationDocumentsDirectory();
    final extension =
        image.path.contains('.') ? image.path.split('.').last : 'jpg';
    final targetPath =
        '${directory.path}/profile_${DateTime.now().millisecondsSinceEpoch}.$extension';
    final savedImage = await File(image.path).copy(targetPath);

    _localImagePath = savedImage.path;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('profile_image_path', savedImage.path);
    notifyListeners();

    final currentUser = _user;
    if (currentUser == null) {
      return false;
    }
    return saveProfile(
      fullName: currentUser.fullName,
      email: currentUser.email,
      phoneNumber: currentUser.phoneNumber,
    );
  }

  // ???? ???? saveProfile ???? ??????? ?? ????? ???? ?????? ?????.
  Future<bool> saveProfile({
    required String fullName,
    required String email,
    required String phoneNumber,
  }) async {
    if (_isSaving) {
      return false;
    }

    final trimmedName = fullName.trim();
    if (trimmedName.isEmpty) {
      _errorMessage = 'الاسم مطلوب.';
      notifyListeners();
      return false;
    }
    final trimmedEmail = email.trim();
    if (trimmedEmail.isEmpty) {
      _errorMessage = 'البريد الإلكتروني مطلوب.';
      notifyListeners();
      return false;
    }
    final trimmedPhone = phoneNumber.trim();
    if (trimmedPhone.isEmpty) {
      _errorMessage = 'رقم الهاتف مطلوب.';
      notifyListeners();
      return false;
    }

    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _user = await _apiService.updateUserProfileMultipart(
        fullName: trimmedName,
        email: trimmedEmail,
        phoneNumber: trimmedPhone,
        imagePath: _localImagePath,
      );
      final prefs = await SharedPreferences.getInstance();
      if ((_user?.profileImage ?? '').trim().isNotEmpty) {
        _localImagePath = null;
        await prefs.remove('profile_image_path');
      } else if (_localImagePath != null && _localImagePath!.isNotEmpty) {
        await prefs.setString('profile_image_path', _localImagePath!);
      }
      await _authProvider.fetchUserProfile();
      return true;
    } catch (error) {
      _errorMessage = error.toString();
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  // ???? ???? logout ???? ??????? ?? ????? ???? ?????? ?????.
  Future<void> logout() async {
    await _authProvider.logout();
  }

  Future<bool> deleteAccount() async {
    if (_isSaving) {
      return false;
    }

    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _authProvider.deleteAccount();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('profile_image_path');
      _localImagePath = null;
      return true;
    } catch (error) {
      _errorMessage = error.toString();
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  // ???? ???? _loadPersistedImage ???? ??????? ?? ????? ???? ?????? ?????.
  Future<void> _loadPersistedImage() async {
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString('profile_image_path');
    if (path == null || path.isEmpty) {
      return;
    }
    if (await File(path).exists()) {
      _localImagePath = path;
    }
  }
}
