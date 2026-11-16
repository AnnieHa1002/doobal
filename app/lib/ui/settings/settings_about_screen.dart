import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/links.dart';
import '../common/notice_page.dart';
import '../common/screen_header.dart';
import '../common/toast.dart';
import 'settings_rows.dart';

/// 웹 페이지가 아직 없는 문서(그림 출처·이전 처리방침)의 안내. 법률 문장은 원문 그대로만 쓴다. 임의로 지어 쓰지 않는다
const _docPending = '문서를 준비하고 있어요';

/// 링크를 못 열었을 때 (브라우저가 없는 등)
const linkFailedText = '페이지를 열 수 없어요';

/// 설정 · 앱 정보 (캔버스 10-3): 그림 출처, AI 사용 고지, 오픈소스 라이선스, 이용약관, 개인정보처리방침,
/// 이전 처리방침. AI 고지·약관·처리방침은 웹 페이지를 브라우저로 연다 (lib/app/links.dart)
class SettingsAboutScreen extends ConsumerWidget {
  const SettingsAboutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void open(String title) => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => NoticePage(title: title, message: _docPending)),
        );
    Future<void> web(Uri url) async {
      final ok = await ref.read(linkOpenerProvider)(url);
      if (!ok && context.mounted) showToast(context, linkFailedText);
    }
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
                    SettingsRow('AI 사용 고지', onTap: () => web(aiNoticeUrl)),
                    SettingsRow(
                      '오픈소스 라이선스',
                      onTap: () => showLicensePage(context: context, applicationName: '두발'),
                    ),
                    SettingsRow('이용약관', onTap: () => web(termsUrl)),
                    SettingsRow('개인정보처리방침', onTap: () => web(privacyPolicyUrl)),
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
