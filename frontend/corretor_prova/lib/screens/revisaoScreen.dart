import 'dart:convert';

import 'package:flutter/material.dart';

import '../models/correcaoModel.dart';
import '../services/correcaoService.dart';

/// Tela de revisão manual: o professor decide cada questão duvidosa vendo o
/// recorte da imagem, a leitura do sistema, a confiança e o motivo da dúvida.
/// A nota só pode ser confirmada quando não restar nenhuma pendência.
class RevisaoScreen extends StatefulWidget {
  final Correcao correcao;

  const RevisaoScreen({super.key, required this.correcao});

  @override
  State<RevisaoScreen> createState() => _RevisaoScreenState();
}

class _RevisaoScreenState extends State<RevisaoScreen> {
  late List<QuestaoCorrigida> _pendentes;
  final Map<int, String?> _decisoes = {}; // numero -> alternativa (null = em branco)
  final Set<int> _enviadas = {};
  ResumoCorrecao? _resumo;
  bool _processando = false;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _pendentes = widget.correcao.questoesPendentes;
    _resumo = widget.correcao.resumo;
  }

  int get _pendentesRestantes =>
      _pendentes.where((q) => !_enviadas.contains(q.numero)).length;

  Future<void> _enviarDecisao(QuestaoCorrigida questao) async {
    if (!_decisoes.containsKey(questao.numero)) return;
    setState(() {
      _processando = true;
      _erro = null;
    });
    try {
      final resumo = await CorrecaoService.revisarQuestao(
        widget.correcao.id,
        questao.numero,
        _decisoes[questao.numero],
      );
      if (!mounted) return;
      setState(() {
        _enviadas.add(questao.numero);
        _resumo = resumo;
        _processando = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _erro = e.mensagem;
        _processando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _erro = 'Falha de conexão ao salvar a revisão. Tente novamente.';
        _processando = false;
      });
    }
  }

  Future<void> _confirmarNota() async {
    setState(() {
      _processando = true;
      _erro = null;
    });
    try {
      final confirmada = await CorrecaoService.confirmarCorrecao(widget.correcao.id);
      if (!mounted) return;
      Navigator.pop(context, confirmada);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _erro = e.mensagem;
        _processando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _erro = 'Falha de conexão ao confirmar. Tente novamente.';
        _processando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final alternativas = _alternativasDisponiveis();
    final podeConfirmar = _pendentesRestantes == 0 && !_processando;

    return Scaffold(
      appBar: AppBar(
        title: Text('Revisão Manual (${widget.correcao.aluno})'),
        backgroundColor: Colors.deepOrange,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Status da revisão
          Container(
            width: double.infinity,
            color: _pendentesRestantes > 0 ? Colors.orange[50] : Colors.green[50],
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _pendentesRestantes > 0
                      ? '⚠️ $_pendentesRestantes questão(ões) aguardando sua decisão'
                      : '✅ Todas as questões revisadas — você já pode confirmar a nota',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                if (_resumo != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Nota parcial: ${_resumo!.notaProvisoria.toStringAsFixed(1)} '
                      '(acertos: ${_resumo!.acertos}/${_resumo!.totalQuestoes})',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
              ],
            ),
          ),
          if (_erro != null)
            Container(
              width: double.infinity,
              color: Colors.red[50],
              padding: const EdgeInsets.all(12),
              child: Text(_erro!, style: const TextStyle(color: Colors.red)),
            ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _pendentes.length,
              itemBuilder: (context, index) =>
                  _buildCardQuestao(_pendentes[index], alternativas),
            ),
          ),
          // Confirmação da nota — só habilita sem pendências (a API valida de novo)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: ElevatedButton.icon(
                onPressed: podeConfirmar ? _confirmarNota : null,
                icon: const Icon(Icons.verified),
                label: Text(
                  _pendentesRestantes > 0
                      ? 'Revise todas as questões para confirmar'
                      : 'Confirmar Nota Final',
                  style: const TextStyle(fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 52),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<String> _alternativasDisponiveis() {
    final letras = <String>{};
    for (final q in widget.correcao.questoes) {
      letras.addAll(q.preenchimentos.keys);
    }
    final lista = letras.toList()..sort();
    return lista.isEmpty ? ['A', 'B', 'C', 'D', 'E'] : lista;
  }

  Widget _buildCardQuestao(QuestaoCorrigida questao, List<String> alternativas) {
    final enviada = _enviadas.contains(questao.numero);
    final decisao = _decisoes[questao.numero];

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: enviada ? Colors.green[50] : null,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: enviada ? Colors.green : Colors.deepOrange,
                  child: Text(
                    '${questao.numero}',
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _descricaoStatus(questao.status),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                if (enviada) const Icon(Icons.check_circle, color: Colors.green),
              ],
            ),
            if (questao.motivo != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  questao.motivo!,
                  style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                ),
              ),
            // Recorte da questão na imagem corrigida
            if (questao.recorteBase64 != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.memory(
                    base64Decode(questao.recorteBase64!),
                    fit: BoxFit.contain,
                    width: double.infinity,
                    gaplessPlayback: true,
                  ),
                ),
              ),
            // Percentuais lidos por alternativa
            Wrap(
              spacing: 6,
              children: questao.preenchimentos.entries
                  .map((e) => Chip(
                        visualDensity: VisualDensity.compact,
                        label: Text(
                          '${e.key}: ${(e.value * 100).toStringAsFixed(0)}%',
                          style: const TextStyle(fontSize: 11),
                        ),
                      ))
                  .toList(),
            ),
            Text(
              'Gabarito: ${questao.respostaCorreta ?? '?'}  •  '
              'Confiança da leitura: ${(questao.confianca * 100).toStringAsFixed(0)}%',
              style: TextStyle(fontSize: 12, color: Colors.grey[700]),
            ),
            const SizedBox(height: 8),
            // Decisão do professor
            Wrap(
              spacing: 6,
              children: [
                ...alternativas.map((alt) => ChoiceChip(
                      label: Text(alt),
                      selected: decisao == alt,
                      onSelected: enviada || _processando
                          ? null
                          : (_) => setState(() => _decisoes[questao.numero] = alt),
                    )),
                ChoiceChip(
                  label: const Text('Em branco'),
                  selected: _decisoes.containsKey(questao.numero) && decisao == null,
                  onSelected: enviada || _processando
                      ? null
                      : (_) => setState(() => _decisoes[questao.numero] = null),
                ),
              ],
            ),
            if (!enviada)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: _decisoes.containsKey(questao.numero) && !_processando
                      ? () => _enviarDecisao(questao)
                      : null,
                  icon: const Icon(Icons.save),
                  label: const Text('Salvar decisão'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _descricaoStatus(String status) {
    switch (status) {
      case 'MULTIPLA':
        return 'Múltiplas marcações detectadas';
      case 'FRACA':
        return 'Marcação fraca ou parcial';
      case 'AMBIGUA':
        return 'Leitura ambígua';
      case 'NAO_LIDA':
        return 'Questão não localizada na imagem';
      default:
        return 'Revisão necessária';
    }
  }
}
