part of pdf_document_scanner;

/// OCR text positioning settings for PDF generation
class OcrSettings {
  /// Source image DPI - determines how to convert pixel coordinates to PDF points
  /// Common values: 72 (low quality), 150 (medium), 300 (high quality), 600 (very high)
  final double sourceDpi;

  /// Target PDF DPI - PDF coordinate system DPI (typically 72)
  final double targetDpi;

  /// Font size multiplier relative to bounding box height
  /// 1.0 = font size equals bounding box height
  /// 0.8 = font size is 80% of bounding box height (recommended)
  final double fontSizeMultiplier;

  /// Horizontal offset adjustment for text positioning (in PDF points)
  /// Positive values move text right, negative values move text left
  final double xOffset;

  /// Vertical offset adjustment for text positioning (in PDF points)
  /// Positive values move text up, negative values move text down
  final double yOffset;

  /// Whether to use word-level or line-level text positioning
  /// true = position each word individually (more accurate)
  /// false = position entire lines (faster, less accurate)
  final bool useWordLevel;

  /// Text opacity for debugging (0.0 = invisible, 1.0 = fully visible)
  /// Set to 0.1-0.3 for debugging to see text placement
  final double textOpacity;

  const OcrSettings({
    this.sourceDpi = 300.0,
    this.targetDpi = 72.0,
    this.fontSizeMultiplier = 0.8,
    this.xOffset = 0.0,
    this.yOffset = 0.0,
    this.useWordLevel = true,
    this.textOpacity = 0.0,
  });
}

/// Options to customise the scanning experience.
///
/// All parameters are optional and have reasonable defaults. The
/// [multiPage] flag controls whether the user may scan more than one page. If
/// [multiPage] is true and [maxPages] is provided, scanning will stop after
/// [maxPages] pages have been captured. If [maxPages] is null the user can
/// continue scanning until they choose to finish.
///
/// The string fields correspond to localisation and can be used to override
/// the titles of the native scanning UI on Android. iOS uses the default
/// localisation provided by the underlying library (WeScan).
@immutable
class PdfScannerOptions {
  /// Whether to enable multi‑page scanning. Defaults to `false`.
  final bool multiPage;

  /// The maximum number of pages to scan. Only honoured when [multiPage] is
  /// true. If null there is no hard limit on the number of pages.
  final int? maxPages;

  /// The initial contrast applied to every scanned page. A value of 1.0 leaves
  /// the image unmodified. Values greater than 1.0 increase contrast and
  /// values between 0.0 and 1.0 decrease contrast. The slider presented to
  /// the user allows values between 0.0 and 2.0 inclusive.
  final double initialContrast;

  /// Title shown at the top of the scanning interface on Android. Has no
  /// effect on iOS.
  final String scanTitle;

  /// Title shown on the crop screen on Android. Has no effect on iOS.
  final String cropTitle;

  /// Title for the black & white button on Android. Has no effect on iOS.
  final String blackWhiteTitle;

  /// Title for the reset button on Android. Has no effect on iOS.
  final String resetTitle;

  /// Colour used for slider active track and confirmation buttons. Defaults
  /// to the platform accent colour.
  final Color accentColor;

  /// OCR text positioning settings for PDF generation
  final OcrSettings ocrSettings;

  const PdfScannerOptions({
    this.multiPage = false,
    this.maxPages,
    this.initialContrast = 1.0,
    this.scanTitle = 'Scanning',
    this.cropTitle = 'Crop',
    this.blackWhiteTitle = 'B & W',
    this.resetTitle = 'Reset',
    this.accentColor = Colors.blue,
    this.ocrSettings = const OcrSettings(),
  });
}