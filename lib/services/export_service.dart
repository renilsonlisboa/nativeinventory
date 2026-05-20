import 'dart:io';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../database/database_helper.dart';

class ExportService {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  // ─────────────────────────────────────────────
  // Métodos internos auxiliares
  // ─────────────────────────────────────────────

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

  Future<File> _saveTempFile(List<int> bytes, String fileName) async {
    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/$fileName');
    await file.writeAsBytes(bytes);
    return file;
  }

  List<CellValue?> _toCellValues(List<dynamic> values) {
    return values.map((e) {
      if (e == null) return null;
      if (e is num) return DoubleCellValue(e.toDouble());
      if (e is int) return IntCellValue(e);
      return TextCellValue(e.toString());
    }).toList();
  }

  /// Retorna a pasta Documentos PÚBLICA do celular.
  /// Android → /storage/emulated/0/Documents
  /// iOS     → pasta Documentos visível no app "Arquivos"
  Future<Directory> _resolveLocalDirectory() async {
    if (Platform.isAndroid) {
      await _requestStoragePermission();
      final dir = Directory('/storage/emulated/0/Documents');
      if (!await dir.exists()) await dir.create(recursive: true);
      return dir;
    }
    return getApplicationDocumentsDirectory();
  }

  /// Solicita permissão de armazenamento adequada à versão do Android.
  Future<void> _requestStoragePermission() async {
    final manageStatus = await Permission.manageExternalStorage.status;
    if (manageStatus.isGranted) return;

    final requested = await Permission.manageExternalStorage.request();
    if (requested.isGranted) return;

    final storageStatus = await Permission.storage.request();
    if (storageStatus.isDenied || storageStatus.isPermanentlyDenied) {
      throw Exception(
        'Permissão de armazenamento negada. '
            'Acesse Configurações > Aplicativos > seu app '
            '> Permissões e ative "Arquivos e mídia".',
      );
    }
  }

  // ─────────────────────────────────────────────
  // Seleção de blocos
  // ─────────────────────────────────────────────

  /// Retorna todos os blocos disponíveis para um inventário,
  /// em ordem crescente. Use este método para popular a UI de seleção.
  Future<List<int>> getBlocosDisponiveis(int inventarioId) async {
    final parcelas = await _dbHelper.getParcelasByInventario(inventarioId);
    final blocos = parcelas.map((p) => p.bloco).toSet().toList()..sort();
    return blocos;
  }

  /// Filtra a lista de parcelas de acordo com os blocos selecionados.
  /// Quando [blocosSelecionados] é nulo ou vazio, retorna todas as parcelas.
  Future<List<dynamic>> _filtrarParcelas(
      int inventarioId,
      List<int>? blocosSelecionados,
      ) async {
    final todasParcelas = await _dbHelper.getParcelasByInventario(inventarioId);
    if (blocosSelecionados == null || blocosSelecionados.isEmpty) {
      return todasParcelas;
    }
    return todasParcelas
        .where((p) => blocosSelecionados.contains(p.bloco))
        .toList();
  }

  // ─────────────────────────────────────────────
  // Geração de conteúdo CSV
  // ─────────────────────────────────────────────

