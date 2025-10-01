import 'dart:io';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../database/database_helper.dart';

class ExportService {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  // Método genérico para compartilhar arquivo
  Future<void> _shareFile(File file, String subject) async {
    try {
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: subject,
      );
    } catch (e) {
      throw Exception('Erro ao compartilhar arquivo: $e');
    }
  }

  // Método para salvar arquivo temporariamente
  Future<File> _saveTempFile(List<int> bytes, String fileName) async {
    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/$fileName');
    await file.writeAsBytes(bytes);
    return file;
  }

  // Exportar para CSV
  Future<void> exportToCsv(int inventarioId) async {
    final inventario = await _dbHelper.getInventario(inventarioId);
    if (inventario == null) {
      throw Exception('Inventário não encontrado');
    }

    final parcelas = await _dbHelper.getParcelasByInventario(inventarioId);

    List<List<dynamic>> csvData = [];

    // Cabeçalho
    csvData.add([
      'Inventario',
      'Bloco',
      'Faixa',
      'Parcela',
      'Numero_Arvore',
      'Codigo',
      'X',
      'Y',
      'Familia',
      'Nome_Cientifico',
      'DAP',
      'HT'
    ]);

    // Dados
    for (final parcela in parcelas) {
      final arvores = await _dbHelper.getArvoresByParcela(parcela.id!);

      for (final arvore in arvores) {
        csvData.add([
          inventario.nome,
          parcela.bloco,
          parcela.faixa,
          parcela.parcela,
          arvore.numeroArvore,
          arvore.codigo,
          arvore.x.toStringAsFixed(2),
          arvore.y.toStringAsFixed(2),
          arvore.familia,
          arvore.nomeCientifico,
          arvore.dap.toStringAsFixed(2),
          arvore.ht.toStringAsFixed(2),
        ]);
      }
    }

    String csv = const ListToCsvConverter().convert(csvData);
    final bytes = csv.codeUnits;

    final fileName = 'inventario_${inventario.nome}_${DateTime.now().millisecondsSinceEpoch}.csv';
    final tempFile = await _saveTempFile(bytes, fileName);

    await _shareFile(tempFile, 'Exportação CSV - ${inventario.nome}');
  }

  // Exportar para XLSX
  Future<void> exportToXlsx(int inventarioId) async {
    final inventario = await _dbHelper.getInventario(inventarioId);
    if (inventario == null) {
      throw Exception('Inventário não encontrado');
    }

    final parcelas = await _dbHelper.getParcelasByInventario(inventarioId);

    // Criar arquivo Excel
    var excel = Excel.createExcel();
    var sheet = excel['Inventario_${inventario.nome}'];

    // Cabeçalho
    sheet.appendRow([
      'Inventario',
      'Bloco',
      'Faixa',
      'Parcela',
      'Numero_Arvore',
      'Codigo',
      'X',
      'Y',
      'Familia',
      'Nome_Cientifico',
      'DAP',
      'HT'
    ]);

    // Dados
    for (final parcela in parcelas) {
      final arvores = await _dbHelper.getArvoresByParcela(parcela.id!);

      for (final arvore in arvores) {
        sheet.appendRow([
          inventario.nome,
          parcela.bloco,
          parcela.faixa,
          parcela.parcela,
          arvore.numeroArvore,
          arvore.codigo,
          arvore.x,
          arvore.y,
          arvore.familia,
          arvore.nomeCientifico,
          arvore.dap,
          arvore.ht,
        ]);
      }
    }

    final bytes = excel.encode()!;
    final fileName = 'inventario_${inventario.nome}_${DateTime.now().millisecondsSinceEpoch}.xlsx';
    final tempFile = await _saveTempFile(bytes, fileName);

    await _shareFile(tempFile, 'Exportação Excel - ${inventario.nome}');
  }

  // Exportar para SQL
  Future<void> exportToSql(int inventarioId) async {
    final inventario = await _dbHelper.getInventario(inventarioId);
    if (inventario == null) {
      throw Exception('Inventário não encontrado');
    }

    final parcelas = await _dbHelper.getParcelasByInventario(inventarioId);

    StringBuffer sql = StringBuffer();

    // Comentário de cabeçalho
    sql.writeln('-- Exportação do Inventário: ${inventario.nome}');
    sql.writeln('-- Data: ${DateTime.now()}');
    sql.writeln('-- Total de Parcelas: ${parcelas.length}');
    sql.writeln();

    // Inserir inventário
    sql.writeln('-- Dados do Inventário');
    sql.writeln("INSERT INTO inventarios (id, nome, numero_blocos, numero_faixas, numero_parcelas, data_criacao) VALUES (");
    sql.writeln("  ${inventario.id},");
    sql.writeln("  '${_escapeSqlString(inventario.nome)}',");
    sql.writeln("  ${inventario.numeroBlocos},");
    sql.writeln("  ${inventario.numeroFaixas},");
    sql.writeln("  ${inventario.numeroParcelas},");
    sql.writeln("  '${inventario.dataCriacao.toIso8601String()}'");
    sql.writeln(");");
    sql.writeln();

    // Inserir parcelas
    sql.writeln('-- Dados das Parcelas');
    for (final parcela in parcelas) {
      sql.writeln("INSERT INTO parcelas (id, inventario_id, bloco, faixa, parcela, valor_arvores, concluida) VALUES (");
      sql.writeln("  ${parcela.id},");
      sql.writeln("  ${parcela.inventarioId},");
      sql.writeln("  ${parcela.bloco},");
      sql.writeln("  ${parcela.faixa},");
      sql.writeln("  ${parcela.parcela},");
      sql.writeln("  ${parcela.valorArvores != null ? "'${_escapeSqlString(parcela.valorArvores!)}'" : "NULL"},");
      sql.writeln("  ${parcela.concluida ? 1 : 0}");
      sql.writeln(");");
    }
    sql.writeln();

    // Inserir árvores
    sql.writeln('-- Dados das Árvores');
    int totalArvores = 0;
    for (final parcela in parcelas) {
      final arvores = await _dbHelper.getArvoresByParcela(parcela.id!);
      totalArvores += arvores.length;

      for (final arvore in arvores) {
        sql.writeln("INSERT INTO arvores (id, parcela_id, numero_arvore, codigo, x, y, familia, nome_cientifico, dap, ht) VALUES (");
        sql.writeln("  ${arvore.id},");
        sql.writeln("  ${arvore.parcelaId},");
        sql.writeln("  ${arvore.numeroArvore},");
        sql.writeln("  '${_escapeSqlString(arvore.codigo)}',");
        sql.writeln("  ${arvore.x},");
        sql.writeln("  ${arvore.y},");
        sql.writeln("  '${_escapeSqlString(arvore.familia)}',");
        sql.writeln("  '${_escapeSqlString(arvore.nomeCientifico)}',");
        sql.writeln("  ${arvore.dap},");
        sql.writeln("  ${arvore.ht}");
        sql.writeln(");");
      }
    }

    sql.writeln();
    sql.writeln('-- Total de árvores exportadas: $totalArvores');

    final sqlString = sql.toString();
    final bytes = sqlString.codeUnits;
    final fileName = 'inventario_${inventario.nome}_${DateTime.now().millisecondsSinceEpoch}.sql';
    final tempFile = await _saveTempFile(bytes, fileName);

    await _shareFile(tempFile, 'Exportação SQL - ${inventario.nome}');
  }

  // Método para escapar strings SQL
  String _escapeSqlString(String input) {
    return input.replaceAll("'", "''");
  }

  // Método para obter estatísticas do inventário
  Future<Map<String, dynamic>> getExportStats(int inventarioId) async {
    final inventario = await _dbHelper.getInventario(inventarioId);
    if (inventario == null) {
      throw Exception('Inventário não encontrado');
    }

    final parcelas = await _dbHelper.getParcelasByInventario(inventarioId);
    int totalArvores = 0;

    for (final parcela in parcelas) {
      final count = await _dbHelper.getArvoresCountByParcela(parcela.id!);
      totalArvores += count;
    }

    return {
      'nomeInventario': inventario.nome,
      'totalParcelas': parcelas.length,
      'totalArvores': totalArvores,
      'blocos': inventario.numeroBlocos,
      'faixas': inventario.numeroFaixas,
      'parcelasPorBloco': inventario.numeroParcelas,
    };
  }

  // Método para exportar dados brutos (útil para debug)
  Future<Map<String, dynamic>> exportRawData(int inventarioId) async {
    final inventario = await _dbHelper.getInventario(inventarioId);
    if (inventario == null) {
      throw Exception('Inventário não encontrado');
    }

    final parcelas = await _dbHelper.getParcelasByInventario(inventarioId);
    final List<Map<String, dynamic>> dadosCompletos = [];

    for (final parcela in parcelas) {
      final arvores = await _dbHelper.getArvoresByParcela(parcela.id!);

      for (final arvore in arvores) {
        dadosCompletos.add({
          'inventario': inventario.nome,
          'bloco': parcela.bloco,
          'faixa': parcela.faixa,
          'parcela': parcela.parcela,
          'numero_arvore': arvore.numeroArvore,
          'codigo': arvore.codigo,
          'x': arvore.x,
          'y': arvore.y,
          'familia': arvore.familia,
          'nome_cientifico': arvore.nomeCientifico,
          'dap': arvore.dap,
          'ht': arvore.ht,
        });
      }
    }

    return {
      'inventario': inventario.toMap(),
      'dados': dadosCompletos,
      'total_registros': dadosCompletos.length,
    };
  }
}