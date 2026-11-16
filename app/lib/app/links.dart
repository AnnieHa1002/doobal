import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

/// 방침·약관·AI 고지 웹 페이지 (GitHub Pages, docs/개발_인계.md 다음 할 일 10).
/// 안드로이드 Health Connect 권한 화면의 처리방침 링크는 같은 주소를
/// android/app/src/main/res/values/strings.xml `privacy_policy_url`에 둔다 (바꿀 때 같이)
const policyBase = 'https://annieha1002.github.io/doobal-policy';
final privacyPolicyUrl = Uri.parse('$policyBase/privacy/');
final termsUrl = Uri.parse('$policyBase/terms/');
final aiNoticeUrl = Uri.parse('$policyBase/ai/');

/// 웹 페이지를 브라우저로 연다. 못 열면 false. 시험은 바꿔 끼운다
typedef LinkOpener = Future<bool> Function(Uri url);

final linkOpenerProvider = Provider<LinkOpener>(
  (ref) => (url) async {
    try {
      return await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  },
);
