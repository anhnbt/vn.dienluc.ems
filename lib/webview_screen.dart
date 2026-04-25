import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:esc_pos_bluetooth/esc_pos_bluetooth.dart';
import 'print_handler.dart';
import 'bluetooth_service.dart';

class WebViewScreen extends StatefulWidget {
  const WebViewScreen({super.key});

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  final GlobalKey webViewKey = GlobalKey();
  final String targetUrl = "https://ems.dienluc.vn/";

  InAppWebViewController? webViewController;
  late final PrintHandler _printHandler;
  final BluetoothService _bluetoothService = BluetoothService();

  double progress = 0;
  bool isError = false;

  late InAppWebViewSettings settings;

  @override
  void initState() {
    super.initState();
    _printHandler = PrintHandler(
      onMessage: (msg) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(msg),
              duration: const Duration(seconds: 4),
            ),
          );
        }
      },
    );

    settings = InAppWebViewSettings(
      javaScriptEnabled: true,
      domStorageEnabled: true,
      allowFileAccess: true,
      useShouldOverrideUrlLoading: true,
      useOnDownloadStart: true,
      supportZoom: true,
    );
    
    _initBluetooth();
  }

  Future<void> _initBluetooth() async {
    bool granted = await _bluetoothService.requestPermissions();
    if (granted) {
      String? savedMac = await _bluetoothService.loadSavedPrinterMac();
      if (savedMac != null) {
        // Automatically start scanning to find the saved printer and connect to it
        _bluetoothService.startScan();
        _bluetoothService.printerManager.scanResults.listen((devices) async {
          for (var device in devices) {
            if (device.address == savedMac) {
              _bluetoothService.stopScan();
              // Cố gắng kết nối thực sự tới máy in
              bool connected = await _bluetoothService.connectToPrinter(device);
              if (mounted) {
                if (connected) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Đã tự động kết nối máy in: ${device.name}')),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Không thể kết nối máy in: ${device.name}')),
                  );
                }
              }
              break;
            }
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('EMS Dien Luc',
            style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 2,
        actions: [
          IconButton(
            icon: const Icon(Icons.print),
            onPressed: () {
              _showPrinterSelectionDialog();
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              webViewController?.reload();
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          if (!isError)
            InAppWebView(
              key: webViewKey,
              initialUrlRequest: URLRequest(url: WebUri(targetUrl)),
              initialSettings: settings,
              onWebViewCreated: (controller) {
                webViewController = controller;

                // Setup JavaScript Bridge to register "print" handlers
                controller.addJavaScriptHandler(
                  handlerName: 'print',
                  callback: _printHandler.handlePrintCall,
                );
                
                controller.addJavaScriptHandler(
                  handlerName: 'printNativeESC',
                  callback: _printHandler.handlePrintNativeCall,
                );
              },
              onLoadStart: (controller, url) {
                setState(() {
                  isError = false;
                });
              },
              onProgressChanged: (controller, progressValue) {
                setState(() {
                  progress = progressValue / 100;
                });
              },
              onLoadStop: (controller, url) async {
                setState(() {
                  progress = 1.0;
                });
              },
              onReceivedError: (controller, request, error) {
                setState(() {
                  isError = true;
                });
              },
              shouldOverrideUrlLoading: (controller, navigationAction) async {
                // Return ALLOW to prevent external browsers from hijacking navigation
                return NavigationActionPolicy.ALLOW;
              },
              onDownloadStartRequest: (controller, downloadRequest) async {
                // TODO: Add file download handling here (e.g. url_launcher or flutter_downloader)
                debugPrint("File Download requested: ${downloadRequest.url}");
              },
            ),

          // Cải tiến UX: Hiển thị màn hình chờ toàn màn hình khi đang tải dữ liệu
          if (progress < 1.0 && !isError)
            Container(
              color: Colors.white,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                      strokeWidth: 3,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Đang tải dữ liệu... ${(progress * 100).toInt()}%',
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.blueGrey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Error State Screen
          if (isError)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.wifi_off, color: Colors.grey, size: 60),
                  const SizedBox(height: 16),
                  const Text('Không thể tải trang',
                      style: TextStyle(fontSize: 18, color: Colors.grey)),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        isError = false;
                        progress = 0;
                      });
                      webViewController?.reload();
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Thử lại'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _showPrinterSelectionDialog() {
    _bluetoothService.startScan();
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setStateSheet) {
            return Column(
              children: [
                AppBar(
                  title: const Text('Chọn máy in Bluetooth'),
                  automaticallyImplyLeading: false,
                  shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
                  actions: [
                    StreamBuilder<bool>(
                      stream: _bluetoothService.printerManager.isScanningStream,
                      initialData: false,
                      builder: (c, snapshot) {
                        if (snapshot.data == true) {
                          return const Padding(
                            padding: EdgeInsets.all(16.0),
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.blue),
                            ),
                          );
                        }
                        return IconButton(
                          icon: const Icon(Icons.refresh),
                          onPressed: () {
                            _bluetoothService.startScan();
                          },
                        );
                      }
                    ),
                  ],
                ),
                Expanded(
                  child: StreamBuilder<List<PrinterBluetooth>>(
                    stream: _bluetoothService.printerManager.scanResults,
                    initialData: const [],
                    builder: (context, snapshot) {
                      final devices = snapshot.data ?? [];
                      
                      return StreamBuilder<bool>(
                        stream: _bluetoothService.printerManager.isScanningStream,
                        initialData: false,
                        builder: (c, scanSnapshot) {
                          final isScanning = scanSnapshot.data ?? false;
                          
                          if (devices.isEmpty) {
                            if (isScanning) {
                              return Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const CircularProgressIndicator(),
                                    const SizedBox(height: 16),
                                    const Text('Đang quét tìm máy in lân cận...', style: TextStyle(color: Colors.grey)),
                                  ],
                                ),
                              );
                            } else {
                              return Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.bluetooth_disabled, size: 60, color: Colors.grey),
                                    const SizedBox(height: 16),
                                    const Text('Không tìm thấy thiết bị nào!', style: TextStyle(color: Colors.grey)),
                                    const SizedBox(height: 8),
                                    TextButton.icon(
                                      icon: const Icon(Icons.refresh),
                                      label: const Text('Quét lại'),
                                      onPressed: () => _bluetoothService.startScan(),
                                    )
                                  ],
                                ),
                              );
                            }
                          }
                          
                          return ListView.separated(
                            itemCount: devices.length,
                            separatorBuilder: (context, index) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final device = devices[index];
                              final isSelected = _bluetoothService.selectedPrinter?.address == device.address;
                              return ListTile(
                                leading: Icon(Icons.print, color: isSelected ? Colors.blue : Colors.grey),
                                title: Text(device.name ?? 'Thiết bị không tên', 
                                    style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                                subtitle: Text(device.address ?? ''),
                                trailing: isSelected 
                                  ? const Icon(Icons.check_circle, color: Colors.green) 
                                  : OutlinedButton(
                                      onPressed: () async {
                                        await _bluetoothService.savePrinter(device);
                                        // Kết nối thực sự tới máy in
                                        bool connected = await _bluetoothService.connectToPrinter(device);
                                        setStateSheet(() {}); // update sheet UI
                                        ScaffoldMessenger.of(this.context).showSnackBar(
                                          SnackBar(content: Text(connected ? 'Đã kết nối máy in: ${device.name}' : 'Không thể kết nối máy in: ${device.name}')),
                                        );
                                        Navigator.pop(context);
                                      },
                                      child: const Text('Kết nối'),
                                    ),
                                onTap: () async {
                                  await _bluetoothService.savePrinter(device);
                                  // Kết nối thực sự tới máy in
                                  bool connected = await _bluetoothService.connectToPrinter(device);
                                  setStateSheet(() {}); // update sheet UI
                                  ScaffoldMessenger.of(this.context).showSnackBar(
                                    SnackBar(content: Text(connected ? 'Đã kết nối máy in: ${device.name}' : 'Không thể kết nối máy in: ${device.name}')),
                                  );
                                  Navigator.pop(context);
                                },
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    ).whenComplete(() {
      _bluetoothService.stopScan();
    });
  }
}
