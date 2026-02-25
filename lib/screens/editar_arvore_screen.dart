import 'package:flutter/material.dart';
import 'dart:async';
import '../models/arvore.dart';
import '../database/database_helper.dart';

class EditarArvoreScreen extends StatefulWidget {
  final int parcelaId;
  final int inventarioId;
  final Arvore? arvore;

  const EditarArvoreScreen({
    Key? key,
    required this.parcelaId,
    required this.inventarioId,
    this.arvore,
  }) : super(key: key);

  @override
  _EditarArvoreScreenState createState() => _EditarArvoreScreenState();
}

class _EditarArvoreScreenState extends State<EditarArvoreScreen> {
  final _formKey = GlobalKey<FormState>();
  final _numeroController = TextEditingController();
  final _codigoController = TextEditingController();
  final _xController = TextEditingController();
  final _yController = TextEditingController();
  final _familiaController = TextEditingController();
  final _nomeCientificoController = TextEditingController();
  final _dapController = TextEditingController();
  final _htController = TextEditingController();

  double _dapMinimo = 10.0;
  bool _dapAbaixoMinimo = false;
  int _anoInventario = DateTime.now().year;

  // Variáveis para o sistema de taxonomia
  List<String> _familiasFiltradas = [];
  List<String> _especiesFiltradas = [];
  bool _mostrarSugestoesFamilia = false;
  bool _mostrarSugestoesEspecie = false;
  String _familiaSelecionada = '';
  Timer? _debounceTimer;

  // Controladores para os campos
  final _familiaFocusNode = FocusNode();
  final _nomeCientificoFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _carregarDadosInventario();
    _configurarListeners();

