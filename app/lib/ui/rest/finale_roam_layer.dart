import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:flutter/material.dart';

import '../../domain/companion.dart';
import '../../domain/decor_place.dart';
import '../../domain/decor_rules.dart';
import '../../domain/finale_roam.dart';
import '../../domain/rest_camera.dart';
import '../common/palette.dart';
import '../companion/companion_art.dart';
import '../scene/scene_view.dart' show SceneTinted;
import 'decor_layer.dart';
import 'decor_wiggle.dart';

// 쉼터를 돌아다니는 완결 동행 (16장 11/18 ④·11/19 ②, config companions.finaleRoam, M2~M6 AB 보충).
// 그림은 동행 자리표시 그림(CompanionFigure)이다. 동행 Rive 걷기·앉기(T2c)가 오면 걷기·서기·앉기를 그 클립으로 바꾼다.
// 앉기는 그때까지 아래를 기준으로 키를 줄여 보인다 (자리표시)

/// 앉은 자리표시: 키를 이만큼으로 (그림이 오면 없앤다)
const _sitScale = 0.82;

/// 걷는 동안 위아래로 흔들리는 높이 (키에 대한 비율, 걷기 탭 동행과 같은 값) 와 한 번 흔들리는 시간
const _bobToHeight = 12 / 180;
const _bobSec = 0.9;

/// 한 번에 이보다 오래 지나면 (앱이 멈췄다 돌아오면) 이만큼만 간 것으로
const _maxStepSec = 0.1;

/// 돌아다니는 동행 한 명 (그림 값)
class RoamingCompanion {
  const RoamingCompanion(this.companion, this.state);

  final Companion companion;
  final RoamState state;

  String get id => companion.id;
}

/// 완결 동행들의 자리·말풍선. 화면이 보일 때만 움직인다 (TickerMode)
class FinaleRoamController extends ChangeNotifier {
  FinaleRoamController({required this.vsync, required this.random});

  final TickerProvider vsync;

  /// 처음 자리·가는 곳·멈춤·앉기·한마디를 고른다
  final math.Random random;
  Ticker? _ticker;
  Duration _last = Duration.zero;

  FinaleRoamer? _roamer;
  FinaleRoamRules? _rules;
  final _companions = <String, Companion>{};
  final _states = <String, RoamState>{};

  /// 지금까지 흐른 시간 (초, 걷기 흔들림)
  double time = 0;

  String? _bubbleId;
  String? _bubbleText;
  double _bubbleLeft = 0;
  final _lastLine = <String, int>{};

  /// 말풍선이 떠 있는 동행과 그 한마디
  ({String id, String text})? get bubble =>
      _bubbleId != null && _bubbleText != null && _bubbleLeft > 0 ? (id: _bubbleId!, text: _bubbleText!) : null;

  List<RoamingCompanion> get companions => [
        for (final e in _companions.entries)
          if (_states[e.key] case final s?) RoamingCompanion(e.value, s),
      ];

  double get w => _roamer?.w ?? 0;
  double get h => _roamer?.h ?? 0;

  /// 화면이 build마다 넣는다 (알리지 않음, 다음 틱부터 그린다). [finale]이 비면 멈춘다
  void configure({
    required FinaleRoamRules? rules,
    required DecorStage? stage,
    required double w,
    required double h,
    required List<Companion> finale,
  }) {
    if (rules == null || stage == null || finale.isEmpty) {
      _companions.clear();
      _states.clear();
      _ticker?.stop();
      return;
    }
    final roamer = _roamer;
    if (roamer == null || roamer.stage != stage || roamer.rules != rules || roamer.w != w || roamer.h != h) {
      _roamer = FinaleRoamer(rules: rules, stage: stage, w: w, h: h, random: random);
    }
    _rules = rules;
    final ids = {for (final c in finale) c.id};
    _companions.removeWhere((id, _) => !ids.contains(id));
    _states.removeWhere((id, _) => !ids.contains(id));
    for (final c in finale) {
      _companions[c.id] = c;
      _states.putIfAbsent(c.id, _roamer!.start);
    }
    _ticker ??= vsync.createTicker(_tick);
    if (!_ticker!.isActive) {
      _last = Duration.zero;
      _ticker!.start();
    }
  }

  void _tick(Duration elapsed) {
    final dt = math.min(_maxStepSec, (elapsed - _last).inMicroseconds / 1e6);
    _last = elapsed;
    final roamer = _roamer;
    if (roamer == null || dt <= 0) return;
    time += dt;
    // 보이는 것이 바뀔 때만 다시 그린다 (걷는 중·자세가 바뀜·말풍선이 사라짐). 서 있거나 앉아 있으면 그대로
    var changed = false;
    for (final id in _states.keys.toList()) {
      final was = _states[id]!;
      final now = roamer.step(was, dt);
      _states[id] = now;
      if (was.pose == RoamPose.walk || now.pose != was.pose) changed = true;
    }
    if (_bubbleLeft > 0) {
      _bubbleLeft -= dt;
      if (_bubbleLeft <= 0) changed = true;
    }
    if (changed) notifyListeners();
  }

