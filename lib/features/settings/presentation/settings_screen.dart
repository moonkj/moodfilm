import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
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
