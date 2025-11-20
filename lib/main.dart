import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/services.dart';
import 'SplashPage.dart';

const String mainHome = 'http://10.0.2.2:9090/';
const int _currentUserId = 1; // 현재 로그인된 사용자 ID 가정
const String _baseUrl = 'http://10.0.2.2:9090/';

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


//프로필 서비스 (Dio 업로드 로직)
class ProfileService {
  final Dio _dio = Dio();
  final String uploadUrl =
      "$_baseUrl/api/profile/upload/$_currentUserId";

  Future<String?> uploadProfileImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    // ... (나머지 Dio 업로드 로직은 이전과 동일하다고 가정)

    if (image == null) return null;

    try {
      FormData formData = FormData.fromMap({
        "file": await MultipartFile.fromFile(image.path, filename: image.path.split('/').last),
        "userId": _currentUserId,
      });

      Response response = await _dio.post(uploadUrl, data: formData);

      if (response.statusCode == 200 && response.data != null) {
        Map<String, dynamic> responseData = response.data is String ? {} : response.data;
        // 서버 응답 형태에 따라 newImageUrl을 추출
        if (responseData.containsKey('newImageUrl')) {
          return responseData['newImageUrl'];
        }
        return response.data.toString(); // JSON이 아닌 문자열 응답 시
      }
      return null;
    } on DioException catch (e) {
      print('Dio 에러 발생: ${e.message}');
      return null;
    } catch (e) {
      print('예상치 못한 에러 발생: $e');
      return null;
    }
  }
}


// 3. SpringWebViewPage (웹뷰 표시 및 제스처, 버튼 통합)
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

  @override
  void initState() {
    super.initState();

    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))

    // 페이지 로드가 시작/끝날 때 로딩 상태 업데이트
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            setState(() { _isLoading = true; });
          },
          onPageFinished: (url) {
            setState(() { _isLoading = false; });
          },
        ),
      )
    // 웹뷰와 Flutter 간의 통신 채널 추가 (프로필 업로드 로직 실행용)
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

  // 뒤로 가기 로직 (버튼 및 스와이프 제스처에서 사용)
  Future<void> _handleBack() async {
    if (await controller.canGoBack()) {
      controller.goBack(); // 웹뷰 내의 방문 기록을 따라 뒤로 이동
      print('웹뷰 뒤로가기');
    } else {
      print('Flutter 화면 닫기');
      _showExitDialog();
    }
  }

  void _showExitDialog(){
    showDialog(
      context:context,
      builder: (context){
        return AlertDialog(
          title: Text('알림'),
          content: Text('앱을 종료 하시겠습니까?'),
          actions:[
            TextButton(
              onPressed: (){
                Navigator.pop(context); //알림창만 닫기
              },
              child: Text('취소'),
            ),
            TextButton(
              onPressed: (){
                Navigator.pop(context);//알림창 닫기
                SystemNavigator.pop();
                print('앱 종료');
              },
              child: Text('확인'),
            ),
          ],
        );
      },
    );
  }


  // 홈 버튼 로직 (초기 URL로 돌아가기)
  Future<void> _handleHome() async {
    controller.loadRequest(Uri.parse(widget.url)); // 웹뷰의 초기 URL로 돌아가기
    print('홈 버튼 (웹뷰 초기 URL 로드)');
  }

  // Flutter Dio 업로드 로직 실행 및 웹뷰에 결과 전달
  Future<void> _handleProfileUploadAndNotifyWeb() async {
    String? newUrl = await _profileService.uploadProfileImage();

    if (newUrl != null) {
      // 업로드 성공 시, 웹뷰의 JS 함수 호출하여 화면 업데이트
      controller.runJavaScript(
        "updateProfileImage('$newUrl');",
      );
    } else {
      // 실패 시 웹뷰에 실패 메시지 전달 (선택 사항)
      controller.runJavaScript("handleUploadFailure('업로드 실패');");
    }
  }


  @override
  Widget build(BuildContext context) {
    // WillPopScope 대신 PopScope를 사용할 수 있지만, 호환성을 위해 WillPopScope로 제스처를 구현합니다.
    return PopScope(
      canPop: false, // Flutter의 기본 뒤로 가기 동작을 막고 우리가 _handleBack()에서 처리하도록 설정
      onPopInvoked: (didPop) async {
        if (!didPop) {
          await _handleBack();
        }
      },
      child: GestureDetector(
        // 🚨 스와이프 제스처 구현: 오른쪽으로 빠르게 드래그할 때 뒤로 가기 실행
        onHorizontalDragEnd: (details) {
          // 오른쪽으로 빠르게 스와이프 (속도 임계값 500 사용)
          if (details.primaryVelocity != null && details.primaryVelocity! > 500) {
            _handleBack();
          }
        },
        child: Scaffold(
          appBar: AppBar(
            toolbarHeight: 0.0,
            backgroundColor: const Color(0xFF040F16),
          ),
          body: Stack(
            children: <Widget>[
              // 웹뷰 위젯
              WebViewWidget(controller: controller),

              // 로딩 인디케이터
              if (_isLoading)
                const Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFFDD0101),
                  ),
                ),
            ],
          ),

          bottomNavigationBar: BottomAppBar(
            color: const Color(0xFF040F16),
            height: 60.0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: <Widget>[
                // 홈 버튼
                IconButton(
                  icon: const Icon(Icons.home, color: Colors.white),
                  onPressed: _handleHome, // 수정된 함수 호출
                ),
                // 뒤로 가기 버튼
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: _handleBack, // 수정된 함수 호출
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}