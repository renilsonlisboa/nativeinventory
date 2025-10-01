import 'package:flutter/material.dart';
import '../services/export_service.dart';

class ExportarScreen extends StatefulWidget {
  final int inventarioId;

  const ExportarScreen({Key? key, required this.inventarioId}) : super(key: key);

  @override
  _ExportarScreenState createState() => _ExportarScreenState();
}

class _ExportarScreenState extends State<ExportarScreen> {
  final ExportService _exportService = ExportService();
  late Future<Map<String, dynamic>> _futureStats;
  bool _isExporting = false;
  String? _exportMessage;
  bool _exportSuccess = false;

  @override
  void initState() {
    super.initState();
    _futureStats = _exportService.getExportStats(widget.inventarioId);
  }

  void _exportData(String format) async {
    setState(() {
      _isExporting = true;
      _exportMessage = null;
      _exportSuccess = false;
    });

    try {
      switch (format) {
        case 'csv':
          await _exportService.exportToCsv(widget.inventarioId);
          break;
        case 'xlsx':
          await _exportService.exportToXlsx(widget.inventarioId);
          break;
        case 'sql':
          await _exportService.exportToSql(widget.inventarioId);
          break;
        default:
          throw Exception('Formato não suportado');
      }

      setState(() {
        _exportMessage = 'Exportação concluída com sucesso! Use o menu de compartilhamento para salvar o arquivo.';
        _exportSuccess = true;
      });
    } catch (e) {
      setState(() {
        _exportMessage = 'Erro ao exportar: $e';
        _exportSuccess = false;
      });
    } finally {
      setState(() {
        _isExporting = false;
      });
    }
  }

  Widget _buildExportButton(String format, String label, IconData icon, Color color) {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      child: ListTile(
        leading: Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 28),
        ),
        title: Text(
          label,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Text(
          'Exportar dados no formato $format\nO arquivo será salvo temporariamente e você poderá escolher onde guardá-lo',
          style: TextStyle(fontSize: 12),
        ),
        trailing: _isExporting
            ? CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(color))
            : Icon(Icons.arrow_forward_ios, color: color),
        onTap: _isExporting ? null : () => _exportData(format),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Exportar Dados'),
        backgroundColor: Colors.green,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Estatísticas
          FutureBuilder<Map<String, dynamic>>(
            future: _futureStats,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Padding(
                  padding: EdgeInsets.all(16),
                  child: LinearProgressIndicator(),
                );
              } else if (snapshot.hasError) {
                return Card(
                  margin: EdgeInsets.all(16),
                  color: Colors.red[50],
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Icon(Icons.error, color: Colors.red, size: 48),
                        SizedBox(height: 8),
                        Text(
                          'Erro ao carregar estatísticas',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 4),
                        Text(
                          '${snapshot.error}',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                );
              } else if (snapshot.hasData) {
                final stats = snapshot.data!;
                return Card(
                  margin: EdgeInsets.all(16),
                  elevation: 2,
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.summarize, color: Colors.green, size: 24),
                            SizedBox(width: 8),
                            Text(
                              'Resumo do Inventário',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        SizedBox(height: 16),
                        _buildStatRow(Icons.forest, 'Inventário', stats['nomeInventario']),
                        _buildStatRow(Icons.grid_on, 'Total de Parcelas', '${stats['totalParcelas']}'),
                        _buildStatRow(Icons.park, 'Total de Árvores', '${stats['totalArvores']}'),
                        _buildStatRow(Icons.view_module, 'Estrutura', '${stats['blocos']} Blocos × ${stats['faixas']} Faixas × ${stats['parcelasPorBloco']} Parcelas'),
                      ],
                    ),
                  ),
                );
              }
              return SizedBox.shrink();
            },
          ),

          // Instruções
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Card(
              elevation: 2,
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info, color: Colors.blue, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Como exportar:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(
                      '1. Escolha o formato desejado\n'
                          '2. Aguarde o processamento\n'
                          '3. Use o menu de compartilhamento do seu dispositivo\n'
                          '4. Escolha onde salvar (Google Drive, Downloads, etc.)',
                      style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Opções de exportação
          Expanded(
            child: ListView(
              children: [
                _buildExportButton('csv', 'Exportar para CSV', Icons.table_chart, Colors.blue),
                _buildExportButton('xlsx', 'Exportar para Excel', Icons.analytics, Colors.green),
                _buildExportButton('sql', 'Exportar para SQL', Icons.storage, Colors.orange),
              ],
            ),
          ),

          // Mensagem de status
          if (_exportMessage != null)
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _exportSuccess ? Colors.green[50] : Colors.red[50],
                border: Border(
                  top: BorderSide(
                    color: _exportSuccess ? Colors.green : Colors.red,
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _exportSuccess ? Icons.check_circle : Icons.error,
                    color: _exportSuccess ? Colors.green : Colors.red,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _exportSuccess ? 'Sucesso!' : 'Atenção',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _exportSuccess ? Colors.green : Colors.red,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          _exportMessage!,
                          style: TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatRow(IconData icon, String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey[600], size: 16),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: Colors.grey[700]),
            ),
          ),
          Text(
            value,
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}