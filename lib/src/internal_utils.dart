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
      const SnackBar(
        content: Text('Camera permission is required to scan documents.'),
      ),
    );
    return false;
  }

  // On Android, no explicit permission request needed
  return true;
}

/// Ask the user whether they wish to scan another page. Returns `true` if
/// another page should be scanned, `false` otherwise.
Future<bool> _askScanAnother(
  BuildContext context,
  PdfScannerOptions opts,
) async {
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
Future<PdfScanResult> _buildSearchablePdf(
  List<File> images,
  PdfScannerOptions opts,
) async {
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
    final RecognizedText recognized = await textRecognizer.processImage(
      inputImage,
    );
    content.writeln(recognized.text);

    doc.addPage(
      pw.Page(
        pageFormat: pageFormat,
        margin: pw.EdgeInsets.zero,
        build: (pw.Context context) {
          return pw.Stack(
            children: [
              // Text layer first (will be hidden beneath the image)
              ...recognized.blocks.expand((block) {
                return (opts.ocrSettings.useWordLevel
                        ? block.lines.expand((line) => line.elements)
                        : recognized.blocks
                              .expand((b) => b.lines)
                              .expand((line) => line.elements))
                    .map((element) {
                      final rect = element.boundingBox;
                      // Direct mapping: no scale needed in default setup
                      final double x = rect.left;
                      final double y = rect.top;
                      final double w = rect.width;
                      final double h = rect.height;
                      final double fontSize =
                          h * opts.ocrSettings.fontSizeMultiplier;
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
      ),
    );
  }

  await textRecognizer.close();

  // Save the PDF
  final outputDir = await getApplicationDocumentsDirectory();
  final pdfName = 'scanned_${DateTime.now().millisecondsSinceEpoch}.pdf';
  final pdfPath = p.join(outputDir.path, pdfName);

  final pdfBytes = await doc.save();
  final outputFile = File(pdfPath);
  await outputFile.writeAsBytes(pdfBytes, flush: true);

  final previewFiles = await _persistPreviewFiles(images);

  if (opts.exportFormat == ExportFormat.pdf) {
    return PdfScanResult(
      file: outputFile,
      content: content.toString(),
      title: 'Scanned Document',
      pageFiles: previewFiles,
      format: opts.exportFormat,
      preset: opts.enhancementOptions.preset,
      curvatureIntensity: opts.enhancementOptions.curvatureIntensity,
      rotationAngle: 0,
    );
  }

  final exportedFiles = await _exportImages(images, opts.exportFormat);
  final primaryExport = exportedFiles.isNotEmpty
      ? exportedFiles.first
      : outputFile;

  return PdfScanResult(
    file: primaryExport,
    content: content.toString(),
    title: 'Scanned Document',
    pageFiles: exportedFiles.isNotEmpty ? exportedFiles : previewFiles,
    format: opts.exportFormat,
    preset: opts.enhancementOptions.preset,
    curvatureIntensity: opts.enhancementOptions.curvatureIntensity,
    rotationAngle: 0,
  );
}

Future<List<File>> _persistPreviewFiles(List<File> files) async {
  if (files.isEmpty) {
    return const [];
  }

  try {
    final tempDir = await getTemporaryDirectory();
    final previewDir = Directory(
      p.join(
        tempDir.path,
        'scan_preview_${DateTime.now().millisecondsSinceEpoch}',
      ),
    );
    await previewDir.create(recursive: true);

    final retainedFiles = <File>[];
    for (var index = 0; index < files.length; index++) {
      final source = files[index];
      final destination = File(
        p.join(previewDir.path, 'page_${index + 1}_${p.basename(source.path)}'),
      );
      await destination.writeAsBytes(await source.readAsBytes(), flush: true);
      retainedFiles.add(destination);
    }
    return retainedFiles;
  } catch (_) {
    return List<File>.from(files);
  }
}

Future<List<File>> _exportImages(List<File> files, ExportFormat format) async {
  if (files.isEmpty) {
    return const [];
  }

  try {
    final outputDir = await getApplicationDocumentsDirectory();
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final extension = format == ExportFormat.jpg ? 'jpg' : 'png';

    final exportedFiles = <File>[];
    for (var index = 0; index < files.length; index++) {
      final source = files[index];
      final decoded = img.decodeImage(await source.readAsBytes());
      if (decoded == null) {
        continue;
      }

      final outputPath = p.join(
        outputDir.path,
        'scanned_${stamp}_page_${index + 1}.$extension',
      );
      final outputFile = File(outputPath);
      final encoded = format == ExportFormat.jpg
          ? img.encodeJpg(decoded, quality: 95)
          : img.encodePng(decoded);
      await outputFile.writeAsBytes(encoded, flush: true);
      exportedFiles.add(outputFile);
    }

    return exportedFiles;
  } catch (_) {
    return const [];
  }
}

/// Show a preview allowing the user to compare original vs. processed pages
/// and choose which set should be used to build the final PDF.
///
/// Returns the selected list of files (either [originals] or [processed])
/// or `null` if the user cancelled.
Future<List<File>?> _showPreviewSelector(
  BuildContext context,
  List<File> originals,
  List<File> processed,
) async {
  if (originals.isEmpty || processed.isEmpty) return null;

  final result = await Navigator.of(context).push<List<File>>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (context) {
        return _PreviewSelectorPage(originals: originals, processed: processed);
      },
    ),
  );

  return result;
}

class _PreviewSelectorPage extends StatefulWidget {
  final List<File> originals;
  final List<File> processed;

  const _PreviewSelectorPage({
    required this.originals,
    required this.processed,
  });

  @override
  State<_PreviewSelectorPage> createState() => _PreviewSelectorPageState();
}

class _PreviewSelectorPageState extends State<_PreviewSelectorPage> {
  bool showProcessed = true;
  int pageIndex = 0;

  @override
  Widget build(BuildContext context) {
    final pages = showProcessed ? widget.processed : widget.originals;

    return Scaffold(
      appBar: AppBar(title: const Text('Preview pages')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 520;
                  final toggle = ToggleButtons(
                    isSelected: [!showProcessed, showProcessed],
                    onPressed: (i) => setState(() => showProcessed = i == 1),
                    constraints: const BoxConstraints(
                      minHeight: 40,
                      minWidth: 110,
                    ),
                    children: const [Text('Original'), Text('Processed')],
                  );

                  return isWide
                      ? Row(
                          children: [
                            toggle,
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                showProcessed
                                    ? 'Processed preview: geometry correction + contrast'
                                    : 'Original preview: no preprocessing applied',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            toggle,
                            const SizedBox(height: 12),
                            Text(
                              showProcessed
                                  ? 'Processed preview: geometry correction + contrast'
                                  : 'Original preview: no preprocessing applied',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        );
                },
              ),
            ),
            Expanded(
              child: PageView.builder(
                itemCount: pages.length,
                onPageChanged: (i) => setState(() => pageIndex = i),
                itemBuilder: (context, i) {
                  final file = pages[i];
                  return Padding(
                    padding: const EdgeInsets.all(12),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Theme.of(context).dividerColor,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: InteractiveViewer(
                          minScale: 1.0,
                          maxScale: 5.0,
                          child: Center(
                            child: Image.file(file, fit: BoxFit.contain),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text('Page ${pageIndex + 1} / ${pages.length}'),
                  OutlinedButton(
                    onPressed: () =>
                        Navigator.of(context).pop(widget.originals),
                    child: const Text('Use Originals'),
                  ),
                  FilledButton(
                    onPressed: () =>
                        Navigator.of(context).pop(widget.processed),
                    child: const Text('Use Processed'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
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
  final String title;
  final String correspondent;
  final String documentType;
  final List<String> selectedTags;
  final DateTime? issueDate;
  final String? ocrText;
  final String? summaryText;
  final String? cleanedText;
  final List<File> pageFiles;
  final ExportFormat format;
  final DocumentEnhancementPreset preset;
  final double curvatureIntensity;
  final int rotationAngle;

  PdfScanResult({
    required this.file,
    required this.content,
    this.title = 'Scanned Document',
    this.correspondent = '',
    this.documentType = '',
    this.selectedTags = const [],
    this.issueDate,
    this.ocrText,
    this.summaryText,
    this.cleanedText,
    this.pageFiles = const [],
    this.format = ExportFormat.pdf,
    this.preset = DocumentEnhancementPreset.auto,
    this.curvatureIntensity = 0.8,
    this.rotationAngle = 0,
  });

  PdfScanResult copyWith({
    File? file,
    String? content,
    String? title,
    String? correspondent,
    String? documentType,
    List<String>? selectedTags,
    DateTime? issueDate,
    String? ocrText,
    String? summaryText,
    String? cleanedText,
    List<File>? pageFiles,
    ExportFormat? format,
    DocumentEnhancementPreset? preset,
    double? curvatureIntensity,
    int? rotationAngle,
  }) {
    return PdfScanResult(
      file: file ?? this.file,
      content: content ?? this.content,
      title: title ?? this.title,
      correspondent: correspondent ?? this.correspondent,
      documentType: documentType ?? this.documentType,
      selectedTags: selectedTags ?? this.selectedTags,
      issueDate: issueDate ?? this.issueDate,
      ocrText: ocrText ?? this.ocrText,
      summaryText: summaryText ?? this.summaryText,
      cleanedText: cleanedText ?? this.cleanedText,
      pageFiles: pageFiles ?? this.pageFiles,
      format: format ?? this.format,
      preset: preset ?? this.preset,
      curvatureIntensity: curvatureIntensity ?? this.curvatureIntensity,
      rotationAngle: rotationAngle ?? this.rotationAngle,
    );
  }
}
