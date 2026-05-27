import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../models/invoice_template.dart';
import '../utils/pdf_generator.dart';

class TemplatePicker extends StatelessWidget {
  final InvoiceTemplate? selected;
  final ValueChanged<InvoiceTemplate> onSelected;
  final bool showUseDefault;
  /// Templates at index >= this value show a lock badge. null = all unlocked.
  final int? lockedAfterIndex;

  const TemplatePicker({
    super.key,
    required this.selected,
    required this.onSelected,
    this.showUseDefault = false,
    this.lockedAfterIndex,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 148,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: InvoiceTemplate.values.asMap().entries.map((entry) {
          final idx = entry.key;
          final tpl = entry.value;
          final isSelected = selected == tpl;
          final isLocked =
              lockedAfterIndex != null && idx >= lockedAfterIndex!;
          return _TemplateCard(
            template: tpl,
            isSelected: isSelected,
            isLocked: isLocked,
            onTap: () => onSelected(tpl),
          );
        }).toList(),
      ),
    );
  }
}

class _TemplateCard extends StatefulWidget {
  final InvoiceTemplate template;
  final bool isSelected;
  final bool isLocked;
  final VoidCallback onTap;

  const _TemplateCard({
    required this.template,
    required this.isSelected,
    required this.isLocked,
    required this.onTap,
  });

  @override
  State<_TemplateCard> createState() => _TemplateCardState();
}

class _TemplateCardState extends State<_TemplateCard> {
  bool _previewing = false;

  Future<void> _openPreview() async {
    if (_previewing) return;
    setState(() => _previewing = true);
    try {
      final bytes = await PdfGenerator.generateSamplePdf(widget.template);
      if (!mounted) return;
      await Printing.layoutPdf(onLayout: (_) => bytes,
          name: '${widget.template.displayName} – Sample');
    } finally {
      if (mounted) setState(() => _previewing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = _schemeFor(widget.template);
    final isSelected = widget.isSelected;
    final isLocked = widget.isLocked;

    return GestureDetector(
      onTap: isLocked ? _openPreview : widget.onTap,
      child: Stack(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 130,
            margin: const EdgeInsets.only(right: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected
                    ? scheme.primary
                    : const Color(0xFFE0E0E0),
                width: isSelected ? 2 : 1,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: scheme.primary.withValues(alpha: 0.18),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      )
                    ]
                  : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Mini preview thumbnail
                ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(9)),
                  child: _MiniPreview(scheme: scheme),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 7, 8, 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              widget.template.displayName,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isSelected
                                    ? scheme.primary
                                    : const Color(0xFF212121),
                              ),
                            ),
                          ),
                          if (isSelected)
                            Icon(Icons.check_circle,
                                size: 14, color: scheme.primary),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.template.description,
                        style: const TextStyle(
                            fontSize: 10, color: Color(0xFF757575)),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Lock badge + preview hint
          if (isLocked)
            Positioned(
              top: 6,
              right: 16,
              child: _previewing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Color(0xCC000000),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.lock_outline,
                          size: 12, color: Colors.white),
                    ),
            ),
          // "Tap to preview" label at the bottom of locked cards
          if (isLocked)
            Positioned(
              left: 0,
              right: 10,
              bottom: 0,
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xCC000000),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(9),
                    bottomRight: Radius.circular(9),
                  ),
                ),
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.visibility_outlined,
                        size: 10, color: Colors.white),
                    SizedBox(width: 3),
                    Text('Tap to preview',
                        style: TextStyle(
                            fontSize: 9,
                            color: Colors.white,
                            fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  _TemplateScheme _schemeFor(InvoiceTemplate tpl) {
    switch (tpl) {
      case InvoiceTemplate.classic:
        return const _TemplateScheme(
          primary: Color(0xFF1565C0),
          header: Color(0xFF1565C0),
          accent: Colors.white,
          row1: Color(0xFFF5F5F5),
          row2: Colors.white,
        );
      case InvoiceTemplate.minimal:
        return const _TemplateScheme(
          primary: Color(0xFF212121),
          header: Colors.white,
          accent: Color(0xFF212121),
          row1: Color(0xFFFAFAFA),
          row2: Colors.white,
        );
      case InvoiceTemplate.corporate:
        return const _TemplateScheme(
          primary: Color(0xFF3899D9),
          header: Color(0xFF243040),
          accent: Color(0xFF3899D9),
          row1: Color(0xFFF5F7FF),
          row2: Colors.white,
        );
      case InvoiceTemplate.modern:
        return const _TemplateScheme(
          primary: Color(0xFF00897B),
          header: Color(0xFF00897B),
          accent: Color(0xFF00897B),
          row1: Color(0xFFE0F7F5),
          row2: Colors.white,
        );
      case InvoiceTemplate.restaurant:
        return const _TemplateScheme(
          primary: Color(0xFF781120),
          header: Color(0xFF781120),
          accent: Color(0xFFC79A1A),
          row1: Color(0xFFFDF7ED),
          row2: Colors.white,
        );
      case InvoiceTemplate.receipt:
        return const _TemplateScheme(
          primary: Color(0xFF212121),
          header: Colors.white,
          accent: Color(0xFF212121),
          row1: Color(0xFFF5F5F5),
          row2: Colors.white,
        );
      case InvoiceTemplate.professional:
        return const _TemplateScheme(
          primary: Color(0xFF1A237E),
          header: Colors.white,
          accent: Color(0xFF1A237E),
          row1: Color(0xFFEEEEEE),
          row2: Colors.white,
        );
      case InvoiceTemplate.gstBill:
        return const _TemplateScheme(
          primary: Color(0xFFE65100),
          header: Color(0xFFE65100),
          accent: Color(0xFFFFCC80),
          row1: Color(0xFFFFF3E0),
          row2: Colors.white,
        );
      case InvoiceTemplate.letterhead:
        return const _TemplateScheme(
          primary: Color(0xFF212121),
          header: Colors.white,
          accent: Color(0xFF212121),
          row1: Color(0xFFF5F5F5),
          row2: Colors.white,
        );
    }
  }
}

class _TemplateScheme {
  final Color primary;
  final Color header;
  final Color accent;
  final Color row1;
  final Color row2;

  const _TemplateScheme({
    required this.primary,
    required this.header,
    required this.accent,
    required this.row1,
    required this.row2,
  });
}

class _MiniPreview extends StatelessWidget {
  final _TemplateScheme scheme;

  const _MiniPreview({required this.scheme});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 62,
      child: CustomPaint(
        painter: _PreviewPainter(scheme: scheme),
        size: const Size(130, 62),
      ),
    );
  }
}

