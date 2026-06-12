/// Serviço da API v2: autenticação de professores, correção com pipeline
/// seguro, revisão manual, histórico e exportação de notas.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:http/http.dart' as http;

import '../models/correcaoModel.dart';

/// Erro de API com mensagem amigável vinda do backend.
class ApiException implements Exception {
  final String mensagem;
  final String? codigo;
  final int? statusCode;

  ApiException(this.mensagem, {this.codigo, this.statusCode});

  @override
  String toString() => mensagem;
}

/// Sessão do professor autenticado (token em memória durante o uso do app).
class Sessao {
  static String? token;
  static Map<String, dynamic>? usuario;

  static bool get autenticado => token != null;

  static void encerrar() {
    token = null;
    usuario = null;
  }
}

class CorrecaoService {
  // Sobrescreva em desenvolvimento com:
  //   USB Android: adb reverse tcp:5001 tcp:5001
  //   flutter run --dart-define=API_URL=http://127.0.0.1:5001
  //   Wi-Fi/celular físico: use http://IP_DO_COMPUTADOR:5001
  static const String baseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'https://corretorprova.onrender.com',
  );
  static const Duration _timeout = Duration(seconds: 60);

  static Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (Sessao.token != null) 'Authorization': 'Bearer ${Sessao.token}',
      };

  static Never _lancarErro(http.Response response) {
    String mensagem = 'Erro inesperado (HTTP ${response.statusCode}).';
    String? codigo;
    try {
      final corpo = jsonDecode(response.body) as Map<String, dynamic>;
      mensagem = corpo['erro'] as String? ?? mensagem;
      codigo = corpo['codigo'] as String?;
    } catch (_) {}
    throw ApiException(mensagem, codigo: codigo, statusCode: response.statusCode);
  }

  // ─── Autenticação ────────────────────────────────────────────────────

  static Future<void> login(String email, String senha) async {
    final response = await http
        .post(Uri.parse('$baseUrl/api/v2/auth/login'),
            headers: _headers,
            body: jsonEncode({'email': email, 'senha': senha}))
        .timeout(_timeout);
    if (response.statusCode != 200) _lancarErro(response);
    final corpo = jsonDecode(response.body) as Map<String, dynamic>;
    Sessao.token = corpo['token'] as String;
    Sessao.usuario = corpo['usuario'] as Map<String, dynamic>?;
  }

  static Future<void> registrar(String nome, String email, String senha) async {
    final response = await http
        .post(Uri.parse('$baseUrl/api/v2/auth/registrar'),
            headers: _headers,
            body: jsonEncode({'nome': nome, 'email': email, 'senha': senha}))
        .timeout(_timeout);
    if (response.statusCode != 201) _lancarErro(response);
    final corpo = jsonDecode(response.body) as Map<String, dynamic>;
    Sessao.token = corpo['token'] as String;
    Sessao.usuario = corpo['usuario'] as Map<String, dynamic>?;
  }

  // ─── Validação local da imagem (antes de gastar rede) ───────────────

  static const int _ladoMinimo = 600;
  static const int _tamanhoMaximoBytes = 15 * 1024 * 1024;

  /// Retorna a mensagem do problema, ou null se a imagem está apta ao envio.
  static Future<String?> validarImagemLocal(File imagem) async {
    final bytes = await imagem.length();
    if (bytes > _tamanhoMaximoBytes) {
      return 'Imagem muito grande (${(bytes / 1024 / 1024).toStringAsFixed(1)} MB). '
          'Use qualidade menor na captura.';
    }
    try {
      final buffer = await ui.ImmutableBuffer.fromUint8List(
          await imagem.readAsBytes());
      final descriptor = await ui.ImageDescriptor.encoded(buffer);
      final largura = descriptor.width;
      final altura = descriptor.height;
      descriptor.dispose();
      buffer.dispose();
      if ((largura < altura ? largura : altura) < _ladoMinimo) {
        return 'Resolução insuficiente (${largura}x$altura). '
            'Aproxime a câmera e capture novamente.';
      }
    } catch (_) {
      return 'Arquivo de imagem inválido ou corrompido.';
    }
    return null;
  }

  // ─── Correção ────────────────────────────────────────────────────────

  static Future<Correcao> corrigirProva({
    required String turma,
    required String aluno,
    required File imagem,
    required Map<String, String> gabaritoOficial,
    int numAlternativas = 5,
    int numColunas = 2,
  }) async {
    final base64Image = base64Encode(await imagem.readAsBytes());
    final response = await http
        .post(Uri.parse('$baseUrl/api/v2/correcoes'),
            headers: _headers,
            body: jsonEncode({
              'turma': turma,
              'aluno': aluno,
              'imagem': 'data:image/jpeg;base64,$base64Image',
              'gabarito_oficial': gabaritoOficial,
              'layout': {
                'num_questoes': gabaritoOficial.length,
                'num_alternativas': numAlternativas,
                'num_colunas': numColunas,
              },
            }))
        .timeout(_timeout);

    // 422 = rejeitada por qualidade: ainda assim vem o corpo estruturado
    if (response.statusCode != 200 && response.statusCode != 422) {
      _lancarErro(response);
    }
    return Correcao.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  // ─── Revisão manual e confirmação ────────────────────────────────────

  /// Define manualmente a resposta de uma questão (null = em branco).
  /// Retorna o resumo recalculado.
  static Future<ResumoCorrecao> revisarQuestao(
      int correcaoId, int numero, String? alternativa) async {
    final response = await http
        .patch(Uri.parse('$baseUrl/api/v2/correcoes/$correcaoId/questoes/$numero'),
            headers: _headers,
            body: jsonEncode({'alternativa': alternativa}))
        .timeout(_timeout);
    if (response.statusCode != 200) _lancarErro(response);
    final corpo = jsonDecode(response.body) as Map<String, dynamic>;
    return ResumoCorrecao.fromJson(corpo['resumo'] as Map<String, dynamic>);
  }

  /// Confirma a nota final. A API bloqueia (409) se houver pendências.
  static Future<Correcao> confirmarCorrecao(int correcaoId) async {
    final response = await http
        .post(Uri.parse('$baseUrl/api/v2/correcoes/$correcaoId/confirmar'),
            headers: _headers)
        .timeout(_timeout);
    if (response.statusCode != 200) _lancarErro(response);
    return Correcao.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  // ─── Histórico e exportação ──────────────────────────────────────────

  static Future<List<Correcao>> listarCorrecoes({String? turma}) async {
    final query = turma != null ? '?turma=$turma' : '';
    final response = await http
        .get(Uri.parse('$baseUrl/api/v2/correcoes$query'), headers: _headers)
        .timeout(_timeout);
    if (response.statusCode != 200) _lancarErro(response);
    final corpo = jsonDecode(response.body) as Map<String, dynamic>;
    return (corpo['correcoes'] as List<dynamic>)
        .map((c) => Correcao.fromJson(c as Map<String, dynamic>))
        .toList();
  }

  static Future<Correcao> obterCorrecao(int id) async {
    final response = await http
        .get(Uri.parse('$baseUrl/api/v2/correcoes/$id'), headers: _headers)
        .timeout(_timeout);
    if (response.statusCode != 200) _lancarErro(response);
    return Correcao.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  /// Baixa o CSV de notas da turma e devolve o conteúdo como texto.
  static Future<String> exportarNotasCsv({String? turma}) async {
    final query = turma != null ? '?turma=$turma' : '';
    final response = await http
        .get(Uri.parse('$baseUrl/api/v2/correcoes/export$query'),
            headers: _headers)
        .timeout(_timeout);
    if (response.statusCode != 200) _lancarErro(response);
    return utf8.decode(response.bodyBytes);
  }
}
