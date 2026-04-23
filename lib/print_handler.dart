import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:esc_pos_utils/esc_pos_utils.dart';
import 'package:esc_pos_bluetooth/esc_pos_bluetooth.dart';
import 'bluetooth_service.dart';

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

  /// Implements ESC/POS Bluetooth printing
  Future<void> printImage(String base64String) async {
    try {
      final bluetoothService = BluetoothService();
      
      if (bluetoothService.selectedPrinter == null) {
        debugPrint('Print Error: No printer selected.');
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
        debugPrint('Print Error: Failed to decode image bytes.');
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
        debugPrint('Print Error: ${result.msg}');
      } else {
        debugPrint('Print Success!');
      }

    } catch (e) {
      debugPrint('Error during print process: $e');
    }
  }
}
