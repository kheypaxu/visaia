import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:visaia/services/pdf_theme_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'bundled PDF fonts support currency, accents and report punctuation',
    () async {
      const sample =
          'Gross Income: \u20b1123,456.78\nCost Deduction: \u20b11,500.00\n'
          'Pe\u00f1a Farm \u2022 2.50 Acres\nIncome Projection \u2014 October 2026\nAudit: validated';
      for (final name in ['Roboto-Regular', 'Roboto-Medium']) {
        final parser = TtfParser(
          await rootBundle.load('assets/fonts/$name.ttf'),
        );
        for (final rune in sample.runes.where((r) => r != 10)) {
          expect(
            parser.charToGlyphIndexMap[rune],
            isNotNull,
            reason: '$name missing U+${rune.toRadixString(16)}',
          );
          expect(parser.charToGlyphIndexMap[rune], isNot(0));
        }
      }
      final pdf = pw.Document(theme: await PdfThemeService.load());
      final logo = await PdfThemeService.loadLogo();
      pdf.addPage(
        pw.Page(
          build: (_) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              PdfThemeService.brandHeader(logo),
              pw.Text(
                'Export typography check',
                style: pw.TextStyle(
                  fontSize: 22,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Text(sample, style: const pw.TextStyle(fontSize: 14)),
              pw.SizedBox(height: 20),
              pw.Text(
                sample,
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      );
      final bytes = await pdf.save();
      expect(bytes.length, greaterThan(1000));
      // Optional artifact for visual QA; regular test runs leave no files behind.
      if (Platform.environment['PDF_QA_OUTPUT'] case final String output) {
        await File(output).parent.create(recursive: true);
        await File(output).writeAsBytes(bytes);
      }
    },
  );
}
