import 'dart:math' as math;

// 연출 5개 (T19, 16장 11/20 Q008·창구 Q015, config ui.motion, 디자인기획/연출5_개발인계.md 가안).
// 새 그림 없이 코드 움직임만이다. 시간은 초, 거리는 pt. 아는 문자열 값만 받고 모르는 값이면 FormatException.
// ① 도착 핀·카드 그림 칸 찍힘, ② 쉼터 정령 쓰다듬기·꾸밈 물품 흔들림, ③ 수레 새 칸·산 물건 빠짐 + SOLD,
// ④ 물감 방울 줍기 럭 숫자, ⑤ 화집 종이 넘김

/// 움직임 줄이기(기기 설정)가 켜지면: 끝 상태만 보인다 (config ui.motion.reducedMotion)
const motionReducedEndStateOnly = 'endStateOnly';

/// 연출이 끝나기 전에 다시 시작되면: 지금 연출을 끝 상태로 건너뛰고 처음부터 (config ui.motion.repeat)
const motionRepeatSkipToEnd = 'skipToEndThenRestart';

class MotionRules {
  const MotionRules({
    this.arrivalPin,
    this.albumFlip,
    required this.restPet,
    required this.decorWiggle,
    required this.cartSlot,
    required this.dropPickup,
  });

  /// config에 ui.motion이 없을 때: 모든 연출 없음 (끝 상태만)
  static const none = MotionRules(
    restPet: null,
    decorWiggle: null,
    cartSlot: null,
    dropPickup: null,
  );

  /// [j]는 config.json 전체. ui.motion이 없으면 [none]
  factory MotionRules.fromJson(Map<String, dynamic> j) {
    final m = (j['ui'] as Map<String, dynamic>?)?['motion'] as Map<String, dynamic>?;
    if (m == null) return none;
    _known(m, 'reducedMotion', {motionReducedEndStateOnly});
    _known(m, 'repeat', {motionRepeatSkipToEnd});
    if (m['sound'] != false || m['haptic'] != false) {
      throw const FormatException('ui.motion: 소리·진동은 없다 (sound·haptic false)');
    }
    Map<String, dynamic>? part(String key, String screen) {
      final p = m[key] as Map<String, dynamic>?;
      if (p != null && p['screen'] != screen) {
        throw FormatException('ui.motion.$key.screen은 $screen: ${p['screen']}');
      }
      return p;
    }

    return MotionRules(
      arrivalPin: switch (part('arrivalPin', 'map')) { final p? => ArrivalPinMotion.fromJson(p), _ => null },
      albumFlip: switch (part('albumFlip', 'album')) { final p? => AlbumFlipMotion.fromJson(p), _ => null },
      restPet: switch (part('restPet', 'rest')) { final p? => RestPetMotion.fromJson(p), _ => null },
      decorWiggle: switch (part('decorWiggle', 'rest')) { final p? => DecorWiggleMotion.fromJson(p), _ => null },
      cartSlot: switch (part('cartSlot', 'shop')) { final p? => CartSlotMotion.fromJson(p), _ => null },
      dropPickup: switch (part('dropPickup', 'walking')) { final p? => DropPickupMotion.fromJson(p), _ => null },
    );
  }

  /// ① 도착 뒤 지도: 핀 떨어짐 + 카드 그림 칸 찍힘. null이면 끝 상태만
  final ArrivalPinMotion? arrivalPin;

  /// ⑤ 화집 종이 넘김. null이면 넘김 없이 바로 바뀜
  final AlbumFlipMotion? albumFlip;

  /// ② 쉼터 정령 쓰다듬기. null이면 문질러도 반응 없음
  final RestPetMotion? restPet;

  /// ② 꾸밈 물품 누르면 흔들림. null이면 흔들지 않음
  final DecorWiggleMotion? decorWiggle;

  /// ③ 수레 새 칸 열림·산 물건 빠짐 + SOLD 도장. null이면 끝 상태만
  final CartSlotMotion? cartSlot;

  /// ④ 물감 방울 줍기 럭 숫자 오름. null이면 숫자만 바로
  final DropPickupMotion? dropPickup;
}

