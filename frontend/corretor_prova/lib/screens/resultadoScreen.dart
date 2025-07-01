import 'package:flutter/material.dart';

class ResultadoScreen extends StatelessWidget {
  final Map<String, dynamic> resultado;

  const ResultadoScreen({super.key, required this.resultado});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Resultado da Correção")),
      body: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Aluno: ${resultado['aluno']}"),
            Text("Turma: ${resultado['turma']}"),
            Text("Acertos: ${resultado['acertos']}"),
            Text("Erros: ${resultado['erros']}"),
            Text("Nota: ${resultado['nota']}"),
            SizedBox(height: 20),
            Text("Respostas do aluno:"),
            Text(resultado['respostas'].join(", ")),
            SizedBox(height: 10),
            Text("Gabarito oficial:"),
            Text(resultado['gabarito'].join(", ")),
          ],
        ),
      ),
    );
  }
}
