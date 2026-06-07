import 'package:flutter/material.dart';
import 'package:flutter_zxing/flutter_zxing.dart';
import 'package:provider/provider.dart';
import '../../models/employee_pairing.dart';
import '../../providers/app_provider.dart';
import '../../utils/app_theme.dart';

/// Shown to an employee. Scans the owner's QR code and applies the pairing
/// so the app reads/writes from the owner's Google Drive file.
class ScanPairingScreen extends StatefulWidget {
  const ScanPairingScreen({super.key});

  @override
  State<ScanPairingScreen> createState() => _ScanPairingScreenState();
}

class _ScanPairingScreenState extends State<ScanPairingScreen> {
  bool _processing = false;

  Future<void> _onScan(Code code) async {
    if (_processing || !code.isValid || code.text == null) return;

    final pairing = EmployeePairing.fromQrString(code.text!);
    if (pairing == null) return; // not a BillBook pairing QR — ignore

    setState(() => _processing = true);

    if (!mounted) return;

    final confirmed = await _showConfirmDialog(pairing);
    if (!confirmed) {
      if (mounted) setState(() => _processing = false);
      return;
    }

    if (!mounted) return;

    final error = await context.read<AppProvider>().applyPairing(pairing);
    if (!mounted) return;

    if (error != null) {
      // Pairing is always saved even when sync fails, so the employee
      // doesn't need to re-scan. Guide them to fix the root cause.
      final String message;
      if (error.contains('403') || error.contains('forbidden') || error.contains('Forbidden')) {
        message = 'Connected, but Drive access was denied. '
            'Sign out and sign back in — your account needs full Drive '
            'permission to access shared business data.';
      } else if (error == 'decryption_failed') {
        message = 'QR code key does not match the business file. '
            'Ask your employer to generate a fresh QR code.';
      } else if (error == 'parse_failed') {
        message = 'Business data is corrupt. Ask your employer to check their Drive file.';
      } else {
        message = 'Connected, but data could not be loaded ($error). '
            'It will sync automatically when you are online.';
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: Colors.orange.shade800,
        duration: const Duration(seconds: 8),
      ));
      // Still navigate away — pairing is persisted and will retry on next launch.
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Connected! You are now viewing the business data.'),
      ));
      Navigator.pop(context, true);
    }
  }

  Future<bool> _showConfirmDialog(EmployeePairing pairing) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Connect to Business?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('You are about to connect to:'),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.business,
                      color: AppTheme.primary, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      pairing.ownerEmail,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 12),
            Text(
              'Your own data stays separate and is restored when you disconnect.',
              style: TextStyle(
                  fontSize: 12, color: AppTheme.subtext(context)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Connect'),
          ),
        ],
      ),
    );
    return ok == true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan Pairing QR')),
      body: Stack(
        children: [
          ReaderWidget(
            onScan: _processing ? null : _onScan,
            codeFormat: Format.qrCode,
            showFlashlight: true,
            showToggleCamera: false,
            showGallery: false,
            scanDelay: const Duration(milliseconds: 600),
            scanDelaySuccess: const Duration(milliseconds: 1500),
            cropPercent: 0.6,
          ),
          if (_processing)
            const Positioned.fill(
              child: ColoredBox(
                color: Colors.black38,
                child: Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