  Future<String> _generateCsvContent(
      int inventarioId, {
        List<int>? blocosSelecionados,
      }) async {
    final inventario = await _dbHelper.getInventario(inventarioId);
    if (inventario == null) throw Exception('Inventário não encontrado');

    final parcelas = await _filtrarParcelas(inventarioId, blocosSelecionados);
    final anosOrdenados =
    (await _obterTodosAnosCap(inventarioId, parcelas: parcelas)).toList()
      ..sort();

    List<List<dynamic>> csvData = [];

    List<dynamic> cabecalho = [
      'Inventario', 'Bloco', 'Parcela', 'Faixa', 'Arvore', 'Fuste',
      'Codigo', 'X', 'Y', 'Familia', 'Nome_Cientifico', 'Nome_Popular',
    ];
    for (final ano in anosOrdenados) cabecalho.add('CAP_$ano');
    cabecalho.addAll([
      'HC','anoHC', 'HT', 'anoHT', 'Forma_Fuste', 'Posicao_Social', 'Fitossanidade',
      'Forma_Copa', 'Posicao_Copa', 'Ano_Ingresso', 'Info_Morta',
      'Ano_Morta', 'Observacoes',
    ]);
    csvData.add(cabecalho);

    for (final parcela in parcelas) {
      final arvores = await _dbHelper.getArvoresByParcela(parcela.id!);
      for (final arvore in arvores) {
        final capsPorAno = await _capsPorAno(arvore.id!);

        List<dynamic> linha = [
          inventario.nome, parcela.bloco, parcela.parcela, parcela.faixa,
          arvore.numeroArvore, arvore.numeroFuste, arvore.codigo,
          arvore.x.toStringAsFixed(2), arvore.y.toStringAsFixed(2),
          arvore.familia, arvore.nomeCientifico, arvore.nomePopular,
        ];
        for (final ano in anosOrdenados) {
          linha.add(capsPorAno[ano] != null
              ? capsPorAno[ano]!.toStringAsFixed(2)
              : '');
        }
        linha.addAll([
          arvore.hc != null ? arvore.hc!.toStringAsFixed(2) : '',
          arvore.anoHC ?? '',
          arvore.ht != null ? arvore.ht!.toStringAsFixed(2) : '',
          arvore.anoHT ?? '',
          arvore.formaFuste ?? '', arvore.posiSoc ?? '',
          arvore.fitossanidade ?? '', arvore.formaCopa ?? '',
          arvore.posiCopa ?? '', arvore.dataIngresso ?? '',
          arvore.infoMorte ?? '', arvore.dataMorte ?? '',
          arvore.observation ?? '',
        ]);
        csvData.add(linha);
      }
    }

    return const ListToCsvConverter().convert(csvData);
  }

  // ─────────────────────────────────────────────
  // Geração de bytes XLSX
  // ─────────────────────────────────────────────

  Future<List<int>> _generateXlsxBytes(
      int inventarioId, {
        List<int>? blocosSelecionados,
      }) async {
    final inventario = await _dbHelper.getInventario(inventarioId);
    if (inventario == null) throw Exception('Inventário não encontrado');

    final parcelas = await _filtrarParcelas(inventarioId, blocosSelecionados);
    final anosOrdenados =
    (await _obterTodosAnosCap(inventarioId, parcelas: parcelas)).toList()
      ..sort();

    var excel = Excel.createExcel();
    var sheet = excel['Inventario_${inventario.nome}'];

    List<dynamic> cabecalho = [
      'Inventario', 'Bloco', 'Parcela', 'Faixa', 'Árvore', 'Fuste',
      'Codigo', 'X', 'Y', 'Familia', 'Nome_Cientifico', 'Nome_Popular',
    ];
    for (final ano in anosOrdenados) cabecalho.add('CAP_$ano');
    cabecalho.addAll([
      'HC', 'anoHC' 'HT', 'anoHT' 'Forma_Fuste', 'Posicao_Social', 'Fitossanidade',
      'Forma_Copa', 'Posicao_Copa', 'AnoIngresso', 'InfoMorta',
      'AnoMorta', 'Observações',
    ]);
    sheet.appendRow(_toCellValues(cabecalho));

    for (final parcela in parcelas) {
      final arvores = await _dbHelper.getArvoresByParcela(parcela.id!);
      for (final arvore in arvores) {
        final capsPorAno = await _capsPorAno(arvore.id!);

        List<dynamic> linha = [
          inventario.nome, parcela.bloco, parcela.parcela, parcela.faixa,
          arvore.numeroArvore, arvore.numeroFuste, arvore.codigo,
          arvore.x, arvore.y, arvore.familia,
          arvore.nomeCientifico, arvore.nomePopular,
        ];
        for (final ano in anosOrdenados) linha.add(capsPorAno[ano] ?? '');
        linha.addAll([
          arvore.hc,
          arvore.anoHC ?? '',
          arvore.ht,
          arvore.anoHT ?? '',
          arvore.formaFuste ?? '',
          arvore.posiSoc ?? '',
          arvore.fitossanidade ?? '',
          arvore.formaCopa ?? '',
          arvore.posiCopa ?? '',
          arvore.dataIngresso ?? 0,
          arvore.infoMorte ?? 0,
          arvore.dataMorte ?? 0,
          arvore.observation,
        ]);
        sheet.appendRow(_toCellValues(linha));
      }
    }

    return excel.encode()!;
  }