/// ② 쉼터 정령 쓰다듬기 (config ui.motion.restPet, 정령 계약 4장): [rubFlipsWithinSec]초 안에 좌우 방향이
/// [rubFlips]번 바뀌면 쓰다듬기. 표정 [expr]을 [exprSec]초(Rive 입력 없음, expr만) + 문지르는 쪽으로 [tiltDeg]도
/// 기울였다 [returnSec]초에 되돌림. 짧게 누르기 반응(머리·배·연타)은 그대로다 (tapRules unchanged)
class RestPetMotion {
  const RestPetMotion({
    required this.rubFlipsWithinSec,
    required this.rubFlips,
    required this.expr,
    required this.exprSec,
    required this.tiltDeg,
    required this.returnSec,
  });

  factory RestPetMotion.fromJson(Map<String, dynamic> j) {
    _known(j, 'tapRules', {'unchanged'});
    final flips = j['rubFlips'] as int;
    if (flips < 1) throw const FormatException('ui.motion.restPet.rubFlips는 1 이상');
    return RestPetMotion(
      rubFlipsWithinSec: _pos(j, 'rubFlipsWithinSec'),
      rubFlips: flips,
      expr: j['expr'] as String,
      exprSec: _pos(j, 'exprSec'),
      tiltDeg: _d(j['tiltDeg']),
      returnSec: _pos(j, 'returnSec'),
    );
  }

  final double rubFlipsWithinSec;
  final int rubFlips;

  /// palette.json customPartsV33 expressions id (happy …)
  final String expr;
  final double exprSec;
  final double tiltDeg;
  final double returnSec;

  /// 쓰다듬은 뒤 [sec]초의 기울기(도). [side]는 문지르는 쪽(+1 오른쪽, −1 왼쪽). 바로 [tiltDeg]만큼 기울고
  /// [returnSec] 동안 천천히 0으로 (끝에서 느려진다)
  double tiltAt(double sec, int side) {
    if (sec >= returnSec) return 0;
    final u = (sec / returnSec).clamp(0.0, 1.0);
    final ease = 1 - math.pow(1 - u, 3);
    return side.sign * tiltDeg * (1 - ease);
  }
}

/// 좌우로 문지르기 세기. 손가락이 [jitterPt]보다 많이 되돌아가야 방향이 바뀐 것으로 본다 (떨림은 안 셈).
/// [move]가 쓰다듬기를 알리면 센 것을 비우고 다시 센다 (계속 문지르면 다시 쓰다듬기)
class RubCounter {
  RubCounter(this.rules, {this.jitterPt = 4});

  final RestPetMotion rules;
  final double jitterPt;

  /// 지금 문지르는 쪽 (0 = 아직 모름)
  int _dir = 0;

  /// [_dir]과 반대로 움직인 거리 (떨림 거르기)
  double _back = 0;

  /// 처음 쪽을 정하기 전까지 움직인 거리
  double _first = 0;
  final _flips = <double>[];

  /// 지금 문지르는 쪽 (+1 오른쪽, −1 왼쪽, 0 모름)
  int get side => _dir;

  /// 가로로 [dx]pt 움직였다 (시각 [sec]초). 쓰다듬기가 되면 그때 문지르는 쪽, 아니면 null
  int? move(double dx, double sec) {
    if (dx == 0) return null;
    final d = dx > 0 ? 1 : -1;
    if (_dir == 0) {
      _first += dx;
      if (_first.abs() > jitterPt) _dir = _first > 0 ? 1 : -1;
      return null;
    }
    if (d == _dir) {
      _back = 0;
      return null;
    }
    _back += dx.abs();
    if (_back <= jitterPt) return null;
    _dir = d;
    _back = 0;
    _flips
      ..add(sec)
      ..removeWhere((t) => sec - t > rules.rubFlipsWithinSec + 1e-9);
    if (_flips.length < rules.rubFlips) return null;
    _flips.clear();
    return _dir;
  }

  /// 손가락을 뗐다
  void reset() {
    _dir = 0;
    _back = 0;
    _first = 0;
    _flips.clear();
  }
}

