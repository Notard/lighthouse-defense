import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter/painting.dart' show Shadow, TextStyle;

import 'config.dart';
import 'strings.dart';

/// 웨이브 판이 끝났을 때의 결과 창 (design.md §7): 판을 어둡게 덮고, 가운데 창에 제목·결과 줄들·다시 하기 단추.
///
/// 누르기 판정은 판의 입력 층(`BoardInput` → `LighthouseGame.tapAt`)이 [restartButton]으로 한다.
class ResultPanel extends Component {
  ResultPanel({required this.title, required this.lines, required this.won})
      : restartButton = RestartButton(
          Vector2(
            (GameConfig.width - GameConfig.restartWidth) / 2,
            GameConfig.resultTop + GameConfig.resultHeight - GameConfig.restartBottom - GameConfig.restartHeight,
          ),
        );

  /// 제목 ("새벽이 왔어요!" / "불빛이 꺼졌어요").
  final String title;

  /// 보이는 글 줄들 (제목 다음 줄부터: 다다른 웨이브, 쓰러뜨린 적, 레벨, 시간).
  final List<String> lines;

  /// 이겼는지 (테두리 색).
  final bool won;

  /// 다시 하기 단추 (`position`·`size`는 게임 좌표, 왼쪽 위 기준).
  final RestartButton restartButton;

  @override
  Future<void> onLoad() async {
    await addAll([_ResultBox(title, lines, won), restartButton]);
  }
}

/// 덮개와 창, 글.
class _ResultBox extends PositionComponent {
  _ResultBox(this._title, this._lines, bool won)
      : _edge = Paint()
          ..color = won ? GameConfig.resultWonEdge : GameConfig.resultLostEdge
          ..style = PaintingStyle.stroke
          ..strokeWidth = GameConfig.resultEdgeWidth,
        super(size: Vector2(GameConfig.width, GameConfig.height));

  final String _title;
  final List<String> _lines;
  final Paint _edge;

  static final _dim = Paint()..color = GameConfig.resultDim;
  static final _fill = Paint()..color = GameConfig.resultFill;

  static TextPaint _text(double size, Color color) => TextPaint(
        style: TextStyle(
          fontFamily: GameConfig.fontFamily,
          fontSize: size,
          color: color,
          shadows: const [Shadow(color: GameConfig.deepSea, blurRadius: GameConfig.resultShadowBlur)],
        ),
      );
  static final _titleText = _text(GameConfig.resultTitleFontSize, GameConfig.resultTitleColor);
  static final _lineText = _text(GameConfig.resultLineFontSize, GameConfig.resultLineColor);

  @override
  void render(Canvas canvas) {
    canvas.drawRect(size.toRect(), _dim);
    const left = (GameConfig.width - GameConfig.resultWidth) / 2;
    const top = GameConfig.resultTop;
    final box = RRect.fromRectAndRadius(
      const Rect.fromLTWH(left, top, GameConfig.resultWidth, GameConfig.resultHeight),
      const Radius.circular(GameConfig.resultCorner),
    );
    canvas.drawRRect(box, _fill);
    canvas.drawRRect(box, _edge);
    const cx = GameConfig.width / 2;
    _titleText.render(canvas, _title, Vector2(cx, top + GameConfig.resultTitleY), anchor: Anchor.center);
    for (final (i, line) in _lines.indexed) {
      _lineText.render(canvas, line, Vector2(cx, top + GameConfig.resultLineTop + i * GameConfig.resultLineGap),
          anchor: Anchor.center);
    }
  }
}

/// 다시 하기 단추.
class RestartButton extends PositionComponent {
  RestartButton(Vector2 position)
      : super(position: position, size: Vector2(GameConfig.restartWidth, GameConfig.restartHeight));

  /// 단추 글 (지금 언어).
  final String label = Strings.restart;

  static final _fill = Paint()..color = GameConfig.restartFill;
  static final _text = TextPaint(
    style: const TextStyle(
      fontFamily: GameConfig.fontFamily,
      fontSize: GameConfig.restartFontSize,
      color: GameConfig.restartTextColor,
    ),
  );

  @override
  void render(Canvas canvas) {
    canvas.drawRRect(RRect.fromRectAndRadius(size.toRect(), const Radius.circular(GameConfig.restartCorner)), _fill);
    _text.render(canvas, label, size / 2, anchor: Anchor.center);
  }
}
