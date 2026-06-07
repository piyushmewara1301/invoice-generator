import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../models/business_profile.dart';
import '../../providers/app_provider.dart';
import '../../services/auth_service.dart';
import '../../services/drive_service.dart';
import '../../services/verification_service.dart';
import '../../utils/app_theme.dart';

class VerificationScreen extends StatefulWidget {
  const VerificationScreen({super.key});

  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  final _codeController = TextEditingController();
  final _notesController = TextEditingController();
  final _picker = ImagePicker();

  final List<XFile> _pickedFiles = [];
  bool _uploading = false;
  bool _checkingStatus = false;
  bool _validatingCode = false;
  String? _codeError;

  @override
  void initState() {
    super.initState();
    // Poll Firestore in case admin has updated our status since last launch.
    WidgetsBinding.instance.addPostFrameCallback((_) => _pollStatus());
  }

  Future<void> _pollStatus() async {
    setState(() => _checkingStatus = true);
    await context.read<AppProvider>().refreshVerificationStatus();
    if (mounted) setState(() => _checkingStatus = false);
  }

  @override
  void dispose() {
    _codeController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDocument() async {
    if (_pickedFiles.length >= 3) return;
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (file != null) {
      setState(() => _pickedFiles.add(file));
    }
  }

  Future<void> _submitRequest() async {
    final appProvider = context.read<AppProvider>();
    final auth = context.read<AuthService>();
    final userEmail = auth.user?.email ?? '';

    if (_pickedFiles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload at least one document.')),
      );
      return;
    }

    setState(() => _uploading = true);

    try {
      final httpClient = await auth.getAuthClient();
      final driveLinks = <String>[];

      if (httpClient != null) {
        final driveService = DriveService(httpClient);
        for (int i = 0; i < _pickedFiles.length; i++) {
          final bytes = await File(_pickedFiles[i].path).readAsBytes();
          final link = await driveService.uploadVerificationDocument(
            bytes,
            'verification_doc_${i + 1}.jpg',
            'image/jpeg',
          );
          driveLinks.add(link);
        }
      }

      final profile = appProvider.profile;
      final notes = _notesController.text.trim();

      // Submit to Firestore so the admin app can see it.
      final firestoreError = await VerificationService.submitRequest(
        userEmail: userEmail,
        businessName: profile.name,
        driveLinks: driveLinks,
        notes: notes.isNotEmpty ? notes : null,
      );

      if (!mounted) return;

      if (firestoreError != null) {
        setState(() => _uploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not reach Firestore: $firestoreError'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 8),
          ),
        );
        return;
      }

      profile.verificationStatus = VerificationStatus.pending;
      profile.verificationNotes = notes.isNotEmpty ? notes : null;
      profile.verificationSubmittedAt = DateTime.now().toIso8601String();
      await appProvider.updateProfile(profile);

      if (!mounted) return;
      setState(() => _uploading = false);
      _showSubmittedDialog(userEmail, Uri.encodeComponent(
        'Business Verification Request\n\n'
        'Business: ${profile.name}\nEmail: $userEmail\n\n'
        'Documents:\n${driveLinks.isNotEmpty ? driveLinks.join("\n") : "Attached separately"}\n\n'
        'Notes: ${notes.isNotEmpty ? notes : "None"}',
      ));
    } catch (e) {
      if (!mounted) return;
      setState(() => _uploading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload failed: $e')),
      );
    }
  }

  void _showSubmittedDialog(String userEmail, String emailBody) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Request Submitted'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your verification request has been saved. '
              'Please send the details to our admin for review.',
            ),
            SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.alternate_email,
                      size: 16, color: AppTheme.subtext(context)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'admin@invoiceapp.com',
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _validateCode() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      setState(() => _codeError = 'Enter the code you received.');
      return;
    }
    final userEmail = context.read<AuthService>().user?.email ?? '';
    setState(() {
      _validatingCode = true;
      _codeError = null;
    });

    // Small artificial delay so the spinner is visible
    await Future.delayed(const Duration(milliseconds: 400));

    final result = VerificationService.validateCode(code, userEmail);
    if (!mounted) return;

    if (result == null) {
      setState(() {
        _validatingCode = false;
        _codeError = 'Invalid or expired code. Please try again.';
      });
      return;
    }

    final appProvider = context.read<AppProvider>();
    final profile = appProvider.profile;
    profile.verificationStatus = result;
    await appProvider.updateProfile(profile);

    setState(() => _validatingCode = false);
    _codeController.clear();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result == VerificationStatus.verified
            ? 'Your business is now verified!'
            : 'Status updated: ${result.name}'),
        backgroundColor: result == VerificationStatus.verified
            ? AppTheme.success
            : AppTheme.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<AppProvider>().profile;
    final status = profile.verificationStatus;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Business Verification'),
        actions: [
          if (_checkingStatus)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _StatusCard(status: status),
          const SizedBox(height: 20),
          if (status == VerificationStatus.verified) ...[
            _InfoCard(
              icon: Icons.verified,
              color: AppTheme.success,
              title: 'Your business is verified',
              body:
                  'Your invoices will show a verified badge. Thank you for completing verification.',
            ),
          ] else ...[
            // Code entry — always visible so user can enter code at any time
            _CodeEntrySection(
              controller: _codeController,
              error: _codeError,
              loading: _validatingCode,
              onValidate: _validateCode,
            ),
            const SizedBox(height: 20),
            if (status == VerificationStatus.pending) ...[
              _InfoCard(
                icon: Icons.hourglass_top_outlined,
                color: AppTheme.warning,
                title: 'Under review',
                body:
                    'Your documents are being reviewed. You will receive a verification code once the review is complete.',
              ),
              const SizedBox(height: 20),
              _CancelButton(onCancel: () async {
                final profile = context.read<AppProvider>().profile;
                profile.verificationStatus = VerificationStatus.unverified;
                profile.verificationSubmittedAt = null;
                profile.verificationNotes = null;
                await context.read<AppProvider>().updateProfile(profile);
                setState(() {});
              }),
            ] else ...[
              if (status == VerificationStatus.rejected)
                _InfoCard(
                  icon: Icons.cancel_outlined,
                  color: AppTheme.error,
                  title: 'Verification rejected',
                  body:
                      'Your previous request was not approved. Please re-submit with valid documents.',
                ),
              SizedBox(height: status == VerificationStatus.rejected ? 20 : 0),
              _SubmitSection(
                pickedFiles: _pickedFiles,
                notesController: _notesController,
                uploading: _uploading,
                onPickDocument: _pickDocument,
                onRemoveDocument: (i) =>
                    setState(() => _pickedFiles.removeAt(i)),
                onSubmit: _submitRequest,
              ),
            ],
          ],
          const SizedBox(height: 32),
          _WhatHappensSection(),
        ],
      ),
    );
  }
}

