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
  Map<String, List<int>>? configuracaoQuestoes;
  bool apiConectada = false;
  bool verificandoApi = true;
  Map<String, dynamic>? infoApi;
  
  final TextEditingController _numeroQuestoesController = TextEditingController();

  final turmas = ['1N', '2N', '3N', '4N', '5N'];
  final alunos = ['Aluno 01', 'Aluno 02', 'Aluno 03', 'Aluno 04', 'Aluno 05'];

  // Opções de configuração de questões
  String tipoConfiguracao = 'automatico';
  final tiposConfiguracao = {
    'automatico': 'Detecção Automática',
    'duas_tabelas': 'Duas Tabelas',
    'tres_tabelas': 'Três Tabelas',
    'por_materia': 'Por Matéria',
    'personalizado': 'Personalizado',
  };

  @override
  void initState() {
    super.initState();
    _numeroQuestoesController.text = numeroQuestoes.toString();
    _verificarApi();
    _criarGabaritoDefault();
    _atualizarConfiguracaoQuestoes();
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
      Map<String, dynamic>? info = await ApiService.obterInfoApi();
      
      setState(() {
        apiConectada = conectada;
        infoApi = info;
        verificandoApi = false;
      });
      
      if (!conectada) {
        _mostrarErroConexao();
      } else {
        _mostrarInfoApi();
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
        content: Text('❌ API não está respondendo. Verifique a conexão.'),
        backgroundColor: Colors.red,
        action: SnackBarAction(
          label: 'Tentar Novamente',
          onPressed: _verificarApi,
        ),
      ),
    );
  }

  void _mostrarInfoApi() {
    if (infoApi != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ ${infoApi!['nome']} conectada!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _criarGabaritoDefault() {
    gabaritoOficial = GabaritoBuilder()
        .criarSequencial(numeroQuestoes)
        .build();
  }

  void _atualizarConfiguracaoQuestoes() {
    switch (tipoConfiguracao) {
      case 'automatico':
        configuracaoQuestoes = null; // Sistema detecta automaticamente
        break;
      case 'duas_tabelas':
        configuracaoQuestoes = ConfiguradorQuestoes.duasTabelas(numeroQuestoes);
        break;
      case 'tres_tabelas':
        configuracaoQuestoes = ConfiguradorQuestoes.tresTabelas(numeroQuestoes);
        break;
      case 'por_materia':
        configuracaoQuestoes = ConfiguradorQuestoes.porMateria(
          matematica: List.generate(10, (i) => i + 1),
          portugues: List.generate(10, (i) => i + 11),
          ciencias: List.generate(10, (i) => i + 21),
          historia: List.generate(7, (i) => i + 31),
          geografia: List.generate(7, (i) => i + 38),
        );
        break;
      case 'personalizado':
        _mostrarDialogConfiguracaoPersonalizada();
        return;
    }
    setState(() {});
  }

  void _atualizarNumeroQuestoes() {
    final novoNumero = int.tryParse(_numeroQuestoesController.text);
    if (novoNumero != null && novoNumero > 0 && novoNumero <= 200) {
      setState(() {
        numeroQuestoes = novoNumero;
        _criarGabaritoDefault();
        _atualizarConfiguracaoQuestoes();
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
            _atualizarConfiguracaoQuestoes();
          });
        },
      ),
    );
  }

  void _gerarGabaritoAleatorio() {
    final gabaritoAleatorio = ApiService.criarGabaritoOficial(numeroQuestoes);
    
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

  void _mostrarDialogConfiguracaoPersonalizada() {
    showDialog(
      context: context,
      builder: (context) => _ConfiguracaoPersonalizadaDialog(
        numeroQuestoes: numeroQuestoes,
        onSalvar: (config) {
          setState(() {
            configuracaoQuestoes = config;
          });
        },
      ),
    );
  }

  void _testarConfiguracoes() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Teste de Configurações'),
        content: Text('Esta funcionalidade permite testar diferentes configurações de questões com a mesma imagem. Deseja continuar para a tela de câmera?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _irParaCamera(modoTeste: true);
            },
            child: Text('Continuar'),
          ),
        ],
      ),
    );
  }

  void _irParaCamera({bool modoTeste = false}) {
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
          configuracaoQuestoes: configuracaoQuestoes,
          modoTeste: modoTeste,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Sistema Corrigido - v3.0"),
        backgroundColor: Colors.blue,
        actions: [
          IconButton(
            icon: Icon(apiConectada ? Icons.wifi : Icons.wifi_off),
            onPressed: _verificarApi,
            tooltip: apiConectada ? 'API Conectada' : 'API Desconectada',
          ),
          if (apiConectada)
            IconButton(
              icon: Icon(Icons.info),
              onPressed: () => _mostrarInfoDetalhada(),
              tooltip: 'Informações da API',
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
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Icon(
                                apiConectada ? Icons.check_circle : Icons.error,
                                color: apiConectada ? Colors.green : Colors.red,
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  apiConectada 
                                    ? 'Sistema Corrigido Conectado' 
                                    : 'API Desconectada',
                                  style: TextStyle(
                                    color: apiConectada ? Colors.green : Colors.red,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (apiConectada && infoApi != null) ...[
                            SizedBox(height: 8),
                            Text(
                              '${infoApi!['versao']} - ${infoApi!['performance']['eficiencia_deteccao']} eficiência',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.green[700],
                              ),
                            ),
                          ],
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

                  // Configuração do Número de Questões
                  Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Número de Questões:', style: TextStyle(fontWeight: FontWeight.bold)),
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
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  foregroundColor: Colors.white,
                                ),
                                child: Text('Gerar Padrão'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  SizedBox(height: 10),

                  // Configuração de Questões (NOVA FUNCIONALIDADE)
                  Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Configuração de Questões:', style: TextStyle(fontWeight: FontWeight.bold)),
                          SizedBox(height: 10),
                          
                          DropdownButton<String>(
                            value: tipoConfiguracao,
                            isExpanded: true,
                            onChanged: (value) {
                              setState(() {
                                tipoConfiguracao = value!;
                              });
                              _atualizarConfiguracaoQuestoes();
                            },
                            items: tiposConfiguracao.entries.map((entry) => DropdownMenuItem(
                              value: entry.key,
                              child: Text(entry.value),
                            )).toList(),
                          ),
                          
                          SizedBox(height: 10),
                          
                          Container(
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.blue[50],
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              _getDescricaoConfiguracao(),
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
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange,
                                  foregroundColor: Colors.white,
                                ),
                                child: Text('Editar'),
                              ),
                              SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: _importarGabarito,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.purple,
                                  foregroundColor: Colors.white,
                                ),
                                child: Text('Importar'),
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

                  SizedBox(height: 20),

                  // Botões de ação
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: apiConectada ? _irParaCamera : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            padding: EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text(
                            'Corrigir Gabarito',
                            style: TextStyle(fontSize: 18, color: Colors.white),
                          ),
                        ),
                      ),
                      SizedBox(width: 10),
                      ElevatedButton(
                        onPressed: apiConectada ? _testarConfiguracoes : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Icon(Icons.science, color: Colors.white),
                      ),
                    ],
                  ),

                  SizedBox(height: 10),

                  // Informações do sistema
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '🎯 Sistema Corrigido v3.0',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 4),
                        Text('• 95.5% de eficiência (42/44 respostas)', style: TextStyle(fontSize: 12)),
                        Text('• Configuração flexível de questões', style: TextStyle(fontSize: 12)),
                        Text('• Detecção automática de tabelas', style: TextStyle(fontSize: 12)),
                        Text('• Base: Murtaza Hassan Style', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  String _getDescricaoConfiguracao() {
    switch (tipoConfiguracao) {
      case 'automatico':
        return '🤖 O sistema detecta automaticamente quantas tabelas existem e processa todas as questões.';
      case 'duas_tabelas':
        return '📊 Divide as questões em duas tabelas (esquerda e direita).';
      case 'tres_tabelas':
        return '📊 Divide as questões em três tabelas igualmente.';
      case 'por_materia':
        return '📚 Organiza as questões por matéria (Matemática, Português, Ciências, etc.).';
      case 'personalizado':
        return '⚙️ Configuração personalizada definida por você.';
      default:
        return '';
    }
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

  void _mostrarInfoDetalhada() {
    if (infoApi == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Informações da API'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildInfoItem('Nome', infoApi!['nome']),
              _buildInfoItem('Versão', infoApi!['versao']),
              _buildInfoItem('Método', infoApi!['metodo']),
              _buildInfoItem('Base', infoApi!['base']),
              SizedBox(height: 10),
              Text('Performance:', style: TextStyle(fontWeight: FontWeight.bold)),
              _buildInfoItem('Eficiência', infoApi!['performance']['eficiencia_deteccao']),
              _buildInfoItem('Respostas', infoApi!['performance']['respostas_detectadas']),
              _buildInfoItem('Tempo', infoApi!['performance']['tempo_processamento']),
              _buildInfoItem('Status', infoApi!['performance']['status']),
            ],
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

  Widget _buildInfoItem(String label, dynamic value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text('$label:', style: TextStyle(fontWeight: FontWeight.w500)),
          ),
          Expanded(child: Text(value?.toString() ?? 'N/A')),
        ],
      ),
    );
  }
}