  // ─────────────────────────────────────────────
  // Geração de conteúdo SQL
  // ─────────────────────────────────────────────

  Future<String> _generateSqlContent(
      int inventarioId, {
        List<int>? blocosSelecionados,
      }) async {
    final inventario = await _dbHelper.getInventario(inventarioId);
    if (inventario == null) throw Exception('Inventário não encontrado');

    final parcelas = await _filtrarParcelas(inventarioId, blocosSelecionados);
    StringBuffer sql = StringBuffer();

    final blocoDesc = (blocosSelecionados == null || blocosSelecionados.isEmpty)
        ? 'todos os blocos'
        : 'blocos: ${blocosSelecionados.join(', ')}';

    sql.writeln('-- Exportação do Inventário: ${inventario.nome}');
    sql.writeln('-- Data: ${DateTime.now()}');
    sql.writeln('-- Filtro: $blocoDesc');
    sql.writeln('-- Total de Parcelas: ${parcelas.length}');
    sql.writeln();

    sql.writeln('-- Dados do Inventário');
    sql.writeln(
        "INSERT INTO inventarios (id, nome, numero_blocos, numero_faixas, numero_parcelas, data_criacao) VALUES (");
    sql.writeln("  ${inventario.id}, '${_escapeSqlString(inventario.nome)}',");
    sql.writeln("  ${inventario.numeroBlocos}, ${inventario.numeroFaixas},");
    sql.writeln("  ${inventario.numeroParcelas}, '${inventario.dataCriacao}'");
    sql.writeln(");");
    sql.writeln();

    sql.writeln('-- Dados das Parcelas');
    for (final parcela in parcelas) {
      sql.writeln(
          "INSERT INTO parcelas (id, inventario_id, bloco, faixa, parcela, valor_arvores, concluida) VALUES (");
      sql.writeln(
          "  ${parcela.id}, ${parcela.inventarioId}, ${parcela.bloco},");
      sql.writeln("  ${parcela.faixa}, ${parcela.parcela},");
      sql.writeln(
          "  ${parcela.valorArvores != null ? "'${_escapeSqlString(parcela.valorArvores!)}'" : "NULL"},");
      sql.writeln("  ${parcela.concluida ? 1 : 0}");
      sql.writeln(");");
    }
    sql.writeln();

    sql.writeln('-- Dados das Árvores');
    int totalArvores = 0;
    for (final parcela in parcelas) {
      final arvores = await _dbHelper.getArvoresByParcela(parcela.id!);
      totalArvores += arvores.length;

      for (final arvore in arvores) {
        sql.writeln(
            "INSERT INTO arvores (id, parcela_id, numero_arvore, codigo, x, y, familia, nome_cientifico, cap, ht) VALUES (");
        sql.writeln(
            "  ${arvore.id}, ${arvore.parcelaId}, ${arvore.numeroArvore},");
        sql.writeln(
            "  '${_escapeSqlString(arvore.codigo)}', ${arvore.x}, ${arvore.y},");
        sql.writeln(
            "  '${_escapeSqlString(arvore.familia)}', '${_escapeSqlString(arvore.nomeCientifico)}',");
        sql.writeln("  ${arvore.cap}, ${arvore.ht}");
        sql.writeln(");");

        final historicoCap = await _dbHelper.getCapHistoricoByArvore(arvore.id!);
        for (final capItem in historicoCap) {
          sql.writeln(
              "INSERT INTO arvores_cap_historico (arvore_id, ano, cap) VALUES (${arvore.id}, ${capItem.ano}, ${capItem.cap});");
        }
      }
    }

    sql.writeln();
    sql.writeln('-- Total de árvores exportadas: $totalArvores');
    return sql.toString();
  }

  // ─────────────────────────────────────────────
  // Sufixo descritivo para nome de arquivo
  // ─────────────────────────────────────────────

