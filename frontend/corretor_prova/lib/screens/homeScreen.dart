import 'package:flutter/material.dart';
import 'cameraScreen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String turmaSelecionada = '1N';
  String alunoSelecionado = 'Aluno 01';

  final turmas = ['1N', '3N', '5N'];
  final alunos = ['Aluno 01', 'Aluno 02', 'Aluno 03'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Selecionar Aluno")),
      body: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          children: [
            DropdownButton<String>(
              value: turmaSelecionada,
              onChanged: (value) => setState(() => turmaSelecionada = value!),
              items: turmas.map((turma) => DropdownMenuItem(
                value: turma,
                child: Text(turma),
              )).toList(),
            ),
            SizedBox(height: 20),
            DropdownButton<String>(
              value: alunoSelecionado,
              onChanged: (value) => setState(() => alunoSelecionado = value!),
              items: alunos.map((aluno) => DropdownMenuItem(
                value: aluno,
                child: Text(aluno),
              )).toList(),
            ),
            SizedBox(height: 40),
            ElevatedButton(
              child: Text("Tirar Foto da Prova"),
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(
                  builder: (_) => CameraScreen(
                    turma: turmaSelecionada,
                    aluno: alunoSelecionado,
                  ),
                ));
              },
            )
          ],
        ),
      ),
    );
  }
}
