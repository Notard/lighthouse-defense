import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import 'beam.dart';
import 'board_input.dart';
import 'config.dart';
import 'geometry.dart';
import 'slots.dart';
import 'strings.dart';

/// 한 판 (2단계: 밤바다, 등대, 둘레 자리 18개, 빛 방향 끌기).
class LighthouseGame extends FlameGame {
  LighthouseGame()
      : super(camera: CameraComponent.withFixedResolution(width: GameConfig.width, height: GameConfig.height));

  /// 자리 18개: 안쪽 `I0`…`I5` 다음 바깥 `O0`…`O11`.
  final List<Slot> slots = buildSlots();

  /// 등대 빛.
  final Beam beam = Beam();

  Slot? _selectedSlot;

  /// 고른 자리 (없으면 null).
  Slot? get selectedSlot => _selectedSlot;

  @override
  Color backgroundColor() => GameConfig.deepSea;

  @override
  Future<void> onLoad() async {
    camera.viewfinder.anchor = Anchor.topLeft;
    // 그리는 순서: 바다 → 빛 → 자리 → 등대 → 제목 (입력 층은 그리지 않는다)
    await world.addAll([SeaBackdrop(), beam, ...slots, LighthouseSpot(), TitleText(), BoardInput()]);
  }

  /// 게임 좌표 [p]에 닿는 자리 (누르는 범위 안에서 가장 가까운 것).
  Slot? slotAt(Vector2 p) {
    Slot? best;
    var bestDistance = double.infinity;
    for (final s in slots) {
      final d = s.center.distanceTo(p);
      if (s.touches(p) && d < bestDistance) {
        best = s;
        bestDistance = d;
      }
    }
    return best;
  }

  /// 누르기: 자리를 고르고, 고른 자리를 다시 누르거나 바다를 누르면 고르기를 푼다. 빛은 그대로.
  void tapAt(Vector2 p) {
    final s = slotAt(p);
    _select(s == _selectedSlot ? null : s);
  }

  void _select(Slot? s) {
    _selectedSlot?.selected = false;
    _selectedSlot = s;
    s?.selected = true;
  }

  /// 끌기: 빛이 [p] 쪽을 가리킨다. 등대 가운데 빈 곳 안이면 마지막 방향 그대로.
  void aimBeamAt(Vector2 p) {
    if (p.distanceTo(lighthouseCenter()) < GameConfig.beamDeadZone) return;
    beam.angleDeg = angleFromLighthouse(p);
  }
}

/// 밤바다 바탕: `night_sea` 그림을 판 전체에 그린다. 그림을 읽기 전(또는 읽기에 실패하면)에는 그러데이션.
class SeaBackdrop extends PositionComponent with HasGameReference<LighthouseGame> {
  SeaBackdrop() : super(size: Vector2(GameConfig.width, GameConfig.height));

  static const imageFile = 'night_sea.webp';

  /// 읽은 그림 (읽기 전에는 null).
  Sprite? get sprite => _sprite;
  Sprite? _sprite;

  final _paint = Paint()
    ..shader = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFF1B2E57), GameConfig.nightSea, GameConfig.deepSea],
    ).createShader(const Rect.fromLTWH(0, 0, GameConfig.width, GameConfig.height));

  @override
  void onLoad() {
    // 판이 그림을 기다리지 않게 읽기만 시작한다 (다 읽으면 그때부터 그림으로 그린다)
    _loadSprite(game, imageFile).then((s) => _sprite = s);
  }

  @override
  void render(Canvas canvas) {
    final s = _sprite;
    if (s == null) {
      canvas.drawRect(size.toRect(), _paint);
    } else {
      s.render(canvas, size: size);
    }
  }
}

/// 등대: `lighthouse` 그림을 등대 가운데에 한 변 [GameConfig.lighthouseSize]로 그린다. 읽기 전에는 임시 원.
class LighthouseSpot extends PositionComponent with HasGameReference<LighthouseGame> {
  LighthouseSpot()
      : super(position: lighthouseCenter(), size: Vector2.all(GameConfig.lighthouseSize), anchor: Anchor.center);

  static const imageFile = 'lighthouse.webp';

  /// 읽은 그림 (읽기 전에는 null).
  Sprite? get sprite => _sprite;
  Sprite? _sprite;

  final _glow = Paint()..color = const Color(0x55FFE9A8);
  final _body = Paint()..color = const Color(0xFFEFE6D2);

  @override
  void onLoad() {
    _loadSprite(game, imageFile).then((s) => _sprite = s);
  }

  @override
  void render(Canvas canvas) {
    final s = _sprite;
    if (s != null) {
      s.render(canvas, size: size);
      return;
    }
    final c = Offset(size.x / 2, size.y / 2);
    final r = size.x * 0.3;
    canvas.drawCircle(c, r * 1.6, _glow);
    canvas.drawCircle(c, r, _body);
  }
}

/// `assets/images/<file>`을 읽어 그림으로. 실패하면 null (임시 모양으로 계속 그린다).
Future<Sprite?> _loadSprite(LighthouseGame game, String file) async {
  try {
    return Sprite(await game.images.load(file));
  } catch (e) {
    debugPrint('image load failed: $file ($e)');
    return null;
  }
}

class TitleText extends TextComponent {
  TitleText()
      : super(
          text: Strings.title,
          anchor: Anchor.topCenter,
          position: Vector2(GameConfig.width / 2, 120),
          textRenderer: TextPaint(style: const TextStyle(fontFamily: GameConfig.fontFamily, fontSize: 64, color: Color(0xFFFFF4DC))),
        );
}
