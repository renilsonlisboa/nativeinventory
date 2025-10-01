class Parcela {
  int? id;
  int inventarioId;
  int bloco;
  int parcela;
  int faixa;
  String? valorArvores;
  bool concluida;

  Parcela({
    this.id,
    required this.inventarioId,
    required this.bloco,
    required this.parcela,
    required this.faixa,
    this.valorArvores,
    this.concluida = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'inventario_id': inventarioId,
      'bloco': bloco,
      'parcela': parcela,
      'faixa': faixa,
      'valor_arvores': valorArvores,
      'concluida': concluida ? 1 : 0,
    };
  }

  factory Parcela.fromMap(Map<String, dynamic> map) {
    return Parcela(
      id: map['id'],
      inventarioId: map['inventario_id'],
      bloco: map['bloco'],
      parcela: map['parcela'],
      faixa: map['faixa'],
      valorArvores: map['valor_arvores'],
      concluida: map['concluida'] == 1,
    );
  }

  String get identificador => 'B${bloco}P${parcela}F${faixa}';

  Parcela copyWith({
    int? id,
    int? inventarioId,
    int? bloco,
    int? parcela,
    int? faixa,
    String? valorArvores,
    bool? concluida,
  }) {
    return Parcela(
      id: id ?? this.id,
      inventarioId: inventarioId ?? this.inventarioId,
      bloco: bloco ?? this.bloco,
      parcela: parcela ?? this.parcela,
      faixa: faixa ?? this.faixa,
      valorArvores: valorArvores ?? this.valorArvores,
      concluida: concluida ?? this.concluida,
    );
  }
}