import 'dart:io';
import 'dart:convert';
import 'package:doobal/domain/look.dart';
import 'package:doobal/domain/face_parts.dart';
import 'package:doobal/domain/spirit_look.dart';
import 'package:doobal/app/profile_service.dart';
import 'package:doobal/data/db/app_db.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
void main(){
 test('기존 모든 얼굴 id는 대응표로 읽고 슬롯·몸·소품 색을 잃지 않는다',(){
  for(final entry in legacyFaceAliases.entries){
   for(final alias in entry.value.entries){
    final raw=Look.initial.withPropColor('hat_01','#D276A0').toJson();raw[entry.key]=alias.key;
    final l=Look.fromJson(raw);expect(l.toJson()[entry.key],alias.value);expect(l.slots,Look.initial.slots);expect(l.propColors['hat_01'],'#D276A0');
   }
  }
  const old=Look(eyes:'cat',brows:'shiba',nose:'shy',mouth:'smirk');final read=Look.fromJson(old.toJson());expect(read,old);expect(read.hashCode,old.hashCode);
 });
 test('새 얼굴 조합을 게임 파일DB에 저장하고 닫았다 다시 연다',()async{
  final dir=Directory.systemTemp.createTempSync('face_save_');addTearDown(()=>dir.deleteSync(recursive:true));final file=File('${dir.path}/profile.sqlite');var db=AppDb(NativeDatabase(file));var svc=ProfileService(db);
  var look=Look.initial.copyWith(eyes:'sparkle',brows:'handsome',nose:'none',mouth:'fangs',body:const CustomBodyColor('#8CBBD0')).withPropColor('hat_01','#D276A0');
  await svc.saveMe('원래 이름',Look.initial);await svc.saveLook(look);await db.close();db=AppDb(NativeDatabase(file));svc=ProfileService(db);final me=await svc.me();expect(me.nickname,'원래 이름');expect(me.look,look);expect(spiritLookOf(me.look).eye,5);expect(spiritLookOf(me.look).brow,6);expect(spiritLookOf(me.look).nose,7);expect(spiritLookOf(me.look).mouth,2);await db.close();
 });
 test('원본 PSD 목록 수와 기본 얼굴 값, 소품색 입력은 분리된다',(){
  expect([eyeParts.length,browParts.length,noseParts.length,mouthParts.length],[6,7,8,8]);final s=spiritLookOf(Look.initial);expect([s.eye,s.brow,s.nose,s.mouth],[0,1,6,6]);expect(s.colors.length,37);expect(Look.fromJson(jsonDecode(jsonEncode(Look.initial.toJson()))),Look.initial);
 });
}
