
import 'package:flutter/material.dart';
import '../model/state.dart';

class Piece extends StatelessWidget {
  final int isPlayer1;  // Determines if the piece belongs to player 1 or 2
  final bool isKing;
  final bool isBigBoard;



  const Piece({super.key, required this.isPlayer1, required this.isKing,
               required this.isBigBoard});

  @override
  Widget build(BuildContext context) {

    double iconSize = 20;

    if(isBigBoard == true){
      iconSize = 10;
    }


    return Container(
      margin: EdgeInsets.all(6.0),  // Add spacing around the piece
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.black,
      ),

      child: Container(
        margin: EdgeInsets.all(1.0),  // Add spacing around the piece
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isPlayer1 > 0 ? Colors.white : Colors.black,
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                spreadRadius: 1,
                blurRadius: 3,
                offset: Offset(0, 3)
            )
          ],
        ),
        child: Icon(
            size: iconSize,
            Icons.add,
            color: isPlayer1 == 1 ? (isKing ? Colors.black : Colors.white)
                : Colors.black,
        ),
      )
    );
  }
}