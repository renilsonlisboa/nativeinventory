import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import '../services/import_service.dart';
import '../models/importacao_config.dart';

class ImportarScreen extends StatefulWidget {
  final int inventarioId;
  final String nomeInventario;

  const ImportarScreen({
    Key? key,
    required this.inventarioId,
    required this.nomeInventario,
  }) : super(key: key);

  @override
  _ImportarScreenState createState() => _ImportarScreenState();
}

class _ImportarScreenState extends State<ImportarScreen> {
  final ImportService _importService = ImportService();
  final TextEditingController _filePathController = TextEditingController();
  String? _fileName;
  File? _selectedFile;
  bool _isImporting = false;
  bool _isValidatingFile = false;
  String? _message;
  bool _success = false;
  List<String> _logs = [];
  Map<String, dynamic>? _resumo;
  int _fileSize = 0;

  void _pickFile() async {
    try {
      PermissionStatus status = await Permission.storage.request();

      if (!status.isGranted) {
        setState(() {
          _message = 'Permissão de armazenamento negada. É necessário permitir o acesso aos arquivos para importar dados.';
          _success = false;
        });
        return;
      }

      setState(() {
        _isValidatingFile = true;
        _message = null;
      });

      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'xlsx', 'xls', 'txt'],
        allowMultiple: false,
        dialogTitle: 'Selecione o arquivo CSV para importar',
        allowCompression: true,
      );

