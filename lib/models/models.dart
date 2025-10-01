class Inventario {
  int? id;
  String nome;
  int numeroBlocos;
  int numeroFaixas;
  int numeroParcelas;
  DateTime dataCriacao;

  Inventario({
    this.id,
    required this.nome,
    required this.numeroBlocos,
    required this.numeroFaixas,
    required this.numeroParcelas,
    required this.dataCriacao,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nome': nome,
      'numero_blocos': numeroBlocos,
      'numero_faixas': numeroFaixas,
      'numero_parcelas': numeroParcelas,
      'data_criacao': dataCriacao.toIso8601String(),
    };
  }

  factory Inventario.fromMap(Map<String, dynamic> map) {
    return Inventario(
      id: map['id'],
      nome: map['nome'],
      numeroBlocos: map['numero_blocos'],
      numeroFaixas: map['numero_faixas'],
      numeroParcelas: map['numero_parcelas'],
      dataCriacao: DateTime.parse(map['data_criacao']),
    );
  }
}