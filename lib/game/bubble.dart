import 'dart:ui';

import 'package:flame/components.dart';

import 'config.dart';
import 'enemy.dart';
import 'lighthouse_game.dart';

/// 해마의 탄 (design.md §5 거품): 과녁의 지금 몸 가운데를 따라 날아가 맞으면 damage.
///
/// 날아가는 중에 과녁이 쓰러지거나 사라지면 과녁의 마지막 자리까지 가서 피해 없이 터진다 (다른 적을 맞히지 않음).
/// 판이 멈추면 멈춘다. 그림 없이 작은 반투명 물방울로 그린다.
///
/// `PositionComponent`가 아닌 까닭은 [Enemy]와 같다 (판의 거품 층이 게임 좌표 그대로라 [position]을 직접 들고 그린다).
class Bubble extends Component with HasGameReference<LighthouseGame> {
  Bubble(Vector2 from, this.target, this.damage, this.speed)
      : position = from.clone(),
        _lastSeen = target.position.clone();

  /// 지금 자리 (게임 좌표).
  final Vector2 position;

  /// 과녁.
  final Enemy target;

  final double damage;

  /// 1초에 날아가는 거리 (게임 px).
  final double speed;

  /// 과녁이 맞을 수 있던 마지막 자리 (쓰러지거나 사라지면 여기까지 간다).
  final Vector2 _lastSeen;

  bool _done = false;

  bool get _targetAlive => target.state != EnemyState.dying && game.enemies.contains(target);

  @override
  void update(double dt) {
    if (_done || game.isStopped || dt <= 0) return;
    final alive = _targetAlive;
    if (alive) _lastSeen.setFrom(target.position);
    // 맞음 판정은 움직이기 전에 본다: 나간 프레임에는 판정하지 않고, 과녁에 닿은 모습이 한 프레임 보인 뒤 터진다
    if (alive && position.distanceTo(target.position) <= target.stats.radius) {
      target.takeDamage(damage);
      _pop();
      return;
    }
    final to = _lastSeen - position;
    final step = speed * dt;
    if (!alive && to.length <= step) {
      _pop(); // 과녁이 없어졌다: 마지막 자리에서 피해 없이 터짐
      return;
    }
    if (to.length <= step) {
      position.setFrom(_lastSeen);
    } else {
      position.add(to.normalized() * step);
    }
  }

  void _pop() {
    _done = true;
    game.forgetBubble(this);
    removeFromParent();
  }

  static final _fill = Paint()..color = GameConfig.bubbleFill;
  static final _edge = Paint()
    ..color = GameConfig.bubbleEdge
    ..style = PaintingStyle.stroke
    ..strokeWidth = GameConfig.bubbleEdgeWidth;
  static final _shine = Paint()..color = GameConfig.bubbleEdge;

  @override
  void render(Canvas canvas) {
    const r = GameConfig.bubbleRadius;
    final c = position.toOffset();
    canvas.drawCircle(c, r, _fill);
    canvas.drawCircle(c, r, _edge);
    const shine = r * GameConfig.bubbleShineOffset;
    canvas.drawCircle(c + const Offset(-shine, -shine), r * GameConfig.bubbleShineSize, _shine);
  }
}
