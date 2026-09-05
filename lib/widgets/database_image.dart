import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:visaia/services/firestore_image_service.dart';

/// Displays HTTP URLs, legacy Base64 values, and Firestore image references.
class DatabaseImage extends StatelessWidget {
  final String source;
  final BoxFit fit;
  final Widget? placeholder;

  const DatabaseImage({
    super.key,
    required this.source,
    this.fit = BoxFit.cover,
    this.placeholder,
  });

  Widget _fallback() => placeholder ??
      const ColoredBox(
        color: Color(0xFFE0E0E0),
        child: Center(child: Icon(Icons.broken_image, color: Colors.grey)),
      );

  @override
  Widget build(BuildContext context) {
    if (source.startsWith('http://') || source.startsWith('https://')) {
      return Image.network(
        source,
        fit: fit,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, __, ___) => _fallback(),
      );
    }

    return FutureBuilder<Uint8List>(
      future: FirestoreImageService.load(source),
      builder: (context, snapshot) {
        if (snapshot.hasError) return _fallback();
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(strokeWidth: 2));
        }
        return Image.memory(
          snapshot.data!,
          fit: fit,
          width: double.infinity,
          height: double.infinity,
          errorBuilder: (_, __, ___) => _fallback(),
        );
      },
    );
  }
}
