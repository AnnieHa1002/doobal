import 'package:doobal/domain/wall.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('벽은 4칸', () {
    expect(wallSlots, 4);
  });

  group('wallFromSlots', () {
    test('행이 없는 칸은 null, 늘 4칸', () {
      expect(wallFromSlots(const {}), [null, null, null, null]);
      expect(wallFromSlots(const {0: 'a', 2: 'c'}), ['a', null, 'c', null]);
    });

    test('범위 밖 칸은 버린다', () {
      expect(wallFromSlots(const {1: 'b', 4: 'x', -1: 'y'}), [null, 'b', null, null]);
    });
  });

  group('placeOnWall', () {
    test('빈 칸에 건다', () {
      expect(placeOnWall([null, null, null, null], 2, 'a'), [null, null, 'a', null]);
    });

    test('다른 그림이 있던 칸에 걸면 그 그림은 벽에서 내려간다', () {
      expect(placeOnWall(['a', 'b', null, null], 1, 'c'), ['a', 'c', null, null]);
    });

    test('이미 다른 칸에 걸린 그림은 옮겨진다 (원래 칸은 빈다)', () {
      expect(placeOnWall(['a', 'b', null, null], 3, 'a'), [null, 'b', null, 'a']);
    });

    test('옮긴 칸에 다른 그림이 있었으면 그 그림은 내려가고 원래 칸은 빈다', () {
      expect(placeOnWall(['a', 'b', 'c', null], 2, 'a'), [null, 'b', 'a', null]);
    });

    test('같은 칸에 같은 그림은 그대로', () {
      expect(placeOnWall(['a', 'b', null, null], 0, 'a'), ['a', 'b', null, null]);
    });

    test('받은 목록을 바꾸지 않는다', () {
      final wall = <String?>['a', null, null, null];
      placeOnWall(wall, 2, 'a');
      expect(wall, ['a', null, null, null]);
    });

    test('칸 번호가 0~3이 아니면 RangeError', () {
      expect(() => placeOnWall([null, null, null, null], 4, 'a'), throwsRangeError);
      expect(() => placeOnWall([null, null, null, null], -1, 'a'), throwsRangeError);
    });
  });

  group('slotToHang', () {
    test('첫 빈 칸', () {
      expect(slotToHang([null, null, null, null], 'a'), 0);
      expect(slotToHang(['x', null, 'y', null], 'a'), 1);
      expect(slotToHang(['x', 'y', 'z', null], 'a'), 3);
    });

    test('이미 걸려 있으면 그 칸 (빈 칸이 앞에 있어도)', () {
      expect(slotToHang([null, 'a', null, null], 'a'), 1);
      expect(slotToHang(['x', 'y', 'z', 'a'], 'a'), 3);
    });

    test('벽이 가득 차고 없는 그림이면 null', () {
      expect(slotToHang(['w', 'x', 'y', 'z'], 'a'), isNull);
    });
  });
}
