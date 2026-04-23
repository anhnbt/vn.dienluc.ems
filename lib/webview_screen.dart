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
  final PrintHandler _printHandler = PrintHandler();
  final BluetoothService _bluetoothService = BluetoothService();

  double progress = 0;
  bool isError = false;

  late InAppWebViewSettings settings;

  @override
  void initState() {
    super.initState();
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
        // Automatically start scanning to find the saved printer and set it
        _bluetoothService.startScan();
        _bluetoothService.printerManager.scanResults.listen((devices) {
          for (var device in devices) {
            if (device.address == savedMac) {
              _bluetoothService.setPrinter(device);
              _bluetoothService.stopScan();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Đã tự động kết nối máy in: ${device.name}')),
                );
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

                // Setup JavaScript Bridge to register "print" handler
                controller.addJavaScriptHandler(
                  handlerName: 'print',
                  callback: _printHandler.handlePrintCall,
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

          // Loading Progress Bar
          if (progress < 1.0 && !isError)
            LinearProgressIndicator(value: progress),

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
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setStateSheet) {
            return Column(
              children: [
                AppBar(
                  title: const Text('Chọn máy in Bluetooth'),
                  automaticallyImplyLeading: false,
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: () {
                        _bluetoothService.startScan();
                      },
                    ),
                  ],
                ),
                Expanded(
                  child: StreamBuilder<List<PrinterBluetooth>>(
                    stream: _bluetoothService.printerManager.scanResults,
                    initialData: const [],
                    builder: (context, snapshot) {
                      final devices = snapshot.data ?? [];
                      if (devices.isEmpty) {
                        return const Center(child: Text('Đang quét hoặc không tìm thấy máy in...'));
                      }
                      return ListView.builder(
                        itemCount: devices.length,
                        itemBuilder: (context, index) {
                          final device = devices[index];
                          final isSelected = _bluetoothService.selectedPrinter?.address == device.address;
                          return ListTile(
                            leading: const Icon(Icons.print),
                            title: Text(device.name ?? 'Unknown'),
                            subtitle: Text(device.address ?? ''),
                            trailing: isSelected ? const Icon(Icons.check, color: Colors.green) : null,
                            onTap: () async {
                              await _bluetoothService.savePrinter(device);
                              setStateSheet(() {}); // update sheet UI
                              ScaffoldMessenger.of(this.context).showSnackBar(
                                SnackBar(content: Text('Đã chọn máy in: ${device.name}')),
                              );
                              Navigator.pop(context);
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
