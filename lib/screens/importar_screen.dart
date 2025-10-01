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
  int? _selectedYear;
  bool _isImporting = false;
  bool _isValidatingFile = false;
  String? _message;
  bool _success = false;
  List<String> _logs = [];
  Map<String, dynamic>? _resumo;
  int _fileSize = 0;

  void _pickFile() async {
    try {
      // Solicitar permissão de armazenamento
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

      // Carregar o arquivo CSV dos assets
      final String csvData = await rootBundle.loadString('assets/csv/dados.csv');

      final tempDir = await getTemporaryDirectory();
      final sampleFile = File('${tempDir.path}/dados.csv');

      // Escrever o conteúdo do asset no arquivo temporário
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

  // Método alternativo para copiar arquivo de assets para local acessível
  void _copyAssetFileToDownload() async {
    try {
      setState(() {
        _isValidatingFile = true;
        _message = null;
      });

      // Solicitar permissão
      PermissionStatus status = await Permission.storage.request();
      if (!status.isGranted) {
        setState(() {
          _message = 'Permissão de armazenamento necessária.';
          _success = false;
        });
        return;
      }

      // Carregar o arquivo CSV dos assets
      final ByteData data = await rootBundle.load('assets/csv/dados.csv');
      final List<int> bytes = data.buffer.asUint8List();

      // Obter diretório de Download
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

    if (_selectedYear == null) {
      setState(() {
        _message = 'Selecione o ano de referência para o CAP.';
        _success = false;
      });
      return;
    }

    // Verificar se o arquivo ainda existe
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
    _adicionarLog('Ano de referência: $_selectedYear');
    _adicionarLog('Arquivo: $_fileName');

    try {
      final config = ImportacaoConfig(
        inventarioId: widget.inventarioId,
        ano: _selectedYear!,
        nomeInventario: widget.nomeInventario,
      );

      final resultado = await _importService.processarArquivo(_selectedFile!, config);

      setState(() {
        _logs = _importService.logs;
        _success = resultado['sucesso'] as bool;

        if (_success) {
          _resumo = resultado['resumo'];
          _message = 'Importação concluída com sucesso!';
          _adicionarLog('=== IMPORTACAO CONCLUIDA COM SUCESSO ===');
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

  Widget _buildFileInput() {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '1. Selecionar Arquivo',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            SizedBox(height: 16),
            Text(
              'Escolha um arquivo CSV com os dados das árvores ou use nosso arquivo de exemplo para testar.',
              style: TextStyle(color: Colors.grey[700]),
            ),
            SizedBox(height: 16),
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
                        : Icon(Icons.folder_open),
                    label: Text(_isValidatingFile ? 'Selecionando...' : 'Selecionar Arquivo'),
                    onPressed: _isValidatingFile ? null : _pickFile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: Icon(Icons.file_copy),
                    label: Text('Usar Exemplo'),
                    onPressed: _isValidatingFile ? null : _createSampleFile,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.orange,
                      padding: EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Align(
              alignment: Alignment.center,
              child: TextButton.icon(
                icon: Icon(Icons.download, size: 16),
                label: Text('Copiar dados.csv para Downloads'),
                onPressed: _isValidatingFile ? null : _copyAssetFileToDownload,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.blue,
                ),
              ),
            ),
            if (_fileName != null) ...[
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Arquivo selecionado:',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 4),
                          Text(
                            _fileName!,
                            style: TextStyle(fontWeight: FontWeight.w500),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Tamanho: ${_formatFileSize(_fileSize)}',
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          ),
                          if (_fileName == 'dados.csv') ...[
                            SizedBox(height: 2),
                            Text(
                              'Fonte: Arquivo interno do app',
                              style: TextStyle(fontSize: 10, color: Colors.green[700], fontStyle: FontStyle.italic),
                            ),
                          ],
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.delete, color: Colors.red),
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

  Widget _buildSupportedFormats() {
    return Card(
      margin: EdgeInsets.all(16),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.help, color: Colors.blue),
                SizedBox(width: 8),
                Text(
                  'Formatos Suportados',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            SizedBox(height: 12),
            _buildFormatItem('CSV (.csv)', 'Arquivos de texto separados por vírgula'),
            _buildFormatItem('Excel (.xlsx, .xls)', 'Planilhas do Microsoft Excel'),
            _buildFormatItem('Texto (.txt)', 'Arquivos de texto simples'),
            SizedBox(height: 8),
            Text(
              'Estrutura esperada: Bloco, Parcela, Faixa, Arvore, Codigo, X, Y, Familia, Nome_Cientifico, CAP_XXXX, HT, HC',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormatItem(String format, String description) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_circle, color: Colors.green, size: 16),
          SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(format, style: TextStyle(fontWeight: FontWeight.w500)),
                Text(
                  description,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogs() {
    if (_logs.isEmpty) return SizedBox.shrink();

    return Card(
      margin: EdgeInsets.all(16),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.list, color: Colors.blue),
                SizedBox(width: 8),
                Text(
                  'Log de Processamento',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              'Detalhes do processamento do arquivo:',
              style: TextStyle(color: Colors.grey[600]),
            ),
            SizedBox(height: 12),
            Container(
              height: 200,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(4),
                color: Colors.grey[50],
              ),
              child: Scrollbar(
                child: ListView.builder(
                  padding: EdgeInsets.all(8),
                  itemCount: _logs.length,
                  itemBuilder: (context, index) {
                    final log = _logs[index];
                    final isError = log.toLowerCase().contains('erro') ||
                        log.toLowerCase().contains('error') ||
                        log.toLowerCase().contains('falha');

                    return Container(
                      padding: EdgeInsets.symmetric(vertical: 2, horizontal: 8),
                      color: isError ? Colors.red[50] : null,
                      child: Text(
                        log,
                        style: TextStyle(
                          fontSize: 12,
                          fontFamily: 'Monospace',
                          color: isError ? Colors.red : Colors.black,
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

  Widget _buildResumo() {
    if (_resumo == null) return SizedBox.shrink();

    return Card(
      margin: EdgeInsets.all(16),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.summarize, color: Colors.green),
                SizedBox(width: 8),
                Text(
                  'Resumo da Importação',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
            SizedBox(height: 12),
            _buildResumoItem('Árvores Processadas', _resumo!['total_arvores'].toString()),
            _buildResumoItem('Parcelas Afetadas', _resumo!['parcelas_afetadas'].toString()),
            _buildResumoItem('Novas Árvores', _resumo!['novas_arvores'].toString()),
            _buildResumoItem('Árvores Atualizadas', _resumo!['arvores_atualizadas'].toString()),
            if (_resumo!['linhas_com_erro'] > 0)
              _buildResumoItem('Linhas com Erro', _resumo!['linhas_com_erro'].toString()),
          ],
        ),
      ),
    );
  }

  Widget _buildResumoItem(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: TextStyle(color: Colors.grey[700])),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.green[50],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.green[800],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Importar Dados'),
        backgroundColor: Colors.blue,
        actions: [
          if (_logs.isNotEmpty)
            IconButton(
              icon: Icon(Icons.info),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text('Logs de Importação'),
                    content: Container(
                      width: double.maxFinite,
                      height: 400,
                      child: Scrollbar(
                        child: ListView.builder(
                          itemCount: _logs.length,
                          itemBuilder: (context, index) {
                            final log = _logs[index];
                            final isError = log.toLowerCase().contains('erro');
                            return Text(
                              log,
                              style: TextStyle(
                                fontSize: 12,
                                fontFamily: 'Monospace',
                                color: isError ? Colors.red : Colors.black,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text('Fechar'),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabeçalho informativo
            Card(
              margin: EdgeInsets.all(16),
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.forest, color: Colors.green),
                        SizedBox(width: 8),
                        Text(
                          'Importação para: ${widget.nomeInventario}',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Importe dados de árvores a partir de um arquivo CSV. O sistema converterá automaticamente CAP para DAP e organizará os dados por bloco, faixa e parcela.',
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                    SizedBox(height: 8),
                    Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info, color: Colors.blue, size: 16),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Arquivo de exemplo: dados.csv (já incluído no app)',
                              style: TextStyle(fontSize: 12, color: Colors.blue[800]),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Entrada do arquivo
            _buildFileInput(),

            // Formatos suportados
            _buildSupportedFormats(),

            // Seletor de ano
            Card(
              margin: EdgeInsets.all(16),
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '2. Selecione o ano de referência',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Informe o ano de referência para o CAP (Circunferência à Altura do Peito). Este ano será usado nos cálculos e relatórios.',
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                    SizedBox(height: 16),
                    DropdownButtonFormField<int>(
                      value: _selectedYear,
                      decoration: InputDecoration(
                        labelText: 'Ano para CAP',
                        border: OutlineInputBorder(),
                        helperText: 'O CAP será convertido para DAP automaticamente',
                      ),
                      items: List.generate(30, (index) {
                        int year = DateTime.now().year - 15 + index;
                        return DropdownMenuItem(
                          value: year,
                          child: Text('$year'),
                        );
                      }),
                      onChanged: (_isImporting || _isValidatingFile) ? null : (value) {
                        setState(() {
                          _selectedYear = value;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),

            // Botão de importação
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: _isImporting
                      ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                      : Icon(Icons.upload),
                  label: Text(_isImporting ? 'Importando...' : 'Iniciar Importação'),
                  onPressed: (_isImporting || _selectedFile == null || _selectedYear == null) ? null : _importFile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: (_selectedFile != null && _selectedYear != null && !_isImporting)
                        ? Colors.green
                        : Colors.grey,
                    padding: EdgeInsets.symmetric(vertical: 16),
                    textStyle: TextStyle(fontSize: 16),
                  ),
                ),
              ),
            ),

            // Mensagem de status
            if (_message != null)
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(16),
                margin: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _success ? Colors.green[50] : Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _success ? Colors.green : Colors.red,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _success ? Icons.check_circle : Icons.error,
                      color: _success ? Colors.green : Colors.red,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _success ? 'Sucesso!' : 'Atenção',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _success ? Colors.green : Colors.red,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(_message!),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

            // Resumo
            _buildResumo(),

            // Logs
            _buildLogs(),

            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}