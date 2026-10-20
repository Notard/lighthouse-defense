import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show TextStyle;

import 'art.dart';
import 'config.dart';
import 'lighthouse_game.dart';
import 'strings.dart';
import 'tables.g.dart';

/// 친구 쟁반 (design.md §5, 연습용: 6단계 카드가 오면 바뀐다). 판 아래쪽에 친구 단추가 가로로.
///
/// 단추를 누르면 그 친구를 든다. 같은 단추를 다시 누르면 내려놓고, 다른 단추면 그 친구로 바뀐다.
/// 누르기 판정은 판의 입력 층(`BoardInput` → `LighthouseGame.tapAt`)이 한다.
class FriendTray extends Component {
  FriendTray() {
    final ids = Tables.friends.keys.toList();
    final total = ids.length * GameConfig.trayButtonWidth + (ids.length - 1) * GameConfig.trayButtonGap;
    final left = (GameConfig.width - total) / 2;
    buttons = [
      for (final (i, id) in ids.indexed)
        TrayButton(id, this, Vector2(left + i * (GameConfig.trayButtonWidth + GameConfig.trayButtonGap), GameConfig.trayY)),
    ];
  }

  /// 친구 단추 (표 순서: 해마·게·복어).
  late final List<TrayButton> buttons;

  /// 든 친구 id (안 들었으면 null).
  String? held;

  @override
  Future<void> onLoad() async {
    addAll(buttons);
  }

  /// 게임 좌표 [p]에 있는 단추 (없으면 null).
  TrayButton? buttonAt(Vector2 p) {
    for (final b in buttons) {
      if (b.toRect().contains(p.toOffset())) return b;
    }
    return null;
  }

  /// 단추 누르기: 그 친구를 들거나, 이미 든 것이면 내려놓는다.
  void press(TrayButton b) => held = held == b.friendId ? null : b.friendId;
}

/// 쟁반의 친구 단추 하나: 친구 그림(idle 첫 프레임)과 이름(지금 언어). 든 단추는 밝게 강조한다.
class TrayButton extends PositionComponent with HasGameReference<LighthouseGame> {
  TrayButton(this.friendId, this._tray, Vector2 position)
      : super(position: position, size: Vector2(GameConfig.trayButtonWidth, GameConfig.trayButtonHeight));

  final String friendId;
  final FriendTray _tray;

  bool get _held => _tray.held == friendId;

  Sprite? _sprite;
  CharacterArt? _art;

  static final _fill = Paint()..color = GameConfig.trayButtonFill;
  static final _edge = Paint()
    ..color = GameConfig.trayButtonEdge
    ..style = PaintingStyle.stroke
    ..strokeWidth = GameConfig.trayButtonEdgeWidth;
  static final _heldFill = Paint()..color = GameConfig.trayHeldFill;
  static final _heldEdge = Paint()
    ..color = GameConfig.trayHeldEdge
    ..style = PaintingStyle.stroke
    ..strokeWidth = GameConfig.trayHeldEdgeWidth;
  static final _placeholder = Paint()..color = GameConfig.friendPlaceholder;

  TextPaint _text(Color color) => TextPaint(
        style: TextStyle(fontFamily: GameConfig.fontFamily, fontSize: GameConfig.trayNameFontSize, color: color),
      );
  late final TextPaint _name = _text(GameConfig.trayNameColor);
  late final TextPaint _heldName = _text(GameConfig.trayHeldNameColor);

  @override
  void onLoad() {
    // 판이 그림을 기다리지 않게 읽기만 시작한다 (읽기 전에는 금빛 원)
    CharacterArt.load(game, friendId).then((art) {
      _art = art;
      _sprite = art.firstFrame('idle');
    }, onError: (Object e) => debugPrint('tray art load failed: $friendId ($e)'));
  }

  @override
  void render(Canvas canvas) {
    final held = _held;
    final box = RRect.fromRectAndRadius(size.toRect(), const Radius.circular(GameConfig.trayButtonCorner));
    canvas.drawRRect(box, held ? _heldFill : _fill);
    canvas.drawRRect(box, held ? _heldEdge : _edge);

    // 그림: 단추 위쪽에 발이 오게, 키 trayArtHeight
    const artH = GameConfig.trayArtHeight;
    final foot = Vector2(size.x / 2, GameConfig.trayArtTop + artH);
    final art = _art;
    final sprite = _sprite;
    if (art == null || sprite == null) {
      canvas.drawCircle(Offset(foot.x, foot.y - artH / 2), artH / 2, _placeholder);
    } else {
      final s = art.scaleForHeight(artH);
      sprite.render(canvas, position: foot - art.anchor * s, size: art.frameSize * s);
    }

    final name = Strings.characterName(Tables.characters[friendId]!);
    (held ? _heldName : _name).render(canvas, name, Vector2(size.x / 2, size.y - GameConfig.trayNameBottom), anchor: Anchor.bottomCenter);
  }
}
