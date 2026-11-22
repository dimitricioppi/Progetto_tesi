
import 'package:flutter/material.dart';
import 'menu.dart';

class BoardSize extends StatelessWidget {
  final MainMenu _menu;

  const BoardSize({super.key, required MainMenu menu}) : _menu = menu;

  @override
  Widget build(BuildContext context) {
    final List<Map<String, int>> sizes = [
      {"Very Small": 7},
      {"Small": 9},
      {"Standard": 11},
      {"Big": 13},
      {"Very Big": 15},
    ];

    return Scaffold(
      backgroundColor: Colors.blueGrey,
      appBar: AppBar(
        title: const Text("Select Board Size"),
        backgroundColor: Colors.black87,
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: sizes.map((entry) {
            final label = entry.keys.first;
            final value = entry.values.first;

            return Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              child: ElevatedButton(
                onPressed: () {

                  _menu.boardSize = value;

                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => _menu),
                        (route) => false,
                  );
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  textStyle: const TextStyle(fontSize: 18),
                  backgroundColor: const Color.fromARGB(229, 255, 247, 103),
                ),
                child: Text(label),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
