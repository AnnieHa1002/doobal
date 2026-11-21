import 'dart:typed_data';

import 'package:doobal/domain/boat.dart';
import 'package:doobal/domain/look.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

// 상점 배 색 (T4c, 16장 11/6, boats.json v4 recolorRule·recolor). 픽셀은 프리멀티플라이 RGBA

/// 픽셀 여럿 (r, g, b, a: 곧은 값) → 프리멀티플라이 바이트
Uint8List px(List<(int, int, int, int)> pixels) => Uint8List.fromList([
      for (final (r, g, b, a) in pixels) ...[r * a ~/ 255, g * a ~/ 255, b * a ~/ 255, a],
    ]);

/// 프리멀티플라이 바이트의 [i]번 픽셀을 곧은 값으로 (반올림)
(int, int, int, int) straight(Uint8List p, int i) {
  final a = p[i * 4 + 3];
  if (a == 0) return (0, 0, 0, 0);
  int s(int v) => (v * 255 / a).round();
  return (s(p[i * 4]), s(p[i * 4 + 1]), s(p[i * 4 + 2]), a);
}

const _clear = (0, 0, 0, 0);
const _terracotta = 0xFFC9775A;

void main() {
  group('저장 꼴 BoatsOwned.colors (recolorRule.save)', () {
    test('고른 구역만 {kind swatch,i}|{kind custom,hex}, 하나도 없으면 null (원래 색)', () {
      final c = BoatColors.none
          .withZone(BoatZone.upper, const CustomBodyColor('#C9775A'))
          .withZone(BoatZone.hull, const SwatchBodyColor(3));
      expect(c.encode(), '{"hull":{"kind":"swatch","i":3},"upper":{"kind":"custom","hex":"#C9775A"}}');
      expect(BoatColors.decode(c.encode()), c);
      expect(BoatColors.none.encode(), isNull);
      expect(c.withZone(BoatZone.hull, null).withZone(BoatZone.upper, null).encode(), isNull);
    });

    test('null·빈 글은 원래 색, 모르는 구역 키는 건너뛰고, 꼴이 틀리면 FormatException', () {
      expect(BoatColors.decode(null), BoatColors.none);
      expect(BoatColors.decode(''), BoatColors.none);
      expect(BoatColors.decode('{"sail":{"kind":"swatch","i":1},"accent":{"kind":"swatch","i":2}}'),
          const BoatColors({BoatZone.accent: SwatchBodyColor(2)}));
      expect(() => BoatColors.decode('[1]'), throwsFormatException);
      expect(() => BoatColors.decode('{"hull":{"kind":"paint"}}'), throwsFormatException);
    });
  });

  group('boats.json v4', () {
    test('상점 배 6척만 색 자료: premium 3 materialIds(판마다 fixed·구역 shading), theme 3 meanLuminance(대표색)', () {
      final colorable = [for (final b in boatCatalog.boats) if (b.recolor != null) b.id];
      expect(colorable, ['boat_cruise', 'boat_speed', 'boat_pirate', 'boat_canopy', 'boat_atelier', 'boat_starlight']);
      for (final b in boatCatalog.boats) {
        expect(b.recolor != null, b.kind == BoatUnlockKind.shop, reason: b.id);
      }
      final canopy = boatCatalog.byId('boat_canopy')!.recolor!;
      expect(canopy.method, RecolorMethod.materialIds);
      expect(canopy.zones, BoatZone.values);
      expect(canopy.dir, 'recolor/premium_01/');
      expect(canopy.neutralMidpoint, 192);
      expect(canopy.fixed[BoatSide.rear], 'rear_fixed.png');
      expect(canopy.shading[BoatSide.front]![BoatZone.accent], 'front_accent_shading.png');
      expect(canopy.review, contains('미술 승인 전 검토본'));
      final cruise = boatCatalog.byId('boat_cruise')!.recolor!;
      expect(cruise.method, RecolorMethod.meanLuminance);
      expect(cruise.defaults[BoatZone.hull], 0xFF688D83);
      // theme 판은 파일 이름이 아직 없어 가안 폴더·이름
      expect(cruise.dir, 'recolor/theme_01/');
      expect(cruise.neutralFiles(BoatSide.rear), ['rear_neutral.png', 'neutral.png']);
      expect(cruise.maskFiles(BoatSide.front, BoatZone.upper), ['front_upper_mask.png', 'upper_mask.png']);
    });

    test('규칙: 구역 이름 선체·지붕·좌석·장식 천, 무료', () {
      final rule = boatCatalog.recolorRule!;
      expect(rule.zoneNames, {BoatZone.hull: '선체', BoatZone.upper: '지붕·좌석', BoatZone.accent: '장식 천'});
      expect(rule.price, 0);
    });

    test('artOf: 색 자료가 있는 배만 고른 색을 싣고, 열쇠가 색마다 다르다', () {
      final cruise = boatCatalog.byId('boat_cruise')!;
      const colors = BoatColors({BoatZone.hull: SwatchBodyColor(9)});
      final plain = boatCatalog.artOf(cruise);
      final painted = boatCatalog.artOf(cruise, colors: colors, argb: {BoatZone.hull: _terracotta});
      expect(plain.recolor, isNull);
      expect(plain.key, 'boat_cruise');
      expect(painted.recolor, isNotNull);
      expect(painted.recolorDir, 'assets/boats/v01fix/recolor/theme_01/');
      expect(painted.colors, {BoatZone.hull: _terracotta});
      expect(painted.key, isNot(plain.key));
      expect(boatCatalog.artOf(cruise, colors: colors, argb: {BoatZone.hull: 0xFF7F8DB3}).key,
          isNot(painted.key));
      // 보상 배는 색을 버린다
      final raft = boatCatalog.artOf(boatCatalog.byId('boat_raft')!, colors: colors, argb: {BoatZone.hull: _terracotta});
      expect((raft.recolor, raft.colors, raft.key), (null, const <BoatZone, int>{}, 'boat_raft'));
    });
  });

  group('premium: shading 층 (materialIds, rgb = min(255, 색 × 회색 ÷ 192), 알파 그대로)', () {
    Uint8List run({
      required Uint8List clean,
      Uint8List? fixed,
      required Map<BoatZone, Uint8List> shading,
      Map<BoatZone, int> colors = const {},
    }) =>
        recolorByShading(
          clean: clean,
          fixed: fixed ?? px([for (var i = 0; i < clean.length ~/ 4; i++) _clear]),
          shading: shading,
          colors: colors,
          midpoint: 192,
        );

    test('회색 192는 고른 색 그대로, 더 밝으면 밝게(255에서 자름), 어두우면 어둡게', () {
      final out = run(
        clean: px([(10, 10, 10, 255), (10, 10, 10, 255), (10, 10, 10, 255)]),
        shading: {BoatZone.hull: px([(192, 192, 192, 255), (255, 255, 255, 255), (96, 96, 96, 255)])},
        colors: {BoatZone.hull: _terracotta},
      );
      expect(straight(out, 0), (0xC9, 0x77, 0x5A, 255));
      // 201 × 255 ÷ 192 = 267 → 255, 119 × 255 ÷ 192 = 158, 90 × 255 ÷ 192 = 120
      expect(straight(out, 1), (255, 158, 120, 255));
      expect(straight(out, 2), (101, 60, 45, 255));
    });

    test('알파는 shading 그대로 (가장자리 반투명도 색만 바뀐다)', () {
      final out = run(
        clean: px([(10, 10, 10, 128)]),
        shading: {BoatZone.hull: px([(192, 192, 192, 128)])},
        colors: {BoatZone.hull: _terracotta},
      );
      final (r, g, b, a) = straight(out, 0);
      expect(a, 128);
      expect((r - 0xC9).abs() <= 2 && (g - 0x77).abs() <= 2 && (b - 0x5A).abs() <= 2, isTrue,
          reason: '$r $g $b');
    });

    test('고르지 않은 구역은 그 자리 원래 그림 색 (평균색을 쓰지 않는다), 고정 층은 맨 위', () {
      final out = run(
        clean: px([(50, 100, 150, 255), (50, 100, 150, 255), (1, 2, 3, 255)]),
        fixed: px([_clear, _clear, (20, 20, 20, 255)]),
        shading: {
          BoatZone.hull: px([(192, 192, 192, 255), _clear, (192, 192, 192, 255)]),
          BoatZone.upper: px([_clear, (192, 192, 192, 255), _clear]),
        },
        colors: {BoatZone.hull: _terracotta},
      );
      expect(straight(out, 0), (0xC9, 0x77, 0x5A, 255));
      expect(straight(out, 1), (50, 100, 150, 255));
      expect(straight(out, 2), (20, 20, 20, 255));
    });

    test('구역이 겹치면 차례(선체 → 지붕 → 장식)대로 위에 얹는다', () {
      final out = run(
        clean: px([(0, 0, 0, 255)]),
        shading: {
          BoatZone.hull: px([(192, 192, 192, 255)]),
          BoatZone.accent: px([(192, 192, 192, 255)]),
        },
        colors: {BoatZone.hull: 0xFF0000FF, BoatZone.accent: 0xFFFF0000},
      );
      expect(straight(out, 0), (255, 0, 0, 255));
    });

    test('층 크기가 다르면 멈춘다', () {
      expect(
          () => run(clean: px([_clear]), shading: {BoatZone.hull: px([_clear, _clear])}),
          throwsArgumentError);
    });
  });

  group('theme: 중립 그림 (meanLuminance, rgb = clamp(중립 × 고른 색 ÷ 구역 평균 밝기))', () {
    test('구역 평균 밝기는 마스크 안 중립 밝기의 평균 (마스크 세기로 무게, 마스크 밖·투명은 뺀다)', () {
      final neutral = px([(100, 100, 100, 255), (150, 150, 150, 255), (250, 250, 250, 255), (90, 90, 90, 0)]);
      final mask = px([(255, 255, 255, 255), (255, 255, 255, 255), _clear, (255, 255, 255, 255)]);
      expect(zoneMeanLuminance(neutral, mask), closeTo(125, 1));
      expect(zoneMeanLuminance(neutral, px([_clear, _clear, _clear, _clear])), isNull);
    });

    test('평균 밝기 픽셀은 고른 색 그대로, 밝은 곳은 밝게(255에서 자름), 마스크 밖·고르지 않은 구역은 원래 그림', () {
      final clean = px([(1, 2, 3, 255), (4, 5, 6, 255), (7, 8, 9, 255), (10, 11, 12, 255)]);
      final neutral = px([(125, 125, 125, 255), (250, 250, 250, 255), (125, 125, 125, 255), (125, 125, 125, 255)]);
      final hull = px([(255, 255, 255, 255), (255, 255, 255, 255), _clear, (128, 128, 128, 255)]);
      final upper = px([_clear, _clear, (255, 255, 255, 255), _clear]);
      final out = recolorByNeutral(
        clean: clean,
        neutral: neutral,
        masks: {BoatZone.hull: hull, BoatZone.upper: upper},
        colors: {BoatZone.hull: 0xFFFA7D00},
        means: {BoatZone.hull: 125, BoatZone.upper: 125},
      );
      expect(straight(out, 0), (250, 125, 0, 255));
      expect(straight(out, 1), (255, 250, 0, 255));
      // 지붕은 고르지 않음
      expect(straight(out, 2), (7, 8, 9, 255));
      // 반 마스크는 반만 섞는다
      final (r, g, _, _) = straight(out, 3);
      expect((r - 130).abs() <= 2 && (g - 68).abs() <= 2, isTrue, reason: '$r $g');
    });

    test('불투명 흑백 마스크도 밝기로 읽는다', () {
      final out = recolorByNeutral(
        clean: px([(0, 0, 0, 255)]),
        neutral: px([(125, 125, 125, 255)]),
        masks: {BoatZone.accent: px([(255, 255, 255, 255)])},
        colors: {BoatZone.accent: 0xFF7F8DB3},
        means: {BoatZone.accent: 125},
      );
      expect(straight(out, 0), (0x7F, 0x8D, 0xB3, 255));
    });
  });

  test('마스크는 보간하지 않는다: 가장 가까운 픽셀로만 늘이고 줄인다', () {
    final src = px([(255, 255, 255, 255), _clear]);
    final up = resampleNearest(src, 2, 1, 5, 2);
    final values = {for (var i = 0; i < up.length; i += 4) up[i + 3]};
    expect(values, {0, 255});
    // 픽셀 가운데로 고른다 (5칸 중 가운데는 원본 경계 위라 오른쪽 픽셀)
    expect([for (var x = 0; x < 5; x++) up[x * 4 + 3]], [255, 255, 0, 0, 0]);
    final down = resampleNearest(px([for (var i = 0; i < 8; i++) i.isEven ? (255, 255, 255, 255) : _clear]), 8, 1, 3, 1);
    expect({for (var i = 0; i < down.length; i += 4) down[i + 3]}.every((a) => a == 0 || a == 255), isTrue);
  });

  test('고른 색 → 구역 ARGB (견본 번호·직접 고른 색, palette body와 같은 계산)', () {
    const colors = BoatColors({BoatZone.hull: SwatchBodyColor(9), BoatZone.accent: CustomBodyColor('#102030')});
    final argb = boatZoneArgb(colors, spiritPalette.body.argbOf);
    expect(argb, {BoatZone.hull: 0xFFC9775A, BoatZone.accent: 0xFF102030});
  });
}
