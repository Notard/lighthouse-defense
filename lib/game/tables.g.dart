// 만든 파일, 고치지 말 것. data/tables/*.csv를 바꾸고 `python tools/gen_tables.py`로 다시 만든다.
// (design.md §4 "숫자 표와 변환기". 뜻은 data/tables/README.md)

/// 적 하나 (enemies.csv 한 줄). speed는 게임 px/초, bite_interval은 초, xp는 떨어뜨리는 빛 조각 값, art는 그림(characters의 id), scale은 그 그림 키에 곱하는 배율, boss는 보스인지.
class EnemyStats {
  const EnemyStats({required this.id, required this.hp, required this.speed, required this.bite, required this.biteInterval, required this.radius, required this.xp, required this.art, required this.scale, required this.boss});

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
  /// `xp`
  final double xp;
  /// `art`
  final String art;
  /// `scale`
  final double scale;
  /// `boss`
  final bool boss;
}

/// 등대 빛 (beam.csv). slow는 빛 속 빠르기 배율, vulnerable은 빛 속 받는 피해 배율, friend_haste는 빛 속 친구의 쉬는 시간이 흐르는 배율.
class BeamStats {
  const BeamStats({required this.widthDeg, required this.length, required this.slow, required this.vulnerable, required this.friendHaste});

  /// `width_deg`
  final double widthDeg;
  /// `length`
  final double length;
  /// `slow`
  final double slow;
  /// `vulnerable`
  final double vulnerable;
  /// `friend_haste`
  final double friendHaste;
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

/// 레벨과 빛 조각 (progression.csv). 레벨 n에서 다음 레벨에 드는 양 = xp_base + xp_step × (n − 1), shard_delay는 초, shard_speed는 게임 px/초, absorb_distance는 게임 px.
class ProgressionStats {
  const ProgressionStats({required this.xpBase, required this.xpStep, required this.shardDelay, required this.shardSpeed, required this.absorbDistance});

  /// `xp_base`
  final double xpBase;
  /// `xp_step`
  final double xpStep;
  /// `shard_delay`
  final double shardDelay;
  /// `shard_speed`
  final double shardSpeed;
  /// `absorb_distance`
  final double absorbDistance;
}

/// 레벨업 카드 하나 (cards.csv 한 줄). kind는 friend·upgrade·beam·lighthouse, max_picks 0은 제한 없음, weight는 뽑힐 무게.
class CardStats {
  const CardStats({required this.id, required this.kind, required this.target, required this.value, required this.maxPicks, required this.weight, required this.nameKo, required this.nameEn, required this.descKo, required this.descEn});

  /// `id`
  final String id;
  /// `kind`
  final String kind;
  /// `target`
  final String target;
  /// `value`
  final double value;
  /// `max_picks`
  final int maxPicks;
  /// `weight`
  final double weight;
  /// `name_ko`
  final String nameKo;
  /// `name_en`
  final String nameEn;
  /// `desc_ko`
  final String descKo;
  /// `desc_en`
  final String descEn;
}

/// 웨이브 표 한 줄 (waves.csv). 웨이브 wave가 시작되고 delay + k × interval초에 k번째(0부터) enemy가 나온다 (count개).
class WaveRow {
  const WaveRow({required this.wave, required this.enemy, required this.count, required this.interval, required this.delay});

  /// `wave`
  final int wave;
  /// `enemy`
  final String enemy;
  /// `count`
  final int count;
  /// `interval`
  final double interval;
  /// `delay`
  final double delay;
}

/// 웨이브 규칙 (wave_rules.csv). first_delay는 첫 웨이브까지, rest는 깬 뒤 쉬는 시간, banner_seconds는 알림이 떠 있는 시간 (모두 초).
class WaveRules {
  const WaveRules({required this.firstDelay, required this.rest, required this.bannerSeconds});

  /// `first_delay`
  final double firstDelay;
  /// `rest`
  final double rest;
  /// `banner_seconds`
  final double bannerSeconds;
}

/// 숫자 표 전체.
abstract final class Tables {
  /// enemies.csv (id → 값, 표 순서).
  static const Map<String, EnemyStats> enemies = {
    'shadow_blob': EnemyStats(id: 'shadow_blob', hp: 30.0, speed: 50.0, bite: 2.0, biteInterval: 1.0, radius: 26.0, xp: 2.0, art: 'shadow_blob', scale: 1.0, boss: false),
    'ink_squid': EnemyStats(id: 'ink_squid', hp: 20.0, speed: 80.0, bite: 1.0, biteInterval: 0.8, radius: 24.0, xp: 1.0, art: 'ink_squid', scale: 1.0, boss: false),
    'shadow_jelly': EnemyStats(id: 'shadow_jelly', hp: 60.0, speed: 35.0, bite: 3.0, biteInterval: 1.2, radius: 28.0, xp: 3.0, art: 'shadow_jelly', scale: 1.0, boss: false),
    'boss_squid': EnemyStats(id: 'boss_squid', hp: 500.0, speed: 28.0, bite: 6.0, biteInterval: 1.0, radius: 44.0, xp: 15.0, art: 'ink_squid', scale: 1.8, boss: true),
    'boss_jelly': EnemyStats(id: 'boss_jelly', hp: 1100.0, speed: 22.0, bite: 10.0, biteInterval: 1.2, radius: 52.0, xp: 30.0, art: 'shadow_jelly', scale: 2.1, boss: true),
  };

