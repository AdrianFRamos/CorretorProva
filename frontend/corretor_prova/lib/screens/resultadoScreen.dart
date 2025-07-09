import 'package:flutter/material.dart';

class ResultadoScreen extends StatelessWidget {
  final Map<String, dynamic> resultado;

  const ResultadoScreen({super.key, required this.resultado});

  @override
  Widget build(BuildContext context) {
    // Extrair dados do resultado
    final acertos = resultado['acertos'] ?? 0;
    final erros = resultado['erros'] ?? 0;
    final totalQuestoes = resultado['total_questoes'] ?? 0;
    final porcentagem = resultado['porcentagem_acerto'] ?? 0.0;
    final nota = resultado['nota'] ?? 0.0;
    final aluno = resultado['aluno'] ?? 'N/A';
    final turma = resultado['turma'] ?? 'N/A';
    final problemas = resultado['problemas'] ?? {};

    return Scaffold(
      appBar: AppBar(
        title: Text("Resultado da Correção"),
        backgroundColor: Colors.blue,
        actions: [
          IconButton(
            icon: Icon(Icons.share),
            onPressed: () => _compartilharResultado(context),
            tooltip: 'Compartilhar',
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
                      'Estatísticas',
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
                      ],
                    ),
                    
                    SizedBox(height: 12),
                    
                    // Barra de progresso
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Progresso:', style: TextStyle(fontWeight: FontWeight.bold)),
                        SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: acertos / totalQuestoes,
                          backgroundColor: Colors.red[200],
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                          minHeight: 8,
                        ),
                        SizedBox(height: 4),
                        Text('$acertos de $totalQuestoes questões corretas'),
                      ],
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
                      
                      if (problemas['questoes_multiplas'] > 0)
                        _buildProblemaItem(
                          'Múltiplas marcações',
                          problemas['questoes_multiplas'],
                          'Questões com mais de uma opção marcada',
                          Icons.radio_button_checked,
                        ),
                      
                      if (problemas['questoes_em_branco'] > 0)
                        _buildProblemaItem(
                          'Questões em branco',
                          problemas['questoes_em_branco'],
                          'Questões sem nenhuma marcação',
                          Icons.radio_button_unchecked,
                        ),
                      
                      if (problemas['questoes_nao_detectadas'] > 0)
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
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cor.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icone, color: cor, size: 32),
          SizedBox(height: 8),
          Text(
            valor,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: cor,
            ),
          ),
          Text(
            titulo,
            style: TextStyle(
              fontSize: 12,
              color: cor,
            ),
          ),
        ],
      ),
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
    
    return Container(
      height: 200,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: respostasAluno.length,
        itemBuilder: (context, index) {
          final questao = index + 1;
          final respostaAluno = respostasAluno[index]?.toString() ?? '?';
          final respostaCorreta = gabaritoOficial[index]?.toString() ?? '?';
          final correto = respostaAluno == respostaCorreta;
          
          return Container(
            width: 60,
            margin: EdgeInsets.only(right: 8),
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: correto ? Colors.green[50] : Colors.red[50],
              border: Border.all(
                color: correto ? Colors.green : Colors.red,
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
                  correto ? Icons.check : Icons.close,
                  color: correto ? Colors.green : Colors.red,
                  size: 20,
                ),
                SizedBox(height: 4),
                Text(
                  respostaAluno,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: correto ? Colors.green : Colors.red,
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
    // Implementar compartilhamento
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Funcionalidade de compartilhamento em desenvolvimento')),
    );
  }

  void _mostrarDetalhes(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Detalhes Técnicos'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (resultado['api_flexivel'] == true) ...[
                Text('✅ API Flexível utilizada'),
                Text('Endpoint: ${resultado['endpoint_usado'] ?? 'N/A'}'),
                SizedBox(height: 8),
              ],
              Text('Dados brutos:'),
              SizedBox(height: 4),
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
        ],
      ),
    );
  }
}

