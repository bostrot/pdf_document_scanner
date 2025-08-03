# pdf_document_scanner

`pdf_document_scanner` is a Flutter package that makes it easy to build a
document scanning workflow in your app. It provides a single API that
launches a camera based scanner, lets your users capture one or more pages,
apply basic image enhancements (contrast), performs Optical Character
Recognition (OCR) on each page and writes a single searchable PDF file to
disk. The resulting PDF contains a transparent text layer so that the
underlying image remains unchanged but the document becomes searchable in
standard PDF viewers.

## Features

* Launch a native camera interface (built on top of the [edge_detection](https://pub.dev/packages/edge_detection) plugin) to scan a page.
* Optional multi‑page scanning with a configurable maximum number of pages.
* Interactive contrast adjustment for each scanned page.
* Uses Google ML Kit via the [google_mlkit_text_recognition](https://pub.dev/packages/google_mlkit_text_recognition) plugin to extract text.
* Generates a PDF with the scanned images and a hidden text overlay for searchability using the [pdf](https://pub.dev/packages/pdf) library.
* Simple, localised button labels for the scanning UI on Android.

## Getting started

Add the package to your `pubspec.yaml`:

```yaml
dependencies:
  pdf_document_scanner:
    git:
      url: <this repository>
```

Add the required dependencies for camera access and ML Kit in your platform files:

### Android

* Ensure your `android/build.gradle` uses Kotlin 1.8.0 or newer.
* Set `minSdkVersion` to 21 or higher.
* Add the following permissions to `AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.CAMERA" />
```

### iOS

* Update the iOS deployment target in your `ios/Podfile` to 15.5 or newer.
* Include the camera usage description in `ios/Runner/Info.plist`:

```xml
<key>NSCameraUsageDescription</key>
<string>This app requires camera access to scan documents.</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>This app saves scanned documents to your photo library.</string>
<key>NSPhotoLibraryAddUsageDescription</key>
<string>This app saves scanned documents to your photo library.</string>
```

## Usage

To start a scan, call the `PdfDocumentScanner.scan` method from a widget
context. The method returns a `File` pointing to the generated PDF or
`null` if the user cancels.

```dart
import 'package:flutter/material.dart';
import 'package:pdf_document_scanner/pdf_document_scanner.dart';

class ScanPage extends StatelessWidget {
  const ScanPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Document Scanner')),
      body: Center(
        child: ElevatedButton(
          onPressed: () async {
            final pdfFile = await PdfDocumentScanner.scan(
              context,
              options: const PdfScannerOptions(
                multiPage: true,
                maxPages: 10,
                scanTitle: 'Scan your document',
                cropTitle: 'Crop',
                blackWhiteTitle: 'B & W',
                resetTitle: 'Reset',
              ),
            );
            if (pdfFile != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('PDF saved to ${pdfFile.path}')),
              );
            }
          },
          child: const Text('Start scan'),
        ),
      ),
    );
  }
}
```

## Notes

* Because this package uses ML Kit under the hood, only the Android and iOS
  platforms are supported. Web, desktop and other targets are not
  supported.
* The generated PDF is saved in the application's documents directory. Use
  `path_provider` or `share` packages to access or share the file.
* A4 is used as the default page size. If your documents have a different
  aspect ratio you can modify `_buildSearchablePdf` in the source to
  specify another `PdfPageFormat`.

## License

This project is provided as is under the MIT license. See LICENSE for
details.