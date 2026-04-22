import 'dart:convert';
import 'package:flutter/foundation.dart';

class PrintHandler {
  /// Handles the 'print' JavaScript channel call
  /// JS execution example: window.flutter_inappwebview.callHandler('print', base64)
  Future<void> handlePrintCall(List<dynamic> args) async {
    if (args.isNotEmpty) {
      final String base64Data = args[0].toString();
      await printImage(base64Data);
    } else {
      debugPrint('Print called from JS but no base64 arguments provided.');
    }
  }

  /// Placeholder function for future ESC/POS Bluetooth printing
  Future<void> printImage(String base64String) async {
    try {
      // Decode base64 to bytes
      // (Strips out 'data:image/png;base64,' prefix if present)
      final cleanBase64 = base64String.contains(',')
          ? base64String.split(',').last
          : base64String;

      final Uint8List bytes = base64Decode(cleanBase64);

      debugPrint('=== PRINT HANDLER LOG ===');
      debugPrint('Received base64 string length: ${base64String.length}');
      debugPrint('Decoded successfully to ${bytes.length} bytes.');

      // TODO: Implement ESC/POS logic here
      // 1. Connect to paired Bluetooth thermal printer (e.g., via flutter_blue_plus)
      // 2. Convert image bytes to ESC/POS format (e.g., using esc_pos_utils)
      // 3. Send payload to printer
      // 4. Disconnect safely
    } catch (e) {
      debugPrint('Error decoding base64 image: $e');
    }
  }
}
