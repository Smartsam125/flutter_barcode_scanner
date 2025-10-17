import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutterbarcodescanner/flutterbarcodescanner.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Barcode Scanner Demo',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: const BarcodeScannerDemo(),
    );
  }
}

class BarcodeScannerDemo extends StatefulWidget {
  const BarcodeScannerDemo({super.key});

  @override
  State<BarcodeScannerDemo> createState() => _BarcodeScannerDemoState();
}

class _BarcodeScannerDemoState extends State<BarcodeScannerDemo> {
  String _scanResult = 'No scan result yet';
  final List<String> _continuousScanResults = [];
  StreamSubscription? _streamSubscription;
  bool _isScanning = false;

  @override
  void dispose() {
    _streamSubscription?.cancel();
    super.dispose();
  }

  /// Scan a single QR code
  Future<void> scanQRCode() async {
    String barcodeScanRes;
    try {
      barcodeScanRes = await FlutterBarcodeScanner.scanBarcode(
        '#ff6666',
        'Cancel',
        true,
        ScanMode.QR,
      );

      if (!mounted) return;

      setState(() {
        _scanResult = barcodeScanRes != '-1'
            ? 'QR Code: $barcodeScanRes'
            : 'Scan cancelled';
      });
    } on PlatformException {
      setState(() {
        _scanResult = 'Failed to get barcode scan result';
      });
    }
  }

  /// Scan a single barcode
  Future<void> scanBarcode() async {
    String barcodeScanRes;
    try {
      barcodeScanRes = await FlutterBarcodeScanner.scanBarcode(
        '#00FF00', // Green line color
        'Cancel',
        true,
        ScanMode.BARCODE,
      );

      if (!mounted) return;

      setState(() {
        _scanResult = barcodeScanRes != '-1'
            ? 'Barcode: $barcodeScanRes'
            : 'Scan cancelled';
      });
    } on PlatformException {
      setState(() {
        _scanResult = 'Failed to get barcode scan result';
      });
    }
  }

  /// Scan any type (QR or Barcode)
  Future<void> scanAny() async {
    String barcodeScanRes;
    try {
      barcodeScanRes = await FlutterBarcodeScanner.scanBarcode(
        '#0000FF', // Blue line color
        'Cancel',
        false, // Don't show flash icon
        ScanMode.DEFAULT,
      );

      if (!mounted) return;

      setState(() {
        _scanResult = barcodeScanRes != '-1'
            ? 'Scanned: $barcodeScanRes'
            : 'Scan cancelled';
      });
    } on PlatformException {
      setState(() {
        _scanResult = 'Failed to get barcode scan result';
      });
    }
  }

  /// Start continuous scanning
  void startContinuousScan() {
    setState(() {
      _isScanning = true;
      _continuousScanResults.clear();
    });

    try {
      final stream = FlutterBarcodeScanner.getBarcodeStreamReceiver(
        '#DC143C', // Crimson color
        'Stop Scanning',
        true,
        ScanMode.QR,
      );

      if (stream != null) {
        _streamSubscription = stream.listen(
          (barcode) {
            if (mounted && barcode != null && barcode != '-1') {
              setState(() {
                _continuousScanResults.insert(0, barcode.toString());
                // Keep only last 20 results
                if (_continuousScanResults.length > 20) {
                  _continuousScanResults.removeLast();
                }
              });
            }
          },
          onError: (error) {
            setState(() {
              _isScanning = false;
            });
            if (mounted) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text('Error: $error')));
            }
          },
          onDone: () {
            setState(() {
              _isScanning = false;
            });
          },
        );
      }
    } on PlatformException catch (e) {
      setState(() {
        _isScanning = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start continuous scan: ${e.message}'),
          ),
        );
      }
    }
  }

  /// Stop continuous scanning
  void stopContinuousScan() {
    _streamSubscription?.cancel();
    _streamSubscription = null;
    setState(() {
      _isScanning = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Barcode Scanner Demo'), elevation: 2),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Single Scan Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Single Scan Mode',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      key: const Key('qr_scan_button'),
                      onPressed: scanQRCode,
                      icon: const Icon(Icons.qr_code),
                      label: const Text('Scan QR Code'),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      key: const Key('barcode_scan_button'),
                      onPressed: scanBarcode,
                      icon: const Icon(Icons.barcode_reader),
                      label: const Text('Scan Barcode'),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      key: const Key('any_scan_button'),
                      onPressed: scanAny,
                      icon: const Icon(Icons.document_scanner),
                      label: const Text('Scan Any (No Flash)'),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Last Scan Result:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _scanResult,
                            style: const TextStyle(fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Continuous Scan Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Continuous Scan Mode',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (_isScanning)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.circle,
                                  size: 8,
                                  color: Colors.white,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Active',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      key: const Key('continuous_scan_button'),
                      onPressed: _isScanning
                          ? stopContinuousScan
                          : startContinuousScan,
                      icon: Icon(_isScanning ? Icons.stop : Icons.play_arrow),
                      label: Text(
                        _isScanning ? 'Stop Scanning' : 'Start Continuous Scan',
                      ),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                        backgroundColor: _isScanning ? Colors.red : null,
                        foregroundColor: _isScanning ? Colors.white : null,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      height: 200,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Scanned Results (${_continuousScanResults.length}):',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Expanded(
                            child: _continuousScanResults.isEmpty
                                ? const Center(
                                    child: Text(
                                      'No scans yet',
                                      style: TextStyle(color: Colors.grey),
                                    ),
                                  )
                                : ListView.builder(
                                    itemCount: _continuousScanResults.length,
                                    itemBuilder: (context, index) {
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 4,
                                        ),
                                        child: Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(6),
                                              decoration: BoxDecoration(
                                                color: Colors.blue,
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                '${index + 1}',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                _continuousScanResults[index],
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
