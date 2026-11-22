
import 'package:flutter/material.dart';
import 'game_mode_selection.dart';
import 'board_size.dart';
import 'rules_screen.dart';
import 'package:flutter/services.dart';

class MainMenu extends StatelessWidget {
  MainMenu({super.key});

  int _boardSize = 11;

  int get boardSize => _boardSize;

  set boardSize(int value) {
    if (value >= 7 && value <= 15) {
      _boardSize = value;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blueGrey,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              "Hnefatafl",
              style: TextStyle(fontSize: 64, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 40),

            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => GameModeSelection(boardSize: _boardSize),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                textStyle: const TextStyle(fontSize: 18),
                backgroundColor: const Color.fromARGB(229, 255, 247, 103),
              ),
              child: const Text("Start"),
            ),

            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const RulesScreen()),
                );
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                textStyle: const TextStyle(fontSize: 18),
                backgroundColor: const Color.fromARGB(229, 255, 247, 103),
              ),
              child: const Text("Rules"),
            ),

            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: () async {
                final selected = await Navigator.push<int>(
                  context,
                  MaterialPageRoute(builder: (_) => BoardSize(menu: this,)),
                );
                if (selected != null) {
                  boardSize = selected;
                }
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                textStyle: const TextStyle(fontSize: 18),
                backgroundColor: const Color.fromARGB(229, 255, 247, 103),
              ),
              child: const Text("Board Size"),
            ),

            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: () {
                SystemNavigator.pop();
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                textStyle: const TextStyle(fontSize: 18),
                backgroundColor: const Color.fromARGB(229, 255, 247, 103),
              ),
              child: const Text("Exit"),
            ),
          ],
        ),
      ),
    );
  }
}
