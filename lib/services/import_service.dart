// services/import_service.dart
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
      final conteudo = await arquivo.readAsString();
      _adicionarLog('Arquivo lido com sucesso (${conteudo.length} caracteres)');

      final linhas = const CsvToListConverter(fieldDelimiter: ';').convert(conteudo);
      _adicionarLog('${linhas.length} linhas detectadas no CSV');

      if (linhas.length <= 1) {
        throw Exception('Arquivo CSV vazio ou com apenas cabeçalho');
      }

      final cabecalho = linhas[0];
      final colunasCap = _detectarColunasCap(cabecalho);

      if (colunasCap.isEmpty) {
        throw Exception(
            'Nenhuma coluna CAP_XXXX detectada no arquivo. Formato esperado: CAP_2011, CAP_2012, etc.');
      }

      _adicionarLog(
          'Colunas CAP detectadas: ${colunasCap.entries.map((e) => 'CAP_${e.key} (índice ${e.value})').join(', ')}');

      final resultado = await _processarLinhas(linhas, config, colunasCap);

      _adicionarLog(
          'Processamento concluído: $totalLinhasProcessadas linhas processadas, $totalLinhasComErro erros');

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

      if (nomeColuna.startsWith('CAP_')) {
        final anoStr = nomeColuna.substring(4);
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
    // OPT #2: cache de parcelas em memória — elimina SELECT repetido por linha
    final Map<String, int> cacheParcelaIds = {};
    // OPT #4: cache de árvores pré-carregadas — elimina SELECT por linha dentro da transação
    final Map<String, int> cacheArvoreIds = {};

    // OPT #4: pré-carregar todas as árvores do inventário de uma só vez
    final arvoresExistentes = await db.rawQuery('''
      SELECT a.id, a.parcela_id, a.numero_arvore, a.codigo, a.numero_fuste
      FROM arvores a
      INNER JOIN parcelas p ON p.id = a.parcela_id
      WHERE p.inventario_id = ?
    ''', [config.inventarioId]);

    for (final a in arvoresExistentes) {
      final chave =
          '${a['parcela_id']}-${a['numero_arvore']}-${a['codigo']}-${a['numero_fuste']}';
      cacheArvoreIds[chave] = a['id'] as int;
    }

    _adicionarLog('Cache inicial: ${cacheArvoreIds.length} árvores pré-carregadas');

    // Contadores de avisos agrupados (OPT #5)
    int avisosCapInvalido = 0;

    // Controle de progresso — imprime a cada 5%
    final totalLinhas = linhas.length - 1; // desconta cabeçalho
    int ultimoPercentualImpresso = -1;

    void _imprimirProgresso(int linhaAtual) {
      if (totalLinhas == 0) return;
      final percentual = ((linhaAtual / totalLinhas) * 100).floor();
      final marcador = (percentual ~/ 5) * 5; // arredonda para múltiplo de 5
      if (marcador > ultimoPercentualImpresso && marcador <= 100) {
        ultimoPercentualImpresso = marcador;
        final msg = '[PROGRESSO] $marcador% — '
            '$linhaAtual/$totalLinhas linhas | '
            'erros: $totalLinhasComErro';
        print(msg);
        _adicionarLog(msg);
      }
    }

    // OPT #1: toda a escrita dentro de uma única transação
    await db.transaction((txn) async {
      // OPT #3: batch único para todos os CAPs do processamento
      final batchCap = txn.batch();

      for (int i = 1; i < linhas.length; i++) {
        try {
          final linha = linhas[i];
          totalLinhasProcessadas++;

          if (linha.length < 11) {
            final msgErro = 'ERRO Linha ${i + 1}: '
                'Número insuficiente de colunas (${linha.length})';
            print(msgErro);
            _adicionarLog(msgErro);
            totalLinhasComErro++;
            _imprimirProgresso(i);
            continue;
          }

          final dadosExtracao = _extrairDadosLinha(
            linha, i + 1, colunasCap,
            onCapInvalido: () => avisosCapInvalido++, // OPT #5
          );

          if (dadosExtracao == null) {
            print('ERRO Linha ${i + 1}: dados inválidos — verifique CAPs e colunas obrigatórias');
            totalLinhasComErro++;
            _imprimirProgresso(i);
            continue;
          }

          // OPT #2: obter parcela via cache (sem query ao banco se já vista)
          final parcelaId = await _obterOuCriarParcelaComCache(
            txn, dadosExtracao, config.inventarioId, cacheParcelaIds,
          );

          final chaveArvore =
              '$parcelaId-${dadosExtracao['arvore']}-${dadosExtracao['codigo']}-${dadosExtracao['fuste']}';

          int arvoreId;

          if (cacheArvoreIds.containsKey(chaveArvore)) {
            // Árvore já existe — apenas atualizar
            arvoreId = cacheArvoreIds[chaveArvore]!;
            await txn.update(
              'arvores',
              _mapArvore(dadosExtracao),
              where: 'id = ?',
              whereArgs: [arvoreId],
            );
            arvoresAtualizadas++;
          } else {
            // Nova árvore — inserir e registrar no cache
            arvoreId = await txn.insert(
              'arvores',
              {
                'parcela_id': parcelaId,
                'numero_arvore': dadosExtracao['arvore'],
                ..._mapArvore(dadosExtracao),
              },
            );
            cacheArvoreIds[chaveArvore] = arvoreId;
            novasArvores++;
          }

          // OPT #3: acumular inserts de CAP no batch (commit único ao final)
          final capsPorAno = dadosExtracao['caps_por_ano'] as Map<int, double>;
          for (final entry in capsPorAno.entries) {
            batchCap.rawInsert('''
              INSERT OR REPLACE INTO arvores_cap_historico (arvore_id, ano, cap)
              VALUES (?, ?, ?)
            ''', [arvoreId, entry.key, entry.value]);
          }

          // Contagem de parcelas únicas via cache
          final chaveParcela =
              '${dadosExtracao['bloco']}-${dadosExtracao['parcela']}-${dadosExtracao['faixa']}';
          if (!cacheParcelaIds.containsKey(
              '${config.inventarioId}-$chaveParcela')) {
            parcelasAfetadas++;
          }

          _imprimirProgresso(i);
        } catch (e) {
          final msgErro = 'ERRO Linha ${i + 1}: $e';
          print(msgErro);
          _adicionarLog(msgErro);
          totalLinhasComErro++;
          _imprimirProgresso(i);
        }
      }

      // OPT #3: commit de todos os CAPs em um único round-trip
      await batchCap.commit(noResult: true);

      // Garante impressão de 100% ao final
      _imprimirProgresso(totalLinhas);
    });

    // OPT #5: log agrupado de avisos de CAP inválido
    if (avisosCapInvalido > 0) {
      _adicionarLog('AVISO: $avisosCapInvalido valores de CAP inválidos ignorados');
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

  /// Monta o mapa de colunas comuns a insert e update,
  /// evitando duplicação entre os dois blocos.
  Map<String, dynamic> _mapArvore(Map<String, dynamic> d) => {
    'numero_fuste': d['fuste'],
    'codigo': d['codigo'],
    'x': d['x'],
    'y': d['y'],
    'familia': d['familia'],
    'nome_cientifico': d['nome_cientifico'],
    'nome_popular': d['nome_popular'],
    'cap': d['cap'],
    'hc': d['hc'],
    'anoHC': d['anoHC'],
    'ht': d['ht'],
    'anoHT': d['anoHT'],
    'formaFuste': d['formaFuste'],
    'posiSoc': d['posiSoc'],
    'fitossanidade': d['fitossanidade'],
    'posiCopa': d['posiCopa'],
    'formaCopa': d['formaCopa'],
    'dataIngresso': d['anoIngresso'],
    'infoMorte': d['infoMorta'],
    'dataMorte': d['anoMorta'],
    'observation': d['observacoes'],
  };

  Map<String, dynamic>? _extrairDadosLinha(
      List<dynamic> linha,
      int numeroLinha,
      Map<int, int> colunasCap, {
        required VoidCallback onCapInvalido, // OPT #5
      }) {
    try {
      final bloco = int.tryParse(linha[0].toString()) ?? 1;
      final parcela = int.tryParse(linha[1].toString()) ?? 1;
      final faixa = int.tryParse(linha[2].toString()) ?? 1;
      final arvore = int.tryParse(linha[3].toString()) ?? 1;
      final fuste = int.tryParse(linha[4].toString()) ?? 1;
      final codigo = linha[5].toString().trim();
      final x = double.tryParse(linha[6].toString()) ?? 0.0;
      final y = double.tryParse(linha[7].toString()) ?? 0.0;
      final familia = linha[8].toString().trim();
      final nomeCientifico = linha[9].toString().trim();
      final nomePopular = linha[10].toString().trim();

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
            onCapInvalido(); // OPT #5: incrementa contador em vez de logar por linha
          }
        }
      }

      final hc = double.tryParse(linha[linha.length - 13].toString());
      final anoHC = int.tryParse(linha[linha.length - 12].toString());
      final ht = double.tryParse(linha[linha.length - 11].toString());
      final anoHT = int.tryParse(linha[linha.length - 10].toString());
      final formaFuste = int.tryParse(linha[linha.length - 9].toString()) ?? 0;
      final posiSoc = int.tryParse(linha[linha.length - 8].toString()) ?? 0;
      final fitossanidade = int.tryParse(linha[linha.length - 7].toString()) ?? 0;
      final posiCopa = int.tryParse(linha[linha.length - 6].toString()) ?? 0;
      final formaCopa = int.tryParse(linha[linha.length - 5].toString()) ?? 0;
      final anoIngresso = int.tryParse(linha[linha.length - 4].toString());
      final infoMorta = int.tryParse(linha[linha.length - 3].toString());
      final anoMorta = int.tryParse(linha[linha.length - 2].toString());
      final observacoes = linha[linha.length - 1].toString().trim();

      if (capsPorAno.isEmpty) {
        _adicionarLog('ERRO Linha $numeroLinha: Nenhum CAP válido encontrado');
        return null;
      }

      final anoMaisRecente = capsPorAno.keys.reduce((a, b) => a > b ? a : b);
      final cap = capsPorAno[anoMaisRecente]!;

      return {
        'bloco': bloco,
        'parcela': parcela,
        'faixa': faixa,
        'arvore': arvore,
        'fuste': fuste,
        'codigo': codigo,
        'x': x,
        'y': y,
        'familia': familia,
        'nome_cientifico': nomeCientifico,
        'nome_popular': nomePopular,
        'caps_por_ano': capsPorAno,
        'cap': cap,
        'hc': hc,
        'anoHC': anoHC,
        'ht': ht,
        'anoHT': anoHT,
        'formaFuste': formaFuste,
        'posiSoc': posiSoc,
        'fitossanidade': fitossanidade,
        'posiCopa': posiCopa,
        'formaCopa': formaCopa,
        'anoIngresso': anoIngresso,
        'infoMorta': infoMorta,
        'anoMorta': anoMorta,
        'observacoes': observacoes,
      };
    } catch (e) {
      _adicionarLog('ERRO Linha $numeroLinha: Erro ao extrair dados - $e');
      return null;
    }
  }

  /// OPT #2: versão com cache para evitar SELECT repetido de parcelas já vistas.
  Future<int> _obterOuCriarParcelaComCache(
      DatabaseExecutor db,
      Map<String, dynamic> dados,
      int inventarioId,
      Map<String, int> cache,
      ) async {
    final chave =
        '$inventarioId-${dados['bloco']}-${dados['parcela']}-${dados['faixa']}';

    if (cache.containsKey(chave)) return cache[chave]!;

    final parcelaExistente = await db.rawQuery('''
      SELECT id FROM parcelas
      WHERE inventario_id = ? AND bloco = ? AND parcela = ? AND faixa = ?
    ''', [inventarioId, dados['bloco'], dados['parcela'], dados['faixa']]);

    final int id;
    if (parcelaExistente.isNotEmpty) {
      id = parcelaExistente.first['id'] as int;
    } else {
      id = await db.insert('parcelas', {
        'inventario_id': inventarioId,
        'bloco': dados['bloco'],
        'parcela': dados['parcela'],
        'faixa': dados['faixa'],
        'concluida': 0,
      });
    }

    cache[chave] = id;
    return id;
  }
}

// Alias para facilitar uso do callback sem importar flutter/foundation
typedef VoidCallback = void Function();