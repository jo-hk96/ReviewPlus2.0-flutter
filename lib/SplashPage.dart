import 'package:flutter/material.dart';
import 'dart:async';
import 'main.dart';

class SplashPage extends StatefulWidget {
  final Color backgroundColor; // 배경 색
  final String logoPath; // 로고 PNG 경로
  final Duration duration; // 스플래시 유지 시간

  const SplashPage({
    super.key,
    required this.backgroundColor,
    required this.logoPath,
    this.duration = const Duration(seconds: 2),
  });

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();

    // duration만큼 보여준 후 WebView로 이동
    Timer(widget.duration, () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => SpringWebViewPage(url: homeUrl),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: widget.backgroundColor,
      body: Center(
        child: Image.asset(
          widget.logoPath,
          width: 150,
          height: 150,
        ),
      ),
    );
  }
}
