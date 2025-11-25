import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:webview_flutter/webview_flutter.dart';
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/services.dart';
import 'SplashPage.dart';
import 'dart:convert';

const String mainHome = 'http://192.168.0.53:9090/';
const String _baseUrl = 'http://192.168.0.53:9090/';
const String myPageLogin = 'http://192.168.0.53:9090/UserMypage';
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
  final String _baseUrl;
  final String _currentUserId;

  // 생성자를 통해 주입받는 것을 권장합니다.
  ProfileService({required String baseUrl, required String currentUserId})
    : _baseUrl = baseUrl,
      _currentUserId = currentUserId;

  Future<String?> uploadProfileImage() async {
    final String uploadUrl = "$_baseUrl/api/profile/upload/";

    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image == null) return null;

    try {
      // 1. FormData 생성: 서버에서 file과 userId를 기대한다고 가정
      FormData formData = FormData.fromMap({
        "file": await MultipartFile.fromFile(
          image.path,
          filename: image.name, // XFile.name이 더 정확합니다.
        ),
      });

      Response response = await _dio.post(uploadUrl, data: formData);

      if (response.statusCode == 200 && response.data != null) {
        final responseData = response.data;
        // 2. 응답 데이터 처리 개선: Dio가 String으로 반환할 경우 JSON 파싱 시도
        if (responseData is Map<String, dynamic> &&
            responseData['success'] == true) {
          if (responseData.containsKey('newImageUrl')) {
            return responseData['newImageUrl'] as String?;
          }
        }
        // success: false 이거나 필수 키가 없을 경우
        print('서버 응답에 문제가 있습니다: $responseData');
        return null;
      } else {
        // 4. HTTP 상태 코드가 200이 아닐 경우 (예: 401, 500 등)
        print('서버 응답 오류: 상태 코드 ${response.statusCode}, 데이터: ${response.data}');
        return null;
      }

      // 4. HTTP 상태 코드가 200이 아닐 경우
      print('서버 응답 오류: 상태 코드 ${response.statusCode}');
      return null;
    } on DioException catch (e) {
      // Dio 특정 에러 처리 (네트워크 오류, 타임아웃 등)
      print('Dio 업로드 에러: ${e.message}, 응답: ${e.response?.data}');
      return null;
    } catch (e) {
      // 기타 예상치 못한 에러
      print('일반 업로드 에러: $e');
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
  final ProfileService _profileService = ProfileService(
    baseUrl: 'http://192.168.0.53:9090/',
    currentUserId: '1',
  );

  void _handleLogout() {
    setState(() {
      isLoggedIn = false;
      profileImageUrl = null;
    });
    // (선택 사항: 로그아웃 후 홈으로 돌아가게 하려면)
    // _handleHome();
  }

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
          } else if (message.message == 'logout_success') {
            setState(() {
              isLoggedIn = false;
              profileImageUrl = null;
            });
            _handleLogout();
          }
        },
      )
      ..loadRequest(Uri.parse(widget.url));
    _fetchUserStatus();
  }

  //사용자 상태
  Future<void> _fetchUserStatus() async {
    // 1. ⭐️ Spring의 세션 유효성 검사 API 호출
    final authCheckUrl = Uri.parse("$_baseUrl/api/user/check-auth");
    final authResponse = await http.get(authCheckUrl);

    if (authResponse.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(authResponse.body);

      // 2. ⭐️ 서버에서 인증 상태 및 URL 확인
      if (data['isAuthenticated'] == true) {
        String? initialUrl = data['profileImageUrl'];

        setState(() {
          isLoggedIn = true;
          profileImageUrl = initialUrl; // 유효한 세션일 경우만 URL 사용
        });
        return;
      }
    }

    // 3. 인증 실패 또는 API 오류 시 (로그아웃 상태로 초기화)
    setState(() {
      isLoggedIn = false;
      profileImageUrl = null;
    });
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

  // 홈 버튼 주소
  Future<void> _handleHome() async {
    controller.loadRequest(Uri.parse(mainHome));
  }

  //myPageLogin
  void _myPageLogin() {
    controller.loadRequest(Uri.parse(myPageLogin));
  }

  // 프로필 업로드 → Javascript 호출
  Future<void> _handleProfileUploadAndNotifyWeb() async {
    // 1. ProfileService를 호출하여 서버로부터 새로운 URL을 'newUrl' 변수에 저장
    String? newUrl = await _profileService.uploadProfileImage();

    if (newUrl != null) {
      // 2. 서버에서 받은 새 URL을 Flutter 상태 변수에 저장하고 화면 갱신
      setState(() {
        isLoggedIn = true; // 로그인 상태 보장 (선택적)
        profileImageUrl = newUrl; // 👈 여기에서 URL을 최종적으로 받아서 저장
      });

      // 3. (선택적) 웹뷰 내부의 HTML 이미지도 갱신하도록 JavaScript 호출
      controller.runJavaScript("updateProfileImage('$newUrl');");
    } else {
      controller.runJavaScript("handleUploadFailure('업로드 실패');");
    }
  }

  //프로필 이미지를 가져오는 API 함수
  Future<String?> fetchProfileImage(int userId) async {
    final url = Uri.parse(
      "http://192.168.0.53:9090/api/profile/image/$userId",
    );

    final response = await http.get(url);

    if (response.statusCode == 200) {
      String imagePath = response.body.trim();
      if (imagePath.isEmpty || imagePath.toLowerCase() == 'default.png') {
        // 기본 이미지 파일명('default.png')을 받았거나, 유효하지 않은 경우
        return null;
      }
      if (imagePath.startsWith('/')) {
        imagePath = imagePath.substring(1);
      }

      return _baseUrl + imagePath;
    }
    return null;
  }

  //-------새로고침---------------
  Future<void> _refreshWebView() async {
    await controller.reload();
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
                      onTap: _myPageLogin,
                      child: CircleAvatar(
                        radius: 20, // 아이콘 크기와 비슷하도록 radius 설정
                        backgroundImage: NetworkImage(profileImageUrl!),
                        backgroundColor: Colors.white, // 로드 전/실패 시 배경색
                      ),
                    )
                  : IconButton(
                      icon: const Icon(
                        Icons.people_alt_rounded,
                        color: Colors.white,
                      ),
                      onPressed: _myPageLogin,
                    ),
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white),
                onPressed: _refreshWebView,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
