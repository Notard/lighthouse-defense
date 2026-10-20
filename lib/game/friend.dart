import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/sprite.dart';
import 'package:flutter/foundation.dart';

import 'art.dart';
import 'config.dart';
import 'enemy.dart';
import 'lighthouse_game.dart';
import 'slots.dart';
import 'tables.g.dart';

/// 자리에 놓여 사거리 안 적을 저절로 공격하는 친구 (design.md §5).
///
/// 위치([position], 게임 좌표)는 자리 가운데 = 몸 가운데. 규칙 숫자는 모두 숫자 표(`Tables.friends`)에서.
/// 판이 멈추면(불빛 꺼짐) 공격도 그림도 멈춘다.
class Friend extends PositionComponent with HasGameReference<LighthouseGame> {
  Friend(this.id, this.slot)
      : stats = Tables.friends[id]!,
        super(position: slot.center.clone());

  /// 공격 시작에서 효과까지 (attack 이벤트 프레임 5: (5 − 1) ÷ 12fps).
  static const double windupSeconds = 1 / 3;

  final String id;
  final FriendStats stats;

  /// 놓인 자리.
  final Slot slot;

  /// 남은 쉬는 시간 (0이면 바로 공격할 수 있다).
  double cooldown = 0;

  bool _attacking = false;
  double _windup = 0;
  Enemy? _target;

  /// 공격 시작 ~ 효과 사이인지.
  bool get isAttacking => _attacking;

  /// 지금 과녁 (공격 시작에 정하고 효과가 나면 놓는다).
  Enemy? get target => _target;

  CharacterArt? _art;
  final Map<String, SpriteAnimationTicker> _tickers = {};
  String _action = 'idle';

  /// 사거리 안 적: 자리 가운데에서 몸 가운데까지 거리 ≤ range이고 쓰러지는 중이 아닌 적.
  List<Enemy> enemiesInRange() => [
        for (final e in game.enemies)
          if (e.state != EnemyState.dying && e.position.distanceTo(position) <= stats.range) e,
      ];

  /// 과녁 고르기: 사거리 안에서 등대에 가장 가까운 적, 같으면 친구에게 더 가까운 적 (없으면 null).
  Enemy? _pickTarget() {
    Enemy? best;
    for (final e in enemiesInRange()) {
      if (best == null ||
          e.distance < best.distance ||
          (e.distance == best.distance && e.position.distanceTo(position) < best.position.distanceTo(position))) {
        best = e;
      }
    }
    return best;
  }

  /// 과녁이 아직 맞을 수 있는지 (쓰러지지 않았고 판에서 사라지지 않음).
  bool _alive(Enemy? e) => e != null && e.state != EnemyState.dying && game.enemies.contains(e);

  @override
  void onLoad() {
    // 판이 그림을 기다리지 않게 읽기만 시작한다 (읽기 전에는 금빛 원)
    CharacterArt.load(game, id).then(_useArt, onError: (Object e) => debugPrint('friend art load failed: $id ($e)'));
  }

  void _useArt(CharacterArt art) {
    for (final action in art.actions) {
      _tickers[action] = art.animation(action).createTicker();
    }
    _art = art;
  }

  @override
  void update(double dt) {
    if (game.isOver) return; // 판이 멈춤: 공격·그림 모두 그대로
    cooldown = math.max(0, cooldown - dt);
    if (_attacking) {
      _windup += dt;
      if (_windup >= windupSeconds) _strike();
    }
    if (!_attacking && cooldown <= 0) {
      final t = _pickTarget();
      if (t != null) _startAttack(t);
    }
    _animate(dt);
  }

  void _startAttack(Enemy t) {
    _target = t;
    _attacking = true;
    _windup = 0;
    cooldown = stats.interval;
    // 그림을 읽기 전 공격은 그림이 온 뒤 재생하지 않는다
    if (_art != null) _play('attack');
  }

  /// 효과: shot은 거품, melee는 과녁에 damage(쓰러졌으면 헛침), burst는 사거리 안 모두에게 damage.
  void _strike() {
    final t = _target;
    _attacking = false;
    _target = null;
    switch (stats.attack) {
      case 'shot':
        final aim = _alive(t) ? t : _pickTarget();
        if (aim != null) game.shootBubble(muzzle, aim, stats.damage, stats.projectileSpeed);
      case 'melee':
        if (_alive(t)) t!.takeDamage(stats.damage);
      case 'burst':
        for (final e in enemiesInRange()) {
          e.takeDamage(stats.damage);
        }
    }
  }

  // ---- 그림 ----

  /// 몸 가운데(첫 프레임 그림 영역의 가운데, 프레임 px).
  static Vector2 _bodyOf(CharacterArt art) =>
      Vector2((art.bbox.left + art.bbox.right) / 2, (art.bbox.top + art.bbox.bottom) / 2);

  /// 거품이 나가는 점 (게임 좌표): 시트의 `muzzle`을 화면 배율로. 그림이나 muzzle이 없으면 자리 가운데.
  Vector2 get muzzle {
    final art = _art;
    final m = art?.muzzle;
    if (art == null || m == null) return position.clone();
    final s = art.scaleForHeight(Tables.characters[id]!.displayHeight);
    return position + (m - _bodyOf(art)) * s;
  }

  void _play(String action) {
    _action = action;
    _tickers[action]?.reset();
  }

  /// idle 반복, 공격 시작에 attack 한 번 → 끝나면 idle.
  void _animate(double dt) {
    if (_art == null) return;
    if (_action == 'attack' && (_tickers['attack']?.done() ?? true)) _play('idle');
    _tickers[_action]?.update(dt);
  }

  @override
  void render(Canvas canvas) {
    final art = _art;
    final ticker = _tickers[_action];
    if (art == null || ticker == null) {
      canvas.drawCircle(Offset.zero, Tables.characters[id]!.displayHeight / 2, _placeholder);
      return;
    }
    // 몸 가운데가 위치(자리 가운데)에 오게, 키 display_height로. 앞을 본다 (뒤집지 않음)
    final s = art.scaleForHeight(Tables.characters[id]!.displayHeight);
    ticker.getSprite().render(canvas, position: -_bodyOf(art) * s, size: art.frameSize * s);
  }

  static final _placeholder = Paint()..color = GameConfig.friendPlaceholder;
}
