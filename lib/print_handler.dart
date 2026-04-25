import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:esc_pos_utils/esc_pos_utils.dart';
import 'package:esc_pos_bluetooth/esc_pos_bluetooth.dart';
import 'bluetooth_service.dart';
import 'esc_pos_parser.dart';

class PrintHandler {
  final void Function(String message)? onMessage;

  PrintHandler({this.onMessage});

  /// Handles the 'print' JavaScript channel call
  /// JS execution example: window.flutter_inappwebview.callHandler('print', base64)
  Future<void> handlePrintCall(List<dynamic> args) async {
    if (args.isNotEmpty) {
      final String base64Data = args[0].toString();
      await printImage(base64Data);
    } else {
      final msg = 'Lỗi JS: Không nhận được dữ liệu base64.';
      debugPrint(msg);
      onMessage?.call(msg);
    }
  }

  /// Handles the 'printNativeESC' JavaScript channel call
  Future<void> handlePrintNativeCall(List<dynamic> args) async {
    if (args.isNotEmpty) {
      final String jsonPayload = args[0].toString();
      await printNativeCommands(jsonPayload);
    } else {
      final msg = 'Lỗi JS: Không nhận được dữ liệu JSON lệnh in.';
      debugPrint(msg);
      onMessage?.call(msg);
    }
  }

  /// Implements ESC/POS Native printing
  Future<void> printNativeCommands(String jsonPayload) async {
    try {
      final bluetoothService = BluetoothService();
      
      if (bluetoothService.selectedPrinter == null) {
        final msg = 'Lỗi: Bạn chưa chọn thiết bị máy in Bluetooth (Bấm icon Máy in ở trên cùng)!';
        debugPrint(msg);
        onMessage?.call(msg);
        return;
      }

      final parser = EscPosParser();
      final List<int> printBytes = await parser.parseJsonToBytes(jsonPayload);
      
      if (printBytes.isEmpty) {
        final msg = 'Lỗi: Không trích xuất được dữ liệu in từ yêu cầu.';
        debugPrint(msg);
        onMessage?.call(msg);
        return;
      }
      
      // Cut paper
      final profile = await CapabilityProfile.load();
      final generator = Generator(PaperSize.mm58, profile);
      printBytes.addAll(generator.cut());
      
      // Send bytes to Bluetooth printer
      final PosPrintResult result = await bluetoothService.printTicket(printBytes);
      
      if (result != PosPrintResult.success) {
        final msg = 'Lỗi in ấn: ${result.msg}';
        debugPrint(msg);
        onMessage?.call(msg);
      } else {
        final msg = 'Đã đẩy lệnh in ESC/POS thành công!';
        debugPrint(msg);
        onMessage?.call(msg);
      }
    } catch (e) {
      final msg = 'Lỗi tiến trình in: $e';
      debugPrint(msg);
      onMessage?.call(msg);
    }
  }

  /// Implements ESC/POS Bluetooth printing
  Future<void> printImage(String base64String) async {
    try {
      final bluetoothService = BluetoothService();
      
      if (bluetoothService.selectedPrinter == null) {
        final msg = 'Lỗi: Bạn chưa chọn thiết bị máy in Bluetooth (Bấm icon Máy in ở trên cùng)!';
        debugPrint(msg);
        onMessage?.call(msg);
        return;
      }

      // Decode base64 to bytes
      final cleanBase64 = base64String.contains(',')
          ? base64String.split(',').last
          : base64String;

      final Uint8List bytes = base64Decode(cleanBase64);

      debugPrint('=== PRINT HANDLER LOG ===');
      debugPrint('Received base64 string length: ${base64String.length}');
      
      // Decode image
      final img.Image? decodedImage = img.decodeImage(bytes);
      if (decodedImage == null) {
        final msg = 'Lỗi: Không thể decode ảnh hóa đơn (Base64 sai định dạng).';
        debugPrint(msg);
        onMessage?.call(msg);
        return;
      }
      
      // Resize image to fit 58mm printer width (approx 384 dots)
      img.Image processedImage = decodedImage;
      if (processedImage.width > 384) {
        processedImage = img.copyResize(processedImage, width: 384);
      }
      
      // Convert to grayscale for better thermal printing contrast
      processedImage = img.grayscale(processedImage);
      
      // Setup ESC/POS generator
      final profile = await CapabilityProfile.load();
      final generator = Generator(PaperSize.mm58, profile);
      
      List<int> printBytes = [];
      
      // Add image to generator
      printBytes += generator.image(processedImage);
      
      // Add some spacing and cut the paper
      printBytes += generator.feed(2);
      printBytes += generator.cut();
      
      // Send bytes to Bluetooth printer
      final PosPrintResult result = await bluetoothService.printTicket(printBytes);
      
      if (result != PosPrintResult.success) {
        final msg = 'Lỗi in ấn: ${result.msg}';
        debugPrint(msg);
        onMessage?.call(msg);
      } else {
        final msg = 'Đã đẩy lệnh in thành công!';
        debugPrint(msg);
        onMessage?.call(msg);
      }

    } catch (e) {
      final msg = 'Lỗi tiến trình in: $e';
      debugPrint(msg);
      onMessage?.call(msg);
    }
  }
}
