import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/stock_transfer.dart';
import '../providers/app_provider.dart';
import '../utils/app_theme.dart';
import '../utils/formatters.dart';

class StockTransferScreen extends StatefulWidget {
  const StockTransferScreen({super.key});

  @override
  State<StockTransferScreen> createState() => _StockTransferScreenState();
}

class _StockTransferScreenState extends State<StockTransferScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    // Register this shop so others can discover it
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppProvider>().registerShop().catchError((_) {});
    });
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      appBar: AppBar(
        title: const Text('Stock Transfers'),
        bottom: TabBar(
          controller: _tab,
          tabs: const [
            Tab(text: 'Incoming'),
            Tab(text: 'Send'),
            Tab(text: 'History'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: const [
          _IncomingTab(),
          _SendTab(),
          _HistoryTab(),
        ],
      ),
    );
  }
}

// ─── Incoming transfers ───────────────────────────────────────────────────────

class _IncomingTab extends StatelessWidget {
  const _IncomingTab();

  @override
  Widget build(BuildContext context) {
    final transfers = context.watch<AppProvider>().incomingTransfers;
    if (transfers.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_outlined,
                size: 48, color: AppTheme.subtext(context)),
            const SizedBox(height: 12),
            Text('No pending transfers',
                style:
                    TextStyle(color: AppTheme.subtext(context), fontSize: 14)),
            const SizedBox(height: 6),
            Text('Ask the other shop to send stock to this shop.',
                style: TextStyle(
                    color: AppTheme.subtext(context), fontSize: 12),
                textAlign: TextAlign.center),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: transfers.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (ctx, i) =>
          _TransferCard(transfer: transfers[i], isIncoming: true),
    );
  }
}

// ─── Send transfer ────────────────────────────────────────────────────────────

class _SendTab extends StatefulWidget {
  const _SendTab();

  @override
  State<_SendTab> createState() => _SendTabState();
}

class _SendTabState extends State<_SendTab> {
  ShopInfo? _targetShop;
  List<ShopInfo> _linkedShops = [];
  bool _loadingShops = true;
  String? _shopError;

  // Selected items: itemId (or itemId+variantId) → qty
  final Map<String, _PickedItem> _picked = {};
  final TextEditingController _noteCtrl = TextEditingController();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _loadShops();
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadShops() async {
    setState(() { _loadingShops = true; _shopError = null; });
    try {
      final shops = await context.read<AppProvider>().getLinkedShops();
      if (mounted) setState(() { _linkedShops = shops; _loadingShops = false; });
    } catch (e) {
      if (mounted) setState(() { _shopError = e.toString(); _loadingShops = false; });
    }
  }

