import 'dart:math' as math;

import 'bucket.dart';
import 'gait.dart';
import 'rules.dart';
import 'walk_record.dart';

class _Gain {
  const _Gain(this.at, this.steps);

  final DateTime at;
  final int steps;
}

/// 기기 걸음 센서(부팅 이후 누적값)로 내는 걷는 중의 실시간 걸음·거리·분당 걸음.
/// health 기록과 달리 늦게 들어오지 않아서 걷는 중 화면 표시에 쓰고, 진행·보상 기준은 아니다.
/// 앱이 숨어 있던([pause]) 동안 센 걸음은 버리지 않는다: 누적값이라 숨은 뒤 처음 받는 증가에
/// 그 사이 걸음이 다 들어 있어서, 숨은 시각부터 그 값을 받은 시각까지로 펴서 센다.
/// 걸음 감지 센서([onDetect], 안드로이드, 16장 11/19)는 걸음마다 바로 와서 화면에 보이는 걸음·거리
/// ([shownSteps]·[shownM])를 카운터보다 먼저 올리고, 감지 걸음이 한 번이라도 오면 분당 걸음도 감지 걸음으로 낸다.
/// 센 걸음([steps]·[distanceM]·[minutes])은 카운터 값 그대로다 (첫 카운터 값을 받기 전 감지 걸음만 예외).
/// 시각은 부르는 쪽이 넘겨서 순수하게 계산한다
class LiveWalk {
  LiveWalk(this.rules);

  final Rules rules;

  /// 마지막으로 본 누적값(기준). 첫 값을 받기 전에는 null. 숨어 있는 동안에도 그대로 둔다
  int? _last;
  var _steps = 0;
  var _distanceM = 0.0;
  var _foregroundM = 0.0;
  var _gait = Gait.walk;
  DateTime? _lastStepAt;
  final _gains = <_Gain>[];

  /// 앱이 숨은 시각. 숨어 있지 않으면 null. 숨은 뒤 처음 늘어난 값이 오면 따라잡고 지운다
  DateTime? _pausedAt;
  var _catchUps = 0;

  /// (UTC epoch 분, 걷기/뛰기)별로 쌓은 걸음. 걷기 기록이 health 대신 쓰는 분 단위 값
  final _buckets = <(int, Gait), int>{};

  /// 감지 센서 걸음 (분당 걸음 창·앞섬 상한에 쓰는 최근 것만). 한 번이라도 오면 [_detecting]
  final _detects = <_Gain>[];
  var _detecting = false;

  /// 감지 센서가 셌지만 아직 카운터 값에 들지 않았다고 보는 걸음 (화면에만 먼저 보인다)
  var _lead = 0;

  /// 화면에 보이는 걸음·거리 (뒤로 가지 않는다)
  var _shownSteps = 0;
  var _shownM = 0.0;

  /// 센서가 값을 주고 있다 (카운터 기준값을 잡았거나 감지 걸음이 왔다)
  bool get active => _last != null || _detecting;

  /// 감지 센서 걸음을 받은 적이 있는가 (분당 걸음을 감지 걸음으로 낸다)
  bool get detecting => _detecting;

  /// 화면에 보이는 걸음: 센 걸음 + 감지 센서가 먼저 센 걸음. 카운터 값이 오면 그 걸음으로 맞추되 뒤로 가지 않는다
  int get shownSteps => _shownSteps;

  /// 화면에 보이는 거리(m): 센 거리 + 먼저 센 걸음 × 지금 보폭. 뒤로 가지 않는다
  double get shownM => _shownM;

  /// 기준 뒤 늘어난 걸음 (재부팅으로 기준을 다시 잡아도 쌓인 값은 그대로)
  int get steps => _steps;

  /// 늘어난 걸음 × 그때의 보폭을 쌓은 거리(m)
  double get distanceM => _distanceM;

  /// [distanceM] 중 앱이 앞에 있는 동안 센 걸음의 거리(m). 숨어 있던 동안 따라잡은 걸음은 뺀다
  /// (길 위 이벤트의 칸 기준, 앱 밖에서 걸은 거리는 이벤트가 없다)
  double get foregroundM => _foregroundM;

  /// 센 걸음을 분(UTC epoch 분)·걷기/뛰기별로 쌓은 목록, 분 순서(같은 분이면 걷기가 먼저).
  /// 증가분의 보폭을 정한 걷기/뛰기로 나눠 담아서, 한 분 안에서 걷기/뛰기가 바뀌면 그 분이 두 번 나온다
  /// (그래야 Σ 걸음 × 보폭이 [distanceM]과 정확히 같다). 재부팅으로 기준을 다시 잡아도 쌓인 값은 그대로.
  /// 숨어 있던 동안의 걸음은 숨은 시각부터 값을 받은 시각까지 분마다 나눠 담는다.
  /// 걷기 기록(summarizeWalk·splitLaps)이 health 기록이 늦을 때 이 값을 쓴다
  List<GaitMinute> get minutes {
    final keys = _buckets.keys.toList()
      ..sort((a, b) => a.$1 != b.$1 ? a.$1.compareTo(b.$1) : a.$2.index.compareTo(b.$2.index));
    return [for (final k in keys) GaitMinute(k.$1, _buckets[k]!, k.$2)];
  }

