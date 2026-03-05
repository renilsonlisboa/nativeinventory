import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/inventario.dart';
import '../models/parcela.dart';
import '../models/arvore.dart';
import '../models/cap_historico.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  static Database? _database;

  static const int _databaseVersion = 9;

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'inventario.db');
    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await _createTables(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    print('🔄 Migrando banco da versão $oldVersion para $newVersion');

    // Migração versão por versão para evitar pulos
    for (int version = oldVersion + 1; version <= newVersion; version++) {
      print('📋 Processando migração para versão $version');

      switch (version) {
        case 2:
        // Na versão 2, apenas criamos os índices se não existirem
          await _createIndexes(db);
          print('✅ Índices criados na migração v2');
          break;

        case 3:
        // Na versão 3, recriamos os índices (pode ser necessário para novos índices)
          await _createIndexes(db);
          print('✅ Índices atualizados na migração v3');
          break;

        case 4:
          await _safeAddColumn(db, 'inventarios', 'dap_minimo', 'REAL NOT NULL DEFAULT 10.0');
          break;

        case 5:
          await _createCapHistoricoTable(db);
          await _createCapHistoricoIndexes(db);
          print('✅ Tabela de histórico CAP criada na migração v5');
          break;

        case 6:
          await _safeAddColumn(db, 'inventarios', 'ano', 'INTEGER NOT NULL DEFAULT 2025');
          break;

        case 7:
          await _safeAddColumn(db, 'arvores', 'cap', 'REAL NOT NULL DEFAULT 0');
          await _safeAddColumn(db, 'arvores', 'hc', 'REAL NOT NULL DEFAULT 0');
          break;

        case 8:
          await _createTaxonomiaTables(db);
          await _createTaxonomiaIndexes(db);
          print('✅ Tabelas de taxonomia criadas na migração v8');
          break;

        case 9:
          await _safeAddColumn(
              db,
              'arvores',
              'numero_fuste',
              'INTEGER NOT NULL DEFAULT 1'
          );
          print('✅ Coluna numero_fuste adicionada na tabela arvores (migração v9)');
          break;
      }
    }
  }

