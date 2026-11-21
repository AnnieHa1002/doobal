// 하루 카드 엽서형 규칙 (config report.card, 16장 11/19 하루 카드 개편, 캔버스 2-3·2-4 DayCardV D안).
// 화면 없이 순수하게 읽고, 틀린 값은 FormatException으로 멈춘다

/// 카드 칩 하나가 보여 주는 값 (config report.card.chips)
enum CardChip {
  /// 하루 걸음 (‘3,000 보’)
  steps,

  /// 물감 길 거리 (‘0.8km 물감 길’)
  paintTrailKm,

  /// 그날 번 럭 (‘+37 럭’, 하루 요약 coins 합)
  coinsGained,

  /// 여러 날 걸음 합
  stepsTotal,

  /// 여러 날 하루 평균 걸음
  stepsDailyAvg,
}

/// 카드 종류 (문장 템플릿·칩·공유를 고른다, config report.card.sentence.pick)
enum CardKind {
  /// 하루, 걸었다
  day,

  /// 카드 날 안에 명소에 닿았다 (하루든 여러 날이든)
  arrived,

  /// 하루, 0보
  rest,

  /// 여러 날, 하루라도 걸었다
  multi,

  /// 여러 날, 모두 0보
  multiRest,
}

/// 문장 템플릿 (config report.card.sentence). 자리 글자는 {dest}·{km}·{n}만
class CardSentences {
  const CardSentences({
    required this.day,
    required this.arrived,
    required this.rest,
    required this.multi,
    required this.multiRest,
    required this.noJourneyDay,
    required this.noJourneyMulti,
    required this.kmDigits,
  });

  final String day, arrived, rest, multi, multiRest;

  /// 여정이 없을 때 (여행 경비로 모임) — {dest}가 없다
  final String noJourneyDay, noJourneyMulti;

  /// {km}의 소수 자리 (kmFormat ‘0.0’ → 1)
  final int kmDigits;

  factory CardSentences.fromJson(Map<String, dynamic> j) {
    final t = j['templates'] as Map<String, dynamic>;
    final none = j['noJourney'] as Map<String, dynamic>;
    String read(Map<String, dynamic> m, String key, Set<String> allowed) {
      final v = m[key];
      if (v is! String || v.isEmpty) {
        throw FormatException('report.card.sentence: $key 문장이 없다');
      }
      for (final hole in RegExp(r'\{(\w+)\}').allMatches(v)) {
        if (!allowed.contains(hole.group(1))) {
          throw FormatException('report.card.sentence.$key: 모르는 자리 {${hole.group(1)}}');
        }
      }
      return v;
    }

    final format = j['kmFormat'] as String;
    final m = RegExp(r'^0(?:\.(0+))?$').firstMatch(format);
    if (m == null) throw FormatException('report.card.sentence.kmFormat: ‘0.0’ 꼴이어야 한다 ($format)');
    return CardSentences(
      day: read(t, 'day', {'dest', 'km'}),
      arrived: read(t, 'arrived', {'dest'}),
      rest: read(t, 'rest', const {}),
      multi: read(t, 'multi', {'n', 'dest', 'km'}),
      multiRest: read(t, 'multiRest', {'n'}),
      noJourneyDay: read(none, 'day', {'km'}),
      noJourneyMulti: read(none, 'multi', {'n', 'km'}),
      kmDigits: m.group(1)?.length ?? 0,
    );
  }
}

/// config report.card 전체
class DayCardRules {
  const DayCardRules({
    required this.postmark,
    required this.postmarkMulti,
    required this.sentences,
    required this.chipsDay,
    required this.chipsMulti,
    required this.chipsRest,
    required this.hideJourneyBarWithoutJourney,
    required this.restDayHollow,
    required this.shareExclude,
    required this.walkedPose,
    required this.restPose,
    required this.restTimePhase,
  });

  /// 소인 날짜 꼴 (하루 ‘M.d’, 여러 날 ‘M.d–M.d’)
  final String postmark;
  final String postmarkMulti;

  final CardSentences sentences;

  /// 칩 3 (하루·여러 날·쉬어 간 날)
  final List<CardChip> chipsDay, chipsMulti, chipsRest;

  /// 여정이 없으면 여정 막대를 숨긴다
  final bool hideJourneyBarWithoutJourney;

  /// 주간 점: 쉰 날(0보)·아직 안 온 날은 빈 점
  final bool restDayHollow;

  /// 공유하지 않는 카드 종류 (쉬어 간 날)
  final Set<CardKind> shareExclude;

  /// 장면 정령 자세 이름 (config character.rive.poses의 이름): 걸은 날 옆면 걷기, 쉬어 간 날 잠
  final String walkedPose;
  final String restPose;

  /// 쉬어 간 날 장면의 시간대 (scene.sky 구간 이름, ‘night’)
  final String restTimePhase;

  factory DayCardRules.fromJson(Map<String, dynamic> j) {
    if (j['style'] != 'postcard') {
      throw FormatException('report.card.style: postcard만 안다 (${j['style']})');
    }
    final postmark = j['postmark'] as Map<String, dynamic>;
    final single = postmark['format'] as String;
    final multi = postmark['multiDay'] as String;
    if (!_datePattern.hasMatch(single) || multi.split('–').length != 2 ||
        !multi.split('–').every(_datePattern.hasMatch)) {
      throw FormatException('report.card.postmark: M·d 꼴이어야 한다 ($single / $multi)');
    }
    final chips = j['chips'] as Map<String, dynamic>;
    List<CardChip> chipList(String key) => [
          for (final c in chips[key] as List)
            CardChip.values.firstWhere((v) => v.name == c,
                orElse: () => throw FormatException('report.card.chips.$key: 모르는 칩 $c')),
        ];
    final share = j['share'] as Map<String, dynamic>;
    final scene = j['scene'] as Map<String, dynamic>;
    final walked = scene['walked'] as Map<String, dynamic>;
    final rest = scene['rest'] as Map<String, dynamic>;
    final dots = j['weekDots'] as Map<String, dynamic>;
    return DayCardRules(
      postmark: single,
      postmarkMulti: multi,
      sentences: CardSentences.fromJson(j['sentence'] as Map<String, dynamic>),
      chipsDay: chipList('day'),
      chipsMulti: chipList('multi'),
      chipsRest: chipList('rest'),
      hideJourneyBarWithoutJourney:
          (j['journeyBar'] as Map<String, dynamic>)['hideWhenNoJourney'] as bool,
      restDayHollow: dots['restDay'] == 'hollow',
      shareExclude: {
        for (final k in share['excludeOn'] as List)
          CardKind.values.firstWhere((v) => v.name == k,
              orElse: () => throw FormatException('report.card.share.excludeOn: 모르는 종류 $k')),
      },
      walkedPose: walked['spirit'] as String,
      restPose: rest['spirit'] as String,
      restTimePhase: rest['timePhase'] as String,
    );
  }
}

/// 소인 날짜 꼴: M(달)과 d(날)이 하나씩, 나머지는 글자 그대로
final _datePattern = RegExp(r'^[^Md]*M[^Md]+d[^Md]*$');

/// [format]의 M·d를 [month]·[day]로 (‘M.d’ → ‘11.18’)
String formatPostmarkDate(String format, int month, int day) =>
    format.replaceFirst('M', '$month').replaceFirst('d', '$day');
