// 만든 파일, 고치지 말 것. data/tables/*.csv를 바꾸고 `python tools/gen_tables.py`로 다시 만든다.
// (design.md §4 "숫자 표와 변환기". 뜻은 data/tables/README.md)

/// 적 하나 (enemies.csv 한 줄). speed는 게임 px/초, bite_interval은 초.
class EnemyStats {
  const EnemyStats({required this.id, required this.hp, required this.speed, required this.bite, required this.biteInterval, required this.radius});

  /// `id`
  final String id;
  /// `hp`
  final double hp;
  /// `speed`
  final double speed;
  /// `bite`
  final double bite;
  /// `bite_interval`
  final double biteInterval;
  /// `radius`
  final double radius;
}

/// 등대 빛 (beam.csv). slow는 빛 속 빠르기 배율, vulnerable은 빛 속 받는 피해 배율.
class BeamStats {
  const BeamStats({required this.widthDeg, required this.length, required this.slow, required this.vulnerable});

  /// `width_deg`
  final double widthDeg;
  /// `length`
  final double length;
  /// `slow`
  final double slow;
  /// `vulnerable`
  final double vulnerable;
}

/// 등대 (lighthouse.csv). hp는 처음 불빛, spawn_distance는 적이 나타나는 거리.
class LighthouseStats {
  const LighthouseStats({required this.hp, required this.spawnDistance});

  /// `hp`
  final double hp;
  /// `spawn_distance`
  final double spawnDistance;
}

/// 연습 스폰 (practice.csv, 7단계 웨이브가 오면 없앤다).
class PracticeStats {
  const PracticeStats({required this.interval, required this.maxAlive});

  /// `interval`
  final double interval;
  /// `max_alive`
  final int maxAlive;
}

/// 캐릭터 (characters.csv 한 줄). display_height는 화면 키 (게임 px).
class CharacterStats {
  const CharacterStats({required this.id, required this.kind, required this.nameKo, required this.nameEn, required this.displayHeight});

  /// `id`
  final String id;
  /// `kind`
  final String kind;
  /// `name_ko`
  final String nameKo;
  /// `name_en`
  final String nameEn;
  /// `display_height`
  final double displayHeight;
}

/// 친구 하나 (friends.csv 한 줄). attack은 shot·melee·burst, range는 게임 px, interval은 초, projectile_speed는 거품 빠르기 (게임 px/초, shot만).
class FriendStats {
  const FriendStats({required this.id, required this.attack, required this.range, required this.damage, required this.interval, required this.projectileSpeed});

  /// `id`
  final String id;
  /// `attack`
  final String attack;
  /// `range`
  final double range;
  /// `damage`
  final double damage;
  /// `interval`
  final double interval;
  /// `projectile_speed`
  final double projectileSpeed;
}

/// 숫자 표 전체.
abstract final class Tables {
  /// enemies.csv (id → 값, 표 순서).
  static const Map<String, EnemyStats> enemies = {
    'shadow_blob': EnemyStats(id: 'shadow_blob', hp: 30.0, speed: 50.0, bite: 2.0, biteInterval: 1.0, radius: 26.0),
    'ink_squid': EnemyStats(id: 'ink_squid', hp: 20.0, speed: 80.0, bite: 1.0, biteInterval: 0.8, radius: 24.0),
    'shadow_jelly': EnemyStats(id: 'shadow_jelly', hp: 60.0, speed: 35.0, bite: 3.0, biteInterval: 1.2, radius: 28.0),
  };

  /// beam.csv
  static const BeamStats beam = BeamStats(widthDeg: 40.0, length: 640.0, slow: 0.5, vulnerable: 1.5);

  /// lighthouse.csv
  static const LighthouseStats lighthouse = LighthouseStats(hp: 100.0, spawnDistance: 780.0);

  /// practice.csv
  static const PracticeStats practice = PracticeStats(interval: 2.0, maxAlive: 8);

  /// characters.csv (id → 값, 표 순서).
  static const Map<String, CharacterStats> characters = {
    'seahorse': CharacterStats(id: 'seahorse', kind: 'friend', nameKo: '\uD574\uB9C8', nameEn: 'Seahorse', displayHeight: 84.0),
    'crab': CharacterStats(id: 'crab', kind: 'friend', nameKo: '\uAC8C', nameEn: 'Crab', displayHeight: 72.0),
    'pufferfish': CharacterStats(id: 'pufferfish', kind: 'friend', nameKo: '\uBCF5\uC5B4', nameEn: 'Pufferfish', displayHeight: 76.0),
    'shadow_blob': CharacterStats(id: 'shadow_blob', kind: 'enemy', nameKo: '\uADF8\uB9BC\uC790 \uBC29\uC6B8', nameEn: 'Shadow Blob', displayHeight: 64.0),
    'ink_squid': CharacterStats(id: 'ink_squid', kind: 'enemy', nameKo: '\uBA39\uBB3C \uC624\uC9D5\uC5B4', nameEn: 'Ink Squid', displayHeight: 70.0),
    'shadow_jelly': CharacterStats(id: 'shadow_jelly', kind: 'enemy', nameKo: '\uADF8\uB9BC\uC790 \uD574\uD30C\uB9AC', nameEn: 'Shadow Jelly', displayHeight: 74.0),
  };

  /// friends.csv (id → 값, 표 순서).
  static const Map<String, FriendStats> friends = {
    'seahorse': FriendStats(id: 'seahorse', attack: 'shot', range: 260.0, damage: 8.0, interval: 1.0, projectileSpeed: 420.0),
    'crab': FriendStats(id: 'crab', attack: 'melee', range: 90.0, damage: 14.0, interval: 1.2, projectileSpeed: 0.0),
    'pufferfish': FriendStats(id: 'pufferfish', attack: 'burst', range: 110.0, damage: 6.0, interval: 1.5, projectileSpeed: 0.0),
  };
}