  /// beam.csv
  static const BeamStats beam = BeamStats(widthDeg: 40.0, length: 640.0, slow: 0.5, vulnerable: 1.5, friendHaste: 1.5);

  /// lighthouse.csv
  static const LighthouseStats lighthouse = LighthouseStats(hp: 100.0, spawnDistance: 780.0);

  /// practice.csv
  static const PracticeStats practice = PracticeStats(interval: 3.5, maxAlive: 4);

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
    'seahorse': FriendStats(id: 'seahorse', attack: 'shot', range: 320.0, damage: 8.0, interval: 1.0, projectileSpeed: 420.0),
    'crab': FriendStats(id: 'crab', attack: 'melee', range: 90.0, damage: 14.0, interval: 1.2, projectileSpeed: 0.0),
    'pufferfish': FriendStats(id: 'pufferfish', attack: 'burst', range: 110.0, damage: 6.0, interval: 1.5, projectileSpeed: 0.0),
  };

  /// progression.csv
  static const ProgressionStats progression = ProgressionStats(xpBase: 3.0, xpStep: 3.0, shardDelay: 0.3, shardSpeed: 360.0, absorbDistance: 40.0);

  /// cards.csv (id → 값, 표 순서).
  static const Map<String, CardStats> cards = {
    'friend_seahorse': CardStats(id: 'friend_seahorse', kind: 'friend', target: 'seahorse', value: 1.0, maxPicks: 0, weight: 10.0, nameKo: '\uD574\uB9C8', nameEn: 'Seahorse', descKo: '\uAC70\uD488\uC744 \uC3D8\uB294 \uCE5C\uAD6C\uB97C \uB193\uC544\uC694', descEn: 'Place a bubble-shooting friend'),
    'friend_crab': CardStats(id: 'friend_crab', kind: 'friend', target: 'crab', value: 1.0, maxPicks: 0, weight: 10.0, nameKo: '\uAC8C', nameEn: 'Crab', descKo: '\uAC00\uAE4C\uC6B4 \uC801\uC744 \uC9D1\uB294 \uCE5C\uAD6C\uB97C \uB193\uC544\uC694', descEn: 'Place a pinching friend'),
    'friend_pufferfish': CardStats(id: 'friend_pufferfish', kind: 'friend', target: 'pufferfish', value: 1.0, maxPicks: 0, weight: 10.0, nameKo: '\uBCF5\uC5B4', nameEn: 'Pufferfish', descKo: '\uB458\uB808\uB97C \uCC0C\uB974\uB294 \uCE5C\uAD6C\uB97C \uB193\uC544\uC694', descEn: 'Place a spiky friend'),
    'upgrade_seahorse': CardStats(id: 'upgrade_seahorse', kind: 'upgrade', target: 'seahorse', value: 1.3, maxPicks: 2, weight: 8.0, nameKo: '\uD574\uB9C8 \uAC15\uD654', nameEn: 'Seahorse Up', descKo: '\uD574\uB9C8 \uBAA8\uB450 \uD53C\uD574 +30%', descEn: 'All seahorses +30% damage'),
    'upgrade_crab': CardStats(id: 'upgrade_crab', kind: 'upgrade', target: 'crab', value: 1.3, maxPicks: 2, weight: 8.0, nameKo: '\uAC8C \uAC15\uD654', nameEn: 'Crab Up', descKo: '\uAC8C \uBAA8\uB450 \uD53C\uD574 +30%', descEn: 'All crabs +30% damage'),
    'upgrade_pufferfish': CardStats(id: 'upgrade_pufferfish', kind: 'upgrade', target: 'pufferfish', value: 1.3, maxPicks: 2, weight: 8.0, nameKo: '\uBCF5\uC5B4 \uAC15\uD654', nameEn: 'Pufferfish Up', descKo: '\uBCF5\uC5B4 \uBAA8\uB450 \uD53C\uD574 +30%', descEn: 'All pufferfish +30% damage'),
    'beam_wide': CardStats(id: 'beam_wide', kind: 'beam', target: 'width_deg', value: 10.0, maxPicks: 3, weight: 6.0, nameKo: '\uB113\uC740 \uBE5B', nameEn: 'Wide Beam', descKo: '\uBE5B\uC904\uAE30 \uD3ED +10\uB3C4', descEn: 'Beam width +10 degrees'),
    'beam_long': CardStats(id: 'beam_long', kind: 'beam', target: 'length', value: 80.0, maxPicks: 3, weight: 6.0, nameKo: '\uBA3C \uBE5B', nameEn: 'Long Beam', descKo: '\uBE5B\uC904\uAE30 \uAE38\uC774 +80', descEn: 'Beam length +80'),
    'light_up': CardStats(id: 'light_up', kind: 'lighthouse', target: 'max_hp', value: 20.0, maxPicks: 5, weight: 6.0, nameKo: '\uBC1D\uC740 \uB4F1\uB300', nameEn: 'Brighter Light', descKo: '\uBD88\uBE5B \uCD5C\uB300 +20 (\uADF8\uB9CC\uD07C \uCC44\uC6C0)', descEn: 'Max light +20 (and refill that much)'),
    'light_regen': CardStats(id: 'light_regen', kind: 'lighthouse', target: 'regen', value: 0.5, maxPicks: 3, weight: 5.0, nameKo: '\uB418\uC0B4\uC544\uB098\uB294 \uBD88\uBE5B', nameEn: 'Light Regen', descKo: '\uBD88\uBE5B\uC774 1\uCD08\uC5D0 0.5\uC529 \uCC28\uC694', descEn: 'Light recovers 0.5 per second'),
  };

