// screens/admin_taxonomia_screen.dart
import 'package:flutter/material.dart';
import '../services/reflora_service.dart';
import '../database/database_helper.dart';

class AdminTaxonomiaScreen extends StatefulWidget {
  @override
  _AdminTaxonomiaScreenState createState() => _AdminTaxonomiaScreenState();
}

class _AdminTaxonomiaScreenState extends State<AdminTaxonomiaScreen> {
  final RefloraService _refloraService = RefloraService();
  final DatabaseHelper _dbHelper = DatabaseHelper();

  bool _importando = false;
  bool _verificandoConexao = false;
  int _totalFamilias = 0;
  int _totalEspecies = 0;
  String _status = '';
  bool _apiDisponivel = false;

  @override
  void initState() {
    super.initState();
    _carregarEstatisticas();
    _verificarConexaoAPI();
  }

  Future<void> _carregarEstatisticas() async {
    try {
      final familias = await _dbHelper.getCountFamilias();
      final especies = await _dbHelper.getCountEspecies();

      setState(() {
        _totalFamilias = familias;
        _totalEspecies = especies;
      });
    } catch (e) {
      print('Erro ao carregar estatísticas: $e');
    }
  }

  Future<void> _verificarConexaoAPI() async {
    setState(() {
      _verificandoConexao = true;
    });

    final conectado = await _refloraService.verificarConexao();

    setState(() {
      _verificandoConexao = false;
      _apiDisponivel = conectado;
      _status = conectado
          ? '✅ Conectado ao REFLORA Online'
          : '⚠️ Modo Offline - Dados Locais';
    });
  }

  Future<void> _importarReflora() async {
    setState(() {
      _importando = true;
      _status = 'Conectando com REFLORA...';
    });

    try {
      final resultado = await _refloraService.importarTaxonomia();

      setState(() {
        _importando = false;
        _status = resultado['sucesso'] == true
            ? '✅ ${resultado['mensagem']}'
            : '❌ ${resultado['erro']}';
      });

      if (resultado['sucesso'] == true) {
        await _carregarEstatisticas();
        _mostrarResultadoImportacao(
            resultado['familias'] ?? 0,
            resultado['especies'] ?? 0
        );
      }
    } catch (e) {
      setState(() {
        _importando = false;
        _status = '❌ Erro na importação: $e';
      });
    }
  }

  Future<void> _limparTaxonomia() async {
    final confirmado = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Limpar Taxonomia'),
        content: Text('Tem certeza que deseja remover todas as famílias e espécies? Esta ação não pode ser desfeita.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Limpar Tudo', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmado == true) {
      setState(() {
        _status = 'Limpando taxonomia...';
      });

      try {
        await _dbHelper.clearTaxonomia();
        await _carregarEstatisticas();

        setState(() {
          _status = '✅ Taxonomia limpa com sucesso';
        });
      } catch (e) {
        setState(() {
          _status = '❌ Erro ao limpar taxonomia: $e';
        });
      }
    }
  }

