import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';

class ProfileService {
  final Dio _dio = Dio();
  final String _baseUrl;
  final String _currentUserId;
  final String? _jsessionId;

  ProfileService({required String baseUrl, required String currentUserId, String? jsessionId})
      : _baseUrl = baseUrl,
        _currentUserId = currentUserId,
        _jsessionId = jsessionId;

  Future<String?> uploadProfileImage() async {
    final String uploadUrl = "$_baseUrl/api/profile/upload/";

    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image == null) return null;

    Map<String, String> headers = {
      HttpHeaders.contentTypeHeader: "multipart/form-data",
    };

    // 🎯 JSESSIONID가 있다면 헤더에 추가합니다.
    if (_jsessionId != null) {
      headers['Cookie'] = 'JSESSIONID=$_jsessionId'; // 👈 여기가 핵심!
    }
    print('>>> DIO 요청 전 확인: JSESSIONID 헤더 값: ${headers['Cookie']}');
    try {
      // 1. FormData 생성: 서버에서 file과 userId를 기대한다고 가정
      FormData formData = FormData.fromMap({
        "file": await MultipartFile.fromFile(
          image.path,
          filename: image.name,
        ),
      });

      Response response = await _dio.post(
        uploadUrl,
        data: formData,
        options: Options(headers: headers), // 준비된 헤더 사용
      );

      if (response.statusCode == 200 && response.data != null) {
        dynamic responseData = response.data;

        // 🎯 1. 만약 String으로 받았다면 JSON 디코딩을 시도합니다.
        if (responseData is String && responseData.isNotEmpty) {
          try {
            responseData = json.decode(responseData);
          } catch (e) {
            print('JSON 디코딩 실패: $e');
            return null;
          }
        }

        // 🎯 2. Map 타입인지 확인하고 'newImageUrl'을 추출합니다.
        if (responseData is Map<String, dynamic> &&
            responseData['success'] == true) {
          if (responseData.containsKey('newImageUrl')) {
            String? newUrlPath = responseData['newImageUrl'] as String?;

            if (newUrlPath != null) {
              // _baseUrl이 'http://10.0.2.2:9090/' 로 끝난다면:
              if (newUrlPath.startsWith('/')) {
                return _baseUrl.replaceAll(RegExp(r'/$'), '') + newUrlPath;
              }
              return _baseUrl + newUrlPath;
            }
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


    } on DioException catch (e) {
      // Dio 특정 에러 처리 (네트워크 오류, 타임아웃 등)
      print('*** DIO UPLOAD ERROR LOG START ***');
      print('Dio 에러 메시지: ${e.message}');
      print('HTTP 상태 코드: ${e.response?.statusCode}'); // 404, 500 등 서버 응답 코드를 확인
      print('서버 응답 데이터: ${e.response?.data}'); // 서버에서 보낸 에러 메시지를 확인
      print('*** DIO UPLOAD ERROR LOG END ***');
      return null;
    } catch (e) {
      // 기타 예상치 못한 에러
      print('일반 업로드 에러: $e');
      return null;
    }
  }
}