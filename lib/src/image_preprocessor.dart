part of 'package:pdf_document_scanner/pdf_document_scanner.dart';

Future<List<File>> _preprocessScannedFiles(
  List<File> scannedFiles, {
  required DocumentEnhancementOptions options,
}) async {
  final processedFiles = <File>[];

  for (final file in scannedFiles) {
    final processed = await _straightenAndEnhanceDocument(
      file,
      options: options,
    );
    processedFiles.add(processed ?? file);
  }

  return processedFiles;
}

Future<File?> _straightenAndEnhanceDocument(
  File inputFile, {
  required DocumentEnhancementOptions options,
}) async {
  try {
    final source = cv.imread(inputFile.path, flags: cv.IMREAD_COLOR);
    if (source.isEmpty) {
      return null;
    }

    cv.Mat workingImage = source;

    // Step 1: Perspective correction (white border fill) - if enabled
    if (options.enablePerspectiveCorrection) {
      workingImage = _safePerspectiveCorrectPage(workingImage);
    }

    // Step 2: Deskew - if enabled
    if (options.enableDeskew) {
      workingImage = _deskewPage(workingImage);
    }

    // Step 3: Enhanced document processing (CLAHE + thresholding)
    final enhanced = _enhanceDocument(workingImage, options: options);

    final tempDir = await getTemporaryDirectory();
    final outputPath = p.join(
      tempDir.path,
      'straightened_${DateTime.now().microsecondsSinceEpoch}.png',
    );

    final success = cv.imwrite(outputPath, enhanced);
    if (!success) {
      return null;
    }

    return File(outputPath);
  } catch (e) {
    debugPrint('Document preprocessing failed: $e');
    return null;
  }
}

cv.Mat _safePerspectiveCorrectPage(cv.Mat source) {
  final gray = cv.cvtColor(source, cv.COLOR_BGR2GRAY);
  final blurred = cv.medianBlur(gray, 5);
  final (_, thresholded) = cv.threshold(
    blurred,
    0,
    255,
    cv.THRESH_BINARY + cv.THRESH_OTSU,
  );

  final edges = cv.canny(thresholded, 50, 150);
  final (contours, _) = cv.findContours2f(
    edges,
    cv.RETR_EXTERNAL,
    cv.CHAIN_APPROX_SIMPLE,
  );
  if (contours.isEmpty) {
    return source;
  }

  cv.VecPoint2f? bestContour;
  double bestArea = 0.0;
  final imageArea = source.rows * source.cols.toDouble();

  for (final contour in contours) {
    final area = cv.contourArea2f(contour);
    if (area > bestArea) {
      bestArea = area;
      bestContour = contour;
    }
  }

  if (bestContour == null || bestArea < imageArea * 0.15) {
    return source;
  }

  final perimeter = cv.arcLength2f(bestContour, true);
  final approximated = cv.approxPolyDP2f(bestContour, perimeter * 0.02, true);
  if (approximated.length == 4) {
    final ordered = _orderCornerPoints(approximated.toList());
    if (ordered != null) {
      final perspectiveResult = _warpFromOrderedCorners(ordered, source);
      if (perspectiveResult != null) {
        return perspectiveResult;
      }
    }
  }

  final rect = cv.minAreaRect2f(bestContour);
  final rectArea = rect.size.width * rect.size.height;
  if (rectArea < imageArea * 0.15) {
    return source;
  }

  final corners = cv.boxPoints(rect);
  if (corners.length != 4) {
    return source;
  }

  // boxPoints returns bottom-left, top-left, top-right, bottom-right.
  final bottomLeft = corners[0];
  final topLeft = corners[1];
  final topRight = corners[2];
  final bottomRight = corners[3];

  // Compute axis-aligned bounding box of all four corners to avoid clipping
  // when the document is rotated. Using max of opposite edges would miss the
  // diagonal corners that extend beyond that rectangle.
  final allX = [topLeft.x, topRight.x, bottomRight.x, bottomLeft.x];
  final allY = [topLeft.y, topRight.y, bottomRight.y, bottomLeft.y];
  final targetWidth = (allX.reduce(math.max) - allX.reduce(math.min)).round();
  final targetHeight = (allY.reduce(math.max) - allY.reduce(math.min)).round();
  if (targetWidth < 20 || targetHeight < 20) {
    return source;
  }

  final srcPoints = <cv.Point2f>[
    topLeft,
    topRight,
    bottomRight,
    bottomLeft,
  ].cvd;
  final dstPoints = <cv.Point2f>[
    cv.Point2f(0, 0),
    cv.Point2f(targetWidth.toDouble() - 1, 0),
    cv.Point2f(targetWidth.toDouble() - 1, targetHeight.toDouble() - 1),
    cv.Point2f(0, targetHeight.toDouble() - 1),
  ].cvd;

  final transform = cv.getPerspectiveTransform2f(srcPoints, dstPoints);
  // Use BORDER_CONSTANT with white fill to avoid grey corners after correction
  return cv.warpPerspective(
    source,
    transform,
    (targetWidth, targetHeight),
    borderMode: cv.BORDER_CONSTANT,
    borderValue: cv.Scalar.white,
  );
}

