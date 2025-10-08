class Arvore {
  final int id;
  final int parcelaId;
  final int numeroArvore;
  final String codigo;
  final double x;
  final double y;
  final String familia;
  final String nomeCientifico;
  final double cap;
  final double hc;
  final double ht;

  Arvore({
    this.id = 0,
    required this.parcelaId,
    required this.numeroArvore,
    required this.codigo,
    required this.x,
    required this.y,
    required this.familia,
    required this.nomeCientifico,
    required this.cap,
    required this.hc,
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
      'cap': cap, // MUDOU
      'hc': hc,   // NOVO
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
      cap: map['cap']?.toDouble() ?? 0.0, // MUDOU
      hc: map['hc']?.toDouble() ?? 0.0,   // NOVO
      ht: map['ht']?.toDouble() ?? 0.0,
    );
  }

  // Método para converter DAP para CAP (se necessário)
  double get dap => cap / 3.14159; // CAP para DAP aproximado

  // Método para obter medições formatadas por ano
  Map<String, double> getMedicoesPorAno(int ano) {
    return {
      'CAP_$ano': cap,
      'HC_$ano': hc,
      'HT_$ano': ht,
    };
  }
}