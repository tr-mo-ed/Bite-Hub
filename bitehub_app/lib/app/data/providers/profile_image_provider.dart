import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ???? ???? ProfileImageProvider ???? ???? ????? ???? ?? ???? ????.
class ProfileImageProvider extends ChangeNotifier {
  static const _pathKey = '_bitehub_profile_image_path';
  static const _expiryKey = 'profile_temp_expiry';

  String? _localPath;
  DateTime? _expiresAt;

  String? get localPath {
    if (_localPath == null) return null;
    if (_expiresAt == null) {
      return _localPath;
    }
    if (DateTime.now().isAfter(_expiresAt!)) {
      clearTempImage();
      return null;
    }
    return _localPath;
  }

  // ???? ???? load ???? ??????? ?? ????? ???? ?????? ?????.
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString(_pathKey);
    final expiryMs = prefs.getInt(_expiryKey);
    if (path == null) return;

    if (expiryMs != null) {
      final expiry = DateTime.fromMillisecondsSinceEpoch(expiryMs);
      if (DateTime.now().isAfter(expiry)) {
        await clearTempImage();
        return;
      }
      _expiresAt = expiry;
    } else {
      _expiresAt = null;
    }
    _localPath = path;
    notifyListeners();
  }

  // ???? ???? setTempImage ???? ??????? ?? ????? ???? ?????? ?????.
  Future<void> setTempImage(String path, Duration duration) async {
    final prefs = await SharedPreferences.getInstance();
    final expiry = DateTime.now().add(duration);
    await prefs.setString(_pathKey, path);
    await prefs.setInt(_expiryKey, expiry.millisecondsSinceEpoch);
    _localPath = path;
    _expiresAt = expiry;
    notifyListeners();
  }

  // ???? ???? setPersistentImage ???? ??????? ?? ????? ???? ?????? ?????.
  Future<void> setPersistentImage(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pathKey, path);
    await prefs.remove(_expiryKey);
    _localPath = path;
    _expiresAt = null;
    notifyListeners();
  }

  // ???? ???? clearTempImage ???? ??????? ?? ????? ???? ?????? ?????.
  Future<void> clearTempImage() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pathKey);
    await prefs.remove(_expiryKey);
    _localPath = null;
    _expiresAt = null;
    notifyListeners();
  }
}