/// ② 꾸밈 물품 누르면 흔들림 (config ui.motion.decorWiggle): 발(땅에 닿는 자리, groundAt)을 축으로
/// [degs] 차례로 좌우를 번갈아(첫 값은 오른쪽으로 기움) [sec]초. 꾸미기 중에는 흔들지 않는다 ([offInEditMode])
class DecorWiggleMotion {
  const DecorWiggleMotion({required this.degs, required this.sec, required this.offInEditMode});

  factory DecorWiggleMotion.fromJson(Map<String, dynamic> j) {
    _known(j, 'pivot', {'groundAt'});
    final degs = [for (final d in j['degs'] as List) _d(d)];
    if (degs.isEmpty) throw const FormatException('ui.motion.decorWiggle.degs가 비었다');
    return DecorWiggleMotion(
      degs: List.unmodifiable(degs),
      sec: _pos(j, 'sec'),
      offInEditMode: j['offInEditMode'] as bool,
    );
  }

  /// 흔들 때 차례로 닿는 각도의 크기 (도, 6·3·0): 0에서 시작해 +6 → −3 → +0
  final List<double> degs;
  final double sec;
  final bool offInEditMode;

  /// 흔든 뒤 [t]초의 기울기(도). 0 → +degs[0] → −degs[1] → … 칸마다 같은 시간, 칸 안은 부드럽게(사인)
  double angleAt(double t) {
    if (t <= 0 || t >= sec) return 0;
    final keys = [0.0, for (final (i, d) in degs.indexed) i.isEven ? d : -d];
    final pos = t / sec * (keys.length - 1);
    final i = pos.floor().clamp(0, keys.length - 2);
    final u = pos - i;
    final s = 0.5 - 0.5 * math.cos(math.pi * u);
    return keys[i] + (keys[i + 1] - keys[i]) * s;
  }
}

/// ③ 수레 칸 (config ui.motion.cartSlot, 캔버스 8-1 메모): 새 칸이 열리면 자물쇠가 [newSlotLockFadeSec]초에 흐려지고
/// 이어 물건이 [dropPt]pt 위에서 [scaleFrom]배로 [dropSec]초 동안 선반에 톡 떨어진다 (한 번 열릴 때 한 번,
/// [oncePerUnlock]). 산 물건은 [boughtRisePt]pt 떠오르며 [boughtFadeSec]초에 사라지고, 이어 SOLD 도장이
/// [soldStampScaleFrom]배에서 [soldStampSec]초에 1배로 찍힌다
class CartSlotMotion {
  const CartSlotMotion({
    required this.newSlotLockFadeSec,
    required this.dropPt,
    required this.dropSec,
    required this.scaleFrom,
    required this.oncePerUnlock,
    required this.boughtRisePt,
    required this.boughtFadeSec,
    required this.soldStampScaleFrom,
    required this.soldStampSec,
  });

  factory CartSlotMotion.fromJson(Map<String, dynamic> j) {
    // 열린 칸마다 한 번만 안다 (상점을 본 시각 기준, 여는 때마다 돌리는 값은 아직 없음)
    if (j['oncePerUnlock'] != true) throw const FormatException('ui.motion.cartSlot.oncePerUnlock은 true만 안다');
    return CartSlotMotion(
      newSlotLockFadeSec: _pos(j, 'newSlotLockFadeSec'),
      dropPt: _d(j['dropPt']),
      dropSec: _pos(j, 'dropSec'),
      scaleFrom: _pos(j, 'scaleFrom'),
      oncePerUnlock: j['oncePerUnlock'] as bool,
      boughtRisePt: _d(j['boughtRisePt']),
      boughtFadeSec: _pos(j, 'boughtFadeSec'),
      soldStampScaleFrom: _pos(j, 'soldStampScaleFrom'),
      soldStampSec: _pos(j, 'soldStampSec'),
    );
  }

  final double newSlotLockFadeSec;
  final double dropPt;
  final double dropSec;
  final double scaleFrom;
  final bool oncePerUnlock;
  final double boughtRisePt;
  final double boughtFadeSec;
  final double soldStampScaleFrom;
  final double soldStampSec;

  /// 새 칸 열림 전체 길이(초): 자물쇠 흐려짐 뒤 물건 떨어짐
  double get unlockSec => newSlotLockFadeSec + dropSec;