  /// [id]를 눌렀다. 말풍선이 떠 있는 동안 한 번 더 누르면 true (동행 화면을 연다), 아니면 한마디를 띄운다
  bool tap(String id) {
    final rules = _rules;
    final c = _companions[id];
    if (rules == null || c == null) return false;
    if (bubble?.id == id && rules.secondTapOpensCompanion) {
      _bubbleLeft = 0;
      notifyListeners();
      return true;
    }
    final i = pickRestLine(c.restLines, _lastLine[id], random, noRepeat: rules.noRepeat);
    if (i == null) {
      // 한마디가 없으면 (데이터 문제) 바로 동행 화면
      return rules.secondTapOpensCompanion;
    }
    _lastLine[id] = i;
    _bubbleId = id;
    _bubbleText = c.restLines[i].text;
    _bubbleLeft = rules.bubbleSec;
    notifyListeners();
    return false;
  }

  @override
  void dispose() {
    _ticker?.dispose();
    super.dispose();
  }
}

/// 장면 층 하나(정령 뒤 또는 앞)에 꾸밈 물품과 완결 동행을 발 y 순서로 (아래가 앞, config orderWithDecor lowerIsFront)
class RestGroundLayer extends StatelessWidget {
  const RestGroundLayer({
    super.key,
    required this.geometry,
    required this.stage,
    required this.front,
    required this.decor,
    required this.roam,
    required this.companionTint,
    this.decorTint,
    this.selected,
    this.hidden,
    this.wiggle,
  });

  final RestGeometry geometry;
  final DecorStage? stage;

  /// 정령 앞 층이면 true (발 y가 정령 발보다 아래인 것만)
  final bool front;

  /// 이 층의 꾸밈 물품 (그리는 순서)
  final List<DecorView> decor;
  final FinaleRoamController roam;
  final int companionTint;
  final List<double>? decorTint;
  final String? selected;
  final String? hidden;

  /// 누른 꾸밈 물품 흔들기 (연출 ②)
  final DecorWiggler? wiggle;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: roam,
      builder: (context, _) {
        final g = geometry;
        final st = stage;
        final walkers = [
          for (final c in roam.companions)
            if (st != null && st.frontOfSpirit(c.state.at) == front) c,
        ];
        // 물품과 동행을 발 y로 섞는다 (같으면 물품이 뒤)
        final entries = <(double, int, Widget)>[
          for (final (i, v) in decor.indexed)
            (v.spot.foot.y, i, decorArtWidgets(g, [v], tint: decorTint, selected: selected, hidden: hidden, wiggle: wiggle).single),
          for (final c in walkers) (c.state.at.y, decor.length + 1, _companion(c)),
        ]..sort((a, b) => a.$1 != b.$1 ? a.$1.compareTo(b.$1) : a.$2.compareTo(b.$2));
        return Stack(clipBehavior: Clip.none, children: [for (final e in entries) e.$3]);
      },
    );
  }

  Widget _companion(RoamingCompanion c) {
    final g = geometry;
    final s = c.state;
    final w = roam.w, h = roam.h;
    final lift = s.pose == RoamPose.walk
        ? h * _bobToHeight * (1 - math.cos(2 * math.pi * roam.time / _bobSec)) / 2
        : 0.0;
    return Positioned(
      key: ValueKey('rest-roam-${c.id}'),
      left: g.sx(s.at.x - w / 2),
      top: g.sy(s.at.y - h - lift),
      width: w * g.k,
      height: h * g.k,
      child: IgnorePointer(
        child: SceneTinted(
          tint: companionTint,
          child: Transform.flip(
            flipX: s.facingLeft,
            child: Transform.scale(
              scaleY: s.pose == RoamPose.sit ? _sitScale : 1,
              alignment: Alignment.bottomCenter,
              child: CompanionFigure(companion: c.companion, height: h * g.k),
            ),
          ),
        ),
      ),
    );
  }
}

/// 완결 동행 누름 상자와 말풍선 (장면 맨 위)
class FinaleRoamHits extends StatelessWidget {
  const FinaleRoamHits({super.key, required this.geometry, required this.roam, required this.onTap});

  final RestGeometry geometry;
  final FinaleRoamController roam;
  final void Function(String id) onTap;

  /// 말풍선 가장 넓은 폭 (pt)
  static const _bubbleMaxWidth = 200.0;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: roam,
      builder: (context, _) {
        final g = geometry;
        final w = roam.w, h = roam.h;
        final bubble = roam.bubble;
        final children = <Widget>[];
        for (final c in roam.companions) {
          final s = c.state;
          children.add(Positioned(
            key: ValueKey('rest-roam-hit-${c.id}'),
            left: g.sx(s.at.x - w / 2),
            top: g.sy(s.at.y - h),
            width: w * g.k,
            height: h * g.k,
            child: Semantics(
              button: true,
              label: c.companion.name,
              excludeSemantics: true,
              child: GestureDetector(
                key: ValueKey('rest-roam-tap-${c.id}'),
                behavior: HitTestBehavior.opaque,
                onTap: () => onTap(c.id),
              ),
            ),
          ));
          if (bubble?.id == c.id) {
            final top = g.sy(s.at.y - h);
            children.add(Positioned(
              key: const ValueKey('rest-roam-bubble'),
              left: g.sx(s.at.x) - _bubbleMaxWidth / 2,
              width: _bubbleMaxWidth,
              bottom: g.height - top + 6,
              child: IgnorePointer(
                child: Center(
                  child: Semantics(
                    liveRegion: true,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: Palette.card,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Palette.ink, width: InkLine.pill),
                        boxShadow: const [BoxShadow(color: Palette.shadow, offset: Offset(0, InkLine.shadow))],
                      ),
                      child: Text(
                        bubble!.text,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 13, height: 1.3, color: Palette.ink),
                      ),
                    ),
                  ),
                ),
              ),
            ));
          }
        }
        return Stack(clipBehavior: Clip.none, children: children);
      },
    );
  }
}