cv.Mat? _warpFromOrderedCorners(
  (cv.Point2f, cv.Point2f, cv.Point2f, cv.Point2f) ordered,
  cv.Mat source,
) {
  final topLeft = ordered.$1;
  final topRight = ordered.$2;
  final bottomRight = ordered.$3;
  final bottomLeft = ordered.$4;

  // Compute axis-aligned bounding box of all four corners to avoid clipping
  // when the document is rotated. Using max of opposite edges would miss the
  // diagonal corners that extend beyond that rectangle.
  final allX = [topLeft.x, topRight.x, bottomRight.x, bottomLeft.x];
  final allY = [topLeft.y, topRight.y, bottomRight.y, bottomLeft.y];
  final targetWidth = (allX.reduce(math.max) - allX.reduce(math.min)).round();
  final targetHeight = (allY.reduce(math.max) - allY.reduce(math.min)).round();
  if (targetWidth < 20 || targetHeight < 20) {
    return null;
  }

  final srcPoints = <cv.Point2f>[
    topLeft,
    topRight,
    bottomRight,
    bottomLeft,
  ].cvd;
  final dstPoints = <cv.Point2f>[
    cv.Point2f(0, 0),
    cv.Point2f(targetWidth.toDouble() - 1, 0),
    cv.Point2f(targetWidth.toDouble() - 1, targetHeight.toDouble() - 1),
    cv.Point2f(0, targetHeight.toDouble() - 1),
  ].cvd;

  final transform = cv.getPerspectiveTransform2f(srcPoints, dstPoints);
  // Use BORDER_CONSTANT with white fill to avoid grey corners after correction
  return cv.warpPerspective(
    source,
    transform,
    (targetWidth, targetHeight),
    borderMode: cv.BORDER_CONSTANT,
    borderValue: cv.Scalar.white,
  );
}

cv.Mat _deskewPage(cv.Mat source) {
  final gray = cv.cvtColor(source, cv.COLOR_BGR2GRAY);
  final minDimension = math.min(gray.rows, gray.cols);
  final blurSize = minDimension < 720 ? 3 : 5;
  final blurred = cv.medianBlur(gray, blurSize);
  final preprocessed = _boostLocalContrast(blurred);
  final (_, thresholded) = cv.threshold(
    preprocessed,
    0,
    255,
    cv.THRESH_BINARY + cv.THRESH_OTSU,
  );

  final angle = _estimateDeskewAngle(thresholded);
  if (angle.abs() < 0.35) {
    return source;
  }

  return _rotateImage(source, angle);
}

cv.Mat _prepareReadablePage(cv.Mat image) {
  final gray = image.channels == 1
      ? image
      : cv.cvtColor(image, cv.COLOR_BGR2GRAY);
  final minDimension = math.min(gray.rows, gray.cols);

  final tileGridSize = minDimension < 64
      ? (2, 2)
      : minDimension < 1024
      ? (4, 4)
      : (8, 8);

  final clahe = cv.CLAHE.create(
    minDimension < 64
        ? 1.8
        : minDimension < 1024
        ? 2.2
        : 2.8,
    tileGridSize,
  );
  final contrastBoosted = clahe.apply(gray);
  clahe.dispose();

  if (minDimension < 5) {
    return contrastBoosted;
  }

  return cv.medianBlur(contrastBoosted, 3);
}

double _estimateDeskewAngle(cv.Mat binary) {
  final edges = cv.canny(binary, 50, 150);
  final lines = cv.HoughLinesP(
    edges,
    1,
    cv.CV_PI / 180,
    120,
    minLineLength: 120,
    maxLineGap: 20,
  );
  if (lines.isEmpty) {
    return 0.0;
  }

  final angles = <double>[];
  for (var row = 0; row < lines.rows; row++) {
    final line = lines.at<cv.Vec4i>(row, 0);
    final dx = line.val3 - line.val1;
    final dy = line.val4 - line.val2;
    if (dx.abs() < 20) {
      continue;
    }

    final angle = math.atan2(dy.toDouble(), dx.toDouble()) * 180 / math.pi;
    if (angle.abs() <= 20) {
      angles.add(angle);
    }
  }

  if (angles.isEmpty) {
    return 0.0;
  }

  angles.sort();
  final median = angles[angles.length ~/ 2];
  return -median;
}

cv.Mat _rotateImage(cv.Mat image, double angleDegrees) {
  final center = cv.Point2f(
    (image.cols / 2).toDouble(),
    (image.rows / 2).toDouble(),
  );
  final matrix = cv.getRotationMatrix2D(center, angleDegrees, 1.0);

  return cv.warpAffine(image, matrix, (
    image.cols,
    image.rows,
  ), borderMode: cv.BORDER_REPLICATE);
}

