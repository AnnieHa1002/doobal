import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/gait.dart';
import '../domain/geo.dart';
import '../domain/paint_color.dart';
import '../domain/rules.dart';
import '../domain/time_kst.dart';
import 'paint_service.dart';
import 'providers.dart';

/// 물감 보관·고르기·칠하기 (스키마 18)
final paintServiceProvider = FutureProvider<PaintService>((ref) async =>
    PaintService(ref.watch(dbProvider), await ref.watch(rulesProvider.future)));

/// 배낭 물감 탭: 가진 색과 지금 칠할 물감. 고르거나 통을 받으면 invalidate 한다
final paintShelfProvider = FutureProvider<PaintShelfData>(
    (ref) async => (await ref.watch(paintServiceProvider.future)).shelf());

/// 처음 모은 뒤 배낭에서 안 본 색 수 (배낭 새 소식 점, M2~M6 v0.20 Y ‘새 색을 처음 모았을 때만’)
final unseenPaintsProvider = FutureProvider<int>(
    (ref) async => (await ref.watch(paintServiceProvider.future)).unseenColors());

/// [colorId] 통을 한 번 더 주울 수 있는가 (가진 통이 상한 아래). 걷는 중 화면이 방울 뒤 물감 통을 보일지 본다.
/// 통을 받으면 invalidate 한다
final paintTubeRoomProvider = FutureProvider.family<bool, String>(
    (ref, colorId) async => (await ref.watch(paintServiceProvider.future)).canGetTube(colorId));

/// 날씨 (getWeather). [kind]가 null이면 모름 (서버 없음·오프라인·실패) → 시간대 색.
/// [day]는 그 날씨의 한국 날짜 키 (하루 한 번 묻기, config weatherSource.per kstDay)
@immutable
class PaintWeatherState {
  const PaintWeatherState({this.kind, this.day, this.askedAt, this.asking = false});

  final PaintWeather? kind;
  final String? day;

  /// 마지막으로 물은 시각 (성공·실패 모두)
  final DateTime? askedAt;
  final bool asking;

  /// [now]에 칠할 때 쓰는 날씨: 하루 한 번이면 그날(또는 [trailStart] 물감 길을 연 날, 자정을 넘긴 물감 길) 날씨만.
  /// 하루 한 번이 아니면 마지막으로 받은 날씨
  PaintWeather? kindFor(DateTime now, [DateTime? trailStart]) {
    final d = day;
    if (d == null) return kind;
    if (d == kstDayKey(now) || (trailStart != null && d == kstDayKey(trailStart))) return kind;
    return null;
  }
}

/// 날씨 묻기 (16장 11/14·11/16, M2~M6 v0.22 AA): 정령이 있는 지도 위 여정 지점으로 서버 getWeather에 묻는다
/// (위치 권한 없음). config weatherSource.per가 kstDay면 한국 날짜가 바뀐 뒤 첫 물감 길에서 한 번만 묻고 그날은 다시
/// 묻지 않는다 (받은 날씨는 DB sync_state에 둬서 앱을 껐다 켜도 그날은 그대로, 실패하면 다음 물감 길에서 다시).
/// 아니면 물감 길이 시작할 때와 askMin마다. 서버가 없거나(시험·서버를 끈 빌드) 로그인 전이거나 실패하면 null = 시간대 색.
/// 물감 통은 받은 순간 색으로 저장된다
class PaintWeatherController extends Notifier<PaintWeatherState> {
  var _loaded = false;

  @override
  PaintWeatherState build() => const PaintWeatherState();

  /// [p]의 날씨를 묻는다. 하루 한 번이면 그날 이미 받았으면 묻지 않고, 아니면 [force]가 아닐 때 마지막으로 물은 뒤
  /// askMin분이 안 지났으면 묻지 않는다
  Future<void> ask(LatLng p, DateTime now, Rules rules, {bool force = false}) async {
    if (state.asking) return;
    final perDay = rules.paintColor.weatherPerDay;
    final today = kstDayKey(now);
    if (perDay) {
      await _loadSaved();
      if (state.day == today && state.kind != null) return;
    } else {
      final last = state.askedAt;
      if (!force &&
          last != null &&
          now.difference(last) < Duration(minutes: rules.paintColor.weatherAskMin)) {
        return;
      }
    }
    final server = ref.read(serverBackendProvider);
    if (server == null) {
      state = PaintWeatherState(kind: state.kind, day: state.day, askedAt: now);
      return;
    }
    state = PaintWeatherState(kind: state.kind, day: state.day, askedAt: now, asking: true);
    PaintWeather? kind;
    try {
      if (await ref.read(accountServiceProvider)?.ensureSignedIn() != null) {
        kind = paintWeatherOf((await server.api.getWeather(p.lat, p.lng)).kind);
      }
    } catch (e) {
      debugPrint('날씨 묻기 실패 (시간대 색): $e');
    }
    if (perDay) {
      // 받지 못했으면 그날 것으로 적지 않는다 (다음 물감 길에서 다시)
      state = kind == null
          ? PaintWeatherState(kind: state.kind, day: state.day, askedAt: now)
          : PaintWeatherState(kind: kind, day: today, askedAt: now);
      if (kind != null) await _save(today, kind);
    } else {
      state = PaintWeatherState(kind: kind, askedAt: now);
    }
  }

  /// 앱을 켠 뒤 처음: 그날 받아 둔 날씨 (DB sync_state, 스키마 20)
  Future<void> _loadSaved() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final saved = await (await ref.read(paintServiceProvider.future)).savedWeather();
      if (saved != null && state.day == null) {
        state = PaintWeatherState(
            kind: paintWeatherOf(saved.kind), day: saved.day, askedAt: state.askedAt);
      }
    } catch (e) {
      debugPrint('받아 둔 날씨 읽기 실패: $e');
    }
  }

  Future<void> _save(String day, PaintWeather kind) async {
    try {
      await (await ref.read(paintServiceProvider.future)).saveWeather(day, kind.name);
    } catch (e) {
      debugPrint('날씨 저장 실패: $e');
    }
  }
}

final paintWeatherProvider =
    NotifierProvider<PaintWeatherController, PaintWeatherState>(PaintWeatherController.new);

/// [p](정령이 있는 지도 위 여정 지점)·[now]의 그 순간 물감 색 id. 지점을 모르면(출발 동네 전) 첫 명소 자리로 잰다
String momentColorFor(LatLng? p, DateTime now, PaintWeather? weather, Gait gait, Rules rules,
        {LatLng? fallback}) =>
    momentColorAt(p ?? fallback ?? rules.ports.values.first, now, weather, gait, rules);
