import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

/// Supported evidence types users can attach to an investigation.
/// We keep this list short and intentional — only the formats the
/// AI pipeline can actually process today (PDF, image, video, URL).
enum EvidenceKind {
  pdf,
  image,
  video,
  url;

  IconData get icon {
    switch (this) {
      case EvidenceKind.pdf:
        return Icons.picture_as_pdf_outlined;
      case EvidenceKind.image:
        return Icons.image_outlined;
      case EvidenceKind.video:
        return Icons.movie_outlined;
      case EvidenceKind.url:
        return Icons.link;
    }
  }

  String get acceptSpec {
    switch (this) {
      case EvidenceKind.pdf:
        return 'application/pdf,.pdf';
      case EvidenceKind.image:
        return 'image/*,.jpg,.jpeg,.png,.webp';
      case EvidenceKind.video:
        return 'video/*,.mp4,.mov,.m4v';
      case EvidenceKind.url:
        return '';
    }
  }

  String get l10nKey {
    switch (this) {
      case EvidenceKind.pdf:
        return 'inv_type_pdf';
      case EvidenceKind.image:
        return 'inv_type_image';
      case EvidenceKind.video:
        return 'inv_type_video';
      case EvidenceKind.url:
        return 'inv_type_link';
    }
  }

  String get l10nSubKey {
    switch (this) {
      case EvidenceKind.pdf:
        return 'inv_type_pdf_sub';
      case EvidenceKind.image:
        return 'inv_type_image_sub';
      case EvidenceKind.video:
        return 'inv_type_video_sub';
      case EvidenceKind.url:
        return 'inv_type_link_sub';
    }
  }
}

/// Processing state of a piece of evidence.
enum EvidenceStatus {
  pending,
  uploading,
  processing,
  processed,
  failed;

  bool get isTerminal =>
      this == EvidenceStatus.processed || this == EvidenceStatus.failed;
}

/// A single piece of evidence attached to an investigation. Can be a
/// file (pdf/image/video) picked from the device, or a URL entered
/// manually by the user.
@immutable
class Evidence {
  const Evidence({
    required this.id,
    required this.kind,
    required this.displayName,
    required this.status,
    required this.uploadedAt,
    this.localPath,
    this.url,
    this.sizeBytes,
    this.extractedText,
    this.error,
  });

  /// Locally-generated unique id (UUID v4 in production, time-based
  /// in this MVP).
  final String id;

  /// Type of evidence. Drives the icon and the validation logic.
  final EvidenceKind kind;

  /// Human-friendly label (file name or shortened URL).
  final String displayName;

  /// Lifecycle state. UI uses this to render progress / error states.
  final EvidenceStatus status;

  /// When the user added the evidence to the investigation.
  final DateTime uploadedAt;

  /// Local file path (filled when the user picked a file).
  final String? localPath;

  /// Remote URL. Always populated for [EvidenceKind.url]; for file
  /// evidence it may carry the upload URL once the file is on the
  /// backend.
  final String? url;

  /// Size in bytes (file evidence only).
  final int? sizeBytes;

  /// Optional text extracted by the AI pipeline (OCR, transcription,
  /// PDF text). Populated when [status] is [EvidenceStatus.processed].
  final String? extractedText;

  /// Optional error message when [status] is [EvidenceStatus.failed].
  final String? error;

  Evidence copyWith({
    EvidenceStatus? status,
    String? url,
    String? extractedText,
    String? error,
    String? displayName,
  }) {
    return Evidence(
      id: id,
      kind: kind,
      displayName: displayName ?? this.displayName,
      status: status ?? this.status,
      uploadedAt: uploadedAt,
      localPath: localPath,
      url: url ?? this.url,
      sizeBytes: sizeBytes,
      extractedText: extractedText ?? this.extractedText,
      error: error ?? this.error,
    );
  }

  /// Builds an [Evidence] entry from a real picked file.
  /// Validates the extension and returns `null` if unsupported.
  static Evidence? fromFile({
    required String name,
    required String path,
    required int? sizeBytes,
  }) {
    final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';

    EvidenceKind? kind;
    if (['pdf'].contains(ext)) {
      kind = EvidenceKind.pdf;
    } else if (['jpg', 'jpeg', 'png', 'webp', 'gif', 'bmp'].contains(ext)) {
      kind = EvidenceKind.image;
    } else if (['mp4', 'mov', 'm4v', 'avi', 'mkv'].contains(ext)) {
      kind = EvidenceKind.video;
    }

    if (kind == null) return null;

    return Evidence(
      id: const Uuid().v4(),
      kind: kind,
      displayName: name,
      status: EvidenceStatus.pending,
      uploadedAt: DateTime.now(),
      localPath: path,
      sizeBytes: sizeBytes,
    );
  }
}
