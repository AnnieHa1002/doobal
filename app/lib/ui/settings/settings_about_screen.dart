import 'package:flutter/material.dart';

import '../common/notice_page.dart';
import '../common/screen_header.dart';
import 'settings_rows.dart';

/// 문서 화면의 안내. 원문이 아직 리포에 없다.
/// TODO: 방침·약관·AI 고지는 https://annieha1002.github.io/doobal-policy/ 웹 페이지로 연다
/// (링크를 여는 패키지가 필요하다). 법률 문장은 원문 그대로만 쓴다. 임의로 지어 쓰지 않는다
const _docPending = '문서를 준비하고 있어요';

/// 설정 · 앱 정보 (캔버스 10-3): 그림 출처, AI 사용 고지, 오픈소스 라이선스, 이용약관, 개인정보처리방침,
/// 이전 처리방침
class SettingsAboutScreen extends StatelessWidget {
  const SettingsAboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    void open(String title) => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => NoticePage(title: title, message: _docPending)),
        );
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const ScreenHeader('앱 정보'),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  SettingsGroup([
                    SettingsRow('그림 출처', onTap: () => open('그림 출처')),
                    SettingsRow('AI 사용 고지', onTap: () => open('AI 사용 고지')),
                    SettingsRow(
                      '오픈소스 라이선스',
                      onTap: () => showLicensePage(context: context, applicationName: '두발'),
                    ),
                    SettingsRow('이용약관', onTap: () => open('이용약관')),
                    SettingsRow('개인정보처리방침', onTap: () => open('개인정보처리방침')),
                    SettingsRow('이전 처리방침 보기', onTap: () => open('이전 처리방침')),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
