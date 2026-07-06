import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bitehub_app/app/data/models/college_model.dart';
import 'package:bitehub_app/app/data/models/notification_model.dart';
import 'package:bitehub_app/app/data/models/nfc_card_model.dart';
import 'package:bitehub_app/app/data/models/order_model.dart';
import 'package:bitehub_app/app/data/models/product_model.dart';
import 'package:bitehub_app/app/data/models/user_model.dart' as app_user;
import 'package:bitehub_app/app/data/models/wallet_model.dart';

// ???? ???? ApiException ???? ???? ????? ???? ?? ???? ????.
class ApiException implements Exception {
  // ??? ??????? message ??? ?????? ???? ????? ????.
  final String message;
  // ??? ??????? statusCode ??? ?????? ???? ????? ????.
  final int? statusCode;

  ApiException(this.message, {this.statusCode});

  @override
  // ???? ???? toString ???? ??????? ?? ????? ???? ?????? ?????.
  String toString() => message;
}

class EmailLoginChallenge {
  const EmailLoginChallenge({
    required this.requestId,
    required this.maskedEmail,
    required this.expiresIn,
    required this.resendAfter,
    this.debugCode,
  });

  final String requestId;
  final String maskedEmail;
  final int expiresIn;
  final int resendAfter;
  final String? debugCode;

  factory EmailLoginChallenge.fromJson(Map<String, dynamic> json) {
    return EmailLoginChallenge(
      requestId: (json['request_id'] ?? '').toString(),
      maskedEmail: (json['masked_email'] ?? '').toString(),
      expiresIn: int.tryParse('${json['expires_in']}') ?? 600,
      resendAfter: int.tryParse('${json['resend_after']}') ?? 60,
      debugCode: json['debug_code']?.toString(),
    );
  }
}

bool _readBool(dynamic value, {bool defaultValue = true}) {
  if (value == null) return defaultValue;
  if (value is bool) return value;
  final normalized = value.toString().trim().toLowerCase();
  if (normalized == 'true' || normalized == '1' || normalized == 'yes') {
    return true;
  }
  if (normalized == 'false' || normalized == '0' || normalized == 'no') {
    return false;
  }
  return defaultValue;
}

class CafeOrderStatus {
  const CafeOrderStatus({
    required this.id,
    required this.name,
    required this.code,
    required this.isActive,
    required this.isAcceptingOrders,
  });

  final int id;
  final String name;
  final String code;
  final bool isActive;
  final bool isAcceptingOrders;

  bool get canAcceptOrders => isActive && isAcceptingOrders;

  factory CafeOrderStatus.fromJson(Map<String, dynamic> json) {
    final cafe = json['cafe'];
    final map = cafe is Map<String, dynamic> ? cafe : json;
    return CafeOrderStatus(
      id: map['id'] is int
          ? map['id'] as int
          : int.tryParse('${map['id']}') ?? 0,
      name: (map['name'] ?? '').toString(),
      code: (map['code'] ?? '').toString(),
      isActive: _readBool(map['is_active']),
      isAcceptingOrders: _readBool(map['is_accepting_orders']),
    );
  }
}

// ???? ???? ApiService ???? ???? ????? ???? ?? ???? ????.
class ApiService {
  // ??? ??????? baseUrl ??? ?????? ???? ????? ????.
  static const String baseUrl = String.fromEnvironment(
    'BITE_HUB_API_BASE_URL',
    defaultValue: 'https://fooood.pythonanywhere.com',
  );
  // ??? ??????? _tokenKey ??? ?????? ???? ????? ????.
  static const String _tokenKey = 'auth_token';
  // ??? ??????? _refreshTokenKey ??? ?????? ???? ????? ????.
  static const String _refreshTokenKey = 'refresh_token';
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  Future<String?> _readSecret(String key) async {
    final secureValue = await _secureStorage.read(key: key);
    if (secureValue != null && secureValue.isNotEmpty) {
      return secureValue;
    }

    final prefs = await SharedPreferences.getInstance();
    final legacyValue = prefs.getString(key);
    if (legacyValue != null && legacyValue.isNotEmpty) {
      await _secureStorage.write(key: key, value: legacyValue);
      await prefs.remove(key);
    }
    return legacyValue;
  }

