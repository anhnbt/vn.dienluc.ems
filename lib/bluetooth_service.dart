import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:esc_pos_bluetooth/esc_pos_bluetooth.dart';
import 'package:flutter_bluetooth_basic/flutter_bluetooth_basic.dart';

class BluetoothService {
  static final BluetoothService _instance = BluetoothService._internal();

  factory BluetoothService() {
    return _instance;
  }

  BluetoothService._internal();

  final PrinterBluetoothManager _printerManager = PrinterBluetoothManager();
  final BluetoothManager _bluetoothManager = BluetoothManager.instance;
  
  PrinterBluetooth? _selectedPrinter;
  bool _isConnected = false;

  static const String _prefPrinterMacKey = 'saved_printer_mac';
  static const String _prefPrinterNameKey = 'saved_printer_name';

  PrinterBluetoothManager get printerManager => _printerManager;
  PrinterBluetooth? get selectedPrinter => _selectedPrinter;
  bool get isConnected => _isConnected;

  Future<bool> requestPermissions() async {
    List<Permission> permissions = [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
    ];

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      permissions.add(Permission.location);
    }

    Map<Permission, PermissionStatus> statuses = await permissions.request();

    bool allGranted = true;
    statuses.forEach((permission, status) {
      if (!status.isGranted && permission != Permission.location) {
        allGranted = false;
      }
    });

    return allGranted;
  }

  void startScan() {
    try {
      _printerManager.startScan(const Duration(seconds: 4));
    } catch (e) {
      debugPrint('Start scan error: $e');
    }
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

  Future<bool> connectToPrinter(PrinterBluetooth printer) async {
    try {
      final device = BluetoothDevice();
      device.name = printer.name;
      device.address = printer.address;
      device.type = printer.type ?? 0;
      
      await _bluetoothManager.connect(device);
      _isConnected = true;
      _selectedPrinter = printer;
      return true;
    } catch (e) {
      debugPrint('Connection error: $e');
      _isConnected = false;
      return false;
    }
  }

  Future<void> disconnect() async {
    try {
      await _bluetoothManager.disconnect();
    } catch (e) {
      debugPrint('Disconnect error: $e');
    } finally {
      _isConnected = false;
    }
  }

  Future<PosPrintResult> printTicket(List<int> bytes) async {
    if (_selectedPrinter == null) {
      return PosPrintResult.printerNotSelected;
    }
    
    // Nếu chưa kết nối, thử kết nối
    if (!_isConnected) {
      bool connected = await connectToPrinter(_selectedPrinter!);
      if (!connected) {
        return PosPrintResult.timeout;
      }
      // Chờ một chút sau khi kết nối trước khi gửi dữ liệu
      await Future.delayed(const Duration(milliseconds: 500));
    }
    
    try {
      // Chia nhỏ dữ liệu thành các gói 256 bytes để tránh bị tràn bộ đệm máy in (gây treo)
      int chunkSize = 256;
      for (var i = 0; i < bytes.length; i += chunkSize) {
        var end = (i + chunkSize < bytes.length) ? i + chunkSize : bytes.length;
        var chunk = bytes.sublist(i, end);
        await _bluetoothManager.writeData(chunk);
        // Delay nhỏ giữa các gói để máy in kịp nhận
        await Future.delayed(const Duration(milliseconds: 10));
      }
      
      return PosPrintResult.success;
    } catch (e) {
      debugPrint('Print error: $e');
      _isConnected = false; // Đánh dấu ngắt kết nối nếu lỗi gửi dữ liệu
      return PosPrintResult.ticketEmpty;
    }
  }
}
