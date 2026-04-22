import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'print_handler.dart';

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
}
