import 'package:flame/components.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lighthouse_defense/game/config.dart';
import 'package:lighthouse_defense/game/lighthouse_game.dart';

/// 1단계: 세로 9:16 판이 뜨고 등대 자리가 가운데 있다.
void main() {
  GameTester(LighthouseGame.new).testGameWidget(
    '세로 720 × 1280 판, 바다·등대 자리·제목',
    verify: (game, tester) async {
      expect(game.camera.viewport.virtualSize, Vector2(GameConfig.width, GameConfig.height));
      expect(game.world.children.whereType<SeaBackdrop>(), hasLength(1));
      final spot = game.world.children.whereType<LighthouseSpot>().single;
      expect(spot.position.x, GameConfig.width / 2);
      expect(game.world.children.whereType<TitleText>().single.text, '등대 지키기');
    },
  );
}
