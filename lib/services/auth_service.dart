import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show ValueChanged;

import '../l10n/app_locale.dart';

/// Thin wrapper around [FirebaseAuth] exposing the auth flows used by
/// the auth screens. All methods throw an [AuthException] (with a
/// message that the UI can show directly) on failure so the screens
/// can present a snackbar.
///
/// Methods accept an [AppLanguage] so the error message returned to
/// the UI is in the caller's language. Without a language, the
/// service falls back to English.
class AuthService {
  AuthService([FirebaseAuth? auth]) : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  FirebaseAuth get raw => _auth;

  /// Creates a new account with email + password and stores the
  /// supplied [displayName] on the user profile.
  Future<User> signUpWithEmail({
    required String email,
    required String password,
    String? displayName,
    AppLanguage language = AppLanguage.english,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      if (displayName != null && displayName.trim().isNotEmpty) {
        await credential.user?.updateDisplayName(displayName.trim());
      }
      return credential.user!;
    } on FirebaseAuthException catch (e) {
      throw AuthException(_mapEmailError(e, language));
    } catch (e) {
      throw AuthException(e.toString());
    }
  }

  /// Signs in with email + password.
  Future<User> signInWithEmail({
    required String email,
    required String password,
    AppLanguage language = AppLanguage.english,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return credential.user!;
    } on FirebaseAuthException catch (e) {
      throw AuthException(_mapEmailError(e, language));
    } catch (e) {
      throw AuthException(e.toString());
    }
  }

