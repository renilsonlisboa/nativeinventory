// services/reflora_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../database/database_helper.dart';
import 'package:sqflite/sqflite.dart';

class RefloraFamiliasService {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  // URL do arquivo CSV no GitHub
  static const String _csvUrl =
      'https://raw.githubusercontent.com/renilsonlisboa/reflora_data/main/resultados_flora.csv';

  final Map<String, String> _headers = {
    'Content-Type': 'text/csv',
    'Accept': 'text/csv',
    'User-Agent': 'InventarioFlorestal/1.0',
  };

  /// Importa dados completos (famílias e espécies) de forma otimizada
  Future<Map<String, dynamic>> importarDadosCompletos() async {
    try {
      print('🌿 Baixando CSV do GitHub...');
      final response = await http.get(
        Uri.parse(_csvUrl),
        headers: _headers,
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        return {
          'sucesso': false,
          'erro': 'Erro ao baixar CSV: HTTP ${response.statusCode}',
        };
      }

      final csvContent = utf8.decode(response.bodyBytes);
      final linhas = LineSplitter.split(csvContent).toList();
      if (linhas.isEmpty) {
        return {'sucesso': false, 'erro': 'Arquivo CSV vazio'};
      }

      print('📊 Total de linhas: ${linhas.length}');

      // Parse simples do cabeçalho (split por vírgula)
      List<String> cabecalho = linhas.first.split(',');
      int idxNomeCientifico = _findIndex(cabecalho, ['Nome_Cientifico', 'cientifico']);
      int idxFamilia = _findIndex(cabecalho, ['Familia', 'familia']);
      int idxStatus = _findIndex(cabecalho, ['Status', 'status']);

      if (idxFamilia == -1 || idxNomeCientifico == -1) {
        return {
          'sucesso': false,
          'erro': 'Colunas necessárias não encontradas. Colunas: $cabecalho',
        };
      }

      // Coletores
      final Set<String> familiasSet = {};
      final List<Map<String, String>> especies = [];

      // Processa linhas de dados (ignora cabeçalho)
      for (int i = 1; i < linhas.length; i++) {
        final linha = linhas[i].trim();
        if (linha.isEmpty) continue;

        final colunas = linha.split(',');
        if (colunas.length <= idxFamilia || colunas.length <= idxNomeCientifico) continue;

        String familia = _limparCampo(colunas[idxFamilia]);
        String nomeCientifico = _limparCampo(colunas[idxNomeCientifico]);
        String status = idxStatus != -1 && idxStatus < colunas.length
            ? _limparCampo(colunas[idxStatus])
            : '';

        if (familia.isNotEmpty && nomeCientifico.isNotEmpty) {
          familiasSet.add(familia);
          especies.add({
            'familia': familia,
            'nome_cientifico': nomeCientifico,
            'status': status,
          });
        }
      }

      print('📊 Famílias únicas: ${familiasSet.length}');
      print('📊 Espécies: ${especies.length}');

      // Limpa dados antigos (fora da transação para não travar)
      await _dbHelper.clearTaxonomia();

      // Obtém referência do banco
      final db = await _dbHelper.database;

      // ---- Transação principal ----
      return await db.transaction((txn) async {
        // 1. Inserir famílias em batch
        final familiaBatch = txn.batch();
        for (final familia in familiasSet) {
          familiaBatch.insert('familias', {'nome': familia},
              conflictAlgorithm: ConflictAlgorithm.ignore);
        }
        await familiaBatch.commit(noResult: true);

        // 2. Obter mapa de família -> id (todas as famílias)
        final List<Map<String, dynamic>> familiasMap =
        await txn.query('familias', columns: ['id', 'nome']);
        final Map<String, int> familiaIdMap = {
          for (var row in familiasMap) row['nome'] as String: row['id'] as int
        };

        // 3. Inserir espécies em batch
        final especiesBatch = txn.batch();
        int especiesInseridas = 0;
        for (final esp in especies) {
          final familiaId = familiaIdMap[esp['familia']];
          if (familiaId != null) {
            especiesBatch.insert('especies', {
              'familia_id': familiaId,
              'nome_cientifico': esp['nome_cientifico']!,
            }, conflictAlgorithm: ConflictAlgorithm.ignore);
            especiesInseridas++;
          }
        }
        await especiesBatch.commit(noResult: true);

        print('✅ Importação concluída: ${familiasSet.length} famílias, $especiesInseridas espécies');
        return {
          'sucesso': true,
          'familias': familiasSet.length,
          'especies': especiesInseridas,
          'mensagem':
          '${familiasSet.length} famílias e $especiesInseridas espécies importadas com sucesso!',
        };
      });
    } catch (e) {
      print('❌ Erro na importação: $e');
      return {'sucesso': false, 'erro': 'Erro ao importar dados: $e'};
    }
  }

  /// Retorna o índice da primeira coluna que corresponde a alguma das chaves fornecidas
  int _findIndex(List<String> cabecalho, List<String> chaves) {
    for (int i = 0; i < cabecalho.length; i++) {
      String col = cabecalho[i].toLowerCase().trim();
      if (chaves.any((key) => col.contains(key.toLowerCase()))) {
        return i;
      }
    }
    return -1;
  }

  /// Remove aspas e espaços extras de um campo CSV
  String _limparCampo(String campo) {
    return campo.trim().replaceAll('"', '').replaceAll("'", "");
  }

  /// Verifica se o arquivo CSV está acessível (conexão com GitHub)
  Future<bool> verificarConexao() async {
    try {
      final response = await http.head(
        Uri.parse(_csvUrl),
        headers: _headers,
      ).timeout(const Duration(seconds: 10));
      return response.statusCode == 200;
    } catch (e) {
      print('❌ GitHub indisponível: $e');
      return false;
    }
  }

  /// Retorna estatísticas atuais do banco local
  Future<Map<String, int>> getEstatisticas() async {
    try {
      final familias = await _dbHelper.getCountFamilias();
      final especies = await _dbHelper.getCountEspecies();
      return {'familias': familias, 'especies': especies};
    } catch (e) {
      print('Erro ao obter estatísticas: $e');
      return {'familias': 0, 'especies': 0};
    }
  }

  // Métodos de busca (mantidos para compatibilidade)
  Future<List<String>> buscarFamilias(String termo) async {
    return await _dbHelper.getFamilias(filtro: termo);
  }

  Future<List<Map<String, dynamic>>> buscarEspeciesPorFamilia(String familia) async {

    return [];
  }
}