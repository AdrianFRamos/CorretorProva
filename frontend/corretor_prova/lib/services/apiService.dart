import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = 'http://172.25.3.135:5000'; // Porta atualizada para Flask
  
  // Modelo para resposta da API
  static Map<String, dynamic> _criarGabaritoOficial(int numeroQuestoes) {
    Map<String, String> gabarito = {};
    
    // Exemplo de gabarito - você pode personalizar conforme necessário
    List<String> opcoes = ['A', 'B', 'C', 'D', 'E'];
    
    for (int i = 1; i <= numeroQuestoes; i++) {
      // Alternando respostas para exemplo - substitua pela lógica real
      gabarito[i.toString()] = opcoes[(i - 1) % 5];
    }
    
    return gabarito;
  }

  // Método principal para correção usando nova API flexível
  static Future<Map<String, dynamic>> corrigirGabarito({
    required String turma,
    required String aluno,
    required File imagem,
    required Map<String, String> gabaritoOficial,
    bool incluirDetalhes = false,
  }) async {
    try {
      // Converter imagem para base64
      List<int> imageBytes = await imagem.readAsBytes();
      String base64Image = base64Encode(imageBytes);

      // Preparar payload para nova API
      Map<String, dynamic> payload = {
        'gabarito_oficial': gabaritoOficial,
        'imagem': base64Image,
        'incluir_detalhes': incluirDetalhes,
      };

      // Fazer requisição para novo endpoint
      var response = await http.post(
        Uri.parse('$baseUrl/api/gabarito/corrigir-simples'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        Map<String, dynamic> responseData = jsonDecode(response.body);
        
        if (responseData['success'] == true) {
          // Adaptar resposta para formato esperado pelo frontend
          return _adaptarResposta(responseData, turma, aluno, gabaritoOficial);
        } else {
          throw Exception('Erro na correção: ${responseData['error']}');
        }
      } else {
        throw Exception('Erro HTTP: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Erro ao corrigir gabarito: $e');
    }
  }

  // Método simplificado que usa gabarito padrão
  static Future<Map<String, dynamic>> enviarProva({
    required String turma,
    required String aluno,
    required File imagem,
    int numeroQuestoes = 10, // Padrão de 10 questões, mas flexível
  }) async {
    // Criar gabarito oficial padrão
    Map<String, String> gabaritoOficial = _criarGabaritoOficial(numeroQuestoes).cast<String, String>();
    
    return await corrigirGabarito(
      turma: turma,
      aluno: aluno,
      imagem: imagem,
      gabaritoOficial: gabaritoOficial,
    );
  }

  // Validar gabarito oficial antes de enviar
  static Future<Map<String, dynamic>> validarGabarito(Map<String, String> gabarito) async {
    try {
      var response = await http.post(
        Uri.parse('$baseUrl/api/gabarito/validar-gabarito'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'gabarito_oficial': gabarito,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Erro na validação: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Erro ao validar gabarito: $e');
    }
  }

  // Obter informações do template
  static Future<Map<String, dynamic>> obterTemplate() async {
    try {
      var response = await http.get(
        Uri.parse('$baseUrl/api/gabarito/gabarito-template'),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Erro ao obter template: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Erro ao obter template: $e');
    }
  }

  // Verificar se API está funcionando
  static Future<bool> verificarSaude() async {
    try {
      var response = await http.get(
        Uri.parse('$baseUrl/api/gabarito/health'),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // Adaptar resposta da nova API para formato esperado pelo frontend
  static Map<String, dynamic> _adaptarResposta(
    Map<String, dynamic> responseData,
    String turma,
    String aluno,
    Map<String, String> gabaritoOficial,
  ) {
    var resultado = responseData['resultado'];
    var problemas = responseData['problemas'];
    
    // Criar lista de respostas do gabarito oficial
    List<String> gabaritoLista = [];
    for (int i = 1; i <= resultado['total_questoes']; i++) {
      gabaritoLista.add(gabaritoOficial[i.toString()] ?? '?');
    }

    // Simular respostas do aluno (na resposta real, isso viria dos detalhes)
    List<String> respostasAluno = List.generate(
      resultado['total_questoes'],
      (index) => gabaritoOficial[(index + 1).toString()] ?? '?',
    );

    return {
      'success': true,
      'aluno': aluno,
      'turma': turma,
      'acertos': resultado['acertos'],
      'erros': resultado['erros'],
      'total_questoes': resultado['total_questoes'],
      'porcentagem_acerto': resultado['porcentagem_acerto'],
      'nota': resultado['nota'],
      'respostas': respostasAluno,
      'gabarito': gabaritoLista,
      'problemas': {
        'questoes_multiplas': problemas['questoes_multiplas'],
        'questoes_em_branco': problemas['questoes_em_branco'],
        'questoes_nao_detectadas': problemas['questoes_nao_detectadas'],
      },
      // Dados adicionais da nova API
      'api_flexivel': true,
      'endpoint_usado': '/api/gabarito/corrigir-simples',
    };
  }
}

// Classe para facilitar criação de gabaritos
class GabaritoBuilder {
  Map<String, String> _gabarito = {};

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

