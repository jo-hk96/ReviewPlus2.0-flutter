import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Profile Uploader',
      home: ImageUploadScreen(),
    );
  }
}

class ImageUploadScreen extends StatefulWidget {
  const ImageUploadScreen({super.key});

  @override
  State<ImageUploadScreen> createState() => _ImageUploadScreenState();
}

class _ImageUploadScreenState extends State<ImageUploadScreen> {
  File? _imageFile; // 선택된 이미지를 담을 변수
  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false; // 업로드 중 상태 관리

  // ⭐️ 토큰을 임시로 설정. 실제 앱에서는 로그인 후 저장된 토큰을 가져와야 함.
  final String _authToken = 'YOUR_AUTH_TOKEN_HERE';
  // ⭐️ Spring 서버 주소. (에뮬레이터에서 로컬 PC 접근 시)
  final String _uploadUrl = '';

  // 1. 갤러리에서 이미지 선택 (Native 기능)
  Future<void> _pickImage() async {
    final XFile? pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
    );
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
      // 이미지 선택 후 바로 업로드 로직으로 이동
      _uploadProfilePicture();
    }
  }

  // 2. 서버로 이미지 전송 (MultipartFile 사용)
  Future<void> _uploadProfilePicture() async {
    if (_imageFile == null) return;

    setState(() {
      _isUploading = true;
    });

    final url = Uri.parse(_uploadUrl);

    try {
      var request = http.MultipartRequest('POST', url);

      // 인증 토큰 헤더 추가 (Spring Security @AuthenticationPrincipal 대응)
      request.headers.addAll({
        'Authorization': 'Bearer $_authToken',
        'Content-Type': 'multipart/form-data',
      });

      final String fileName = _imageFile!.path.split('/').last;
      request.files.add(
        await http.MultipartFile.fromPath(
          'file', // ⭐️ Spring의 @RequestParam("file")과 일치
          _imageFile!.path,
          filename: fileName,
        ),
      );

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        _showMessage('프로필 사진 업로드 성공!', Colors.green);
      } else {
        _showMessage(
          '업로드 실패: ${response.statusCode} - ${response.body}',
          Colors.red,
        );
      }
    } catch (e) {
      _showMessage('네트워크 오류 발생: $e', Colors.red);
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }

  void _showMessage(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '프로필 설정 (Native)',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF040F16),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            // 1. 프로필 이미지 표시 영역
            GestureDetector(
              onTap: _pickImage, // 🔴 이미지 클릭 시 네이티브 갤러리 열기
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(75),
                  border: Border.all(color: const Color(0xFF040F16), width: 3),
                ),
                child: _imageFile != null
                    ? ClipOval(
                        child: Image.file(
                          _imageFile!,
                          fit: BoxFit.cover,
                        ),
                      )
                    : Center(
                        child: Text(
                          '사진 선택',
                          style: TextStyle(
                            color: Colors.grey[700],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 50),

            // 2. 로딩 인디케이터
            _isUploading
                ? const Column(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 10),
                      Text(
                        "업로드 중...",
                        style: TextStyle(color: Colors.blueGrey),
                      ),
                    ],
                  )
                : const Text(
                    "프로필 이미지를 탭하여 변경하세요.",
                    style: TextStyle(color: Colors.grey),
                  ),
          ],
        ),
      ),
    );
  }
}
