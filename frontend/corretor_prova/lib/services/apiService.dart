import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path/path.dart';

class ApiService {
  static const String baseUrl = 'http://172.25.3.135:8000'; // Android Emulator

  static Future<Map<String, dynamic>> enviarProva({
    required String turma,
    required String aluno,
    required File imagem,
  }) async {
    var uri = Uri.parse("$baseUrl/corrigir");

    var request = http.MultipartRequest('POST', uri)
      ..fields['turma'] = turma
      ..fields['aluno'] = aluno
      ..files.add(await http.MultipartFile.fromPath(
        'file',
        imagem.path,
        filename: basename(imagem.path),
      ));

    var response = await request.send();
    var body = await response.stream.bytesToString();

    return jsonDecode(body);
  }
}
