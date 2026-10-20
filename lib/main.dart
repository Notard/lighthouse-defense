import 'dart:math' as math;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import 'game/config.dart';
import 'game/lighthouse_game.dart';
import 'game/strings.dart';

void main() {
  runApp(const LighthouseApp());
}

/// 앱 루트: 카드·웨이브 판 하나. 다시 하기를 누르면 새 판(새 씨앗)으로 바꿔 끼운다 (design.md §7).
class LighthouseApp extends StatefulWidget {
  const LighthouseApp({super.key});

  @override
  State<LighthouseApp> createState() => _LighthouseAppState();
}

class _LighthouseAppState extends State<LighthouseApp> {
  final _random = math.Random();
  late LighthouseGame _game = _newGame();

  LighthouseGame _newGame() =>
      LighthouseGame(cards: true, waves: true, seed: _random.nextInt(1 << 31), onRestart: _restart);

  void _restart() => setState(() => _game = _newGame());

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: Strings.title,
      debugShowCheckedModeBanner: false,
      // 판이 바뀌면 GameWidget도 새로 (ObjectKey)
      home: ColoredBox(color: GameConfig.deepSea, child: GameWidget(key: ObjectKey(_game), game: _game)),
    );
  }
}
