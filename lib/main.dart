import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/services/storage_service.dart';
import 'app.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 세로 모드 고정
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  // 상태바 투명
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  // Hive 초기화
  await StorageService.init();


  // Firebase 초기화 — google-services.json 추가 후 활성화
  // await Firebase.initializeApp();

  runApp(
    const ProviderScope(
      child: MoodFilmApp(),
    ),
  );
}
