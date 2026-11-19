#!/bin/zsh
# main에 올릴 커밋 그대로 임시 워크트리에서 전체 시험을 돌린다 (통합 세션, 11/19 스크래치에서 옮김).
# 쓰는 법: zsh tools/verify_tree.sh <통합 워크트리> <임시 폴더> [커밋, 기본 dev-batch]
# 비밀 값 검사(origin/main..HEAD) → analyze → 핵심 시험 → UI 시험 파일마다 따로(화면 꺼진 Mac에서 한 번에 돌리면 Rive가 멈춤).
# 결과 줄: 커밋·미커밋·비밀 값·analyze·핵심 통과/실패·UI 통과/실패. 끝나면 `git worktree remove --force <임시 폴더>/verify`
I=$1
S=$2
C=${3:-dev-batch}
T=${0:A:h}
V="$S/verify"
git -C "$I" worktree add -q --detach "$V" "$C" || exit 1
cd "$V/app" || exit 1
echo "커밋 $(git rev-parse --short HEAD)"
git status --short | wc -l | tr -d ' ' | sed 's/^/미커밋 /'
python3 -I ../tools/check_secrets.py --range origin/main..HEAD | head -5
# rive_native 시험 라이브러리는 무시 목록이라 통합 워크트리 빌드에서 복사한다
mkdir -p build/rive_native/native/build/macosx/bin/debug_shared
cp "$I/app/build/rive_native/native/build/macosx/bin/debug_shared/librive_native.dylib" build/rive_native/native/build/macosx/bin/debug_shared/
flutter pub get --offline > /dev/null 2>&1 || flutter pub get > /dev/null 2>&1
flutter analyze 2>&1 | tail -1 | cut -c1-100
flutter test --no-pub --timeout 120s test/domain test/app test/data test/widget_test.dart > "$S/final_core.log" 2>&1
python3 -I "$T/sum_test_log.py" core "$S/final_core.log"
: > "$S/final_ui.log"
for f in test/ui/*_test.dart; do
  flutter test --no-pub --timeout 120s "$f" > "$S/verify_one.log" 2>&1
  python3 -I "$T/sum_test_log.py" one "$S/verify_one.log" "$f" "$S/final_ui.log"
done
python3 -I "$T/sum_test_log.py" ui "$S/final_ui.log"
