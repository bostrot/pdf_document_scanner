part of pdf_document_scanner;

// ignore_for_file: avoid_print

/// Request camera permissions from the user using the permission_handler
/// package. Returns true if permission is granted, otherwise false.
/// On iOS, VisionKit requires explicit camera permissions.
/// On Android, ML Kit handles permissions automatically.
Future<bool> _ensureCameraPermission(BuildContext context) async {
  // Only request camera permissions on iOS
  // Android ML Kit handles permissions automatically
  if (Platform.isIOS) {
    final status = await Permission.camera.status;
    if (status.isGranted) {
      return true;
    }
    final result = await Permission.camera.request();
    if (result.isGranted) {
      return true;
    }
    // Inform the user that camera access is required on iOS.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Camera permission is required to scan documents.')),
    );
    return false;
  }

  // On Android, no explicit permission request needed
  return true;
}

/// Ask the user whether they wish to scan another page. Returns `true` if
/// another page should be scanned, `false` otherwise.
Future<bool> _askScanAnother(BuildContext context, PdfScannerOptions opts) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      return AlertDialog(
        title: const Text('Add another page?'),
        content: const Text('Would you like to scan another page or finish?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Finish'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Add'),
          ),
        ],
      );
    },
  );
  return result ?? false;
}

/// Build a searchable PDF from a list of processed images. Returns a [File]
/// pointing to the saved PDF in the application's documents directory.
Future<PdfScanResult> _buildSearchablePdf(List<File> images, PdfScannerOptions opts) async {
  // Create document with metadata during construction
  final doc = pw.Document(
    title: 'Scanned Document',
    author: 'PDF Document Scanner',
    creator: 'Flutter PDF Scanner App',
    producer: 'pdf package',
    subject: 'Scanned document with OCR',
  );

  final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
  var content = StringBuffer();

  for (final file in images) {
    final bytes = await file.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) continue;

    final imgWidth = decoded.width.toDouble();
    final imgHeight = decoded.height.toDouble();

    // Map image pixels directly to PDF points for accurate positioning
    final pdfWidth = imgWidth;
    final pdfHeight = imgHeight;
    final pageFormat = PdfPageFormat(pdfWidth, pdfHeight);

    final pw.ImageProvider pdfImage = pw.MemoryImage(bytes);

    // Perform OCR
    final inputImage = InputImage.fromFilePath(file.path);
    final RecognizedText recognized = await textRecognizer.processImage(inputImage);
    content.writeln(recognized.text);

    // No scaling needed: pixel coordinates map directly to PDF points
    final scaleX = 1.0;
    final scaleY = 1.0;

    doc.addPage(pw.Page(
      pageFormat: pageFormat,
      margin: pw.EdgeInsets.zero,
      build: (pw.Context context) {
        return pw.Stack(
          children: [
            // Text layer first (will be hidden beneath the image)
            ...recognized.blocks.expand((block) {
              return (opts.ocrSettings.useWordLevel ?
                block.lines.expand((line) => line.elements) :
                recognized.blocks.expand((b) => b.lines).expand((line) => line.elements)
              ).map((element) {
                final rect = element.boundingBox;
                // Direct mapping: no scale needed in default setup
                final double x = rect.left;
                final double y = rect.top;
                final double w = rect.width;
                final double h = rect.height;
                final double fontSize = h * opts.ocrSettings.fontSizeMultiplier;
                return pw.Positioned(
                  left: x + opts.ocrSettings.xOffset,
                  top: y + opts.ocrSettings.yOffset,
                  child: pw.Container(
                    width: w,
                    height: h,
                    child: pw.Text(
                      element.text,
                      style: pw.TextStyle(
                        fontSize: fontSize,
                        color: PdfColors.black,
                      ),
                    ),
                  ),
                );
              });
            }).toList(),
            // Background image on top to fully obscure the text layer
            pw.Image(
              pdfImage,
              width: pdfWidth,
              height: pdfHeight,
              fit: pw.BoxFit.fill,
            ),
          ],
        );
      },
    ));
  }

  await textRecognizer.close();

  // Save the PDF
  final outputDir = await getApplicationDocumentsDirectory();
  final pdfName = 'scanned_${DateTime.now().millisecondsSinceEpoch}.pdf';
  final pdfPath = p.join(outputDir.path, pdfName);

  final pdfBytes = await doc.save();
  final outputFile = File(pdfPath);
  await outputFile.writeAsBytes(pdfBytes, flush: true);
  return PdfScanResult(file: outputFile, content: content.toString());
}

List<Uri> extractImageUris(String input) {
  final re = RegExp(r'Page\{imageUri=(file://[^}\]]+)\}');
  return re
      .allMatches(input)
      .map((m) => Uri.tryParse(m.group(1)!))
      .whereType<Uri>()
      .toList();
}

/// Result of scanning: generated PDF and extracted text content
class PdfScanResult {
  final File file;
  final String content;

  PdfScanResult({required this.file, required this.content});
}