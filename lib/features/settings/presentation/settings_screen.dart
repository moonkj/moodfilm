import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/services/storage_service.dart';
import '../../../native_plugins/camera_engine/camera_engine.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final prefs = StorageService.prefs;
    return Scaffold(
      backgroundColor: AppColors.primary,
      appBar: AppBar(title: const Text('설정')),
      body: ListView(
        children: [
          // 카메라 설정
          _SettingsSection(
            title: '카메라',
            children: [
              SwitchListTile(
                secondary: const Icon(Icons.volume_off_rounded),
                title: const Text('무음 셔터'),
                subtitle: const Text('촬영음 없이 사진 찍기 (1920×1080 저장)'),
                value: prefs.isSilentShutter,
                onChanged: (v) {
                  setState(() {
                    prefs.isSilentShutter = v;
                    prefs.save();
                  });
                },
                activeThumbColor: AppColors.accent,
              ),
            ],
          ),
          // 앱 정보
          _SettingsSection(
            title: '앱 정보',
            children: [
              const ListTile(
                leading: Icon(Icons.info_outline_rounded),
                title: Text('버전'),
                trailing: Text('1.0.0', style: AppTypography.caption),
              ),
              ListTile(
                leading: const Icon(Icons.privacy_tip_outlined),
                title: const Text('개인정보처리방침'),
                onTap: () {},
              ),
              ListTile(
                leading: const Icon(Icons.article_outlined),
                title: const Text('이용약관'),
                onTap: () {},
              ),
              ListTile(
                leading: const Icon(Icons.mail_outline_rounded),
                title: const Text('문의하기'),
                onTap: () {},
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
          child: Text(title,
              style: AppTypography.caption.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5)),
        ),
        ...children,
      ],
    );
  }
}
