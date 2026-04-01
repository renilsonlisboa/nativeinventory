class Arvore {
  final int id;
  final int parcelaId;
  final int numeroArvore;
  final int numeroFuste;
  final String codigo;
  final double x;
  final double y;
  final String familia;
  final String nomeCientifico;
  final String? nomePopular;
  final double cap;
  final double? hc;
  final int? anoHC;
  final double? ht;
  final int? anoHT;
  final int? formaFuste;
  final int? posiSoc;
  final int? fitossanidade;
  final int? posiCopa;
  final int? formaCopa;
  final int? dataIngresso;
  final int? infoMorte;
  final int? dataMorte;
  final String? observation;

  Arvore({
    this.id = 0,
    required this.parcelaId,
    required this.numeroArvore,
    required this.numeroFuste,
    required this.codigo,
    required this.x,
    required this.y,
    required this.familia,
    required this.nomeCientifico,
    required this.nomePopular,
    required this.cap,
    required this.hc,
    required this.anoHC,
    required this.ht,
    required this.anoHT,
    required this.formaFuste,
    required this.posiSoc,
    required this.fitossanidade,
    required this.posiCopa,
    required this.formaCopa,
    required this.dataIngresso,
    required this.infoMorte,
    this.dataMorte,
    required this.observation,
  });


  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'parcela_id': parcelaId,
      'numero_arvore': numeroArvore,
      'numero_fuste': numeroFuste,
      'codigo': codigo,
      'x': x,
      'y': y,
      'familia': familia,
      'nome_cientifico': nomeCientifico,
      'nome_popular': nomePopular,
      'cap': cap,
      'hc': hc,
      'anoHC': anoHC,
      'ht': ht,
      'anoHT': anoHT,
      'formaFuste': formaFuste,
      'posiSoc': posiSoc,
      'fitossanidade': fitossanidade,
      'posiCopa': posiCopa,
      'formaCopa': formaCopa,
      'dataIngresso': dataIngresso,
      'infoMorte': infoMorte,
      'dataMorte': dataMorte,
      'observation': observation,
    };
  }

  factory Arvore.fromMap(Map<String, dynamic> map) {
    return Arvore(
      id: map['id'],
      parcelaId: map['parcela_id'],
      numeroArvore: map['numero_arvore'],
      numeroFuste: map['numero_fuste'],
      codigo: map['codigo'],
      x: map['x'],
      y: map['y'],
      familia: map['familia'],
      nomeCientifico: map['nome_cientifico'],
      nomePopular: map['nome_popular'],
      cap: map['cap'],
      hc: map['hc'],
      anoHC: (map['anoHC'] as num?)?.toInt(),   // ← conversão
      ht: map['ht'],
      anoHT: (map['anoHT'] as num?)?.toInt(),   // ← conversão
      formaFuste: map['formaFuste'],
      posiSoc: map['posiSoc'],
      fitossanidade: map['fitossanidade'],
      posiCopa: map['posiCopa'],
      formaCopa: map['formaCopa'],
      dataIngresso: map['dataIngresso'],
      infoMorte: map['infoMorte'],
      dataMorte: map['dataMorte'],
      observation: map['observation'],
    );
  }

  // Método para converter DAP para CAP (se necessário)
  double get dap => cap / 3.14159; // CAP para DAP aproximado

  // Método para obter medições formatadas por ano
  Map<String, double> getMedicoesPorAno(int ano) {
    return {
      'CAP_$ano': cap,
      'HC_$ano': hc!,
      'HT_$ano': ht!,
    };
  }
}