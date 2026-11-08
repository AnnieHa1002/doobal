// 동행과 이야기 (companions.json, M4). 장 0은 프롤로그(만남 장면), 그림은 0장·8장만 있다

/// 걷는 중 연출 (companions.json pace): ahead 앞서 뛰어갔다 돌아옴, walkOnly 늘 걷기, match 사용자에 맞춤
enum CompanionPace { ahead, walkOnly, match }

/// 동행 그림의 층을 숨기는 때 (companions.json hideLayerWhen). finaleRead = 마지막 장을 읽은 뒤
enum HideLayerWhen { finaleRead }

/// 대사의 말하는 이 (narr는 지문)
enum StorySpeaker { narr, companion, me }

/// 이야기 한 줄. [face]는 동행 표정 id (동행이 말할 때만)
class StoryLine {
  const StoryLine({required this.who, required this.text, this.face});

  final StorySpeaker who;
  final String text;
  final String? face;

  factory StoryLine.fromJson(Map<String, dynamic> j) => StoryLine(
        who: switch (j['who']) {
          'narr' => StorySpeaker.narr,
          'companion' => StorySpeaker.companion,
          'me' => StorySpeaker.me,
          final w => throw FormatException('모르는 말하는 이: $w'),
        },
        text: j['text'] as String,
        face: j['face'] as String?,
      );
}

/// 이야기 한 장. [art]는 story_layers.json 장면 id (0장·8장만), [prop]은 이 장에서 받는 완결 소품,
/// [choices]는 장 끝의 고르기 (0장: together·solo)
class StoryChapter {
  const StoryChapter({
    required this.no,
    required this.title,
    required this.lines,
    this.art,
    this.prop,
    this.choices = const [],
  });

  final int no;
  final String title;
  final List<StoryLine> lines;
  final String? art;
  final String? prop;
  final List<String> choices;

  factory StoryChapter.fromJson(Map<String, dynamic> j) => StoryChapter(
        no: j['no'] as int,
        title: j['title'] as String,
        lines: [for (final l in j['lines'] as List) StoryLine.fromJson(l as Map<String, dynamic>)],
        art: j['art'] as String?,
        prop: j['prop'] as String?,
        choices: (j['choice'] as List?)?.cast<String>() ?? const [],
      );
}

/// 동행 한 명
class Companion {
  const Companion({
    required this.id,
    required this.name,
    required this.species,
    required this.speciesName,
    required this.terrain,
    required this.pace,
    required this.finaleProp,
    required this.faces,
    required this.chapters,
    this.hideLayerOnFinale,
    this.hideLayerWhen,
  });

  final String id;
  final String name;
  final String species;

  /// 종의 화면 이름 (길 위 만남 ‘새 동행을 만났어요’ 아래 줄)
  final String speciesName;

  /// 어울리는 지형 (만남 확률이 오른다). 명소 terrain 값과 같다
  final String terrain;
  final CompanionPace pace;

  /// 이야기 완결 때 받는 소품 id
  final String finaleProp;

  /// 완결 장을 읽은 뒤 동행 그림에서 숨기는 층 (심 박사 안경)
  final String? hideLayerOnFinale;

  /// [hideLayerOnFinale]를 숨기는 때. 없으면 숨기지 않는다
  final HideLayerWhen? hideLayerWhen;
  final List<String> faces;

  /// 장 번호 순서
  final List<StoryChapter> chapters;

  factory Companion.fromJson(Map<String, dynamic> j) => Companion(
        id: j['id'] as String,
        name: j['name'] as String,
        species: j['species'] as String,
        speciesName: j['speciesName'] as String,
        terrain: j['terrain'] as String,
        pace: switch (j['pace']) {
          'ahead' => CompanionPace.ahead,
          'walkOnly' => CompanionPace.walkOnly,
          'match' => CompanionPace.match,
          final p => throw FormatException('모르는 pace: $p (${j['id']})'),
        },
        finaleProp: j['finaleProp'] as String,
        hideLayerOnFinale: j['hideLayerOnFinale'] as String?,
        hideLayerWhen: switch (j['hideLayerWhen']) {
          null => null,
          'finaleRead' => HideLayerWhen.finaleRead,
          final w => throw FormatException('모르는 hideLayerWhen: $w (${j['id']})'),
        },
        faces: (j['faces'] as List).cast<String>(),
        chapters: [
          for (final c in j['chapters'] as List) StoryChapter.fromJson(c as Map<String, dynamic>),
        ]..sort((a, b) => a.no.compareTo(b.no)),
      );
}

/// companions.json 전체
class CompanionCatalog {
  CompanionCatalog(this.companions);

  final List<Companion> companions;

  late final Map<String, Companion> _byId = {for (final c in companions) c.id: c};

  Companion? byId(String id) => _byId[id];
}

CompanionCatalog parseCompanions(Map<String, dynamic> json) => CompanionCatalog([
      for (final c in json['companions'] as List) Companion.fromJson(c as Map<String, dynamic>),
    ]);
