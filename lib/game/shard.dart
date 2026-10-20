import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import 'config.dart';
import 'geometry.dart';
import 'lighthouse_game.dart';
import 'tables.g.dart';

/// 빛 조각 (design.md §6): 적이 쓰러진 자리에 생겨 `shard_delay`초 반짝인 뒤 등대 가운데로 날아가고,
/// `absorb_distance` 안에 들면 빨려 들어 값만큼 빛 조각이 쌓인다. 판이 멈추면(창·놓기·꺼짐) 멈춘다.
///
/// `PositionComponent`가 아닌 까닭은 [Bubble]과 같다 (판의 조각 층이 게임 좌표 그대로라 [position]을 직접 들고 그린다).
class Shard extends Component with HasGameReference<LighthouseGame> {
  Shard(Vector2 at, this.value) : position = at.clone();

  /// 지금 자리 (게임 좌표).
  final Vector2 position;

  /// 빨려 들 때 쌓이는 양 (쓰러진 적의 xp).
  final double value;

  double _age = 0;
  bool _done = false;

  @override
  void update(double dt) {
    if (_done || game.isStopped || dt <= 0) return;
    final p = Tables.progression;
    _age += dt;
    if (_age < p.shardDelay) return; // 제자리에서 반짝임
    final to = lighthouseCenter() - position;
    final step = p.shardSpeed * dt;
    if (to.length <= step) {
      position.setFrom(lighthouseCenter());
    } else {
      position.add(to.normalized() * step);
    }
    if (position.distanceTo(lighthouseCenter()) <= p.absorbDistance) {
      _done = true;
      game.absorbShard(this);
      removeFromParent();
    }
  }

  static final _glow = Paint()..color = GameConfig.shardGlow;
  static final _star = Paint()..color = GameConfig.shardColor;

  @override
  void render(Canvas canvas) {
    // 작은 노란 별빛: 둘레 번짐 위에 네 갈래 별, 크기가 조금씩 반짝인다
    final phase = ((_age % GameConfig.shardTwinklePeriod) / GameConfig.shardTwinklePeriod).clamp(0.0, 1.0);
    final twinkle = (1 + math.cos(phase * 2 * math.pi)) / 2; // 0~1
    final c = position.toOffset();
    canvas.drawCircle(c, GameConfig.shardGlowRadius, _glow);
    final r = GameConfig.shardSize * (1 - GameConfig.shardTwinkleDepth * twinkle);
    final w = r * GameConfig.shardWaist;
    final path = Path()
      ..moveTo(c.dx, c.dy - r)
      ..lineTo(c.dx + w, c.dy - w)
      ..lineTo(c.dx + r, c.dy)
      ..lineTo(c.dx + w, c.dy + w)
      ..lineTo(c.dx, c.dy + r)
      ..lineTo(c.dx - w, c.dy + w)
      ..lineTo(c.dx - r, c.dy)
      ..lineTo(c.dx - w, c.dy - w)
      ..close();
    canvas.drawPath(path, _star);
  }
}
