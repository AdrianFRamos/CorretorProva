import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/apiService.dart';
import 'resultadoScreen.dart';

class CameraScreen extends StatefulWidget {
  final String turma;
  final String aluno;
  final Map<String, String> gabaritoOficial;

  const CameraScreen({
    super.key,
    required this.turma,
    required this.aluno,
    required this.gabaritoOficial,
  });

  @override
  _CameraScreenState createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  File? _imagem;
  bool _processando = false;
  String? _erro;

  Future<void> _tirarFoto() async {
    try {
      final picker = ImagePicker();
      final foto = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85, // Otimizar qualidade para upload
        maxWidth: 1920,
        maxHeight: 1080,
      );

      if (foto != null) {
        setState(() {
          _imagem = File(foto.path);
          _erro = null;
        });
      }
    } catch (e) {
      setState(() {
        _erro = 'Erro ao capturar foto: $e';
      });
    }
  }

  Future<void> _selecionarDaGaleria() async {
    try {
      final picker = ImagePicker();
      final foto = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 1080,
      );

      if (foto != null) {
        setState(() {
          _imagem = File(foto.path);
          _erro = null;
        });
      }
    } catch (e) {
      setState(() {
        _erro = 'Erro ao selecionar imagem: $e';
      });
    }
  }

  Future<void> _enviarParaCorrecao() async {
    if (_imagem == null) {
      setState(() {
        _erro = 'Nenhuma imagem selecionada';
      });
      return;
    }

    setState(() {
      _processando = true;
      _erro = null;
    });

    try {
      // Validar gabarito antes de enviar
      final validacao = await ApiService.validarGabarito(widget.gabaritoOficial);
      
      if (!validacao['valido']) {
        throw Exception('Gabarito inválido: ${validacao['erros'].join(', ')}');
      }

      // Enviar para correção usando nova API
      final resultado = await ApiService.corrigirGabarito(
        turma: widget.turma,
        aluno: widget.aluno,
        imagem: _imagem!,
        gabaritoOficial: widget.gabaritoOficial,
        incluirDetalhes: true,
      );

      // Navegar para tela de resultado
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ResultadoScreen(resultado: resultado),
        ),
      );
    } catch (e) {
      setState(() {
        _erro = 'Erro na correção: $e';
        _processando = false;
      });
    }
  }

  void _mostrarPreviewGabarito() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Gabarito Oficial'),
        content: Container(
          width: double.maxFinite,
          height: 300,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Total de questões: ${widget.gabaritoOficial.length}'),
                SizedBox(height: 10),
                ...widget.gabaritoOficial.entries.map((entry) => 
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 2),
                    child: Text('Questão ${entry.key}: ${entry.value}'),
                  )
                ).toList(),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Fechar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Captura da Prova"),
        backgroundColor: Colors.blue,
        actions: [
          IconButton(
            icon: Icon(Icons.assignment),
            onPressed: _mostrarPreviewGabarito,
            tooltip: 'Ver Gabarito',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Informações do aluno
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Informações:', style: TextStyle(fontWeight: FontWeight.bold)),
                    SizedBox(height: 8),
                    Text('Aluno: ${widget.aluno}'),
                    Text('Turma: ${widget.turma}'),
                    Text('Questões: ${widget.gabaritoOficial.length}'),
                  ],
                ),
              ),
            ),

            SizedBox(height: 20),

            // Preview da imagem
            Container(
              height: 300,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
              ),
              child: _imagem == null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.camera_alt, size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text(
                            "Nenhuma imagem capturada",
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        _imagem!,
                        fit: BoxFit.contain,
                        width: double.infinity,
                      ),
                    ),
            ),

            SizedBox(height: 20),

            // Botões de captura
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _processando ? null : _tirarFoto,
                    icon: Icon(Icons.camera_alt),
                    label: Text("Câmera"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _processando ? null : _selecionarDaGaleria,
                    icon: Icon(Icons.photo_library),
                    label: Text("Galeria"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),

            SizedBox(height: 20),

            // Botão de envio
            ElevatedButton(
              onPressed: (_imagem != null && !_processando) ? _enviarParaCorrecao : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: _processando
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                        SizedBox(width: 10),
                        Text("Processando..."),
                      ],
                    )
                  : Text(
                      "Enviar para Correção",
                      style: TextStyle(fontSize: 16),
                    ),
            ),

            // Exibir erro se houver
            if (_erro != null) ...[
              SizedBox(height: 20),
              Card(
                color: Colors.red[50],
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.error, color: Colors.red),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _erro!,
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            SizedBox(height: 20),

            // Dicas
            Card(
              color: Colors.blue[50],
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.lightbulb, color: Colors.blue),
                        SizedBox(width: 8),
                        Text(
                          'Dicas para melhor resultado:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text('• Mantenha o gabarito bem iluminado'),
                    Text('• Evite sombras sobre as marcações'),
                    Text('• Certifique-se que todas as questões estão visíveis'),
                    Text('• Preencha completamente os círculos'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

