import 'dart:io';
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

  // Controle de loading por ação individual: 'csv_share', 'csv_save', 'xlsx_share', etc.
  String? _loadingAction;

  @override
  void initState() {
    super.initState();
    _futureStats = _exportService.getExportStats(widget.inventarioId);
  }

  bool get _isLoading => _loadingAction != null;


  Future<void> _share(String format) async {
    final actionKey = '${format}_share';
    setState(() => _loadingAction = actionKey);
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
      }
    } catch (e) {
      if (mounted) _showError('Erro ao compartilhar: $e');
    } finally {
      if (mounted) setState(() => _loadingAction = null);
    }
  }

  Future<void> _saveLocally(String format) async {
    final actionKey = '${format}_save';
    setState(() => _loadingAction = actionKey);
    try {
      File savedFile;
      switch (format) {
        case 'csv':
          savedFile = await _exportService.saveCsvToDownloads(widget.inventarioId);
          break;
        case 'xlsx':
          savedFile = await _exportService.saveXlsxToDownloads(widget.inventarioId);
          break;
        case 'sql':
          savedFile = await _exportService.saveSqlToDownloads(widget.inventarioId);
          break;
        default:
          throw Exception('Formato não suportado');
      }
      if (mounted) _showSaveSuccess(savedFile.path);
    } catch (e) {
      if (mounted) _showError('Erro ao salvar: $e');
    } finally {
      if (mounted) setState(() => _loadingAction = null);
    }
  }


  void _showSaveSuccess(String path) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 28),
            SizedBox(width: 8),
            Text('Arquivo salvo!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('O arquivo foi salvo em:'),
            SizedBox(height: 8),
            Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                path,
                style: TextStyle(fontSize: 12, fontFamily: 'monospace'),
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Acesse pelo gerenciador de arquivos ou pelo app "Arquivos" do seu dispositivo.',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('OK', style: TextStyle(color: Colors.green)),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.white),
            SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red[700],
        behavior: SnackBarBehavior.floating,
      ),
    );
  }


  Widget _buildFormatCard({
    required String format,
    required String label,
    required String description,
    required IconData icon,
    required Color color,
  }) {
    final isSharingLoading = _loadingAction == '${format}_share';
    final isSavingLoading  = _loadingAction == '${format}_save';

    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabeçalho do formato
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 26),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text(
                        description,
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 14),
            Divider(height: 1),
            SizedBox(height: 12),
            // Botões de ação
            Row(
              children: [
                // Salvar no aparelho
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isLoading ? null : () => _saveLocally(format),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: color,
                      side: BorderSide(color: color),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: EdgeInsets.symmetric(vertical: 10),
                    ),
                    icon: isSavingLoading
                        ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(color),
                      ),
                    )
                        : Icon(Icons.save_alt, size: 18),
                    label: Text(
                      isSavingLoading ? 'Salvando...' : 'Salvar',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ),
                SizedBox(width: 10),
                // Compartilhar
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : () => _share(format),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: color,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: color.withOpacity(0.4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: EdgeInsets.symmetric(vertical: 10),
                    ),
                    icon: isSharingLoading
                        ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                        : Icon(Icons.share, size: 18),
                    label: Text(
                      isSharingLoading ? 'Aguarde...' : 'Compartilhar',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
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
          Expanded(
            child: ListView(
              children: [
                // Resumo do inventário
                FutureBuilder<Map<String, dynamic>>(
                  future: _futureStats,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Padding(
                        padding: EdgeInsets.all(16),
                        child: LinearProgressIndicator(color: Colors.green),
                      );
                    } else if (snapshot.hasError) {
                      return Card(
                        margin: EdgeInsets.all(16),
                        color: Colors.red[50],
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Icon(Icons.error, color: Colors.red),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Erro ao carregar estatísticas: ${snapshot.error}',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    } else if (snapshot.hasData) {
                      final stats = snapshot.data!;
                      return Card(
                        margin: EdgeInsets.fromLTRB(16, 16, 16, 8),
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.summarize, color: Colors.green, size: 22),
                                  SizedBox(width: 8),
                                  Text(
                                    'Resumo do Inventário',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              SizedBox(height: 12),
                              _buildStatRow(Icons.forest, 'Inventário', '${stats['nomeInventario']}'),
                              _buildStatRow(Icons.grid_on, 'Parcelas', '${stats['totalParcelas']}'),
                              _buildStatRow(Icons.park, 'Árvores', '${stats['totalArvores']}'),
                              _buildStatRow(Icons.view_module, 'Estrutura',
                                  '${stats['blocos']} Blocos × ${stats['faixas']} Faixas × ${stats['parcelasPorBloco']} Parcelas'),
                            ],
                          ),
                        ),
                      );
                    }
                    return SizedBox.shrink();
                  },
                ),

                // Legenda dos botões
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(
                    children: [
                      Icon(Icons.save_alt, size: 14, color: Colors.grey[500]),
                      SizedBox(width: 4),
                      Text('Salvar — grava direto em Downloads/Documentos',
                          style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Icon(Icons.share, size: 14, color: Colors.grey[500]),
                      SizedBox(width: 4),
                      Text('Compartilhar — abre o menu do sistema (Drive, e-mail…)',
                          style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                    ],
                  ),
                ),
                SizedBox(height: 8),

                // Cards de formato
                _buildFormatCard(
                  format: 'csv',
                  label: 'CSV',
                  description: 'Compatível com Excel, Google Sheets e R',
                  icon: Icons.table_chart,
                  color: Colors.blue,
                ),
                _buildFormatCard(
                  format: 'xlsx',
                  label: 'Excel (.xlsx)',
                  description: 'Planilha formatada para Microsoft Excel',
                  icon: Icons.analytics,
                  color: Colors.green[700]!,
                ),
                _buildFormatCard(
                  format: 'sql',
                  label: 'SQL',
                  description: 'Script de backup para banco de dados',
                  icon: Icons.storage,
                  color: Colors.orange,
                ),

                SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(IconData icon, String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey[500], size: 15),
          SizedBox(width: 6),
          Expanded(child: Text(label, style: TextStyle(color: Colors.grey[700], fontSize: 13))),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }
}