import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

/// Lets the user choose between taking a photo or browsing the gallery.
/// Returns `null` when the sheet is dismissed.
Future<ImageSource?> pickImageSource(BuildContext context) {
  return showModalBottomSheet<ImageSource>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Select a source',
              style: GoogleFonts.manrope(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1B3015),
              ),
            ),
            const SizedBox(height: 10),
            ListTile(
              leading: const Icon(Icons.photo_camera_rounded,
                  color: Color(0xFF4A633F), size: 24),
              title: Text(
                'Take a photo',
                style: GoogleFonts.manrope(
                    color: const Color(0xFF1B3015),
                    fontSize: 15,
                    fontWeight: FontWeight.w600),
              ),
              onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded,
                  color: Color(0xFF4A633F), size: 24),
              title: Text(
                'Choose from gallery',
                style: GoogleFonts.manrope(
                    color: const Color(0xFF1B3015),
                    fontSize: 15,
                    fontWeight: FontWeight.w600),
              ),
              onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
            ),
            const SizedBox(height: 10),
          ],
        ),
      );
    },
  );
}
