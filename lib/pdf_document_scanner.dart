/// Main entry point for the PDF document scanning package.
///
/// This package exposes a single static method, [PdfDocumentScanner.scan],
/// which opens a camera based scanner, lets the user capture one or more
/// pages, performs optical character recognition (OCR) on the scanned
/// pages, overlays the recognized text on top of the page image to create
/// a searchable PDF, and returns the path to the generated document.
///
/// The scan method accepts an optional [PdfScannerOptions] which can be
/// used to customise the scanning experience such as button labels,
/// whether the user may scan multiple pages, the initial contrast level,
/// and simple colour theming.
///
/// ## Example
///
/// ```dart
/// import 'package:pdf_document_scanner/pdf_document_scanner.dart';
///
/// // Inside an async function with a BuildContext
/// final pdfFile = await PdfDocumentScanner.scan(context,
///   options: const PdfScannerOptions(
///     multiPage: true,
///     maxPages: 5,
///     scanTitle: 'Scan your document',
///     cropTitle: 'Crop',
///     blackWhiteTitle: 'B & W',
///     resetTitle: 'Reset',
///   ),
/// );
/// if (pdfFile != null) {
///   // Do something with the generated PDF
/// }
/// ```

library pdf_document_scanner;

import 'dart:async';
import 'dart:io';

import 'package:flutter_doc_scanner/flutter_doc_scanner.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

part 'src/options.dart';

part 'src/internal_utils.dart';

/// Provides a high‑level API to scan documents and return a searchable PDF.
class PdfDocumentScanner {
  const PdfDocumentScanner._();

  /// Launch the scanning flow and return a [PdfScanResult] with PDF file and extracted content.
  ///
  /// When called, a native camera interface will be presented (via the
  /// underlying [flutter_doc_scanner](https://pub.dev/packages/flutter_doc_scanner) plugin).
  /// The user can capture one or more pages. After each capture the user is
  /// given the option to adjust the contrast of the page. When scanning is
  /// complete the package performs OCR on each page using the
  /// [google_mlkit_text_recognition](https://pub.dev/packages/google_mlkit_text_recognition)
  /// plugin, overlays the extracted text as an invisible layer on top of the
  /// page image, combines all pages into a single PDF and saves it to the
  /// application's documents directory. If the user cancels the operation
  /// or camera permissions are not granted, the method returns `null`.
  static Future<PdfScanResult?> scan(
    BuildContext context, {
    PdfScannerOptions? options,
  }) async {
    final opts = options ?? const PdfScannerOptions();

    // Request camera permissions
    final cameraGranted = await _ensureCameraPermission(context);
    if (!cameraGranted) {
      return null;
    }

    final List<File> scannedFiles = [];

    if (opts.multiPage) {
      // Multi-page scanning loop
      int pageCount = 0;
      bool continuScanning = true;

      while (continuScanning &&
          (opts.maxPages == null || pageCount < opts.maxPages!)) {
        try {
          Map scannedMap =
              await FlutterDocScanner().getScannedDocumentAsImages();
          if (scannedMap.isNotEmpty) {
            List<Uri> uris = extractImageUris(scannedMap['Uri']);

            for (final uri in uris) {
              final file = File.fromUri(uri);
              if (await file.exists()) {
                scannedFiles.add(file);
              }

              // Ask if user wants to scan another page (unless we've hit the limit)
              if (opts.maxPages == null || pageCount < opts.maxPages!) {
                continuScanning = await _askScanAnother(context, opts);
              } else {
                continuScanning = false;
              }
            }
          }
        } catch (_) {
          continuScanning = false;
        }
      }
    } else {
      // Single page scanning
      try {
        final scannedImage = await FlutterDocScanner().getScanDocuments();
        if (scannedImage != null && scannedImage.isNotEmpty) {
          final file = File(scannedImage);
          if (await file.exists()) {
            scannedFiles.add(file);
          }
        }
      } catch (_) {
        return null;
      }
    }

    if (scannedFiles.isEmpty) {
      return null;
    }

    // Build the PDF from processed pages.
    final scanResult = await _buildSearchablePdf(scannedFiles, opts);

    // Clean up temporary scanned images
    for (final file in scannedFiles) {
      try {
        if (await file.exists()) await file.delete();
      } catch (_) {}
    }

    return scanResult;
  }
}
