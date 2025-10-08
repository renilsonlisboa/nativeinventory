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
    _adicionarLog('Modo: Detecção automática de colunas CAP');

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

      // Detectar colunas CAP automaticamente
      final cabecalho = linhas[0];
      final colunasCap = _detectarColunasCap(cabecalho);

      if (colunasCap.isEmpty) {
        throw Exception('Nenhuma coluna CAP_XXXX detectada no arquivo. Formato esperado: CAP_2011, CAP_2012, etc.');
      }

      _adicionarLog('Colunas CAP detectadas: ${colunasCap.entries.map((e) => 'CAP_${e.key} (índice ${e.value})').join(', ')}');

      // Processar dados
      final resultado = await _processarLinhas(linhas, config, colunasCap);

      _adicionarLog('Processamento concluído: $totalLinhasProcessadas linhas processadas, $totalLinhasComErro erros');

      return {
        'sucesso': true,
        'resumo': resultado,
        'anos_detectados': colunasCap.keys.toList(),
      };
    } catch (e) {
      _adicionarLog('ERRO durante o processamento: $e');
      return {
        'sucesso': false,
        'erro': e.toString(),
      };
    }
  }

  Map<int, int> _detectarColunasCap(List<dynamic> cabecalho) {
    final colunasCap = <int, int>{}; // ano -> índice da coluna

    for (int i = 0; i < cabecalho.length; i++) {
      final nomeColuna = cabecalho[i].toString().toUpperCase().trim();

      // Verificar se é uma coluna CAP (CAP_2011, CAP_2012, etc.)
      if (nomeColuna.startsWith('CAP_')) {
        final anoStr = nomeColuna.substring(4); // Remove "CAP_"
        final ano = int.tryParse(anoStr);

        if (ano != null && ano > 1900 && ano < 2100) {
          colunasCap[ano] = i;
          _adicionarLog('Detectada coluna: $nomeColuna no índice $i (ano: $ano)');
        }
      }
    }

    return colunasCap;
  }

  Future<Map<String, dynamic>> _processarLinhas(
      List<List<dynamic>> linhas,
      ImportacaoConfig config,
      Map<int, int> colunasCap) async {

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

        // Validar linha básica - agora precisamos de pelo menos 9 colunas (até nome_cientifico)
        if (linha.length < 9) {
          _adicionarLog('ERRO Linha ${i + 1}: Número insuficiente de colunas (${linha.length})');
          totalLinhasComErro++;
          continue;
        }

        // Extrair dados da linha com múltiplos CAPs
        final dados = _extrairDadosLinha(linha, i + 1, colunasCap);
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
        final chaveParcela = '${dados['bloco']}-${dados['parcela']}-${dados['faixa']}';
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
      'anos_detectados': colunasCap.keys.toList(),
    };
  }

  Map<String, dynamic>? _extrairDadosLinha(
      List<dynamic> linha,
      int numeroLinha,
      Map<int, int> colunasCap) {

    try {
      // Extrair dados básicos
      final bloco = int.tryParse(linha[0].toString()) ?? 1;
      final parcela = int.tryParse(linha[1].toString()) ?? 1;
      final faixa = int.tryParse(linha[2].toString()) ?? 1;
      final arvore = int.tryParse(linha[3].toString()) ?? 1;
      final codigo = linha[4].toString().trim();
      final x = double.tryParse(linha[5].toString()) ?? 0.0;
      final y = double.tryParse(linha[6].toString()) ?? 0.0;
      final familia = linha[7].toString().trim();
      final nomeCientifico = linha[8].toString().trim();

      // Extrair HT e HC (podem estar em colunas fixas ou variáveis)
      double ht = 0.0;
      double hc = 0.0;

      // Tentar encontrar HT e HC - podem estar após as colunas CAP
      // Procura pelas colunas HT e HC no cabeçalho seria ideal, mas por simplicidade
      // vamos assumir posições fixas ou procurar pelos nomes
      if (linha.length > 9) {
        ht = double.tryParse(linha[9].toString()) ?? 0.0;
      }
      if (linha.length > 10) {
        hc = double.tryParse(linha[10].toString()) ?? 0.0;
      }

      // Extrair todos os CAPs detectados
      final capsPorAno = <int, double>{};
      for (final entry in colunasCap.entries) {
        final ano = entry.key;
        final indiceColuna = entry.value;

        if (indiceColuna < linha.length) {
          final capValue = linha[indiceColuna];
          final cap = double.tryParse(capValue.toString());

          if (cap != null && cap > 0) {
            capsPorAno[ano] = cap;
          } else {
            _adicionarLog('AVISO Linha $numeroLinha: CAP inválido para ano $ano (valor: $capValue)');
          }
        }
      }

      if (capsPorAno.isEmpty) {
        _adicionarLog('ERRO Linha $numeroLinha: Nenhum CAP válido encontrado');
        return null;
      }

      // Usar o CAP mais recente (maior ano) para calcular DAP da árvore atual
      final anoMaisRecente = capsPorAno.keys.reduce((a, b) => a > b ? a : b);
      final capMaisRecente = capsPorAno[anoMaisRecente]!;
      final cap = capMaisRecente;

      return {
        'bloco': bloco,
        'parcela': parcela,
        'faixa': faixa,
        'arvore': arvore,
        'codigo': codigo,
        'x': x,
        'y': y,
        'familia': familia,
        'nome_cientifico': nomeCientifico,
        'caps_por_ano': capsPorAno, // Mapa com todos os CAPs por ano
        'cap': cap, // DAP calculado do CAP mais recente
        'ht': ht,
        'hc': hc,
        'ano_mais_recente': anoMaisRecente,
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
    WHERE parcela_id = ? AND numero_arvore = ? AND codigo NOT IN (1, 2)
  ''', [parcelaId, dados['arvore']]);

    int arvoreId;
    bool novaArvore = false;

    if (arvoreExistente.isNotEmpty) {
      arvoreId = arvoreExistente.first['id'] as int;

      // Atualizar dados da árvore existente
      await db.update('arvores', {
        'codigo': dados['codigo'],
        'x': dados['x'],
        'y': dados['y'],
        'familia': dados['familia'],
        'nome_cientifico': dados['nome_cientifico'],
        'cap': dados['cap'], // DAP do ano mais recente
        'ht': dados['ht'],
      }, where: 'id = ?', whereArgs: [arvoreId]);
    } else {
      // Inserir nova árvore
      arvoreId = await db.insert('arvores', {
        'parcela_id': parcelaId,
        'numero_arvore': dados['arvore'],
        'codigo': dados['codigo'],
        'x': dados['x'],
        'y': dados['y'],
        'familia': dados['familia'],
        'nome_cientifico': dados['nome_cientifico'],
        'cap': dados['cap'], // DAP do ano mais recente
        'ht': dados['ht'],
      });
      novaArvore = true;
    }

    // Salvar todos os CAPs no histórico
    final capsPorAno = dados['caps_por_ano'] as Map<int, double>;
    for (final entry in capsPorAno.entries) {
      final ano = entry.key;
      final cap = entry.value;

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

    return {'novo': novaArvore};
  }

  Future<int> _obterOuCriarParcela(
      Database db, Map<String, dynamic> dados, int inventarioId) async {

    // Buscar parcela existente
    final parcelaExistente = await db.rawQuery('''
      SELECT id FROM parcelas 
      WHERE inventario_id = ? AND bloco = ? AND faixa = ? AND parcela = ?
    ''', [inventarioId, dados['bloco'], dados['parcela'], dados['faixa']]);

    if (parcelaExistente.isNotEmpty) {
      return parcelaExistente.first['id'] as int;
    }

    // Criar nova parcela
    final novaParcelaId = await db.insert('parcelas', {
      'inventario_id': inventarioId,
      'bloco': dados['bloco'],
      'parcela': dados['parcela'],
      'faixa': dados['faixa'],
      'concluida': 0,
    });

    return novaParcelaId;
  }
}