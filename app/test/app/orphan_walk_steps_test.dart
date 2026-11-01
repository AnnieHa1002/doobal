import 'package:doobal/data/db/app_db.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';

import '../ui/ui_env.dart';

// 앱을 켠 직후 '걷기가 멈췄어요' 토스트에 쓰는 SyncService 두 가지:
// 닫은 창의 끝 시각(closeOrphanAppWalksEnd)과 그 뒤 쌓인 걸음(stepsFrom).
// 설치 t0(UTC 00:00), 분 기준은 모두 t0 이후

DateTime _t(int minutes, [int seconds = 0]) => t0.add(Duration(minutes: minutes, seconds: seconds));

int _ms(DateTime t) => t.millisecondsSinceEpoch;

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  group('closeOrphanAppWalksEnd', () {
    test('열린 창이 없으면 null이고 아무것도 건드리지 않는다', () async {
      final e = UiEnv();
      addTearDown(e.db.close);
      expect(await e.svc.closeOrphanAppWalksEnd(_t(60)), isNull);
      expect(await e.db.select(e.db.syncState).get(), isEmpty);
    });

    test('창을 마지막으로 살아 있던 시각에 닫고 그 시각을 돌려준다 (다시 부르면 null)', () async {
      final e = UiEnv();
      addTearDown(e.db.close);
      await e.svc.sync(t0);
      await e.db.into(e.db.appWalks).insert(AppWalksCompanion.insert(startUtc: _ms(t0)));
      await e.svc.saveAlive(_t(20));

      expect(await e.svc.closeOrphanAppWalksEnd(_t(60)), _t(20));
      final row = (await e.db.select(e.db.appWalks).get()).single;
      expect((row.endUtc, row.endReason), (_ms(_t(20)), AppWalkEnd.appEnded));
      expect(await e.svc.closeOrphanAppWalksEnd(_t(61)), isNull);
    });

    test('창이 둘 열려 있으면 가장 늦은 끝: 첫 창은 살아 있던 시각 20분, 둘째는 그보다 늦게 열려 길이 0 (30분)',
        () async {
      final e = UiEnv();
      addTearDown(e.db.close);
      await e.svc.sync(t0);
      await e.db.into(e.db.appWalks).insert(AppWalksCompanion.insert(startUtc: _ms(t0)));
      await e.db.into(e.db.appWalks).insert(AppWalksCompanion.insert(startUtc: _ms(_t(30))));
      await e.svc.saveAlive(_t(20));

      expect(await e.svc.closeOrphanAppWalksEnd(_t(60)), _t(30));
    });

    test('closeOrphanAppWalks는 그대로 닫은 창의 수를 돌려준다', () async {
      final e = UiEnv();
      addTearDown(e.db.close);
      await e.svc.sync(t0);
      await e.db.into(e.db.appWalks).insert(AppWalksCompanion.insert(startUtc: _ms(t0)));
      expect(await e.svc.closeOrphanAppWalks(_t(60)), 1);
      expect(await e.svc.closeOrphanAppWalks(_t(61)), 0);
    });
  });

  group('stepsFrom: 분 시작이 from 이상, upTo가 속한 분까지', () {
    /// 분 5~9(500보), 20~22(300보), 40·41(200보)가 저장돼 있다
    Future<UiEnv> env() async {
      final e = UiEnv();
      addTearDown(e.db.close);
      await e.svc.sync(t0);
      e.source.records
        ..add(walkRecord(_t(5), 5, 100))
        ..add(walkRecord(_t(20), 3, 100))
        ..add(walkRecord(_t(40), 2, 100));
      await e.svc.sync(_t(60));
      return e;
    }

    test('분 경계에 맞는 from: 20분부터면 20~22분과 40·41분 = 500보', () async {
      final e = await env();
      expect(await e.svc.stepsFrom(_t(20), _t(60)), 500);
      expect(await e.svc.stepsFrom(_t(0), _t(60)), 1000);
    });

    test('from이 분 중간이면 그 분은 창에 속하니 세지 않고 다음 분부터: 20분 30초 → 21~22분과 40·41분 = 400보',
        () async {
      final e = await env();
      expect(await e.svc.stepsFrom(_t(20, 30), _t(60)), 400);
      // 분 경계 바로 뒤(1초)도 다음 분부터
      expect(await e.svc.stepsFrom(_t(20, 1), _t(60)), 400);
    });

    test('upTo가 속한 분은 센다, 그 뒤 분은 안 센다', () async {
      final e = await env();
      // 22분 10초면 20·21·22분 = 300보
      expect(await e.svc.stepsFrom(_t(20), _t(22, 10)), 300);
      // 21분 정각이면 20·21분 = 200보
      expect(await e.svc.stepsFrom(_t(20), _t(21)), 200);
    });

    test('걸음이 없는 구간이면 0', () async {
      final e = await env();
      expect(await e.svc.stepsFrom(_t(50), _t(60)), 0);
      expect(await e.svc.stepsFrom(_t(23), _t(39)), 0);
    });
  });
}
