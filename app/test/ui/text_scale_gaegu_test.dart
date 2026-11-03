import 'package:doobal/domain/display_font.dart';

import 'text_scale_test.dart' as text_scale;
import 'ui_env.dart';

// 표시 글꼴을 개구(으)로 고른 앱에서 같은 글자 크기 점검(text_scale_test)을 한 번 더 돈다 (16장 11/3:
// 표시 글꼴 고르기, 넘침 확인). 테스트 글꼴은 글자가 정사각형이라 실제보다 넓게 잰다
void main() {
  testDisplayFont = DisplayFont.gaegu;
  text_scale.main();
}
