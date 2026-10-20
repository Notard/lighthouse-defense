import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/painting.dart' show decodeImageFromList;

/// `assets/images/<file>`을 읽어 판의 그림 캐시(`game.images`)에 넣고 돌려준다.
///
/// `game.images.load`는 읽기에 실패하면 캐시 안쪽 Future의 오류가 처리되지 않은 채 남아(테스트에서는 실패로 보고된다)
/// 직접 읽어 디코딩한 뒤 캐시에 넣는다. 실패하면 이 Future만 오류로 끝난다 (부르는 쪽이 임시 모양으로 계속 그린다).
Future<Image> loadGameImage(FlameGame game, String file) async {
  if (game.images.containsKey(file)) return game.images.load(file);
  final image = await decodeImageFromList(await game.assets.readBinaryFile('images/$file'));
  if (game.images.containsKey(file)) {
    // 그사이 다른 쪽이 먼저 넣었다
    image.dispose();
    return game.images.load(file);
  }
  game.images.add(file, image);
  return image;
}

/// 시트 JSON(`actions.<동작>`)의 동작 하나 (design.md §3-2 시트 읽기 다지기).
class SheetAction {
  const SheetAction({required this.frames, this.fps = defaultFps, this.loop = false, this.event});

  /// `fps`가 없을 때 쓰는 값.
  static const double defaultFps = 12;

  /// `frames`는 꼭 있어야 한다 (없거나 정수가 아니면 [FormatException]). `fps` 없으면 12, `loop` 없으면 false.
  factory SheetAction.fromJson(Map<String, dynamic> json) {
    final frames = json['frames'];
    if (frames is! int || frames < 1) {
      throw FormatException('frames must be a positive integer', frames);
    }
    final fps = json['fps'] ?? defaultFps;
    final loop = json['loop'] ?? false;
    final event = json['event'];
    if (fps is! num || fps <= 0) throw FormatException('fps must be a positive number', fps);
    if (loop is! bool) throw FormatException('loop must be a bool', loop);
    if (event != null && event is! int) throw FormatException('event must be an integer', event);
    return SheetAction(frames: frames, fps: fps.toDouble(), loop: loop, event: event as int?);
  }

  /// 프레임 수.
  final int frames;

  /// 초당 프레임.
  final double fps;

  /// 되풀이하는지.
  final bool loop;

  /// 이벤트(쏘기·생산·피해)가 일어나는 프레임 번호 (1부터, 없으면 null).
  final int? event;
}

/// 캐릭터 하나의 스프라이트 시트 묶음 (tools/pack_sheets.py가 만든 `<캐릭터>.json` + 동작별 WebP, design.md §3).
///
/// 그림 만들기: gen_art.py ref → cut_parts.py → blender_cutout.py → pack_sheets.py (tools/build_sprites.sh).
class CharacterArt {
  CharacterArt._(this.name, this.frameSize, this.anchor, this.bbox, this.muzzle, this._data, this._images);

  final String name;

  /// 한 프레임 크기 (px).
  final Vector2 frameSize;

  /// 프레임 안의 발 위치. 자리 가운데에 맞추는 기준점이다.
  final Vector2 anchor;

  /// 첫 동작 첫 프레임에서 그림이 있는 영역 (표시 크기·카드 그림).
  final Rect bbox;

  /// 이벤트(쏘기·빛 내기 등)가 일어나는 위치 (없을 수 있음).
  final Vector2? muzzle;

  final Map<String, SheetAction> _data;
  final Map<String, Image> _images;

  Iterable<String> get actions => _data.keys;

  /// 동작의 이벤트 프레임 번호 (1부터, 없으면 null).
  int? eventFrame(String action) => _data[action]?.event;

  bool loops(String action) => _data[action]!.loop;

  int frameCount(String action) => _data[action]!.frames;

  double fps(String action) => _data[action]!.fps;

  /// 발에서 머리 끝까지의 높이 (프레임 px).
  double get characterHeight => anchor.y - bbox.top;

  /// 키가 [height] 논리 px로 보이게 하는 배율.
  double scaleForHeight(double height) => height / characterHeight;

  SpriteAnimation animation(String action) {
    final a = _data[action]!;
    return SpriteAnimation.fromFrameData(
      _images[action]!,
      SpriteAnimationData.sequenced(
        amount: a.frames,
        stepTime: 1 / a.fps,
        textureSize: frameSize,
        loop: a.loop,
      ),
    );
  }

  /// [action]을 계속 되풀이하는 그림. 발이 [foot]에 오고 키가 [height] (자리 위·소개 창).
  SpriteAnimationComponent actor(String action, {required double height, required Vector2 foot}) {
    final s = scaleForHeight(height);
    final anim = animation(action);
    return SpriteAnimationComponent(
      animation: loops(action) ? anim : (anim.clone()..loop = true),
      size: frameSize * s,
      anchor: Anchor(anchor.x / frameSize.x, anchor.y / frameSize.y),
      position: foot,
    );
  }

  /// 첫 동작 첫 프레임 (카드 그림, 놓기 전 미리보기).
  Sprite firstFrame(String action) =>
      Sprite(_images[action]!, srcPosition: Vector2.zero(), srcSize: frameSize);

  static final Map<String, Future<CharacterArt>> _cache = {};

  /// `assets/images/<name>/`을 읽는다. 같은 캐릭터는 한 번만 읽는다.
  /// 읽기에 실패하면 캐시에 남기지 않는다 (다음에 다시 읽는다). 그 폴더는 pubspec.yaml assets에 등록해야 한다.
  static Future<CharacterArt> load(FlameGame game, String name) {
    final cached = _cache[name];
    if (cached != null) return cached;
    late final Future<CharacterArt> future;
    future = _load(game, name).then(
      (art) => _loaded[name] = art,
      onError: (Object error, StackTrace stack) {
        if (identical(_cache[name], future)) _cache.remove(name);
        Error.throwWithStackTrace(error, stack);
      },
    );
    _cache[name] = future;
    return future;
  }

  /// 읽는 중이거나 다 읽은 그림이 캐시에 있는지.
  static bool isCached(String name) => _cache.containsKey(name);

  /// 다 읽은 그림 (아직이면 null). 기다릴 수 없는 곳(그리기 도중 등)에서 쓴다.
  static CharacterArt? loaded(String name) => _loaded[name];
  static final Map<String, CharacterArt> _loaded = {};

  static Future<CharacterArt> _load(FlameGame game, String name) async {
    final json = await game.assets.readJson('images/$name/$name.json');
    final actions = (json['actions'] as Map<String, dynamic>).map(
      (k, v) => MapEntry(k, SheetAction.fromJson(v as Map<String, dynamic>)),
    );
    final images = <String, Image>{
      for (final action in actions.keys)
        action: await loadGameImage(game, '$name/$action.webp'),
    };
    Vector2 vec(List<dynamic> v) => Vector2((v[0] as num).toDouble(), (v[1] as num).toDouble());
    final b = (json['bbox'] as List).map((v) => (v as num).toDouble()).toList();
    return CharacterArt._(
      name,
      vec(json['frame'] as List),
      vec(json['anchor'] as List),
      Rect.fromLTRB(b[0], b[1], b[2], b[3]),
      json['muzzle'] == null ? null : vec(json['muzzle'] as List),
      actions,
      images,
    );
  }

  /// 테스트에서 게임을 새로 만들 때 이전 게임의 그림 캐시를 비운다.
  static void clearCache() {
    _cache.clear();
    _loaded.clear();
  }
}
