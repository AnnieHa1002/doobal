import 'dart:convert';
import 'dart:io';

import 'package:doobal/data/firebase_backend.dart' show serverModeName;
import 'package:doobal/data/server_options.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

// 시험용 가짜 값 (키 꼴이 아니다)
const _android = {
  SecretKeys.projectId: 'test-project',
  SecretKeys.senderId: '1234567890',
  SecretKeys.androidKey: 'TestOnlyAndroidKey',
  SecretKeys.androidAppId: '1:1234567890:android:abc',
};
const _ios = {
  SecretKeys.projectId: 'test-project',
  SecretKeys.senderId: '1234567890',
  SecretKeys.iosKey: 'TestOnlyIosKey',
  SecretKeys.iosAppId: '1:1234567890:ios:abc',
  SecretKeys.iosClientId: 'test-ios.apps.googleusercontent.com',
};

ServerPlan _plan(
  String mode,
  Map<String, String> values, {
  TargetPlatform platform = TargetPlatform.android,
  bool release = false,
}) =>
    planServer(modeName: mode, values: values, platform: platform, release: release);

void main() {
  group('DOOBAL_SERVER', () {
    test('off는 값이 다 있어도 서버 없이', () {
      final p = _plan('off', _android);
      expect(p.mode, ServerMode.off);
      expect(p.options, isNull);
      expect(p.reason, 'DOOBAL_SERVER=off');
    });

    test('emulator는 디버그 빌드에서 demo-doobal 가짜 옵션, 실제 값은 보지 않는다', () {
      final p = _plan('emulator', _android);
      expect(p.mode, ServerMode.emulator);
      expect(p.options!.projectId, emulatorProject);
      expect(p.options!.apiKey, isNot(_android[SecretKeys.androidKey]));
      expect(_plan('emulator', const {}).mode, ServerMode.emulator);
    });

    test('emulator는 출시 빌드에서 듣지 않는다', () {
      final p = _plan('emulator', _android, release: true);
      expect(p.mode, ServerMode.off);
      expect(p.reason, contains('출시'));
    });

    test('모르는 이름은 서버 없이', () {
      final p = _plan('prod', _android);
      expect(p.mode, ServerMode.off);
      expect(p.reason, contains('prod'));
    });

    test('기본은 real이고, 값을 주지 않은 빌드(시험)는 서버 없이', () {
      expect(serverModeName, 'real');
      expect(buildSecrets.values.every((v) => v.isEmpty), isTrue);
      final p = _plan(serverModeName, buildSecrets);
      expect(p.mode, ServerMode.off);
      expect(p.reason, contains(SecretKeys.androidKey));
    });
  });

  group('real 안드로이드', () {
    test('값이 다 있으면 그 값으로 옵션', () {
      for (final release in [false, true]) {
        final p = _plan('real', _android, release: release);
        expect(p.mode, ServerMode.real);
        expect(p.reason, isNull);
        final o = p.options!;
        expect(o.projectId, 'test-project');
        expect(o.messagingSenderId, '1234567890');
        expect(o.apiKey, 'TestOnlyAndroidKey');
        expect(o.appId, '1:1234567890:android:abc');
        expect(o.iosBundleId, isNull);
      }
    });

    test('하나라도 빠지면 서버 없이, 까닭에는 키 이름만', () {
      for (final key in SecretKeys.android) {
        final values = Map.of(_android)..remove(key);
        final p = _plan('real', values);
        expect(p.mode, ServerMode.off, reason: key);
        expect(p.options, isNull);
        expect(p.reason, contains(key));
        for (final v in values.values) {
          expect(p.reason, isNot(contains(v)), reason: '값이 로그에 남지 않게');
        }
      }
    });

    test('빈칸·공백도 빠진 것으로', () {
      expect(_plan('real', {..._android, SecretKeys.androidKey: ''}).mode, ServerMode.off);
      expect(_plan('real', {..._android, SecretKeys.androidAppId: '  '}).mode, ServerMode.off);
    });

    test('앞뒤 공백은 떼고 쓴다', () {
      final p = _plan('real', {..._android, SecretKeys.projectId: ' test-project\n'});
      expect(p.options!.projectId, 'test-project');
    });

    test('견본 값(Fake…)이면 서버 없이', () {
      final p = _plan('real', {..._android, SecretKeys.androidKey: 'Fake: 비밀번호 관리자에서 복사'});
      expect(p.mode, ServerMode.off);
      expect(p.reason, contains(SecretKeys.androidKey));
    });

    test('구글 웹 클라이언트 id·App Check 디버그 토큰은 없어도 켠다', () {
      expect(_plan('real', _android).mode, ServerMode.real);
      expect(
        _plan('real', {
          ..._android,
          SecretKeys.googleServerClientId: 'test-web.apps.googleusercontent.com',
          SecretKeys.appCheckDebug: 'test-debug',
        }).mode,
        ServerMode.real,
      );
    });

    test('iOS 값만 있으면 안드로이드는 서버 없이', () {
      final p = _plan('real', _ios);
      expect(p.mode, ServerMode.off);
      expect(p.reason, contains(SecretKeys.androidKey));
      expect(p.reason, contains(SecretKeys.androidAppId));
      expect(p.reason, isNot(contains(SecretKeys.projectId)));
    });
  });

  group('real iOS (11/28 뒤 값을 채움)', () {
    test('값이 다 있으면 iOS 옵션 + 번들 ID·클라이언트 id', () {
      final p = _plan('real', _ios, platform: TargetPlatform.iOS);
      expect(p.mode, ServerMode.real);
      final o = p.options!;
      expect(o.apiKey, 'TestOnlyIosKey');
      expect(o.appId, '1:1234567890:ios:abc');
      expect(o.iosBundleId, iosBundleId);
      expect(o.iosClientId, 'test-ios.apps.googleusercontent.com');
    });

    test('클라이언트 id는 없어도 켠다 (구글 연결만 준비 중)', () {
      final values = Map.of(_ios)..remove(SecretKeys.iosClientId);
      final p = _plan('real', values, platform: TargetPlatform.iOS);
      expect(p.mode, ServerMode.real);
      expect(p.options!.iosClientId, isNull);
    });

    test('하나라도 빠지면 서버 없이', () {
      for (final key in SecretKeys.ios) {
        final values = Map.of(_ios)..remove(key);
        final p = _plan('real', values, platform: TargetPlatform.iOS);
        expect(p.mode, ServerMode.off, reason: key);
        expect(p.reason, contains(key));
      }
    });

    test('안드로이드 값만 있으면 iOS는 서버 없이', () {
      final p = _plan('real', _android, platform: TargetPlatform.iOS);
      expect(p.mode, ServerMode.off);
      expect(p.reason, contains(SecretKeys.iosKey));
    });
  });

  test('안드로이드·iOS 밖 플랫폼은 서버 없이', () {
    final p = _plan('real', {..._android, ..._ios}, platform: TargetPlatform.macOS);
    expect(p.mode, ServerMode.off);
    expect(p.reason, contains('macOS'));
  });

  test('견본 secrets.json.example: 키가 코드와 같고 값은 모두 Fake라 real이 켜지지 않는다', () {
    final example = (jsonDecode(File('secrets.json.example').readAsStringSync()) as Map)
        .cast<String, String>();
    expect(example.keys.toSet(), buildSecrets.keys.toSet());
    expect(example.values.every((v) => v.startsWith('Fake')), isTrue);
    for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
      expect(_plan('real', example, platform: platform).mode, ServerMode.off);
    }
  });
}
