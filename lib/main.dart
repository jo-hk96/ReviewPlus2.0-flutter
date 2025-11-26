import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'profile_service.dart';

const String baseUrl = 'http://10.0.2.2:9090';
const String homeUrl = '$baseUrl/';
const String myPageLoginUrl = '$baseUrl/UserMypage';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ReviewPlus 2.0',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const SpringWebViewPage(url: homeUrl),
    );
  }
}

class SpringWebViewPage extends StatefulWidget {
  final String url;
  const SpringWebViewPage({super.key, required this.url});

  @override
  State<SpringWebViewPage> createState() => _SpringWebViewPageState();
}

class _SpringWebViewPageState extends State<SpringWebViewPage> {
  late final WebViewController _controller;

  ProfileService? _profileService;
  String? _sessionId;

  bool _isLoading = true;
  bool _isLoggedIn = false;
  String? _profileImageUrl;

  @override
  void initState() {
    super.initState();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'ProfileChannel',
        onMessageReceived: _onJsMessage,
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) => setState(() => _isLoading = true),
          onPageFinished: _onPageFinished,
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  // -------------------- cookie extract ----------------------------
  Future<String?> _extractSession() async {
    try {
      final result = await _controller.runJavaScriptReturningResult(
        'document.cookie',
      );

      String cookie = result.toString();

      if (cookie.startsWith('"') && cookie.endsWith('"')) {
        cookie = cookie.substring(1, cookie.length - 1);
      }

      final parts = cookie.split(';');
      for (final p in parts) {
        final t = p.trim();
        if (t.startsWith("SESSION=")) {
          return t.substring(8);
        }
        if (t.startsWith("JSESSIONID=")) {
          return t.substring(11);
        }
      }
    } catch (e) {
      debugPrint("cookie parse error: $e");
    }
    return null;
  }

  // -------------------- page finish ----------------------------
  Future<void> _onPageFinished(String url) async {
    setState(() => _isLoading = false);

    await _injectJS();

    final sid = await _extractSession();
    if (sid == null) {
      _sessionId = null;
      _profileService = null;

      setState(() {
        _isLoggedIn = false;
        _profileImageUrl = null;
      });
      return;
    }

    _sessionId = sid;

    if (_profileService == null) {
      _profileService = ProfileService(
        baseUrl: baseUrl,
        currentUserId: "1",
        jsessionId: sid,
      );
    } else {
      _profileService!.updateSession(sid);
    }

    await _checkAuth();
  }

  // -------------------- inject JS ----------------------------
  Future<void> _injectJS() async {
    await _controller.runJavaScript("""
      window.updateProfileImage = function(url){
        const img = document.getElementById("profile-img");
        if(img){
          img.src = url;
          img.removeAttribute('srcset');
        }
      };
    """);
  }

  // -------------------- JS messages ----------------------------
  void _onJsMessage(JavaScriptMessage msg) {
    if (msg.message == "upload_start") {
      _handleUpload();
    }
    if (msg.message == "logout_success") {
      _handleLogout();
    }
  }

  // -------------------- check auth ----------------------------
  Future<void> _checkAuth() async {
    if (_profileService == null) return;

    final resp = await _profileService!.checkAuth();

    if (resp["isAuthenticated"] == true) {
      final img = resp["profileImageUrl"];
      final cacheUrl = "$img?t=${DateTime.now().millisecondsSinceEpoch}";
      setState(() {
        _isLoggedIn = true;
        _profileImageUrl = cacheUrl;
      });
    } else {
      setState(() {
        _isLoggedIn = false;
        _profileImageUrl = null;
      });
    }
  }

  // -------------------- upload ----------------------------
  Future<void> _handleUpload() async {
    final sid = await _extractSession();
    if (sid == null) {
      await _controller.runJavaScript(
        "handleUploadFailure('세션이 만료되었습니다. 다시 로그인 해주세요.');",
      );
      return;
    }

    _profileService!.updateSession(sid);

    final newUrl = await _profileService!.uploadProfileImage();
    if (newUrl == null) {
      await _controller.runJavaScript(
        "handleUploadFailure('업로드 실패');",
      );
      return;
    }

    final cacheUrl = "$newUrl?t=${DateTime.now().millisecondsSinceEpoch}";

    setState(() => _profileImageUrl = cacheUrl);

    await _controller.runJavaScript("updateProfileImage('$cacheUrl');");
  }

  void _handleLogout() {
    setState(() {
      _isLoggedIn = false;
      _profileImageUrl = null;
      _sessionId = null;
      _profileService = null;
    });
  }

  // -------------------- back ----------------------------
  Future<void> _handleBack() async {
    if (await _controller.canGoBack()) {
      _controller.goBack();
    } else {
      SystemNavigator.pop();
    }
  }

  // ---------------------- UI ----------------------
  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        await _handleBack();
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: 0,
          backgroundColor: const Color(0xFF040F16),
        ),
        body: Stack(
          children: [
            WebViewWidget(controller: _controller),
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
          ],
        ),
        bottomNavigationBar: BottomAppBar(
          color: const Color(0xFF040F16),
          child: SizedBox(
            height: 60,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                IconButton(
                  icon: const Icon(Icons.home, color: Colors.white),
                  onPressed: () => _controller.loadRequest(Uri.parse(homeUrl)),
                ),

                IconButton(
                  icon: const Icon(
                    Icons.people_alt_rounded,
                    color: Colors.white,
                  ),
                  onPressed: () =>
                      _controller.loadRequest(Uri.parse(myPageLoginUrl)),
                ),

                IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.white),
                  onPressed: () => _controller.reload(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
