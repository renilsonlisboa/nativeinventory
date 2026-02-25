// services/reflora_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../database/database_helper.dart';

class RefloraService {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  // URLs da API REFLORA - Brazilian Flora 2020
  static const String _baseUrl = 'https://servicos.jbrj.gov.br/flora';
  static const String _apiUrl = '$_baseUrl/api';

  final Map<String, String> _headers = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    'User-Agent': 'InventarioFlorestal/1.0',
  };

  Future<Map<String, dynamic>> importarTaxonomia() async {
    try {
      print('🌿 Iniciando importação da taxonomia REFLORA...');

      int familiasInseridas = 0;
      int especiesInseridas = 0;

      // Limpa a taxonomia existente
      await _dbHelper.clearTaxonomia();

      // Busca famílias da flora brasileira
      final familias = await _buscarFamilias();
      print('📊 Famílias encontradas: ${familias.length}');

      for (final familia in familias) {
        try {
          final familiaId = await _dbHelper.insertFamilia(familia);
          if (familiaId > 0) {
            familiasInseridas++;

            // Busca espécies para esta família
            final especies = await _buscarEspeciesPorFamilia(familia);
            print('🌱 Família $familia: ${especies.length} espécies');

            for (final especie in especies) {
              try {
                final especieId = await _dbHelper.insertEspecie(
                  familiaId,
                  especie['nome_cientifico'] ?? '',
                  sinonimos: especie['sinonimos'],
                  nomePopular: especie['nome_popular'],
                );
                if (especieId > 0) {
                  especiesInseridas++;
                }
              } catch (e) {
                print('⚠️ Erro ao inserir espécie ${especie['nome_cientifico']}: $e');
              }
            }
          }
        } catch (e) {
          print('⚠️ Erro ao processar família $familia: $e');
        }

        // Pequena pausa para não sobrecarregar a API
        await Future.delayed(Duration(milliseconds: 200));
      }

      print('✅ Importação concluída: $familiasInseridas famílias, $especiesInseridas espécies');

      return {
        'sucesso': true,
        'familias': familiasInseridas,
        'especies': especiesInseridas,
        'mensagem': 'Taxonomia importada com sucesso!'
      };
    } catch (e) {
      print('❌ Erro na importação: $e');
      return {
        'sucesso': false,
        'erro': 'Erro ao importar taxonomia: $e'
      };
    }
  }

  Future<List<String>> _buscarFamilias() async {
    try {
      final response = await http.get(
        Uri.parse('$_apiUrl/familia'),
        headers: _headers,
      ).timeout(Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        final List<String> familias = [];

        if (data is List) {
          for (var item in data) {
            final nome = item['nome']?.toString() ?? '';
            if (nome.isNotEmpty) {
              familias.add(nome);
            }
          }
        }
        return familias.toSet().toList()..sort();
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      print('❌ Erro ao buscar famílias: $e');
      throw e;
    }
  }

  Future<List<Map<String, dynamic>>> _buscarEspeciesPorFamilia(String familia) async {
    try {
      final response = await http.get(
        Uri.parse('$_apiUrl/especie?familia=${Uri.encodeQueryComponent(familia)}'),
        headers: _headers,
      ).timeout(Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        final List<Map<String, dynamic>> especies = [];

        if (data is List) {
          for (var item in data) {
            final nomeCientifico = item['nomeCientifico']?.toString() ?? '';
            if (nomeCientifico.isNotEmpty) {
              especies.add({
                'nome_cientifico': nomeCientifico,
                'sinonimos': _extrairSinonimos(item),
                'nome_popular': _extrairNomesPopulares(item),
              });
            }
          }
        }

        return especies;
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      print('❌ Erro ao buscar espécies da família $familia: $e');
      return [];
    }
  }

  String? _extrairSinonimos(Map<String, dynamic> especie) {
    try {
      if (especie['sinonimos'] != null && especie['sinonimos'] is List) {
        final sinonimos = (especie['sinonimos'] as List)
            .whereType<String>()
            .where((s) => s.isNotEmpty)
            .toList();
        return sinonimos.isNotEmpty ? sinonimos.join('; ') : null;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  String? _extrairNomesPopulares(Map<String, dynamic> especie) {
    try {
      if (especie['nomesPopulares'] != null && especie['nomesPopulares'] is List) {
        final nomes = (especie['nomesPopulares'] as List)
            .whereType<String>()
            .where((n) => n.isNotEmpty)
            .toList();
        return nomes.isNotEmpty ? nomes.join('; ') : null;
      }

      // Tenta buscar em campos alternativos
      if (especie['nomePopular'] != null && especie['nomePopular'] is String) {
        final nome = especie['nomePopular'] as String;
        return nome.isNotEmpty ? nome : null;
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  // Busca espécies por termo (para autocomplete)
  Future<List<Map<String, dynamic>>> buscarEspecies(String termo) async {
    try {
      if (termo.length < 2) return [];

      final response = await http.get(
        Uri.parse('$_apiUrl/especie?nome=${Uri.encodeQueryComponent(termo)}'),
        headers: _headers,
      ).timeout(Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        final List<Map<String, dynamic>> resultados = [];

        if (data is List) {
          for (var item in data.take(20)) {
            final nomeCientifico = item['nomeCientifico']?.toString() ?? '';
            if (nomeCientifico.isNotEmpty) {
              resultados.add({
                'nome_cientifico': nomeCientifico,
                'familia': item['familia']?.toString() ?? '',
                'sinonimos': _extrairSinonimos(item),
                'nome_popular': _extrairNomesPopulares(item),
              });
            }
          }
        }

        return resultados;
      }

      return [];
    } catch (e) {
      print('⚠️ Erro na busca de espécies: $e');
      return await _buscarEspeciesLocais(termo);
    }
  }

  Future<List<Map<String, dynamic>>> _buscarEspeciesLocais(String termo) async {
    try {
      final familias = await _dbHelper.getFamilias(filtro: '');
      final resultados = <Map<String, dynamic>>[];

      for (final familia in familias) {
        final especies = await _dbHelper.getEspeciesByFamilia(familia, filtro: termo);
        for (final especie in especies) {
          resultados.add({
            'nome_cientifico': especie,
            'familia': familia,
            'sinonimos': null,
            'nome_popular': null,
          });
        }

        if (resultados.length >= 20) break;
      }

      return resultados;
    } catch (e) {
      return [];
    }
  }

  // Busca famílias por termo
  Future<List<String>> buscarFamilias(String termo) async {
    try {
      if (termo.isEmpty) {
        return await _dbHelper.getFamilias(filtro: '');
      }

      final response = await http.get(
        Uri.parse('$_apiUrl/familia?nome=${Uri.encodeQueryComponent(termo)}'),
        headers: _headers,
      ).timeout(Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        final List<String> familias = [];

        if (data is List) {
          for (var item in data) {
            final nome = item['nome']?.toString() ?? '';
            if (nome.isNotEmpty) {
              familias.add(nome);
            }
          }
        }

        return familias.take(50).toList();
      }

      return await _dbHelper.getFamilias(filtro: termo);
    } catch (e) {
      print('⚠️ Erro na busca de famílias: $e');
      return await _dbHelper.getFamilias(filtro: termo);
    }
  }

  // Método para verificar se a API está disponível
  Future<bool> verificarConexao() async {
    try {
      final response = await http.get(
        Uri.parse('$_apiUrl/familia'),
        headers: _headers,
      ).timeout(Duration(seconds: 10));

      return response.statusCode == 200;
    } catch (e) {
      print('❌ API REFLORA indisponível: $e');
      return false;
    }
  }

  // Busca detalhes de uma espécie específica
  Future<Map<String, dynamic>?> buscarDetalhesEspecie(String nomeCientifico) async {
    try {
      final response = await http.get(
        Uri.parse('$_apiUrl/especie?nomeCientifico=${Uri.encodeQueryComponent(nomeCientifico)}'),
        headers: _headers,
      ).timeout(Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));

        if (data is List && data.isNotEmpty) {
          final especie = data.first;
          return {
            'nome_cientifico': especie['nomeCientifico'] ?? '',
            'familia': especie['familia'] ?? '',
            'sinonimos': _extrairSinonimos(especie),
            'nome_popular': _extrairNomesPopulares(especie),
            'autor': especie['autor'] ?? '',
            'status': especie['status'] ?? '',
            'origem': especie['origem'] ?? '',
          };
        }
      }

      return null;
    } catch (e) {
      print('⚠️ Erro ao buscar detalhes da espécie: $e');
      return null;
    }
  }
}