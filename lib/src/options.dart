part of pdf_document_scanner;

/// Options for document image enhancement pipeline.
///
/// Each correction can be toggled on/off independently. Use [DocumentEnhancementOptions.disabled]
/// to disable all corrections, or [DocumentEnhancementOptions.defaults] for sensible defaults.
@immutable
class DocumentEnhancementOptions {
  /// Whether to apply perspective correction (detect document edges and flatten).
  final bool enablePerspectiveCorrection;

  /// Whether to apply deskewing (correct slight rotation angles).
  final bool enableDeskew;

  /// Whether to apply bilateral filtering (noise removal with edge preservation).
  final bool enableBilateralFilter;

  /// Whether to apply CLAHE (contrast limited adaptive histogram enhancement).
  final bool enableClahe;

  /// Whether to apply adaptive thresholding (convert to pure black & white).
  final bool enableAdaptiveThreshold;

  /// Whether to apply morphological operations (noise cleanup after thresholding).
  final bool enableMorphologicalCleanup;

  /// Clip limit for CLAHE. Higher values = more local contrast, but more noise.
  /// Recommended range: 1.0 (subtle) to 4.0 (aggressive).
  final double claheClipLimit;

  /// Kernel size for bilateral filtering. Larger = more blur, but slower.
  /// Must be odd. Recommended: 5-15.
  final int bilateralFilterSize;

  /// Sigma color for bilateral filtering. Higher = more color range considered.
  /// Recommended: 30-80.
  final double bilateralSigmaColor;

  /// Sigma space for bilateral filtering. Higher = farther pixels influence each other.
  /// Recommended: 30-80.
  final double bilateralSigmaSpace;

  /// Block size for adaptive thresholding. Larger = larger context considered.
  /// Must be odd. Recommended: 11-41.
  final int adaptiveThresholdBlockSize;

  /// Constant subtracted from the mean. Higher = darker output.
  /// Recommended: 5-20.
  final double adaptiveThresholdConstant;

  const DocumentEnhancementOptions({
    this.enablePerspectiveCorrection = true,
    this.enableDeskew = true,
    this.enableBilateralFilter = true,
    this.enableClahe = true,
    this.enableAdaptiveThreshold = true,
    this.enableMorphologicalCleanup = true,
    this.claheClipLimit = 2.0,
    this.bilateralFilterSize = 9,
    this.bilateralSigmaColor = 50.0,
    this.bilateralSigmaSpace = 50.0,
    this.adaptiveThresholdBlockSize = 11,
    this.adaptiveThresholdConstant = 10.0,
  });

  /// All corrections enabled with default parameters.
  static const DocumentEnhancementOptions defaults =
      DocumentEnhancementOptions();

  /// All corrections disabled.
  static const DocumentEnhancementOptions disabled = DocumentEnhancementOptions(
    enablePerspectiveCorrection: false,
    enableDeskew: false,
    enableBilateralFilter: false,
    enableClahe: false,
    enableAdaptiveThreshold: false,
    enableMorphologicalCleanup: false,
  );

  /// Creates a copy of this options with the given fields replaced.
  DocumentEnhancementOptions copyWith({
    bool? enablePerspectiveCorrection,
    bool? enableDeskew,
    bool? enableBilateralFilter,
    bool? enableClahe,
    bool? enableAdaptiveThreshold,
    bool? enableMorphologicalCleanup,
    double? claheClipLimit,
    int? bilateralFilterSize,
    double? bilateralSigmaColor,
    double? bilateralSigmaSpace,
    int? adaptiveThresholdBlockSize,
    double? adaptiveThresholdConstant,
  }) {
    return DocumentEnhancementOptions(
      enablePerspectiveCorrection:
          enablePerspectiveCorrection ?? this.enablePerspectiveCorrection,
      enableDeskew: enableDeskew ?? this.enableDeskew,
      enableBilateralFilter:
          enableBilateralFilter ?? this.enableBilateralFilter,
      enableClahe: enableClahe ?? this.enableClahe,
      enableAdaptiveThreshold:
          enableAdaptiveThreshold ?? this.enableAdaptiveThreshold,
      enableMorphologicalCleanup:
          enableMorphologicalCleanup ?? this.enableMorphologicalCleanup,
      claheClipLimit: claheClipLimit ?? this.claheClipLimit,
      bilateralFilterSize: bilateralFilterSize ?? this.bilateralFilterSize,
      bilateralSigmaColor: bilateralSigmaColor ?? this.bilateralSigmaColor,
      bilateralSigmaSpace: bilateralSigmaSpace ?? this.bilateralSigmaSpace,
      adaptiveThresholdBlockSize:
          adaptiveThresholdBlockSize ?? this.adaptiveThresholdBlockSize,
      adaptiveThresholdConstant:
          adaptiveThresholdConstant ?? this.adaptiveThresholdConstant,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DocumentEnhancementOptions &&
          enablePerspectiveCorrection == other.enablePerspectiveCorrection &&
          enableDeskew == other.enableDeskew &&
          enableBilateralFilter == other.enableBilateralFilter &&
          enableClahe == other.enableClahe &&
          enableAdaptiveThreshold == other.enableAdaptiveThreshold &&
          enableMorphologicalCleanup == other.enableMorphologicalCleanup &&
          claheClipLimit == other.claheClipLimit &&
          bilateralFilterSize == other.bilateralFilterSize &&
          bilateralSigmaColor == other.bilateralSigmaColor &&
          bilateralSigmaSpace == other.bilateralSigmaSpace &&
          adaptiveThresholdBlockSize == other.adaptiveThresholdBlockSize &&
          adaptiveThresholdConstant == other.adaptiveThresholdConstant;

  @override
  int get hashCode => Object.hash(
    enablePerspectiveCorrection,
    enableDeskew,
    enableBilateralFilter,
    enableClahe,
    enableAdaptiveThreshold,
    enableMorphologicalCleanup,
    claheClipLimit,
    bilateralFilterSize,
    bilateralSigmaColor,
    bilateralSigmaSpace,
    adaptiveThresholdBlockSize,
    adaptiveThresholdConstant,
  );
}

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

  /// Document image enhancement options (perspective correction, deskew, filtering, etc.)
  final DocumentEnhancementOptions enhancementOptions;

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
    this.enhancementOptions = const DocumentEnhancementOptions(),
    this.ocrSettings = const OcrSettings(),
  });
}
