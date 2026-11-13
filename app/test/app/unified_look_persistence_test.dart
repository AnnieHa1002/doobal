import 'dart:io';
import 'package:doobal/app/profile_service.dart';
import 'package:doobal/data/db/app_db.dart';
import 'package:doobal/domain/look.dart';
import 'package:doobal/domain/spirit_look.dart';
import 'package:doobal/domain/unified_wardrobe.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
void main(){
 test('37색과 소품 선택을 실제 게임 DB에 저장하고 닫았다 다시 연다; 다른 프로필 값 유지',()async{
 final dir=Directory.systemTemp.createTempSync('doobal_look_');addTearDown(()=>dir.deleteSync(recursive:true));final file=File('${dir.path}/game.sqlite');
 var db=AppDb(NativeDatabase(file));var svc=ProfileService(db);await svc.confirmAge(DateTime.utc(2026,11,12));await svc.saveMe('원래 닉네임',Look.initial);
 final old=await svc.row();
 for(final p in unifiedProps){await db.into(db.propsOwned).insertOnConflictUpdate(PropsOwnedCompanion(propId:Value(p.id),unlockedUtc:const Value(123)));}
 var look=Look.initial.copyWith(body:const CustomBodyColor('#8CBBD0'));
 for(final p in unifiedProps){look=look.withPropColor(p.id,'#D276A0').withSlot(p.slot,p.id);}
 await svc.saveLook(look);await db.close();
 db=AppDb(NativeDatabase(file));svc=ProfileService(db);final restored=(await svc.me()).look;expect(restored,look);expect(restored.propColors.length,37);
 final row=await svc.row();expect(row!.nickname,old!.nickname);expect(row.installId,old.installId);expect(row.ageConfirmedAt,old.ageConfirmedAt);
 final mapped=spiritLookOf(restored,bodyArgb:0xff8cbbd0);expect(mapped.colors.values,everyElement(0xffd276a0));expect(mapped.choices,{'hat':4,'face':3,'cloth':5,'shoe':5,'hand':5,'bag':5,'pet':5,'float':5});
 await db.close();
 });
 test('옛 모습 JSON은 새 색 항목 없이 읽고, 파손된 색 하나가 기존 모습을 지우지 않는다',(){
 final old=Look.initial.toJson();expect(Look.fromJson(old),Look.initial);
 final read=Look.fromJson({...old,'propColors':{'hat_01':'#aabbcc','shoe_05':'wrong','unknown':'#ffffff'}});
 expect(read.propColors,{'hat_01':'#AABBCC'});expect(read.slots,Look.initial.slots);
 });
 test('옷·몸·다른 소품을 바꿔도 벗은 소품의 색을 기억한다',(){
 final a=Look.initial.withPropColor('hat_01','#D276A0').withSlot('hat',null).copyWith(body:const CustomBodyColor('#8CBBD0')).withSlot('hat','hat_01');
 expect(a.propColors['hat_01'],'#D276A0');expect(Look.fromJson(a.toJson()),a);
 });
}