class _PreviewPainter extends CustomPainter {
  final _TemplateScheme scheme;

  const _PreviewPainter({required this.scheme});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Header band
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h * 0.36),
      Paint()..color = scheme.header,
    );

    // Accent strip (corporate/modern style)
    canvas.drawRect(
      Rect.fromLTWH(0, h * 0.36, w, 2),
      Paint()..color = scheme.accent,
    );

    // Alternating rows simulating table
    final rowH = (h - h * 0.36 - 2) / 3;
    for (int i = 0; i < 3; i++) {
      canvas.drawRect(
        Rect.fromLTWH(
            0, h * 0.36 + 2 + i * rowH, w, rowH),
        Paint()..color = i.isEven ? scheme.row1 : scheme.row2,
      );
    }

    // Tiny "line" hints in rows
    final linePaint = Paint()
      ..color = scheme.primary.withValues(alpha: 0.12)
      ..strokeWidth = 1;
    for (int i = 1; i < 3; i++) {
      final y = h * 0.36 + 2 + i * rowH;
      canvas.drawLine(Offset(0, y), Offset(w, y), linePaint);
    }

    // Minimal template: draw dark bold divider under header instead
    if (scheme.header == Colors.white) {
      canvas.drawRect(
        Rect.fromLTWH(0, h * 0.36, w, 2),
        Paint()..color = const Color(0xFF212121),
      );
    }
  }

  @override
  bool shouldRepaint(_PreviewPainter old) => old.scheme != scheme;
}
