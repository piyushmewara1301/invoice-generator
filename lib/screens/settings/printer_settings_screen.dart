import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:flutter/material.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

import '../../services/thermal_printer_service.dart';
import '../../utils/app_theme.dart';

class PrinterSettingsScreen extends StatefulWidget {
  const PrinterSettingsScreen({super.key});

  @override
  State<PrinterSettingsScreen> createState() => _PrinterSettingsScreenState();
}

class _PrinterSettingsScreenState extends State<PrinterSettingsScreen> {
  SavedPrinter? _saved;
  PaperSize _paperSize = PaperSize.mm58;
  List<BluetoothInfo> _devices = [];
  bool _scanning = false;
  bool _connectedNow = false;
  String? _connectingMac;
  bool _testing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final saved = await ThermalPrinterService.getSavedPrinter();
    final paperSize = await ThermalPrinterService.getPaperWidth();
    final connected = await ThermalPrinterService.isConnected;
    if (!mounted) return;
    setState(() {
      _saved = saved;
      _paperSize = paperSize;
      _connectedNow = connected;
    });
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppTheme.error : AppTheme.success,
      ),
    );
  }

  Future<void> _scan() async {
    setState(() => _scanning = true);
    try {
      final granted = await ThermalPrinterService.requestPermissions();
      if (!granted) {
        _showMessage(
            'Bluetooth permission is required to find printers.',
            isError: true);
        return;
      }
      final enabled = await ThermalPrinterService.isBluetoothEnabled;
      if (!enabled) {
        _showMessage('Please turn on Bluetooth and try again.',
            isError: true);
        return;
      }
      final devices = await ThermalPrinterService.getPairedDevices();
      if (!mounted) return;
      setState(() => _devices = devices);
      if (devices.isEmpty) {
        _showMessage(
            'No paired printers found. Pair your printer in system Bluetooth settings first.');
      }
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  Future<void> _selectDevice(BluetoothInfo device) async {
    setState(() => _connectingMac = device.macAdress);
    try {
      final connected = await ThermalPrinterService.connect(device.macAdress);
      if (!connected) {
        _showMessage('Could not connect to ${device.name}.', isError: true);
        return;
      }
      await ThermalPrinterService.saveDefaultPrinter(device);
      if (!mounted) return;
      setState(() {
        _saved = SavedPrinter(name: device.name, macAddress: device.macAdress);
        _connectedNow = true;
      });
      _showMessage('Connected to ${device.name}');
    } finally {
      if (mounted) setState(() => _connectingMac = null);
    }
  }

  Future<void> _forget() async {
    await ThermalPrinterService.disconnect();
    await ThermalPrinterService.clearDefaultPrinter();
    if (!mounted) return;
    setState(() {
      _saved = null;
      _connectedNow = false;
    });
  }

  Future<void> _setPaperWidth(PaperSize size) async {
    await ThermalPrinterService.savePaperWidth(size);
    setState(() => _paperSize = size);
  }

  Future<void> _testPrint() async {
    setState(() => _testing = true);
    try {
      await ThermalPrinterService.testPrint();
      _showMessage('Test receipt sent to printer');
    } catch (e) {
      _showMessage(e.toString().replaceAll('Exception: ', ''), isError: true);
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Printer Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
        children: [
          _card(
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: (_saved != null
                            ? AppTheme.success
                            : AppTheme.subtext(context))
                        .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.print_outlined,
                    color: _saved != null
                        ? AppTheme.success
                        : AppTheme.subtext(context),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _saved?.name ?? 'No printer connected',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.onCard(context),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _saved != null
                            ? (_connectedNow
                                ? '${_saved!.macAddress} · Connected'
                                : _saved!.macAddress)
                            : 'Pair a Bluetooth thermal printer to print receipts',
                        style: TextStyle(
                            fontSize: 12, color: AppTheme.subtext(context)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (_saved != null)
                  IconButton(
                    icon: Icon(Icons.link_off, color: AppTheme.error),
                    tooltip: 'Forget printer',
                    onPressed: _forget,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Paper width ─────────────────────────────────────────────
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionLabel('Paper Width'),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _Chip(
                      label: '58mm',
                      selected: _paperSize == PaperSize.mm58,
                      onTap: () => _setPaperWidth(PaperSize.mm58),
                    ),
                    const SizedBox(width: 8),
                    _Chip(
                      label: '80mm',
                      selected: _paperSize == PaperSize.mm80,
                      onTap: () => _setPaperWidth(PaperSize.mm80),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Scan / device list ──────────────────────────────────────
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: _sectionLabel('Available Printers')),
                    TextButton.icon(
                      onPressed: _scanning ? null : _scan,
                      icon: _scanning
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.bluetooth_searching, size: 18),
                      label: Text(_scanning ? 'Scanning…' : 'Scan'),
                    ),
                  ],
                ),
                Text(
                  'Pair your printer in your phone\'s Bluetooth settings, '
                  'then tap Scan to find it.',
                  style: TextStyle(
                      fontSize: 12, color: AppTheme.subtext(context)),
                ),
                if (_devices.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  ..._devices.map((d) {
                    final isSaved = _saved?.macAddress == d.macAdress;
                    final connecting = _connectingMac == d.macAdress;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: connecting ? null : () => _selectDevice(d),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSaved
                                  ? AppTheme.primary
                                  : AppTheme.outline(context),
                              width: isSaved ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.print_outlined,
                                  size: 18,
                                  color: isSaved
                                      ? AppTheme.primary
                                      : AppTheme.subtext(context)),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(d.name,
                                        style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: AppTheme.onCard(context))),
                                    Text(d.macAdress,
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: AppTheme.subtext(context))),
                                  ],
                                ),
                              ),
                              if (connecting)
                                const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              else if (isSaved)
                                Icon(Icons.check_circle,
                                    size: 18, color: AppTheme.primary),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton.icon(
              onPressed: _saved == null || _testing ? null : _testPrint,
              icon: _testing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.receipt_long_outlined),
              label: const Text('Test Print',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _card({required Widget child}) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.card(context),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.outline(context)),
        ),
        child: child,
      );

  Widget _sectionLabel(String text) => Text(
        text,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: AppTheme.onCard(context),
        ),
      );
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.primary.withValues(alpha: 0.1)
              : AppTheme.card(context),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppTheme.primary : AppTheme.outline(context),
            width: selected ? 2 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? AppTheme.primary : AppTheme.subtext(context),
          ),
        ),
      ),
    );
  }
}
