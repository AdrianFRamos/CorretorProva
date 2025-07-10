import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ResultadoScreen extends StatelessWidget {
  final Map<String, dynamic> resultado;
  final bool modoTeste;

  const ResultadoScreen({
    super.key, 
    required this.resultado,
    this.modoTeste = false,
  });

  @override
  Widget build(BuildContext context) {
    if (modoTeste) {
      return _buildResultadoTeste(context);
    } else {
      return _buildResultadoNormal(context);
    }
  }

  Widget _buildResultadoNormal(BuildContext context) {
    // Extrair dados do resultado
    final acertos = resultado['acertos'] ?? 0;
    final erros = resultado['erros'] ?? 0;
    final totalQuestoes = resultado['total_questoes'] ?? 0;
    final questoesRespondidas = resultado['questoes_respondidas'] ?? 0;
    final porcentagem = (resultado['porcentagem_acerto'] as num?)?.toDouble() ?? 0.0;
    final eficiencia = (resultado['eficiencia'] as num?)?.toDouble() ?? 0.0;
    final nota = (resultado['nota'] as num?)?.toDouble() ?? 0.0;
    final aluno = resultado['aluno'] ?? 'N/A';
    final turma = resultado['turma'] ?? 'N/A';
    final problemas = resultado['problemas'] ?? {};
    final apiInfo = resultado['api_info'] ?? {};

    return Scaffold(
      appBar: AppBar(
        title: Text("Resultado - Sistema Corrigido"),
        backgroundColor: Colors.blue,
        actions: [
          IconButton(
            icon: Icon(Icons.share),
            onPressed: () => _compartilharResultado(context),
            tooltip: 'Compartilhar',
          ),
          IconButton(
            icon: Icon(Icons.info),
            onPressed: () => _mostrarInfoTecnica(context),
            tooltip: 'Info Técnica',
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
                    Text(
                      'Informações do Aluno',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 12),
                    _buildInfoRow('Aluno:', aluno),
                    _buildInfoRow('Turma:', turma),
                    _buildInfoRow('Total de questões:', '$totalQuestoes'),
                    _buildInfoRow('Questões detectadas:', '$questoesRespondidas'),
                    _buildInfoRow('Eficiência de detecção:', '${eficiencia.toStringAsFixed(1)}%'),
                  ],
                ),
              ),
            ),

            SizedBox(height: 16),

            // Resultado principal
            Card(
              color: _getCorNota(nota),
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  children: [
                    Icon(
                      _getIconeNota(nota),
                      size: 64,
                      color: Colors.white,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'NOTA: ${nota.toStringAsFixed(1)}',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      '${porcentagem.toStringAsFixed(1)}% de acerto',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white70,
                      ),
                    ),
                    SizedBox(height: 8),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Sistema Corrigido v${apiInfo['versao'] ?? '3.0'}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 16),

            // Estatísticas detalhadas
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Estatísticas Detalhadas',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 16),
                    
                    Row(
                      children: [
                        Expanded(
                          child: _buildEstatisticaCard(
                            'Acertos',
                            '$acertos',
                            Colors.green,
                            Icons.check_circle,
                          ),
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: _buildEstatisticaCard(
                            'Erros',
                            '$erros',
                            Colors.red,
                            Icons.cancel,
                          ),
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: _buildEstatisticaCard(
                            'Detectadas',
                            '$questoesRespondidas',
                            Colors.blue,
                            Icons.visibility,
                          ),
                        ),
                      ],
                    ),
                    
                    SizedBox(height: 16),
                    
                    // Barras de progresso
                    _buildBarraProgresso(
                      'Acertos',
                      acertos,
                      totalQuestoes,
                      Colors.green,
                    ),
                    SizedBox(height: 8),
                    _buildBarraProgresso(
                      'Detecção',
                      questoesRespondidas,
                      totalQuestoes,
                      Colors.blue,
                    ),
                  ],
                ),
              ),
            ),

            // Problemas detectados (se houver)
            if (_temProblemas(problemas)) ...[
              SizedBox(height: 16),
              Card(
                color: Colors.orange[50],
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.warning, color: Colors.orange),
                          SizedBox(width: 8),
                          Text(
                            'Problemas Detectados',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange[800],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12),
                      
                      if ((problemas['questoes_multiplas'] ?? 0) > 0)
                        _buildProblemaItem(
                          'Múltiplas marcações',
                          problemas['questoes_multiplas'],
                          'Questões com mais de uma opção marcada',
                          Icons.radio_button_checked,
                        ),
                      
                      if ((problemas['questoes_em_branco'] ?? 0) > 0)
                        _buildProblemaItem(
                          'Questões em branco',
                          problemas['questoes_em_branco'],
                          'Questões sem nenhuma marcação detectada',
                          Icons.radio_button_unchecked,
                        ),
                      
                      if ((problemas['questoes_nao_detectadas'] ?? 0) > 0)
                        _buildProblemaItem(
                          'Não detectadas',
                          problemas['questoes_nao_detectadas'],
                          'Questões que não puderam ser processadas',
                          Icons.visibility_off,
                        ),
                    ],
                  ),
                ),
              ),
            ],

            SizedBox(height: 16),

            // Gabarito comparativo
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Comparativo de Respostas',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 12),
                    
                    if (resultado['respostas'] != null && resultado['gabarito'] != null)
                      _buildComparativoRespostas()
                    else
                      Text('Detalhes das respostas não disponíveis'),
                  ],
                ),
              ),
            ),

            // Informações do sistema
            SizedBox(height: 16),
            Card(
              color: Colors.blue[50],
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info, color: Colors.blue),
                        SizedBox(width: 8),
                        Text(
                          'Informações do Sistema',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[800],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text('Método: ${apiInfo['metodo'] ?? 'Sistema Corrigido'}', style: TextStyle(fontSize: 12)),
                    Text('Base: ${apiInfo['base'] ?? 'Murtaza Hassan Style'}', style: TextStyle(fontSize: 12)),
                    Text('Versão: ${apiInfo['versao'] ?? '3.0'}', style: TextStyle(fontSize: 12)),
                    if (resultado['configuracao_usada'] != null)
                      Text('Configuração: ${resultado['configuracao_usada']}', style: TextStyle(fontSize: 12)),
                  ],
                ),
              ),
            ),

            SizedBox(height: 20),

            // Botões de ação
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
                    icon: Icon(Icons.home),
                    label: Text('Nova Correção'),
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
                    onPressed: () => _mostrarDetalhes(context),
                    icon: Icon(Icons.info),
                    label: Text('Detalhes'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultadoTeste(BuildContext context) {
    // Para modo teste, mostrar comparação de configurações
    return Scaffold(
      appBar: AppBar(
        title: Text("Resultado do Teste"),
        backgroundColor: Colors.green,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              color: Colors.green[50],
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  children: [
                    Icon(Icons.science, size: 48, color: Colors.green),
                    SizedBox(height: 8),
                    Text(
                      'Teste de Configurações',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.green[800],
                      ),
                    ),
                    Text(
                      'Comparação de diferentes métodos de processamento',
                      style: TextStyle(color: Colors.green[600]),
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 16),

            // Mostrar resultados de cada configuração testada
            if (resultado['resultados'] != null) ...[
              ...((resultado['resultados'] as Map<String, dynamic>).entries.map((entry) => 
                _buildCardConfiguracao(entry.key, entry.value)
              )),
            ] else ...[
              Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Nenhum resultado de teste disponível'),
                ),
              ),
            ],

            SizedBox(height: 20),

            ElevatedButton.icon(
              onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
              icon: Icon(Icons.home),
              label: Text('Voltar ao Início'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardConfiguracao(String nome, Map<String, dynamic> dados) {
    final acertos = dados['acertos'] ?? 0;
    final total = dados['total_questoes'] ?? 0;
    final eficiencia = (dados['eficiencia'] as num?)?.toDouble() ?? 0.0;
    final nota = (dados['nota'] as num?)?.toDouble() ?? 0.0;

    return Card(
      margin: EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  nome.toUpperCase(),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getCorNota(nota),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${nota.toStringAsFixed(1)}',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: Text('Acertos: $acertos/$total')),
                Expanded(child: Text('Eficiência: ${eficiencia.toStringAsFixed(1)}%')),
              ],
            ),
            SizedBox(height: 8),
            LinearProgressIndicator(
              value: acertos / total,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(_getCorNota(nota)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String valor) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontWeight: FontWeight.w500)),
          Text(valor, style: TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildEstatisticaCard(String titulo, String valor, Color cor, IconData icone) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cor.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icone, color: cor, size: 24),
          SizedBox(height: 4),
          Text(
            valor,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: cor,
            ),
          ),
          Text(
            titulo,
            style: TextStyle(
              fontSize: 10,
              color: cor,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildBarraProgresso(String label, int valor, int total, Color cor) {
    final porcentagem = total > 0 ? (valor / total) : 0.0;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(fontWeight: FontWeight.bold)),
            Text('$valor/$total (${(porcentagem * 100).toStringAsFixed(1)}%)'),
          ],
        ),
        SizedBox(height: 4),
        LinearProgressIndicator(
          value: porcentagem,
          backgroundColor: Colors.grey[300],
          valueColor: AlwaysStoppedAnimation<Color>(cor),
          minHeight: 6,
        ),
      ],
    );
  }

  Widget _buildProblemaItem(String titulo, int quantidade, String descricao, IconData icone) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icone, color: Colors.orange[700], size: 20),
          SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$titulo: $quantidade',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  descricao,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComparativoRespostas() {
    final respostasAluno = resultado['respostas'] as List<dynamic>? ?? [];
    final gabaritoOficial = resultado['gabarito'] as List<dynamic>? ?? [];
    
    return SizedBox(
      height: 200,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: respostasAluno.length,
        itemBuilder: (context, index) {
          final questao = index + 1;
          final respostaAluno = respostasAluno[index]?.toString() ?? '?';
          final respostaCorreta = gabaritoOficial[index]?.toString() ?? '?';
          final correto = respostaAluno == respostaCorreta;
          final detectado = respostaAluno != '?';
          
          return Container(
            width: 60,
            margin: EdgeInsets.only(right: 8),
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: !detectado 
                ? Colors.grey[100]
                : correto 
                  ? Colors.green[50] 
                  : Colors.red[50],
              border: Border.all(
                color: !detectado 
                  ? Colors.grey
                  : correto 
                    ? Colors.green 
                    : Colors.red,
                width: 2,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Q$questao',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                Icon(
                  !detectado 
                    ? Icons.help_outline
                    : correto 
                      ? Icons.check 
                      : Icons.close,
                  color: !detectado 
                    ? Colors.grey
                    : correto 
                      ? Colors.green 
                      : Colors.red,
                  size: 20,
                ),
                SizedBox(height: 4),
                Text(
                  respostaAluno,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: !detectado 
                      ? Colors.grey
                      : correto 
                        ? Colors.green 
                        : Colors.red,
                  ),
                ),
                Text(
                  '($respostaCorreta)',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Color _getCorNota(double nota) {
    if (nota >= 7.0) return Colors.green;
    if (nota >= 5.0) return Colors.orange;
    return Colors.red;
  }

  IconData _getIconeNota(double nota) {
    if (nota >= 7.0) return Icons.sentiment_very_satisfied;
    if (nota >= 5.0) return Icons.sentiment_neutral;
    return Icons.sentiment_dissatisfied;
  }

  bool _temProblemas(Map<String, dynamic> problemas) {
    return (problemas['questoes_multiplas'] ?? 0) > 0 ||
           (problemas['questoes_em_branco'] ?? 0) > 0 ||
           (problemas['questoes_nao_detectadas'] ?? 0) > 0;
  }

  void _compartilharResultado(BuildContext context) {
    final texto = '''
Resultado da Correção - Sistema Corrigido v3.0

Aluno: ${resultado['aluno']}
Turma: ${resultado['turma']}
Nota: ${(resultado['nota'] as num?)?.toStringAsFixed(1) ?? '0.0'}
Acertos: ${resultado['acertos']}/${resultado['total_questoes']}
Eficiência de detecção: ${(resultado['eficiencia'] as num?)?.toStringAsFixed(1) ?? '0.0'}%

Processado com ${resultado['api_info']?['metodo'] ?? 'Sistema Corrigido'}
''';

    Clipboard.setData(ClipboardData(text: texto));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Resultado copiado para a área de transferência'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _mostrarDetalhes(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Detalhes Completos'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Dados completos da correção:', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  resultado.toString(),
                  style: TextStyle(fontSize: 10, fontFamily: 'monospace'),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Fechar'),
          ),
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: resultado.toString()));
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Dados copiados para área de transferência')),
              );
            },
            child: Text('Copiar'),
          ),
        ],
      ),
    );
  }

  void _mostrarInfoTecnica(BuildContext context) {
    final apiInfo = resultado['api_info'] ?? {};
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Informações Técnicas'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildInfoTecnicaItem('Método', apiInfo['metodo']),
              _buildInfoTecnicaItem('Base', apiInfo['base']),
              _buildInfoTecnicaItem('Versão', apiInfo['versao']),
              _buildInfoTecnicaItem('Timestamp', apiInfo['timestamp']),
              SizedBox(height: 10),
              Text('Performance:', style: TextStyle(fontWeight: FontWeight.bold)),
              _buildInfoTecnicaItem('Eficiência', '${(resultado['eficiencia'] as num?)?.toStringAsFixed(1) ?? '0.0'}%'),
              _buildInfoTecnicaItem('Questões detectadas', '${resultado['questoes_respondidas']}/${resultado['total_questoes']}'),
              _buildInfoTecnicaItem('Configuração', resultado['configuracao_usada']),
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

  Widget _buildInfoTecnicaItem(String label, dynamic value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text('$label:', style: TextStyle(fontWeight: FontWeight.w500)),
          ),
          Expanded(child: Text(value?.toString() ?? 'N/A')),
        ],
      ),
    );
  }
}

