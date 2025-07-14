import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = 'https://corretorprova.onrender.com';
  
  // Verificar se API está funcionando
  static Future<bool> verificarSaude() async {
    try {
      var response = await http.get(
        Uri.parse('$baseUrl/api/gabarito/health'),
        headers: {
          'Content-Type': 'application/json',
        },
      ).timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('API Status: ${data['message']}');
        print('Versão: ${data['version']}');
        print('Eficiência: ${data['eficiencia']}');
        return true;
      }
      return false;
    } catch (e) {
      print('Erro ao verificar saúde da API: $e');
      return false;
    }
  }

  // Obter informações da API
  static Future<Map<String, dynamic>?> obterInfoApi() async {
    try {
      var response = await http.get(
        Uri.parse('$baseUrl/api/gabarito/info'),
        headers: {
          'Content-Type': 'application/json',
        },
      ).timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      print('Erro ao obter info da API: $e');
      return null;
    }
  }

  // Método principal para correção com sistema corrigido
  static Future<Map<String, dynamic>> corrigirGabarito({
    required String turma,
    required String aluno,
    required File imagem,
    required Map<String, String> gabaritoOficial,
    Map<String, List<int>>? configuracaoQuestoes,
  }) async {
    try {
      print('Iniciando correção de gabarito...');
      print('Aluno: $aluno, Turma: $turma');
      print('Questões no gabarito: ${gabaritoOficial.length}');
      
      // Converter imagem para base64
      List<int> imageBytes = await imagem.readAsBytes();
      String base64Image = base64Encode(imageBytes);
      print('Imagem convertida para base64 (${imageBytes.length} bytes)');

      // Preparar payload para o sistema corrigido
      Map<String, dynamic> payload = {
        'imagem': 'data:image/jpeg;base64,$base64Image',
        'gabarito_oficial': gabaritoOficial,
      };

      // Adicionar configuração de questões se fornecida
      if (configuracaoQuestoes != null) {
        payload['configuracao_questoes'] = configuracaoQuestoes;
        print('Configuração de questões personalizada: $configuracaoQuestoes');
      }

      print('Enviando requisição para API...');

      // Fazer requisição para o endpoint corrigido
      var response = await http.post(
        Uri.parse('$baseUrl/api/gabarito/processar'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(payload),
      ).timeout(Duration(seconds: 30));

      print('Resposta recebida: ${response.statusCode}');

      if (response.statusCode == 200) {
        Map<String, dynamic> responseData = jsonDecode(response.body);
        print('Processamento bem-sucedido!');
        print('Respostas detectadas: ${responseData['questoes_respondidas']}/${responseData['total_questoes']}');
        print('Eficiência: ${responseData['eficiencia']}%');
        
        return _adaptarRespostaCorrigida(responseData, turma, aluno, gabaritoOficial);
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception('Erro HTTP ${response.statusCode}: ${errorData['erro'] ?? 'Erro desconhecido'}');
      }
    } catch (e) {
      print('Erro ao corrigir gabarito: $e');
      throw Exception('Erro ao corrigir gabarito: $e');
    }
  }

  // Método simplificado que usa configuração automática
  static Future<Map<String, dynamic>> enviarProva({
    required String turma,
    required String aluno,
    required File imagem,
    required Map<String, String> gabaritoOficial,
  }) async {
    return await corrigirGabarito(
      turma: turma,
      aluno: aluno,
      imagem: imagem,
      gabaritoOficial: gabaritoOficial,
      configuracaoQuestoes: null, // Deixa o sistema detectar automaticamente
    );
  }

  // Método para testar diferentes configurações
  static Future<Map<String, dynamic>> testarConfiguracoes({
    required File imagem,
    required Map<String, String> gabaritoOficial,
    required Map<String, Map<String, List<int>>> configuracoes,
  }) async {
    try {
      // Converter imagem para base64
      List<int> imageBytes = await imagem.readAsBytes();
      String base64Image = base64Encode(imageBytes);

      // Preparar payload
      Map<String, dynamic> payload = {
        'imagem': 'data:image/jpeg;base64,$base64Image',
        'gabarito_oficial': gabaritoOficial,
        'configuracoes': configuracoes,
      };

      // Fazer requisição
      var response = await http.post(
        Uri.parse('$baseUrl/api/gabarito/configurar'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(payload),
      ).timeout(Duration(seconds: 45));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception('Erro HTTP ${response.statusCode}: ${errorData['erro'] ?? 'Erro desconhecido'}');
      }
    } catch (e) {
      throw Exception('Erro ao testar configurações: $e');
    }
  }

  // Gerar imagem de debug
  static Future<String?> gerarDebug({
    required File imagem,
    required Map<String, String> gabaritoOficial,
    Map<String, List<int>>? configuracaoQuestoes,
  }) async {
    try {
      // Converter imagem para base64
      List<int> imageBytes = await imagem.readAsBytes();
      String base64Image = base64Encode(imageBytes);

      // Preparar payload
      Map<String, dynamic> payload = {
        'imagem': 'data:image/jpeg;base64,$base64Image',
        'gabarito_oficial': gabaritoOficial,
      };

      if (configuracaoQuestoes != null) {
        payload['configuracao_questoes'] = configuracaoQuestoes;
      }

      // Fazer requisição
      var response = await http.post(
        Uri.parse('$baseUrl/api/gabarito/debug'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(payload),
      ).timeout(Duration(seconds: 30));

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        return responseData['debug_image']; // Retorna base64 da imagem de debug
      } else {
        print('Erro ao gerar debug: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Erro ao gerar debug: $e');
      return null;
    }
  }

  // Adaptar resposta da API corrigida para formato esperado pelo frontend
  static Map<String, dynamic> _adaptarRespostaCorrigida(
    Map<String, dynamic> responseData,
    String turma,
    String aluno,
    Map<String, String> gabaritoOficial,
  ) {
    final respostasDetectadas = responseData['respostas_detectadas'] as Map<String, dynamic>? ?? {};
    final totalQuestoes = responseData['total_questoes'] ?? gabaritoOficial.length;
    final questoesRespondidas = responseData['questoes_respondidas'] ?? 0;
    final acertos = responseData['acertos'] ?? 0;
    final nota = (responseData['nota'] as num?)?.toDouble() ?? 0.0;
    final precisao = (responseData['precisao'] as num?)?.toDouble() ?? 0.0;
    final eficiencia = (responseData['eficiencia'] as num?)?.toDouble() ?? 0.0;

    // Criar lista de respostas do gabarito oficial
    List<String> gabaritoLista = [];
    for (int i = 1; i <= totalQuestoes; i++) {
      gabaritoLista.add(gabaritoOficial[i.toString()] ?? '?');
    }

    // Criar lista de respostas do aluno
    List<String> respostasAluno = [];
    for (int i = 1; i <= totalQuestoes; i++) {
      respostasAluno.add(respostasDetectadas[i.toString()] ?? '?');
    }

    // Calcular problemas
    int questoesNaoDetectadas = totalQuestoes - questoesRespondidas;
    int questoesEmBranco = 0;
    int questoesMultiplas = 0;

    // Contar questões em branco (não detectadas)
    for (int i = 1; i <= totalQuestoes; i++) {
      if (!respostasDetectadas.containsKey(i.toString())) {
        questoesEmBranco++;
      }
    }

    return {
      'success': true,
      'aluno': aluno,
      'turma': turma,
      'acertos': acertos,
      'erros': totalQuestoes - acertos,
      'total_questoes': totalQuestoes,
      'questoes_respondidas': questoesRespondidas,
      'porcentagem_acerto': precisao,
      'nota': nota,
      'eficiencia': eficiencia,
      'respostas': respostasAluno,
      'gabarito': gabaritoLista,
      'respostas_detectadas_raw': respostasDetectadas,
      'problemas': {
        'questoes_multiplas': questoesMultiplas,
        'questoes_em_branco': questoesEmBranco,
        'questoes_nao_detectadas': questoesNaoDetectadas,
      },
      'api_info': {
        'metodo': responseData['metodo'] ?? 'sistema_corrigido_funcional',
        'versao': responseData['versao'] ?? '3.0',
        'base': responseData['base'] ?? 'Murtaza Hassan Style',
        'timestamp': responseData['timestamp'],
      },
      'configuracao_usada': responseData['configuracao_usada'],
    };
  }

  // Criar gabarito padrão
  static Map<String, String> criarGabaritoOficial(int numeroQuestoes) {
    Map<String, String> gabarito = {};
    List<String> opcoes = ['A', 'B', 'C', 'D', 'E'];
    
    for (int i = 1; i <= numeroQuestoes; i++) {
      // Padrão cíclico para exemplo
      gabarito[i.toString()] = opcoes[(i - 1) % 5];
    }
    
    return gabarito;
  }

  // Criar configuração de questões para duas tabelas
  static Map<String, List<int>> criarConfiguracaoDuasTabelas(int totalQuestoes) {
    int metade = totalQuestoes ~/ 2;
    
    return {
      'tabela_esquerda': List.generate(metade, (i) => i + 1),
      'tabela_direita': List.generate(totalQuestoes - metade, (i) => i + metade + 1),
    };
  }

  // Criar configuração personalizada
  static Map<String, List<int>> criarConfiguracaoPersonalizada({
    required List<int> grupo1,
    required List<int> grupo2,
    String nomeGrupo1 = 'primeira_parte',
    String nomeGrupo2 = 'segunda_parte',
  }) {
    return {
      nomeGrupo1: grupo1,
      nomeGrupo2: grupo2,
    };
  }
}

// Classe para facilitar criação de gabaritos (mantida para compatibilidade)
class GabaritoBuilder {
  final Map<String, String> _gabarito = {};

  GabaritoBuilder adicionarQuestao(int numero, String resposta) {
    if (!['A', 'B', 'C', 'D', 'E'].contains(resposta.toUpperCase())) {
      throw ArgumentError('Resposta deve ser A, B, C, D ou E');
    }
    _gabarito[numero.toString()] = resposta.toUpperCase();
    return this;
  }

  GabaritoBuilder adicionarQuestoes(Map<int, String> questoes) {
    questoes.forEach((numero, resposta) {
      adicionarQuestao(numero, resposta);
    });
    return this;
  }

  GabaritoBuilder criarSequencial(int quantidade, {String? padrao}) {
    List<String> opcoes = ['A', 'B', 'C', 'D', 'E'];
    
    for (int i = 1; i <= quantidade; i++) {
      String resposta = padrao ?? opcoes[(i - 1) % 5];
      _gabarito[i.toString()] = resposta;
    }
    return this;
  }

  Map<String, String> build() {
    if (_gabarito.isEmpty) {
      throw StateError('Gabarito não pode estar vazio');
    }
    return Map.from(_gabarito);
  }

  void limpar() {
    _gabarito.clear();
  }
}

// Classe para gerenciar configurações de questões
class ConfiguradorQuestoes {
  static Map<String, List<int>> automatico() {
    // Retorna null para deixar o sistema detectar automaticamente
    return {};
  }

  static Map<String, List<int>> duasTabelas(int totalQuestoes) {
    return ApiService.criarConfiguracaoDuasTabelas(totalQuestoes);
  }

  static Map<String, List<int>> tresTabelas(int totalQuestoes) {
    int terco = totalQuestoes ~/ 3;
    int resto = totalQuestoes % 3;
    
    return {
      'tabela_1': List.generate(terco + (resto > 0 ? 1 : 0), (i) => i + 1),
      'tabela_2': List.generate(terco + (resto > 1 ? 1 : 0), (i) => i + terco + (resto > 0 ? 1 : 0) + 1),
      'tabela_3': List.generate(terco, (i) => i + 2 * terco + (resto > 0 ? 1 : 0) + (resto > 1 ? 1 : 0) + 1),
    };
  }

  static Map<String, List<int>> porMateria({
    required List<int> matematica,
    required List<int> portugues,
    required List<int> ciencias,
    List<int>? historia,
    List<int>? geografia,
  }) {
    Map<String, List<int>> config = {
      'matematica': matematica,
      'portugues': portugues,
      'ciencias': ciencias,
    };

    if (historia != null && historia.isNotEmpty) {
      config['historia'] = historia;
    }

    if (geografia != null && geografia.isNotEmpty) {
      config['geografia'] = geografia;
    }

    return config;
  }

  static Map<String, List<int>> personalizado(Map<String, List<int>> configuracao) {
    return Map.from(configuracao);
  }
}

