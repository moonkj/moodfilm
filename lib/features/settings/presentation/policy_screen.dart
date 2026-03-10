import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class PolicyScreen extends StatelessWidget {
  const PolicyScreen({super.key, required this.title, required this.sections});

  final String title;
  final List<PolicySection> sections;

  // ── 개인정보처리방침 ──────────────────────────────────────────────────
  static const privacyPolicy = PolicyScreen(
    title: '개인정보처리방침',
    sections: [
      PolicySection(
        heading: null,
        body:
            'Like it! (이하 "앱")은 사용자의 개인정보를 중요하게 생각합니다. '
            '본 방침은 앱을 사용할 때 어떤 정보가 수집되고 어떻게 사용되는지 설명합니다.\n\n'
            '최종 업데이트: 2026년 3월 10일',
      ),
      PolicySection(
        heading: '1. 수집하는 정보',
        body:
            '본 앱은 다음 정보에 접근합니다.\n\n'
            '• 카메라 — 사진 및 동영상 촬영을 위해 사용됩니다. 촬영된 이미지는 기기 내에서만 처리되며 외부 서버로 전송되지 않습니다.\n\n'
            '• 사진 라이브러리 — 갤러리에서 사진/동영상을 불러오거나 편집 결과물을 저장하기 위해 사용됩니다.\n\n'
            '• 마이크 — 동영상 녹화 시 오디오를 함께 녹음하기 위해 사용됩니다.',
      ),
      PolicySection(
        heading: '2. 수집하지 않는 정보',
        body:
            '• 이름, 이메일, 전화번호 등 개인 식별 정보를 수집하지 않습니다.\n'
            '• 위치 정보를 수집하지 않습니다.\n'
            '• 광고 식별자(IDFA)를 수집하거나 사용하지 않습니다.\n'
            '• 사용자 행동 데이터를 외부 서비스로 전송하지 않습니다.',
      ),
      PolicySection(
        heading: '3. 데이터 처리 방식',
        body:
            '앱에서 촬영하거나 불러온 사진/동영상은 오직 기기 내에서만 처리됩니다. '
            '모든 필터 적용 및 편집 작업은 온디바이스(On-device)로 이루어지며, '
            '어떠한 이미지도 외부 서버로 전송되지 않습니다.',
      ),
      PolicySection(
        heading: '4. 제3자 서비스',
        body: '본 앱은 현재 제3자 분석·광고·트래킹 서비스를 사용하지 않습니다.',
      ),
      PolicySection(
        heading: '5. 데이터 보관',
        body:
            '앱 내에서 생성된 결과물(편집된 사진, 필터 설정값 등)은 사용자의 기기에만 저장됩니다. '
            '앱을 삭제하면 앱과 관련된 모든 데이터가 함께 삭제됩니다.',
      ),
      PolicySection(
        heading: '6. 어린이 개인정보 보호',
        body:
            '본 앱은 만 4세 이상 전체 연령을 대상으로 하며, '
            '13세 미만 어린이의 개인정보를 의도적으로 수집하지 않습니다.',
      ),
      PolicySection(
        heading: '7. 권한 관리',
        body:
            '앱에 부여된 권한(카메라, 사진 라이브러리, 마이크)은 '
            'iOS 설정 → 개인정보 보호에서 언제든지 변경하거나 철회할 수 있습니다.',
      ),
      PolicySection(
        heading: '8. 문의',
        body: '개인정보처리방침에 관한 문의사항이 있으시면 아래로 연락해 주세요.\n\nimurmkj@gmail.com',
      ),
      PolicySection(
        heading: '9. 방침 변경',
        body:
            '본 방침이 변경될 경우 앱 업데이트를 통해 공지합니다. '
            '지속적인 앱 사용은 변경된 방침에 동의한 것으로 간주됩니다.',
      ),
    ],
  );

  // ── 이용약관 ──────────────────────────────────────────────────────────
  static const termsOfService = PolicyScreen(
    title: '이용약관',
    sections: [
      PolicySection(
        heading: null,
        body:
            '본 이용약관은 Like it! 앱(이하 "서비스") 이용에 관한 조건을 규정합니다.\n\n'
            '최종 업데이트: 2026년 3월 10일',
      ),
      PolicySection(
        heading: '1. 서비스 이용',
        body:
            '본 서비스는 감성 필터 카메라 앱으로, 사진 및 동영상 촬영과 편집 기능을 제공합니다. '
            '서비스를 이용함으로써 본 약관에 동의하는 것으로 간주됩니다.',
      ),
      PolicySection(
        heading: '2. 지식재산권',
        body:
            '앱 내 포함된 필터, 아이콘, UI 디자인 등 모든 콘텐츠의 지식재산권은 개발자에게 있습니다. '
            '사용자가 촬영·편집한 사진의 저작권은 사용자에게 있습니다.',
      ),
      PolicySection(
        heading: '3. 금지 행위',
        body:
            '• 앱을 역공학(reverse engineering)하거나 소스코드를 추출하는 행위\n'
            '• 앱을 상업적 목적으로 무단 복제·배포하는 행위\n'
            '• 타인의 권리를 침해하는 용도로 사용하는 행위',
      ),
      PolicySection(
        heading: '4. 면책 조항',
        body:
            '본 서비스는 "있는 그대로(as-is)" 제공됩니다. '
            '개발자는 서비스 이용으로 인한 직간접적 손해에 대해 책임을 지지 않습니다.',
      ),
      PolicySection(
        heading: '5. 서비스 변경 및 중단',
        body:
            '개발자는 사전 고지 없이 서비스의 일부 또는 전부를 변경하거나 중단할 수 있습니다.',
      ),
      PolicySection(
        heading: '6. 준거법',
        body: '본 약관은 대한민국 법률에 따라 해석되고 적용됩니다.',
      ),
      PolicySection(
        heading: '7. 문의',
        body: '이용약관에 관한 문의사항은 아래로 연락해 주세요.\n\nimurmkj@gmail.com',
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      appBar: AppBar(
        title: Text(title),
        backgroundColor: AppColors.primary,
        elevation: 0,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        itemCount: sections.length,
        itemBuilder: (context, i) {
          final s = sections[i];
          return Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (s.heading != null) ...[
                  Text(
                    s.heading!,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF3D3531),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 6),
                ],
                Text(
                  s.body,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF7A706A),
                    height: 1.7,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class PolicySection {
  const PolicySection({required this.heading, required this.body});
  final String? heading;
  final String body;
}
