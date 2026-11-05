import 'dart:math' as math;

import 'camp_theme.dart';
import 'rules.dart';

/// 쉼터 장면을 어디까지 밀고 얼마나 확대했나. [x]는 장면 왼쪽 끝의 화면 x(pt, 0 = 처음 화면, 음수 = 오른쪽으로 민 것)
class RestCamera {
  const RestCamera({this.x = 0, this.zoom = 1});

  final double x;
  final double zoom;

  @override
  bool operator ==(Object other) => other is RestCamera && other.x == x && other.zoom == zoom;

  @override
  int get hashCode => Object.hash(x, zoom);

  @override
  String toString() => 'RestCamera($x, $zoom)';
}

/// 쉼터 좌표 계산: 장면 pt ↔ 기기 pt, 밀기·확대 경계. 그리는 쪽과 시험이 함께 쓴다.
/// 장면은 화면 아래 기준이라 키 작은 폰은 하늘 위쪽이 잘린다
class RestGeometry {
  RestGeometry(this.theme, this.rules, this.width, this.height)
      : k = theme.scaleFor(width, height);

  final CampTheme theme;
  final RestRules rules;

  /// 화면 크기 (기기 pt)
  final double width;
  final double height;

  /// 기기 pt ÷ 장면 pt
  final double k;

  /// 확대 전 장면 폭 (기기 pt)
  double get sceneWidth => theme.widthPt * k;

  /// 장면 pt x → 확대·밀기 전 기기 x
  double sx(double x) => x * k;

  /// 장면 pt y → 확대 전 기기 y (아래 기준)
  double sy(double y) => height - (theme.refH - y) * k;

  /// 원경이 보일 수 있는 가장 넓은 폭 (기기 pt). 처음 배율에서 오른쪽 끝까지 밀었을 때다
  double get farWidth => width + (sceneWidth - width) * rules.farParallax;

  /// 이 배율에서 밀 수 있는 왼쪽 끝. 장면이 화면보다 좁으면 0
  double minX(double zoom) => math.min(0, width - sceneWidth * zoom);

  double clampZoom(double zoom) => zoom.clamp(rules.zoomMin, rules.zoomMax);

  RestCamera clamp(RestCamera c) {
    final zoom = clampZoom(c.zoom);
    return RestCamera(x: c.x.clamp(minX(zoom), 0.0), zoom: zoom);
  }

  /// 손가락 제스처: [start]에서 시작해 초점이 [fromX]에서 [toX]로 옮겨 가고 배율이 [scale]배가 됐다.
  /// 한 손가락은 scale 1이라 그냥 밀기다. 초점 아래의 장면 지점이 손가락을 따라간다
  RestCamera gesture(RestCamera start, {double scale = 1, required double fromX, required double toX}) {
    final zoom = clampZoom(start.zoom * scale);
    return clamp(RestCamera(x: toX - (fromX - start.x) * (zoom / start.zoom), zoom: zoom));
  }

  /// 손을 뗀 뒤 자리: 확대 중이면 그대로, 아니면 가까운 끝으로 붙는다 (config rest.drag·rest.zoom)
  RestCamera settle(RestCamera c) {
    final at = clamp(c);
    final zoomed = at.zoom > rules.zoomMin + _zoomEpsilon;
    if (zoomed && !rules.snapEdgesWhenZoomed) return at;
    if (!rules.snapToEnds) return at;
    final zoom = zoomed ? at.zoom : rules.zoomMin;
    final end = minX(zoom);
    return RestCamera(x: at.x < end / 2 ? end : 0, zoom: zoom);
  }

  /// 원경 층의 화면 x
  double farX(RestCamera c) => c.x * rules.farParallax;

  /// 확대 때 위로 밀려 올라가는 만큼 (아래 기준)
  double liftY(RestCamera c) => height * (1 - c.zoom);

  /// 장면 pt → 지금 화면 위 기기 pt. 시험과 다른 트랙(겹쳐 띄울 때)이 쓴다
  ({double x, double y}) toScreen(RestCamera c, double x, double y) =>
      (x: c.x + c.zoom * sx(x), y: liftY(c) + c.zoom * sy(y));
}

/// 이보다 작게 확대된 것은 확대가 아니다 (손을 뗄 때 처음 배율로 돌아간다)
const _zoomEpsilon = 0.001;
