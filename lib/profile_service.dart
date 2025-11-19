import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';

class ProfileService {
  final Dio _dio = Dio();
  // 💡 Spring Boot 서버의 파일 업로드 엔드포인트
  final String uploadUrl =
      "http://10.0.2.2:9090/api/profile/upload/1"; // 사용자 ID 1 가정

  // ⭐️ 이미지 선택 및 업로드 함수 ⭐️
  Future<String?> uploadProfileImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image == null) {
      print('이미지 선택 취소');
      return null;
    }

    // 1. 파일 이름 설정
    String fileName = image.path.split('/').last;

    try {
      // 2. FormData 생성 및 파일 추가 (MultipartFile)
      FormData formData = FormData.fromMap({
        // Spring Boot 컨트롤러에서 @RequestParam("file")로 받을 이름과 일치해야 함!
        "file": await MultipartFile.fromFile(
          image.path,
          filename: fileName,
        ),
        // 필요하다면 다른 데이터도 함께 전송 가능 (예: userId)
        "userId": 1,
      });

      // 3. Dio 요청 실행
      Response response = await _dio.post(
        uploadUrl,
        data: formData,
        // 업로드 진행 상황을 보고 싶다면 onSendProgress 사용
        onSendProgress: (int sent, int total) {
          double progress = sent / total;
          print('업로드 진행률: ${(progress * 100).toStringAsFixed(0)}%');
        },
      );

      // 4. 응답 처리
      if (response.statusCode == 200 && response.data != null) {
        // Spring에서 Map<String, Object> 형태로 JSON을 반환했으므로 Map으로 받음
        Map<String, dynamic> responseData = response.data;

        if (responseData['success'] == true) {
          print("업로드 성공! 메시지: ${responseData['message']}");

          // ⭐️ 새로운 URL 추출 ⭐️
          String? newUrl = responseData['newImageUrl'];

          if (newUrl != null) {
            return newUrl; // 새로운 URL 반환
          }
        } else {
          print("서버 처리 실패: ${responseData['message']}");
        }
        return null; // 실패 또는 URL이 없는 경우
      } else {
        print("업로드 실패. 상태 코드: ${response.statusCode}");
        return null;
      }
    } on DioException catch (e) {
      // Dio 에러 처리 (네트워크 문제, 서버 에러 등)
      print('Dio 에러 발생: ${e.message}');
      print('응답: ${e.response?.data}');
      return null;
    } catch (e) {
      print('예상치 못한 에러 발생: $e');
      return null;
    }
  }
}

// ⭐️ UI에서 사용하는 예시 ⭐️
void main() async {
  // 실제 Flutter 앱에서는 위젯 내부에서 호출
  ProfileService service = ProfileService();
  String? newUrl = await service.uploadProfileImage();

  if (newUrl != null) {
    print('프로필 사진이 성공적으로 업데이트되었습니다. 새 URL: $newUrl');
    // 이 URL을 웹뷰의 updateProfileImage JS 함수에 전달하면 돼!
  } else {
    print('프로필 사진 업데이트 실패');
  }
}