  Future<void> _send() async {
    if (_targetShop == null || _picked.isEmpty) return;
    final items = _picked.values
        .where((p) => p.qty > 0)
        .map((p) => TransferItem(
              itemName: p.displayName,
              itemId: p.itemId,
              variantId: p.variantId,
              variantName: p.variantName,
              quantity: p.qty,
            ))
        .toList();
    if (items.isEmpty) return;

    setState(() => _sending = true);
    try {
      await context.read<AppProvider>().sendStockTransfer(
            toShopId: _targetShop!.shopId,
            toShopName: _targetShop!.shopName,
            items: items,
            note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
          );
      if (!mounted) return;
      setState(() { _picked.clear(); _targetShop = null; _noteCtrl.clear(); });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Transfer sent successfully'),
            backgroundColor: AppTheme.success),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final shopId = provider.currentShopId;
    final trackedItems = provider.serviceItems
        .where((s) => s.isTrackingStock || s.variants.any((v) => v.isTrackingStock))
        .toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── Target shop ─────────────────────────────────────────────────────
        _SectionHeader(
          icon: Icons.store_outlined,
          title: 'Destination Shop',
          trailing: TextButton.icon(
            onPressed: _loadShops,
            icon: const Icon(Icons.refresh, size: 14),
            label: const Text('Refresh', style: TextStyle(fontSize: 12)),
          ),
        ),
        const SizedBox(height: 8),
        if (_loadingShops)
          const Center(
              child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator()))
        else if (_shopError != null)
          _ErrorCard(message: _shopError!, onRetry: _loadShops)
        else if (_linkedShops.isEmpty)
          _InfoCard(
            icon: Icons.link_off,
            message:
                'No other shops found.\nLog in with the same email on your other device — it will appear here automatically.',
          )
        else
          ..._linkedShops.map((shop) {
            final selected = _targetShop?.shopId == shop.shopId;
            return GestureDetector(
              onTap: () => setState(() => _targetShop = shop),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: selected
                      ? AppTheme.primary.withValues(alpha: 0.08)
                      : AppTheme.card(context),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: selected
                        ? AppTheme.primary
                        : AppTheme.outline(context),
                    width: selected ? 1.5 : 0.8,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.storefront,
                        size: 20,
                        color: selected
                            ? AppTheme.primary
                            : AppTheme.subtext(context)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(shop.shopName,
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: selected
                                  ? AppTheme.primary
                                  : AppTheme.onCard(context))),
                    ),
                    if (selected)
                      const Icon(Icons.check_circle,
                          size: 18, color: AppTheme.primary),
                  ],
                ),
              ),
            );
          }),

        const SizedBox(height: 20),

        // ── Items ────────────────────────────────────────────────────────────
        _SectionHeader(
          icon: Icons.inventory_2_outlined,
          title: 'Items to Transfer',
        ),
        const SizedBox(height: 8),
        if (trackedItems.isEmpty)
          _InfoCard(
            icon: Icons.info_outline,
            message:
                'No tracked items found. Enable stock tracking in Settings → Products.',
          )
        else
          ...trackedItems.expand((item) {
            if (item.hasVariants) {
              return item.variants
                  .where((v) => v.isTrackingStock)
                  .map((v) => _ItemPickRow(
                        key: ValueKey('${item.id}_${v.id}'),
                        pickedKey: '${item.id}_${v.id}',
                        label: '${item.name} — ${v.name}',
                        available: v.stockFor(shopId),
                        initialQty:
                            _picked['${item.id}_${v.id}']?.qty ?? 0,
                        onChanged: (qty) => setState(() {
                          if (qty <= 0) {
                            _picked.remove('${item.id}_${v.id}');
                          } else {
                            _picked['${item.id}_${v.id}'] = _PickedItem(
                              itemId: item.id,
                              variantId: v.id,
                              variantName: v.name,
                              displayName: '${item.name} (${v.name})',
                              qty: qty,
                            );
                          }
                        }),
                      ));
            } else {
              return [
                _ItemPickRow(
                  key: ValueKey(item.id),
                  pickedKey: item.id,
                  label: item.name,
                  available: item.stockFor(shopId),
                  initialQty: _picked[item.id]?.qty ?? 0,
                  onChanged: (qty) => setState(() {
                    if (qty <= 0) {
                      _picked.remove(item.id);
                    } else {
                      _picked[item.id] = _PickedItem(
                        itemId: item.id,
                        displayName: item.name,
                        qty: qty,
                      );
                    }
                  }),
                )
              ];
            }
          }),

        const SizedBox(height: 16),

        // ── Note ─────────────────────────────────────────────────────────────
        TextField(
          controller: _noteCtrl,
          decoration: InputDecoration(
            labelText: 'Note (optional)',
            hintText: 'e.g. Monthly restock',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            prefixIcon: const Icon(Icons.notes_outlined),
          ),
          maxLines: 2,
        ),

        const SizedBox(height: 20),

        // ── Summary + send ────────────────────────────────────────────────────
        if (_picked.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${_picked.length} item(s) selected',
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13)),
                ..._picked.values.map((p) => Text(
                      '• ${p.displayName}: ${_fmtQty(p.qty)}',
                      style: const TextStyle(fontSize: 12),
                    )),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        ElevatedButton.icon(
          onPressed: (_targetShop != null && _picked.isNotEmpty && !_sending)
              ? _send
              : null,
          icon: _sending
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.send_outlined),
          label: Text(_sending ? 'Sending…' : 'Send Transfer'),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            backgroundColor: AppTheme.primary,
            foregroundColor: Colors.white,
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }
}

// ─── History ──────────────────────────────────────────────────────────────────

class _HistoryTab extends StatefulWidget {
  const _HistoryTab();

  @override
  State<_HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<_HistoryTab> {
  List<StockTransfer>? _history;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final h = await context.read<AppProvider>().getTransferHistory();
      if (mounted) setState(() { _history = h; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return _ErrorCard(message: _error!, onRetry: _load);
    }
    final list = _history ?? [];
    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history, size: 48, color: AppTheme.subtext(context)),
            const SizedBox(height: 12),
            Text('No transfer history',
                style:
                    TextStyle(color: AppTheme.subtext(context), fontSize: 14)),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: list.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (ctx, i) {
          final myId = ctx.read<AppProvider>().currentShopId ?? '';
          final isOutgoing = list[i].fromShopId == myId;
          return _TransferCard(transfer: list[i], isIncoming: !isOutgoing);
        },
      ),
    );
  }
}

// ─── Transfer card ────────────────────────────────────────────────────────────

class _TransferCard extends StatelessWidget {
  final StockTransfer transfer;
  final bool isIncoming;
  const _TransferCard({required this.transfer, required this.isIncoming});

  Color _statusColor(TransferStatus s) => switch (s) {
        TransferStatus.pending => Colors.orange,
        TransferStatus.accepted => AppTheme.success,
        TransferStatus.rejected => AppTheme.error,
        TransferStatus.cancelled => Colors.grey,
      };

  String _statusLabel(TransferStatus s) => switch (s) {
        TransferStatus.pending => 'Pending',
        TransferStatus.accepted => 'Accepted',
        TransferStatus.rejected => 'Rejected',
        TransferStatus.cancelled => 'Cancelled',
      };

