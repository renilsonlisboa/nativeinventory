class Inventario {
  int? id;
  String nome;
  int numeroBlocos;
  int numeroFaixas;
  int numeroParcelas;
  double dapMinimo; // NOVO CAMPO
  DateTime dataCriacao;

  Inventario({
    this.id,
    required this.nome,
    required this.numeroBlocos,
    required this.numeroFaixas,
    required this.numeroParcelas,
    required this.dapMinimo, // NOVO
    required this.dataCriacao,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nome': nome,
      'numero_blocos': numeroBlocos,
      'numero_faixas': numeroFaixas,
      'numero_parcelas': numeroParcelas,
      'dap_minimo': dapMinimo, // NOVO
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
      dapMinimo: map['dap_minimo']?.toDouble() ?? 10.0, // Valor padrão 10.0 cm
      dataCriacao: DateTime.parse(map['data_criacao']),
    );
  }
}