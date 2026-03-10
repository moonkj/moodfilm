import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/services/storage_service.dart';
import '../../../l10n/app_localizations.dart';
import 'policy_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final prefs = StorageService.prefs;
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: AppColors.primary,
      appBar: AppBar(title: Text(l10n.settings)),
      body: ListView(
        children: [
          // 카메라 설정
          _SettingsSection(
            title: l10n.camera,
            children: [
              SwitchListTile(
                secondary: const Icon(Icons.volume_off_rounded),
                title: Text(l10n.silentShutter),
                subtitle: Text(l10n.silentShutterSubtitle),
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
            title: l10n.appInfo,
            children: [
              ListTile(
                leading: const Icon(Icons.info_outline_rounded),
                title: Text(l10n.version),
                trailing: const Text('1.0.0', style: AppTypography.caption),
              ),
              ListTile(
                leading: const Icon(Icons.privacy_tip_outlined),
                title: Text(l10n.privacyPolicy),
                trailing: const Icon(Icons.chevron_right, size: 18, color: Color(0xFFBBB6B2)),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => PolicyScreen.privacyPolicy),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.article_outlined),
                title: Text(l10n.termsOfService),
                trailing: const Icon(Icons.chevron_right, size: 18, color: Color(0xFFBBB6B2)),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => PolicyScreen.termsOfService),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.mail_outline_rounded),
                title: Text(l10n.contactUs),
                trailing: const Icon(Icons.chevron_right, size: 18, color: Color(0xFFBBB6B2)),
                onTap: () => launchUrl(
                  Uri.parse('mailto:imurmkj@gmail.com?subject=${l10n.contactEmailSubject}'),
                  mode: LaunchMode.externalApplication,
                ),
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
