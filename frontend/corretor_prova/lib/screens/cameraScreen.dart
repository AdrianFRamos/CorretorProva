import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/apiService.dart';
import 'resultadoScreen.dart';

class CameraScreen extends StatefulWidget {
  final String turma;
  final String aluno;

  const CameraScreen({super.key, required this.turma, required this.aluno});

  @override
  _CameraScreenState createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  File? _imagem;

  Future<void> _tirarFoto() async {
    final picker = ImagePicker();
    final foto = await picker.pickImage(source: ImageSource.camera);

    if (foto != null) {
      setState(() {
        _imagem = File(foto.path);
      });
    }
  }

  void _enviar() async {
    if (_imagem == null) return;
    final resultado = await ApiService.enviarProva(
      turma: widget.turma,
      aluno: widget.aluno,
      imagem: _imagem!,
    );

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ResultadoScreen(resultado: resultado),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Captura da Prova")),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _imagem == null
              ? Text("Nenhuma imagem capturada")
              : Image.file(_imagem!),
          SizedBox(height: 20),
          ElevatedButton(onPressed: _tirarFoto, child: Text("Tirar Foto")),
          SizedBox(height: 10),
          ElevatedButton(onPressed: _enviar, child: Text("Enviar para Correção")),
        ],
      ),
    );
  }
}