  String _blocosSuffix(List<int>? blocosSelecionados) {
    if (blocosSelecionados == null || blocosSelecionados.isEmpty) return '';
    return '_blocos${blocosSelecionados.join('-')}';
  }

  // ─────────────────────────────────────────────
  // COMPARTILHAR via Share Sheet
  // ─────────────────────────────────────────────

  /// [blocosSelecionados] — lista de blocos a exportar.
  /// Passe null ou lista vazia para exportar todos os blocos.
  Future<void> exportToCsv(
      int inventarioId, {
        List<int>? blocosSelecionados,
      }) async {
    final inventario = await _dbHelper.getInventario(inventarioId);
    if (inventario == null) throw Exception('Inventário não encontrado');
    final content = await _generateCsvContent(
      inventarioId,
      blocosSelecionados: blocosSelecionados,
    );
    final suffix = _blocosSuffix(blocosSelecionados);
    final file = await _saveTempFile(
      content.codeUnits,
      'inventario_${inventario.nome}$suffix\_${DateTime.now().millisecondsSinceEpoch}.csv',
    );
    await _shareFile(file, 'Exportação CSV - ${inventario.nome}');
  }

  Future<void> exportToXlsx(
      int inventarioId, {
        List<int>? blocosSelecionados,
      }) async {
    final inventario = await _dbHelper.getInventario(inventarioId);
    if (inventario == null) throw Exception('Inventário não encontrado');
    final bytes = await _generateXlsxBytes(
      inventarioId,
      blocosSelecionados: blocosSelecionados,
    );
    final suffix = _blocosSuffix(blocosSelecionados);
    final file = await _saveTempFile(
      bytes,
      'inventario_${inventario.nome}$suffix\_${DateTime.now().millisecondsSinceEpoch}.xlsx',
    );
    await _shareFile(file, 'Exportação Excel - ${inventario.nome}');
  }

  Future<void> exportToSql(
      int inventarioId, {
        List<int>? blocosSelecionados,
      }) async {
    final inventario = await _dbHelper.getInventario(inventarioId);
    if (inventario == null) throw Exception('Inventário não encontrado');
    final content = await _generateSqlContent(
      inventarioId,
      blocosSelecionados: blocosSelecionados,
    );
    final suffix = _blocosSuffix(blocosSelecionados);
    final file = await _saveTempFile(
      content.codeUnits,
      'inventario_${inventario.nome}$suffix\_${DateTime.now().millisecondsSinceEpoch}.sql',
    );
    await _shareFile(file, 'Exportação SQL - ${inventario.nome}');
  }

  // ─────────────────────────────────────────────
  // SALVAR LOCALMENTE na pasta Documentos pública
  // ─────────────────────────────────────────────

  Future<File> saveCsvToDownloads(
      int inventarioId, {
        List<int>? blocosSelecionados,
      }) async {
    final inventario = await _dbHelper.getInventario(inventarioId);
    if (inventario == null) throw Exception('Inventário não encontrado');
    final content = await _generateCsvContent(
      inventarioId,
      blocosSelecionados: blocosSelecionados,
    );
    final dir = await _resolveLocalDirectory();
    final suffix = _blocosSuffix(blocosSelecionados);
    final file = File(
        '${dir.path}/inventario_${inventario.nome}$suffix\_${DateTime.now().millisecondsSinceEpoch}.csv');
    await file.writeAsString(content, flush: true);
    return file;
  }

