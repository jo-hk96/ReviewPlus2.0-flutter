import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';
import 'profile_service.dart';

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

final ProfileService _profileService = ProfileService();

class _MyHomePageState extends State<MyHomePage> {
  // 🟢 1. 로딩 상태를 추적할 변수 추가 (기본값: true)
  bool _isLoading = true;

  // 웹뷰 컨트롤러 생성
  late final WebViewController controller;


  //안드로이드 시뮬레이션 'http://10.0.2.2:9090/';
  //웹,IOS ex>'http://localhost:9090/';
  //실제기기,웹에서 테스트시 서버의 실제 IP주소,도메인 사용
  final String springBootUrl =
      'http://10.0.2.2:9090/';

  @override
  void initState() {
    super.initState();
    WebViewController().clearCache();
    WebViewController().clearLocalStorage();

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
      ..addJavaScriptChannel(
        'ToFlutter', // JS 코드의 window.ToFlutter와 일치
        onMessageReceived: (JavaScriptMessage message) {
          if (message.message == 'START_UPLOAD_FLOW') {
            // JS에서 보낸 메시지 확인
            debugPrint('Flutter: 웹뷰로부터 업로드 시작 요청 받음');
            _handleImagePickAndUpload(); // 갤러리 열기 및 업로드 함수 호출
          }
        },
      )
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

  Future<void> _handleImagePickAndUpload() async {
    String? newUrl = await _profileService.uploadProfileImage();

    if (newUrl != null) {
      final String serverBaseUrl =
          'http://10.0.2.2:9090/';
      String absoluteUrl = newUrl.startsWith('http')
          ? newUrl
          : serverBaseUrl + newUrl;

      // 웹뷰의 JS 함수 호출하여 UI 업데이트
      controller.runJavaScript('updateProfileImage("$absoluteUrl");');
    } else {
      debugPrint('Flutter: 이미지 업로드 실패');
    }
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
                color: Color(0xFFDD0101),
              ),
            ),
        ],
      ),

      bottomNavigationBar: BottomAppBar(
        color: const Color(0xFF040F16), // 앱바 배경색 설정
        height: 60.0, // 앱바 높이 설정 (원하는 대로 조정 가능)
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: <Widget>[
            //홈버튼
            IconButton(
              icon: const Icon(Icons.home, color: Colors.white),
              onPressed: () {
                // TODO: 홈 버튼 눌렀을 때 동작
                print('홈 버튼');
              },
            ),

            //뒤로가기 버튼
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () {
                // TODO: 뒤로 가기 동작 (예: controller.goBack())
                print('뒤로 가기 버튼');
              },
            ),

            //새로고침
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              onPressed: () {
                // TODO: 새로고침 동작 (예: controller.reload())
                print('새로고침 버튼');
              },
            ),
          ],
        ),
      ),
    );
  }
}