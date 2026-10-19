import 'dart:convert';
import 'dart:io';

import 'package:flutter_image_compress/flutter_image_compress.dart';

/// Identifies which side of an identity document is being handled.
enum IdSide {
  front,
  back;

  String get label => this == IdSide.front ? 'Front' : 'Back';
}

/// Result of a compressed image ready to be persisted as a Base64 string.
class CompressedImage {
  /// Base64 encoded (no data-uri prefix) JPEG payload.
  final String base64;

  /// Original file name, kept for audit purposes.
  final String fileName;

  /// Size of the compressed payload in bytes.
  final int bytes;

  const CompressedImage({
    required this.base64,
    required this.fileName,
    required this.bytes,
  });
}

/// Compresses the image at [filePath] and returns it as a Base64 string.
///
/// Images are downscaled to at most [maxDimension] px on the longest edge and
/// re-encoded as JPEG at [quality] so the resulting Base64 payload stays small
/// enough to live comfortably inside a Firestore document.
Future<CompressedImage?> compressImageToBase64(
  String filePath, {
  String? fileName,
  int quality = 60,
  int maxDimension = 1200,
}) async {
  try {
    final bytes = await FlutterImageCompress.compressWithFile(
      filePath,
      quality: quality,
      minWidth: maxDimension,
      minHeight: maxDimension,
      format: CompressFormat.jpeg,
      keepExif: false,
    );

    if (bytes == null || bytes.isEmpty) return null;

    return CompressedImage(
      base64: base64Encode(bytes),
      fileName: fileName ?? filePath.split(Platform.pathSeparator).last,
      bytes: bytes.length,
    );
  } catch (_) {
    // Fall back to the raw file when the native compressor is unavailable.
    try {
      final file = File(filePath);
      if (!file.existsSync()) return null;
      final raw = await file.readAsBytes();
      if (raw.isEmpty) return null;
      return CompressedImage(
        base64: base64Encode(raw),
        fileName: fileName ?? filePath.split(Platform.pathSeparator).last,
        bytes: raw.length,
      );
    } catch (_) {
      return null;
    }
  }
}

/// Approximate size (in kilobytes) of a Base64 payload.
double base64SizeInKb(String base64) {
  if (base64.isEmpty) return 0;
  return (base64.length * 3) / 4 / 1024;
}
