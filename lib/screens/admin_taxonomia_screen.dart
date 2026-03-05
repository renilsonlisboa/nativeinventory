// screens/admin_taxonomia_screen.dart
import 'package:flutter/material.dart';
import '../services/reflora_service.dart';
import '../database/database_helper.dart';

class AdminTaxonomiaScreen extends StatefulWidget {
  @override
  _AdminTaxonomiaScreenState createState() => _AdminTaxonomiaScreenState();
}

class _AdminTaxonomiaScreenState extends State<AdminTaxonomiaScreen> {
  final RefloraFamiliasService _refloraService = RefloraFamiliasService();
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
    final stats = await _refloraService.getEstatisticas();
    setState(() {
      _totalFamilias = stats['familias']!;
      _totalEspecies = stats['especies']!;
    });
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
          ? '✅ Conectado ao GitHub - Dados disponíveis'
          : '⚠️ Modo Offline - Usando dados locais';
    });
  }

  Future<void> _importarDados() async {
    setState(() {
      _importando = true;
      _status = 'Baixando e processando CSV do GitHub...';
    });

    try {
      final resultado = await _refloraService.importarDadosCompletos();

      setState(() {
        _importando = false;
        _status = resultado['sucesso'] == true
            ? '✅ ${resultado['mensagem']}'
            : '❌ ${resultado['erro']}';
      });

      if (resultado['sucesso'] == true) {
        await _carregarEstatisticas();
        _mostrarResultadoImportacao(
          familias: resultado['familias'] ?? 0,
          especies: resultado['especies'] ?? 0,
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
        title: Text('Limpar Base de Dados'),
        content: Text(
            'Tem certeza que deseja remover todas as famílias e espécies da base local? Esta ação não pode ser desfeita.'),
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
        _status = 'Limpando base de dados...';
      });

      try {
        await _dbHelper.clearTaxonomia();
        await _carregarEstatisticas();
        setState(() {
          _status = '✅ Base de dados limpa com sucesso';
        });
      } catch (e) {
        setState(() {
          _status = '❌ Erro ao limpar base: $e';
        });
      }
    }
  }

  void _mostrarResultadoImportacao(
      {required int familias, required int especies}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 6),
            Text('Importação Concluída'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Dados importados do GitHub com sucesso!'),
            SizedBox(height: 16),
            _buildItemEstatistica('Famílias:', familias.toString()),
            _buildItemEstatistica('Espécies:', especies.toString()),
            SizedBox(height: 8),
            Text(
              'A base local foi atualizada com os dados da flora brasileira.',
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
          Expanded(
            flex: 3,
            child: Text(label, style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: Text(value,
                textAlign: TextAlign.right,
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Base de Dados REFLORA',
            style: TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.green.shade700,
        elevation: 4,
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
            colors: [Colors.green.shade50, Colors.blue.shade50],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildStatusCard(),
              SizedBox(height: 16),
              _buildStatsCard(),
              SizedBox(height: 16),
              if (_status.isNotEmpty) _buildOperationStatusCard(),
              SizedBox(height: 16),
              _buildActionCard(),
              SizedBox(height: 16),
              _buildInfoCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    return Card(
      elevation: 4,
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
                    _apiDisponivel ? Colors.green : Colors.orange),
              ),
            )
                : Icon(
              _apiDisponivel ? Icons.cloud_done : Icons.cloud_off,
              color: _apiDisponivel
                  ? Colors.green.shade700
                  : Colors.orange.shade700,
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _apiDisponivel ? 'Conectado ao GitHub' : 'Modo Offline',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: _apiDisponivel
                          ? Colors.green.shade700
                          : Colors.orange.shade700,
                    ),
                  ),
                  Text(
                    _apiDisponivel
                        ? 'Dados consolidados da flora brasileira'
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Dados Atuais',
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
                _buildEstatisticaCard(
                    'Famílias', _totalFamilias, Icons.category),
                _buildEstatisticaCard(
                    'Espécies', _totalEspecies, Icons.science),
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
            Expanded(
                child: Text(_status, style: TextStyle(color: Colors.black87))),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Gerenciar Base de Dados',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.green.shade800,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Atualize a base local com os dados consolidados do REFLORA (CSV)',
              style: TextStyle(color: Colors.grey.shade600),
            ),
            SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _importando ? null : _importarDados,
                icon: _importando
                    ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor:
                    AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
                    : Icon(Icons.cloud_download),
                label: Text(
                  _importando
                      ? 'Importando Dados...'
                      : 'Importar Dados do GitHub',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade700,
                  foregroundColor: Colors.white,
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            SizedBox(height: 12),
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sobre os Dados',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade800,
              ),
            ),
            SizedBox(height: 12),
            _buildInfoItem('🌿', 'Dados consolidados da Flora do Brasil'),
            _buildInfoItem('📊', 'Famílias e espécies catalogadas'),
            _buildInfoItem('📦', 'Fonte: GitHub - reflora_data'),
            _buildInfoItem('💾', 'Funciona offline após importação'),
            _buildInfoItem('🔄', 'Atualize periodicamente'),
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
          style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
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