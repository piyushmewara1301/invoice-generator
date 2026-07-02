import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/business_profile.dart';
import '../models/invoice.dart';
import '../utils/esc_pos_receipt_generator.dart';

/// A previously paired Bluetooth thermal printer saved as the default.
class SavedPrinter {
  final String name;
  final String macAddress;
  const SavedPrinter({required this.name, required this.macAddress});
}

/// Wraps `print_bluetooth_thermal` to scan for, connect to, and print
/// receipts on Bluetooth ESC/POS thermal printers. Persists the chosen
/// default printer and paper width via [SharedPreferences].
class ThermalPrinterService {
  static const _kPrinterNameKey = 'thermal_printer_name';
  static const _kPrinterMacKey = 'thermal_printer_mac';
  static const _kPaperWidthKey = 'thermal_printer_paper_width';

  /// Requests the runtime permissions needed to scan/connect over
  /// Bluetooth on Android 12+. Returns true if granted.
  static Future<bool> requestPermissions() async {
    final statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
    ].request();
    return statuses.values.every((s) => s.isGranted);
  }

  static Future<bool> get isBluetoothEnabled =>
      PrintBluetoothThermal.bluetoothEnabled;

  static Future<List<BluetoothInfo>> getPairedDevices() =>
      PrintBluetoothThermal.pairedBluetooths;

  static Future<bool> get isConnected => PrintBluetoothThermal.connectionStatus;

  static Future<bool> connect(String macAddress) =>
      PrintBluetoothThermal.connect(macPrinterAddress: macAddress);

  static Future<bool> disconnect() => PrintBluetoothThermal.disconnect;

  // ── Persisted default printer ──────────────────────────────────

  static Future<SavedPrinter?> getSavedPrinter() async {
    final prefs = await SharedPreferences.getInstance();
    final mac = prefs.getString(_kPrinterMacKey);
    final name = prefs.getString(_kPrinterNameKey);
    if (mac == null || mac.isEmpty) return null;
    return SavedPrinter(name: name ?? mac, macAddress: mac);
  }

  static Future<void> saveDefaultPrinter(BluetoothInfo device) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPrinterNameKey, device.name);
    await prefs.setString(_kPrinterMacKey, device.macAdress);
  }

  static Future<void> clearDefaultPrinter() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kPrinterNameKey);
    await prefs.remove(_kPrinterMacKey);
  }

  static Future<PaperSize> getPaperWidth() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_kPaperWidthKey) == 80 ? PaperSize.mm80 : PaperSize.mm58;
  }

  static Future<void> savePaperWidth(PaperSize size) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kPaperWidthKey, size == PaperSize.mm80 ? 80 : 58);
  }

  // ── Printing ──────────────────────────────────────────────────

  /// Connects to the saved default printer (if not already connected) and
  /// prints the given [invoice] as a thermal receipt. Throws a descriptive
  /// [Exception] if no printer is configured or printing fails.
  static Future<void> printInvoice(
      Invoice invoice, BusinessProfile profile) async {
    final saved = await getSavedPrinter();
    if (saved == null) {
      throw Exception('No printer configured. Set up a printer in Settings.');
    }

    if (!await isConnected) {
      final connected = await connect(saved.macAddress);
      if (!connected) {
        throw Exception('Could not connect to ${saved.name}.');
      }
    }

    final paperSize = await getPaperWidth();
    final bytes = await EscPosReceiptGenerator.generateInvoiceReceipt(
      invoice,
      profile,
      paperSize: paperSize,
    );
    final ok = await PrintBluetoothThermal.writeBytes(bytes);
    if (!ok) {
      throw Exception('Failed to send receipt to ${saved.name}.');
    }
  }

  /// Connects to the saved default printer (if needed) and prints a short
  /// test ticket so the user can confirm the connection works.
  static Future<void> testPrint() async {
    final saved = await getSavedPrinter();
    if (saved == null) {
      throw Exception('No printer configured. Set up a printer first.');
    }

    if (!await isConnected) {
      final connected = await connect(saved.macAddress);
      if (!connected) {
        throw Exception('Could not connect to ${saved.name}.');
      }
    }

    final paperSize = await getPaperWidth();
    final cap = await CapabilityProfile.load();
    final gen = Generator(paperSize, cap);
    var bytes = <int>[];
    bytes += gen.text(
      'BillBook',
      styles: const PosStyles(
        align: PosAlign.center,
        bold: true,
        height: PosTextSize.size2,
        width: PosTextSize.size2,
      ),
    );
    bytes += gen.text('Test Print', styles: const PosStyles(align: PosAlign.center));
    bytes += gen.hr();
    bytes += gen.text('Printer: ${saved.name}');
    bytes += gen.text('Paper: ${paperSize == PaperSize.mm80 ? '80mm' : '58mm'}');
    bytes += gen.text(DateTime.now().toString().split('.').first);
    bytes += gen.hr();
    bytes += gen.text(
      'Connection successful!',
      styles: const PosStyles(align: PosAlign.center, bold: true),
    );
    bytes += gen.cut();

    final ok = await PrintBluetoothThermal.writeBytes(bytes);
    if (!ok) {
      throw Exception('Failed to send test print to ${saved.name}.');
    }
  }
}