  @override
  Widget build(BuildContext context) {
    final t = transfer;
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.card(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.outline(context), width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Row(
              children: [
                Icon(
                  isIncoming ? Icons.call_received : Icons.call_made,
                  size: 16,
                  color: isIncoming ? AppTheme.success : AppTheme.primary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    isIncoming
                        ? 'From: ${t.fromShopName}'
                        : 'To: ${t.toShopName}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                ),
                _StatusChip(
                    label: _statusLabel(t.status),
                    color: _statusColor(t.status)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    Fmt.date(t.createdAt),
                    style: TextStyle(
                        fontSize: 11, color: AppTheme.subtext(context)),
                  ),
                ),
                if (isIncoming)
                  Text('To: ${t.toShopName}',
                      style: TextStyle(
                          fontSize: 11, color: AppTheme.subtext(context))),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Items
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: t.items
                  .map((i) => Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: Row(
                          children: [
                            const Icon(Icons.circle,
                                size: 5, color: Colors.grey),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(i.itemName,
                                  style: const TextStyle(fontSize: 12)),
                            ),
                            Text(_fmtQty(i.quantity),
                                style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ))
                  .toList(),
            ),
          ),
          if (t.note != null) ...[
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Text('Note: ${t.note}',
                  style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.subtext(context),
                      fontStyle: FontStyle.italic)),
            ),
          ],
          // Accept / Reject buttons (incoming pending only)
          if (isIncoming && t.status == TransferStatus.pending) ...[
            const Divider(height: 16),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () =>
                          _respond(context, TransferStatus.rejected),
                      style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.error,
                          side:
                              const BorderSide(color: AppTheme.error)),
                      child: const Text('Reject'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () =>
                          _respond(context, TransferStatus.accepted),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.success,
                          foregroundColor: Colors.white),
                      child: const Text('Accept'),
                    ),
                  ),
                ],
              ),
            ),
          ] else
            const SizedBox(height: 12),
        ],
      ),
    );
  }

  Future<void> _respond(BuildContext context, TransferStatus status) async {
    final provider = context.read<AppProvider>();
    try {
      if (status == TransferStatus.accepted) {
        await provider.acceptStockTransfer(transfer);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Transfer accepted — stock updated'),
              backgroundColor: AppTheme.success));
        }
      } else {
        await provider.rejectStockTransfer(transfer);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Transfer rejected')));
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error));
      }
    }
  }
}

// ─── Item pick row ────────────────────────────────────────────────────────────

class _ItemPickRow extends StatefulWidget {
  final String pickedKey;
  final String label;
  final double available;
  final double initialQty;
  final ValueChanged<double> onChanged;

  const _ItemPickRow({
    super.key,
    required this.pickedKey,
    required this.label,
    required this.available,
    required this.initialQty,
    required this.onChanged,
  });

  @override
  State<_ItemPickRow> createState() => _ItemPickRowState();
}

class _ItemPickRowState extends State<_ItemPickRow> {
  late TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(
        text: widget.initialQty > 0 ? _fmtQty(widget.initialQty) : '');
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.card(context),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.outline(context), width: 0.8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.label,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w500)),
                Text('Available: ${_fmtQty(widget.available)}',
                    style: TextStyle(
                        fontSize: 11, color: AppTheme.subtext(context))),
              ],
            ),
          ),
          SizedBox(
            width: 80,
            child: TextField(
              controller: _ctrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                hintText: '0',
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onChanged: (v) {
                final qty = double.tryParse(v.trim()) ?? 0;
                widget.onChanged(qty.clamp(0, widget.available));
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Helpers & small widgets ──────────────────────────────────────────────────

class _PickedItem {
  final String itemId;
  final String? variantId;
  final String? variantName;
  final String displayName;
  final double qty;

  const _PickedItem({
    required this.itemId,
    this.variantId,
    this.variantName,
    required this.displayName,
    required this.qty,
  });
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget? trailing;
  const _SectionHeader(
      {required this.icon, required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppTheme.primary),
        const SizedBox(width: 8),
        Text(title,
            style: const TextStyle(
                fontWeight: FontWeight.w700, fontSize: 14)),
        if (trailing != null) ...[const Spacer(), trailing!],
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String message;
  const _InfoCard({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.card(context),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.outline(context), width: 0.8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppTheme.subtext(context)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message,
                style: TextStyle(
                    fontSize: 12, color: AppTheme.subtext(context))),
          ),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorCard({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off, size: 40, color: AppTheme.subtext(context)),
          const SizedBox(height: 12),
          Text('Could not connect',
              style: TextStyle(
                  fontWeight: FontWeight.w600, color: AppTheme.error)),
          const SizedBox(height: 4),
          Text(message,
              style:
                  TextStyle(fontSize: 11, color: AppTheme.subtext(context)),
              textAlign: TextAlign.center),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

String _fmtQty(double q) =>
    q % 1 == 0 ? q.toInt().toString() : q.toStringAsFixed(2);
