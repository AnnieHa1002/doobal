import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/gait.dart';
import '../domain/geo.dart';
import '../domain/paint_color.dart';
import '../domain/rules.dart';
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

/// 지금 날씨 (getWeather). [kind]가 null이면 모름 (서버 없음·오프라인·실패) → 시간대 색
@immutable
class PaintWeatherState {
  const PaintWeatherState({this.kind, this.askedAt, this.asking = false});

  final PaintWeather? kind;

  /// 마지막으로 물은 시각 (성공·실패 모두)
  final DateTime? askedAt;
  final bool asking;
}

/// 날씨 묻기 (16장 11/14, M2~M6 v0.20 Y): 물감 길이 시작할 때와 config paintColor.weatherSource.askMin마다
/// 정령이 있는 지도 위 여정 지점으로 서버 getWeather에 묻는다 (위치 권한 없음). 서버가 없거나(시험·서버를 끈 빌드)
/// 로그인 전이거나 실패하면 null = 시간대 색. 날씨는 저장하지 않는다 (물감 통은 받은 순간 색으로 저장된다)
class PaintWeatherController extends Notifier<PaintWeatherState> {
  @override
  PaintWeatherState build() => const PaintWeatherState();

  /// [p]의 날씨를 묻는다. [force]가 아니면 마지막으로 물은 뒤 askMin분이 안 지났으면 묻지 않는다
  Future<void> ask(LatLng p, DateTime now, Rules rules, {bool force = false}) async {
    if (state.asking) return;
    final last = state.askedAt;
    if (!force &&
        last != null &&
        now.difference(last) < Duration(minutes: rules.paintColor.weatherAskMin)) {
      return;
    }
    final server = ref.read(serverBackendProvider);
    if (server == null) {
      state = PaintWeatherState(askedAt: now);
      return;
    }
    state = PaintWeatherState(kind: state.kind, askedAt: now, asking: true);
    PaintWeather? kind;
    try {
      if (await ref.read(accountServiceProvider)?.ensureSignedIn() != null) {
        kind = paintWeatherOf((await server.api.getWeather(p.lat, p.lng)).kind);
      }
    } catch (e) {
      debugPrint('날씨 묻기 실패 (시간대 색): $e');
    }
    state = PaintWeatherState(kind: kind, askedAt: now);
  }
}

final paintWeatherProvider =
    NotifierProvider<PaintWeatherController, PaintWeatherState>(PaintWeatherController.new);

/// [p](정령이 있는 지도 위 여정 지점)·[now]의 그 순간 물감 색 id. 지점을 모르면(출발 동네 전) 첫 명소 자리로 잰다
String momentColorFor(LatLng? p, DateTime now, PaintWeather? weather, Gait gait, Rules rules,
        {LatLng? fallback}) =>
    momentColorAt(p ?? fallback ?? rules.ports.values.first, now, weather, gait, rules);