  /// 마지막으로 판정한 걷기/뛰기. 걸음이 없던 동안에는 그대로 둔다 (그래서 달리는 중인지는 분당 걸음 > 0도 본다)
  Gait get gait => _gait;

  /// 숨어 있던 동안 걸음을 따라잡은 횟수. 늘면 걸음이 한꺼번에 들어온 것이라 화면이 거리를 바로 맞춘다
  int get catchUps => _catchUps;

  /// 센서 값 하나. 처음 값은 기준값이라 세지 않고, 그 뒤 증가분만 센다.
  /// 값이 기준보다 작아지면 재부팅으로 카운터가 0부터 다시 시작한 것이라 그 값을 새 기준으로 잡는다.
  /// [pause] 뒤에는 처음 늘어난 값이 숨어 있던 동안의 걸음까지 포함하므로 따라잡아 센다
  /// (기준과 같은 값이 먼저 와도 숨은 상태는 그대로다. 기기에 따라 옛 값을 다시 주기도 한다)
  /// 카운터 값이 오면 감지 센서가 먼저 센 걸음([shownSteps]의 앞선 몫)에서 늘어난 만큼을 빼고, 최근
  /// liveDetectorLeadSec초보다 앞서 감지한 걸음은 카운터에 들었다고 본다 (카운터는 늦어도 그 안에 담는다).
  /// 첫 값(기준)을 받기 전에 감지한 걸음은 그 값에 들어 있다고 보고 센 걸음으로 옮긴다
  /// (감지 걸음으로 물감 길이 열린 뒤 카운터가 처음 값을 줄 때)
  void onCount(int total, DateTime at) {
    final last = _last;
    _last = total;
    if (last == null) {
      if (_lead > 0) _count(_lead, at);
      _lead = 0;
      _show();
      return;
    }
    if (total <= last) return;
    final gain = total - last;

    final pausedAt = _pausedAt;
    if (pausedAt != null) {
      _catchUp(gain, pausedAt, at);
      // 따라잡은 걸음에 숨기 전 먼저 센 걸음까지 들어 있다
      _lead = 0;
      _show();
      return;
    }

    _resetGaitAfterGap(at);
    _gains
      ..removeWhere((g) => !_inWindow(g.at, at))
      ..add(_Gain(at, gain));
    _gait = judgeGait(stepsPerMin(at), _gait, rules);
    _count(gain, at);
    _lead = math.min(math.max(0, _lead - gain), _detectedSince(at, rules.liveDetectorLeadSec));
    _show();
  }

  /// 걸음 감지 센서가 [at]에 걸음 [steps]개를 알아챘다 (앱이 앞에 있을 때만 부른다). 화면 걸음·거리를 바로 올리고
  /// 분당 걸음 창에 넣는다. 센 걸음은 그대로다 (카운터 값이 오면 맞춘다)
  void onDetect(DateTime at, [int steps = 1]) {
    if (steps <= 0) return;
    _detecting = true;
    _resetGaitAfterGap(at);
    final keep = Duration(seconds: math.max(rules.liveCadenceWindowSec, rules.liveDetectorLeadSec));
    _detects
      ..removeWhere((g) => at.difference(g.at) >= keep)
      ..add(_Gain(at, steps));
    _gait = judgeGait(stepsPerMin(at), _gait, rules);
    _lead += steps;
    _show();
  }

  /// 걸음이 없던 시간이 sessionMaxGapMin보다 길면 새 걷기라 walk로 다시 시작한다 (classifyGait와 같은 규칙)
  void _resetGaitAfterGap(DateTime at) {
    final lastStepAt = _lastStepAt;
    if (lastStepAt != null &&
        at.difference(lastStepAt) > Duration(minutes: rules.sessionMaxGapMin)) {
      _gait = Gait.walk;
    }
    if (lastStepAt == null || at.isAfter(lastStepAt)) _lastStepAt = at;
  }

  /// 앞에 있을 때 센 걸음 [gain]을 [at]의 분·지금 걷기/뛰기로 담는다
  void _count(int gain, DateTime at) {
    _buckets.update((epochMinute(at), _gait), (n) => n + gain, ifAbsent: () => gain);
    _steps += gain;
    final m = gain * strideM(_gait, rules);
    _distanceM += m;
    _foregroundM += m;
  }

  /// [now] 전 [sec]초 안에 감지한 걸음 수
  int _detectedSince(DateTime now, int sec) => _detects
      .where((g) => now.difference(g.at) < Duration(seconds: sec))
      .fold(0, (sum, g) => sum + g.steps);

  /// 화면 걸음·거리를 지금 값으로 올린다 (내리지 않는다)
  void _show() {
    _shownSteps = math.max(_shownSteps, _steps + _lead);
    _shownM = math.max(_shownM, _distanceM + _lead * strideM(_gait, rules));
  }

