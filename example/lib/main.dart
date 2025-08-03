import 'dart:io';

import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import 'package:pdf_document_scanner/pdf_document_scanner.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PDF Document Scanner Example',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const ScannerHomePage(),
    );
  }
}

class ScannerHomePage extends StatefulWidget {
  const ScannerHomePage({super.key});

  @override
  State<ScannerHomePage> createState() => _ScannerHomePageState();
}

class _ScannerHomePageState extends State<ScannerHomePage> {
  File? _pdfFile;
  bool _isScanning = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Document Scanner')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_isScanning) ...[
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              const Text('Scanning...'),
            ] else ...[
              ElevatedButton(
                onPressed: () async {
                  setState(() {
                    _isScanning = true;
                  });
                  final pdf = await PdfDocumentScanner.scan(
                    context,
                    options: const PdfScannerOptions(
                      multiPage: true,
                      maxPages: 5,
                      scanTitle: 'Scan',
                      cropTitle: 'Crop',
                      blackWhiteTitle: 'B & W',
                      resetTitle: 'Reset',
                    ),
                  );
                  setState(() {
                    _pdfFile = pdf;
                    _isScanning = false;
                  });
                },
                child: const Text('Start Scan'),
              ),
              const SizedBox(height: 16),
              if (_pdfFile != null) ...[
                Text('PDF saved: ${_pdfFile!.path}'),
                ElevatedButton(
                  onPressed: () {
                    OpenFile.open(_pdfFile!.path);
                  },
                  child: const Text('Open PDF'),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}