import 'dart:io';
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';

class ProfileService {
  final String baseUrl;
  final String currentUserId;
  String jsessionId; // 변경 가능해야 하기 때문에 final 제거
  final Dio _dio = Dio();

  ProfileService({
    required this.baseUrl,
    required this.currentUserId,
    required this.jsessionId,
  }) {
    _dio.options.headers['Cookie'] = 'SESSION=$jsessionId';
  }

  /// ⭐ 세션 갱신 함수 (가장 중요함)
  void updateSession(String newSession) {
    jsessionId = newSession;
    _dio.options.headers['Cookie'] = 'SESSION=$newSession';
  }

  /// pick image
  Future<XFile?> _pickImage() async {
    final picker = ImagePicker();
    return picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
  }

  /// upload profile image
  Future<String?> uploadProfileImage() async {
    try {
      final file = await _pickImage();
      if (file == null) return null;

      final formData = FormData.fromMap({
        'userId': currentUserId,
        'file': await MultipartFile.fromFile(
          file.path,
          filename: file.name,
        ),
      });

      final resp = await _dio.post(
        '$baseUrl/api/profile/upload',
        data: formData,
        options: Options(
          followRedirects: false,
          validateStatus: (status) => status != null && status < 400,
        ),
      );

      if (resp.statusCode == 200) {
        final data = resp.data;
        final url = data['newImageUrl'];
        if (url == null) return null;
        return url.startsWith('http') ? url : '$baseUrl/$url';
      }

      return null;
    } catch (e) {
      debugPrint('upload error: $e');
    }
    return null;
  }

  /// auth check
  Future<Map<String, dynamic>> checkAuth() async {
    try {
      final resp = await _dio.get(
        '$baseUrl/api/user/check-auth',
        options: Options(
          followRedirects: false,
          validateStatus: (status) => status != null && status < 400,
        ),
      );

      if (resp.statusCode == 200) {
        return Map<String, dynamic>.from(resp.data);
      }
    } catch (e) {
      debugPrint('auth check error: $e');
    }

    return {'isAuthenticated': false};
  }
}