  /// 산 물건 빠짐 + 도장 전체 길이(초)
  double get soldSec => boughtFadeSec + soldStampSec;

  /// 새 칸이 열린 뒤 [t]초의 모습
  CartUnlockFrame unlockAt(double t) {
    if (t >= unlockSec) return CartUnlockFrame.end;
    if (t < newSlotLockFadeSec) {
      return CartUnlockFrame(lockOpacity: 1 - t / newSlotLockFadeSec, itemShown: false, itemDy: -dropPt, itemScale: scaleFrom);
    }
    final u = ((t - newSlotLockFadeSec) / dropSec).clamp(0.0, 1.0);
    // 떨어질수록 빨라진다 (easeIn)
    final fall = u * u;
    return CartUnlockFrame(
      lockOpacity: 0,
      itemShown: true,
      itemDy: -dropPt * (1 - fall),
      itemScale: scaleFrom + (1 - scaleFrom) * u,
    );
  }

  /// 칸이 팔린 뒤 [t]초의 모습
  CartSoldFrame soldAt(double t) {
    if (t >= soldSec) return CartSoldFrame.end;
    if (t < boughtFadeSec) {
      final u = t / boughtFadeSec;
      // 떠오르며 빨리 출발해 천천히 멈춘다 (easeOut)
      final rise = 1 - (1 - u) * (1 - u);
      return CartSoldFrame(itemDy: -boughtRisePt * rise, itemOpacity: 1 - u, stampShown: false, stampScale: soldStampScaleFrom);
    }
    final u = ((t - boughtFadeSec) / soldStampSec).clamp(0.0, 1.0);
    return CartSoldFrame(
      itemDy: -boughtRisePt,
      itemOpacity: 0,
      stampShown: true,
      stampScale: soldStampScaleFrom + (1 - soldStampScaleFrom) * u,
    );
  }
}

/// 새 칸 열림의 한 순간: 자물쇠 투명도, 물건이 보이는지·떨어지는 높이(pt, 위가 −)·크기
class CartUnlockFrame {
  const CartUnlockFrame({required this.lockOpacity, required this.itemShown, required this.itemDy, required this.itemScale});

  static const end = CartUnlockFrame(lockOpacity: 0, itemShown: true, itemDy: 0, itemScale: 1);

  final double lockOpacity;
  final bool itemShown;
  final double itemDy;
  final double itemScale;
}

/// 산 물건 빠짐의 한 순간: 물건 높이(pt, 위가 −)·투명도, 도장이 보이는지·크기
class CartSoldFrame {
  const CartSoldFrame({required this.itemDy, required this.itemOpacity, required this.stampShown, required this.stampScale});

  static const end = CartSoldFrame(itemDy: 0, itemOpacity: 0, stampShown: true, stampScale: 1);

  final double itemDy;
  final double itemOpacity;
  final bool stampShown;
  final double stampScale;
}

/// ④ 물감 방울 줍기 (config ui.motion.dropPickup, 캔버스 3-1 메모): 주운 럭 숫자가 [luxCountSec]초 동안 [luxStep]씩
/// 올라가며 [luxBounceScale]배로 튄다. 통 아이콘은 [tubeDelaySec]초 늦게. 떠오르는 ‘+n 럭’의 길(떠오름·흐려짐)은
/// 그대로 (plusOne unchanged)
class DropPickupMotion {
  const DropPickupMotion({
    required this.luxCountSec,
    required this.luxStep,
    required this.luxBounceScale,
    required this.tubeDelaySec,
  });

  factory DropPickupMotion.fromJson(Map<String, dynamic> j) {
    _known(j, 'plusOne', {'unchanged'});
    final step = j['luxStep'] as int;
    if (step < 1) throw const FormatException('ui.motion.dropPickup.luxStep은 1 이상');
    return DropPickupMotion(
      luxCountSec: _pos(j, 'luxCountSec'),
      luxStep: step,
      luxBounceScale: _pos(j, 'luxBounceScale'),
      tubeDelaySec: _d(j['tubeDelaySec']),
    );
  }

