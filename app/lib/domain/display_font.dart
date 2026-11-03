/// 표시 글꼴: 제목·숫자·버튼·딱지·이름표·굵은 글자 (UI 명세 0장, 16장 11/3). 설정에서 고르고,
/// 본문은 늘 고운 돋움이다. [scale]은 글꼴마다 보이는 크기를 맞추는 배율(명세 pt는 고운 바탕 1.0 기준),
/// [height]는 줄 높이 배율(null이면 글꼴 그대로). 개구·동글은 줄 높이를 고운 바탕만큼으로 줄인다
enum DisplayFont {
  gaegu('Gaegu', '개구', 1.3, 1.1),
  dongle('Dongle', '동글', 1.5, 1.0),
  batang('GowunBatang', '고운 바탕', 1.0, null);

  const DisplayFont(this.family, this.label, this.scale, this.height);

  /// pubspec 글꼴 이름
  final String family;

  /// 설정에 보이는 이름
  final String label;
  final double scale;
  final double? height;

  /// 저장한 이름(Profile.displayFont)으로. 없거나 모르는 이름이면 기본 개구
  static DisplayFont fromName(String? name) =>
      values.firstWhere((f) => f.name == name, orElse: () => DisplayFont.gaegu);
}
