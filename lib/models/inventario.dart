class Inventario {
  final int id;
  final String nome;
  final int areaInventariada;
  final int numeroBlocos;
  final int numeroFaixas;
  final int numeroParcelas;
  final double dapMinimo;
  final String dataCriacao;
  final int ano; // NOVO CAMPO

  Inventario({
    this.id = 0,
    required this.nome,
    required this.areaInventariada,
    required this.numeroBlocos,
    required this.numeroFaixas,
    required this.numeroParcelas,
    required this.dapMinimo,
    required this.dataCriacao,
    required this.ano, // NOVO
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nome': nome,
      'area_inventariada' : areaInventariada,
      'numero_blocos': numeroBlocos,
      'numero_faixas': numeroFaixas,
      'numero_parcelas': numeroParcelas,
      'dap_minimo': dapMinimo,
      'data_criacao': dataCriacao,
      'ano': ano, // NOVO
    };
  }

  factory Inventario.fromMap(Map<String, dynamic> map) {
    return Inventario(
      id: map['id'],
      nome: map['nome'],
      areaInventariada: map['area_inventariada'],
      numeroBlocos: map['numero_blocos'],
      numeroFaixas: map['numero_faixas'],
      numeroParcelas: map['numero_parcelas'],
      dapMinimo: map['dap_minimo']?.toDouble() ?? 10.0,
      dataCriacao: map['data_criacao'],
      ano: map['ano'] ?? DateTime.now().year, // NOVO - default para ano atual
    );
  }
}