  /// Starts the phone sign-in flow by sending an SMS code to
  /// [phoneNumber] (E.164, e.g. +9665...). The [onCodeSent] callback
  /// fires once the SMS is dispatched and gives the [verificationId]
  /// the user will need to confirm the OTP. Once the user types the
  /// code, call [confirmPhoneCode].
  Future<void> startPhoneLogin({
    required String phoneNumber,
    ValueChanged<String>? onCodeSent,
    ValueChanged<String>? onAutoVerified,
    ValueChanged<PhoneAuthCredential>? onAutoVerifiedCredential,
    Duration codeTimeout = const Duration(seconds: 60),
    AppLanguage language = AppLanguage.english,
  }) async {
    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        timeout: codeTimeout,
        // Android-only: instant auto-fill if the device reads the SMS.
        forceResendingToken: null,
        verificationCompleted: (PhoneAuthCredential credential) async {
          if (onAutoVerifiedCredential != null) {
            onAutoVerifiedCredential(credential);
          } else if (onAutoVerified != null) {
            try {
              final userCred =
                  await _auth.signInWithCredential(credential);
              onAutoVerified(userCred.user?.uid ?? '');
            } on FirebaseAuthException catch (e) {
              throw AuthException(_mapPhoneError(e, language));
            }
          }
        },
        codeSent: (String verificationId, int? resendToken) {
          onCodeSent?.call(verificationId);
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          onCodeSent?.call(verificationId);
        },
        verificationFailed: (FirebaseAuthException e) {
          throw AuthException(_mapPhoneError(e, language));
        },
      );
    } on FirebaseAuthException catch (e) {
      throw AuthException(_mapPhoneError(e, language));
    } catch (e) {
      if (e is AuthException) rethrow;
      throw AuthException(e.toString());
    }
  }

  /// Completes the phone sign-in by submitting the 6-digit [smsCode]
  /// that was sent to the user's phone, using the [verificationId]
  /// returned by [startPhoneLogin].
  Future<User> confirmPhoneCode({
    required String verificationId,
    required String smsCode,
    AppLanguage language = AppLanguage.english,
  }) async {
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );
      final userCred = await _auth.signInWithCredential(credential);
      return userCred.user!;
    } on FirebaseAuthException catch (e) {
      throw AuthException(_mapPhoneError(e, language));
    } catch (e) {
      throw AuthException(e.toString());
    }
  }

  Future<void> signOut() async {
    // Snapshot the current user so we can confirm the auth state
    // actually flips to `null` before resolving.
    final previousUser = _auth.currentUser;
    try {
      await _auth.signOut();
    } on FirebaseAuthException catch (_) {
      throw AuthException(_localize(
        en: 'Sign-out failed. Please try again.',
        ar: 'تعذّر تسجيل الخروج. حاول مرة أخرى.',
        language: AppLanguage.english,
      ));
    } catch (e) {
      throw AuthException(e.toString());
    }

    // Firebase sign-out can occasionally return without flushing the
    // auth state to `null`. Wait up to 2 s for the broadcast stream
    // to emit a logged-out state so the caller can navigate
    // immediately. We don't fail the call if the stream doesn't fire
    // because the local Firebase cache is already cleared.
    if (previousUser != null) {
      final completer = Completer<void>();
      late final StreamSubscription<User?> sub;
      sub = _auth.authStateChanges().listen((user) {
        if (user == null && !completer.isCompleted) {
          completer.complete();
          sub.cancel();
        }
      });
      try {
        await completer.future.timeout(const Duration(seconds: 2));
      } on TimeoutException {
        // Don't surface this — the local sign-out already succeeded.
      } finally {
        await sub.cancel();
      }
    }
  }

  String _mapEmailError(FirebaseAuthException e, AppLanguage language) {
    switch (e.code) {
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
      case 'invalid-login-credentials':
        return _localize(
          en: 'Invalid email or password.',
          ar: 'البريد الإلكتروني أو كلمة المرور غير صحيحة.',
          language: language,
        );
      case 'user-disabled':
        return _localize(
          en: 'This account has been disabled.',
          ar: 'تم تعطيل هذا الحساب.',
          language: language,
        );
      case 'invalid-email':
        return _localize(
          en: 'The email address is not valid.',
          ar: 'البريد الإلكتروني غير صالح.',
          language: language,
        );
      case 'email-already-in-use':
        return _localize(
          en: 'An account already exists for this email.',
          ar: 'يوجد حساب مسبق مسجّل بهذا البريد الإلكتروني.',
          language: language,
        );
      case 'weak-password':
        return _localize(
          en: 'Password is too weak. Use at least 6 characters.',
          ar: 'كلمة المرور ضعيفة. استخدم 6 أحرف على الأقل.',
          language: language,
        );
      case 'too-many-requests':
        return _localize(
          en: 'Too many attempts. Try again later.',
          ar: 'محاولات كثيرة جدًا. حاول لاحقًا.',
          language: language,
        );
      case 'network-request-failed':
        return _localize(
          en: 'Network error. Check your connection and try again.',
          ar: 'خطأ في الشبكة. تحقّق من الاتصال وحاول مرة أخرى.',
          language: language,
        );
      default:
        return _localize(
          en: 'Authentication failed. Please try again.',
          ar: '.تعذّر إكمال المصادقة. حاول مرة أخرى',
          language: language,
        );
    }
  }

  String _mapPhoneError(FirebaseAuthException e, AppLanguage language) {
    switch (e.code) {
      case 'invalid-phone-number':
        return _localize(
          en: 'The phone number is not valid.',
          ar: 'رقم الهاتف غير صالح.',
          language: language,
        );
      case 'missing-phone-number':
        return _localize(
          en: 'Please enter a phone number.',
          ar: 'الرجاء إدخال رقم الهاتف.',
          language: language,
        );
      case 'quota-exceeded':
        return _localize(
          en: 'SMS quota exceeded. Try again later.',
          ar: 'تم تجاوز الحد المسموح للرسائل. حاول لاحقًا.',
          language: language,
        );
      case 'invalid-verification-code':
      case 'invalid-verification-id':
        return _localize(
          en: 'The verification code is invalid or expired.',
          ar: 'رمز التحقق غير صالح أو منتهي الصلاحية.',
          language: language,
        );
      case 'session-expired':
        return _localize(
          en: 'The verification session expired. Request a new code.',
          ar: 'انتهت صلاحية جلسة التحقق. اطلب رمزًا جديدًا.',
          language: language,
        );
      case 'too-many-requests':
        return _localize(
          en: 'Too many attempts. Try again later.',
          ar: 'محاولات كثيرة جدًا. حاول لاحقًا.',
          language: language,
        );
      case 'network-request-failed':
        return _localize(
          en: 'Network error. Check your connection and try again.',
          ar: 'خطأ في الشبكة. تحقّق من الاتصال وحاول مرة أخرى.',
          language: language,
        );
      default:
        return _localize(
          en: 'Could not send the SMS code. Try again.',
          ar: '.تعذّر إرسال رمز SMS. حاول مرة أخرى',
          language: language,
        );
    }
  }

  /// Returns the Arabic string when the language is Arabic and the
  /// translated message is provided, otherwise the English fallback.
  String _localize({
    required String en,
    required String ar,
    required AppLanguage language,
  }) {
    return language == AppLanguage.arabic ? ar : en;
  }
}

class AuthException implements Exception {
  AuthException(this.message);
  final String message;
  @override
  String toString() => message;
}
