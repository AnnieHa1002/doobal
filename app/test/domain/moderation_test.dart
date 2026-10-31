import 'package:doobal/domain/moderation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:korean_profanity_filter/korean_profanity_filter.dart';

import 'helpers.dart';

/// 명소 이름이 문장 속에 들어간 모습들 (앞뒤 글자 때문에 패키지가 잘못 잡는지 본다)
Iterable<String> _sentences(String name) sync* {
  for (final p in ['', '오늘 ', '드디어 ', '와 ']) {
    for (final s in ['', '!', ' 최고', '에서 걸었어요', '에 다녀왔어요.', ' 너무 좋아요 ㅎㅎ', '의 풍경이 멋져요']) {
      yield '$p$name$s';
    }
  }
}

void main() {
  group('욕설 (korean_profanity_filter)', () {
    test('대표 욕설과 초성 줄임이 걸린다', () {
      for (final t in ['시발', '씨발', 'ㅅㅂ', 'ㅂㅅ', '병신', '개새끼', '좆', '지랄', '존나 좋다']) {
        expect(isBlocked(t), isTrue, reason: t);
      }
    });

    test('문장 속에 섞여 있어도 걸린다', () {
      for (final t in ['오늘 진짜 시발 날씨', '와 ㅅㅂ 대박', '길이 병신 같아요', '경복궁 ㅅㅂ']) {
        expect(isBlocked(t), isTrue, reason: t);
      }
    });

    test('일반 문장은 안 걸린다', () {
      for (final t in [
        '',
        '안녕하세요 걷기 좋은 날이에요',
        '경복궁에 다녀왔어요',
        '멋진 풍경이에요 감사합니다',
        '두발 최고',
        'ㅋㅋㅋㅋ',
        '충주호 좋았어요',
        '오늘 5시 발걸음이 가벼웠다',
        '지금 몇 시 바람이 분다',
        '새끼 고양이를 만났어요',
        '탐색기',
        '😀😀😀',
        'Beautiful view!',
      ]) {
        expect(isBlocked(t), isFalse, reason: t);
      }
    });

    test('욕설은 패키지 containsBadWords와 같은 답이다 (추가 목록·허용 목록이 없을 때)', () {
      for (final t in ['시발', '안녕', '병신 같은', '새끼 고양이', 'ㅗ']) {
        expect(isBlocked(t), t.containsBadWords, reason: t);
      }
    });

    test('알려진 한계: 패키지가 못 잡는 표기 (공백을 낀 것, ㅈㄹ, 꺼져)', () {
      // 글을 그대로 검사하므로 공백을 끼운 표기는 지나간다. 공백을 지워 붙이면 "5시 발걸음" 같은
      // 멀쩡한 글이 걸려서 그렇게 하지 않는다. 이 목록이 줄면 (패키지가 좋아지면) 이 테스트를 고친다
      for (final t in ['시 발', 'ㅈㄹ', '꺼져']) {
        expect(isBlocked(t), isFalse, reason: t);
      }
    });
  });

  group('명소 이름 101곳', () {
    test('명소는 101곳이다', () => expect(landmarks, hasLength(101)));

    test('허용 목록이 없어도 패키지가 걸지 않는다 (이름만, 그리고 문장 속에서)', () {
      final blocked = <String>[];
      for (final l in landmarks) {
        for (final t in _sentences(l.name)) {
          if (isBlocked(t)) blocked.add(t);
        }
      }
      expect(blocked, isEmpty);
    });

    test('허용 목록에 넣어도 걸리지 않는다', () {
      final names = [for (final l in landmarks) l.name];
      for (final l in landmarks) {
        for (final t in _sentences(l.name)) {
          expect(isBlocked(t, allowedNames: names), isFalse, reason: t);
        }
      }
    });
  });

  group('허용 목록', () {
    test('패키지가 잘못 잡는 낱말("시발점")도 허용 이름이면 통과한다', () {
      expect(isBlocked('시발점'), isTrue);
      expect(isBlocked('시발점', allowedNames: ['시발점']), isFalse);
      expect(isBlocked('시발점에서 출발해요', allowedNames: ['시발점']), isFalse);
    });

    test('허용 이름 옆의 욕설은 여전히 걸린다', () {
      expect(isBlocked('시발점 시발', allowedNames: ['시발점']), isTrue);
      expect(isBlocked('시발점 ㅅㅂ', allowedNames: ['시발점']), isTrue);
    });

    test('이름이 겹치면 긴 이름부터 뺀다', () {
      expect(isBlocked('서울시발점', allowedNames: ['서울', '서울시발점']), isFalse);
      expect(isBlocked('서울시발점', allowedNames: ['서울시발점', '서울']), isFalse);
    });

    test('빈 이름은 무시하고, 글에 없는 이름은 아무 일도 안 한다', () {
      expect(isBlocked('시발', allowedNames: ['', '경복궁']), isTrue);
      expect(isBlocked('안녕', allowedNames: ['']), isFalse);
    });

    test('이름을 뺀 자리는 공백이라 앞뒤 글자가 이어져 새 욕설이 되지 않는다', () {
      // '시' + 이름 + '발'이 '시발'로 붙어 걸리면 안 된다
      expect(isBlocked('시경복궁발', allowedNames: ['경복궁']), isFalse);
    });
  });

  group('혐오·성적 표현 추가 목록 (extraWords)', () {
    test('시작 목록은 아직 비어 있다 (기획/방명록_금칙어.md v02가 리포에 들어오면 채운다)', () {
      expect(starterWords, isEmpty);
    });

    test('공백·특수문자를 뺀 글에 부분 일치로 본다', () {
      const extra = ['나쁜말'];
      for (final t in ['나쁜말', '나 쁜 말', '나쁜.말', '나-쁜_말', '그건 나쁜말이야', '고양이 나 쁜 말 하지마']) {
        expect(isBlocked(t, extraWords: extra), isTrue, reason: t);
      }
      for (final t in ['나쁜 소리', '나는 말했다', '']) {
        expect(isBlocked(t, extraWords: extra), isFalse, reason: t);
      }
    });

    test('추가 낱말도 같은 규칙으로 다듬는다 (소문자, 공백·특수문자 제거)', () {
      expect(isBlocked('BADWORD', extraWords: ['bad word']), isTrue);
      expect(isBlocked('b-a-d w.o.r.d', extraWords: ['Bad Word']), isTrue);
    });

    test('다듬으면 빈 낱말은 모든 글에 들어 있는 것이 되지 않게 건너뛴다', () {
      expect(isBlocked('안녕하세요', extraWords: ['', '  ', '-.-']), isFalse);
    });

    test('추가 목록이 없으면 욕설 검사만 한다', () {
      expect(isBlocked('시발', extraWords: const []), isTrue);
      expect(isBlocked('안녕', extraWords: const []), isFalse);
    });
  });

  group('normalizeForModeration', () {
    test('소문자로 바꾸고 글자·숫자가 아닌 것을 뺀다', () {
      expect(normalizeForModeration('A b-C. 1_2 가 나!'), 'abc12가나');
      expect(normalizeForModeration('ㅅ ㅂ'), 'ㅅㅂ');
      expect(normalizeForModeration(' \n\t'), '');
    });
  });

  test('안내 문구는 어떤 단어인지 말하지 않는다', () {
    expect(blockedMessage, '이 표현은 방명록에 남길 수 없어요');
  });
}
