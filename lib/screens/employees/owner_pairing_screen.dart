import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../providers/app_provider.dart';
import '../../utils/app_theme.dart';

/// Shown to the business owner. Generates a one-time pairing QR code that
/// grants the selected employee access to the Drive data file.
class OwnerPairingScreen extends StatefulWidget {
  final String employeeName;
  final String employeeEmail;

  /// When set the QR restricts the employee to this shop only.
  final String? shopId;
  final String? shopName;

  const OwnerPairingScreen({
    super.key,
    required this.employeeName,
    required this.employeeEmail,
    this.shopId,
    this.shopName,
  });

  @override
  State<OwnerPairingScreen> createState() => _OwnerPairingScreenState();
}

class _OwnerPairingScreenState extends State<OwnerPairingScreen> {
  String? _qrData;
  String? _error;
  bool _generating = false;

  @override
  void initState() {
    super.initState();
    _generate();
  }

  Future<void> _generate() async {
    setState(() {
      _generating = true;
      _error = null;
    });
    try {
      final qr = await context
          .read<AppProvider>()
          .generatePairingQr(widget.employeeEmail,
              shopId: widget.shopId, shopName: widget.shopName);
      if (mounted) setState(() => _qrData = qr);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Share Business Access')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              // Header
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.qr_code_2,
                    size: 32, color: AppTheme.primary),
              ),
              const SizedBox(height: 16),
              Text(
                'Pairing QR for ${widget.employeeName}',
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w700),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                widget.employeeEmail,
                style: TextStyle(
                    fontSize: 13, color: AppTheme.subtext(context)),
              ),
              if (widget.shopName != null) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Shop: ${widget.shopName}',
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primary),
                  ),
                ),
              ],
              const SizedBox(height: 24),

              if (_generating)
                const SizedBox(
                  height: 240,
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_error != null)
                _ErrorBox(error: _error!, onRetry: _generate)
              else if (_qrData != null)
                _QrBox(qrData: _qrData!),

              const SizedBox(height: 24),

              // Instructions
              _InstructionCard(),

              const SizedBox(height: 24),

              // Done button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Done'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QrBox extends StatelessWidget {
  final String qrData;
  const _QrBox({required this.qrData});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.card(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.outline(context)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: QrImageView(
        data: qrData,
        version: QrVersions.auto,
        size: 240,
        errorCorrectionLevel: QrErrorCorrectLevel.M,
        backgroundColor: Colors.white,
      ),
    );
  }
}

class _InstructionCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Row(
            children: [
              Icon(Icons.info_outline, size: 16, color: AppTheme.primary),
              SizedBox(width: 8),
              Text('How it works',
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: AppTheme.primary)),
            ],
          ),
          SizedBox(height: 10),
          _Step(n: '1', text: 'The employee opens BillBook and signs in with their Google account.'),
          SizedBox(height: 6),
          _Step(n: '2', text: 'They go to Settings → Connect to Business and tap Scan QR.'),
          SizedBox(height: 6),
          _Step(n: '3', text: 'They scan this code. The app gives them access to your data.'),
          SizedBox(height: 6),
          _Step(n: '4', text: 'Your invoice and client data stays exclusively in your Google Drive.'),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  final String n;
  final String text;
  const _Step({required this.n, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 18,
          height: 18,
          decoration: const BoxDecoration(
            color: AppTheme.primary,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(n,
                style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.white)),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text,
              style: TextStyle(
                  fontSize: 13, color: AppTheme.onCard(context))),
        ),
      ],
    );
  }
}

class _ErrorBox extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorBox({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 240,
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 40, color: Colors.red),
          const SizedBox(height: 12),
          Text(error,
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.subtext(context))),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
