import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show TextPainter, TextSpan, TextStyle, Shadow;

import 'art.dart';
import 'config.dart';
import 'geometry.dart';
import 'lighthouse_game.dart';
import 'strings.dart';
import 'tables.g.dart';

/// 카드 창 (design.md §6 그리기): 판을 어둡게 덮고, 위에 제목("레벨 업!" 또는 "첫 친구를 골라요"),
/// 가운데에 카드를 세로로 쌓는다. 누르기 판정은 판의 입력 층(`BoardInput` → `LighthouseGame.tapAt`)이 [views]로 한다.
class CardPanel extends Component {
  CardPanel(List<String> cardIds, {required this.first}) {
    final left = (GameConfig.width - GameConfig.cardWidth) / 2;
    views = [
      for (final (i, id) in cardIds.indexed)
        CardView(id, Vector2(left, GameConfig.cardTop + i * (GameConfig.cardHeight + GameConfig.cardGap))),
    ];
  }

  /// 첫 친구 고르기 창인지 (제목이 다르다).
  final bool first;

  /// 카드 (창의 순서).
  late final List<CardView> views;

  @override
  Future<void> onLoad() async {
    await addAll([_Dim(), _Title(first ? Strings.firstPick : Strings.levelUp), ...views]);
  }

  /// 게임 좌표 [p]에 있는 카드의 순서 (없으면 null).
  int? indexAt(Vector2 p) {
    for (final (i, v) in views.indexed) {
      if (v.toRect().contains(p.toOffset())) return i;
    }
    return null;
  }
}

/// 판 전체를 어둡게 덮는다.
class _Dim extends PositionComponent {
  _Dim() : super(size: Vector2(GameConfig.width, GameConfig.height));

  static final _paint = Paint()..color = GameConfig.cardDim;

  @override
  void render(Canvas canvas) => canvas.drawRect(size.toRect(), _paint);
}

class _Title extends TextComponent {
  _Title(String text)
      : super(
          text: text,
          anchor: Anchor.center,
          position: Vector2(GameConfig.width / 2, GameConfig.cardTitleY),
          textRenderer: TextPaint(
            style: const TextStyle(
              fontFamily: GameConfig.fontFamily,
              fontSize: GameConfig.cardTitleFontSize,
              color: GameConfig.cardTitleColor,
              shadows: [Shadow(color: GameConfig.deepSea, blurRadius: GameConfig.cardTitleShadowBlur)],
            ),
          ),
        );
}

/// 카드 한 장: 왼쪽에 그림(친구·강화는 친구 그림, 빛은 부채꼴, 등대는 불빛 원), 오른쪽에 이름과 설명. 종류별 색 테두리.
class CardView extends PositionComponent with HasGameReference<LighthouseGame> {
  CardView(this.cardId, Vector2 position)
      : stats = Tables.cards[cardId]!,
        super(position: position, size: Vector2(GameConfig.cardWidth, GameConfig.cardHeight));

  final String cardId;
  final CardStats stats;

  CharacterArt? _art;
  Sprite? _sprite;

  bool get _hasFriendArt => stats.kind == 'friend' || stats.kind == 'upgrade';

  Color get _color => switch (stats.kind) {
        'friend' => GameConfig.cardFriendColor,
        'upgrade' => GameConfig.cardUpgradeColor,
        'beam' => GameConfig.cardBeamColor,
        _ => GameConfig.cardLighthouseColor,
      };

  // 그리기 붓: 프레임마다 만들지 않고 카드 하나에 한 번 (색은 종류로 정해진다)
  static final _fill = Paint()..color = GameConfig.cardFill;
  static final _placeholder = Paint()..color = GameConfig.friendPlaceholder;
  late final Paint _edge = Paint()
    ..color = _color
    ..style = PaintingStyle.stroke
    ..strokeWidth = GameConfig.cardEdgeWidth;
  late final Paint _ink = Paint()..color = _color;
  Paint? _glow;
  Offset? _glowCenter;

  late final TextPainter _name = _layout(
    Strings.cardName(stats),
    TextStyle(fontFamily: GameConfig.fontFamily, fontSize: GameConfig.cardNameFontSize, color: GameConfig.cardNameColor),
  );
  late final TextPainter _desc = _layout(
    Strings.cardDesc(stats),
    TextStyle(fontFamily: GameConfig.fontFamily, fontSize: GameConfig.cardDescFontSize, color: GameConfig.cardDescColor),
  );

