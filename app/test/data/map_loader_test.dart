import 'package:doobal/data/map_loader.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // pubspec의 assets/map/ 선언이 맞는지 rootBundle로 확인한다 (파일을 따로 읽는 다른 테스트와 달리)
  test('rootBundle에서 투영과 경계를 읽는다', () async {
    final projection = await loadMapProjection();
    expect(projection.width, 2048);
    expect(projection.height, 2560);
    final regions = await loadMapRegions();
    expect(regions, hasLength(18));
  });
}