  Future<void> _writeSecret(String key, String value) async {
    await _secureStorage.write(key: key, value: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
  }

  Future<void> _deleteSecret(String key) async {
    await _secureStorage.delete(key: key);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
  }

  // ???? ???? getToken ???? ??????? ?? ????? ???? ?????? ?????.
  Future<String?> getToken() async {
    return _readSecret(_tokenKey);
  }

  // ???? ???? saveToken ???? ??????? ?? ????? ???? ?????? ?????.
  Future<void> saveToken(String token) async {
    await _writeSecret(_tokenKey, token);
  }

  // ???? ???? saveRefreshToken ???? ??????? ?? ????? ???? ?????? ?????.
  Future<void> saveRefreshToken(String token) async {
    await _writeSecret(_refreshTokenKey, token);
  }

  // ???? ???? removeToken ???? ??????? ?? ????? ???? ?????? ?????.
  Future<void> removeToken() async {
    await _deleteSecret(_tokenKey);
    await _deleteSecret(_refreshTokenKey);
  }

  // ???? ???? getRefreshToken ???? ??????? ?? ????? ???? ?????? ?????.
  Future<String?> getRefreshToken() async {
    return _readSecret(_refreshTokenKey);
  }

  // ???? ???? _buildAuthorizationValue ???? ??????? ?? ????? ???? ?????? ?????.
  String _buildAuthorizationValue(String token) {
    final normalized = token.trim();
    final jwtParts = normalized.split('.');
    final looksLikeJwt =
        jwtParts.length == 3 && jwtParts.every((part) => part.isNotEmpty);
    return looksLikeJwt ? 'Bearer $normalized' : 'Token $normalized';
  }

  // ???? ???? _headers ???? ??????? ?? ????? ???? ?????? ?????.
  Future<Map<String, String>> _headers({bool authRequired = false}) async {
    final headers = <String, String>{
      'Content-Type': 'application/json; charset=UTF-8',
      'Accept': 'application/json',
    };

    if (authRequired) {
      final token = await getToken();
      if (token == null || token.isEmpty) {
        throw ApiException('يرجى تسجيل الدخول من جديد.', statusCode: 401);
      }
      headers['Authorization'] = _buildAuthorizationValue(token);
    }

    return headers;
  }

  // ???? ???? _multipartHeaders ???? ??????? ?? ????? ???? ?????? ?????.
  Future<Map<String, String>> _multipartHeaders() async {
    final token = await getToken();
    if (token == null || token.isEmpty) {
      throw ApiException('يرجى تسجيل الدخول من جديد.', statusCode: 401);
    }
    return {
      'Accept': 'application/json',
      'Authorization': _buildAuthorizationValue(token),
    };
  }

  // ???? ???? _tryRefreshToken ???? ??????? ?? ????? ???? ?????? ?????.
  Future<bool> _tryRefreshToken() async {
    final refreshToken = await getRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      return false;
    }

    final url = Uri.parse('$baseUrl/api/v2/app/auth/refresh/');
    try {
      final response = await http.post(
        url,
        headers: const {
          'Content-Type': 'application/json; charset=UTF-8',
          'Accept': 'application/json',
        },
        body: json.encode({'refresh': refreshToken}),
      );
      final data = _decodeBody(response);
      if (response.statusCode == 200 && data is Map) {
        final accessToken = data['access']?.toString();
        if (accessToken != null && accessToken.isNotEmpty) {
          await saveToken(accessToken);
          final rotatedRefreshToken = data['refresh']?.toString();
          if (rotatedRefreshToken != null && rotatedRefreshToken.isNotEmpty) {
            await saveRefreshToken(rotatedRefreshToken);
          }
          return true;
        }
      }
    } catch (_) {
      // JWT refresh is optional until the backend refresh endpoint is enabled.
    }
    return false;
  }

  // ???? ???? _sendWithAuthRetry ???? ??????? ?? ????? ???? ?????? ?????.
  Future<http.Response> _sendWithAuthRetry(
    // ???? ???? Function ???? ??????? ?? ????? ???? ?????? ?????.
    Future<http.Response> Function(Map<String, String> headers) requestBuilder,
  ) async {
    var headers = await _headers(authRequired: true);
    var response = await requestBuilder(headers);
    if (response.statusCode != 401 && response.statusCode != 403) {
      return response;
    }

    final refreshed = await _tryRefreshToken();
    if (!refreshed) {
      return response;
    }

    headers = await _headers(authRequired: true);
    return requestBuilder(headers);
  }

  // ???? ???? _decodeBody ???? ??????? ?? ????? ???? ?????? ?????.
  dynamic _decodeBody(http.Response response) {
    if (response.bodyBytes.isEmpty) {
      return null;
    }
    final bodyText = utf8.decode(response.bodyBytes);
    if (bodyText.isEmpty) {
      return null;
    }
    try {
      return json.decode(bodyText);
    } catch (_) {
      return bodyText;
    }
  }

