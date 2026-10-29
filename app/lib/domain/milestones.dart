/// 총 걸음보다 큰 첫 방명록 걸음 숫자. 마지막 숫자를 넘었으면 null.
/// milestones는 오름차순(milestones.json의 stepMilestones)
int? nextMilestone(int totalSteps, List<int> milestones) {
  for (final m in milestones) {
    if (m > totalSteps) return m;
  }
  return null;
}
