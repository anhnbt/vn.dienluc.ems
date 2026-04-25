# Điện Lực JSC (ems_webview)

Ứng dụng Flutter Webview có tích hợp in hoá đơn qua kết nối Bluetooth (ESC/POS).

## Hướng dẫn chạy và build cơ bản

Cài đặt package và chạy ở chế độ Debug:
```bash
flutter pub get
flutter run
```

Build cho Android:
```bash
flutter build apk --release
adb install build/app/outputs/flutter-apk/app-release.apk
```

## Quản lý App Icon và Splash Screen

### 1. Thay đổi Splash Screen (Màn hình chờ)
- File nguồn được sử dụng là `splash_logo.png`. (Nên thu nhỏ kích thước logo ví dụ chiều rộng tầm 300-400px để không bị vỡ hoặc phình to khỏi màn hình).
- Lệnh để cập nhật Splash Screen:
  ```bash
  dart run flutter_native_splash:create
  ```

### 2. Thay đổi App Icon (Biểu tượng ứng dụng ngoài màn hình)
- File nguồn chính cho Android là `icon-2048.png`.
- **Lưu ý quan trọng cho iOS:** Apple *nghiêm cấm* App Icon có chứa nền trong suốt (Alpha channel/thủng nền).
- Để đồng bộ iOS mà không bị Apple từ chối, ứng dụng này đã có sẵn script Dart để loại bỏ vùng trong suốt, lót nền trắng và xuất ra `icon_ios.png`.
  
Các bước cập nhật:
1. Bạn thay thế file `icon-2048.png` mới.
2. Chạy lệnh tạo icon cho riêng iOS (lót nền trắng):
   ```bash
   dart run make_ios_icon.dart
   ```
3. Chạy lệnh áp dụng App Icon:
   ```bash
   dart run flutter_launcher_icons
   ```

## Hướng dẫn Build iOS & Đưa lên TestFlight (App Store Connect)

Mỗi lần bạn cần đẩy một phiên bản mới lên TestFlight cho Tester tải về, hãy làm theo quy trình chuẩn sau:

1. **Nâng phiên bản (Version Bumping)**: Vô `pubspec.yaml` nâng version, ví dụ từ `1.0.0+1` lên `1.0.0+2`.
2. **Build nạp Framework**: Mở terminal tại thư mục gốc, chạy lệnh:
   ```bash
   flutter build ios --release
   ```
   *(Lệnh này rất quan trọng để nạp các file framework Flutter mới nhất vào native của iOS).*
3. **Mở Xcode**: Bật Xcode, chọn **Open**, trỏ vào thư mục dự án và chọn **`ios/Runner.xcworkspace`** (Lưu ý: Mở file `.xcworkspace`, **KHÔNG** mở `.xcodeproj`).
4. **Cấu hình Signing**: 
   - Ở cột bên trái, click vào `Runner`. Sang Tab **Signing & Capabilities**.
   - Mục **Team**, nhớ chọn chứng chỉ tài khoản Apple Developer của mình.
5. **Chọn thiết bị**: Ở mép trên cùng (gần nút Play của Xcode), bấm vào mục thiết bị, cuộn lên trên cùng chọn **Any iOS Device (arm64)**.
6. **Archive**: 
   - Trên menu công cụ của Mac, bấm **Product** > **Archive**.
   - Đợi Xcode build và đóng gói (khoảng từ 1-3 phút).
7. **Đẩy lên TestFlight**: 
   - Khi Archive xong, cửa sổ **Organizer** mở ra, bấm nút **Distribute App** (Xanh biển bên phải).
   - Chọn **TestFlight & App Store** -> Để mọi thứ mặc định bấm Next liên tục -> **Distribute**.
8. Quá trình xử lí trên App Store sẽ mất khoảng 15-30 phút là Tester có thể tải qua app TestFlight.