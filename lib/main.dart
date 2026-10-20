import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import 'game/config.dart';
import 'game/lighthouse_game.dart';
import 'game/strings.dart';

void main() {
  runApp(const LighthouseApp());
}

/// 앱 루트 (1단계: 판 하나만).
class LighthouseApp extends StatelessWidget {
  const LighthouseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: Strings.title,
      debugShowCheckedModeBanner: false,
      home: ColoredBox(color: GameConfig.deepSea, child: GameWidget(game: LighthouseGame())),
    );
  }
}