cv.Mat _boostLocalContrast(cv.Mat image) {
  final minDimension = math.min(image.rows, image.cols);
  if (minDimension < 64) {
    return image;
  }

  final clahe = cv.CLAHE.create(
    minDimension < 1024 ? 1.6 : 2.0,
    minDimension < 1024 ? (4, 4) : (8, 8),
  );
  final result = clahe.apply(image);
  clahe.dispose();
  return result;
}

/// Enhanced document processing pipeline.
///
/// Uses CLAHE contrast enhancement followed by Otsu's thresholding to produce
/// a clean, scanner-quality black-and-white document image with pure white
/// background and crisp black text.
cv.Mat _enhanceDocument(
  cv.Mat source, {
  required DocumentEnhancementOptions options,
}) {
  // Step 1: Convert to grayscale
  final gray = source.channels == 1
      ? source
      : cv.cvtColor(source, cv.COLOR_BGR2GRAY);

  cv.Mat workingImage = gray;

  // Step 2: Bilateral filtering for noise removal with edge preservation
  // This removes noise while preserving document edges (better than Gaussian for documents)
  if (options.enableBilateralFilter) {
    final filterSize = options.bilateralFilterSize % 2 == 1
        ? options.bilateralFilterSize
        : options.bilateralFilterSize + 1;
    workingImage = cv.bilateralFilter(
      workingImage,
      filterSize,
      options.bilateralSigmaColor,
      options.bilateralSigmaSpace,
    );
  }

  // Step 3: Apply CLAHE for local contrast enhancement
  if (options.enableClahe) {
    final minDim = math.min(workingImage.rows, workingImage.cols);
    final tileGridSize = minDim < 64
        ? (2, 2)
        : minDim < 1024
        ? (4, 4)
        : (8, 8);

    final clahe = cv.CLAHE.create(options.claheClipLimit, tileGridSize);
    final enhanced = clahe.apply(workingImage);
    clahe.dispose();

    if (workingImage != gray) {
      workingImage.dispose();
    }
    workingImage = enhanced;
  }

  // Step 4: Adaptive Gaussian thresholding for uneven lighting
  // Better than Otsu for documents with shadows/curvature
  if (options.enableAdaptiveThreshold) {
    final minDim = math.min(workingImage.rows, workingImage.cols);
    final blockSize = math.max(11, (minDim ~/ 15).toInt());
    final adjustedBlockSize = blockSize % 2 == 1 ? blockSize : blockSize + 1;

    final binary = cv.adaptiveThreshold(
      workingImage,
      255.0,
      cv.ADAPTIVE_THRESH_GAUSSIAN_C,
      cv.THRESH_BINARY,
      adjustedBlockSize,
      options.adaptiveThresholdConstant,
    );

    // Step 5: Morphological operations to clean up noise
    if (options.enableMorphologicalCleanup) {
      // Small kernel to remove salt-and-pepper noise while preserving text
      final kernel = cv.getStructuringElement(cv.MORPH_RECT, (2, 2));

      // Opening to remove small white noise (salt)
      final opened = cv.morphologyEx(binary, cv.MORPH_OPEN, kernel);

      // Closing to fill small black holes (pepper) in text/background
      final closed = cv.morphologyEx(opened, cv.MORPH_CLOSE, kernel);

      // Clean up
      binary.dispose();
      kernel.dispose();
      opened.dispose();

      if (workingImage != gray) {
        workingImage.dispose();
      }
      return closed;
    }

    if (workingImage != gray) {
      workingImage.dispose();
    }
    return binary;
  }

  // No thresholding - return as-is (grayscale or filtered)
  return workingImage;
}

(cv.Point2f, cv.Point2f, cv.Point2f, cv.Point2f)? _orderCornerPoints(
  List<cv.Point2f> points,
) {
  if (points.length < 4) {
    return null;
  }

  cv.Point2f? topLeft;
  cv.Point2f? topRight;
  cv.Point2f? bottomRight;
  cv.Point2f? bottomLeft;
  double minSum = double.infinity;
  double maxSum = -double.infinity;
  double minDiff = double.infinity;
  double maxDiff = -double.infinity;

  for (final point in points) {
    final sum = point.x + point.y;
    final diff = point.y - point.x;

    if (sum < minSum) {
      minSum = sum;
      topLeft = point;
    }
    if (sum > maxSum) {
      maxSum = sum;
      bottomRight = point;
    }
    if (diff < minDiff) {
      minDiff = diff;
      topRight = point;
    }
    if (diff > maxDiff) {
      maxDiff = diff;
      bottomLeft = point;
    }
  }

  if (topLeft == null ||
      topRight == null ||
      bottomRight == null ||
      bottomLeft == null) {
    return null;
  }

  return (topLeft, topRight, bottomRight, bottomLeft);
}

double _pointDistance(cv.Point2f a, cv.Point2f b) {
  final dx = a.x - b.x;
  final dy = a.y - b.y;
  return math.sqrt(dx * dx + dy * dy);
}
