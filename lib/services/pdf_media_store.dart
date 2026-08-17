import 'dart:io';

import 'package:flutter/services.dart';

/// Bridges the Dart side of the app to the Kotlin side
/// declared in `android/app/src/main/kotlin/.../MainActivity.kt`.
///
/// We use a single `openPdf` method that takes the absolute
/// path of a PDF on disk and hands it off to the platform
/// PDF viewer via Android's `FileProvider`. The Kotlin side
/// wraps the `file://` URI in a `content://` URI with a
/// temporary read grant (see `AndroidManifest.xml` for the
/// `<provider>` declaration and `res/xml/file_paths.xml`
/// for the shared paths).
class PdfMediaStore {
  PdfMediaStore._();

  /// Channel name mirrored on the Kotlin side.
  static const _channel =
      MethodChannel('com.aidata.kashfLite/pdf_media_store');

  /// Opens [path] (absolute path on disk) with the platform
  /// PDF viewer. Returns a [PdfOpenResult] describing what
  /// happened so the caller can:
  ///   * show "saved" if the viewer launched successfully,
  ///   * show "please reinstall the app" if no native
  ///     handler is registered (stale APK),
  ///   * or surface a specific error if the native side
  ///     reported one.
  static Future<PdfOpenResult> openPdf({
    required String path,
    String? title,
  }) async {
    if (!Platform.isAndroid) return PdfOpenResult.noHandler;
    try {
      final uri = await _channel.invokeMethod<String>(
        'openPdf',
        <String, dynamic>{
          'path': path,
          'title': title,
        },
      );
      if (uri == null) return PdfOpenResult.noHandler;
      return PdfOpenResult.ok(contentUri: uri);
    } on MissingPluginException {
      // The Kotlin side has no handler registered for this
      // channel. This almost always means the user is
      // running a stale APK that was installed before the
      // FileProvider fix landed. They need to reinstall.
      return PdfOpenResult.noHandler;
    } on PlatformException catch (e) {
      return PdfOpenResult.error(
        code: e.code,
        message: e.message ?? 'unknown platform error',
      );
    }
  }
}

/// Outcome of [PdfMediaStore.openPdf].
///
/// * [ok] — the native handler fired `Intent.ACTION_VIEW`
///   and granted the receiving app a `content://` URI.
/// * [noHandler] — either the channel has no native
///   handler (stale APK) or we're not on Android.
/// * [error] — the native side reported an error.
class PdfOpenResult {
  const PdfOpenResult._(this.kind, {this.contentUri, this.code, this.message});

  final PdfOpenResultKind kind;
  final String? contentUri;
  final String? code;
  final String? message;

  factory PdfOpenResult.ok({required String contentUri}) =>
      PdfOpenResult._(PdfOpenResultKind.ok, contentUri: contentUri);

  static const noHandler =
      PdfOpenResult._(PdfOpenResultKind.noHandler);

  factory PdfOpenResult.error({
    required String code,
    required String message,
  }) =>
      PdfOpenResult._(
        PdfOpenResultKind.error,
        code: code,
        message: message,
      );

  bool get isOk => kind == PdfOpenResultKind.ok;
  bool get isNoHandler => kind == PdfOpenResultKind.noHandler;
  bool get isError => kind == PdfOpenResultKind.error;
}

enum PdfOpenResultKind { ok, noHandler, error }