class Parcela {
  int? id;
  int inventarioId;
  int bloco;
  int faixa;
  int parcela;
  String? valorArvores;
  bool concluida;

  Parcela({
    this.id,
    required this.inventarioId,
    required this.bloco,
    required this.faixa,
    required this.parcela,
    this.valorArvores,
    this.concluida = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'inventario_id': inventarioId,
      'bloco': bloco,
      'faixa': faixa,
      'parcela': parcela,
      'valor_arvores': valorArvores,
      'concluida': concluida ? 1 : 0,
    };
  }

  factory Parcela.fromMap(Map<String, dynamic> map) {
    return Parcela(
      id: map['id'],
      inventarioId: map['inventario_id'],
      bloco: map['bloco'],
      faixa: map['faixa'],
      parcela: map['parcela'],
      valorArvores: map['valor_arvores'],
      concluida: map['concluida'] == 1,
    );
  }

  String get identificador => 'B${bloco}F${faixa}P${parcela}';

  // ADICIONE ESTE MÉTODO copyWith
  Parcela copyWith({
    int? id,
    int? inventarioId,
    int? bloco,
    int? faixa,
    int? parcela,
    String? valorArvores,
    bool? concluida,
  }) {
    return Parcela(
      id: id ?? this.id,
      inventarioId: inventarioId ?? this.inventarioId,
      bloco: bloco ?? this.bloco,
      faixa: faixa ?? this.faixa,
      parcela: parcela ?? this.parcela,
      valorArvores: valorArvores ?? this.valorArvores,
      concluida: concluida ?? this.concluida,
    );
  }
}