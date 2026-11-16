import 'dart:convert';
import 'dart:io';

import 'package:doobal/app/paint_providers.dart';
import 'package:doobal/app/providers.dart';
import 'package:doobal/data/db/app_db.dart';
import 'package:doobal/data/server.dart';
import 'package:doobal/domain/gait.dart';
import 'package:doobal/domain/geo.dart';
import 'package:doobal/domain/paint_color.dart';
import 'package:doobal/domain/rules.dart';
import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../domain/helpers.dart';
import 'fake_server.dart';

// 날씨 묻기 (16장 11/14 ⑤·11/16 ①, M2~M6 v0.20 Y·v0.22 AA): 정령이 있는 지도 위 여정 지점으로 getWeather,
// 한국 날짜마다 한 번(받은 날씨는 DB에 둬서 껐다 켜도 그날은 그대로, 실패하면 다음에 다시),
// 서버가 없거나 로그인 전이거나 실패하면 null = 시간대 색 (오프라인 원칙의 예외 하나)

const _seoul = LatLng(37.5665, 126.978);
final _t = DateTime.utc(2026, 11, 18, 1);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  Future<(ProviderContainer, FakeServer?)> make(
      {bool server = true, bool ageConfirmed = true, AppDb? reuse}) async {
    final db = reuse ?? AppDb(NativeDatabase.memory());
    if (reuse == null) addTearDown(db.close);
    if (ageConfirmed && reuse == null) {
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

  test('하루 한 번: 그날 받았으면 다시 묻지 않고(물감 길을 다시 열어도), 한국 날짜가 바뀌면 다시 묻는다', () async {
    final (c, s) = await make();
    s!.api.weather = 'rain';
    final w = c.read(paintWeatherProvider.notifier);
    await w.ask(_seoul, _t, rules, force: true);
    expect(c.read(paintWeatherProvider).kind, PaintWeather.rain);
    expect(c.read(paintWeatherProvider).day, '2026-11-18');
    expect(s.api.weatherAsked, [(37.5665, 126.978)]);

    // 같은 날 다른 물감 길(force)·멀리 간 지점이어도 그날 날씨 그대로
    s.api.weather = 'snow';
    await w.ask(const LatLng(35.1796, 129.0756), _t.add(const Duration(hours: 13)), rules, force: true);
    expect(c.read(paintWeatherProvider).kind, PaintWeather.rain);
    expect(s.api.weatherAsked, hasLength(1));
    // KST 11/19 00:00 = UTC 11/18 15:00: 날이 바뀌면 다시 묻는다
    await w.ask(_seoul, DateTime.utc(2026, 11, 18, 15), rules, force: true);
    expect(c.read(paintWeatherProvider).kind, PaintWeather.snow);
    expect(c.read(paintWeatherProvider).day, '2026-11-19');
    expect(s.api.weatherAsked, hasLength(2));
  });

  test('칠할 때 쓰는 날씨: 그날 날씨, 자정을 넘긴 물감 길은 연 날 날씨, 다음 날 새 물감 길은 묻기 전까지 모름', () async {
    const st = PaintWeatherState(kind: PaintWeather.cloudy, day: '2026-11-18');
    expect(st.kindFor(_t), PaintWeather.cloudy);
    // KST 11/19 00:30, 11/18에 연 물감 길
    final after = DateTime.utc(2026, 11, 18, 15, 30);
    expect(st.kindFor(after, DateTime.utc(2026, 11, 18, 14)), PaintWeather.cloudy);
    expect(st.kindFor(after, after), isNull);
    expect(st.kindFor(after), isNull);
    // 하루 한 번이 아니면(날짜 없음) 마지막 날씨
    expect(const PaintWeatherState(kind: PaintWeather.rain).kindFor(after), PaintWeather.rain);
  });

  test('받은 날씨는 sync_state에 둬서 앱을 새로 켜도 그날은 다시 묻지 않는다', () async {
    final (c, s) = await make();
    final db = c.read(dbProvider);
    await db.into(db.syncState).insert(
        SyncStateCompanion.insert(id: const Value(1), firstRecordDay: '2026-11-18', installUtc: 0));
    s!.api.weather = 'snow';
    await c.read(paintWeatherProvider.notifier).ask(_seoul, _t, rules, force: true);
    expect(s.api.weatherAsked, hasLength(1));

    // 앱을 새로 켰다 (같은 DB, 새 컨테이너·새 서버)
    final (again, s2) = await make(reuse: db);
    s2!.api.weather = 'rain';
    await again.read(paintWeatherProvider.notifier).ask(_seoul, _t.add(const Duration(hours: 2)), rules, force: true);
    expect(again.read(paintWeatherProvider).kind, PaintWeather.snow);
    expect(s2.api.weatherAsked, isEmpty);
  });

  test('하루 한 번이 아니면(config per 없음) askMin 간격으로 다시 묻는다', () async {
    final j = jsonDecode(File('assets/data/config.json').readAsStringSync()) as Map<String, dynamic>;
    final source = j['paintColor']['weatherSource'] as Map<String, dynamic>;
    source.remove('per');
    source['askMin'] = 30;
    final r = Rules.fromJson(j);
    expect(r.paintColor.weatherPerDay, isFalse);
    final (c, s) = await make();
    s!.api.weather = 'rain';
    final w = c.read(paintWeatherProvider.notifier);
    await w.ask(_seoul, _t, r);
    s.api.weather = 'snow';
    await w.ask(_seoul, _t.add(const Duration(minutes: 29)), r);
    expect(c.read(paintWeatherProvider).kind, PaintWeather.rain);
    await w.ask(_seoul, _t.add(const Duration(minutes: 30)), r);
    expect(c.read(paintWeatherProvider).kind, PaintWeather.snow);
    expect(s.api.weatherAsked, hasLength(2));
  });

  test('실패·오프라인이면 null(시간대 색), 서버가 없거나 만 14세 확인 전이면 묻지 않는다', () async {
    final (c, s) = await make();
    s!.api.failAlways = const ServerError.offline();
    await c.read(paintWeatherProvider.notifier).ask(_seoul, _t, rules);
    expect(c.read(paintWeatherProvider).kind, isNull);
    expect(c.read(paintWeatherProvider).askedAt, _t);
    // 실패는 그날 것으로 적지 않아서 다음 물감 길에서 다시 묻는다
    expect(c.read(paintWeatherProvider).day, isNull);
    s.api.failAlways = null;
    s.api.weather = 'cloudy';
    await c.read(paintWeatherProvider.notifier).ask(_seoul, _t.add(const Duration(minutes: 5)), rules, force: true);
    expect(c.read(paintWeatherProvider).kind, PaintWeather.cloudy);

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
    expect(momentColorFor(_seoul, _t, null, Gait.walk, rules), 'autumn.day');
    expect(momentColorFor(_seoul, _t, PaintWeather.rain, Gait.run, rules), 'autumn.rain_run');
    // 지점을 모르면 다른 자리로라도 시간대 색을 낸다
    expect(momentColorFor(null, _t, PaintWeather.snow, Gait.walk, rules), 'autumn.snow');
  });
}
