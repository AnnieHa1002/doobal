import 'dart:io';

import 'package:doobal/app/profile_service.dart';
import 'package:doobal/data/db/app_db.dart';
import 'package:doobal/domain/look.dart';
import 'package:doobal/domain/spirit_look.dart';
import 'package:doobal/domain/unified_wardrobe.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('37 소품 착용과 몸 색을 실제 파일 DB에 저장하고 닫았다 다시 연다; 다른 프로필 값 유지', () async {
    final dir = Directory.systemTemp.createTempSync('doobal_look_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/game.sqlite');
    var db = AppDb(NativeDatabase(file));
    var svc = ProfileService(db);
    await svc.confirmAge(DateTime.utc(2026, 11, 12));
    await svc.saveMe('원래 닉네임', Look.initial);
    final old = await svc.row();
    for (final p in unifiedProps) {
      await db.into(db.propsOwned).insertOnConflictUpdate(
          PropsOwnedCompanion(propId: Value(p.id), unlockedUtc: const Value(123)));
    }
    var look = Look.initial.copyWith(body: const CustomBodyColor('#8CBBD0'));
    for (final p in unifiedProps) {
      look = look.withSlot(p.slot, p.id);
    }
    await svc.saveLook(look);
    await db.close();

    db = AppDb(NativeDatabase(file));
    svc = ProfileService(db);
    final restored = (await svc.me()).look;
    expect(restored, look);
    final row = await svc.row();
    expect(row!.nickname, old!.nickname);
    expect(row.installId, old.installId);
    expect(row.ageConfirmedAt, old.ageConfirmedAt);
    // 칸마다 마지막에 끼운 소품, 색은 Rive에 넣는 기본색 (소품 색은 직접 고르지 않음, 16장 11/4)
    final mapped = spiritLookOf(restored, bodyArgb: 0xff8cbbd0);
    expect(mapped.choices,
        {'hat': 4, 'face': 3, 'cloth': 5, 'shoe': 5, 'hand': 5, 'bag': 5, 'pet': 5, 'float': 5});
    expect(mapped.colors, {for (final p in unifiedProps) p.colorField: p.argb});
    await db.close();
  });

  test('옛 모습 JSON은 그대로 읽고, 11/12 시험판의 propColors 키는 읽지 않는다', () {
    final old = Look.initial.toJson();
    expect(Look.fromJson(old), Look.initial);
    final read = Look.fromJson({
      ...old,
      'propColors': {'hat_01': '#aabbcc', 'shoe_05': 'wrong'},
    });
    expect(read, Look.initial);
    expect(read.toJson().containsKey('propColors'), isFalse);
  });
}
