import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../screens/cameraScreen.dart';
import '../services/apiService.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String turmaSelecionada = '1N';
  String alunoSelecionado = 'Aluno 01';
  int numeroQuestoes = 44; // Padrão, mas totalmente editável
  Map<String, String> gabaritoOficial = {};
  bool apiConectada = false;
  bool verificandoApi = true;
  
  final TextEditingController _numeroQuestoesController = TextEditingController();

  final turmas = ['1N', '3N', '5N'];
  final alunos = ['Aluno 01', 'Aluno 02', 'Aluno 03'];

  @override
  void initState() {
    super.initState();
    _numeroQuestoesController.text = numeroQuestoes.toString();
    _verificarApi();
    _criarGabaritoDefault();
  }

  @override
  void dispose() {
    _numeroQuestoesController.dispose();
    super.dispose();
  }

  Future<void> _verificarApi() async {
    setState(() => verificandoApi = true);
    
    try {
      bool conectada = await ApiService.verificarSaude();
      setState(() {
        apiConectada = conectada;
        verificandoApi = false;
      });
      
      if (!conectada) {
        _mostrarErroConexao();
      }
    } catch (e) {
      setState(() {
        apiConectada = false;
        verificandoApi = false;
      });
      _mostrarErroConexao();
    }
  }

  void _mostrarErroConexao() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Erro: API não está respondendo. Verifique a conexão.'),
        backgroundColor: Colors.red,
        action: SnackBarAction(
          label: 'Tentar Novamente',
          onPressed: _verificarApi,
        ),
      ),
    );
  }

  void _criarGabaritoDefault() {
    gabaritoOficial = GabaritoBuilder()
        .criarSequencial(numeroQuestoes)
        .build();
  }

  void _atualizarNumeroQuestoes() {
    final novoNumero = int.tryParse(_numeroQuestoesController.text);
    if (novoNumero != null && novoNumero > 0 && novoNumero <= 200) {
      setState(() {
        numeroQuestoes = novoNumero;
        _criarGabaritoDefault();
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Número de questões deve ser entre 1 e 200'),
          backgroundColor: Colors.orange,
        ),
      );
      _numeroQuestoesController.text = numeroQuestoes.toString();
    }
  }

  void _editarGabarito() {
    showDialog(
      context: context,
      builder: (context) => _GabaritoDialog(
        gabaritoAtual: gabaritoOficial,
        numeroQuestoes: numeroQuestoes,
        onSalvar: (novoGabarito) {
          setState(() {
            gabaritoOficial = novoGabarito;
          });
        },
      ),
    );
  }

  void _importarGabarito() {
    showDialog(
      context: context,
      builder: (context) => _ImportarGabaritoDialog(
        onImportar: (gabarito) {
          setState(() {
            gabaritoOficial = gabarito;
            numeroQuestoes = gabarito.length;
            _numeroQuestoesController.text = numeroQuestoes.toString();
          });
        },
      ),
    );
  }

  void _gerarGabaritoAleatorio() {
    final opcoes = ['A', 'B', 'C', 'D', 'E'];
    final gabaritoAleatorio = <String, String>{};
    
    for (int i = 1; i <= numeroQuestoes; i++) {
      gabaritoAleatorio[i.toString()] = opcoes[(i - 1) % 5]; // Padrão cíclico
    }
    
    setState(() {
      gabaritoOficial = gabaritoAleatorio;
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Gabarito padrão gerado para $numeroQuestoes questões'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _irParaCamera() {
    if (!apiConectada) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('API não está conectada. Verifique a conexão.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (gabaritoOficial.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Configure o gabarito oficial antes de continuar.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CameraScreen(
          turma: turmaSelecionada,
          aluno: alunoSelecionado,
          gabaritoOficial: gabaritoOficial,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Correção de Gabarito - Flexível"),
        backgroundColor: Colors.blue,
        actions: [
          IconButton(
            icon: Icon(apiConectada ? Icons.wifi : Icons.wifi_off),
            onPressed: _verificarApi,
            tooltip: apiConectada ? 'API Conectada' : 'API Desconectada',
          ),
        ],
      ),
      body: verificandoApi
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Status da API
                  Card(
                    color: apiConectada ? Colors.green[50] : Colors.red[50],
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(
                            apiConectada ? Icons.check_circle : Icons.error,
                            color: apiConectada ? Colors.green : Colors.red,
                          ),
                          SizedBox(width: 8),
                          Text(
                            apiConectada ? 'API Conectada (v2.0 Melhorada)' : 'API Desconectada',
                            style: TextStyle(
                              color: apiConectada ? Colors.green : Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  SizedBox(height: 20),
                  
                  // Seleção de Turma e Aluno
                  Row(
                    children: [
                      Expanded(
                        child: Card(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Turma:', style: TextStyle(fontWeight: FontWeight.bold)),
                                DropdownButton<String>(
                                  value: turmaSelecionada,
                                  isExpanded: true,
                                  onChanged: (value) => setState(() => turmaSelecionada = value!),
                                  items: turmas.map((turma) => DropdownMenuItem(
                                    value: turma,
                                    child: Text(turma),
                                  )).toList(),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Card(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Aluno:', style: TextStyle(fontWeight: FontWeight.bold)),
                                DropdownButton<String>(
                                  value: alunoSelecionado,
                                  isExpanded: true,
                                  onChanged: (value) => setState(() => alunoSelecionado = value!),
                                  items: alunos.map((aluno) => DropdownMenuItem(
                                    value: aluno,
                                    child: Text(aluno),
                                  )).toList(),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: 10),

                  // Configuração do Número de Questões (LIVRE)
                  Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Número de Questões (LIVRE):', style: TextStyle(fontWeight: FontWeight.bold)),
                          SizedBox(height: 10),
                          
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _numeroQuestoesController,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                    LengthLimitingTextInputFormatter(3),
                                  ],
                                  decoration: InputDecoration(
                                    labelText: 'Número de questões',
                                    hintText: 'Digite qualquer número (1-200)',
                                    border: OutlineInputBorder(),
                                    suffixIcon: IconButton(
                                      icon: Icon(Icons.check),
                                      onPressed: _atualizarNumeroQuestoes,
                                    ),
                                  ),
                                  onSubmitted: (_) => _atualizarNumeroQuestoes(),
                                ),
                              ),
                              SizedBox(width: 10),
                              ElevatedButton(
                                onPressed: _gerarGabaritoAleatorio,
                                child: Text('Gerar Padrão'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ],
                          ),
                          
                          SizedBox(height: 10),
                          
                          Container(
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.blue[50],
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '💡 Dica: Digite qualquer número de questões (ex: 10, 44, 100). O sistema é totalmente flexível!',
                              style: TextStyle(fontSize: 12, color: Colors.blue[800]),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  SizedBox(height: 10),

                  // Configuração do Gabarito
                  Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Gabarito Oficial:', style: TextStyle(fontWeight: FontWeight.bold)),
                          SizedBox(height: 10),
                          
                          Row(
                            children: [
                              Expanded(
                                child: Text('${gabaritoOficial.length} questões configuradas'),
                              ),
                              ElevatedButton(
                                onPressed: _editarGabarito,
                                child: Text('Editar'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                              SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: _importarGabarito,
                                child: Text('Importar'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.purple,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ],
                          ),
                          
                          SizedBox(height: 10),
                          
                          // Preview do gabarito
                          Container(
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              _criarPreviewGabarito(),
                              style: TextStyle(fontSize: 12, fontFamily: 'monospace'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  SizedBox(height: 30),

                  // Botão principal
                  ElevatedButton(
                    onPressed: apiConectada ? _irParaCamera : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      'Tirar Foto da Prova (${gabaritoOficial.length} questões)',
                      style: TextStyle(fontSize: 18, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  String _criarPreviewGabarito() {
    if (gabaritoOficial.isEmpty) {
      return 'Nenhum gabarito configurado';
    }
    
    List<String> preview = [];
    int maxPreview = 15;
    
    for (int i = 1; i <= numeroQuestoes && i <= maxPreview; i++) {
      preview.add('$i:${gabaritoOficial[i.toString()] ?? '?'}');
    }
    
    if (numeroQuestoes > maxPreview) {
      preview.add('...(+${numeroQuestoes - maxPreview} questões)');
    }
    
    return preview.join(' ');
  }
}

// Dialog para editar gabarito (sem limitação)
class _GabaritoDialog extends StatefulWidget {
  final Map<String, String> gabaritoAtual;
  final int numeroQuestoes;
  final Function(Map<String, String>) onSalvar;

  const _GabaritoDialog({
    required this.gabaritoAtual,
    required this.numeroQuestoes,
    required this.onSalvar,
  });

  @override
  _GabaritoDialogState createState() => _GabaritoDialogState();
}

class _GabaritoDialogState extends State<_GabaritoDialog> {
  late Map<String, String> gabarito;
  final opcoes = ['A', 'B', 'C', 'D', 'E'];

  @override
  void initState() {
    super.initState();
    gabarito = Map.from(widget.gabaritoAtual);
    
    // Garantir que todas as questões tenham uma resposta
    for (int i = 1; i <= widget.numeroQuestoes; i++) {
      if (!gabarito.containsKey(i.toString())) {
        gabarito[i.toString()] = 'A'; // Padrão
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Editar Gabarito (${widget.numeroQuestoes} questões)'),
      content: Container(
        width: double.maxFinite,
        height: 400,
        child: widget.numeroQuestoes <= 50 
          ? _buildGridView()
          : _buildListView(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () {
            widget.onSalvar(gabarito);
            Navigator.pop(context);
          },
          child: Text('Salvar'),
        ),
      ],
    );
  }

  Widget _buildGridView() {
    return GridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        childAspectRatio: 1.5,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: widget.numeroQuestoes,
      itemBuilder: (context, index) {
        int questao = index + 1;
        String questaoStr = questao.toString();
        
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Q$questao', style: TextStyle(fontSize: 12)),
            DropdownButton<String>(
              value: gabarito[questaoStr],
              isExpanded: true,
              onChanged: (value) {
                setState(() {
                  gabarito[questaoStr] = value!;
                });
              },
              items: opcoes.map((opcao) => DropdownMenuItem(
                value: opcao,
                child: Text(opcao),
              )).toList(),
            ),
          ],
        );
      },
    );
  }

  Widget _buildListView() {
    return ListView.builder(
      itemCount: widget.numeroQuestoes,
      itemBuilder: (context, index) {
        int questao = index + 1;
        String questaoStr = questao.toString();
        
        return ListTile(
          title: Text('Questão $questao'),
          trailing: DropdownButton<String>(
            value: gabarito[questaoStr],
            onChanged: (value) {
              setState(() {
                gabarito[questaoStr] = value!;
              });
            },
            items: opcoes.map((opcao) => DropdownMenuItem(
              value: opcao,
              child: Text(opcao),
            )).toList(),
          ),
        );
      },
    );
  }
}

// Dialog para importar gabarito
class _ImportarGabaritoDialog extends StatefulWidget {
  final Function(Map<String, String>) onImportar;

  const _ImportarGabaritoDialog({required this.onImportar});

  @override
  _ImportarGabaritoDialogState createState() => _ImportarGabaritoDialogState();
}

class _ImportarGabaritoDialogState extends State<_ImportarGabaritoDialog> {
  final TextEditingController _controller = TextEditingController();
  String _exemplo = '''Exemplo de formato:
1:A
2:B
3:C
4:D
5:E

Ou separado por vírgulas:
A,B,C,D,E,A,B,C,D,E''';

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Importar Gabarito'),
      content: Container(
        width: double.maxFinite,
        height: 300,
        child: Column(
          children: [
            Text(_exemplo, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            SizedBox(height: 10),
            Expanded(
              child: TextField(
                controller: _controller,
                maxLines: null,
                expands: true,
                decoration: InputDecoration(
                  hintText: 'Cole ou digite o gabarito aqui...',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _importar,
          child: Text('Importar'),
        ),
      ],
    );
  }

  void _importar() {
    try {
      final texto = _controller.text.trim();
      final gabarito = <String, String>{};
      
      if (texto.contains(':')) {
        // Formato questao:resposta
        final linhas = texto.split('\n');
        for (final linha in linhas) {
          if (linha.contains(':')) {
            final partes = linha.split(':');
            if (partes.length == 2) {
              final questao = partes[0].trim();
              final resposta = partes[1].trim().toUpperCase();
              if (['A', 'B', 'C', 'D', 'E'].contains(resposta)) {
                gabarito[questao] = resposta;
              }
            }
          }
        }
      } else if (texto.contains(',')) {
        // Formato separado por vírgulas
        final respostas = texto.split(',');
        for (int i = 0; i < respostas.length; i++) {
          final resposta = respostas[i].trim().toUpperCase();
          if (['A', 'B', 'C', 'D', 'E'].contains(resposta)) {
            gabarito[(i + 1).toString()] = resposta;
          }
        }
      }
      
      if (gabarito.isNotEmpty) {
        widget.onImportar(gabarito);
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Formato inválido. Verifique o exemplo.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao importar: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

