import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/correcaoModel.dart';
import '../services/correcaoService.dart';
import 'resultadoCorrecaoScreen.dart';

/// Histórico de correções com filtro por turma, acesso à revisão de provas
/// pendentes e exportação das notas da turma em CSV.
class HistoricoScreen extends StatefulWidget {
  const HistoricoScreen({super.key});

  @override
  State<HistoricoScreen> createState() => _HistoricoScreenState();
}

class _HistoricoScreenState extends State<HistoricoScreen> {
  List<Correcao> _correcoes = [];
  bool _carregando = true;
  String? _erro;
  String? _filtroTurma;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      final correcoes = await CorrecaoService.listarCorrecoes(turma: _filtroTurma);
      if (!mounted) return;
      setState(() {
        _correcoes = correcoes;
        _carregando = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _erro = e.mensagem;
        _carregando = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _erro = 'Falha de conexão ao carregar o histórico.';
        _carregando = false;
      });
    }
  }

  Future<void> _exportarCsv() async {
    try {
      final csv = await CorrecaoService.exportarNotasCsv(turma: _filtroTurma);
      if (!mounted) return;
      await Clipboard.setData(ClipboardData(text: csv));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Notas da turma ${_filtroTurma ?? '(todas)'} copiadas em CSV. '
            'Cole em planilha ou arquivo.',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao exportar: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _abrirCorrecao(Correcao resumo) async {
    try {
      // Busca a correção completa (com questões e recortes)
      final completa = await CorrecaoService.obterCorrecao(resumo.id);
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => ResultadoCorrecaoScreen(correcao: completa)),
      );
      if (mounted) _carregar(); // atualiza status após possível revisão
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao abrir correção: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final turmas = _correcoes.map((c) => c.turma).toSet().toList()..sort();
    final pendentes = _correcoes.where((c) => c.precisaRevisao).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Histórico de Correções'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'Exportar notas (CSV)',
            onPressed: _correcoes.isEmpty ? null : _exportarCsv,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _carregar,
          ),
        ],
      ),
      body: _carregando
          ? const Center(child: CircularProgressIndicator())
          : _erro != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_erro!, style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 12),
                      ElevatedButton(
                          onPressed: _carregar, child: const Text('Tentar novamente')),
                    ],
                  ),
                )
              : Column(
                  children: [
                    if (pendentes > 0)
                      Container(
                        width: double.infinity,
                        color: Colors.orange[50],
                        padding: const EdgeInsets.all(10),
                        child: Text(
                          '⚠️ $pendentes prova(s) aguardando revisão manual',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    if (turmas.length > 1 || _filtroTurma != null)
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Wrap(
                          spacing: 6,
                          children: [
                            ChoiceChip(
                              label: const Text('Todas'),
                              selected: _filtroTurma == null,
                              onSelected: (_) {
                                setState(() => _filtroTurma = null);
                                _carregar();
                              },
                            ),
                            ...turmas.map((t) => ChoiceChip(
                                  label: Text(t),
                                  selected: _filtroTurma == t,
                                  onSelected: (_) {
                                    setState(() => _filtroTurma = t);
                                    _carregar();
                                  },
                                )),
                          ],
                        ),
                      ),
                    Expanded(
                      child: _correcoes.isEmpty
                          ? const Center(child: Text('Nenhuma correção registrada.'))
                          : ListView.builder(
                              itemCount: _correcoes.length,
                              itemBuilder: (context, i) =>
                                  _buildItem(_correcoes[i]),
                            ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildItem(Correcao c) {
    final (cor, rotulo) = switch (c.status) {
      'CONFIRMADA' => (Colors.green, 'Confirmada'),
      'PRECISA_REVISAO' => (Colors.deepOrange, 'Pendente de revisão'),
      'REJEITADA_QUALIDADE' => (Colors.red, 'Imagem rejeitada'),
      _ => (Colors.blueGrey, c.status),
    };
    final nota = c.notaFinal ?? c.notaProvisoria;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: cor,
          child: Text(
            nota != null ? nota.toStringAsFixed(1) : '—',
            style: const TextStyle(
                color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text('${c.aluno} — ${c.turma}'),
        subtitle: Text(
          '$rotulo'
          '${c.notaFinal == null && c.notaProvisoria != null ? ' (nota provisória)' : ''}'
          '${c.criadaEm != null ? '\n${c.criadaEm!.substring(0, 16).replaceFirst('T', ' ')}' : ''}',
          style: const TextStyle(fontSize: 12),
        ),
        isThreeLine: c.criadaEm != null,
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _abrirCorrecao(c),
      ),
    );
  }
}
