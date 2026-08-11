import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show ValueChanged;
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

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

  /// Returns the currently signed-in user, or `null` when no user
  /// is signed in. Convenience wrapper used by the settings screens
  /// to render account info.
  User? get currentUser => _auth.currentUser;

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

  /// Updates the display name on the currently signed-in user.
  /// Throws [AuthException] when no user is signed in or the update
  /// is rejected by Firebase.
  Future<void> updateDisplayName({
    required String displayName,
    AppLanguage language = AppLanguage.english,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw AuthException(_localize(
        en: 'You need to be signed in first.',
        ar: '.يجب تسجيل الدخول أولاً',
        language: language,
      ));
    }
    try {
      await user.updateDisplayName(displayName.trim());
      await user.reload();
    } on FirebaseAuthException catch (e) {
      throw AuthException(_localize(
        en: e.code == 'requires-recent-login'
            ? 'Please sign in again to update your profile.'
            : 'Could not save your changes.',
        ar: e.code == 'requires-recent-login'
            ? '.الرجاء تسجيل الدخول مجدداً لتحديث ملفك الشخصي'
            : '.تعذّر حفظ التغييرات',
        language: language,
      ));
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

  /// Signs in with an arbitrary [AuthCredential] (phone, Apple, etc.).
  /// Used by the phone-sign-in flow on Android when Firebase
  /// auto-verifies the SMS code and hands us a [PhoneAuthCredential]
  /// before the user has had a chance to type anything.
  Future<User> signInWithCredential(
    AuthCredential credential, {
    AppLanguage language = AppLanguage.english,
  }) async {
    try {
      final cred = await _auth.signInWithCredential(credential);
      return cred.user!;
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'invalid-verification-code':
        case 'invalid-verification-id':
          throw AuthException(_localize(
            en: 'The verification code is invalid or expired.',
            ar: '.رمز التحقق غير صالح أو انتهت صلاحيته',
            language: language,
          ));
        case 'session-expired':
          throw AuthException(_localize(
            en: 'The verification session expired. Request a new code.',
            ar: '.انتهت صلاحية جلسة التحقق. اطلب رمزًا جديدًا',
            language: language,
          ));
        case 'network-request-failed':
          throw AuthException(_localize(
            en: 'Network error. Check your connection and try again.',
            ar: '.خطأ في الشبكة. تحقّق من الاتصال وحاول مرة أخرى',
            language: language,
          ));
        default:
          throw AuthException(_localize(
            en: 'Sign-in failed. Please try again.',
            ar: '.تعذّر تسجيل الدخول. حاول مرة أخرى',
            language: language,
          ));
      }
    }
  }

  /// Starts the phone sign-in flow by sending an SMS code to
  /// [phoneNumber] (E.164, e.g. +9665...). The [onCodeSent] callback
  /// fires once the SMS is dispatched and gives the [verificationId]
  /// the user will need to confirm the OTP. Once the user types the
  /// code, call [confirmPhoneCode].
  ///
  /// [onCodeResent] fires when Firebase gives us a fresh resend token.
  /// Pass the token back to a subsequent call via [forceResendingToken]
  /// so re-sends don't get rate-limited.
  ///
  /// On Android, when the SMS Retriever API can read the code
  /// automatically, [onAutoVerifiedCredential] fires and the screen
  /// can sign the user in directly — no OTP entry needed.
  Future<void> startPhoneLogin({
    required String phoneNumber,
    ValueChanged<String>? onCodeSent,
    ValueChanged<int?>? onCodeResent,
    ValueChanged<PhoneAuthCredential>? onAutoVerifiedCredential,
    Duration codeTimeout = const Duration(seconds: 60),
    int? forceResendingToken,
    AppLanguage language = AppLanguage.english,
  }) async {
    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        timeout: codeTimeout,
        forceResendingToken: forceResendingToken,
        verificationCompleted: (PhoneAuthCredential credential) {
          if (onAutoVerifiedCredential != null) {
            onAutoVerifiedCredential(credential);
          } else {
            // No handler — sign in directly so the caller doesn't
            // get stuck waiting for an OTP the user never typed.
            _auth.signInWithCredential(credential);
          }
        },
        codeSent: (String verificationId, int? resendToken) {
          onCodeSent?.call(verificationId);
          onCodeResent?.call(resendToken);
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          // The OS couldn't auto-retrieve. Drop into the OTP stage
          // so the user can type the code manually.
          onCodeSent?.call(verificationId);
          onCodeResent?.call(null);
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

  /// Changes the password for the currently signed-in user.
  ///
  /// Firebase requires the user to have re-authenticated recently for
  /// sensitive actions like a password change. Throws [AuthException]
  /// with a localised message on failure.
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
    String? reauthPassword,
    AppLanguage language = AppLanguage.english,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw AuthException(_localize(
        en: 'You need to be signed in to change your password.',
        ar: '.يجب تسجيل الدخول لتغيير كلمة المرور',
        language: language,
      ));
    }
    try {
      final credential = EmailAuthProvider.credential(
        email: user.email ?? '',
        password: (reauthPassword ?? currentPassword),
      );
      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(newPassword);
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'wrong-password':
        case 'invalid-credential':
        case 'invalid-login-credentials':
          throw AuthException(_localize(
            en: 'Current password is incorrect.',
            ar: '.كلمة المرور الحالية غير صحيحة',
            language: language,
          ));
        case 'weak-password':
          throw AuthException(_localize(
            en: 'Password is too weak. Use at least 6 characters.',
            ar: '.كلمة المرور ضعيفة. استخدم 6 أحرف على الأقل',
            language: language,
          ));
        case 'requires-recent-login':
          throw AuthException(_localize(
            en: 'Please re-enter your current password to continue.',
            ar: '.الرجاء إعادة إدخال كلمة المرور الحالية للمتابعة',
            language: language,
          ));
        case 'network-request-failed':
          throw AuthException(_localize(
            en: 'Network error. Check your connection and try again.',
            ar: '.خطأ في الشبكة. تحقّق من الاتصال وحاول مرة أخرى',
            language: language,
          ));
        default:
          throw AuthException(_localize(
            en: 'Could not update your password.',
            ar: '.تعذّر تحديث كلمة المرور',
            language: language,
          ));
      }
    }
  }

  /// Re-authenticates the current user with the given [password].
  /// Used before destructive actions (delete account).
  Future<void> reauthenticateWithPassword({
    required String password,
    AppLanguage language = AppLanguage.english,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw AuthException(_localize(
        en: 'You need to be signed in first.',
        ar: '.يجب تسجيل الدخول أولاً',
        language: language,
      ));
    }
    try {
      final credential = EmailAuthProvider.credential(
        email: user.email ?? '',
        password: password,
      );
      await user.reauthenticateWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'wrong-password':
        case 'invalid-credential':
        case 'invalid-login-credentials':
          throw AuthException(_localize(
            en: 'Current password is incorrect.',
            ar: '.كلمة المرور الحالية غير صحيحة',
            language: language,
          ));
        case 'requires-recent-login':
          throw AuthException(_localize(
            en: 'Please re-enter your current password to continue.',
            ar: '.الرجاء إعادة إدخال كلمة المرور الحالية للمتابعة',
            language: language,
          ));
        case 'network-request-failed':
          throw AuthException(_localize(
            en: 'Network error. Check your connection and try again.',
            ar: '.خطأ في الشبكة. تحقّق من الاتصال وحاول مرة أخرى',
            language: language,
          ));
        default:
          throw AuthException(_localize(
            en: 'Could not verify your password.',
            ar: '.تعذّر التحقق من كلمة المرور',
            language: language,
          ));
      }
    }
  }

  /// Permanently deletes the current Firebase Auth account. The
  /// user is signed out as part of the deletion. Throws an
  /// [AuthException] on failure.
  Future<void> deleteAccount({
    String? reauthPassword,
    AppLanguage language = AppLanguage.english,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw AuthException(_localize(
        en: 'You need to be signed in to delete your account.',
        ar: '.يجب تسجيل الدخول لحذف حسابك',
        language: language,
      ));
    }
    try {
      if (reauthPassword != null && reauthPassword.isNotEmpty) {
        final credential = EmailAuthProvider.credential(
          email: user.email ?? '',
          password: reauthPassword,
        );
        await user.reauthenticateWithCredential(credential);
      }
      await user.delete();
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'requires-recent-login':
          throw AuthException(_localize(
            en: 'Please re-enter your current password to continue.',
            ar: '.الرجاء إعادة إدخال كلمة المرور الحالية للمتابعة',
            language: language,
          ));
        case 'network-request-failed':
          throw AuthException(_localize(
            en: 'Network error. Check your connection and try again.',
            ar: '.خطأ في الشبكة. تحقّق من الاتصال وحاول مرة أخرى',
            language: language,
          ));
        default:
          throw AuthException(_localize(
            en: 'Could not delete your account. Please try again.',
            ar: '.تعذّر حذف الحساب. حاول مرة أخرى',
            language: language,
          ));
      }
    }
  }

  /// Real Apple sign-in via `sign_in_with_apple` + Firebase's
  /// `OAuthProvider('apple.com').credential(...)`.
  ///
  /// Apple sign-in is only available on iOS, iPadOS, macOS, tvOS
  /// and web. Every other platform (most importantly Android, which
  /// is what this app primarily ships on) raises
  /// `SignInWithAppleNotSupportedException` — we catch that and
  /// re-throw it as a friendly [AuthException] so the UI shows a
  /// snackbar instead of silently dropping the user into the app.
  Future<User> signInWithApple({
    AppLanguage language = AppLanguage.english,
  }) async {
    try {
      // Trigger the native Apple ID sheet.
      final apple = await SignInWithApple.getAppleIDCredential(
        scopes: const [],
        webAuthenticationOptions: WebAuthenticationOptions(
          // On web: the same redirect target Firebase uses for Apple.
          clientId: 'com.aidata.kashfLite',
          redirectUri: Uri.parse('https://kashf-lite.app/__/auth/handler'),
        ),
      );
      // Exchange the Apple identity token for a Firebase credential.
      final oauth = OAuthProvider('apple.com').credential(
        idToken: apple.identityToken,
        accessToken: apple.authorizationCode,
      );
      final cred = await _auth.signInWithCredential(oauth);
      return cred.user!;
    } on SignInWithAppleNotSupportedException {
      throw AuthException(_localize(
        en: 'Apple sign-in is only available on iOS and macOS.',
        ar: '.تسجيل الدخول عبر Apple متاح فقط على نظامي iOS وmacOS',
        language: language,
      ));
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        throw AuthException(_localize(
          en: 'Sign-in cancelled.',
          ar: '.تم إلغاء تسجيل الدخول',
          language: language,
        ));
      }
      throw AuthException(_localize(
        en: 'Apple sign-in failed. Please try again.',
        ar: '.تعذّر تسجيل الدخول عبر Apple. حاول مرة أخرى',
        language: language,
      ));
    } on FirebaseAuthException catch (e) {
      throw AuthException(_localize(
        en: e.code == 'network-request-failed'
            ? 'Network error. Check your connection and try again.'
            : 'Apple sign-in failed. Please try again.',
        ar: e.code == 'network-request-failed'
            ? '.خطأ في الشبكة. تحقّق من الاتصال وحاول مرة أخرى'
            : '.تعذّر تسجيل الدخول عبر Apple. حاول مرة أخرى',
        language: language,
      ));
    } catch (_) {
      throw AuthException(_localize(
        en: 'Apple sign-in failed. Please try again.',
        ar: '.تعذّر تسجيل الدخول عبر Apple. حاول مرة أخرى',
        language: language,
      ));
    }
  }

  Future<void> signOut() async {
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

    // Wait for auth state to actually flip to null before resolving,
    // so callers can navigate immediately after this future completes.
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
        // Local sign-out already succeeded — don't propagate a timeout.
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
          en: 'The phone number is not valid. Use the full international format, e.g. +9665XXXXXXXX.',
          ar: '.رقم الهاتف غير صالح. استخدم الصيغة الدولية الكاملة مثل +9665XXXXXXXX',
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
          ar: 'رمز التحقق غير صالح أو انتهت صلاحيته.',
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
      case 'credential-already-in-use':
      case 'account-exists-with-different-credential':
        return _localize(
          en:
              'This phone number is already linked to an account created with another sign-in method.',
          ar:
              '.رقم الهاتف هذا مربوط بحساب تم إنشاؤه بطريقة تسجيل دخول مختلفة',
          language: language,
        );
      case 'user-disabled':
        return _localize(
          en: 'This account has been disabled.',
          ar: 'تم تعطيل هذا الحساب.',
          language: language,
        );
      case 'web-context-cancelled':
      case 'app-not-authorized':
        return _localize(
          en:
              'Phone sign-in is not authorised on this device. Please update the app.',
          ar:
              '.تسجيل الدخول بالهاتف غير مصرّح به على هذا الجهاز. حدّث التطبيق',
          language: language,
        );
      case 'billing-not-enabled':
      case 'project-not-found':
        return _localize(
          en:
              'Phone sign-in is not enabled for this Firebase project. Enable it in the Firebase console (Authentication → Sign-in method → Phone).',
          ar:
              '.تسجيل الدخول بالهاتف غير مفعّل لهذا المشروع على Firebase. فعّله من لوحة Firebase (Authentication ← Sign-in method ← Phone)',
          language: language,
        );
      case 'operation-not-allowed':
        // Firebase returns this for two distinct cases:
        //   1) The Phone provider is disabled in the console.
        //   2) The requested region isn't enabled — Firebase
        //      blocks SMS for some regions until the developer
        //      explicitly opts in via the Blaze plan / region
        //      settings. We surface the message verbatim so the
        //      user/developer knows exactly what to fix.
        return _localize(
          en:
              'Phone sign-in is disabled for this Firebase project, or SMS sending is not yet enabled for your region. Enable it in the Firebase console under Authentication → Sign-in method → Phone.',
          ar:
              '.تسجيل الدخول بالهاتف معطّل لهذا المشروع على Firebase، أو إرسال الرسائل القصيرة غير مفعّل بعد لمنطقتك. فعّله من لوحة Firebase (Authentication ← Sign-in method ← Phone)',
          language: language,
        );
      case 'app-verification-failed':
      case 'captcha-check-failed':
      case 'missing-app-credential':
      case 'invalid-app-credential':
        return _localize(
          en:
              'Could not verify this app with Firebase. Make sure the SHA-1 / SHA-256 fingerprints in Firebase match the ones configured for your Android build, then try again.',
          ar:
              '.تعذّر التحقق من التطبيق مع Firebase. تأكّد من مطابقة بصمات SHA-1 / SHA-256 في Firebase لبنية Android ثم حاول مجدداً',
          language: language,
        );
      case 'internal-error':
        return _localize(
          en:
              'A Firebase internal error occurred. Please try again in a moment.',
          ar:
              '.حدث خطأ داخلي في Firebase. حاول مرة أخرى بعد قليل',
          language: language,
        );
      case 'cancelled':
        return _localize(
          en: 'Sign-in cancelled.',
          ar: '.تم إلغاء تسجيل الدخول',
          language: language,
        );
      default:
        // Surface the raw Firebase code so we can debug in production.
        // This is intentional — phone auth is notoriously sensitive
        // to misconfiguration and "Could not send the SMS code"
        // alone is unactionable for support.
        return _localize(
          en: 'Could not send the SMS code (${e.code}). Try again.',
          ar: '.تعذّر إرسال رمز SMS (${e.code}). حاول مرة أخرى',
          language: language,
        );
    }
  }

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
