import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // 2. 플랫폼별 구현체 등록
  if (WebViewPlatform.instance is AndroidWebViewPlatform) {
    AndroidWebViewPlatform.registerWith();
  }
  if (WebViewPlatform.instance is WebKitWebViewPlatform) {
    WebKitWebViewPlatform.registerWith();
  }

  // 3. runApp 실행
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // 로딩 스피너가 Material Design을 따르므로, MaterialApp 유지
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  // 🟢 1. 로딩 상태를 추적할 변수 추가 (기본값: true)
  bool _isLoading = true;

  // 웹뷰 컨트롤러 생성
  late final WebViewController controller;

  // 스프링 부트 서버의 주소 (중요!)
  final String springBootUrl =
      '';

  @override
  void initState() {
    super.initState();

    //로딩 상태를 3초 동안 강제로 true로 유지
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    });

    // WebViewController 초기화
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            debugPrint('WebView is loading (progress: $progress%)');
          },
          onPageStarted: (String url) {
            debugPrint('Page started loading: $url');
            //페이지 시작 시 로딩 시작
            if (mounted) {
              setState(() {
                //_isLoading = true;
              });
            }
          },
          onPageFinished: (String url) {
            debugPrint('Page finished loading: $url');
            //페이지 로딩 완료 시 로딩 끝
            if (mounted) {
              setState(() {
                //_isLoading = false;
              });
            }
          },
          onWebResourceError: (WebResourceError error) {
            // 에러 발생 시 처리 (에러 발생 시에도 로딩을 false로 바꿔야 함)
            debugPrint('''
              Page resource error:
              code: ${error.errorCode}
              description: ${error.description}
              errorType: ${error.errorType}
              isForMainFrame: ${error.isForMainFrame}
            ''');
            if (mounted) {
              setState(() {
                _isLoading = false;
              });
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(springBootUrl)); // 서버 주소 로드
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 0.0,
        backgroundColor: const Color(0xFF040F16),
      ),
      body: Stack(
        children: <Widget>[
          WebViewWidget(controller: controller),

          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(
                color: Color(0xFFDD0101), // 네이티브 앱 색상에 맞춰 색상 변경 가능
              ),
            ),
        ],
      ),
    );
  }
}
