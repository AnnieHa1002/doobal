import 'dart:convert';
import 'dart:ui' as ui;

import 'package:doobal/domain/geo.dart';
import 'package:doobal/domain/scene.dart';
import 'package:doobal/ui/scene/scene_art.dart';
import 'package:doobal/ui/scene/scene_art_painter.dart';
import 'package:doobal/ui/scene/scene_painter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../domain/helpers.dart';

/// 실제 번들에 [extra] 파일이 있는 척한다. 읽은 그림 이름을 적어 둔다
class _Bundle extends AssetBundle {
  _Bundle({this.extra = const {}, this.scene});

  final Set<String> extra;
  final String Function(String)? scene;
  final loaded = <String>[];

  @override
  Future<ByteData> load(String key) async {
    if (key.contains('/backgrounds/')) loaded.add(key.split('/').last);
    if (extra.contains(key)) {
      // 작은 진짜 그림으로 대신한다
      return rootBundle.load('assets/backgrounds/v11/sky_star_dot_v01_clean.png');
    }
    if (key == 'assets/data/scene.json' && scene != null) {
      final text = await rootBundle.loadString(key);
      return ByteData.sublistView(Uint8List.fromList(utf8.encode(scene!(text))));
    }
    return rootBundle.load(key);
  }
}

const _dir = 'assets/backgrounds/v11';
const _seoul = LatLng(37.5776, 126.9769);

SceneLook _look(int month) =>
    sceneLook(DateTime.utc(2026, month, 15, 3), _seoul, false, landmarks, rules);