  // ???? ???? _extractMessage ???? ??????? ?? ????? ???? ?????? ?????.
  String _friendlyServerMessage(String message, {int? statusCode}) {
    final normalized = message.trim();
    final lower = normalized.toLowerCase();

    if (statusCode == 401 ||
        statusCode == 403 ||
        lower.contains('not authenticated') ||
        lower.contains('authentication') ||
        lower.contains('credentials')) {
      return 'بيانات الدخول غير صحيحة أو انتهت الجلسة.';
    }
    if (lower.contains('network error') ||
        lower.contains('socketexception') ||
        lower.contains('failed host lookup') ||
        lower.contains('connection refused') ||
        lower.contains('handshakeexception') ||
        lower.contains('xmlhttprequest')) {
      return 'تعذر الاتصال بالخادم. تأكد من الإنترنت ثم حاول مرة أخرى.';
    }
    if (lower.contains('<!doctype html') ||
        lower.contains('<html') ||
        lower.contains('page not found at')) {
      return 'الخدمة المطلوبة غير متاحة على الخادم. حدّث التطبيق والخادم ثم حاول مجددًا.';
    }
    if (lower.contains('account was not found')) {
      return 'لا يوجد حساب بهذه البيانات.';
    }
    if (lower.contains('verification email could not be sent') ||
        lower.contains('brevo is not configured')) {
      return 'تعذر إرسال رمز التحقق إلى البريد. حاول بعد قليل.';
    }
    if (lower.contains('please wait before requesting another code')) {
      return 'انتظر قليلاً قبل طلب رمز جديد.';
    }
    if (lower.contains('too many login codes requested') ||
        lower.contains('too many verification codes requested')) {
      return 'تم طلب رموز كثيرة. حاول مرة أخرى بعد ساعة.';
    }
    if (lower.contains('verification code has expired') ||
        lower.contains('invalid or expired verification code')) {
      return 'انتهت صلاحية الرمز. اطلب رمزاً جديداً.';
    }
    if (lower.contains('invalid verification code')) {
      return 'رمز التحقق غير صحيح.';
    }
    if (lower.contains('too many invalid attempts')) {
      return 'تم تجاوز عدد المحاولات. اطلب رمزاً جديداً.';
    }
    if (lower.contains('invalid login') ||
        lower.contains('invalid credentials')) {
      return 'البريد الإلكتروني أو رقم الهاتف أو كلمة السر غير صحيحة.';
    }
    if (lower.contains('phone number is already registered') ||
        normalized.contains('رقم الهاتف مسجل')) {
      return 'رقم الهاتف مسجل مسبقاً.';
    }
    if (lower.contains('email') && lower.contains('already') ||
        lower.contains('unique constraint') && lower.contains('email') ||
        normalized.contains('البريد الإلكتروني مسجل')) {
      return 'البريد الإلكتروني مسجل مسبقاً.';
    }
    if (lower.contains('invalid libyan phone')) {
      return 'رقم الهاتف غير صحيح. استخدم رقم ليبي مثل 09XXXXXXXX.';
    }
    if (lower.contains('password is required')) {
      return 'كلمة السر مطلوبة.';
    }
    if (lower.contains('password must be at least 6 characters')) {
      return 'يجب أن تكون كلمة السر 6 أحرف على الأقل.';
    }
    if (normalized.contains('اسم الطالب مطلوب') ||
        lower.contains('full_name') ||
        lower.contains('full name')) {
      return 'اسم الطالب مطلوب.';
    }
    if (lower.contains('insufficient wallet balance')) {
      return 'رصيد المحفظة غير كافٍ لإتمام العملية.';
    }
    if (lower.contains('wallet top-up is not enabled') ||
        lower.contains('wallet top-up is only available')) {
      return 'شحن المحفظة يتم من لوحة المقهى أو المشرف حالياً.';
    }
    if (lower.contains('wallet payment is only available')) {
      return 'الدفع من المحفظة يتم عبر الطلب أو منظومة المقهى فقط.';
    }
    if (lower.contains('some products do not belong')) {
      return 'لا يمكن طلب منتجات من أكثر من مقهى في نفس الطلب.';
    }
    if (lower.contains('out of stock') || lower.contains('stock')) {
      return 'أحد الأصناف غير متوفر حالياً.';
    }
    if (statusCode != null && statusCode >= 500) {
      return 'حدث خلل في الخادم. حاول بعد قليل.';
    }
    if (normalized.isEmpty ||
        normalized.startsWith('Exception:') ||
        normalized.startsWith('ApiException')) {
      return 'تعذر تنفيذ العملية. حاول مرة أخرى.';
    }
    return normalized;
  }

  ApiException _networkException(Object error) {
    return ApiException(
      _friendlyServerMessage('Network error: $error'),
    );
  }

