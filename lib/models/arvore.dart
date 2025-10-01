class Arvore {
  int? id;
  int parcelaId;
  int numeroArvore;
  String codigo;
  double x;
  double y;
  String familia;
  String nomeCientifico;
  double dap;
  double ht;

  Arvore({
    this.id,
    required this.parcelaId,
    required this.numeroArvore,
    required this.codigo,
    required this.x,
    required this.y,
    required this.familia,
    required this.nomeCientifico,
    required this.dap,
    required this.ht,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'parcela_id': parcelaId,
      'numero_arvore': numeroArvore,
      'codigo': codigo,
      'x': x,
      'y': y,
      'familia': familia,
      'nome_cientifico': nomeCientifico,
      'dap': dap,
      'ht': ht,
    };
  }

  factory Arvore.fromMap(Map<String, dynamic> map) {
    return Arvore(
      id: map['id'],
      parcelaId: map['parcela_id'],
      numeroArvore: map['numero_arvore'],
      codigo: map['codigo'],
      x: map['x']?.toDouble() ?? 0.0,
      y: map['y']?.toDouble() ?? 0.0,
      familia: map['familia'],
      nomeCientifico: map['nome_cientifico'],
      dap: map['dap']?.toDouble() ?? 0.0,
      ht: map['ht']?.toDouble() ?? 0.0,
    );
  }
}