  /// waves.csv (표 순서).
  static const List<WaveRow> waves = [
    WaveRow(wave: 1, enemy: 'shadow_blob', count: 6, interval: 2.5, delay: 0.0),
    WaveRow(wave: 2, enemy: 'shadow_blob', count: 6, interval: 2.2, delay: 0.0),
    WaveRow(wave: 2, enemy: 'ink_squid', count: 4, interval: 3.0, delay: 4.0),
    WaveRow(wave: 3, enemy: 'shadow_blob', count: 8, interval: 2.0, delay: 0.0),
    WaveRow(wave: 3, enemy: 'ink_squid', count: 6, interval: 2.5, delay: 3.0),
    WaveRow(wave: 4, enemy: 'shadow_blob', count: 8, interval: 1.8, delay: 0.0),
    WaveRow(wave: 4, enemy: 'ink_squid', count: 6, interval: 2.0, delay: 2.0),
    WaveRow(wave: 4, enemy: 'shadow_jelly', count: 3, interval: 5.0, delay: 5.0),
    WaveRow(wave: 5, enemy: 'boss_squid', count: 1, interval: 1.0, delay: 0.0),
    WaveRow(wave: 5, enemy: 'shadow_blob', count: 6, interval: 3.0, delay: 4.0),
    WaveRow(wave: 6, enemy: 'ink_squid', count: 10, interval: 1.5, delay: 0.0),
    WaveRow(wave: 6, enemy: 'shadow_jelly', count: 4, interval: 4.0, delay: 3.0),
    WaveRow(wave: 7, enemy: 'shadow_blob', count: 12, interval: 1.4, delay: 0.0),
    WaveRow(wave: 7, enemy: 'ink_squid', count: 8, interval: 2.0, delay: 6.0),
    WaveRow(wave: 7, enemy: 'shadow_jelly', count: 5, interval: 3.5, delay: 2.0),
    WaveRow(wave: 8, enemy: 'ink_squid', count: 14, interval: 1.2, delay: 0.0),
    WaveRow(wave: 8, enemy: 'shadow_jelly', count: 6, interval: 3.0, delay: 4.0),
    WaveRow(wave: 9, enemy: 'shadow_blob', count: 14, interval: 1.1, delay: 0.0),
    WaveRow(wave: 9, enemy: 'ink_squid', count: 12, interval: 1.3, delay: 2.0),
    WaveRow(wave: 9, enemy: 'shadow_jelly', count: 8, interval: 2.5, delay: 5.0),
    WaveRow(wave: 10, enemy: 'boss_jelly', count: 1, interval: 1.0, delay: 0.0),
    WaveRow(wave: 10, enemy: 'shadow_jelly', count: 6, interval: 4.0, delay: 6.0),
    WaveRow(wave: 10, enemy: 'ink_squid', count: 10, interval: 1.8, delay: 3.0),
  ];

  /// wave_rules.csv
  static const WaveRules waveRules = WaveRules(firstDelay: 3.0, rest: 5.0, bannerSeconds: 2.5);
}
