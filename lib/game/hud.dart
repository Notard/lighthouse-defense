import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter/painting.dart' show Shadow, TextStyle;

import 'config.dart';
import 'strings.dart';

/// 판 위쪽 불빛 막대 (design.md §4 등대 불빛). 채운 비율 = 지금 불빛 ÷ 처음 불빛.
///
/// [position]·[size]는 막대 전체 (게임 좌표, 왼쪽 위 기준).
class LightBar extends PositionComponent {
  LightBar(this._ratio)
      : super(
          position: Vector2(GameConfig.lightBarX, GameConfig.lightBarY),
          size: Vector2(GameConfig.lightBarWidth, GameConfig.lightBarHeight),
        );

  final double Function() _ratio;

  /// 채운 비율 (0~1).
  double get ratio => _ratio().clamp(0.0, 1.0);

  final _empty = Paint()..color = GameConfig.lightBarEmpty;
  final _fill = Paint()..color = GameConfig.lightBarFill;
  final _border = Paint()
    ..color = GameConfig.lightBarBorder
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2;

  @override
  void render(Canvas canvas) {
    final radius = Radius.circular(size.y / 2);
    final whole = RRect.fromRectAndRadius(size.toRect(), radius);
    canvas.drawRRect(whole, _empty);
    final r = ratio;
    if (r > 0) {
      canvas.save();
      canvas.clipRRect(whole);
      canvas.drawRect(Rect.fromLTWH(0, 0, size.x * r, size.y), _fill);
      canvas.restore();
    }
    canvas.drawRRect(whole, _border);
  }
}

/// 불빛이 꺼졌을 때 판 가운데 문구 (꺼졌을 때만 판에 있다).
class LightOutText extends TextComponent {
  LightOutText()
      : super(
          text: Strings.lightOut,
          anchor: Anchor.center,
          position: Vector2(GameConfig.width / 2, GameConfig.height / 2),
          textRenderer: TextPaint(
            style: const TextStyle(
              fontFamily: GameConfig.fontFamily,
              fontSize: GameConfig.lightOutFontSize,
              color: GameConfig.lightOutColor,
              shadows: [Shadow(color: GameConfig.deepSea, blurRadius: 12)],
            ),
          ),
        );
}