    if (widget.arvore != null) {
      _numeroController.text = widget.arvore!.numeroArvore.toString();
      _codigoController.text = widget.arvore!.codigo;
      _xController.text = widget.arvore!.x.toString();
      _yController.text = widget.arvore!.y.toString();
      _familiaController.text = widget.arvore!.familia;
      _nomeCientificoController.text = widget.arvore!.nomeCientifico;

      // CORREÇÃO: Converter CAP para DAP (CAP = DAP * π)
      final dap = widget.arvore!.cap / 3.14159;
      _dapController.text = dap.toStringAsFixed(2);

      _htController.text = widget.arvore!.ht.toString();

      _familiaSelecionada = widget.arvore!.familia;
    }
  }

  void _configurarListeners() {
    _familiaController.addListener(_onFamiliaChanged);
    _nomeCientificoController.addListener(_onEspecieChanged);
    _familiaFocusNode.addListener(_onFamiliaFocusChanged);
    _nomeCientificoFocusNode.addListener(_onEspecieFocusChanged);
  }

  void _onFamiliaChanged() {
    if (_debounceTimer?.isActive ?? false) _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _filtrarFamilias();
    });
  }

  void _onEspecieChanged() {
    if (_debounceTimer?.isActive ?? false) _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _filtrarEspecies();
    });
  }

  void _onFamiliaFocusChanged() {
    if (_familiaFocusNode.hasFocus) {
      _filtrarFamilias();
      setState(() {
        _mostrarSugestoesFamilia = true;
      });
    } else {
      setState(() {
        _mostrarSugestoesFamilia = false;
      });
    }
  }

  void _onEspecieFocusChanged() {
    if (_nomeCientificoFocusNode.hasFocus && _familiaSelecionada.isNotEmpty) {
      _filtrarEspecies();
      setState(() {
        _mostrarSugestoesEspecie = true;
      });
    } else {
      setState(() {
        _mostrarSugestoesEspecie = false;
      });
    }
  }

  Future<void> _filtrarFamilias() async {
    final filtro = _familiaController.text;
    final dbHelper = DatabaseHelper();

    // GARANTIR QUE AS TABELAS DE TAXONOMIA EXISTEM
    await dbHelper.ensureTaxonomiaTablesExist();

    final familias = await dbHelper.getFamilias(filtro: filtro);

    setState(() {
      _familiasFiltradas = familias;
      _mostrarSugestoesFamilia = _familiaFocusNode.hasFocus && filtro.isNotEmpty;
    });
  }

  Future<void> _filtrarEspecies() async {
    final filtro = _nomeCientificoController.text;

    if (_familiaSelecionada.isEmpty) {
      setState(() {
        _especiesFiltradas = [];
        _mostrarSugestoesEspecie = false;
      });
      return;
    }

    final dbHelper = DatabaseHelper();

    // GARANTIR QUE AS TABELAS DE TAXONOMIA EXISTEM
    await dbHelper.ensureTaxonomiaTablesExist();

    final especies = await dbHelper.getEspeciesByFamilia(_familiaSelecionada, filtro: filtro);

    setState(() {
      _especiesFiltradas = especies;
      _mostrarSugestoesEspecie = _nomeCientificoFocusNode.hasFocus && filtro.isNotEmpty;
    });
  }

  void _selecionarFamilia(String familia) {
    setState(() {
      _familiaController.text = familia;
      _familiaSelecionada = familia;
      _mostrarSugestoesFamilia = false;
      _familiaFocusNode.unfocus();

      // Limpar espécie quando mudar a família
      _nomeCientificoController.clear();
      _especiesFiltradas = [];

      // Focar no campo de espécie
      WidgetsBinding.instance.addPostFrameCallback((_) {
        FocusScope.of(context).requestFocus(_nomeCientificoFocusNode);
      });
    });
  }

  void _selecionarEspecie(String especie) {
    setState(() {
      _nomeCientificoController.text = especie;
      _mostrarSugestoesEspecie = false;
      _nomeCientificoFocusNode.unfocus();
    });
  }

  Future<void> _carregarDadosInventario() async {
    final inventario = await DatabaseHelper().getInventario(widget.inventarioId);
    if (inventario != null) {
      setState(() {
        _dapMinimo = inventario.dapMinimo;
        _anoInventario = inventario.ano;
      });
    }
  }

  void _validarDAP(String value) {
    final dap = double.tryParse(value) ?? 0.0;
    setState(() {
      _dapAbaixoMinimo = dap < _dapMinimo && dap > 0;
    });
  }

  // CORREÇÃO: Função auxiliar para conversão segura de tipos
  int _parseIntSafe(String value) {
    // Tenta converter para double primeiro, depois arredonda para int
    final parsed = double.tryParse(value);
    if (parsed == null) {
      return 0;
    }
    return parsed.round();
  }

  double _parseDoubleSafe(String value) {
    return double.tryParse(value) ?? 0.0;
  }

  Future<void> _salvarArvore() async {
    if (_formKey.currentState!.validate()) {
      try {
        // CORREÇÃO: Usar conversões seguras
        final dapInserido = _parseDoubleSafe(_dapController.text);
        final cap = dapInserido * 3.14159; // Converter DAP para CAP

        // Verificar se o DAP está abaixo do mínimo
        if (dapInserido < _dapMinimo) {
          final bool? confirmar = await _mostrarAvisoDapMinimo(dapInserido);
          if (confirmar != true) {
            return;
          }
        }

        // CORREÇÃO: Usar funções de conversão segura
        final arvore = Arvore(
          id: widget.arvore?.id ?? 0,
          parcelaId: widget.parcelaId,
          numeroArvore: _parseIntSafe(_numeroController.text),
          codigo: _codigoController.text,
          x: _parseDoubleSafe(_xController.text),
          y: _parseDoubleSafe(_yController.text),
          familia: _familiaController.text,
          nomeCientifico: _nomeCientificoController.text,
          cap: cap,
          hc: 0.0,
          ht: _parseDoubleSafe(_htController.text),
        );

        final dbHelper = DatabaseHelper();

        int arvoreId;
        if (widget.arvore == null) {
          arvoreId = await dbHelper.insertArvore(arvore);
        } else {
          arvoreId = arvore.id;
          await dbHelper.updateArvore(arvore);
        }

        // Salvar o CAP no histórico
        await dbHelper.inserirOuAtualizarCapHistorico(arvoreId, _anoInventario, cap);

        Navigator.pop(context, true);
      } catch (e) {
        print('❌ Erro ao salvar árvore: $e');
        _mostrarErro('Erro ao salvar árvore: $e');
      }
    }
  }

  void _mostrarErro(String mensagem) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensagem),
        backgroundColor: Colors.red.shade700,
        duration: Duration(seconds: 3),
      ),
    );
  }

  Future<bool?> _mostrarAvisoDapMinimo(double dapInserido) async {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.warning, color: Colors.orange.shade700),
              SizedBox(width: 8),
              Text('DAP Abaixo do Mínimo'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('O DAP informado (${dapInserido.toStringAsFixed(1)} cm) é menor que o DAP mínimo do inventário (${_dapMinimo.toStringAsFixed(1)} cm).'),
              SizedBox(height: 8),
              Text(
                'Árvores com DAP abaixo do mínimo normalmente não são incluídas no inventário.',
                style: TextStyle(fontStyle: FontStyle.italic),
              ),
              SizedBox(height: 8),
              Text('Deseja salvar mesmo assim?'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('Corrigir DAP'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange.shade700,
                foregroundColor: Colors.white,
              ),
              child: Text('Salvar Mesmo Assim'),
            ),
          ],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        );
      },
    );
  }

  Widget _buildCampoFamilia() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _familiaController,
          focusNode: _familiaFocusNode,
          decoration: InputDecoration(
            labelText: 'Família Botânica',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.green.shade700, width: 2),
            ),
            suffixIcon: Icon(Icons.arrow_drop_down, color: Colors.green.shade700),
            prefixIcon: Icon(Icons.category, color: Colors.green.shade700),
            hintText: 'Digite para buscar famílias...',
            filled: true,
            fillColor: Colors.white.withOpacity(0.9),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Por favor, selecione a família';
            }
            return null;
          },
        ),
        if (_mostrarSugestoesFamilia && _familiasFiltradas.isNotEmpty)
          _buildListaSugestoes(
            _familiasFiltradas,
            _selecionarFamilia,
            icone: Icons.category,
          ),
        if (_mostrarSugestoesFamilia && _familiasFiltradas.isEmpty && _familiaController.text.isNotEmpty)
          _buildMensagemNenhumResultado('Nenhuma família encontrada'),
      ],
    );
  }

  Widget _buildCampoEspecie() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _nomeCientificoController,
          focusNode: _nomeCientificoFocusNode,
          enabled: _familiaSelecionada.isNotEmpty,
          decoration: InputDecoration(
            labelText: 'Espécie Botânica',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.green.shade700, width: 2),
            ),
            suffixIcon: Icon(Icons.arrow_drop_down, color: Colors.green.shade700),
            prefixIcon: Icon(Icons.eco, color: Colors.green.shade700),
            hintText: _familiaSelecionada.isEmpty
                ? 'Selecione primeiro a família'
                : 'Digite para buscar espécies...',
            filled: true,
            fillColor: Colors.white.withOpacity(0.9),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Por favor, selecione a espécie';
            }
            return null;
          },
        ),
        if (_mostrarSugestoesEspecie && _especiesFiltradas.isNotEmpty)
          _buildListaSugestoes(
            _especiesFiltradas,
            _selecionarEspecie,
            icone: Icons.eco,
          ),
        if (_mostrarSugestoesEspecie && _especiesFiltradas.isEmpty && _nomeCientificoController.text.isNotEmpty)
          _buildMensagemNenhumResultado('Nenhuma espécie encontrada para a família $_familiaSelecionada'),
        if (_familiaSelecionada.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Text(
              'Selecione uma família primeiro',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildListaSugestoes(List<String> sugestoes, Function(String) onSelecionar, {IconData? icone}) {
    return Card(
      elevation: 4,
      shadowColor: Colors.black26,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      margin: EdgeInsets.only(top: 4),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: 200),
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: sugestoes.length,
          itemBuilder: (context, index) {
            final sugestao = sugestoes[index];
            return ListTile(
              leading: Icon(icone ?? Icons.check, color: Colors.green.shade700, size: 20),
              title: Text(sugestao),
              onTap: () => onSelecionar(sugestao),
            );
          },
        ),
      ),
    );
  }

  Widget _buildMensagemNenhumResultado(String mensagem) {
    return Card(
      elevation: 2,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      margin: EdgeInsets.only(top: 4),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            Icon(Icons.search_off, color: Colors.grey.shade600, size: 20),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                mensagem,
                style: TextStyle(color: Colors.grey.shade700),
              ),
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
        title: Text(
          widget.arvore == null ? 'Nova Árvore' : 'Editar Árvore',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.green.shade700,
        elevation: 4,
        shadowColor: Colors.black26,
        actions: [
          IconButton(
            icon: Icon(Icons.save),
            onPressed: _salvarArvore,
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
        child: GestureDetector(
          onTap: () {
            // Fechar sugestões ao tocar fora
            setState(() {
              _mostrarSugestoesFamilia = false;
              _mostrarSugestoesEspecie = false;
            });
            FocusScope.of(context).unfocus();
          },
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  // Card de Ano do Inventário
                  Card(
                    elevation: 4,
                    shadowColor: Colors.black26,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today, color: Colors.blue.shade700),
                          SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Inventário $_anoInventario',
                                  style: TextStyle(
                                    color: Colors.blue.shade800,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Medições serão salvas como: CAP_$_anoInventario, HT_$_anoInventario',
                                  style: TextStyle(
                                    color: Colors.blue.shade700,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 16),

                  // Card de DAP mínimo
                  Card(
                    elevation: 4,
                    shadowColor: Colors.black26,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    color: _dapAbaixoMinimo ? Colors.orange.shade50 : Colors.green.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Icon(
                            _dapAbaixoMinimo ? Icons.warning : Icons.info,
                            color: _dapAbaixoMinimo ? Colors.orange.shade700 : Colors.green.shade700,
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _dapAbaixoMinimo
                                  ? 'DAP abaixo do mínimo (${_dapMinimo} cm)'
                                  : 'DAP mínimo do inventário: ${_dapMinimo} cm',
                              style: TextStyle(
                                color: _dapAbaixoMinimo ? Colors.orange.shade800 : Colors.green.shade800,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 16),

                  // Campos do formulário (agrupados em um card)
                  Card(
                    elevation: 4,
                    shadowColor: Colors.black26,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          _buildTextField(
                            controller: _numeroController,
                            label: 'Número da Árvore',
                            icon: Icons.numbers,
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Por favor, insira o número da árvore';
                              }
                              final numero = _parseIntSafe(value);
                              if (numero <= 0) {
                                return 'Por favor, insira um número válido';
                              }
                              return null;
                            },
                          ),
                          SizedBox(height: 16),

                          _buildTextField(
                            controller: _codigoController,
                            label: 'Código',
                            icon: Icons.tag,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Por favor, insira o código';
                              }
                              return null;
                            },
                          ),
                          SizedBox(height: 16),

                          _buildTextField(
                            controller: _xController,
                            label: 'Coordenada X',
                            icon: Icons.pin_drop,
                            keyboardType: TextInputType.numberWithOptions(decimal: true),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Por favor, insira a coordenada X';
                              }
                              if (_parseDoubleSafe(value) == 0.0 && value != '0') {
                                return 'Por favor, insira um número válido';
                              }
                              return null;
                            },
                          ),
                          SizedBox(height: 16),

                          _buildTextField(
                            controller: _yController,
                            label: 'Coordenada Y',
                            icon: Icons.pin_drop,
                            keyboardType: TextInputType.numberWithOptions(decimal: true),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Por favor, insira a coordenada Y';
                              }
                              if (_parseDoubleSafe(value) == 0.0 && value != '0') {
                                return 'Por favor, insira um número válido';
                              }
                              return null;
                            },
                          ),
                          SizedBox(height: 16),

                          // CAMPOS COM SUGESTÕES DA TAXONOMIA
                          _buildCampoFamilia(),
                          SizedBox(height: 16),

                          _buildCampoEspecie(),
                          SizedBox(height: 16),

                          _buildTextField(
                            controller: _dapController,
                            label: 'DAP (cm)',
                            icon: Icons.straighten,
                            keyboardType: TextInputType.numberWithOptions(decimal: true),
                            onChanged: _validarDAP,
                            errorText: _dapAbaixoMinimo ? 'DAP abaixo do mínimo' : null,
                            helperText: 'Será convertido para CAP automaticamente',
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Por favor, insira o DAP';
                              }
                              if (_parseDoubleSafe(value) == 0.0 && value != '0') {
                                return 'Por favor, insira um número válido';
                              }
                              return null;
                            },
                          ),
                          SizedBox(height: 16),

                          _buildTextField(
                            controller: _htController,
                            label: 'HT (m)',
                            icon: Icons.height,
                            keyboardType: TextInputType.numberWithOptions(decimal: true),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Por favor, insira o HT';
                              }
                              if (_parseDoubleSafe(value) == 0.0 && value != '0') {
                                return 'Por favor, insira um número válido';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 24),

                  // Botão Salvar
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton.icon(
                      onPressed: _salvarArvore,
                      icon: Icon(Icons.save, size: 24),
                      label: Text(
                        'Salvar Árvore',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade700,
                        foregroundColor: Colors.white,
                        elevation: 8,
                        shadowColor: Colors.green.shade700.withOpacity(0.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        padding: EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Método auxiliar para campos de texto padronizados
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
    String? errorText,
    String? helperText,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey.shade700),
        prefixIcon: Icon(icon, color: Colors.green.shade700),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.green.shade700, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.red.shade700),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.red.shade700, width: 2),
        ),
        errorText: errorText,
        helperText: helperText,
        helperStyle: TextStyle(color: Colors.grey.shade600, fontSize: 12),
        filled: true,
        fillColor: Colors.white.withOpacity(0.9),
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      keyboardType: keyboardType,
      validator: validator,
      onChanged: onChanged,
    );
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _familiaFocusNode.dispose();
    _nomeCientificoFocusNode.dispose();
    super.dispose();
  }
}