  final double luxCountSec;
  final int luxStep;
  final double luxBounceScale;
  final double tubeDelaySec;

  /// [from]에서 [to]로 오르기 시작한 뒤 [t]초에 보이는 숫자: [luxStep]씩 고르게, [luxCountSec]에 [to]
  int countAt(int from, int to, double t) {
    if (t >= luxCountSec || to <= from) return to;
    if (t <= 0) return from;
    final steps = ((to - from) / luxStep).ceil();
    final k = (steps * t / luxCountSec).floor();
    return math.min(to, from + k * luxStep);
  }

  /// 오르기 시작한 뒤 [t]초의 숫자 크기: 1 → [luxBounceScale] → 1 (가운데에서 가장 큼)
  double scaleAt(double t) {
    if (t <= 0 || t >= luxCountSec) return 1;
    return 1 + (luxBounceScale - 1) * math.sin(math.pi * t / luxCountSec);
  }
}

/// ① 도착 핀 (config ui.motion.arrivalPin, 캔버스 4-1 메모): 도착한 명소의 압정 핀이 [dropPt]pt 위에서
/// [dropSec]초 동안 떨어져(easeIn, 떨어질수록 빠르게) 꽂히고 [bounceSec]초 동안 1 → [bounceScale] → 1배로 튄다.
/// [stampDelaySec]초 뒤 지도 카드의 그림 칸이 [stampScaleFrom]배에서 [stampSec]초에 1배로 찍힌다 (칸 색 = 액자 등급,
/// stampColor frameTier)
class ArrivalPinMotion {
  const ArrivalPinMotion({
    required this.dropPt,
    required this.dropSec,
    required this.bounceScale,
    required this.bounceSec,
    required this.stampDelaySec,
    required this.stampScaleFrom,
    required this.stampSec,
  });

  factory ArrivalPinMotion.fromJson(Map<String, dynamic> j) {
    _known(j, 'ease', {'easeIn'});
    _known(j, 'stampColor', {'frameTier'});
    return ArrivalPinMotion(
      dropPt: _d(j['dropPt']),
      dropSec: _pos(j, 'dropSec'),
      bounceScale: _pos(j, 'bounceScale'),
      bounceSec: _pos(j, 'bounceSec'),
      stampDelaySec: _d(j['stampDelaySec']),
      stampScaleFrom: _pos(j, 'stampScaleFrom'),
      stampSec: _pos(j, 'stampSec'),
    );
  }

  final double dropPt;
  final double dropSec;
  final double bounceScale;
  final double bounceSec;
  final double stampDelaySec;
  final double stampScaleFrom;
  final double stampSec;

  /// 핀이 떨어져 튀기까지(초)
  double get pinSec => dropSec + bounceSec;

  /// 그림 칸이 찍히기 시작하는 때(초)
  double get stampStartSec => pinSec + stampDelaySec;

  /// 전체 길이(초)
  double get totalSec => stampStartSec + stampSec;

  /// 시작한 뒤 [t]초의 모습
  ArrivalPinFrame at(double t) {
    if (t >= totalSec) return ArrivalPinFrame.end;
    var lift = 0.0;
    var scale = 1.0;
    if (t < dropSec) {
      final u = math.max(0.0, t) / dropSec;
      lift = dropPt * (1 - u * u);
    } else if (t < pinSec) {
      scale = 1 + (bounceScale - 1) * math.sin(math.pi * (t - dropSec) / bounceSec);
    }
    final shown = t >= stampStartSec;
    final w = shown ? ((t - stampStartSec) / stampSec).clamp(0.0, 1.0) : 0.0;
    return ArrivalPinFrame(
      pinLiftPt: lift,
      pinScale: scale,
      stampShown: shown,
      stampScale: stampScaleFrom + (1 - stampScaleFrom) * w,
    );
  }
}

/// 도착 핀의 한 순간: 핀이 뜬 높이(pt, 위로)·크기(바늘 끝 기준), 그림 칸이 찍혔는지·크기
class ArrivalPinFrame {
  const ArrivalPinFrame({required this.pinLiftPt, required this.pinScale, required this.stampShown, required this.stampScale});

