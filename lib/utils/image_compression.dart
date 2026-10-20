import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

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

/// Firestore rejects documents larger than ~1 MiB and Base64 inflates the
/// payload by roughly 33%. Keeping the encoded string below this ceiling
/// guarantees the image always fits inside the farmer document.
const int kMaxEncodedImageBytes = 700 * 1024;

/// Compresses the image at [filePath] and returns it as a Base64 string.
///
/// The image is downscaled so that its shortest edge is at least
/// [maxDimension] px (the native compressor never upscales) and re-encoded as
/// JPEG at [quality]. When the resulting payload would still be too large for
/// Firestore, it is recompressed with a lower quality and smaller dimensions.
///
/// Returns `null` when the file cannot be read or compressed.
Future<CompressedImage?> compressImageToBase64(
  String filePath, {
  String? fileName,
  int quality = 60,
  int maxDimension = 1200,
  int maxBytes = kMaxEncodedImageBytes,
}) async {
  final resolvedName = fileName ?? filePath.split(Platform.pathSeparator).last;

  try {
    var attemptQuality = quality;
    var attemptDimension = maxDimension;

    for (var attempt = 0; attempt < 4; attempt++) {
      final bytes = await FlutterImageCompress.compressWithFile(
        filePath,
        quality: attemptQuality,
        minWidth: attemptDimension,
        minHeight: attemptDimension,
        format: CompressFormat.jpeg,
        keepExif: false,
      );

      if (bytes == null || bytes.isEmpty) break;

      final encoded = base64Encode(bytes);
      if (encoded.length <= maxBytes) {
        return CompressedImage(
          base64: encoded,
          fileName: resolvedName,
          bytes: bytes.length,
        );
      }

      // Still too heavy for Firestore — shrink and try again.
      attemptQuality = (attemptQuality * 0.7).round();
      if (attemptQuality < 25) attemptQuality = 25;
      attemptDimension = (attemptDimension * 0.75).round();
      if (attemptDimension < 240) attemptDimension = 240;
    }
  } catch (_) {
    // Fall through to the raw-file fallback below.
  }

  // Fall back to the raw file when the native compressor is unavailable.
  try {
    final file = File(filePath);
    if (!file.existsSync()) return null;
    final raw = await file.readAsBytes();
    if (raw.isEmpty) return null;
    final encoded = base64Encode(raw);
    if (encoded.length > maxBytes) return null;
    return CompressedImage(
      base64: encoded,
      fileName: resolvedName,
      bytes: raw.length,
    );
  } catch (_) {
    return null;
  }
}

/// Approximate size (in kilobytes) of a Base64 payload.
double base64SizeInKb(String base64) {
  if (base64.isEmpty) return 0;
  return (base64.length * 3) / 4 / 1024;
}

/// Decodes a Base64 payload, returning `null` when it is not valid Base64.
///
/// Guards the UI from crashing when a stored image is malformed.
Uint8List? decodeBase64Safely(String? value) {
  if (value == null || value.isEmpty) return null;
  try {
    return base64Decode(value);
  } catch (_) {
    return null;
  }
}