// Dialog para configuração personalizada
class _ConfiguracaoPersonalizadaDialog extends StatefulWidget {
  final int numeroQuestoes;
  final Function(Map<String, List<int>>) onSalvar;

  const _ConfiguracaoPersonalizadaDialog({
    required this.numeroQuestoes,
    required this.onSalvar,
  });

  @override
  _ConfiguracaoPersonalizadaDialogState createState() => _ConfiguracaoPersonalizadaDialogState();
}

class _ConfiguracaoPersonalizadaDialogState extends State<_ConfiguracaoPersonalizadaDialog> {
  final Map<String, List<int>> _configuracao = {};
  final TextEditingController _nomeController = TextEditingController();
  final TextEditingController _questoesController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Configuração Personalizada'),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: Column(
          children: [
            // Adicionar novo grupo
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _nomeController,
                    decoration: InputDecoration(
                      labelText: 'Nome do grupo',
                      hintText: 'ex: matematica',
                    ),
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _questoesController,
                    decoration: InputDecoration(
                      labelText: 'Questões',
                      hintText: 'ex: 1,2,3,4,5',
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _adicionarGrupo,
                  icon: Icon(Icons.add),
                ),
              ],
            ),
            
            SizedBox(height: 16),
            
            // Lista de grupos configurados
            Expanded(
              child: ListView.builder(
                itemCount: _configuracao.length,
                itemBuilder: (context, index) {
                  final entry = _configuracao.entries.elementAt(index);
                  return ListTile(
                    title: Text(entry.key),
                    subtitle: Text('Questões: ${entry.value.join(', ')}'),
                    trailing: IconButton(
                      icon: Icon(Icons.delete),
                      onPressed: () {
                        setState(() {
                          _configuracao.remove(entry.key);
                        });
                      },
                    ),
                  );
                },
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
          onPressed: _configuracao.isNotEmpty ? () {
            widget.onSalvar(_configuracao);
            Navigator.pop(context);
          } : null,
          child: Text('Salvar'),
        ),
      ],
    );
  }

  void _adicionarGrupo() {
    final nome = _nomeController.text.trim();
    final questoesTexto = _questoesController.text.trim();
    
    if (nome.isEmpty || questoesTexto.isEmpty) return;
    
    try {
      final questoes = questoesTexto
          .split(',')
          .map((s) => int.parse(s.trim()))
          .toList();
      
      setState(() {
        _configuracao[nome] = questoes;
        _nomeController.clear();
        _questoesController.clear();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Formato inválido. Use números separados por vírgula.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

// Dialogs existentes (mantidos para compatibilidade)
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
      content: SizedBox(
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

class _ImportarGabaritoDialog extends StatefulWidget {
  final Function(Map<String, String>) onImportar;

  const _ImportarGabaritoDialog({required this.onImportar});

  @override
  _ImportarGabaritoDialogState createState() => _ImportarGabaritoDialogState();
}

class _ImportarGabaritoDialogState extends State<_ImportarGabaritoDialog> {
  final TextEditingController _controller = TextEditingController();
  final String _exemplo = '''Exemplo de formato:
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
      content: SizedBox(
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

