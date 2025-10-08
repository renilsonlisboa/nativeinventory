// models/cap_historico.dart
class CapHistorico {
  final int? id;
  final int arvoreId;
  final int ano;
  final double cap;

  CapHistorico({
    this.id,
    required this.arvoreId,
    required this.ano,
    required this.cap,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'arvore_id': arvoreId,
      'ano': ano,
      'cap': cap,
    };
  }

  factory CapHistorico.fromMap(Map<String, dynamic> map) {
    return CapHistorico(
      id: map['id'],
      arvoreId: map['arvore_id'],
      ano: map['ano'],
      cap: map['cap'] is double ? map['cap'] : (map['cap'] as num).toDouble(),
    );
  }

  @override
  String toString() {
    return 'CapHistorico{id: $id, arvoreId: $arvoreId, ano: $ano, cap: $cap}';
  }
}