  String _extractMessage(dynamic body,
      {String fallback = 'تعذر تنفيذ الطلب.'}) {
    if (body is Map) {
      for (final key in ['detail', 'error', 'message']) {
        final value = body[key];
        if (value != null && value.toString().trim().isNotEmpty) {
          return _friendlyServerMessage(value.toString());
        }
      }
    }
    if (body is String && body.trim().isNotEmpty) {
      return _friendlyServerMessage(body);
    }
    return fallback;
  }

  // ???? ???? _buildException ???? ??????? ?? ????? ???? ?????? ?????.
  ApiException _buildException(http.Response response, dynamic body) {
    return ApiException(
      _extractMessage(body,
          fallback:
              _friendlyServerMessage('', statusCode: response.statusCode)),
      statusCode: response.statusCode,
    );
  }

  String _absoluteMediaUrl(String? value) {
    final path = (value ?? '').trim();
    if (path.isEmpty ||
        path.startsWith('http://') ||
        path.startsWith('https://')) {
      return path;
    }
    final normalized = path.startsWith('/') ? path : '/$path';
    return '$baseUrl$normalized';
  }

  Map<String, dynamic> _normalizeProductPayload(Map<String, dynamic> map) {
    map['image_url'] = _absoluteMediaUrl(
      (map['image_url'] ?? map['image'] ?? map['imageUrl'])?.toString(),
    );
    return map;
  }

  Map<String, dynamic> _normalizeOrderPayload(Map<String, dynamic> map) {
    map['cafe_logo'] = _absoluteMediaUrl(
      (map['cafe_logo'] ?? map['image_url'])?.toString(),
    );
    final items = map['items'];
    if (items is List) {
      map['items'] = items.map((raw) {
        if (raw is! Map) {
          return raw;
        }
        final item = Map<String, dynamic>.from(raw);
        item['product_image'] = _absoluteMediaUrl(
          (item['product_image'] ?? item['image_url'] ?? item['image'])
              ?.toString(),
        );
        return item;
      }).toList();
    }
    return map;
  }

