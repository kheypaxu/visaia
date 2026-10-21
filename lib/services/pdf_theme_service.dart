import 'package:flutter/services.dart';
import 'package:pdf/widgets.dart' as pw;

/// Bundled fonts keep currency, punctuation and accented names legible offline.
class PdfThemeService {
  static Future<pw.MemoryImage> loadLogo() async => pw.MemoryImage(
    (await rootBundle.load(
      'assets/images/final-logo-visaia.png',
    )).buffer.asUint8List(),
  );

  static pw.Widget brandHeader(pw.ImageProvider logo) => pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 16),
    child: pw.Row(
      children: [
        pw.Image(logo, width: 42, height: 42, fit: pw.BoxFit.contain),
        pw.SizedBox(width: 12),
        pw.Text(
          'VISAIA',
          style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
        ),
      ],
    ),
  );

  static Future<pw.ThemeData>? _theme;
  static Future<pw.ThemeData> load() => _theme ??= _load();
  static Future<pw.ThemeData> _load() async {
    final regular = pw.Font.ttf(
      await rootBundle.load('assets/fonts/Roboto-Regular.ttf'),
    );
    final medium = pw.Font.ttf(
      await rootBundle.load('assets/fonts/Roboto-Medium.ttf'),
    );
    return pw.ThemeData.withFont(
      base: regular,
      bold: medium,
      italic: regular,
      boldItalic: medium,
    );
  }
}
