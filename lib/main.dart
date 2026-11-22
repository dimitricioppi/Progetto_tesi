
import 'package:flutter/material.dart';
import 'view/menu.dart';

void main() {
  runApp(const HnefataflGame());
}

class HnefataflGame extends StatelessWidget {
  const HnefataflGame({super.key});

  @override
  Widget build(BuildContext context) {

    return MaterialApp(
      title: 'Hnefatafl Game',
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Hnefatafl Game'),
        ),
        body: MainMenu(),
      ),
    );
  }
}
