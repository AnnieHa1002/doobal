/// 앱에 든 파일 목록. 코드에 그림 경로를 적지 않고 파일이 있는지 보고 찾는다.
/// 그림이 오면 정해진 폴더에 파일만 넣으면 된다
class AssetIndex {
  AssetIndex(Iterable<String> paths) : _paths = paths.toList(growable: false);

  /// 칸 그림 폴더 (pubspec에 등록). 소품·상품 아이콘은 여기에 넣는다
  static const iconDir = 'assets/items/icons/';

  /// 그 밖의 소품 묶음 폴더. 여기 파일은 이름에 `_icon`이 있어야 아이콘이다 (입는 조각과 섞여 있다)
  static const _itemsDir = 'assets/items/';

  /// 럭 보석 (Drive `ui_gem_sky_v01_clean`)
  static const _gemDir = 'assets/ui/';
  static const _gemStem = 'ui_gem_sky';

  final List<String> _paths;
  final _icons = <String, String?>{};
  late final Set<String> _set = _paths.toSet();

  bool has(String path) => _set.contains(path);

  /// 상품·소품 [id]의 칸 그림. 없으면 null.
  /// 아이콘 폴더에서는 `item_hat_02_icon_v01_clean.webp`·`ui_shop_fx_shortcut_v01_clean.png`처럼 이름에 id가 있으면 되고,
  /// 아이콘 폴더에 없으면 다른 소품 묶음의 `*_<id>_icon*`을 쓴다
  String? itemIcon(String id) => _icons.putIfAbsent(id, () {
        final name = RegExp.escape(id);
        final inIcons = RegExp('(^|_)$name(_icon)?(_v\\d+)?(_clean)?\\.(webp|png)\$');
        final elsewhere = RegExp('(^|_)${name}_icon(_v\\d+)?(_clean)?\\.(webp|png)\$');
        return _best(iconDir, inIcons) ?? _best(_itemsDir, elsewhere);
      });

  /// 럭 보석 그림. 버전이 올라도 그대로 찾는다
  String? get gem => _best(_gemDir, RegExp('^$_gemStem(_v\\d+)?(_clean)?\\.(webp|png)\$'));

  /// [dir] 안의 [pngName] 파일. 같은 이름의 WebP를 먼저 본다
  String? file(String dir, String pngName) {
    final webp = '$dir/${pngName.replaceAll('.png', '.webp')}';
    if (has(webp)) return webp;
    final png = '$dir/$pngName';
    return has(png) ? png : null;
  }

  /// [dir] 아래에서 파일 이름이 [name]에 맞는 것 중 WebP를 먼저, 그다음 이름이 뒤인 것(새 버전)
  String? _best(String dir, RegExp name) {
    String? best;
    for (final p in _paths) {
      if (!p.startsWith(dir) || !name.hasMatch(p.substring(p.lastIndexOf('/') + 1))) continue;
      if (best == null || _rank(p).compareTo(_rank(best)) > 0) best = p;
    }
    return best;
  }

  static String _rank(String path) =>
      '${path.endsWith('.webp') ? 1 : 0}${path.substring(path.lastIndexOf('/') + 1)}';
}
