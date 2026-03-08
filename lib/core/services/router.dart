import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/camera/presentation/camera_screen.dart';
import '../../features/editor/presentation/editor_screen.dart';
import '../../features/filter_library/presentation/filter_library_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../../features/gallery/presentation/gallery_picker_screen.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  redirect: (context, state) {
    // 첫 실행: 온보딩 강제 없이 카메라 바로 시작 (Progressive Disclosure)
    return null;
  },
  routes: [
    GoRoute(
      path: '/',
      name: 'camera',
      builder: (context, state) => const CameraScreen(),
    ),
    GoRoute(
      path: '/editor',
      name: 'editor',
      builder: (context, state) {
        final extra = state.extra;
        if (extra is Map<String, String?>) {
          return EditorScreen(
            imagePath: extra['path'],
            assetId: extra['assetId'],
          );
        }
        return EditorScreen(imagePath: extra as String?);
      },
    ),
    GoRoute(
      path: '/library',
      name: 'library',
      builder: (context, state) => const FilterLibraryScreen(),
    ),
    GoRoute(
      path: '/settings',
      name: 'settings',
      builder: (context, state) => const SettingsScreen(),
    ),
    GoRoute(
      path: '/onboarding',
      name: 'onboarding',
      builder: (context, state) => const OnboardingScreen(),
    ),
    GoRoute(
      path: '/gallery',
      name: 'gallery',
      builder: (context, state) => const GalleryPickerScreen(),
    ),
  ],
  errorBuilder: (context, state) => Scaffold(
    body: Center(
      child: Text('페이지를 찾을 수 없습니다: ${state.uri}'),
    ),
  ),
);
