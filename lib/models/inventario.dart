// models/inventario.dart
class Inventario {
  final int id;
  final String nome;
  final double areaInventariada;
  final int numeroBlocos;
  final int numeroFaixas;
  final int numeroParcelas;
  final double dapMinimo;
  final DateTime dataCriacao;
  final int ano;

  Inventario({
    this.id = 0,
    required this.nome,
    required this.areaInventariada,
    required this.numeroBlocos,
    required this.numeroFaixas,
    required this.numeroParcelas,
    this.dapMinimo = 10.0,
    required this.dataCriacao,
    this.ano = 2025,
  });

  factory Inventario.fromMap(Map<String, dynamic> map) {
    return Inventario(
      id: map['id'] as int? ?? 0,
      nome: map['nome'] as String? ?? '',
      areaInventariada: (map['area_inventariada'] as num?)?.toDouble() ?? 0.0,
      numeroBlocos: map['numero_blocos'] as int? ?? 0,
      numeroFaixas: map['numero_faixa'] as int? ?? 0,
      numeroParcelas: map['numero_parcelas'] as int? ?? 0,
      dapMinimo: (map['dap_minimo'] as num?)?.toDouble() ?? 10.0,
      dataCriacao: DateTime.parse(map['data_criacao'] as String? ?? DateTime.now().toIso8601String()),
      ano: map['ano'] as int? ?? DateTime.now().year,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nome': nome,
      'area_inventariada': areaInventariada,
      'numero_blocos': numeroBlocos,
      'numero_faixas': numeroFaixas,
      'numero_parcelas': numeroParcelas,
      'dap_minimo': dapMinimo,
      'data_criacao': dataCriacao.toIso8601String(),
      'ano': ano,
    };
  }
}