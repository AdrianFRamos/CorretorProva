import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/correcaoModel.dart';
import 'revisaoScreen.dart';

/// Resultado da correção v2.
///
/// Garante visualmente a regra central do sistema: nota só aparece como
/// CONFIRMADA quando não há nenhuma questão pendente; caso contrário a tela
/// mostra nota provisória e direciona o professor para a revisão manual.
class ResultadoCorrecaoScreen extends StatefulWidget {
  final Correcao correcao;

  const ResultadoCorrecaoScreen({super.key, required this.correcao});

  @override
  State<ResultadoCorrecaoScreen> createState() => _ResultadoCorrecaoScreenState();
}

class _ResultadoCorrecaoScreenState extends State<ResultadoCorrecaoScreen> {
  late Correcao _correcao;

  @override
  void initState() {
    super.initState();
    _correcao = widget.correcao;
  }

  Future<void> _abrirRevisao() async {
    final confirmada = await Navigator.push<Correcao>(
      context,
      MaterialPageRoute(builder: (_) => RevisaoScreen(correcao: _correcao)),
    );
    if (confirmada != null && mounted) {
      setState(() => _correcao = confirmada);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_correcao.rejeitada) return _buildRejeitada(context);

    final resumo = _correcao.resumo;
    final pendentes = resumo?.pendentesRevisao ?? 0;
    final confirmada = _correcao.confirmada;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Resultado da Correção'),
        backgroundColor: confirmada ? Colors.green : Colors.deepOrange,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.copy),
            tooltip: 'Copiar resumo',
            onPressed: () => _copiarResumo(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildCabecalho(),
            const SizedBox(height: 12),
            _buildNota(resumo, confirmada, pendentes),
            if (pendentes > 0) ...[
              const SizedBox(height: 12),
              _buildAlertaRevisao(pendentes),
            ],
            if (_correcao.diagnostico.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildDiagnostico(),
            ],
            const SizedBox(height: 12),
            _buildEstatisticas(resumo),
            const SizedBox(height: 12),
            _buildGradeQuestoes(),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () =>
                  Navigator.of(context).popUntil((route) => route.isFirst),
              icon: const Icon(Icons.home),
              label: const Text('Nova Correção'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCabecalho() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Aluno: ${_correcao.aluno}',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            Text('Turma: ${_correcao.turma}'),
            if (_correcao.confirmadaPor != null)
              Text(
                'Confirmada por: ${_correcao.confirmadaPor}',
                style: TextStyle(fontSize: 12, color: Colors.grey[700]),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildNota(ResumoCorrecao? resumo, bool confirmada, int pendentes) {
    final nota = confirmada
        ? (_correcao.notaFinal ?? resumo?.notaConfirmada ?? 0.0)
        : (resumo?.notaProvisoria ?? 0.0);
    final cor = confirmada
        ? (nota >= 7 ? Colors.green : (nota >= 5 ? Colors.orange : Colors.red))
        : Colors.blueGrey;

    return Card(
      color: cor,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(confirmada ? Icons.verified : Icons.hourglass_top,
                size: 56, color: Colors.white),
            const SizedBox(height: 8),
            Text(
              confirmada
                  ? 'NOTA: ${nota.toStringAsFixed(1)}'
                  : 'NOTA PROVISÓRIA: ${nota.toStringAsFixed(1)}',
              style: const TextStyle(
                  fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            if (!confirmada && resumo != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Pode chegar a ${resumo.notaMaximaPossivel.toStringAsFixed(1)} '
                  'após a revisão das $pendentes pendência(s)',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                confirmada ? 'NOTA CONFIRMADA' : 'AGUARDANDO REVISÃO MANUAL',
                style: const TextStyle(
                    color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertaRevisao(int pendentes) {
    return Card(
      color: Colors.orange[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.warning_amber, color: Colors.deepOrange),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$pendentes questão(ões) não puderam ser corrigidas '
                    'automaticamente com segurança.',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'O sistema nunca atribui resposta quando a leitura é duvidosa '
              '(marcação dupla, fraca, rasura ou ambiguidade). Revise cada uma '
              'para liberar a nota final.',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _abrirRevisao,
              icon: const Icon(Icons.rate_review),
              label: const Text('Revisar Questões Pendentes'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepOrange,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 46),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDiagnostico() {
    return Card(
      color: Colors.blue[50],
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Diagnóstico do processamento',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 6),
            ..._correcao.diagnostico.map((d) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('• $d', style: const TextStyle(fontSize: 12)),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildEstatisticas(ResumoCorrecao? resumo) {
    if (resumo == null) return const SizedBox.shrink();
    Widget item(String titulo, String valor, Color cor, IconData icone) {
      return Expanded(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: cor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: cor.withOpacity(0.3)),
          ),
          child: Column(
            children: [
              Icon(icone, color: cor, size: 22),
              Text(valor,
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold, color: cor)),
              Text(titulo,
                  style: TextStyle(fontSize: 10, color: cor),
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }

    return Row(
      children: [
        item('Acertos', '${resumo.acertos}', Colors.green, Icons.check_circle),
        item('Erros', '${resumo.erros}', Colors.red, Icons.cancel),
        item('Em branco', '${resumo.emBranco}', Colors.grey, Icons.radio_button_unchecked),
        item('Revisão', '${resumo.pendentesRevisao}', Colors.deepOrange, Icons.help),
      ],
    );
  }

  Widget _buildGradeQuestoes() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Questões',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _correcao.questoes.map(_buildCelulaQuestao).toList(),
            ),
            const SizedBox(height: 10),
            const Text(
              'Verde: acerto • Vermelho: erro • Cinza: em branco • '
              'Laranja: pendente de revisão',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCelulaQuestao(QuestaoCorrigida q) {
    final revisada = _correcao.revisoes.containsKey('${q.numero}');
    Color cor;
    String texto;
    if (q.precisaRevisao && !revisada) {
      cor = Colors.deepOrange;
      texto = '?';
    } else if (revisada) {
      final alt = _correcao.revisoes['${q.numero}']?['alternativa'];
      final acertou = alt != null && alt == q.respostaCorreta;
      cor = alt == null ? Colors.grey : (acertou ? Colors.green : Colors.red);
      texto = (alt ?? '–').toString();
    } else if (q.status == 'EM_BRANCO') {
      cor = Colors.grey;
      texto = '–';
    } else {
      cor = (q.acertou ?? false) ? Colors.green : Colors.red;
      texto = q.alternativaDetectada ?? '?';
    }

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: cor.withOpacity(0.15),
        border: Border.all(color: cor, width: 1.5),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('${q.numero}',
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
          Text(texto,
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.bold, color: cor)),
        ],
      ),
    );
  }

  Widget _buildRejeitada(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Imagem Rejeitada'),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.no_photography, size: 72, color: Colors.red),
            const SizedBox(height: 16),
            const Text(
              'A imagem não tem qualidade suficiente para uma correção segura. '
              'Nenhuma nota foi gerada.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ..._correcao.diagnostico.map((d) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text('• $d', textAlign: TextAlign.center),
                )),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.camera_alt),
              label: const Text('Capturar Novamente'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _copiarResumo(BuildContext context) {
    final resumo = _correcao.resumo;
    final texto = '''
Correção de Prova
Aluno: ${_correcao.aluno} • Turma: ${_correcao.turma}
Status: ${_correcao.confirmada ? 'Nota confirmada' : 'Aguardando revisão manual'}
Nota: ${(_correcao.notaFinal ?? resumo?.notaProvisoria ?? 0).toStringAsFixed(1)}${_correcao.confirmada ? '' : ' (provisória)'}
Acertos: ${resumo?.acertos}/${resumo?.totalQuestoes} • Em branco: ${resumo?.emBranco} • Pendentes: ${resumo?.pendentesRevisao}
''';
    Clipboard.setData(ClipboardData(text: texto));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Resumo copiado para a área de transferência')),
    );
  }
}
