import 'package:flutter/services.dart';
import 'package:pdf/widgets.dart' as pw;

/// Bundled fonts keep currency, punctuation and accented names legible offline.
class PdfThemeService {
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
