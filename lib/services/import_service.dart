// services/import_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:sqflite/sqflite.dart';
import '../models/importacao_config.dart';
import '../database/database_helper.dart';

class ImportService {
  List<String> logs = [];
  int totalLinhasProcessadas = 0;
  int totalLinhasComErro = 0;

  void _adicionarLog(String mensagem) {
    logs.add('${DateTime.now().toString().split(' ')[1]} - $mensagem');
  }

  void _limparLogs() {
    logs.clear();
    totalLinhasProcessadas = 0;
    totalLinhasComErro = 0;
  }

  Future<Map<String, dynamic>> processarArquivo(
      File arquivo, ImportacaoConfig config) async {
    _limparLogs();

    _adicionarLog('Iniciando processamento do arquivo: ${arquivo.path}');
    _adicionarLog('Inventário: ${config.nomeInventario} (ID: ${config.inventarioId})');
    _adicionarLog('Ano de referência: ${config.ano}');

    try {
      // Ler o conteúdo do arquivo
      final conteudo = await arquivo.readAsString();
      _adicionarLog('Arquivo lido com sucesso (${conteudo.length} caracteres)');

      // Converter CSV para lista
      final linhas = const CsvToListConverter().convert(conteudo);
      _adicionarLog('${linhas.length} linhas detectadas no CSV');

      if (linhas.length <= 1) {
        throw Exception('Arquivo CSV vazio ou com apenas cabeçalho');
      }

      // Processar dados
      final resultado = await _processarLinhas(linhas, config);

      _adicionarLog('Processamento concluído: $totalLinhasProcessadas linhas processadas, $totalLinhasComErro erros');

      return {
        'sucesso': true,
        'resumo': resultado,
      };
    } catch (e) {
      _adicionarLog('ERRO durante o processamento: $e');
      return {
        'sucesso': false,
        'erro': e.toString(),
      };
    }
  }

  Future<Map<String, dynamic>> _processarLinhas(
      List<List<dynamic>> linhas, ImportacaoConfig config) async {

    final dbHelper = DatabaseHelper();
    final db = await dbHelper.database;

    int novasArvores = 0;
    int arvoresAtualizadas = 0;
    int parcelasAfetadas = 0;
    Set<String> parcelasProcessadas = {};

    // Pular cabeçalho e processar linhas
    for (int i = 1; i < linhas.length; i++) {
      try {
        final linha = linhas[i];
        totalLinhasProcessadas++;

        // Validar linha básica
        if (linha.length < 11) {
          _adicionarLog('ERRO Linha ${i + 1}: Número insuficiente de colunas (${linha.length})');
          totalLinhasComErro++;
          continue;
        }

        // Extrair dados da linha
        final dados = _extrairDadosLinha(linha, i + 1);
        if (dados == null) {
          totalLinhasComErro++;
          continue;
        }

        // Processar no banco de dados
        final resultado = await _processarArvoreNoBanco(db, dados, config);

        if (resultado['novo']) {
          novasArvores++;
        } else {
          arvoresAtualizadas++;
        }

        // Registrar parcela processada
        final chaveParcela = '${dados['bloco']}-${dados['faixa']}-${dados['parcela']}';
        if (!parcelasProcessadas.contains(chaveParcela)) {
          parcelasProcessadas.add(chaveParcela);
          parcelasAfetadas++;
        }

        if (i % 50 == 0) {
          _adicionarLog('Processadas $i linhas...');
        }

      } catch (e) {
        _adicionarLog('ERRO Linha ${i + 1}: $e');
        totalLinhasComErro++;
      }
    }

    return {
      'total_arvores': (novasArvores + arvoresAtualizadas),
      'novas_arvores': novasArvores,
      'arvores_atualizadas': arvoresAtualizadas,
      'parcelas_afetadas': parcelasAfetadas,
      'linhas_com_erro': totalLinhasComErro,
    };
  }

  Map<String, dynamic>? _extrairDadosLinha(List<dynamic> linha, int numeroLinha) {
    try {
      // Converter CAP para DAP (CAP = π * DAP, então DAP = CAP / π)
      final cap = double.tryParse(linha[9].toString());
      if (cap == null || cap <= 0) {
        _adicionarLog('ERRO Linha $numeroLinha: CAP inválido (${linha[9]})');
        return null;
      }

      final dap = cap / 3.14159;

      return {
        'bloco': int.tryParse(linha[0].toString()) ?? 1,
        'parcela': int.tryParse(linha[1].toString()) ?? 1,
        'faixa': int.tryParse(linha[2].toString()) ?? 1,
        'arvore': int.tryParse(linha[3].toString()) ?? 1,
        'codigo': linha[4].toString().trim(),
        'x': double.tryParse(linha[5].toString()) ?? 0.0,
        'y': double.tryParse(linha[6].toString()) ?? 0.0,
        'familia': linha[7].toString().trim(),
        'nome_cientifico': linha[8].toString().trim(),
        'dap': dap,
        'ht': double.tryParse(linha[10].toString()) ?? 0.0,
        'hc': linha.length > 11 ? double.tryParse(linha[11].toString()) ?? 0.0 : 0.0,
      };
    } catch (e) {
      _adicionarLog('ERRO Linha $numeroLinha: Erro ao extrair dados - $e');
      return null;
    }
  }

  Future<Map<String, dynamic>> _processarArvoreNoBanco(
      Database db, Map<String, dynamic> dados, ImportacaoConfig config) async {

    // Buscar ou criar parcela
    final parcelaId = await _obterOuCriarParcela(db, dados, config.inventarioId);

    // Verificar se árvore já existe
    final arvoreExistente = await db.rawQuery('''
      SELECT id FROM arvores 
      WHERE parcela_id = ? AND numero_arvore = ?
    ''', [parcelaId, dados['arvore']]);

    if (arvoreExistente.isNotEmpty) {
      // Atualizar árvore existente
      await db.update('arvores', {
        'codigo': dados['codigo'],
        'x': dados['x'],
        'y': dados['y'],
        'familia': dados['familia'],
        'nome_cientifico': dados['nome_cientifico'],
        'dap': dados['dap'],
        'ht': dados['ht'],
      }, where: 'id = ?', whereArgs: [arvoreExistente.first['id']]);

      return {'novo': false};
    } else {
      // Inserir nova árvore
      await db.insert('arvores', {
        'parcela_id': parcelaId,
        'numero_arvore': dados['arvore'],
        'codigo': dados['codigo'],
        'x': dados['x'],
        'y': dados['y'],
        'familia': dados['familia'],
        'nome_cientifico': dados['nome_cientifico'],
        'dap': dados['dap'],
        'ht': dados['ht'],
      });

      return {'novo': true};
    }
  }

  Future<int> _obterOuCriarParcela(
      Database db, Map<String, dynamic> dados, int inventarioId) async {

    // Buscar parcela existente
    final parcelaExistente = await db.rawQuery('''
      SELECT id FROM parcelas 
      WHERE inventario_id = ? AND bloco = ? AND faixa = ? AND parcela = ?
    ''', [inventarioId, dados['bloco'], dados['faixa'], dados['parcela']]);

    if (parcelaExistente.isNotEmpty) {
      return parcelaExistente.first['id'] as int;
    }

    // Criar nova parcela
    final novaParcelaId = await db.insert('parcelas', {
      'inventario_id': inventarioId,
      'bloco': dados['bloco'],
      'faixa': dados['faixa'],
      'parcela': dados['parcela'],
      'concluida': 0,
    });

    return novaParcelaId;
  }
}