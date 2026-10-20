import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/painting.dart';

import 'config.dart';

/// 한 판 (1단계: 빈 밤바다와 등대 자리만).
class LighthouseGame extends FlameGame {
  LighthouseGame()
      : super(camera: CameraComponent.withFixedResolution(width: GameConfig.width, height: GameConfig.height));

  @override
  Color backgroundColor() => GameConfig.deepSea;

  @override
  Future<void> onLoad() async {
    camera.viewfinder.anchor = Anchor.topLeft;
    await world.addAll([SeaBackdrop(), LighthouseSpot(), TitleText()]);
  }
}

/// 밤바다 바탕: 위는 조금 밝고 아래로 깊어진다 (3단계에서 그림으로 바꾼다).
class SeaBackdrop extends PositionComponent {
  SeaBackdrop() : super(size: Vector2(GameConfig.width, GameConfig.height));

  final _paint = Paint()
    ..shader = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFF1B2E57), GameConfig.nightSea, GameConfig.deepSea],
    ).createShader(const Rect.fromLTWH(0, 0, GameConfig.width, GameConfig.height));

  @override
  void render(Canvas canvas) => canvas.drawRect(size.toRect(), _paint);
}

/// 등대 자리 (임시 원). 둘레의 안쪽·바깥 고리 자리는 2단계에서.
class LighthouseSpot extends PositionComponent {
  LighthouseSpot()
      : super(position: Vector2(GameConfig.lighthouseX, GameConfig.lighthouseY), size: Vector2.all(120), anchor: Anchor.center);

  static const double radius = 60;
  final _glow = Paint()..color = const Color(0x55FFE9A8);
  final _body = Paint()..color = const Color(0xFFEFE6D2);

  @override
  void render(Canvas canvas) {
    final c = Offset(size.x / 2, size.y / 2);
    canvas.drawCircle(c, radius * 1.6, _glow);
    canvas.drawCircle(c, radius, _body);
  }
}

class TitleText extends TextComponent {
  TitleText()
      : super(
          text: '등대 지키기',
          anchor: Anchor.topCenter,
          position: Vector2(GameConfig.width / 2, 120),
          textRenderer: TextPaint(style: const TextStyle(fontSize: 64, color: Color(0xFFFFF4DC), fontWeight: FontWeight.w700)),
        );
}