  void _mostrarResultadoImportacao(int familias, int especies) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text('Importação Concluída'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Dados importados do REFLORA com sucesso!'),
            SizedBox(height: 16),
            _buildItemEstatistica('Famílias importadas:', familias.toString()),
            _buildItemEstatistica('Espécies importadas:', especies.toString()),
            SizedBox(height: 8),
            Text(
              'A base local foi atualizada com os dados mais recentes da flora brasileira.',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Fechar'),
          ),
        ],
      ),
    );
  }

  Widget _buildItemEstatistica(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          SizedBox(width: 8),
          Text(value),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Taxonomia Botânica',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.green.shade700,
        elevation: 4,
        shadowColor: Colors.black26,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.white),
            onPressed: _verificandoConexao ? null : _verificarConexaoAPI,
            tooltip: 'Verificar Conexão',
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.green.shade50,
              Colors.blue.shade50,
            ],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Status da Conexão (card estilizado)
              _buildStatusCard(),
              SizedBox(height: 16),

              // Cartão de estatísticas
              _buildStatsCard(),
              SizedBox(height: 16),

              // Status da operação (se houver)
              if (_status.isNotEmpty) _buildOperationStatusCard(),
              SizedBox(height: 16),

              // Botões de ação (gerenciar taxonomia)
              _buildActionCard(),
              SizedBox(height: 16),

              // Informações sobre REFLORA
              _buildInfoCard(),
            ],
          ),
        ),
      ),
    );
  }

  // Cards estilizados com sombra e bordas arredondadas
  Widget _buildStatusCard() {
    return Card(
      elevation: 4,
      shadowColor: Colors.black26,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: _apiDisponivel ? Colors.green.shade50 : Colors.orange.shade50,
        ),
        padding: EdgeInsets.all(16),
        child: Row(
          children: [
            _verificandoConexao
                ? SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  _apiDisponivel ? Colors.green : Colors.orange,
                ),
              ),
            )
                : Icon(
              _apiDisponivel ? Icons.wifi : Icons.wifi_off,
              color: _apiDisponivel ? Colors.green.shade700 : Colors.orange.shade700,
              size: 24,
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _apiDisponivel ? 'Conectado ao REFLORA' : 'Modo Offline',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: _apiDisponivel ? Colors.green.shade700 : Colors.orange.shade700,
                    ),
                  ),
                  Text(
                    _apiDisponivel
                        ? 'Dados em tempo real da flora brasileira'
                        : 'Usando base de dados local',
                    style: TextStyle(fontSize: 14, color: Colors.black54),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCard() {
    return Card(
      elevation: 4,
      shadowColor: Colors.black26,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Estatísticas da Base',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade800,
              ),
            ),
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildEstatisticaCard('Famílias', _totalFamilias, Icons.category),
                _buildEstatisticaCard('Espécies', _totalEspecies, Icons.eco),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOperationStatusCard() {
    Color cardColor = Colors.blue.shade50;
    Color iconColor = Colors.blue.shade700;
    IconData icon = Icons.info;

    if (_status.contains('✅')) {
      cardColor = Colors.green.shade50;
      iconColor = Colors.green.shade700;
      icon = Icons.check_circle;
    } else if (_status.contains('❌')) {
      cardColor = Colors.red.shade50;
      iconColor = Colors.red.shade700;
      icon = Icons.error;
    }

    return Card(
      elevation: 2,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: cardColor,
        ),
        padding: EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(icon, color: iconColor),
            SizedBox(width: 12),
            Expanded(child: Text(_status, style: TextStyle(color: Colors.black87))),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard() {
    return Card(
      elevation: 4,
      shadowColor: Colors.black26,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Gerenciar Taxonomia',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.green.shade800,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Atualize a base de dados com as famílias e espécies do REFLORA',
              style: TextStyle(color: Colors.grey.shade600),
            ),
            SizedBox(height: 16),
            // Botão Importar (verde)
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _importando ? null : _importarReflora,
                icon: _importando
                    ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
                    : Icon(Icons.cloud_download),
                label: Text(
                  _importando ? 'Importando...' : 'Importar do REFLORA',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade700,
                  foregroundColor: Colors.white,
                  elevation: 4,
                  shadowColor: Colors.green.shade700.withOpacity(0.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            SizedBox(height: 12),
            // Botão Limpar (vermelho delineado)
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton.icon(
                onPressed: _importando ? null : _limparTaxonomia,
                icon: Icon(Icons.delete, color: Colors.red.shade700),
                label: Text(
                  'Limpar Base Local',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.red.shade700,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.red.shade700, width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Card(
      elevation: 4,
      shadowColor: Colors.black26,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sobre o REFLORA',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade800,
              ),
            ),
            SizedBox(height: 12),
            _buildInfoItem('🌿', 'Dados oficiais da Flora do Brasil 2020'),
            _buildInfoItem('📊', 'Mais de 300 famílias e 30.000 espécies'),
            _buildInfoItem('⚡', 'Busca em tempo real quando online'),
            _buildInfoItem('💾', 'Funciona offline após importação'),
            _buildInfoItem('🔄', 'Atualize periodicamente para dados recentes'),
          ],
        ),
      ),
    );
  }

  Widget _buildEstatisticaCard(String titulo, int valor, IconData icone) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            shape: BoxShape.circle,
          ),
          child: Icon(icone, size: 30, color: Colors.blue.shade700),
        ),
        SizedBox(height: 8),
        Text(
          valor.toString(),
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: Colors.blue.shade800,
          ),
        ),
        Text(
          titulo,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoItem(String emoji, String texto) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: TextStyle(fontSize: 18)),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              texto,
              style: TextStyle(fontSize: 15, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }
}