void main() {
  group('겨울 후경 (scene.json winterTiles)', () {
    const winter = [
      'bg_far_capital_winter_wide_v13_part1_clean.png',
      'bg_far_capital_winter_wide_v13_part2_clean.png',
      'bg_far_capital_winter_wide_v13_part3_clean.png',
    ];

    Future<_Bundle> run(WidgetTester tester, int month, Set<String> extra) async {
      final bundle = _Bundle(extra: extra);
      final art = (await tester.runAsync(
        () => SceneArt.load(bundle, _look(month), false, 1 / 3, 3),
      ))!;
      art.dispose();
      return bundle;
    }

    testWidgets('파일이 없으면 지금 그림을 그대로 쓴다', (tester) async {
      final b = await run(tester, 1, const {});
      expect(b.loaded, contains('bg_far_capital_wide_part1_v10_clean.png'));
    });

    testWidgets('세 장이 다 있으면 겨울에는 겨울판', (tester) async {
      final b = await run(tester, 1, {for (final n in winter) '$_dir/$n'});
      for (final n in winter) {
        expect(b.loaded, contains(n));
      }
      expect(b.loaded, isNot(contains('bg_far_capital_wide_part1_v10_clean.png')));
    });

    testWidgets('한 장이라도 없으면 기본판', (tester) async {
      final b = await run(tester, 1, {'$_dir/${winter[0]}', '$_dir/${winter[1]}'});
      expect(b.loaded, contains('bg_far_capital_wide_part1_v10_clean.png'));
    });

    testWidgets('겨울이 아니면 겨울판을 안 읽는다', (tester) async {
      final b = await run(tester, 7, {for (final n in winter) '$_dir/$n'});
      for (final n in winter) {
        expect(b.loaded, isNot(contains(n)));
      }
    });

    testWidgets('WebP가 있으면 WebP를 쓴다', (tester) async {
      final b = await run(tester, 1, {
        for (final n in winter) '$_dir/${n.replaceAll('.png', '.webp')}',
      });
      expect(b.loaded, contains(winter[0].replaceAll('.png', '.webp')));
      expect(b.loaded, isNot(contains('bg_far_capital_wide_part1_v10_clean.png')));
    });
  });

  group('이음새 수정본 (seamFixTiles)', () {
    const seam = [
      'bg_far_jeolla_wide_part1_v13_clean.png',
      'bg_far_jeolla_wide_part2_v13_clean.png',
      'bg_far_jeolla_wide_part3_v13_clean.png',
    ];
    SceneLook jeolla() {
      final l = _look(7);
      return SceneLook(l.mix, l.sky, l.celestial, 'jeolla', l.season);
    }

    testWidgets('adopted false면 안 쓰고, true면 쓴다', (tester) async {
      final extra = {for (final n in seam) '$_dir/$n'};
      final off = _Bundle(extra: extra);
      (await tester.runAsync(() => SceneArt.load(off, jeolla(), false, 1 / 3, 3)))!.dispose();
      expect(off.loaded, contains('bg_far_jeolla_wide_part1_v10_clean.png'));
      expect(off.loaded, isNot(contains(seam[0])));

      final on = _Bundle(
        extra: extra,
        scene: (text) {
          final j = jsonDecode(text) as Map<String, dynamic>;
          j['backdrops']['jeolla']['seamFixTiles']['adopted'] = true;
          return jsonEncode(j);
        },
      );
      (await tester.runAsync(() => SceneArt.load(on, jeolla(), false, 1 / 3, 3)))!.dispose();
      expect(on.loaded, contains(seam[0]));
      expect(on.loaded, isNot(contains('bg_far_jeolla_wide_part1_v10_clean.png')));
    });
  });

  group('넓은 캠프 그림 (scene.json rest.files)', () {
    const wide = [
      'bg_rest_camp_back_wide_v01_clean.png',
      'bg_rest_camp_back_grass_wide_v01_clean.png',
      'bg_rest_camp_front_wide_v01_clean.png',
      'bg_rest_camp_front_grass_wide_v01_clean.png',
    ];

    testWidgets('파일이 없으면 v11 캠프를 읽는다', (tester) async {
      final art = (await tester.runAsync(() => SceneArt.load(_Bundle(), _look(7), true, 1 / 3, 3)))!;
      expect(art.wideCamp, isNull);
      expect(art.images.containsKey('bg_rest_camp_back_v11_clean.png'), isTrue);
      art.dispose();
    });

    testWidgets('네 장이 다 있으면 넓은 그림을 쓰고 v11은 안 읽는다', (tester) async {
      final art = (await tester.runAsync(
        () => SceneArt.load(_Bundle(extra: {for (final n in wide) '$_dir/$n'}), _look(7), true, 1 / 3, 3),
      ))!;
      expect(art.wideCamp, isNotNull);
      expect(art.images.containsKey('bg_rest_camp_back_v11_clean.png'), isFalse);
      // 그려도 문제없다
      for (final pass in [ScenePass.restBack, ScenePass.restFront]) {
        final recorder = ui.PictureRecorder();
        SceneArtPainter(
          art: art,
          look: _look(7),
          mode: SceneMode.rest,
          distanceM: 0,
          rules: rules,
          onSea: false,
          pass: pass,
          elapsed: 0,
          camp: campTheme,
          layoutSize: const Size(390, 844),
        ).paint(Canvas(recorder), const Size(585, 844));
        recorder.endRecording().dispose();
      }
      art.dispose();
    });

    testWidgets('한 장이라도 없으면 v11', (tester) async {
      final art = (await tester.runAsync(
        () => SceneArt.load(_Bundle(extra: {'$_dir/${wide[0]}'}), _look(7), true, 1 / 3, 3),
      ))!;
      expect(art.wideCamp, isNull);
      art.dispose();
    });
  });

  group('계절 색', () {
    testWidgets('땅은 회색조 바탕 + 풀 두 장을 읽고, 풀 값은 palette.json', (tester) async {
      final art = (await tester.runAsync(() => SceneArt.load(_Bundle(), _look(4), false, 1 / 3, 3)))!;
      expect(art.images.containsKey('bg_lower_bank_base_v11_clean.png'), isTrue);
      expect(art.images.containsKey('bg_lower_bank_grass_v11_clean.png'), isTrue);
      expect(art.images.containsKey('bg_lower_bank_spring_v11_clean.png'), isFalse);
      expect(art.grass!.base, 150);
      expect(art.grass!.seasons['autumn'], 0xFFC79A5B);
      art.dispose();
    });

    testWidgets('들판 회색조 파일이 없으면 계절 완성 그림을 쓴다', (tester) async {
      final art = (await tester.runAsync(() => SceneArt.load(_Bundle(), _look(10), false, 1 / 3, 3)))!;
      expect(art.images.containsKey('bg_back_meadow_autumn_v10_preview.png'), isTrue);
      art.dispose();
    });

    testWidgets('들판 회색조 두 장이 생기면 그것을 읽는다', (tester) async {
      final art = (await tester.runAsync(() => SceneArt.load(
            _Bundle(extra: {
              '$_dir/bg_back_meadow_v10_clean.png',
              '$_dir/bg_back_meadow_grass_v10_clean.png',
            }),
            _look(10),
            false,
            1 / 3,
            3,
          )))!;
      expect(art.meadowGray, ['bg_back_meadow_v10_clean.png', 'bg_back_meadow_grass_v10_clean.png']);
      expect(art.images.containsKey('bg_back_meadow_v10_clean.png'), isTrue);
      expect(art.images.containsKey('bg_back_meadow_autumn_v10_preview.png'), isFalse);
      final recorder = ui.PictureRecorder();
      SceneArtPainter(
        art: art,
        look: _look(10),
        mode: SceneMode.walking,
        distanceM: 100,
        rules: rules,
        onSea: false,
        pass: ScenePass.background,
        elapsed: 0,
        seed: 'test',
      ).paint(Canvas(recorder), const Size(390, 844));
      recorder.endRecording().dispose();
      art.dispose();
    });

    testWidgets('가을은 후경이 황갈로 곱해지고, 여름 후경은 그대로다', (tester) async {
      final summer = _look(7);
      final art = (await tester.runAsync(() => SceneArt.load(_Bundle(), summer, false, 1 / 3, 3)))!;
      Future<List<int>> pixel(SceneLook look) async {
        final recorder = ui.PictureRecorder();
        SceneArtPainter(
          art: art,
          look: look,
          mode: SceneMode.walking,
          distanceM: 0,
          rules: rules,
          onSea: false,
          pass: ScenePass.background,
          elapsed: 0,
          seed: 'test',
        ).paint(Canvas(recorder), const Size(390, 844));
        final picture = recorder.endRecording();
        final image = await picture.toImage(390, 844);
        final data = (await image.toByteData())!;
        // 후경 가운데쯤
        final i = (500 * 390 + 195) * 4;
        final out = [data.getUint8(i), data.getUint8(i + 1), data.getUint8(i + 2)];
        image.dispose();
        picture.dispose();
        return out;
      }

      final autumn = SceneLook(summer.mix, summer.sky, summer.celestial, summer.backdrop, Season.autumn);
      final plain = (await tester.runAsync(() => pixel(summer)))!;
      final tinted = (await tester.runAsync(() => pixel(autumn)))!;
      expect(tinted, isNot(plain));
      // 황갈을 곱하면 파랑이 가장 많이 줄어든다
      expect(plain[2] - tinted[2], greaterThan(plain[0] - tinted[0]));
      art.dispose();
    });
  });
}