  static const end = ArrivalPinFrame(pinLiftPt: 0, pinScale: 1, stampShown: true, stampScale: 1);

  final double pinLiftPt;
  final double pinScale;
  final bool stampShown;
  final double stampScale;
}

/// ⑤ 화집 종이 넘김이 도는 때 (config ui.motion.albumFlip.on)
enum AlbumFlipOn {
  /// 그림 탭의 일기·전체 바꾸기
  diaryAllToggle,

  /// 일기에서 달 머리줄이 화면에 들어올 때 (달을 넘길 때)
  monthHeader,
}

/// ⑤ 화집 종이 넘김 (config ui.motion.albumFlip, 캔버스 6-1 메모): 오른쪽 끝을 축으로 가로 크기 1 → 0 → 1을
/// [sec]초(3D 말림 없음), 가운데 [shadowSec]초 동안 잉크 그림자 [shadowInk]. 그림 크게 보기에는 쓰지 않는다
class AlbumFlipMotion {
  const AlbumFlipMotion({required this.on, required this.sec, required this.shadowInk, required this.shadowSec});

  factory AlbumFlipMotion.fromJson(Map<String, dynamic> j) {
    _known(j, 'axis', {'rightEdge'});
    final scaleX = [for (final v in j['scaleX'] as List) _d(v)];
    if (scaleX.length != 3 || scaleX[0] != 1 || scaleX[1] != 0 || scaleX[2] != 1) {
      throw FormatException('ui.motion.albumFlip.scaleX는 [1, 0, 1]만 안다: $scaleX');
    }
    if (j['curl3d'] != false) throw const FormatException('ui.motion.albumFlip.curl3d는 false만 안다');
    if (j['notInBigView'] != true) throw const FormatException('ui.motion.albumFlip.notInBigView는 true만 안다');
    final on = {
      for (final v in j['on'] as List)
        AlbumFlipOn.values.firstWhere((o) => o.name == v, orElse: () => throw FormatException('ui.motion.albumFlip.on: 모르는 값 $v')),
    };
    final shadowInk = _d(j['shadowInk']);
    if (shadowInk < 0 || shadowInk > 1) throw FormatException('ui.motion.albumFlip.shadowInk는 0~1: $shadowInk');
    final sec = _pos(j, 'sec');
    final shadowSec = _d(j['shadowSec']);
    if (shadowSec < 0 || shadowSec > sec) throw FormatException('ui.motion.albumFlip.shadowSec는 0~sec: $shadowSec');
    return AlbumFlipMotion(on: on, sec: sec, shadowInk: shadowInk, shadowSec: shadowSec);
  }

  final Set<AlbumFlipOn> on;
  final double sec;
  final double shadowInk;
  final double shadowSec;

  /// 앞 종이가 접혀 뒷 종이로 바뀌는 때(초): 가로 크기가 0인 가운데
  double get swapSec => sec / 2;

  /// 시작한 뒤 [t]초의 가로 크기: 1 → 0 → 1. 종이가 축을 따라 고르게 돌 때 보이는 폭(|cos|)이다
  double scaleXAt(double t) {
    if (t <= 0 || t >= sec) return 1;
    return math.cos(math.pi * t / sec).abs();
  }

  /// 시작한 뒤 [t]초의 잉크 그림자 진하기: 가운데 [shadowSec]초 동안 0 → [shadowInk] → 0
  double shadowAt(double t) {
    if (shadowSec <= 0) return 0;
    final d = (t - swapSec).abs();
    if (d >= shadowSec / 2) return 0;
    return shadowInk * (1 - 2 * d / shadowSec);
  }
}

/// 초를 Duration으로
Duration motionDuration(double sec) => Duration(microseconds: (sec * Duration.microsecondsPerSecond).round());

void _known(Map<String, dynamic> j, String key, Set<String> known) {
  final v = j[key];
  if (!known.contains(v)) throw FormatException('ui.motion $key: 모르는 값 $v');
}

double _pos(Map<String, dynamic> j, String key) {
  final v = _d(j[key]);
  if (v <= 0) throw FormatException('ui.motion $key는 0보다 커야 한다: $v');
  return v;
}

double _d(dynamic v) => (v as num).toDouble();