// ── Status banner ─────────────────────────────────────────────────────────────

class _StatusCard extends StatelessWidget {
  final VerificationStatus status;
  const _StatusCard({required this.status});

  @override
  Widget build(BuildContext context) {
    final cfg = _statusConfig(context, status);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cfg.color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cfg.color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: cfg.color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(cfg.icon, color: cfg.color, size: 22),
          ),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(cfg.label,
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: cfg.color,
                        fontSize: 15)),
                SizedBox(height: 2),
                Text(cfg.description,
                    style: TextStyle(
                        fontSize: 12, color: AppTheme.subtext(context))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  ({IconData icon, Color color, String label, String description})
      _statusConfig(BuildContext context, VerificationStatus s) {
    switch (s) {
      case VerificationStatus.unverified:
        return (
          icon: Icons.shield_outlined,
          color: AppTheme.subtext(context),
          label: 'Not Verified',
          description: 'Submit documents to get your business verified.',
        );
      case VerificationStatus.pending:
        return (
          icon: Icons.hourglass_top_outlined,
          color: AppTheme.warning,
          label: 'Under Review',
          description: 'Your request is being reviewed by our team.',
        );
      case VerificationStatus.verified:
        return (
          icon: Icons.verified,
          color: AppTheme.success,
          label: 'Verified',
          description: 'Your business identity has been confirmed.',
        );
      case VerificationStatus.rejected:
        return (
          icon: Icons.cancel_outlined,
          color: AppTheme.error,
          label: 'Rejected',
          description: 'Review did not pass. Please re-submit.',
        );
    }
  }
}

