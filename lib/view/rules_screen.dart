
import 'package:flutter/material.dart';

class RulesScreen extends StatelessWidget {
  const RulesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blueGrey,
      appBar: AppBar(title: const Text("Regole del Gioco")),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Colors.black,
                    width: 3,
                  ),
                ),

                child: SingleChildScrollView(

                  padding: EdgeInsets.symmetric(vertical: 10,horizontal: 10),

                  child :RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: "Regole del gioco:\n\n",
                          style: TextStyle(fontSize: 24, color: Color.fromARGB(
                              204, 255, 247, 103)),
                        ),
                        TextSpan(
                          text: '''
- Inizia il nero.

- Ogni giocatore muove un pezzo a turno.

- Tutti i pezzi possono muoversi di un qualsiasi numero di caselle ortogonalmente.

- I pezzi non possono saltare altri pezzi; inoltre solo il re può fermarsi nelle caselle speciali (quelle non bianche).

- Se si muove un pezzo adiacente a un pezzo avversario in modo tale che la mossa crea un sandwich verticale o
  orizzontale contenente un singolo pezzo avversario fra i propri pezzi, allora quel pezzo viene catturato e rimosso dalla scacchiera. 

- Il re può essere catturato solo se circondato ortogonalmente dai pezzi neri, ad eccezione di quando è adiacente al centro
  della scacchiera: in quel caso va circondato sui rimanenti 3 lati.

- È possibile catturare più pezzi contemporaneamente se con una sola mossa si formano più sandwich di cattura.

- Un metodo speciale di cattura permette di catturare un gruppo di pedine avversarie (re escluso) nel caso esse siano tutte adiacenti
  a un lato della scacchiera: se si riesce a circondare tale gruppo con le proprie pedine in modo che non possano più muoversi,
  allora il gruppo è catturato e rimosso dalla scacchiera (tranne il re se è interno al gruppo).

- Le quattro caselle agli angoli sono dette caselle di fuga: se il re muove in una di queste caselle il bianco vince.

- Le caselle di fuga sono dette anche ostili e possono essere utilizzate come sostituto a una propria pedina per eseguire una cattura.

- Anche la casella centrale è ostile, ma se occupata dal re lo è solo nei confronti del nero.

- Se il re viene catturato i neri vincono.

- Se il nero riesce a circondare il bianco in modo tale che sia impossibile per lui raggiungere il bordo della scacchiera
  con tutte le sue pedine, allora il nero vince (questa condizione non viene applicata quando si gioca contro la CPU).

- Se viene ripetuta la stessa situazione tre volte di fila il nero vince.

- Se il re bianco è adiacente a un bordo, può muoversi ed è circondato da un forte di proprie pedine tale che il forte
  è impenetrabile, allora il bianco vince (non applicato se si gioca contro la CPU).

- Se il bianco cattura tutti i pezzi neri vince.

- Lo stallo causa la sconfitta del giocatore in stallo.

- Se in 100 mosse non vi è stata alcuna cattura, allora il gioco finisce in pareggio.
''',
                          style: TextStyle(fontSize: 20, color: Color.fromARGB(
                              204, 255, 247, 103)),
                        ),
                      ],
                    ),
                  )
                ),
              ),
            ),
            Container(
              margin: const EdgeInsets.only(top: 32, left: 20, right: 20, bottom: 96),
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  textStyle: const TextStyle(fontSize: 18),
                  backgroundColor: const Color.fromARGB(229, 255, 247, 103),
                ),
                child: const Text("Return to menu"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
