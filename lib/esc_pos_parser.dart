import 'dart:convert';
import 'package:esc_pos_utils/esc_pos_utils.dart'; // Sử dụng thư viện có sẵn trong pubspec.yaml

class EscPosParser {
  /// Hàm parse JSON array từ Webview thành mảng bytes lệnh in ESC/POS
  Future<List<int>> parseJsonToBytes(String jsonPayload) async {
    final profile = await CapabilityProfile.load();
    // Khổ giấy K58
    final generator = Generator(PaperSize.mm58, profile);
    
    List<int> bytes = [];
    
    try {
      final dynamic decoded = jsonDecode(jsonPayload);
      List<dynamic> commands = [];
      
      if (decoded is List) {
        commands = decoded;
      } else if (decoded is Map && decoded.containsKey('commands')) {
        commands = decoded['commands'] ?? [];
      } else {
        throw Exception("Unknown json format: Expected List or Map with 'commands' key");
      }

      for (var cmd in commands) {
        final String type = cmd['type'] ?? '';

        switch (type) {
          case 'text':
            final String text = cmd['text'] ?? '';
            final bool isBold = cmd['bold'] == true;
            final String alignStr = cmd['align'] ?? 'left';
            final String sizeStr = cmd['size'] ?? 'normal';

            // Căn chỉnh
            PosAlign align = PosAlign.left;
            if (alignStr == 'center') align = PosAlign.center;
            if (alignStr == 'right') align = PosAlign.right;

            // Kích thước (large -> doubleWidth & doubleHeight)
            PosTextSize textSize = PosTextSize.size1;
            if (sizeStr == 'large') {
              textSize = PosTextSize.size2;
            }

            // Do dữ liệu đã loại bỏ dấu tiếng Việt (latin1), chúng ta in thẳng text
            bytes += generator.text(
              text,
              styles: PosStyles(
                align: align,
                bold: isBold,
                height: textSize,
                width: textSize,
              ),
            );
            break;

          case 'row':
            final String left = cmd['left'] ?? '';
            final String right = cmd['right'] ?? '';
            final bool isBold = cmd['bold'] == true;
            bytes += _processRow(left, right, isBold, generator);
            break;

          case 'divider':
            // In một hàng gạch ngang 32 ký tự (chuẩn K58)
            bytes += generator.text(
              '--------------------------------',
              styles: const PosStyles(align: PosAlign.center),
            );
            break;

          case 'feed':
            final int lines = cmd['lines'] ?? 1;
            bytes += generator.feed(lines);
            break;

          default:
            // Bỏ qua các type không xác định
            break;
        }
      }
      
    } catch (e) {
      print('Lỗi parse JSON lệnh in: $e');
    }

    return bytes;
  }

  /// Logic xử lý type: 'row' để hóa đơn không bị lệch
  List<int> _processRow(String left, String right, bool isBold, Generator generator) {
    int maxChars = 32; // Quy chuẩn K58
    int spaceCount = maxChars - (left.length + right.length);

    // Nếu chuỗi quá dài, đảm bảo ít nhất 1 khoảng trắng
    if (spaceCount < 1) spaceCount = 1;

    String fullLine = left + (" " * spaceCount) + right;
    return generator.text(fullLine, styles: PosStyles(bold: isBold));
  }
}