  // ???? ???? login ???? ??????? ?? ????? ???? ?????? ?????.
  Future<Map<String, dynamic>> login(String identifier, String password) async {
    final url = Uri.parse('$baseUrl/api/v2/app/auth/login/');
    final normalizedIdentifier = identifier.trim();
    final payload = <String, dynamic>{
      'identifier': normalizedIdentifier,
      if (normalizedIdentifier.contains('@')) 'email': normalizedIdentifier,
      if (!normalizedIdentifier.contains('@'))
        'phone_number': normalizedIdentifier,
      'password': password,
    };

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Accept': 'application/json',
        },
        body: json.encode(payload),
      );
      final data = _decodeBody(response);

      if (response.statusCode == 200) {
        if (data is Map) {
          final accessToken =
              data['access']?.toString() ?? data['token']?.toString();
          if (accessToken != null && accessToken.isNotEmpty) {
            await saveToken(accessToken);
          }
        }
        if (data is Map && data['refresh'] != null) {
          await saveRefreshToken(data['refresh'].toString());
        }
        return data is Map
            ? Map<String, dynamic>.from(data)
            : <String, dynamic>{};
      }

      throw _buildException(response, data);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw _networkException(e);
    }
  }

  Future<EmailLoginChallenge> requestEmailLoginCode(String email) async {
    final url = Uri.parse('$baseUrl/api/v2/app/auth/email-code/request/');

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Accept': 'application/json',
        },
        body: json.encode({'email': email.trim().toLowerCase()}),
      );
      final data = _decodeBody(response);
      if (response.statusCode == 200 && data is Map) {
        return EmailLoginChallenge.fromJson(
          Map<String, dynamic>.from(data),
        );
      }
      throw _buildException(response, data);
    } on ApiException {
      rethrow;
    } catch (error) {
      throw _networkException(error);
    }
  }

  Future<Map<String, dynamic>> verifyEmailLoginCode({
    required String email,
    required String requestId,
    required String code,
  }) async {
    final url = Uri.parse('$baseUrl/api/v2/app/auth/email-code/verify/');

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Accept': 'application/json',
        },
        body: json.encode({
          'email': email.trim().toLowerCase(),
          'request_id': requestId,
          'code': code.trim(),
        }),
      );
      final data = _decodeBody(response);
      if (response.statusCode == 200 && data is Map) {
        final authData = Map<String, dynamic>.from(data);
        final accessToken =
            authData['access']?.toString() ?? authData['token']?.toString();
        if (accessToken != null && accessToken.isNotEmpty) {
          await saveToken(accessToken);
        }
        final refreshToken = authData['refresh']?.toString();
        if (refreshToken != null && refreshToken.isNotEmpty) {
          await saveRefreshToken(refreshToken);
        }
        return authData;
      }
      throw _buildException(response, data);
    } on ApiException {
      rethrow;
    } catch (error) {
      throw _networkException(error);
    }
  }

  // ???? ???? signup ???? ??????? ?? ????? ???? ?????? ?????.
  Future<EmailLoginChallenge> signup(
    String fullName,
    String email,
    String phone,
    String password,
  ) async {
    final url = Uri.parse('$baseUrl/api/v2/app/auth/signup/');

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Accept': 'application/json',
        },
        body: json.encode({
          'full_name': fullName,
          'email': email,
          'phone_number': phone,
          'password': password,
        }),
      );
      final data = _decodeBody(response);

      if (response.statusCode == 202 && data is Map) {
        return EmailLoginChallenge.fromJson(
          Map<String, dynamic>.from(data),
        );
      }

      throw _buildException(response, data);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw _networkException(e);
    }
  }

  Future<Map<String, dynamic>> verifySignupCode({
    required String email,
    required String requestId,
    required String code,
  }) async {
    final url = Uri.parse('$baseUrl/api/v2/app/auth/signup/verify/');

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Accept': 'application/json',
        },
        body: json.encode({
          'email': email.trim().toLowerCase(),
          'request_id': requestId,
          'code': code.trim(),
        }),
      );
      final data = _decodeBody(response);
      if (response.statusCode == 201 && data is Map) {
        final authData = Map<String, dynamic>.from(data);
        final accessToken =
            authData['access']?.toString() ?? authData['token']?.toString();
        if (accessToken != null && accessToken.isNotEmpty) {
          await saveToken(accessToken);
        }
        final refreshToken = authData['refresh']?.toString();
        if (refreshToken != null && refreshToken.isNotEmpty) {
          await saveRefreshToken(refreshToken);
        }
        return authData;
      }
      throw _buildException(response, data);
    } on ApiException {
      rethrow;
    } catch (error) {
      throw _networkException(error);
    }
  }

  // ???? ???? getUserProfile ???? ??????? ?? ????? ???? ?????? ?????.
  Future<app_user.User> getUserProfile() async {
    final url = Uri.parse('$baseUrl/api/v2/app/user/');

    try {
      final response = await _sendWithAuthRetry(
          (headers) => http.get(url, headers: headers));
      final data = _decodeBody(response);

      if (response.statusCode == 200 && data is Map<String, dynamic>) {
        return app_user.User.fromJson(data);
      }

      throw _buildException(response, data);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw _networkException(e);
    }
  }

  Future<CafeOrderStatus> getManagedCafeOrderStatus() async {
    final url = Uri.parse('$baseUrl/api/v2/cafe/status/');

    try {
      final response = await _sendWithAuthRetry(
        (headers) => http.get(url, headers: headers),
      );
      final data = _decodeBody(response);

      if (response.statusCode == 200 && data is Map<String, dynamic>) {
        return CafeOrderStatus.fromJson(data);
      }

      throw _buildException(response, data);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw _networkException(e);
    }
  }

  Future<CafeOrderStatus> setManagedCafeAcceptingOrders(
    bool isAcceptingOrders,
  ) async {
    final url = Uri.parse('$baseUrl/api/v2/cafe/status/');

    try {
      final response = await _sendWithAuthRetry(
        (headers) => http.patch(
          url,
          headers: headers,
          body: json.encode({
            'is_accepting_orders': isAcceptingOrders,
          }),
        ),
      );
      final data = _decodeBody(response);

      if (response.statusCode == 200 && data is Map<String, dynamic>) {
        return CafeOrderStatus.fromJson(data);
      }

      throw _buildException(response, data);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw _networkException(e);
    }
  }

  // ???? ???? getCafes ???? ??????? ?? ????? ???? ?????? ?????.
  Future<List<CollegeModel>> getCafes() async {
    final url = Uri.parse('$baseUrl/api/v2/app/cafes/');

    try {
      final response = await http.get(url, headers: await _headers());
      final data = _decodeBody(response);

      if (response.statusCode == 200 && data is List) {
        return data.map((raw) {
          final map = Map<String, dynamic>.from(raw as Map);
          map['image'] = _absoluteMediaUrl(map['image']?.toString());
          return CollegeModel.fromJson(map);
        }).toList();
      }

      throw _buildException(response, data);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw _networkException(e);
    }
  }

  // ???? ???? getProducts ???? ??????? ?? ????? ???? ?????? ?????.
  Future<List<ProductModel>> getProducts({String? cafeId}) async {
    final normalizedCafeId = (cafeId ?? '').trim();
    final url = Uri.parse('$baseUrl/api/v2/app/products/').replace(
      queryParameters:
          normalizedCafeId.isEmpty ? null : {'cafe_id': normalizedCafeId},
    );

    try {
      final response = await http.get(url, headers: await _headers());
      final data = _decodeBody(response);

      if (response.statusCode == 200 && data is List) {
        return data.map((raw) {
          final map = Map<String, dynamic>.from(raw as Map);
          return ProductModel.fromJson(_normalizeProductPayload(map));
        }).toList();
      }

      throw _buildException(response, data);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw _networkException(e);
    }
  }

  // ???? ???? getWallet ???? ??????? ?? ????? ???? ?????? ?????.
  Future<WalletModel> getWallet() async {
    final url = Uri.parse('$baseUrl/api/v2/app/wallet/');

    try {
      final response = await _sendWithAuthRetry(
          (headers) => http.get(url, headers: headers));
      final data = _decodeBody(response);

      if (response.statusCode == 200 && data is Map<String, dynamic>) {
        return WalletModel.fromJson(data);
      }

      throw _buildException(response, data);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw _networkException(e);
    }
  }

  Future<bool> respondWalletDebitRequest({
    required String requestId,
    required bool approve,
  }) async {
    final url = Uri.parse(
      '$baseUrl/api/v2/app/wallet/debit-requests/$requestId/respond/',
    );

    try {
      final response = await _sendWithAuthRetry(
        (headers) => http.post(
          url,
          headers: headers,
          body: json.encode({
            'decision': approve ? 'approve' : 'reject',
          }),
        ),
      );
      final data = _decodeBody(response);
      if (response.statusCode == 200 &&
          data is Map &&
          data['success'] == true) {
        return true;
      }
      throw _buildException(response, data);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw _networkException(e);
    }
  }

  // ???? ???? linkWalletWithCode ???? ??????? ?? ????? ???? ?????? ?????.
  Future<bool> linkWalletWithCode(String linkCode) async {
    final url = Uri.parse('$baseUrl/api/v2/app/wallet/link/');

    try {
      final response = await _sendWithAuthRetry(
        (headers) => http.post(
          url,
          headers: headers,
          body: json.encode({'link_code': linkCode}),
        ),
      );
      final data = _decodeBody(response);

      if (response.statusCode == 200) {
        return true;
      }

      throw _buildException(response, data);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw _networkException(e);
    }
  }

  Future<bool> linkNfcCard(String cardUid) async {
    final url = Uri.parse('$baseUrl/api/v2/app/wallet/nfc/link/');

    try {
      final response = await _sendWithAuthRetry(
        (headers) => http.post(
          url,
          headers: headers,
          body: json.encode({'card_uid': cardUid}),
        ),
      );
      final data = _decodeBody(response);
      if (response.statusCode == 200 &&
          data is Map &&
          data['success'] == true) {
        return true;
      }
      throw _buildException(response, data);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw _networkException(e);
    }
  }

  Future<NfcCardModel> lookupNfcCard(String cardUid) async {
    final url = Uri.parse('$baseUrl/api/v2/app/wallet/nfc/lookup/');

    try {
      final response = await _sendWithAuthRetry(
        (headers) => http.post(
          url,
          headers: headers,
          body: json.encode({'card_uid': cardUid}),
        ),
      );
      final data = _decodeBody(response);
      if (response.statusCode == 200 && data is Map) {
        final card = data['card'];
        if (card is Map) {
          return NfcCardModel.fromJson(Map<String, dynamic>.from(card));
        }
      }
      throw _buildException(response, data);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw _networkException(e);
    }
  }

  Future<bool> transferWalletToNfc({
    required String cardUid,
    required double amount,
    String? note,
  }) async {
    final url = Uri.parse('$baseUrl/api/v2/app/wallet/nfc/transfer/');

    try {
      final response = await _sendWithAuthRetry(
        (headers) => http.post(
          url,
          headers: headers,
          body: json.encode({
            'card_uid': cardUid,
            'amount': amount,
            if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
          }),
        ),
      );
      final data = _decodeBody(response);
      if (response.statusCode == 200 &&
          data is Map &&
          data['success'] == true) {
        return true;
      }
      throw _buildException(response, data);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw _networkException(e);
    }
  }

  // ???? ???? updateUserProfile ???? ??????? ?? ????? ???? ?????? ?????.
  Future<app_user.User> updateUserProfile({
    required String fullName,
    String? email,
    String? phoneNumber,
    String? profileImageUrl,
  }) async {
    final url = Uri.parse('$baseUrl/api/v2/app/user/');
    final payload = <String, dynamic>{
      'full_name': fullName.trim(),
      if (email != null) 'email': email.trim(),
      if (phoneNumber != null) 'phone_number': phoneNumber.trim(),
      if (profileImageUrl != null) 'profile_image_url': profileImageUrl.trim(),
    };

    try {
      final response = await _sendWithAuthRetry(
        (headers) => http.patch(
          url,
          headers: headers,
          body: json.encode(payload),
        ),
      );
      final data = _decodeBody(response);

      if (response.statusCode == 200 && data is Map<String, dynamic>) {
        return app_user.User.fromJson(data);
      }

      throw _buildException(response, data);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw _networkException(e);
    }
  }

  // ???? ???? updateUserProfileMultipart ???? ??????? ?? ????? ???? ?????? ?????.
  Future<app_user.User> updateUserProfileMultipart({
    required String fullName,
    String? email,
    String? phoneNumber,
    String? imagePath,
  }) async {
    final url = Uri.parse('$baseUrl/api/v2/app/user/');
    final request = http.MultipartRequest('PATCH', url);
    request.headers.addAll(await _multipartHeaders());
    request.fields['full_name'] = fullName.trim();
    if (email != null) {
      request.fields['email'] = email.trim();
    }
    if (phoneNumber != null) {
      request.fields['phone_number'] = phoneNumber.trim();
    }

    final normalizedPath = (imagePath ?? '').trim();
    if (normalizedPath.isNotEmpty) {
      request.files.add(
        await http.MultipartFile.fromPath('profile_image', normalizedPath),
      );
    }

    try {
      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);
      final data = _decodeBody(response);

      if (response.statusCode == 200 && data is Map<String, dynamic>) {
        return app_user.User.fromJson(data);
      }

      throw _buildException(response, data);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw _networkException(e);
    }
  }

  Future<void> deleteCurrentUser() async {
    final url = Uri.parse('$baseUrl/api/v2/app/user/');

    try {
      final response = await _sendWithAuthRetry(
        (headers) => http.delete(url, headers: headers),
      );

      if (response.statusCode == 204 || response.statusCode == 200) {
        await removeToken();
        return;
      }

      final data = _decodeBody(response);
      throw _buildException(response, data);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw _networkException(e);
    }
  }

  // ???? ???? transferWallet ???? ??????? ?? ????? ???? ?????? ?????.
  Future<bool> transferWallet({
    required String walletCode,
    required double amount,
    String? recipientName,
    String? note,
  }) async {
    final url = Uri.parse('$baseUrl/api/v2/app/wallet/transfer/');

    try {
      final response = await _sendWithAuthRetry(
        (headers) => http.post(
          url,
          headers: headers,
          body: json.encode({
            'wallet_code': walletCode,
            'amount': amount,
            if (recipientName != null && recipientName.trim().isNotEmpty)
              'recipient_name': recipientName.trim(),
            if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
          }),
        ),
      );
      final data = _decodeBody(response);

      if (response.statusCode == 200 &&
          data is Map &&
          data['success'] == true) {
        return true;
      }

      throw _buildException(response, data);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw _networkException(e);
    }
  }

  Future<bool> topUpWallet({
    required double amount,
    String? note,
  }) async {
    final url = Uri.parse('$baseUrl/api/v2/app/wallet/topup/');

    try {
      final response = await _sendWithAuthRetry(
        (headers) => http.post(
          url,
          headers: headers,
          body: json.encode({
            'amount': amount,
            if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
          }),
        ),
      );
      final data = _decodeBody(response);

      if (response.statusCode == 200 &&
          data is Map &&
          data['success'] == true) {
        return true;
      }

      throw _buildException(response, data);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw _networkException(e);
    }
  }

  // ???? ???? withdrawWallet ???? ??????? ?? ????? ???? ?????? ?????.
  Future<bool> withdrawWallet({
    required double amount,
    String? note,
  }) async {
    final url = Uri.parse('$baseUrl/api/v2/app/wallet/withdraw/');

    try {
      final response = await _sendWithAuthRetry(
        (headers) => http.post(
          url,
          headers: headers,
          body: json.encode({
            'amount': amount,
            if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
          }),
        ),
      );
      final data = _decodeBody(response);

      if (response.statusCode == 200 &&
          data is Map &&
          data['success'] == true) {
        return true;
      }

      throw _buildException(response, data);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw _networkException(e);
    }
  }

  // ???? ???? createOrder ???? ??????? ?? ????? ???? ?????? ?????.
  Future<OrderModel> createOrder(
      double totalPrice, List<Map<String, dynamic>> items, String collegeId,
      {String paymentMethod = 'WALLET',
      String? orderNote,
      String? nfcCardUid}) async {
    final url = Uri.parse('$baseUrl/api/v2/app/orders/');

    try {
      final response = await _sendWithAuthRetry(
        (headers) => http.post(
          url,
          headers: headers,
          body: json.encode({
            'total_price': totalPrice,
            'cafe_id': collegeId,
            'items': items,
            'payment_method': paymentMethod,
            if (nfcCardUid != null && nfcCardUid.trim().isNotEmpty)
              'nfc_card_uid': nfcCardUid.trim(),
            if (orderNote != null && orderNote.trim().isNotEmpty)
              'order_note': orderNote.trim(),
            if (orderNote != null && orderNote.trim().isNotEmpty)
              'notes': orderNote.trim(),
          }),
        ),
      );
      final data = _decodeBody(response);

      if ((response.statusCode == 201 || response.statusCode == 200) &&
          data is Map<String, dynamic>) {
        final orderPayload = data['order'];
        if (orderPayload is Map<String, dynamic>) {
          return OrderModel.fromJson(_normalizeOrderPayload(orderPayload));
        }

        return OrderModel(
          id: data['order_id'] is int
              ? data['order_id']
              : int.tryParse(data['order_id'].toString()) ?? 0,
          orderNumber: data['order_number']?.toString() ?? '---',
          totalPrice: totalPrice,
          status: 'PENDING',
          createdAt: DateTime.now().toIso8601String(),
          notes: orderNote ?? '',
          paymentMethod: paymentMethod,
          items: items
              .map(
                (item) => OrderItem(
                  productId: int.tryParse(item['product_id'].toString()) ?? 0,
                  productName: item['product_name']?.toString() ?? 'منتج',
                  quantity: int.tryParse(item['quantity'].toString()) ?? 1,
                  price: double.tryParse(item['price']?.toString() ?? '0') ?? 0,
                  options: item['options']?.toString() ?? '',
                ),
              )
              .toList(),
          cafeId: collegeId,
        );
      }

      throw _buildException(response, data);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw _networkException(e);
    }
  }

  // ???? ???? getOrders ???? ??????? ?? ????? ???? ?????? ?????.
  Future<List<OrderModel>> getOrders() async {
    final url = Uri.parse('$baseUrl/api/v2/app/orders/');

    try {
      final response = await _sendWithAuthRetry(
          (headers) => http.get(url, headers: headers));
      final data = _decodeBody(response);

      if (response.statusCode == 200 && data is List) {
        return data.map((item) {
          final map = Map<String, dynamic>.from(item as Map);
          return OrderModel.fromJson(_normalizeOrderPayload(map));
        }).toList();
      }

      throw _buildException(response, data);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw _networkException(e);
    }
  }

  Future<List<NotificationItem>> getNotifications() async {
    final url = Uri.parse('$baseUrl/api/v2/app/notifications/');

    try {
      final response = await _sendWithAuthRetry(
          (headers) => http.get(url, headers: headers));
      final data = _decodeBody(response);

      if (response.statusCode == 200 && data is Map) {
        final rawItems = data['notifications'];
        if (rawItems is List) {
          return rawItems
              .whereType<Map>()
              .map((item) => NotificationItem.fromJson(
                    Map<String, dynamic>.from(item),
                  ))
              .toList();
        }
        return [];
      }

      throw _buildException(response, data);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw _networkException(e);
    }
  }

  Future<void> markNotificationsRead() async {
    final url = Uri.parse('$baseUrl/api/v2/app/notifications/');

    try {
      final response = await _sendWithAuthRetry(
        (headers) => http.post(url, headers: headers),
      );
      final data = _decodeBody(response);

      if (response.statusCode == 200) {
        return;
      }

      throw _buildException(response, data);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw _networkException(e);
    }
  }

  // ???? ???? cancelOrder ???? ??????? ?? ????? ???? ?????? ?????.
  Future<void> cancelOrder(int orderId) async {
    final url = Uri.parse('$baseUrl/api/v2/app/orders/$orderId/cancel/');
    try {
      final response = await _sendWithAuthRetry(
        (headers) => http.patch(
          url,
          headers: headers,
          body: json.encode({'status': 'CANCELLED'}),
        ),
      );
      final data = _decodeBody(response);
      if (response.statusCode == 200 || response.statusCode == 204) {
        return;
      }
      throw _buildException(response, data);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw _networkException(e);
    }
  }

  // ???? ???? updateSecondaryPhone ???? ??????? ?? ????? ???? ?????? ?????.
  Future<bool> updateSecondaryPhone(String phone) async {
    final url = Uri.parse('$baseUrl/api/v2/app/user/secondary-phone/');

    try {
      final response = await _sendWithAuthRetry(
        (headers) => http.post(
          url,
          headers: headers,
          body: json.encode({'secondary_phone': phone}),
        ),
      );
      final data = _decodeBody(response);

      if (response.statusCode == 200) {
        return true;
      }

      throw _buildException(response, data);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw _networkException(e);
    }
  }
}
