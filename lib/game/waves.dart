import 'dart:math' as math;

import 'enemy.dart';
import 'geometry.dart';
import 'lighthouse_game.dart';
import 'strings.dart';
import 'tables.g.dart';

/// 웨이브 진행 (design.md §7, 표 `waves.csv`·`wave_rules.csv`). 웨이브 판에서만 판이 들고 있다.
///
/// - 판이 시작되면 `first_delay`초 뒤 웨이브 1. 깨면 `rest`초 쉬고 다음 웨이브, 마지막 웨이브를 깨면 이김
/// - 웨이브 n의 줄마다: 시작에서 delay + k × interval초에 k번째(0부터) 적. 각도는 씨앗 무작위로 0 이상 360 미만
/// - 때 맞춤: 웨이브가 시작된 뒤 **첫 [tick]부터** 웨이브 시간이 흐르고 delay 0인 적은 그 첫 tick에서 나온다.
///   깸은 tick에서 판정하고, 쉬는 시간은 깬 tick의 **다음 tick부터** 센다
/// - 판이 멈추면(카드 창·놓기·꺼짐) 판이 [tick]을 부르지 않으므로 시간이 흐르지 않는다
class WaveRunner {
  WaveRunner(int seed) : _random = math.Random(seed);

  final math.Random _random;

  /// 마지막 웨이브 번호 (표의 가장 큰 번호).
  static final int waveCount = Tables.waves.map((w) => w.wave).reduce(math.max);

  /// 지금(또는 막 깬) 웨이브 번호 (첫 웨이브 전 0).
  int wave = 0;

  /// 깨고 다음을 기다리는 중 (첫 웨이브 전 기다림도 참).
  bool resting = true;

  /// 이번 웨이브에서 지금까지 나온 적 수.
  int spawned = 0;

  /// 떠 있는 알림 글 (없으면 null).
  String? banner;
  double _bannerLeft = 0;

  /// 쉬는 시간 (첫 웨이브 전이면 first_delay, 깬 뒤면 rest까지 센다).
  double _restTime = 0;

  /// 이번 웨이브 시간과 줄마다 나온 수.
  double _waveTime = 0;
  List<WaveRow> _rows = const [];
  List<int> _rowSpawned = const [];

  /// 이번 웨이브에 나올 적 수 합계.
  int get _total => _rows.fold(0, (sum, r) => sum + r.count);

  /// 지금 바로 웨이브 [n]을 시작한다 (쉬는 시간·남은 스폰은 버림). 적은 다음 [tick]부터 나온다.
  void start(int n) {
    wave = n;
    resting = false;
    spawned = 0;
    _waveTime = 0;
    _rows = [for (final r in Tables.waves) if (r.wave == n) r];
    _rowSpawned = List.filled(_rows.length, 0);
    final boss = _rows.any((r) => Tables.enemies[r.enemy]!.boss);
    banner = boss ? Strings.bossComing : Strings.waveBanner(n);
    _bannerLeft = Tables.waveRules.bannerSeconds;
  }

  /// [dt]초 흘린다 (판이 멈추지 않았고 dt > 0일 때만 판이 부른다). 마지막 웨이브를 깨면 참을 돌려준다.
  bool tick(LighthouseGame game, double dt) {
    if (banner != null) {
      _bannerLeft -= dt;
      if (_bannerLeft <= 0) banner = null;
    }
    if (resting) {
      _restTime += dt;
      final wait = wave == 0 ? Tables.waveRules.firstDelay : Tables.waveRules.rest;
      if (_restTime >= wait) start(wave + 1);
      return false;
    }

    _waveTime += dt;
    for (var i = 0; i < _rows.length; i++) {
      final r = _rows[i];
      while (_rowSpawned[i] < r.count && r.delay + _rowSpawned[i] * r.interval <= _waveTime) {
        _rowSpawned[i]++;
        spawned++;
        game.spawnEnemy(r.enemy, normalizeDeg(_random.nextDouble() * 360));
      }
    }

    // 다 나왔고 판에 쓰러지는 중이 아닌 적이 없으면 깸
    final alive = game.enemies.any((e) => e.state != EnemyState.dying);
    if (spawned >= _total && !alive) {
      if (wave >= waveCount) return true;
      // 쉬는 시간은 이 tick이 아니라 다음 tick부터 센다 (여기서 바로 돌아간다)
      resting = true;
      _restTime = 0;
    }
    return false;
  }
}