// ── Info card ─────────────────────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String body;
  const _InfoCard(
      {required this.icon,
      required this.color,
      required this.title,
      required this.body});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.card(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.outline(context)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: color)),
                SizedBox(height: 4),
                Text(body,
                    style: TextStyle(
                        fontSize: 13, color: AppTheme.subtext(context),
                        height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Code entry ────────────────────────────────────────────────────────────────

class _CodeEntrySection extends StatelessWidget {
  final TextEditingController controller;
  final String? error;
  final bool loading;
  final VoidCallback onValidate;

  const _CodeEntrySection({
    required this.controller,
    required this.error,
    required this.loading,
    required this.onValidate,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.card(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.outline(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Have a verification code?',
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: AppTheme.onCard(context))),
          SizedBox(height: 4),
          Text(
            'Once the admin reviews your request, they will send you a code.',
            style: TextStyle(fontSize: 12, color: AppTheme.subtext(context)),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    hintText: 'Enter code (e.g. ABCD1234EFGH5678)',
                    errorText: error,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 42,
                child: loading
                    ? const Center(
                        child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2)))
                    : FilledButton(
                        onPressed: onValidate,
                        style: FilledButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8))),
                        child: const Text('Apply'),
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Submit section ────────────────────────────────────────────────────────────

class _SubmitSection extends StatelessWidget {
  final List<XFile> pickedFiles;
  final TextEditingController notesController;
  final bool uploading;
  final VoidCallback onPickDocument;
  final void Function(int) onRemoveDocument;
  final VoidCallback onSubmit;

  const _SubmitSection({
    required this.pickedFiles,
    required this.notesController,
    required this.uploading,
    required this.onPickDocument,
    required this.onRemoveDocument,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.card(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.outline(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Submit for verification',
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: AppTheme.onCard(context))),
          SizedBox(height: 4),
          Text(
            'Upload photos of your business documents (GST certificate, '
            'trade licence, incorporation certificate, etc.).',
            style: TextStyle(
                fontSize: 12, color: AppTheme.subtext(context), height: 1.4),
          ),
          const SizedBox(height: 14),

          // Document thumbnails + add button
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (int i = 0; i < pickedFiles.length; i++)
                _DocumentThumb(
                    file: pickedFiles[i],
                    onRemove: () => onRemoveDocument(i)),
              if (pickedFiles.length < 3)
                _AddDocButton(onTap: onPickDocument),
            ],
          ),

          const SizedBox(height: 14),
          TextField(
            controller: notesController,
            maxLines: 2,
            decoration: InputDecoration(
              hintText: 'Additional notes (optional)',
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              isDense: true,
            ),
          ),

          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: FilledButton.icon(
              onPressed: uploading ? null : onSubmit,
              icon: uploading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child:
                          CircularProgressIndicator(strokeWidth: 2,
                              color: Colors.white))
                  : const Icon(Icons.upload_outlined, size: 18),
              label: Text(uploading ? 'Uploading…' : 'Submit Request'),
              style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10))),
            ),
          ),
        ],
      ),
    );
  }
}

class _DocumentThumb extends StatelessWidget {
  final XFile file;
  final VoidCallback onRemove;
  const _DocumentThumb({required this.file, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.file(File(file.path),
              width: 72, height: 72, fit: BoxFit.cover),
        ),
        Positioned(
          top: 0,
          right: 0,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              width: 20,
              height: 20,
              decoration: const BoxDecoration(
                  color: Colors.red, shape: BoxShape.circle),
              child:
                  const Icon(Icons.close, size: 12, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}

class _AddDocButton extends StatelessWidget {
  final VoidCallback onTap;
  const _AddDocButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: AppTheme.outline(context), style: BorderStyle.solid),
        ),
        child: Icon(Icons.add_photo_alternate_outlined,
            color: AppTheme.subtext(context), size: 28),
      ),
    );
  }
}

class _CancelButton extends StatelessWidget {
  final VoidCallback onCancel;
  const _CancelButton({required this.onCancel});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onCancel,
      icon: const Icon(Icons.cancel_outlined, size: 16),
      label: const Text('Cancel Request'),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppTheme.error,
        side: BorderSide(color: AppTheme.error.withValues(alpha: 0.4)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

// ── What happens section ──────────────────────────────────────────────────────

class _WhatHappensSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.card(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.outline(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('How verification works',
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: AppTheme.onCard(context))),
          const SizedBox(height: 12),
          _step(context, '1', 'Upload documents',
              'Photos of your GST certificate, trade licence, or other business proof.'),
          _step(context, '2', 'Admin review',
              'Our team reviews your submission within 2–3 business days.'),
          _step(context, '3', 'Receive code',
              'Once approved, you\'ll receive a verification code to enter above.'),
          _step(context, '4', 'Verified badge',
              'Your invoices will no longer show the unverified disclaimer.'),
        ],
      ),
    );
  }

  Widget _step(BuildContext context, String num, String title, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(num,
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primary)),
            ),
          ),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.onCard(context))),
                Text(desc,
                    style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.subtext(context),
                        height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
