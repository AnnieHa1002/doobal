import 'package:flutter/material.dart';

import '../../domain/landmark.dart';
import '../common/format.dart';
import '../common/palette.dart';

/// 검색 칸 (높이 44pt, 카드색 + 잉크 테두리)
class MapSearchField extends StatelessWidget {
  const MapSearchField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onChanged,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      // 44pt가 최소 높이다. 글자 크기를 키우면 입력 줄이 커져서 칸도 같이 커진다
      constraints: const BoxConstraints(minHeight: 44),
      padding: const EdgeInsets.only(left: 12),
      decoration: BoxDecoration(
        color: Palette.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Palette.ink, width: 2.5),
      ),
      child: Row(
        children: [
          const Icon(Icons.search, size: 20, color: Palette.subInk),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              onChanged: onChanged,
              textInputAction: TextInputAction.search,
              style: const TextStyle(fontSize: 16, color: Palette.ink),
              decoration: const InputDecoration(
                hintText: '명소 이름 검색',
                hintStyle: TextStyle(fontSize: 16, color: Palette.subInk),
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
          // 지우기: 글자가 있을 때만
          ListenableBuilder(
            listenable: controller,
            builder: (context, _) => controller.text.isEmpty
                ? const SizedBox(width: 12)
                : IconButton(
                    // 칸이 최소 높이만 정해 두므로 지우기 버튼이 칸을 키우지 않게 (넓이 48, 높이 39)
                    constraints: const BoxConstraints(minWidth: 48, minHeight: 39),
                    icon: const Icon(Icons.close, size: 18, color: Palette.subInk),
                    onPressed: () {
                      controller.clear();
                      onChanged('');
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// 검색 결과 카드 목록. 한 줄이 48pt
class SearchResults extends StatelessWidget {
  const SearchResults({super.key, required this.results, required this.onPick});

  final List<Landmark> results;
  final ValueChanged<Landmark> onPick;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Palette.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Palette.ink, width: 2.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final l in results)
            InkWell(
              key: ValueKey('result-${l.id}'),
              onTap: () => onPick(l),
              child: Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                alignment: Alignment.centerLeft,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        l.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Palette.ink,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(l.sido, style: const TextStyle(fontSize: 12, color: Palette.subInk)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 권역 7개 칩 한 줄: `경상 4/31`. 누르면 [onTap]에 권역 키(capital …)를 준다
class RegionChips extends StatelessWidget {
  const RegionChips({super.key, required this.progress, required this.onTap});

  final Map<String, ({int visited, int total})> progress;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          for (final e in regionLabels.entries) ...[
            _Chip(
              key: ValueKey('chip-${e.key}'),
              label: '${e.value} ${progress[e.key]?.visited ?? 0}/${progress[e.key]?.total ?? 0}',
              onTap: () => onTap(e.key),
            ),
            if (e.key != regionLabels.keys.last) const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // 누르는 자리는 44pt, 눈에 보이는 칩은 36pt
    return Semantics(
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          height: 44,
          child: Center(
            child: Container(
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Palette.card,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Palette.ink, width: 2),
              ),
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Palette.ink,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