  /// 글 칸 너비 (카드 너비 − 그림 칸 − 여백 셋).
  static const double _textWidth = GameConfig.cardWidth - GameConfig.cardArtBox - GameConfig.cardPadding * 3;

  static TextPainter _layout(String text, TextStyle style) =>
      TextPainter(text: TextSpan(text: text, style: style), textDirection: TextDirection.ltr)..layout(maxWidth: _textWidth);

  @override
  void onLoad() {
    if (!_hasFriendArt) return;
    // 판이 그림을 기다리지 않게 읽기만 시작한다 (읽기 전에는 금빛 원)
    CharacterArt.load(game, stats.target).then((art) {
      _art = art;
      _sprite = art.firstFrame('idle');
    }, onError: (Object e) => debugPrint('card art load failed: ${stats.target} ($e)'));
  }

  @override
  void onRemove() {
    _name.dispose();
    _desc.dispose();
    super.onRemove();
  }

  @override
  void render(Canvas canvas) {
    final box = RRect.fromRectAndRadius(size.toRect(), const Radius.circular(GameConfig.cardCorner));
    canvas.drawRRect(box, _fill);
    canvas.drawRRect(box, _edge);

    // 그림 칸 가운데
    final art = Offset(GameConfig.cardPadding + GameConfig.cardArtBox / 2, size.y / 2);
    _renderArt(canvas, art);

    // 이름과 설명: 글 칸에서 위아래 가운데
    const textLeft = GameConfig.cardPadding * 2 + GameConfig.cardArtBox;
    final textHeight = _name.height + GameConfig.cardLineGap + _desc.height;
    final top = (size.y - textHeight) / 2;
    _name.paint(canvas, Offset(textLeft, top));
    _desc.paint(canvas, Offset(textLeft, top + _name.height + GameConfig.cardLineGap));
  }

  void _renderArt(Canvas canvas, Offset c) {
    final paint = _ink;
    switch (stats.kind) {
      case 'friend' || 'upgrade':
        const h = GameConfig.cardArtHeight;
        final art = _art;
        final sprite = _sprite;
        if (art == null || sprite == null) {
          canvas.drawCircle(c, h / 2, _placeholder);
        } else {
          // 몸 가운데(첫 프레임 그림 영역의 가운데)가 그림 칸 가운데에 오게, 키 cardArtHeight
          final s = art.scaleForHeight(h);
          final body = Vector2((art.bbox.left + art.bbox.right) / 2, (art.bbox.top + art.bbox.bottom) / 2);
          sprite.render(canvas, position: Vector2(c.dx, c.dy) - body * s, size: art.frameSize * s);
        }
        if (stats.kind == 'upgrade') _renderPlus(canvas, c + const Offset(h / 2, -h / 2), paint);
      case 'beam':
        // 아래에서 위(cardIconFanAngle)로 뻗는 부채꼴
        const r = GameConfig.cardIconRadius;
        const half = GameConfig.cardIconFanDeg / 2;
        final origin = c + const Offset(0, r / 2);
        final path = Path()
          ..moveTo(origin.dx, origin.dy)
          ..arcTo(Rect.fromCircle(center: origin, radius: r), degToRad(GameConfig.cardIconFanAngle - half),
              degToRad(GameConfig.cardIconFanDeg), false)
          ..close();
        canvas.drawPath(path, paint);
      default:
        // 등대 불빛: 번지는 원
        if (_glow == null || _glowCenter != c) {
          final color = _color;
          _glowCenter = c;
          _glow = Paint()..shader = Gradient.radial(c, GameConfig.cardIconGlowRadius, [color, color.withValues(alpha: 0)]);
        }
        canvas.drawCircle(c, GameConfig.cardIconGlowRadius, _glow!);
        canvas.drawCircle(c, GameConfig.cardIconGlowRadius / 2, paint);
    }
  }

  /// 강화 표시 "+".
  static void _renderPlus(Canvas canvas, Offset c, Paint paint) {
    const s = GameConfig.cardPlusSize / 2;
    const w = GameConfig.cardPlusWidth / 2;
    canvas.drawRect(Rect.fromLTRB(c.dx - s, c.dy - w, c.dx + s, c.dy + w), paint);
    canvas.drawRect(Rect.fromLTRB(c.dx - w, c.dy - s, c.dx + w, c.dy + s), paint);
  }
}
