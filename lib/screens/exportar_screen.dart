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

  List<int> _blocosDisponiveis = [];

  String? _loadingAction;

  @override
  void initState() {
    super.initState();
    _futureStats = _exportService.getExportStats(widget.inventarioId);
    _carregarBlocos();
  }

  Future<void> _carregarBlocos() async {
    try {
      final blocos = await _exportService.getBlocosDisponiveis(widget.inventarioId);
      setState(() => _blocosDisponiveis = blocos);
    } catch (_) {}
  }

  bool get _isLoading => _loadingAction != null;

  // ─── Dialog de seleção de blocos ──────────────────────────────────────────

  /// Abre o dialog e retorna a lista de blocos escolhidos pelo usuário,
  /// ou null se ele cancelou.
  Future<List<int>?> _showBlocoDialog() async {
    // Se só existe um bloco, não tem sentido exibir o dialog
    if (_blocosDisponiveis.length <= 1) return _blocosDisponiveis;

    Set<int> selecionados = _blocosDisponiveis.toSet();

    return showDialog<List<int>>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final todos = selecionados.length == _blocosDisponiveis.length;

            void toggle(int bloco) {
              setDialogState(() {
                if (selecionados.contains(bloco)) {
                  if (selecionados.length > 1) selecionados.remove(bloco);
                } else {
                  selecionados.add(bloco);
                }
              });
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              titlePadding: EdgeInsets.fromLTRB(20, 20, 12, 0),
              contentPadding: EdgeInsets.fromLTRB(20, 12, 20, 0),
              title: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.view_module,
                        color: Colors.green, size: 20),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Selecionar Blocos',
                            style: TextStyle(fontSize: 16)),
                        Text(
                          '${selecionados.length} de ${_blocosDisponiveis.length} selecionado(s)',
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.normal),
                        ),
                      ],
                    ),
                  ),
                  // Botão Todos / Limpar
                  TextButton(
                    onPressed: () => setDialogState(() {
                      selecionados = todos
                          ? {_blocosDisponiveis.first}
                          : _blocosDisponiveis.toSet();
                    }),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.green,
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(todos ? 'Limpar' : 'Todos',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(height: 4),
                    Divider(height: 1),
                    ConstrainedBox(
                      constraints: BoxConstraints(maxHeight: 260),
                      child: Scrollbar(
                        thumbVisibility: true,
                        child: ListView.separated(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          itemCount: _blocosDisponiveis.length,
                          separatorBuilder: (_, __) =>
                              Divider(height: 1, indent: 16, endIndent: 16),
                          itemBuilder: (_, index) {
                            final bloco = _blocosDisponiveis[index];
                            final sel = selecionados.contains(bloco);
                            final unico = sel && selecionados.length == 1;
                            return InkWell(
                              onTap: unico ? null : () => toggle(bloco),
                              borderRadius: BorderRadius.circular(8),
                              child: Padding(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 12),
                                child: Row(
                                  children: [
                                    AnimatedContainer(
                                      duration: Duration(milliseconds: 180),
                                      width: 22,
                                      height: 22,
                                      decoration: BoxDecoration(
                                        color: sel
                                            ? Colors.green
                                            : Colors.transparent,
                                        border: Border.all(
                                          color: unico
                                              ? Colors.green.withOpacity(0.4)
                                              : sel
                                              ? Colors.green
                                              : Colors.grey[400]!,
                                          width: 2,
                                        ),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: sel
                                          ? Icon(Icons.check,
                                          size: 14, color: Colors.white)
                                          : null,
                                    ),
                                    SizedBox(width: 14),
                                    Text(
                                      'Bloco $bloco',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: sel
                                            ? FontWeight.w600
                                            : FontWeight.normal,
                                        color: unico
                                            ? Colors.grey[500]
                                            : Colors.grey[850],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    Divider(height: 1),
                    if (!todos) ...[
                      SizedBox(height: 10),
                      Container(
                        width: double.maxFinite,
                        padding: EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.amber[50],
                          border: Border.all(color: Colors.amber[300]!),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.filter_alt,
                                size: 14, color: Colors.amber[700]),
                            SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Somente os blocos selecionados serão exportados.',
                                style: TextStyle(
                                    fontSize: 11, color: Colors.amber[800]),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    SizedBox(height: 4),
                  ],
                ),
              ),
              actionsPadding:
              EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, null),
                  child: Text('Cancelar',
                      style: TextStyle(color: Colors.grey[600])),
                ),
                ElevatedButton(
                  onPressed: () =>
                      Navigator.pop(ctx, selecionados.toList()..sort()),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text('Confirmar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ─── Ações de exportação ──────────────────────────────────────────────────

  Future<void> _share(String format) async {
    final blocos = await _showBlocoDialog();
    if (blocos == null) return; // usuário cancelou

    final filtro =
    blocos.length == _blocosDisponiveis.length ? null : blocos;

    final actionKey = '${format}_share';
    setState(() => _loadingAction = actionKey);
    try {
      switch (format) {
        case 'csv':
          await _exportService.exportToCsv(widget.inventarioId,
              blocosSelecionados: filtro);
          break;
        case 'xlsx':
          await _exportService.exportToXlsx(widget.inventarioId,
              blocosSelecionados: filtro);
          break;
        case 'sql':
          await _exportService.exportToSql(widget.inventarioId,
              blocosSelecionados: filtro);
          break;
      }
    } catch (e) {
      if (mounted) _showError('Erro ao compartilhar: $e');
    } finally {
      if (mounted) setState(() => _loadingAction = null);
    }
  }

  Future<void> _saveLocally(String format) async {
    final blocos = await _showBlocoDialog();
    if (blocos == null) return; // usuário cancelou

    final filtro =
    blocos.length == _blocosDisponiveis.length ? null : blocos;

    final actionKey = '${format}_save';
    setState(() => _loadingAction = actionKey);
    try {
      File savedFile;
      switch (format) {
        case 'csv':
          savedFile = await _exportService.saveCsvToDownloads(
              widget.inventarioId,
              blocosSelecionados: filtro);
          break;
        case 'xlsx':
          savedFile = await _exportService.saveXlsxToDownloads(
              widget.inventarioId,
              blocosSelecionados: filtro);
          break;
        case 'sql':
          savedFile = await _exportService.saveSqlToDownloads(
              widget.inventarioId,
              blocosSelecionados: filtro);
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

  // ─── Diálogos e snackbars ─────────────────────────────────────────────────

  void _showSaveSuccess(String path) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
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
                style:
                TextStyle(fontSize: 12, fontFamily: 'monospace'),
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

  // ─── Widgets ──────────────────────────────────────────────────────────────

  Widget _buildFormatCard({
    required String format,
    required String label,
    required String description,
    required IconData icon,
    required Color color,
  }) {
    final isSharingLoading = _loadingAction == '${format}_share';
    final isSavingLoading = _loadingAction == '${format}_save';

    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape:
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                      Text(label,
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                      Text(description,
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey[600])),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 14),
            Divider(height: 1),
            SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed:
                    _isLoading ? null : () => _saveLocally(format),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: color,
                      side: BorderSide(color: color),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      padding: EdgeInsets.symmetric(vertical: 10),
                    ),
                    icon: isSavingLoading
                        ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor:
                        AlwaysStoppedAnimation<Color>(color),
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
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed:
                    _isLoading ? null : () => _share(format),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: color,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: color.withOpacity(0.4),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      padding: EdgeInsets.symmetric(vertical: 10),
                    ),
                    icon: isSharingLoading
                        ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white),
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
      body: ListView(
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
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.summarize,
                                color: Colors.green, size: 22),
                            SizedBox(width: 8),
                            Text('Resumo do Inventário',
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                        SizedBox(height: 12),
                        _buildStatRow(Icons.forest, 'Inventário',
                            '${stats['nomeInventario']}'),
                        _buildStatRow(Icons.grid_on, 'Parcelas',
                            '${stats['totalParcelas']}'),
                        _buildStatRow(Icons.park, 'Árvores',
                            '${stats['totalArvores']}'),
                        _buildStatRow(
                          Icons.view_module,
                          'Estrutura',
                          '${stats['blocos']} Blocos × ${stats['faixas']} Faixas × ${stats['parcelasPorBloco']} Parcelas',
                        ),
                      ],
                    ),
                  ),
                );
              }
              return SizedBox.shrink();
            },
          ),

          // Legenda
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(children: [
              Icon(Icons.save_alt, size: 14, color: Colors.grey[500]),
              SizedBox(width: 4),
              Text('Salvar — grava direto em Downloads/Documentos',
                  style:
                  TextStyle(fontSize: 11, color: Colors.grey[500])),
            ]),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              Icon(Icons.share, size: 14, color: Colors.grey[500]),
              SizedBox(width: 4),
              Text(
                  'Compartilhar — abre o menu do sistema (Drive, e-mail…)',
                  style:
                  TextStyle(fontSize: 11, color: Colors.grey[500])),
            ]),
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
    );
  }

  Widget _buildStatRow(IconData icon, String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey[500], size: 15),
          SizedBox(width: 6),
          Expanded(
              child: Text(label,
                  style: TextStyle(
                      color: Colors.grey[700], fontSize: 13))),
          Text(value,
              style:
              TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }
}