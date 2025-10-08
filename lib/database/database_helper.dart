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

  // Aumente a versão para 6 para incluir o campo ano
  static const int _databaseVersion = 7;

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
    // Migração para versão 2: tabela de árvores
    if (oldVersion < 2) {
      await _createArvoresTable(db);
      await _createIndexes(db);
    }

    // Migração para versão 3: índices (se necessário)
    if (oldVersion < 3) {
      await _createIndexes(db);
    }

    // Migração para versão 4: coluna dap_minimo
    if (oldVersion < 4) {
      await db.execute('ALTER TABLE inventarios ADD COLUMN dap_minimo REAL NOT NULL DEFAULT 10.0');
    }

    // Migração para versão 5: tabela de histórico de CAPs
    if (oldVersion < 5) {
      await _createCapHistoricoTable(db);
      await _createCapHistoricoIndexes(db);
    }

    // Migração para versão 6: adicionar campo ano na tabela inventarios
    if (oldVersion < 6) {
      await db.execute('ALTER TABLE inventarios ADD COLUMN ano INTEGER NOT NULL DEFAULT 2025');
    }

    if (oldVersion < 7) {
      await db.execute("ALTER TABLE arvores ADD COLUMN cap REAL NOT NULL DEFAULT 0");
      await db.execute("ALTER TABLE arvores ADD COLUMN hc REAL NOT NULL DEFAULT 0");
      // se quiser remover dap, só criando a tabela do zero (SQLite não remove colunas fácil)
    }

  }

  Future<void> _createTables(Database db) async {
    // Tabela de inventários (COM ano)
    await db.execute('''
      CREATE TABLE inventarios(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nome TEXT NOT NULL,
        area_inventariada NOT NULL,
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

    // Índices para melhor performance
    await _createIndexes(db);
    await _createCapHistoricoIndexes(db);
  }

  Future<void> _createArvoresTable(Database db) async {
    await db.execute('''
    CREATE TABLE arvores(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      parcela_id INTEGER NOT NULL,
      numero_arvore INTEGER NOT NULL,
      codigo TEXT NOT NULL,
      x REAL NOT NULL,
      y REAL NOT NULL,
      familia TEXT NOT NULL,
      nome_cientifico TEXT NOT NULL,
      cap REAL NOT NULL,
      hc REAL,
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

  // Método para verificar se a tabela arvores existe
  Future<bool> tableExists(String tableName) async {
    final db = await database;
    try {
      await db.rawQuery('SELECT 1 FROM $tableName LIMIT 1');
      return true;
    } catch (e) {
      return false;
    }
  }

  // Método para criar a tabela arvores se não existir
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

  // ========== MÉTODOS PARA HISTÓRICO DE CAP ==========

  Future<void> inserirOuAtualizarCapHistorico(int arvoreId, int ano, double cap) async {
    await ensureCapHistoricoTableExists();
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
    await ensureCapHistoricoTableExists();
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
    await ensureCapHistoricoTableExists();
    final db = await database;
    final result = await db.rawQuery('''
      SELECT DISTINCT ano FROM arvores_cap_historico 
      WHERE arvore_id = ? 
      ORDER BY ano DESC
    ''', [arvoreId]);

    return result.map((map) => map['ano'] as int).toList();
  }

  Future<double?> getCapPorAno(int arvoreId, int ano) async {
    await ensureCapHistoricoTableExists();
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
    await ensureCapHistoricoTableExists();
    final db = await database;
    await db.delete(
      'arvores_cap_historico',
      where: 'arvore_id = ?',
      whereArgs: [arvoreId],
    );
  }

  Future<List<int>> getTodosAnosComCaptura() async {
    await ensureCapHistoricoTableExists();
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

  // Métodos para obter valores únicos para filtros
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
    await ensureArvoresTableExists();
    final db = await database;
    return await db.insert('arvores', arvore.toMap());
  }

  Future<void> insertArvores(List<Arvore> arvores) async {
    await ensureArvoresTableExists();
    final db = await database;
    final batch = db.batch();
    for (var arvore in arvores) {
      batch.insert('arvores', arvore.toMap());
    }
    await batch.commit();
  }

  Future<List<Arvore>> getArvoresByParcela(int parcelaId) async {
    await ensureArvoresTableExists();
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
    await ensureArvoresTableExists();
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
    await ensureArvoresTableExists();
    final db = await database;
    return await db.update(
      'arvores',
      arvore.toMap(),
      where: 'id = ?',
      whereArgs: [arvore.id],
    );
  }

  Future<int> deleteArvore(int id) async {
    await ensureArvoresTableExists();
    final db = await database;
    return await db.delete(
      'arvores',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteArvoresByParcela(int parcelaId) async {
    await ensureArvoresTableExists();
    final db = await database;
    await db.delete(
      'arvores',
      where: 'parcela_id = ?',
      whereArgs: [parcelaId],
    );
  }

  Future<int> getArvoresCountByParcela(int parcelaId) async {
    await ensureArvoresTableExists();
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

    // Total de parcelas
    final totalParcelasResult = await db.rawQuery(
      'SELECT COUNT(*) FROM parcelas WHERE inventario_id = ?',
      [inventarioId],
    );
    final totalParcelas = totalParcelasResult.first.values.first as int;

    // Parcelas concluídas
    final parcelasConcluidasResult = await db.rawQuery(
      'SELECT COUNT(*) FROM parcelas WHERE inventario_id = ? AND concluida = 1',
      [inventarioId],
    );
    final parcelasConcluidas = parcelasConcluidasResult.first.values.first as int;

    // Total de árvores
    final totalArvoresResult = await db.rawQuery('''
      SELECT COUNT(*) FROM arvores 
      INNER JOIN parcelas ON arvores.parcela_id = parcelas.id 
      WHERE parcelas.inventario_id = ?
    ''', [inventarioId]);
    final totalArvores = totalArvoresResult.first.values.first as int;

    // Média de árvores por parcela
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

  // Métodos para obter valores únicos de Família e Nome Científico
  Future<List<String>> getFamiliasUnicas() async {
    await ensureArvoresTableExists();
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.rawQuery(
      'SELECT DISTINCT familia FROM arvores WHERE familia IS NOT NULL AND familia != "" ORDER BY familia',
    );
    return List.generate(maps.length, (i) => maps[i]['familia'] as String);
  }

  Future<List<String>> getNomesCientificosUnicos() async {
    await ensureArvoresTableExists();
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

    // Primeiro deletar o histórico de CAPs das árvores
    await db.execute('''
      DELETE FROM arvores_cap_historico 
      WHERE arvore_id IN (
        SELECT arvores.id FROM arvores 
        INNER JOIN parcelas ON arvores.parcela_id = parcelas.id 
        WHERE parcelas.inventario_id = ?
      )
    ''', [inventarioId]);

    // Depois deletar as árvores
    await db.execute('''
      DELETE FROM arvores 
      WHERE parcela_id IN (
        SELECT id FROM parcelas WHERE inventario_id = ?
      )
    ''', [inventarioId]);

    // Finalmente deletar as parcelas
    await db.delete('parcelas', where: 'inventario_id = ?', whereArgs: [inventarioId]);
  }

  // NOVO MÉTODO: Obter o ano do inventário
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
    return DateTime.now().year; // Retorna ano atual como fallback
  }
}