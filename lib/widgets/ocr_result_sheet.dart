import 'package:flutter/material.dart';
import '../utils/app_theme.dart';

/// A single extracted field shown in the OCR result sheet.
class OcrField {
  final String key;
  final String label;
  final String displayValue;
  /// The typed value the caller will receive when this field is applied
  /// (e.g., a [double] for amount, [DateTime] for date, [String] for text).
  final Object rawValue;

  const OcrField({
    required this.key,
    required this.label,
    required this.displayValue,
    required this.rawValue,
  });
}

/// Bottom sheet that shows OCR-extracted fields with per-field toggles.
/// Calls [onApply] with a map of `key → rawValue` for every checked field.
class OcrResultSheet extends StatefulWidget {
  final List<OcrField> fields;
  final void Function(Map<String, Object> selected) onApply;

  const OcrResultSheet({
    super.key,
    required this.fields,
    required this.onApply,
  });

  @override
  State<OcrResultSheet> createState() => _OcrResultSheetState();
}

class _OcrResultSheetState extends State<OcrResultSheet> {
  late final Set<String> _checked;

  @override
  void initState() {
    super.initState();
    _checked = widget.fields.map((f) => f.key).toSet();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.document_scanner_outlined,
                      color: AppTheme.primary, size: 20),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Receipt Scan Results',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700)),
                      Text('Select fields to auto-fill',
                          style: TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            ...widget.fields.map((f) => _FieldRow(
                  field: f,
                  checked: _checked.contains(f.key),
                  onToggle: (v) => setState(
                      () => v ? _checked.add(f.key) : _checked.remove(f.key)),
                )),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Skip'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    onPressed: _checked.isEmpty
                        ? null
                        : () {
                            final result = <String, Object>{};
                            for (final f in widget.fields) {
                              if (_checked.contains(f.key)) {
                                result[f.key] = f.rawValue;
                              }
                            }
                            Navigator.pop(context);
                            widget.onApply(result);
                          },
                    icon: const Icon(Icons.auto_fix_high, size: 16),
                    label: const Text('Apply Fields'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FieldRow extends StatelessWidget {
  final OcrField field;
  final bool checked;
  final ValueChanged<bool> onToggle;

  const _FieldRow({
    required this.field,
    required this.checked,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onToggle(!checked),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Checkbox(
              value: checked,
              onChanged: (v) => onToggle(v ?? false),
              activeColor: AppTheme.primary,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(field.label,
                  style: TextStyle(
                      fontSize: 13, color: AppTheme.subtext(context))),
            ),
            Text(
              field.displayValue,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: checked ? AppTheme.primary : AppTheme.onCard(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact card used inside forms to attach a receipt image.
/// Shows an image picker trigger (camera + gallery) when empty,
/// and a thumbnail + actions (change / scan / remove) when filled.
class ReceiptCard extends StatelessWidget {
  final String? imageBase64;
  final bool scanning;
  final VoidCallback onCamera;
  final VoidCallback onGallery;
  final VoidCallback? onScan;   // null while scanning or no image
  final VoidCallback onRemove;

  const ReceiptCard({
    super.key,
    required this.imageBase64,
    required this.scanning,
    required this.onCamera,
    required this.onGallery,
    this.onScan,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    if (imageBase64 == null) {
      return _EmptyCard(onCamera: onCamera, onGallery: onGallery);
    }
    return _FilledCard(
      imageBase64: imageBase64!,
      scanning: scanning,
      onCamera: onCamera,
      onGallery: onGallery,
      onScan: onScan,
      onRemove: onRemove,
    );
  }
}

class _EmptyCard extends StatelessWidget {
  final VoidCallback onCamera;
  final VoidCallback onGallery;

  const _EmptyCard({required this.onCamera, required this.onGallery});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.card(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.primary.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _ActionButton(
              icon: Icons.camera_alt_outlined,
              label: 'Camera',
              onTap: onCamera,
              borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(12)),
            ),
          ),
          Container(width: 1, height: 52, color: AppTheme.primary.withValues(alpha: 0.2)),
          Expanded(
            child: _ActionButton(
              icon: Icons.photo_library_outlined,
              label: 'Gallery',
              onTap: onGallery,
              borderRadius: const BorderRadius.horizontal(
                  right: Radius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilledCard extends StatelessWidget {
  final String imageBase64;
  final bool scanning;
  final VoidCallback onCamera;
  final VoidCallback onGallery;
  final VoidCallback? onScan;
  final VoidCallback onRemove;

  const _FilledCard({
    required this.imageBase64,
    required this.scanning,
    required this.onCamera,
    required this.onGallery,
    this.onScan,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.card(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.outline(context)),
      ),
      child: Row(
        children: [
          // Thumbnail
          ClipRRect(
            borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(11)),
            child: Image.memory(
              Uri.parse('data:image/jpeg;base64,$imageBase64')
                  .data!
                  .contentAsBytes(),
              width: 72,
              height: 72,
              fit: BoxFit.cover,
              errorBuilder: (ctx, err, stack) => Container(
                width: 72,
                height: 72,
                color: AppTheme.primary.withValues(alpha: 0.1),
                child: const Icon(Icons.image_outlined,
                    color: AppTheme.primary),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Receipt attached',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.onCard(context))),
                const SizedBox(height: 4),
                if (scanning)
                  Row(children: [
                    const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppTheme.primary)),
                    const SizedBox(width: 8),
                    Text('Scanning…',
                        style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.subtext(context))),
                  ])
                else
                  Row(children: [
                    _Chip(
                      icon: Icons.document_scanner_outlined,
                      label: 'Scan & Fill',
                      onTap: onScan,
                    ),
                    const SizedBox(width: 6),
                    _Chip(
                      icon: Icons.edit_outlined,
                      label: 'Change',
                      onTap: () => _showPicker(context),
                    ),
                  ]),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.close, size: 18, color: AppTheme.subtext(context)),
            onPressed: onRemove,
            tooltip: 'Remove receipt',
          ),
        ],
      ),
    );
  }

  void _showPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Take photo'),
              onTap: () { Navigator.pop(context); onCamera(); },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () { Navigator.pop(context); onGallery(); },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final BorderRadius borderRadius;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: borderRadius,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22, color: AppTheme.primary),
            const SizedBox(height: 4),
            Text(label,
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primary)),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _Chip({required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppTheme.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: AppTheme.primary),
            const SizedBox(width: 4),
            Text(label,
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primary)),
          ],
        ),
      ),
    );
  }
}
