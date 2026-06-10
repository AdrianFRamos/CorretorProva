import 'package:flutter_test/flutter_test.dart';
import 'package:corretor_prova/models/correcaoModel.dart';

Map<String, dynamic> _respostaApi({
  String status = 'CONFIRMADA',
  double? notaFinal = 10.0,
  int pendentes = 0,
  Map<String, dynamic>? revisoes,
}) {
  return {
    'id': 1,
    'turma': '1N',
    'aluno': 'Maria',
    'status': status,
    'nota_provisoria': 8.0,
    'nota_final': notaFinal,
    'criada_em': '2026-06-10T10:00:00',
    'confirmada_em': notaFinal != null ? '2026-06-10T10:05:00' : null,
    'confirmada_por': notaFinal != null ? 'prof@escola.com' : null,
    'revisoes': revisoes ?? {},
    'resultado': <String, dynamic>{
      'status': status == 'CONFIRMADA' ? 'APROVADA_AUTOMATICA' : status,
      'diagnostico': ['aviso de teste'],
      'questoes': [
        {
          'numero': 1,
          'status': 'OK',
          'alternativa_detectada': 'A',
          'resposta_correta': 'A',
          'confianca': 0.95,
          'motivo': null,
          'precisa_revisao': false,
          'acertou': true,
          'preenchimentos': {'A': 0.9, 'B': 0.05},
        },
        {
          'numero': 2,
          'status': 'MULTIPLA',
          'alternativa_detectada': null,
          'resposta_correta': 'B',
          'confianca': 0.0,
          'motivo': 'Múltiplas marcações detectadas: A, B.',
          'precisa_revisao': true,
          'acertou': null,
          'preenchimentos': {'A': 0.8, 'B': 0.75},
          'recorte': 'aW1n',
        },
      ],
      'resumo': {
        'total_questoes': 2,
        'acertos': 1,
        'erros': 0,
        'em_branco': 0,
        'pendentes_revisao': pendentes,
        'nota_provisoria': 5.0,
        'nota_maxima_possivel': 10.0,
        'nota_confirmada': pendentes == 0 ? 5.0 : null,
      },
    },
  };
}

void main() {
  group('Correcao.fromJson', () {
    test('parseia correção confirmada com questões e resumo', () {
      final c = Correcao.fromJson(_respostaApi());

      expect(c.id, 1);
      expect(c.confirmada, isTrue);
      expect(c.notaFinal, 10.0);
      expect(c.questoes, hasLength(2));
      expect(c.resumo!.totalQuestoes, 2);
      expect(c.diagnostico, contains('aviso de teste'));
    });

    test('questão pendente nunca traz alternativa detectada', () {
      final c = Correcao.fromJson(_respostaApi(
          status: 'PRECISA_REVISAO', notaFinal: null, pendentes: 1));
      final pendente = c.questoes.firstWhere((q) => q.precisaRevisao);

      expect(pendente.alternativaDetectada, isNull,
          reason: 'regra de segurança: dúvida não tem resposta automática');
      expect(pendente.motivo, isNotNull);
      expect(pendente.recorteBase64, isNotNull,
          reason: 'pendente precisa do recorte para revisão visual');
    });

    test('nota confirmada é nula enquanto houver pendência', () {
      final c = Correcao.fromJson(_respostaApi(
          status: 'PRECISA_REVISAO', notaFinal: null, pendentes: 1));

      expect(c.precisaRevisao, isTrue);
      expect(c.notaFinal, isNull);
      expect(c.resumo!.notaConfirmada, isNull);
      expect(c.resumo!.notaProvisoria, 5.0);
    });

    test('questoesPendentes ignora questões já revisadas pelo professor', () {
      final c = Correcao.fromJson(_respostaApi(
        status: 'PRECISA_REVISAO',
        notaFinal: null,
        pendentes: 0,
        revisoes: {
          '2': {'alternativa': 'B', 'revisado_por': 'prof@escola.com'},
        },
      ));

      expect(c.questoesPendentes, isEmpty);
    });

    test('status de rejeição por qualidade é reconhecido', () {
      final json = _respostaApi(status: 'REJEITADA_QUALIDADE', notaFinal: null);
      (json['resultado'] as Map<String, dynamic>)['resumo'] = null;
      final c = Correcao.fromJson(json);

      expect(c.rejeitada, isTrue);
      expect(c.resumo, isNull);
      expect(c.notaFinal, isNull);
    });
  });
}
