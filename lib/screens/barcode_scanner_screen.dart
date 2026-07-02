import 'package:flutter/material.dart';
import 'package:flutter_zxing/flutter_zxing.dart';
import '../utils/app_theme.dart';

/// Full-screen camera barcode scanner.
/// Push this route and await the result — returns a [String] barcode value,
/// or null if the user cancels.
///
/// ```dart
/// final barcode = await Navigator.push<String>(
///   context,
///   MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
/// );
/// ```
class BarcodeScannerScreen extends StatefulWidget {
  final String title;
  const BarcodeScannerScreen({
    super.key,
    this.title = 'Scan Barcode',
  });

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  bool _scanned = false;

  void _onScan(Code code) {
    if (_scanned || !code.isValid || code.text == null || code.text!.isEmpty) {
      return;
    }
    setState(() => _scanned = true);
    Navigator.pop(context, code.text);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Stack(
        children: [
          ReaderWidget(
            onScan: _scanned ? null : _onScan,
            codeFormat: Format.any,
            showFlashlight: true,
            showToggleCamera: false,
            showGallery: true,
            scanDelay: const Duration(milliseconds: 400),
            scanDelaySuccess: const Duration(milliseconds: 1000),
            cropPercent: 0.55,
          ),
          // Hint label at the bottom
          Positioned(
            bottom: 32,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Text(
                  'Point camera at a barcode or QR code',
                  style: TextStyle(color: Colors.white, fontSize: 13),
                ),
              ),
            ),
          ),
          if (_scanned)
            const Positioned.fill(
              child: ColoredBox(
                color: Colors.black38,
                child: Center(
                  child: CircularProgressIndicator(color: AppTheme.primary),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Helper: push [BarcodeScannerScreen] and return the scanned string (or null).
Future<String?> scanBarcode(BuildContext context, {String title = 'Scan Barcode'}) {
  return Navigator.push<String>(
    context,
    MaterialPageRoute(
      builder: (_) => BarcodeScannerScreen(title: title),
      fullscreenDialog: true,
    ),
  );
}
