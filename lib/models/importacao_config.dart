// models/importacao_config.dart
class ImportacaoConfig {
  final int inventarioId;
  final int ano;
  final String nomeInventario;

  ImportacaoConfig({
    required this.inventarioId,
    required this.ano,
    required this.nomeInventario,
  });

  Map<String, dynamic> toMap() {
    return {
      'inventarioId': inventarioId,
      'ano': ano,
      'nomeInventario': nomeInventario,
    };
  }
}