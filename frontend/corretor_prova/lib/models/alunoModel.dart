class Aluno {
  final String id;
  final String nome;
  final String email;
  final String? matricula;

  Aluno({
    required this.id,
    required this.nome,
    required this.email,
    this.matricula,
  });

  factory Aluno.fromJson(Map<String, dynamic> json) {
    return Aluno(
      id: json['id'] as String,
      nome: json['nome'] as String,
      email: json['email'] as String,
      matricula: json['matricula'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nome': nome,
      'email': email,
      'matricula': matricula,
    };
  }
}