  Future<File> saveXlsxToDownloads(
      int inventarioId, {
        List<int>? blocosSelecionados,
      }) async {
    final inventario = await _dbHelper.getInventario(inventarioId);
    if (inventario == null) throw Exception('Inventário não encontrado');
    final bytes = await _generateXlsxBytes(
      inventarioId,
      blocosSelecionados: blocosSelecionados,
    );
    final dir = await _resolveLocalDirectory();
    final suffix = _blocosSuffix(blocosSelecionados);
    final file = File(
        '${dir.path}/inventario_${inventario.nome}$suffix\_${DateTime.now().millisecondsSinceEpoch}.xlsx');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  Future<File> saveSqlToDownloads(
      int inventarioId, {
        List<int>? blocosSelecionados,
      }) async {
    final inventario = await _dbHelper.getInventario(inventarioId);
    if (inventario == null) throw Exception('Inventário não encontrado');
    final content = await _generateSqlContent(
      inventarioId,
      blocosSelecionados: blocosSelecionados,
    );
    final dir = await _resolveLocalDirectory();
    final suffix = _blocosSuffix(blocosSelecionados);
    final file = File(
        '${dir.path}/inventario_${inventario.nome}$suffix\_${DateTime.now().millisecondsSinceEpoch}.sql');
    await file.writeAsString(content, flush: true);
    return file;
  }

  // ─────────────────────────────────────────────
  // Utilitários
  // ─────────────────────────────────────────────

  Future<Map<int, double>> _capsPorAno(int arvoreId) async {
    final historico = await _dbHelper.getCapHistoricoByArvore(arvoreId);
    return {for (final item in historico) item.ano: item.cap};
  }

  String _escapeSqlString(String input) => input.replaceAll("'", "''");

  /// Aceita uma lista de parcelas já filtradas para evitar re-consulta ao BD.
  Future<Set<int>> _obterTodosAnosCap(
      int inventarioId, {
        List<dynamic>? parcelas,
      }) async {
    final lista =
        parcelas ?? await _dbHelper.getParcelasByInventario(inventarioId);
    final todosAnos = <int>{};
    for (final parcela in lista) {
      final arvores = await _dbHelper.getArvoresByParcela(parcela.id!);
      for (final arvore in arvores) {
        final historico = await _dbHelper.getCapHistoricoByArvore(arvore.id!);
        todosAnos.addAll(historico.map((e) => e.ano));
      }
    }
    return todosAnos;
  }

  Future<Map<String, dynamic>> getExportStats(
      int inventarioId, {
        List<int>? blocosSelecionados,
      }) async {
    final inventario = await _dbHelper.getInventario(inventarioId);
    if (inventario == null) throw Exception('Inventário não encontrado');

    final parcelas = await _filtrarParcelas(inventarioId, blocosSelecionados);
    int totalArvores = 0;
    for (final parcela in parcelas) {
      totalArvores += await _dbHelper.getArvoresCountByParcela(parcela.id!);
    }

    final todosAnos =
    await _obterTodosAnosCap(inventarioId, parcelas: parcelas);
    return {
      'nomeInventario': inventario.nome,
      'totalParcelas': parcelas.length,
      'totalArvores': totalArvores,
      'blocos': inventario.numeroBlocos,
      'faixas': inventario.numeroFaixas,
      'parcelasPorBloco': inventario.numeroParcelas,
      'blocosSelecionados': blocosSelecionados ?? [],
      'anosCap': todosAnos.toList()..sort(),
      'totalAnosCap': todosAnos.length,
    };
  }

  Future<Map<String, dynamic>> exportRawData(
      int inventarioId, {
        List<int>? blocosSelecionados,
      }) async {
    final inventario = await _dbHelper.getInventario(inventarioId);
    if (inventario == null) throw Exception('Inventário não encontrado');

    final parcelas = await _filtrarParcelas(inventarioId, blocosSelecionados);
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
          'nome_popular': arvore.nomePopular,
          'historico_cap': await _capsPorAno(arvore.id!),
          'hc': arvore.hc,
          'anoHC': arvore.anoHC,
          'ht': arvore.ht,
          'anoHT': arvore.anoHT,
          'forma_fuste': arvore.formaFuste,
          'posicao_social': arvore.posiSoc,
          'fitossanidade': arvore.fitossanidade,
          'forma_copa': arvore.formaCopa,
          'posicao_copa': arvore.posiCopa,
          'anoIngresso': arvore.dataIngresso,
          'infoMorta': arvore.infoMorte,
          'anoMorta': arvore.dataMorte,
          'observation': arvore.observation,
        });
      }
    }

    return {
      'inventario': inventario.toMap(),
      'dados': dadosCompletos,
      'total_registros': dadosCompletos.length,
      'blocosSelecionados': blocosSelecionados ?? [],
    };
  }
}