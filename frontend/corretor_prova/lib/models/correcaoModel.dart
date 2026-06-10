/// Models tipados do contrato v2 da API de correção.
///
/// Espelham a resposta estruturada do pipeline: status por questão,
/// confiança, motivo da dúvida, resumo com nota provisória/confirmada.
library;

class QuestaoCorrigida {
  final int numero;
  final String status; // OK | EM_BRANCO | MULTIPLA | FRACA | AMBIGUA | NAO_LIDA
  final String? alternativaDetectada;
  final String? respostaCorreta;
  final double confianca;
  final String? motivo;
  final bool precisaRevisao;
  final bool? acertou; // null enquanto pendente de revisão
  final Map<String, double> preenchimentos;
  final String? recorteBase64; // recorte da questão, presente quando pendente

  QuestaoCorrigida({
    required this.numero,
    required this.status,
    this.alternativaDetectada,
    this.respostaCorreta,
    required this.confianca,
    this.motivo,
    required this.precisaRevisao,
    this.acertou,
    this.preenchimentos = const {},
    this.recorteBase64,
  });

  factory QuestaoCorrigida.fromJson(Map<String, dynamic> json) {
    return QuestaoCorrigida(
      numero: json['numero'] as int,
      status: json['status'] as String? ?? 'NAO_LIDA',
      alternativaDetectada: json['alternativa_detectada'] as String?,
      respostaCorreta: json['resposta_correta'] as String?,
      confianca: (json['confianca'] as num?)?.toDouble() ?? 0.0,
      motivo: json['motivo'] as String?,
      precisaRevisao: json['precisa_revisao'] as bool? ?? false,
      acertou: json['acertou'] as bool?,
      preenchimentos: (json['preenchimentos'] as Map<String, dynamic>? ?? {})
          .map((k, v) => MapEntry(k, (v as num).toDouble())),
      recorteBase64: json['recorte'] as String?,
    );
  }
}

class ResumoCorrecao {
  final int totalQuestoes;
  final int acertos;
  final int erros;
  final int emBranco;
  final int pendentesRevisao;
  final double notaProvisoria;
  final double notaMaximaPossivel;
  final double? notaConfirmada; // null enquanto houver pendência

  ResumoCorrecao({
    required this.totalQuestoes,
    required this.acertos,
    required this.erros,
    required this.emBranco,
    required this.pendentesRevisao,
    required this.notaProvisoria,
    required this.notaMaximaPossivel,
    this.notaConfirmada,
  });

  factory ResumoCorrecao.fromJson(Map<String, dynamic> json) {
    return ResumoCorrecao(
      totalQuestoes: json['total_questoes'] as int? ?? 0,
      acertos: json['acertos'] as int? ?? 0,
      erros: json['erros'] as int? ?? 0,
      emBranco: json['em_branco'] as int? ?? 0,
      pendentesRevisao: json['pendentes_revisao'] as int? ?? 0,
      notaProvisoria: (json['nota_provisoria'] as num?)?.toDouble() ?? 0.0,
      notaMaximaPossivel:
          (json['nota_maxima_possivel'] as num?)?.toDouble() ?? 0.0,
      notaConfirmada: (json['nota_confirmada'] as num?)?.toDouble(),
    );
  }
}

class Correcao {
  final int id;
  final String turma;
  final String aluno;

  /// CONFIRMADA | PRECISA_REVISAO | REJEITADA_QUALIDADE | APROVADA_AUTOMATICA
  final String status;
  final double? notaProvisoria;
  final double? notaFinal;
  final String? criadaEm;
  final String? confirmadaEm;
  final String? confirmadaPor;
  final List<QuestaoCorrigida> questoes;
  final ResumoCorrecao? resumo;
  final List<String> diagnostico;
  final Map<String, dynamic> revisoes;

  Correcao({
    required this.id,
    required this.turma,
    required this.aluno,
    required this.status,
    this.notaProvisoria,
    this.notaFinal,
    this.criadaEm,
    this.confirmadaEm,
    this.confirmadaPor,
    this.questoes = const [],
    this.resumo,
    this.diagnostico = const [],
    this.revisoes = const {},
  });

  bool get confirmada => status == 'CONFIRMADA';
  bool get rejeitada => status == 'REJEITADA_QUALIDADE';
  bool get precisaRevisao => status == 'PRECISA_REVISAO';

  List<QuestaoCorrigida> get questoesPendentes => questoes
      .where((q) => q.precisaRevisao && !revisoes.containsKey('${q.numero}'))
      .toList();

  factory Correcao.fromJson(Map<String, dynamic> json) {
    final resultado = json['resultado'] as Map<String, dynamic>? ?? {};
    return Correcao(
      id: json['id'] as int,
      turma: json['turma'] as String? ?? '',
      aluno: json['aluno'] as String? ?? '',
      status: json['status'] as String? ?? '',
      notaProvisoria: (json['nota_provisoria'] as num?)?.toDouble(),
      notaFinal: (json['nota_final'] as num?)?.toDouble(),
      criadaEm: json['criada_em'] as String?,
      confirmadaEm: json['confirmada_em'] as String?,
      confirmadaPor: json['confirmada_por'] as String?,
      questoes: (resultado['questoes'] as List<dynamic>? ?? [])
          .map((q) => QuestaoCorrigida.fromJson(q as Map<String, dynamic>))
          .toList(),
      resumo: resultado['resumo'] != null
          ? ResumoCorrecao.fromJson(resultado['resumo'] as Map<String, dynamic>)
          : null,
      diagnostico: (resultado['diagnostico'] as List<dynamic>? ?? [])
          .map((d) => d.toString())
          .toList(),
      revisoes: json['revisoes'] as Map<String, dynamic>? ?? {},
    );
  }
}
