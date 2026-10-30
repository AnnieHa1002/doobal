import 'package:doobal/domain/guestbook.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  test('config: 글 200자, 걸음 숫자 기회는 500보', () {
    expect(rules.guestbookMaxChars, 200);
    expect(rules.guestbookWindowSteps, 500);
  });

  group('기회 id·scope', () {
    test('도착은 여정마다, 걸음 숫자는 숫자마다 하나', () {
      expect(arrivalTicketId('j123'), 'a:j123');
      expect(milestoneTicketId(12345), 'm:12345');
      expect(milestoneScope(12345), 'steps:12345');
    });

    test('milestoneOfScope: 걸음 scope만 숫자로, 나머지는 null', () {
      expect(milestoneOfScope('steps:12345'), 12345);
      expect(milestoneOfScope('steps:100'), 100);
      expect(milestoneOfScope('kr001'), isNull);
      expect(milestoneOfScope('sketch'), isNull);
      expect(milestoneOfScope('steps:abc'), isNull);
    });
  });

  group('milestonesReached', () {
    test('걸음이 숫자와 같으면 달성 (경계)', () {
      expect(milestonesReached(0, milestones), isEmpty);
      expect(milestonesReached(99, milestones), isEmpty);
      expect(milestonesReached(100, milestones), [100]);
      expect(milestonesReached(999, milestones), [100]);
      expect(milestonesReached(1000, milestones), [100, 1000]);
    });

    test('한 번에 여러 개를 넘으면 모두, 오름차순', () {
      expect(milestonesReached(7777, milestones), [100, 1000, 5000, 7777]);
      expect(milestonesReached(12345, milestones), [100, 1000, 5000, 7777, 10000, 12345]);
    });

    test('마지막 숫자를 넘으면 23개 전부', () {
      expect(milestonesReached(1234567, milestones), milestones);
      expect(milestonesReached(5000000, milestones), hasLength(23));
    });

    test('목록이 비어 있으면 없다', () {
      expect(milestonesReached(100000, const []), isEmpty);
    });
  });

  group('stepsLeft', () {
    test('열린 직후는 창 전체, 걸은 만큼 줄고 0에서 멈춘다', () {
      expect(stepsLeft(500, 0), 500);
      expect(stepsLeft(500, 123), 377);
      expect(stepsLeft(500, 499), 1);
      expect(stepsLeft(500, 500), 0);
      expect(stepsLeft(500, 501), 0);
      expect(stepsLeft(500, 100000), 0);
    });
  });

  group('글 검사', () {
    final max = rules.guestbookMaxChars;

    test('0자와 공백만 있는 글은 못 쓴다', () {
      expect(cleanPost('', max), isNull);
      expect(cleanPost('   ', max), isNull);
      expect(cleanPost(' \n\t \n', max), isNull);
    });

    test('앞뒤 공백은 자르고 가운데는 둔다', () {
      expect(cleanPost('  안녕 하세요 \n', max), '안녕 하세요');
      expect(cleanPost('가', max), '가');
    });

    test('200자는 되고 201자는 안 된다', () {
      expect(cleanPost('가' * 200, max), '가' * 200);
      expect(cleanPost('가' * 201, max), isNull);
    });

    test('길이는 공백을 자른 뒤로 센다: 공백 포함 201자라도 자르면 200자면 된다', () {
      expect(cleanPost(' ${'가' * 200}', max), '가' * 200);
      expect(cleanPost('${'가' * 200} ', max), '가' * 200);
      expect(cleanPost(' ${'가' * 201} ', max), isNull);
    });

    test('길이는 글자(rune) 수: 이모지 하나는 한 글자', () {
      expect(postLength('가나다'), 3);
      expect(postLength('😀'), 1);
      expect('😀'.length, 2); // UTF-16 코드 단위로는 2
      expect(cleanPost('😀' * 200, max), '😀' * 200);
      expect(cleanPost('😀' * 201, max), isNull);
    });

    test('clipPost: 상한 안은 그대로, 넘으면 앞에서 자른다 (이모지를 쪼개지 않는다)', () {
      expect(clipPost('가나다', 5), '가나다');
      expect(clipPost('가나다라마', 5), '가나다라마');
      expect(clipPost('가나다라마바', 5), '가나다라마');
      expect(clipPost('😀😀😀', 2), '😀😀');
      expect(clipPost('', 5), '');
    });
  });
}