// Método auxiliar para adicionar colunas apenas se não existirem
  Future<void> _safeAddColumn(Database db, String table, String column, String definition) async {
    try {
      // Verifica se a coluna já existe
      final columns = await db.rawQuery("PRAGMA table_info($table)");
      final columnExists = columns.any((col) => col['name'] == column);

      if (!columnExists) {
        await db.execute('ALTER TABLE $table ADD COLUMN $column $definition');
        print('✅ Coluna $column adicionada na tabela $table');
      } else {
        print('ℹ️ Coluna $column já existe na tabela $table - pulando');
      }
    } catch (e) {
      print('⚠️ Erro ao verificar/adicionar coluna $column na tabela $table: $e');
      // Em caso de erro, tenta adicionar a coluna ignorando erros de duplicação
      try {
        await db.execute('ALTER TABLE $table ADD COLUMN $column $definition');
        print('✅ Coluna $column adicionada com sucesso (segunda tentativa)');
      } catch (e2) {
        print('❌ Falha ao adicionar coluna $column: $e2');
      }
    }
  }

  Future<void> _createTables(Database db) async {
    // Tabela de inventários
    await db.execute('''
      CREATE TABLE inventarios(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nome TEXT NOT NULL,
        area_inventariada REAL NOT NULL,
        numero_blocos INTEGER NOT NULL,
        numero_faixas INTEGER NOT NULL,
        numero_parcelas INTEGER NOT NULL,
        dap_minimo REAL NOT NULL DEFAULT 10.0,
        data_criacao TEXT NOT NULL,
        ano INTEGER NOT NULL DEFAULT 2025
      )
    ''');

    // Tabela de parcelas
    await db.execute('''
      CREATE TABLE parcelas(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        inventario_id INTEGER NOT NULL,
        bloco INTEGER NOT NULL,
        faixa INTEGER NOT NULL,
        parcela INTEGER NOT NULL,
        valor_arvores TEXT,
        concluida INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (inventario_id) REFERENCES inventarios (id) ON DELETE CASCADE
      )
    ''');

    // Tabela de árvores
    await _createArvoresTable(db);

    // Tabela de histórico de CAPs
    await _createCapHistoricoTable(db);

    // Tabelas de taxonomia
    await _createTaxonomiaTables(db);

    // Índices
    await _createIndexes(db);
    await _createCapHistoricoIndexes(db);
    await _createTaxonomiaIndexes(db);

    print('✅ Todas as tabelas criadas com sucesso');
  }

  Future<void> _createTaxonomiaTables(Database db) async {
    await db.execute('''
      CREATE TABLE familias(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nome TEXT UNIQUE NOT NULL,
        fonte TEXT DEFAULT 'REFLORA',
        data_importacao DATETIME DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    await db.execute('''
      CREATE TABLE especies(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        familia_id INTEGER NOT NULL,
        nome_cientifico TEXT NOT NULL,
        sinonimos TEXT,
        nome_popular TEXT,
        fonte TEXT DEFAULT 'REFLORA',
        data_importacao DATETIME DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (familia_id) REFERENCES familias (id) ON DELETE CASCADE,
        UNIQUE(familia_id, nome_cientifico)
      )
    ''');
  }

  Future<void> _createTaxonomiaIndexes(Database db) async {
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_familias_nome ON familias(nome)
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_especies_familia_id ON especies(familia_id)
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_especies_nome_cientifico ON especies(nome_cientifico)
    ''');
  }

  Future<void> _createArvoresTable(Database db) async {
    await db.execute('''
      CREATE TABLE arvores(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        parcela_id INTEGER NOT NULL,
        numero_arvore INTEGER NOT NULL,
        numero_fuste INTEGER NOT NULL,
        codigo TEXT NOT NULL,
        x REAL NOT NULL,
        y REAL NOT NULL,
        familia TEXT NOT NULL,
        nome_cientifico TEXT NOT NULL,
        cap REAL NOT NULL DEFAULT 0,
        hc REAL DEFAULT 0,
        ht REAL,
        FOREIGN KEY (parcela_id) REFERENCES parcelas (id) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> _createCapHistoricoTable(Database db) async {
    await db.execute('''
      CREATE TABLE arvores_cap_historico(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        arvore_id INTEGER NOT NULL,
        ano INTEGER NOT NULL,
        cap REAL NOT NULL,
        FOREIGN KEY (arvore_id) REFERENCES arvores (id) ON DELETE CASCADE,
        UNIQUE(arvore_id, ano)
      )
    ''');
  }

  Future<void> _createIndexes(Database db) async {
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_parcelas_inventario_id ON parcelas(inventario_id)
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_parcelas_bloco_faixa_parcela ON parcelas(bloco, faixa, parcela)
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_arvores_parcela_id ON arvores(parcela_id)
    ''');
  }

  Future<void> _createCapHistoricoIndexes(Database db) async {
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_cap_historico_arvore_id ON arvores_cap_historico(arvore_id)
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_cap_historico_ano ON arvores_cap_historico(ano)
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_cap_historico_arvore_ano ON arvores_cap_historico(arvore_id, ano)
    ''');
  }

  // ========== MÉTODOS PARA TAXONOMIA ==========

  Future<int> insertFamilia(String nome) async {
    final db = await database;
    try {
      return await db.insert(
        'familias',
        {'nome': nome},
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    } catch (e) {
      // Se falhar, tenta obter o ID da existente
      final id = await getFamiliaId(nome);
      if (id != -1) return id;
      rethrow;
    }
  }

  Future<int> insertEspecie(int familiaId, String nomeCientifico, {String? sinonimos, String? nomePopular}) async {
    final db = await database;
    try {
      return await db.insert('especies', {
        'familia_id': familiaId,
        'nome_cientifico': nomeCientifico,
        'sinonimos': sinonimos,
        'nome_popular': nomePopular,
      });
    } catch (e) {
      return 0;
    }
  }

  Future<List<String>> getFamilias({String? filtro}) async {
    final db = await database;
    String where = '';
    List<dynamic> whereArgs = [];

    if (filtro != null && filtro.isNotEmpty) {
      where = 'nome LIKE ?';
      whereArgs = ['%$filtro%'];
    }

    final List<Map<String, dynamic>> maps = await db.query(
        'familias',
        where: where,
        whereArgs: whereArgs,
        orderBy: 'nome',
        limit: 50
    );

    return List.generate(maps.length, (i) => maps[i]['nome'] as String);
  }

  Future<List<String>> getEspeciesByFamilia(String familia, {String? filtro}) async {
    final db = await database;

    String where = 'f.nome = ?';
    List<dynamic> whereArgs = [familia];

    if (filtro != null && filtro.isNotEmpty) {
      where += ' AND (e.nome_cientifico LIKE ? OR e.sinonimos LIKE ?)';
      whereArgs.add('%$filtro%');
      whereArgs.add('%$filtro%');
    }

    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT DISTINCT e.nome_cientifico 
      FROM especies e
      INNER JOIN familias f ON e.familia_id = f.id
      WHERE $where
      ORDER BY e.nome_cientifico
      LIMIT 50
    ''', whereArgs);

    return List.generate(maps.length, (i) => maps[i]['nome_cientifico'] as String);
  }

  Future<void> clearTaxonomia() async {
    final db = await database;
    await db.delete('especies');
    await db.delete('familias');
  }

  Future<int> getCountFamilias() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM familias');
    return result.first['count'] as int;
  }

  Future<int> getCountEspecies() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM especies');
    return result.first['count'] as int;
  }

  Future<bool> taxonomiaTablesExist() async {
    final db = await database;
    try {
      await db.rawQuery('SELECT 1 FROM familias LIMIT 1');
      await db.rawQuery('SELECT 1 FROM especies LIMIT 1');
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> ensureTaxonomiaTablesExist() async {
    if (!await taxonomiaTablesExist()) {
      final db = await database;
      await _createTaxonomiaTables(db);
      await _createTaxonomiaIndexes(db);
      print('✅ Tabelas de taxonomia criadas via ensure');
    }
  }

  // ========== MÉTODOS PARA HISTÓRICO DE CAP ==========

  Future<void> inserirOuAtualizarCapHistorico(int arvoreId, int ano, double cap) async {
    final db = await database;
    await db.insert(
      'arvores_cap_historico',
      {
        'arvore_id': arvoreId,
        'ano': ano,
        'cap': cap,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<CapHistorico>> getCapHistoricoByArvore(int arvoreId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'arvores_cap_historico',
      where: 'arvore_id = ?',
      whereArgs: [arvoreId],
      orderBy: 'ano DESC',
    );
    return List.generate(maps.length, (i) => CapHistorico.fromMap(maps[i]));
  }

  Future<Map<int, double>> getCapsPorAnoByArvore(int arvoreId) async {
    final historico = await getCapHistoricoByArvore(arvoreId);
    Map<int, double> caps = {};
    for (var item in historico) {
      caps[item.ano] = item.cap;
    }
    return caps;
  }

  Future<List<int>> getAnosComCapturaByArvore(int arvoreId) async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT DISTINCT ano FROM arvores_cap_historico 
      WHERE arvore_id = ? 
      ORDER BY ano DESC
    ''', [arvoreId]);

    return result.map((map) => map['ano'] as int).toList();
  }

  Future<double?> getCapPorAno(int arvoreId, int ano) async {
    final db = await database;
    final result = await db.query(
      'arvores_cap_historico',
      where: 'arvore_id = ? AND ano = ?',
      whereArgs: [arvoreId, ano],
    );

    if (result.isNotEmpty) {
      return result.first['cap'] as double;
    }
    return null;
  }

  Future<void> deletarCapHistoricoByArvore(int arvoreId) async {
    final db = await database;
    await db.delete(
      'arvores_cap_historico',
      where: 'arvore_id = ?',
      whereArgs: [arvoreId],
    );
  }

  Future<List<int>> getTodosAnosComCaptura() async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT DISTINCT ano FROM arvores_cap_historico 
      ORDER BY ano DESC
    ''');

    return result.map((map) => map['ano'] as int).toList();
  }

  // ========== MÉTODOS PARA INVENTÁRIOS ==========

  Future<int> insertInventario(Inventario inventario) async {
    final db = await database;
    return await db.insert('inventarios', inventario.toMap());
  }

  Future<List<Inventario>> getInventarios() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'inventarios',
      orderBy: 'data_criacao DESC',
    );
    return List.generate(maps.length, (i) => Inventario.fromMap(maps[i]));
  }

  Future<Inventario?> getInventario(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'inventarios',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) {
      return Inventario.fromMap(maps.first);
    }
    return null;
  }

  Future<int> updateInventario(Inventario inventario) async {
    final db = await database;
    return await db.update(
      'inventarios',
      inventario.toMap(),
      where: 'id = ?',
      whereArgs: [inventario.id],
    );
  }

  Future<int> deleteInventario(int id) async {
    final db = await database;
    return await db.delete(
      'inventarios',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ========== MÉTODOS PARA PARCELAS ==========

  Future<int> insertParcela(Parcela parcela) async {
    final db = await database;
    return await db.insert('parcelas', parcela.toMap());
  }

  Future<void> insertParcelas(List<Parcela> parcelas) async {
    final db = await database;
    final batch = db.batch();
    for (var parcela in parcelas) {
      batch.insert('parcelas', parcela.toMap());
    }
    await batch.commit();
  }

  Future<List<Parcela>> getParcelasByInventario(int inventarioId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'parcelas',
      where: 'inventario_id = ?',
      whereArgs: [inventarioId],
      orderBy: 'bloco, faixa, parcela',
    );
    return List.generate(maps.length, (i) => Parcela.fromMap(maps[i]));
  }

  Future<Parcela?> getParcela(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'parcelas',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) {
      return Parcela.fromMap(maps.first);
    }
    return null;
  }

  Future<int> updateParcela(Parcela parcela) async {
    final db = await database;
    return await db.update(
      'parcelas',
      parcela.toMap(),
      where: 'id = ?',
      whereArgs: [parcela.id],
    );
  }

  Future<int> deleteParcela(int id) async {
    final db = await database;
    return await db.delete(
      'parcelas',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> getParcelasConcluidasCount(int inventarioId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) FROM parcelas WHERE inventario_id = ? AND concluida = 1',
      [inventarioId],
    );
    return result.first.values.first as int;
  }

  Future<int> getTotalParcelasCount(int inventarioId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) FROM parcelas WHERE inventario_id = ?',
      [inventarioId],
    );
    return result.first.values.first as int;
  }

  Future<List<int>> getBlocosUnicos(int inventarioId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT DISTINCT bloco FROM parcelas WHERE inventario_id = ? ORDER BY bloco',
      [inventarioId],
    );
    return result.map((map) => map['bloco'] as int).toList();
  }

  Future<List<int>> getFaixasUnicas(int inventarioId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT DISTINCT faixa FROM parcelas WHERE inventario_id = ? ORDER BY faixa',
      [inventarioId],
    );
    return result.map((map) => map['faixa'] as int).toList();
  }

  Future<List<int>> getParcelasUnicas(int inventarioId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT DISTINCT parcela FROM parcelas WHERE inventario_id = ? ORDER BY parcela',
      [inventarioId],
    );
    return result.map((map) => map['parcela'] as int).toList();
  }

  // ========== MÉTODOS PARA ÁRVORES ==========

  Future<int> insertArvore(Arvore arvore) async {
    final db = await database;
    return await db.insert('arvores', arvore.toMap());
  }

  Future<void> insertArvores(List<Arvore> arvores) async {
    final db = await database;
    final batch = db.batch();
    for (var arvore in arvores) {
      batch.insert('arvores', arvore.toMap());
    }
    await batch.commit();
  }

  Future<List<Arvore>> getArvoresByParcela(int parcelaId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'arvores',
      where: 'parcela_id = ?',
      whereArgs: [parcelaId],
      orderBy: 'numero_arvore',
    );
    return List.generate(maps.length, (i) => Arvore.fromMap(maps[i]));
  }

  Future<Arvore?> getArvore(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'arvores',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) {
      return Arvore.fromMap(maps.first);
    }
    return null;
  }

  Future<int> updateArvore(Arvore arvore) async {
    final db = await database;
    return await db.update(
      'arvores',
      arvore.toMap(),
      where: 'id = ?',
      whereArgs: [arvore.id],
    );
  }

  Future<int> deleteArvore(int id) async {
    final db = await database;
    return await db.delete(
      'arvores',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteArvoresByParcela(int parcelaId) async {
    final db = await database;
    await db.delete(
      'arvores',
      where: 'parcela_id = ?',
      whereArgs: [parcelaId],
    );
  }

  Future<int> getArvoresCountByParcela(int parcelaId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) FROM arvores WHERE parcela_id = ?',
      [parcelaId],
    );
    return result.first.values.first as int;
  }

  // ========== MÉTODOS DE ESTATÍSTICAS E RELATÓRIOS ==========

  Future<Map<String, dynamic>> getEstatisticasInventario(int inventarioId) async {
    final db = await database;

    final totalParcelasResult = await db.rawQuery(
      'SELECT COUNT(*) FROM parcelas WHERE inventario_id = ?',
      [inventarioId],
    );
    final totalParcelas = totalParcelasResult.first.values.first as int;

    final parcelasConcluidasResult = await db.rawQuery(
      'SELECT COUNT(*) FROM parcelas WHERE inventario_id = ? AND concluida = 1',
      [inventarioId],
    );
    final parcelasConcluidas = parcelasConcluidasResult.first.values.first as int;

    final totalArvoresResult = await db.rawQuery('''
      SELECT COUNT(*) FROM arvores 
      INNER JOIN parcelas ON arvores.parcela_id = parcelas.id 
      WHERE parcelas.inventario_id = ?
    ''', [inventarioId]);
    final totalArvores = totalArvoresResult.first.values.first as int;

    final mediaArvoresPorParcela = totalParcelas > 0 ? totalArvores / totalParcelas : 0;

    return {
      'totalParcelas': totalParcelas,
      'parcelasConcluidas': parcelasConcluidas,
      'totalArvores': totalArvores,
      'mediaArvoresPorParcela': mediaArvoresPorParcela,
      'progresso': totalParcelas > 0 ? parcelasConcluidas / totalParcelas : 0,
    };
  }

  // ========== MÉTODOS DE LIMPEZA E MANUTENÇÃO ==========

  Future<void> close() async {
    final db = await database;
    await db.close();
  }

  Future<void> deleteAppDatabase() async {
    final dbPath = join(await getDatabasesPath(), 'inventario.db');
    await deleteDatabase(dbPath);
  }

  // ========== MÉTODOS DE TRANSACTION ==========

  Future<T> executeTransaction<T>(Future<T> Function(Transaction t) action) async {
    final db = await database;
    return await db.transaction<T>(action);
  }

  Future<void> executeInTransaction(Function(Transaction t) action) async {
    final db = await database;
    await db.transaction((txn) async {
      await action(txn);
    });
  }

  Future<List<String>> getFamiliasUnicas() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.rawQuery(
      'SELECT DISTINCT familia FROM arvores WHERE familia IS NOT NULL AND familia != "" ORDER BY familia',
    );
    return List.generate(maps.length, (i) => maps[i]['familia'] as String);
  }

  Future<List<String>> getNomesCientificosUnicos() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.rawQuery(
      'SELECT DISTINCT nome_cientifico FROM arvores WHERE nome_cientifico IS NOT NULL AND nome_cientifico != "" ORDER BY nome_cientifico',
    );
    return List.generate(maps.length, (i) => maps[i]['nome_cientifico'] as String);
  }

  Future<List<String>> getSugestoesFamilia(String query) async {
    final familias = await getFamiliasUnicas();
    return familias
        .where((familia) => familia.toLowerCase().contains(query.toLowerCase()))
        .toList();
  }

  Future<List<String>> getSugestoesNomeCientifico(String query) async {
    final nomes = await getNomesCientificosUnicos();
    return nomes
        .where((nome) => nome.toLowerCase().contains(query.toLowerCase()))
        .toList();
  }

  Future<void> limparDadosInventario(int inventarioId) async {
    final db = await database;

    await db.execute('''
      DELETE FROM arvores_cap_historico 
      WHERE arvore_id IN (
        SELECT arvores.id FROM arvores 
        INNER JOIN parcelas ON arvores.parcela_id = parcelas.id 
        WHERE parcelas.inventario_id = ?
      )
    ''', [inventarioId]);

    await db.execute('''
      DELETE FROM arvores 
      WHERE parcela_id IN (
        SELECT id FROM parcelas WHERE inventario_id = ?
      )
    ''', [inventarioId]);

    await db.delete('parcelas', where: 'inventario_id = ?', whereArgs: [inventarioId]);
  }

  Future<int> getAnoInventario(int inventarioId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'inventarios',
      columns: ['ano'],
      where: 'id = ?',
      whereArgs: [inventarioId],
    );

    if (maps.isNotEmpty) {
      return maps.first['ano'] as int;
    }
    return DateTime.now().year;
  }

  Future<bool> tableExists(String tableName) async {
    final db = await database;
    try {
      await db.rawQuery('SELECT 1 FROM $tableName LIMIT 1');
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> recreateDatabase() async {
    final dbPath = join(await getDatabasesPath(), 'inventario.db');
    await deleteDatabase(dbPath);
    _database = null;
    await database;
    print('✅ Banco de dados recriado com todas as tabelas');
  }

  // Método para verificar se a tabela arvores existe
  Future<void> ensureArvoresTableExists() async {
    final exists = await tableExists('arvores');
    if (!exists) {
      final db = await database;
      await _createArvoresTable(db);
      await _createIndexes(db);
    }
  }

  // Método para criar a tabela de histórico de CAPs se não existir
  Future<void> ensureCapHistoricoTableExists() async {
    final exists = await tableExists('arvores_cap_historico');
    if (!exists) {
      final db = await database;
      await _createCapHistoricoTable(db);
      await _createCapHistoricoIndexes(db);
    }
  }

  Future<int> getFamiliaId(String nome) async {
    final db = await database;
    final result = await db.query(
      'familias',
      where: 'nome = ?',
      whereArgs: [nome],
    );
    if (result.isNotEmpty) {
      return result.first['id'] as int;
    }
    return -1;
  }
}