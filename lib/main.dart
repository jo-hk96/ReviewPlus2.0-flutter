import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:webview_flutter/webview_flutter.dart';
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/services.dart';
import 'SplashPage.dart';

const String mainHome = 'https://decompressive-xavi-unanimated.ngrok-free.dev/';
const String _baseUrl = 'https://decompressive-xavi-unanimated.ngrok-free.dev/';
const String myPageLogin =
    'https://decompressive-xavi-unanimated.ngrok-free.dev/UserMypage';
const int _currentUserId = 1;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ReviewPlus2.0 Webview',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const SplashPage(
        backgroundColor: Color(0xFF1A1A1A),
        logoPath: 'assets/logo.png',
      ),
    );
  }
}

// ---------------------- Profile Service ----------------------
class ProfileService {
  final Dio _dio = Dio();
  final String uploadUrl = "$_baseUrl/api/profile/upload/$_currentUserId";

  Future<String?> uploadProfileImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image == null) return null;

    try {
      FormData formData = FormData.fromMap({
        "file": await MultipartFile.fromFile(
          image.path,
          filename: image.path.split('/').last,
        ),
        "userId": _currentUserId,
      });

      Response response = await _dio.post(uploadUrl, data: formData);

      if (response.statusCode == 200 && response.data != null) {
        Map<String, dynamic> responseData = response.data is String
            ? {}
            : response.data;

        if (responseData.containsKey('newImageUrl')) {
          return responseData['newImageUrl'];
        }
        return response.data.toString();
      }
      return null;
    } catch (e) {
      print('업로드 에러: $e');
      return null;
    }
  }
}

// ---------------------- WebView Page ----------------------
class SpringWebViewPage extends StatefulWidget {
  final String url;

  const SpringWebViewPage({super.key, required this.url});

  @override
  State<SpringWebViewPage> createState() => _SpringWebViewPageState();
}

class _SpringWebViewPageState extends State<SpringWebViewPage> {
  late final WebViewController controller;
  final ProfileService _profileService = ProfileService();
  bool _isLoading = true;
  bool isLoggedIn = false;
  String? profileImageUrl;
  @override
  void initState() {
    super.initState();

    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) => setState(() => _isLoading = true),
          onPageFinished: (_) => setState(() => _isLoading = false),
        ),
      )
      ..addJavaScriptChannel(
        'ProfileChannel',
        onMessageReceived: (JavaScriptMessage message) {
          if (message.message == 'upload_start') {
            _handleProfileUploadAndNotifyWeb();
          }
        },
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  // 뒤로가기
  Future<void> _handleBack() async {
    if (await controller.canGoBack()) {
      controller.goBack();
    } else {
      _showExitDialog();
    }
  }

  // 종료 확인
  void _showExitDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('알림'),
        content: const Text('앱을 종료 하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              SystemNavigator.pop();
            },
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  // 홈 버튼
  Future<void> _handleHome() async {
    controller.loadRequest(Uri.parse(mainHome));
  }

  //myPageLogin
  void _myPageLogin() {
    controller.loadRequest(Uri.parse(myPageLogin));
  }

  // 프로필 업로드 → Javascript 호출
  Future<void> _handleProfileUploadAndNotifyWeb() async {
    String? newUrl = await _profileService.uploadProfileImage();

    if (newUrl != null) {
      controller.runJavaScript("updateProfileImage('$newUrl');");
    } else {
      controller.runJavaScript("handleUploadFailure('업로드 실패');");
    }
  }

  //프로필 이미지를 가져오는 API 함수
  Future<String?> fetchProfileImage(int userId) async {
    final url = Uri.parse(
      "https://decompressive-xavi-unanimated.ngrok-free.dev//api/profile/image/$userId",
    );

    final response = await http.get(url);

    if (response.statusCode == 200) {
      final fileName = response.body.trim();

      // 최종 이미지 URL 만들기
      return "https://decompressive-xavi-unanimated.ngrok-free.dev/images/profile/$fileName";
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (!didPop) _handleBack();
      },
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: 0,
          backgroundColor: const Color(0xFF040F16),
        ),

        body: Stack(
          children: [
            // ----------- 웹뷰 -----------
            WebViewWidget(controller: controller),

            // ----------- 페이지 로딩 표시 (드래그 방해 X) -----------
            if (_isLoading)
              const Positioned.fill(
                child: IgnorePointer(
                  child: Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFFDD0101),
                    ),
                  ),
                ),
              ),

            // ----------- Edge Swipe Back (왼쪽 20px) -----------
            Positioned(
              top: 0,
              bottom: 0,
              left: 0,
              width: 20,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onPanUpdate: (details) {
                  if (details.delta.dx > 8) {
                    _handleBack();
                  }
                },
              ),
            ),
          ],
        ),

        // ----------- 하단 네비게이션 바 -----------
        bottomNavigationBar: BottomAppBar(
          color: const Color(0xFF040F16),
          height: 60.0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              //홈버튼
              IconButton(
                icon: const Icon(Icons.home, color: Colors.white),
                onPressed: _handleHome,
              ),
              isLoggedIn &&
                      profileImageUrl !=
                          null // 👈 로그인 상태 체크
                  ? GestureDetector(
                      // 👈 로그인 시: 프로필 이미지 아바타 표시
                      onTap: _myPageLogin,
                      child: CircleAvatar(
                        radius: 18, // 아이콘 크기와 비슷하도록 radius 설정
                        // null이 아님이 보장되므로 '!' 사용
                        backgroundImage: NetworkImage(profileImageUrl!),
                        backgroundColor: Colors.white, // 로드 전/실패 시 배경색
                      ),
                    )
                  : IconButton(
                      // 👈 로그아웃 시: 기본 아이콘 표시
                      icon: const Icon(
                        Icons.people_alt_rounded,
                        color: Colors.white,
                      ),
                      onPressed: _myPageLogin,
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