  /// 숨어 있는 동안 [LiveWalk]에 먹이지 않고 센서 값 [total]만 본 때의 걸음 수 (알림에 쓰는 미리보기):
  /// 지금까지 센 걸음 + 기준 뒤 늘어난 만큼. 기준이 없거나 [total]이 기준보다 작으면(재부팅) 더하지 않는다.
  /// 상태는 바꾸지 않는다
  int previewSteps(int total) {
    final last = _last;
    return last == null ? _steps : _steps + math.max(0, total - last);
  }

  /// [previewSteps]와 같은 값으로 낸 거리(m): 지금까지 센 거리 + 기준 뒤 늘어난 걸음 × 걷기 보폭.
  /// 숨어 있는 동안은 걷는지 뛰는지 알 수 없어서, 알림 거리가 앞섰다가 줄어드는 일이 없게
  /// 더 짧은 걷기 보폭을 쓴다 (앞으로 돌아오면 판정한 보폭으로 다시 맞춘다). 상태는 바꾸지 않는다
  double previewDistanceM(int total) {
    final last = _last;
    return last == null
        ? _distanceM
        : _distanceM + math.max(0, total - last) * strideM(Gait.walk, rules);
  }

  /// 앱이 [at]에 숨었다. 기준값은 그대로 두고 분당 걸음 창만 비운다.
  /// 이미 숨어 있으면 이른 시각을 그대로 둔다. 기준값을 받은 적이 없으면 따라잡을 게 없어 무시한다
  void pause(DateTime at) {
    _detects.clear();
    if (_last == null) return;
    _pausedAt ??= at;
    _gains.clear();
  }

  /// 숨어 있던 동안의 걸음 [gain]을 [pausedAt]~[at]에 펴서 센다. 구간 전체의 평균 분당 걸음으로
  /// 걷기/뛰기를 한 번 정하고(직전 상태는 걷기), 분당 걸음 창에는 넣지 않는다 (화면에 뛰기로 튀지 않게)
  void _catchUp(int gain, DateTime pausedAt, DateTime at) {
    final gapSec = math.max(1, at.difference(pausedAt).inSeconds);
    final gait = judgeGait((gain * 60 / gapSec).round(), Gait.walk, rules);
    splitSteps(gain, pausedAt, at).forEach((minute, n) {
      _buckets.update((minute, gait), (v) => v + n, ifAbsent: () => n);
    });
    _steps += gain;
    _distanceM += gain * strideM(gait, rules);
    _gait = gait;
    _lastStepAt = at;
    _pausedAt = null;
    _catchUps++;
  }

  /// [now] 기준 최근 liveCadenceWindowSec초 동안의 걸음을 분당으로 환산한 값. 감지 걸음이 온 적이 있으면
  /// 감지 걸음으로 (카운터는 걸음을 모아 늦게 보내서 빠르기가 들쭉날쭉하다), 아니면 카운터 증가로 낸다.
  /// 창이 차기 전에는 낮게 나온다 (첫 걸음 몇 개로 뛰기로 튀지 않게)
  int stepsPerMin(DateTime now) {
    final recent = (_detecting ? _detects : _gains)
        .where((g) => _inWindow(g.at, now))
        .fold(0, (sum, g) => sum + g.steps);
    return (recent * 60 / rules.liveCadenceWindowSec).round();
  }

  bool _inWindow(DateTime at, DateTime now) =>
      now.difference(at) < Duration(seconds: rules.liveCadenceWindowSec);
}

/// 걷는 중 화면에 보이는 이번 걷기 숫자: 걸음·거리는 health 기록과 센서 중 큰 쪽,
/// 분당 걸음과 걷기/뛰기는 센서 기준. 센서가 아직 값을 주지 않으면 health 그대로
/// (health 기록도 아직 없으면 null). 센서 걸음에는 앱이 숨어 있던 동안 센 것도 들어 있다
/// (돌아올 때 한꺼번에 더해진다. 그 사이 앱이 종료되면 센서는 놓치고 health에만 남는다)
WalkSummary? liveSummary(WalkSummary? health, LiveWalk live, DateTime now) {
  if (!live.active) return health;
  return WalkSummary(
    steps: math.max(health?.steps ?? 0, live.steps),
    distanceM: math.max(health?.distanceM ?? 0, live.distanceM),
    activeMinutes: health?.activeMinutes ?? 0,
    runSteps: health?.runSteps ?? 0,
    lastSteps: live.stepsPerMin(now),
    lastGait: live.gait,
  );
}

/// 걷는 중 화면에 보이는 이번 걷기 걸음·거리: health 기록과 센서 화면 값([LiveWalk.shownSteps]·[LiveWalk.shownM]:
/// 센 걸음 + 감지 센서가 먼저 센 걸음) 중 큰 쪽. 뒤로 가지 않는다 (둘 다 뒤로 가지 않는다)
({int steps, double distanceM}) liveShown(WalkSummary? health, LiveWalk live) => (
      steps: math.max(health?.steps ?? 0, live.shownSteps),
      distanceM: math.max(health?.distanceM ?? 0, live.shownM),
    );
