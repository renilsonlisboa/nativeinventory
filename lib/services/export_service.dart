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

  // Exportar para CSV com apenas colunas CAP_ANO
  Future<void> exportToCsv(int inventarioId) async {
    final inventario = await _dbHelper.getInventario(inventarioId);
    if (inventario == null) {
      throw Exception('Inventário não encontrado');
    }

    final parcelas = await _dbHelper.getParcelasByInventario(inventarioId);

    // Primeiro, coletar todos os anos únicos de CAP de todo o inventário
    final todosAnos = await _obterTodosAnosCap(inventarioId);
    final anosOrdenados = todosAnos.toList()..sort();

    List<List<dynamic>> csvData = [];

    // Cabeçalho SEM coluna CAP individual
    List<dynamic> cabecalho = [
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
      'HT',
      // REMOVIDO: 'CAP' e 'HC'
    ];

    // Adicionar apenas colunas CAP_ANO para cada ano histórico
    for (final ano in anosOrdenados) {
      cabecalho.add('CAP_$ano');
    }

    csvData.add(cabecalho);

    // Dados
    for (final parcela in parcelas) {
      final arvores = await _dbHelper.getArvoresByParcela(parcela.id!);

      for (final arvore in arvores) {
        // Obter histórico de CAP para esta árvore
        final historicoCap = await _dbHelper.getCapHistoricoByArvore(arvore.id!);
        final capsPorAno = <int, double>{};
        for (final item in historicoCap) {
          capsPorAno[item.ano] = item.cap;
        }

        // Linha SEM coluna CAP individual
        List<dynamic> linha = [
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
          arvore.ht.toStringAsFixed(2),
          // REMOVIDO: CAP atual e HC
        ];

        // Adicionar valores CAP para cada ano histórico
        for (final ano in anosOrdenados) {
          final valorCap = capsPorAno[ano];
          linha.add(valorCap != null ? valorCap.toStringAsFixed(2) : '');
        }

        csvData.add(linha);
      }
    }

    String csv = const ListToCsvConverter().convert(csvData);
    final bytes = csv.codeUnits;

    final fileName = 'inventario_${inventario.nome}_${DateTime.now().millisecondsSinceEpoch}.csv';
    final tempFile = await _saveTempFile(bytes, fileName);

    await _shareFile(tempFile, 'Exportação CSV - ${inventario.nome}');
  }

  // Exportar para XLSX com apenas colunas CAP_ANO
  Future<void> exportToXlsx(int inventarioId) async {
    final inventario = await _dbHelper.getInventario(inventarioId);
    if (inventario == null) {
      throw Exception('Inventário não encontrado');
    }

    final parcelas = await _dbHelper.getParcelasByInventario(inventarioId);

    // Coletar todos os anos únicos de CAP
    final todosAnos = await _obterTodosAnosCap(inventarioId);
    final anosOrdenados = todosAnos.toList()..sort();

    // Criar arquivo Excel
    var excel = Excel.createExcel();
    var sheet = excel['Inventario_${inventario.nome}'];

    // Cabeçalho SEM coluna CAP individual
    List<dynamic> cabecalho = [
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
      'HT',
      // REMOVIDO: 'CAP' e 'HC'
    ];

    // Adicionar apenas colunas CAP_ANO para cada ano histórico
    for (final ano in anosOrdenados) {
      cabecalho.add('CAP_$ano');
    }

    sheet.appendRow(cabecalho);

    // Dados
    for (final parcela in parcelas) {
      final arvores = await _dbHelper.getArvoresByParcela(parcela.id!);

      for (final arvore in arvores) {
        // Obter histórico de CAP para esta árvore
        final historicoCap = await _dbHelper.getCapHistoricoByArvore(arvore.id!);
        final capsPorAno = <int, double>{};
        for (final item in historicoCap) {
          capsPorAno[item.ano] = item.cap;
        }

        // Linha SEM coluna CAP individual
        List<dynamic> linha = [
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
          arvore.ht,
          // REMOVIDO: CAP atual e HC
        ];

        // Adicionar valores CAP para cada ano histórico
        for (final ano in anosOrdenados) {
          final valorCap = capsPorAno[ano];
          linha.add(valorCap ?? '');
        }

        sheet.appendRow(linha);
      }
    }

    final bytes = excel.encode()!;
    final fileName = 'inventario_${inventario.nome}_${DateTime.now().millisecondsSinceEpoch}.xlsx';
    final tempFile = await _saveTempFile(bytes, fileName);

    await _shareFile(tempFile, 'Exportação Excel - ${inventario.nome}');
  }

  // Método auxiliar para obter todos os anos únicos de CAP de um inventário
  Future<Set<int>> _obterTodosAnosCap(int inventarioId) async {
    final parcelas = await _dbHelper.getParcelasByInventario(inventarioId);
    final todosAnos = <int>{};

    for (final parcela in parcelas) {
      final arvores = await _dbHelper.getArvoresByParcela(parcela.id!);

      for (final arvore in arvores) {
        final historico = await _dbHelper.getCapHistoricoByArvore(arvore.id!);
        for (final item in historico) {
          todosAnos.add(item.ano);
        }
      }
    }

    return todosAnos;
  }

  // Exportar para SQL (mantido igual - aqui mantemos o CAP na tabela arvores pois é parte do modelo interno)
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
    sql.writeln("  '${inventario.dataCriacao}'");
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
        sql.writeln("INSERT INTO arvores (id, parcela_id, numero_arvore, codigo, x, y, familia, nome_cientifico, cap, ht) VALUES (");
        sql.writeln("  ${arvore.id},");
        sql.writeln("  ${arvore.parcelaId},");
        sql.writeln("  ${arvore.numeroArvore},");
        sql.writeln("  '${_escapeSqlString(arvore.codigo)}',");
        sql.writeln("  ${arvore.x},");
        sql.writeln("  ${arvore.y},");
        sql.writeln("  '${_escapeSqlString(arvore.familia)}',");
        sql.writeln("  '${_escapeSqlString(arvore.nomeCientifico)}',");
        sql.writeln("  ${arvore.cap},");
        sql.writeln("  ${arvore.ht}");
        sql.writeln(");");

        // Inserir histórico de CAP
        final historicoCap = await _dbHelper.getCapHistoricoByArvore(arvore.id!);
        for (final capItem in historicoCap) {
          sql.writeln("INSERT INTO arvores_cap_historico (arvore_id, ano, cap) VALUES (");
          sql.writeln("  ${arvore.id},");
          sql.writeln("  ${capItem.ano},");
          sql.writeln("  ${capItem.cap}");
          sql.writeln(");");
        }
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
    final todosAnos = await _obterTodosAnosCap(inventarioId);

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
      'anosCap': todosAnos.toList()..sort(),
      'totalAnosCap': todosAnos.length,
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
        final historicoCap = await _dbHelper.getCapHistoricoByArvore(arvore.id!);
        final capsPorAno = <int, double>{};
        for (final item in historicoCap) {
          capsPorAno[item.ano] = item.cap;
        }

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
          'ht': arvore.ht,
          'historico_cap': capsPorAno,
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