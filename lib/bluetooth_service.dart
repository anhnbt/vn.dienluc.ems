import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:esc_pos_bluetooth/esc_pos_bluetooth.dart';
import 'package:esc_pos_utils/esc_pos_utils.dart';

class BluetoothService {
  static final BluetoothService _instance = BluetoothService._internal();

  factory BluetoothService() {
    return _instance;
  }

  BluetoothService._internal();

  final PrinterBluetoothManager _printerManager = PrinterBluetoothManager();
  PrinterBluetooth? _selectedPrinter;
  bool _isConnected = false;

  static const String _prefPrinterMacKey = 'saved_printer_mac';
  static const String _prefPrinterNameKey = 'saved_printer_name';

  PrinterBluetoothManager get printerManager => _printerManager;
  PrinterBluetooth? get selectedPrinter => _selectedPrinter;
  bool get isConnected => _isConnected;

  Future<bool> requestPermissions() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();

    bool allGranted = true;
    statuses.forEach((permission, status) {
      if (!status.isGranted) {
        allGranted = false;
      }
    });

    return allGranted;
  }

  void startScan() {
    _printerManager.startScan(const Duration(seconds: 4));
  }

  void stopScan() {
    _printerManager.stopScan();
  }

  Future<void> savePrinter(PrinterBluetooth printer) async {
    _selectedPrinter = printer;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefPrinterMacKey, printer.address ?? '');
    await prefs.setString(_prefPrinterNameKey, printer.name ?? '');
  }

  Future<String?> loadSavedPrinterMac() async {
    final prefs = await SharedPreferences.getInstance();
    final mac = prefs.getString(_prefPrinterMacKey);
    final name = prefs.getString(_prefPrinterNameKey);

    if (mac != null && mac.isNotEmpty) {
      return mac;
    }
    return null;
  }

  void setPrinter(PrinterBluetooth printer) {
    _selectedPrinter = printer;
  }

  Future<PosPrintResult> printTicket(List<int> bytes) async {
    if (_selectedPrinter == null) {
      return PosPrintResult.printerNotSelected;
    }
    
    _printerManager.selectPrinter(_selectedPrinter!);
    final result = await _printerManager.printTicket(bytes);
    return result;
  }
}
