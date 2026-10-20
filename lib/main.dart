import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import 'game/config.dart';
import 'game/lighthouse_game.dart';
import 'game/strings.dart';

void main() {
  runApp(const LighthouseApp());
}

/// 앱 루트 (판 하나만, 카드 판. 7단계 웨이브 전까지 연습 스폰을 켠다).
class LighthouseApp extends StatelessWidget {
  const LighthouseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: Strings.title,
      debugShowCheckedModeBanner: false,
      home: ColoredBox(color: GameConfig.deepSea, child: GameWidget(game: LighthouseGame(practice: true, cards: true))),
    );
  }
}
