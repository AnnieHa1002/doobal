import 'package:doobal/app/paint_providers.dart';
import 'package:doobal/app/providers.dart';
import 'package:doobal/data/db/app_db.dart';
import 'package:doobal/data/server.dart';
import 'package:doobal/domain/gait.dart';
import 'package:doobal/domain/geo.dart';
import 'package:doobal/domain/paint_color.dart';
import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../domain/helpers.dart';
import 'fake_server.dart';

// 날씨 묻기 (16장 11/14 ⑤, M2~M6 v0.20 Y): 정령이 있는 지도 위 여정 지점으로 getWeather, askMin 간격,
// 서버가 없거나 로그인 전이거나 실패하면 null = 시간대 색 (오프라인 원칙의 예외 하나)

const _seoul = LatLng(37.5665, 126.978);
final _t = DateTime.utc(2026, 11, 18, 1);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  Future<(ProviderContainer, FakeServer?)> make({bool server = true, bool ageConfirmed = true}) async {
    final db = AppDb(NativeDatabase.memory());
    addTearDown(db.close);
    if (ageConfirmed) {
      await db.into(db.profile).insert(
          ProfileCompanion.insert(id: const Value(1), ageConfirmedAt: const Value(1)));
    }
    final s = server ? FakeServer() : null;
    final c = ProviderContainer(overrides: [
      dbProvider.overrideWithValue(db),
      rulesProvider.overrideWith((ref) => rules),
      if (s != null) serverBackendProvider.overrideWithValue(s.backend),
    ]);
    addTearDown(c.dispose);
    return (c, s);
  }

  test('지점으로 묻고 받은 날씨를 둔다. askMin(config 없으면 cacheMin 60분) 안에는 다시 묻지 않는다', () async {
    final (c, s) = await make();
    s!.api.weather = 'rain';
    final w = c.read(paintWeatherProvider.notifier);
    await w.ask(_seoul, _t, rules);
    expect(c.read(paintWeatherProvider).kind, PaintWeather.rain);
    expect(s.api.weatherAsked, [(37.5665, 126.978)]);

    s.api.weather = 'snow';
    await w.ask(_seoul, _t.add(const Duration(minutes: 59)), rules);
    expect(c.read(paintWeatherProvider).kind, PaintWeather.rain);
    expect(s.api.weatherAsked, hasLength(1));
    await w.ask(_seoul, _t.add(const Duration(minutes: 60)), rules);
    expect(c.read(paintWeatherProvider).kind, PaintWeather.snow);
    // 물감 길을 열 때는 바로 묻는다
    s.api.weather = 'cloudy';
    await w.ask(_seoul, _t.add(const Duration(minutes: 61)), rules, force: true);
    expect(c.read(paintWeatherProvider).kind, PaintWeather.cloudy);
  });

  test('실패·오프라인이면 null(시간대 색), 서버가 없거나 만 14세 확인 전이면 묻지 않는다', () async {
    final (c, s) = await make();
    s!.api.failAlways = const ServerError.offline();
    await c.read(paintWeatherProvider.notifier).ask(_seoul, _t, rules);
    expect(c.read(paintWeatherProvider).kind, isNull);
    expect(c.read(paintWeatherProvider).askedAt, _t);

    final (none, _) = await make(server: false);
    await none.read(paintWeatherProvider.notifier).ask(_seoul, _t, rules);
    expect(none.read(paintWeatherProvider).kind, isNull);

    final (young, ys) = await make(ageConfirmed: false);
    await young.read(paintWeatherProvider.notifier).ask(_seoul, _t, rules);
    expect(young.read(paintWeatherProvider).kind, isNull);
    expect(ys!.api.weatherAsked, isEmpty);
  });

  test('모르는 날씨 이름은 null, 날씨에 따라 그 순간 색이 바뀐다 (서울 KST 10시 = 낮)', () async {
    final (c, s) = await make();
    s!.api.weather = 'hail';
    await c.read(paintWeatherProvider.notifier).ask(_seoul, _t, rules);
    expect(c.read(paintWeatherProvider).kind, isNull);
    expect(momentColorFor(_seoul, _t, null, Gait.walk, rules), 'day');
    expect(momentColorFor(_seoul, _t, PaintWeather.rain, Gait.run, rules), 'rain_run');
    // 지점을 모르면 다른 자리로라도 시간대 색을 낸다
    expect(momentColorFor(null, _t, PaintWeather.snow, Gait.walk, rules), 'snow');
  });
}
