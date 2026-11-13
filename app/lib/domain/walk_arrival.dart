/// 센서 미리보기가 목적지에 닿았는가: health 동기화 값에 아직 안 들어간 걸음 거리
/// ([extraM] = 센서 걸음이 만든 거리 − 동기화된 이번 걷기 거리)가 남은 거리 [remainingKm] 이상이면 true.
/// 닿았다는 건 '동기화를 지금 돌려 보라'는 신호일 뿐이다: 도착은 늘 동기화가 정한다 (M1).
/// 배 구간은 같은 걸음이 더 멀리 가므로 이 판정이 늦을 뿐 틀리지는 않는다 (보수적)
bool previewReachesDest({required double remainingKm, required double extraM}) =>
    extraM > 0 && extraM / 1000 >= remainingKm;

/// 도착 확인 동기화를 지금 돌려도 되는가: 마지막으로 돌린 뒤 [minSec]초가 지났으면 true.
/// 미리보기가 100%를 넘은 채 동기화가 도착을 안 정해 주는 동안 매 프레임 동기화하지 않게 한다
bool arrivalProbeDue(DateTime? last, DateTime now, int minSec) =>
    last == null || now.difference(last) >= Duration(seconds: minSec);
