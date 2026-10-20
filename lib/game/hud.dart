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
    ..strokeWidth = GameConfig.barBorderWidth;

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

/// 불빛 막대 아래 조각 막대 (design.md §6 레벨). 채운 비율 = 쌓인 양 ÷ 지금 레벨에 드는 양, 옆에 `Lv n`.
///
/// [position]·[size]는 막대 전체 (게임 좌표, 왼쪽 위 기준). 레벨 글자는 막대 오른쪽 바깥에 그린다.
class XpBar extends PositionComponent {
  XpBar(this._ratio, this._level)
      : super(
          position: Vector2(GameConfig.xpBarX, GameConfig.xpBarY),
          size: Vector2(GameConfig.xpBarWidth, GameConfig.xpBarHeight),
        );

  final double Function() _ratio;
  final int Function() _level;

  /// 채운 비율 (0~1).
  double get ratio => _ratio().clamp(0.0, 1.0);

  /// 레벨 글자 (`Lv n`).
  String get levelText => Strings.level(_level());

  final _empty = Paint()..color = GameConfig.xpBarEmpty;
  final _fill = Paint()..color = GameConfig.xpBarFill;
  final _border = Paint()
    ..color = GameConfig.xpBarBorder
    ..style = PaintingStyle.stroke
    ..strokeWidth = GameConfig.barBorderWidth;
  final _text = TextPaint(
    style: const TextStyle(
      fontFamily: GameConfig.fontFamily,
      fontSize: GameConfig.xpLevelFontSize,
      color: GameConfig.xpLevelColor,
      shadows: [Shadow(color: GameConfig.deepSea, blurRadius: 6)],
    ),
  );

  @override
  void render(Canvas canvas) {
    final whole = RRect.fromRectAndRadius(size.toRect(), Radius.circular(size.y / 2));
    canvas.drawRRect(whole, _empty);
    final r = ratio;
    if (r > 0) {
      canvas.save();
      canvas.clipRRect(whole);
      canvas.drawRect(Rect.fromLTWH(0, 0, size.x * r, size.y), _fill);
      canvas.restore();
    }
    canvas.drawRRect(whole, _border);
    // 막대 오른쪽 바깥, 막대 높이 가운데에 레벨 글자
    _text.render(canvas, levelText, Vector2(size.x + size.y, size.y / 2), anchor: Anchor.centerLeft);
  }
}

/// 놓기 상태의 안내 (design.md §6): 판 가운데 위에 "친구를 놓을 자리를 눌러요". 놓기 상태일 때만 그린다.
class PlaceHint extends PositionComponent {
  PlaceHint(this._visible) : super(position: Vector2(GameConfig.width / 2, GameConfig.placeHintY));

  final bool Function() _visible;

  final _text = TextPaint(
    style: const TextStyle(
      fontFamily: GameConfig.fontFamily,
      fontSize: GameConfig.placeHintFontSize,
      color: GameConfig.placeHintColor,
      shadows: [Shadow(color: GameConfig.deepSea, blurRadius: 10)],
    ),
  );

  @override
  void render(Canvas canvas) {
    if (!_visible()) return;
    _text.render(canvas, Strings.placeHint, Vector2.zero(), anchor: Anchor.center);
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
