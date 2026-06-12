import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/nfc_manager_android.dart';

class NfcCardException implements Exception {
  const NfcCardException(this.message);

  final String message;

  @override
  String toString() => message;
}

class NfcCardService {
  NfcCardService._();

  static final NfcCardService instance = NfcCardService._();

  Future<NfcAvailability> availability() async {
    if (defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS) {
      return NfcAvailability.unsupported;
    }
    return NfcManager.instance.checkAvailability();
  }

  Future<String> scanCard({
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final currentAvailability = await availability();
    if (currentAvailability == NfcAvailability.unsupported) {
      throw const NfcCardException('هذا الهاتف لا يدعم NFC.');
    }
    if (currentAvailability == NfcAvailability.disabled) {
      throw const NfcCardException(
        'ميزة NFC مغلقة. فعّلها من إعدادات الهاتف ثم حاول مجددًا.',
      );
    }

    final completer = Completer<String>();
    Timer? timer;

    Future<void> finish({
      String? value,
      Object? error,
    }) async {
      timer?.cancel();
      try {
        await NfcManager.instance.stopSession(
          alertMessageIos: value == null ? null : 'تمت قراءة البطاقة.',
          errorMessageIos: error?.toString(),
        );
      } catch (_) {}
      if (completer.isCompleted) {
        return;
      }
      if (error != null) {
        completer.completeError(error);
      } else if (value != null) {
        completer.complete(value);
      }
    }

    timer = Timer(
      timeout,
      () => finish(
        error: const NfcCardException(
          'انتهت مهلة القراءة. قرّب البطاقة من خلف الهاتف وحاول مجددًا.',
        ),
      ),
    );

    await NfcManager.instance.startSession(
      pollingOptions: const {
        NfcPollingOption.iso14443,
        NfcPollingOption.iso15693,
      },
      alertMessageIos: 'قرّب بطاقة Bite Hub من الهاتف.',
      onDiscovered: (tag) {
        final androidTag = NfcTagAndroid.from(tag);
        if (androidTag == null || androidTag.id.isEmpty) {
          finish(
            error: const NfcCardException(
              'تعذر قراءة معرف البطاقة. استخدم بطاقة NFC أخرى.',
            ),
          );
          return;
        }

        final hex = androidTag.id
            .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
            .join()
            .toUpperCase();
        final compactUid =
            hex.length > 16 ? hex.substring(hex.length - 16) : hex;
        finish(value: 'NFC-$compactUid');
      },
    );

    return completer.future;
  }
}