      if (result != null && result.files.isNotEmpty) {
        PlatformFile file = result.files.first;

        if (file.path == null) {
          setState(() {
            _message = 'Erro: Não foi possível acessar o caminho do arquivo.';
            _success = false;
          });
          return;
        }

        setState(() {
          _selectedFile = File(file.path!);
          _fileName = file.name;
          _fileSize = file.size;
          _filePathController.text = file.path!;
          _message = 'Arquivo selecionado: ${file.name} (${_formatFileSize(file.size)})';
          _success = true;
          _logs.clear();
          _resumo = null;
        });

        _adicionarLog('Arquivo selecionado: ${file.name}');
        _adicionarLog('Tamanho: ${_formatFileSize(file.size)}');
        _adicionarLog('Caminho: ${file.path}');
      } else {
        setState(() {
          _message = 'Nenhum arquivo selecionado.';
          _success = false;
        });
      }
    } catch (e) {
      setState(() {
        _message = 'Erro ao selecionar arquivo: $e';
        _success = false;
      });
      _adicionarLog('ERRO ao selecionar arquivo: $e');
    } finally {
      setState(() {
        _isValidatingFile = false;
      });
    }
  }

  void _adicionarLog(String mensagem) {
    _logs.add('${DateTime.now().toString().split(' ')[1]} - $mensagem');
  }

  void _createSampleFile() async {
    try {
      setState(() {
        _isValidatingFile = true;
        _message = null;
      });

      final String csvData = await rootBundle.loadString('assets/csv/dados.csv');

      final tempDir = await getTemporaryDirectory();
      final sampleFile = File('${tempDir.path}/dados.csv');

      await sampleFile.writeAsString(csvData);

      setState(() {
        _selectedFile = sampleFile;
        _fileName = 'dados.csv';
        _fileSize = csvData.length;
        _filePathController.text = sampleFile.path;
        _message = 'Arquivo de exemplo (dados.csv) criado com sucesso! Use este arquivo para testar a importação.';
        _success = true;
        _logs.clear();
        _resumo = null;
      });

      _adicionarLog('Arquivo de exemplo criado: ${sampleFile.path}');
      _adicionarLog('Dados carregados do arquivo assets/csv/dados.csv');
    } catch (e) {
      setState(() {
        _message = 'Erro ao criar arquivo de exemplo: $e. Certifique-se de que o arquivo assets/csv/dados.csv existe.';
        _success = false;
      });
      _adicionarLog('ERRO ao criar exemplo: $e');
    } finally {
      setState(() {
        _isValidatingFile = false;
      });
    }
  }

  void _copyAssetFileToDownload() async {
    try {
      setState(() {
        _isValidatingFile = true;
        _message = null;
      });

      PermissionStatus status = await Permission.storage.request();
      if (!status.isGranted) {
        setState(() {
          _message = 'Permissão de armazenamento necessária.';
          _success = false;
        });
        return;
      }

      final ByteData data = await rootBundle.load('assets/csv/dados.csv');
      final List<int> bytes = data.buffer.asUint8List();

      final Directory? downloadsDir = await getExternalStorageDirectory();
      if (downloadsDir == null) {
        setState(() {
          _message = 'Não foi possível acessar o diretório de downloads.';
          _success = false;
        });
        return;
      }

      final File assetFile = File('${downloadsDir.path}/dados.csv');
      await assetFile.writeAsBytes(bytes);

      setState(() {
        _selectedFile = assetFile;
        _fileName = 'dados.csv';
        _fileSize = bytes.length;
        _filePathController.text = assetFile.path;
        _message = 'Arquivo dados.csv copiado para: ${assetFile.path}';
        _success = true;
        _logs.clear();
        _resumo = null;
      });

      _adicionarLog('Arquivo copiado para: ${assetFile.path}');
      _adicionarLog('Tamanho: ${_formatFileSize(bytes.length)}');
    } catch (e) {
      setState(() {
        _message = 'Erro ao copiar arquivo: $e';
        _success = false;
      });
      _adicionarLog('ERRO ao copiar arquivo: $e');
    } finally {
      setState(() {
        _isValidatingFile = false;
      });
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB"];
    int i = (math.log(bytes) / math.log(1024)).floor();
    return '${(bytes / math.pow(1024, i)).toStringAsFixed(1)} ${suffixes[i]}';
  }

  void _importFile() async {
    if (_selectedFile == null) {
      setState(() {
        _message = 'Nenhum arquivo válido selecionado.';
        _success = false;
      });
      return;
    }

    if (!await _selectedFile!.exists()) {
      setState(() {
        _message = 'Arquivo não encontrado. O arquivo pode ter sido movido ou excluído.';
        _success = false;
      });
      return;
    }

    setState(() {
      _isImporting = true;
      _message = null;
      _logs.clear();
      _resumo = null;
    });

    _adicionarLog('=== INICIANDO IMPORTACAO ===');
    _adicionarLog('Inventário: ${widget.nomeInventario} (ID: ${widget.inventarioId})');
    _adicionarLog('Arquivo: $_fileName');
    _adicionarLog('Modo: Importação automática de todas as colunas de CAP');

    try {
      final config = ImportacaoConfig(
        inventarioId: widget.inventarioId,
        nomeInventario: widget.nomeInventario,
        ano: DateTime.now().year,
      );

      final resultado = await _importService.processarArquivo(_selectedFile!, config);

      setState(() {
        _logs = _importService.logs;
        _success = resultado['sucesso'] as bool;

        if (_success) {
          _resumo = resultado['resumo'];
          final anosDetectados = resultado['anos_detectados'] as List<int>?;
          final totalAnos = anosDetectados?.length ?? 0;

          _message = 'Importação concluída com sucesso! '
              'Foram detectados e importados $totalAnos anos de dados CAP.';

          if (anosDetectados != null && anosDetectados.isNotEmpty) {
            _message = _message! + ' Anos: ${anosDetectados.join(', ')}';
          }

          _adicionarLog('=== IMPORTACAO CONCLUIDA COM SUCESSO ===');
          _adicionarLog('Total de anos detectados: $totalAnos');
          if (anosDetectados != null) {
            _adicionarLog('Anos: ${anosDetectados.join(', ')}');
          }
        } else {
          _message = resultado['erro'] as String;
          _adicionarLog('=== IMPORTACAO FALHOU ===');
        }
      });
    } catch (e) {
      setState(() {
        _message = 'Erro durante a importação: $e';
        _success = false;
        _logs = _importService.logs;
      });
      _adicionarLog('ERRO CRÍTICO: $e');
    } finally {
      setState(() {
        _isImporting = false;
      });
    }
  }

  void _clearSelection() {
    setState(() {
      _selectedFile = null;
      _fileName = null;
      _fileSize = 0;
      _filePathController.clear();
      _message = null;
      _logs.clear();
      _resumo = null;
    });
    _adicionarLog('Seleção de arquivo limpa');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Importar Dados',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.green.shade700,
        elevation: 4,
        shadowColor: Colors.black26,
        actions: [
          if (_logs.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.info),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Logs de Importação'),
                    content: Container(
                      width: double.maxFinite,
                      height: 400,
                      child: Scrollbar(
                        child: ListView.builder(
                          itemCount: _logs.length,
                          itemBuilder: (context, index) {
                            final log = _logs[index];
                            final isError = log.toLowerCase().contains('erro');
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Text(
                                log,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontFamily: 'Monospace',
                                  color: isError ? Colors.red.shade700 : Colors.black87,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Fechar'),
                      ),
                    ],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                );
              },
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
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Cabeçalho informativo
              _buildInfoHeader(),
              const SizedBox(height: 16),

              // Card de seleção de arquivo
              _buildFileInputCard(),
              const SizedBox(height: 16),

              // Card de formatos suportados
              _buildSupportedFormatsCard(),
              const SizedBox(height: 16),

              // Botão de importação
              _buildImportButton(),

              // Mensagem de status
              if (_message != null) _buildStatusMessage(),

              // Resumo
              if (_resumo != null) _buildResumoCard(),

              // Logs
              if (_logs.isNotEmpty) _buildLogsCard(),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoHeader() {
    return Card(
      elevation: 4,
      shadowColor: Colors.black26,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.forest, color: Colors.green.shade700),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Importação para: ${widget.nomeInventario}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.green.shade800,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Importe dados de árvores a partir de um arquivo CSV. O sistema detectará automaticamente todas as colunas de CAP (CAP_XXXX) e importará todos os dados históricos.',
              style: TextStyle(color: Colors.grey.shade700),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.auto_awesome, color: Colors.blue.shade700, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Detecção automática: Todos os anos de CAP serão importados',
                      style: TextStyle(fontSize: 12, color: Colors.blue.shade800),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFileInputCard() {
    return Card(
      elevation: 4,
      shadowColor: Colors.black26,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.file_upload, color: Colors.blue.shade700),
                const SizedBox(width: 8),
                Text(
                  '1. Selecionar Arquivo',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.blue.shade800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Escolha um arquivo CSV com os dados das árvores. O sistema detectará automaticamente todas as colunas de CAP (CAP_2020, CAP_2021, etc.) e importará todos os dados históricos.',
              style: TextStyle(color: Colors.grey.shade700),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: _isValidatingFile
                        ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                        : const Icon(Icons.folder_open),
                    label: Text(_isValidatingFile ? 'Selecionando...' : 'Selecionar Arquivo'),
                    onPressed: _isValidatingFile ? null : _pickFile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade700,
                      foregroundColor: Colors.white,
                      elevation: 4,
                      shadowColor: Colors.blue.shade700.withOpacity(0.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.file_copy),
                    label: const Text('Usar Exemplo'),
                    onPressed: _isValidatingFile ? null : _createSampleFile,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.orange.shade700,
                      side: BorderSide(color: Colors.orange.shade700),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.center,
              child: TextButton.icon(
                icon: const Icon(Icons.download, size: 16),
                label: const Text('Copiar dados.csv para Downloads'),
                onPressed: _isValidatingFile ? null : _copyAssetFileToDownload,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.blue.shade700,
                ),
              ),
            ),
            if (_fileName != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.shade700),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green.shade700),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Arquivo selecionado:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _fileName!,
                            style: TextStyle(fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Tamanho: ${_formatFileSize(_fileSize)}',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          ),
                          if (_fileName == 'dados.csv') ...[
                            const SizedBox(height: 2),
                            Text(
                              'Fonte: Arquivo interno do app',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.green.shade700,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.delete, color: Colors.red.shade700),
                      onPressed: _clearSelection,
                      tooltip: 'Remover arquivo',
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSupportedFormatsCard() {
    return Card(
      elevation: 4,
      shadowColor: Colors.black26,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.help, color: Colors.blue.shade700),
                const SizedBox(width: 8),
                Text(
                  'Formatos Suportados',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.blue.shade800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildFormatItem('CSV (.csv)', 'Arquivos de texto separados por vírgula'),
            _buildFormatItem('Excel (.xlsx, .xls)', 'Planilhas do Microsoft Excel'),
            _buildFormatItem('Texto (.txt)', 'Arquivos de texto simples'),
            const SizedBox(height: 8),
            Text(
              'Estrutura esperada: Bloco, Parcela, Faixa, Arvore, Codigo, X, Y, Familia, Nome_Cientifico, CAP_XXXX, HT, HC',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.auto_awesome, color: Colors.green.shade700, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'O sistema detectará automaticamente todas as colunas CAP_XXXX (CAP_2020, CAP_2021, etc.)',
                      style: TextStyle(fontSize: 12, color: Colors.green.shade800),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormatItem(String format, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_circle, color: Colors.green.shade700, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(format, style: TextStyle(fontWeight: FontWeight.w500)),
                Text(
                  description,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImportButton() {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton.icon(
        icon: _isImporting
            ? SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        )
            : const Icon(Icons.upload),
        label: Text(
          _isImporting ? 'Importando...' : 'Iniciar Importação Automática',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        onPressed: (_isImporting || _selectedFile == null) ? null : _importFile,
        style: ElevatedButton.styleFrom(
          backgroundColor: _selectedFile != null && !_isImporting
              ? Colors.green.shade700
              : Colors.grey.shade400,
          foregroundColor: Colors.white,
          elevation: 8,
          shadowColor: _selectedFile != null && !_isImporting
              ? Colors.green.shade700.withOpacity(0.5)
              : Colors.grey.shade400.withOpacity(0.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
        ),
      ),
    );
  }

  Widget _buildStatusMessage() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _success ? Colors.green.shade50 : Colors.red.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _success ? Colors.green.shade700 : Colors.red.shade700,
        ),
      ),
      child: Row(
        children: [
          Icon(
            _success ? Icons.check_circle : Icons.error,
            color: _success ? Colors.green.shade700 : Colors.red.shade700,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _success ? 'Sucesso!' : 'Atenção',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _success ? Colors.green.shade800 : Colors.red.shade800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _message!,
                  style: TextStyle(color: Colors.grey.shade800),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResumoCard() {
    return Card(
      elevation: 4,
      shadowColor: Colors.black26,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.only(top: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.summarize, color: Colors.green.shade700),
                const SizedBox(width: 8),
                Text(
                  'Resumo da Importação',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.green.shade800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildResumoItem('Árvores Processadas', _resumo!['total_arvores'].toString()),
            _buildResumoItem('Parcelas Afetadas', _resumo!['parcelas_afetadas'].toString()),
            _buildResumoItem('Novas Árvores', _resumo!['novas_arvores'].toString()),
            _buildResumoItem('Árvores Atualizadas', _resumo!['arvores_atualizadas'].toString()),
            if (_resumo!.containsKey('anos_detectados') && _resumo!['anos_detectados'] != null)
              _buildResumoItem('Anos Detectados', _resumo!['anos_detectados'].length.toString()),
            if (_resumo!['linhas_com_erro'] > 0)
              _buildResumoItem('Linhas com Erro', _resumo!['linhas_com_erro'].toString()),
          ],
        ),
      ),
    );
  }

  Widget _buildResumoItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: TextStyle(color: Colors.grey.shade700)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.green.shade800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogsCard() {
    return Card(
      elevation: 4,
      shadowColor: Colors.black26,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.only(top: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.list, color: Colors.blue.shade700),
                const SizedBox(width: 8),
                Text(
                  'Log de Processamento',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.blue.shade800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Detalhes do processamento do arquivo:',
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 12),
            Container(
              height: 200,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(12),
                color: Colors.grey.shade50,
              ),
              child: Scrollbar(
                child: ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: _logs.length,
                  itemBuilder: (context, index) {
                    final log = _logs[index];
                    final isError = log.toLowerCase().contains('erro') ||
                        log.toLowerCase().contains('error') ||
                        log.toLowerCase().contains('falha');

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(
                        log,
                        style: TextStyle(
                          fontSize: 12,
                          fontFamily: 'Monospace',
                          color: isError ? Colors.red.shade700 : Colors.black87,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}