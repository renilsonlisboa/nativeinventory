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
  final _fusteController = TextEditingController();
  final _xController = TextEditingController();
  final _yController = TextEditingController();
  final _familiaController = TextEditingController();
  final _nomeCientificoController = TextEditingController();
  final _nomePopularController = TextEditingController();
  final _dapController = TextEditingController();
  final _hcController = TextEditingController();
  final _anoHCController = TextEditingController();
  final _htController = TextEditingController();
  final _anoHTController = TextEditingController();
  final _observationController = TextEditingController();

  // Variável para o dropdown de código
  int? _selectedCodigo;
  int? _selectedFormaFuste;
  int? _selectedPosiSoc;
  int? _selectedFito;
  int? _selectedPosiCopa;
  int? _selectedFormaCopa;
  int? _selecteddataIngresso;
  int? _selectedinfoMorta;
  int? _selecteddataMorta;

  double _dapMinimo = 31.4;
  bool _dapAbaixoMinimo = false;
  int _anoInventario = DateTime.now().year;

  double? _capAnoAnterior;
  bool _capMenorQueAnoAnterior = false;

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
      _fusteController.text = widget.arvore!.numeroFuste.toString();
      _selectedCodigo = int.tryParse(widget.arvore!.codigo);
      _xController.text = widget.arvore!.x.toString();
      _yController.text = widget.arvore!.y.toString();
      _familiaController.text = widget.arvore!.familia;
      _nomeCientificoController.text = widget.arvore!.nomeCientifico;
      _familiaSelecionada = widget.arvore!.familia;
      _nomePopularController.text = widget.arvore!.nomePopular.toString();

      _hcController.text = widget.arvore!.hc.toString();
      _htController.text = widget.arvore!.ht.toString();

      _selectedFormaFuste = (widget.arvore!.formaFuste);
      _selectedPosiSoc = (widget.arvore!.posiSoc);
      _selectedFito = (widget.arvore!.fitossanidade);
      _selectedPosiCopa = (widget.arvore!.posiCopa);
      _selectedFormaCopa = (widget.arvore!.formaCopa);
    }else {
      _familiaController.text = 'N.I.';
      _nomeCientificoController.text = 'N.I.';
      _nomePopularController.text = 'N.I.';
    }
    _selecteddataIngresso = widget.arvore?.dataIngresso;
    _selectedinfoMorta = widget.arvore?.infoMorte ?? 0;
    _selecteddataMorta = widget.arvore?.dataMorte;

    // Guardar o CAP do ano anterior para comparação
    if (widget.arvore != null && widget.arvore!.cap > 0) {
      _capAnoAnterior = widget.arvore!.cap;
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
    if (_nomeCientificoFocusNode.hasFocus && _nomeCientificoController.text.isNotEmpty) {
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

    await dbHelper.ensureTaxonomiaTablesExist();

    final familias = await dbHelper.getFamilias(filtro: filtro);

    setState(() {
      _familiasFiltradas = familias;
      _mostrarSugestoesFamilia = _familiaFocusNode.hasFocus && filtro.isNotEmpty;
    });
  }

  Future<void> _filtrarEspecies() async {
    final filtro = _nomeCientificoController.text;

    final dbHelper = DatabaseHelper();

    // GARANTIR QUE AS TABELAS DE TAXONOMIA EXISTEM
    await dbHelper.ensureTaxonomiaTablesExist();

    List<String> especies;
    if (_familiaSelecionada.isEmpty) {
      // Busca global por espécies (independente da família)
      especies = await dbHelper.getEspecies(filtro: filtro);
    } else {
      // Busca restrita à família selecionada
      especies = await dbHelper.getEspeciesByFamilia(_familiaSelecionada, filtro: filtro);
    }

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

  void _selecionarEspecie(String especie) async {
    setState(() {
      _nomeCientificoController.text = especie;
      _mostrarSugestoesEspecie = false;
      _nomeCientificoFocusNode.unfocus();
    });

    // Buscar a família correspondente à espécie selecionada
    final dbHelper = DatabaseHelper();
    final familia = await dbHelper.getFamiliaByNomeCientifico(especie);
    if (familia != null && familia.isNotEmpty) {
      setState(() {
        _familiaController.text = familia;
        _familiaSelecionada = familia;
      });
    }
  }

  Future<void> _carregarDadosInventario() async {
    final inventario = await DatabaseHelper().getInventario(widget.inventarioId);
    if (inventario != null) {
      setState(() {
        _dapMinimo = inventario.dapMinimo * 3.14;
        _anoInventario = inventario.ano;
      });
    }
  }

  void _validarDAP(String value) {
    final dap = double.tryParse(value) ?? 0.0;
    setState(() {
      _dapAbaixoMinimo = dap < _dapMinimo && dap > 0;
      _capMenorQueAnoAnterior =
          _capAnoAnterior != null && dap > 0 && dap < _capAnoAnterior!;
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

  Future<void> _definirMorta() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar'),
        content: const Text('Tem certeza que deseja definir esta árvore como morta?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      if (_selectedinfoMorta == 0) {
        _selectedinfoMorta = 1;
        _selecteddataMorta = 2026;
      }
      _selectedinfoMorta = 0;
      _selecteddataMorta = null;
      print('teste');
    }
  }

  Future<void> _salvarArvore() async {
    if (_formKey.currentState!.validate()) {
      try {
        // CORREÇÃO: Usar conversões seguras
        final dapInserido = _parseDoubleSafe(_dapController.text);
        final cap = dapInserido;

        // Verificar se o DAP está abaixo do mínimo
        if (dapInserido < _dapMinimo) {
          final bool? confirmar = await _mostrarAvisoDapMinimo(dapInserido);
          if (confirmar != true) {
            return;
          }
        }

        // Verificar se o CAP atual é menor que o CAP do ano anterior
        if (_capAnoAnterior != null && dapInserido > 0 && dapInserido < _capAnoAnterior!) {
          final bool? confirmar = await _mostrarAvisoCapMenorAnoAnterior(dapInserido);
          if (confirmar != true) {
            return;
          }
        }

        // Verificar se o CAP atual é menor que o CAP do ano anterior
        if (_capAnoAnterior != null && dapInserido > 0 && (dapInserido - _capAnoAnterior!) > 8.0) {
          final bool? confirmar = await _mostrarAvisoCapMaiorLimite(dapInserido);
          if (confirmar != true) {
            return;
          }
        }

        final arvore = Arvore(
          id: widget.arvore?.id ?? 0,
          parcelaId: widget.parcelaId,
          numeroArvore: _parseIntSafe(_numeroController.text),
          numeroFuste: _parseIntSafe(_fusteController.text),
          codigo: _selectedCodigo?.toString() ?? '',
          x: _parseDoubleSafe(_xController.text),
          y: _parseDoubleSafe(_yController.text),
          familia: _familiaController.text,
          nomeCientifico: _nomeCientificoController.text,
          nomePopular: _nomePopularController.text,
          cap: cap,
          hc: _parseDoubleSafe(_hcController.text),
          anoHC: _parseIntSafe(_anoHCController.text),
          ht: _parseDoubleSafe(_htController.text),
          anoHT: _parseIntSafe(_anoHTController.text),
          formaFuste: _selectedFormaFuste,
          posiSoc: _selectedPosiSoc,
          fitossanidade: _selectedFito,
          formaCopa: _selectedFormaCopa,
          posiCopa: _selectedPosiCopa,
          dataIngresso: _selecteddataIngresso,
          infoMorte: _selectedinfoMorta,
          dataMorte: _selecteddataMorta,
          observation: _observationController.text,
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
              Text('CAP Abaixo do Mínimo'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('O CAP informado (${dapInserido.toStringAsFixed(1)} cm) é menor que o CAP mínimo do inventário (${_dapMinimo.toStringAsFixed(1)} cm).'),
              SizedBox(height: 7),
              Text(
                'Árvores com CAP abaixo do mínimo normalmente não são incluídas no inventário.',
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

  Future<bool?> _mostrarAvisoCapMenorAnoAnterior(double capAtual) async {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.trending_down, color: Colors.red.shade700),
              SizedBox(width: 8),
              Text('CAP Menor que Ano Anterior'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 120,
                width: double.maxFinite,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset(
                    'assets/images/aviso_cap.png',
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                  ),
                ),
              ),
              SizedBox(height: 12),
              Text(
                'O CAP informado (${capAtual.toStringAsFixed(1)} cm) é menor que o CAP registrado no inventário anterior (${_capAnoAnterior!.toStringAsFixed(1)} cm).',
              ),
              SizedBox(height: 8),
              Text(
                'Normalmente o CAP de uma árvore não diminui entre inventários. Isso pode indicar um erro de digitação.',
                style: TextStyle(fontStyle: FontStyle.italic),
              ),
              SizedBox(height: 8),
              Text('Deseja salvar mesmo assim?'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('Corrigir CAP'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700,
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

  Future<bool?> _mostrarAvisoCapMaiorLimite(double capAtual) async {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.trending_down, color: Colors.red.shade700),
              SizedBox(width: 8),
              Text('CAP maior que o limite definido'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 120,
                width: double.maxFinite,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset(
                    'assets/images/aviso_cap.png',
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                  ),
                ),
              ),
              SizedBox(height: 12),
              Text(
                'O CAP informado (${capAtual.toStringAsFixed(1)} cm) apresenta uma diferença maior que 8.0 cm em relação a medição anterior (${_capAnoAnterior!.toStringAsFixed(1)} cm).',
              ),
              SizedBox(height: 8),
              Text(
                'O CAP informado apresenta uma diferença maior que o limite de 8 cm definido para o período',
                style: TextStyle(fontStyle: FontStyle.italic),
              ),
              SizedBox(height: 8),
              Text('Deseja salvar mesmo assim?'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('Corrigir CAP'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700,
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
            hintText: 'Digite para buscar espécies...',
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
          _buildMensagemNenhumResultado(
            _familiaSelecionada.isEmpty
                ? 'Nenhuma espécie encontrada'
                : 'Nenhuma espécie encontrada para a família $_familiaSelecionada',
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
            icon: Icon(Icons.receipt),
            onPressed: _definirMorta,
          ),
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
                                  ? 'CAP abaixo do mínimo (${_dapMinimo.toStringAsFixed(1)} cm)'
                                  : 'CAP mínimo do inventário: ${_dapMinimo.toStringAsFixed(1)} cm',
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

                  // Card de aviso: CAP menor que ano anterior
                  if (_capAnoAnterior != null)
                    Card(
                      elevation: 4,
                      shadowColor: Colors.black26,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      color: _capMenorQueAnoAnterior
                          ? Colors.red.shade50
                          : Colors.blue.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Icon(
                              _capMenorQueAnoAnterior
                                  ? Icons.trending_down
                                  : Icons.history,
                              color: _capMenorQueAnoAnterior
                                  ? Colors.red.shade700
                                  : Colors.blue.shade700,
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _capMenorQueAnoAnterior
                                    ? 'CAP menor que o ano anterior (${_capAnoAnterior!.toStringAsFixed(1)} cm)'
                                    : 'CAP do inventário anterior: ${_capAnoAnterior!.toStringAsFixed(1)} cm',
                                style: TextStyle(
                                  color: _capMenorQueAnoAnterior
                                      ? Colors.red.shade800
                                      : Colors.blue.shade800,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  SizedBox(height: 16),

                  Card(
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
                            controller: _fusteController,
                            label: 'Número do Fuste',
                            icon: Icons.numbers,
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Por favor, insira o número do fuste';
                              }
                              final numero = _parseIntSafe(value);
                              if (numero <= 0) {
                                return 'Por favor, insira um número válido';
                              }
                              return null;
                            },
                          ),
                          SizedBox(height: 16),

                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.9),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: DropdownButtonFormField<int>(
                              value: _selectedCodigo,
                              decoration: InputDecoration(
                                labelText: 'Código / Tipo',
                                labelStyle: TextStyle(color: Colors.grey.shade700),
                                prefixIcon: Icon(Icons.tag, color: Colors.green.shade700),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                filled: true,
                                fillColor: Colors.transparent,
                                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              ),
                              items: const [
                                DropdownMenuItem(value: 0, child: Text('0 - Árvore Normal')),
                                DropdownMenuItem(value: 1, child: Text('1 - Bifurcada Principal')),
                                DropdownMenuItem(value: 2, child: Text('2 - Bifurcada Secundária')),
                                DropdownMenuItem(value: 3, child: Text('3 - Araucária Reg. Semente')),
                                DropdownMenuItem(value: 4, child: Text('4 - Araucária Reg. Brotação')),
                              ],
                              onChanged: (value) {
                                setState(() {
                                  _selectedCodigo = value;
                                });
                              },
                              validator: (value) {
                                if (value == null) {
                                  return 'Selecione um código';
                                }
                                return null;
                              },
                              icon: Icon(Icons.arrow_drop_down, color: Colors.green.shade700),
                              isExpanded: true,
                              dropdownColor: Colors.white,
                              style: TextStyle(color: Colors.black87, fontSize: 16),
                            ),
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
                            controller: _nomePopularController,
                            label: 'Nome Popular',
                            icon: Icons.pin_drop,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Por favor, insira o Nome Popular';
                              }
                              return null;
                            },
                          ),

                          SizedBox(height: 16),
                          _buildTextField(
                            controller: _dapController,
                            label: 'CAP (cm)',
                            icon: Icons.straighten,
                            keyboardType: TextInputType.numberWithOptions(decimal: true),
                            onChanged: _validarDAP,
                            errorText: _dapAbaixoMinimo ? 'CAP abaixo do mínimo' : null,
                            validator: (value) {

                              if (_selectedinfoMorta == 1 && (value == null || value.isEmpty)) {
                                return null; // válido
                              }

                              if (value == null || value.isEmpty) {
                                return 'Por favor, insira o CAP';
                              }
                              if (_parseDoubleSafe(value) == 0.0 && value != '0') {
                                return 'Por favor, insira um número válido';
                              }
                              return null;
                            },
                          ),
                          SizedBox(height: 16),

                          _buildTextField(
                            controller: _hcController,
                            label: 'HC (m)',
                            icon: Icons.height,
                            keyboardType: TextInputType.numberWithOptions(decimal: true),
                          ),

                          SizedBox(height: 16),

                          _buildTextField(
                            controller: _htController,
                            label: 'HT (m)',
                            icon: Icons.height,
                            keyboardType: TextInputType.numberWithOptions(decimal: true),
                          ),

                          SizedBox(height: 16),

                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.9),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: DropdownButtonFormField<int>(
                              value: _selectedFormaFuste,
                              decoration: InputDecoration(
                                labelText: 'Forma do Fuste',
                                labelStyle: TextStyle(color: Colors.grey.shade700),
                                prefixIcon: Icon(Icons.tag, color: Colors.green.shade700),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                filled: true,
                                fillColor: Colors.transparent,
                                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              ),
                              items: const [
                                DropdownMenuItem(value: 0, child: Text('0 - Não Atribuido')),
                                DropdownMenuItem(value: 1, child: Text('1 - Fuste Tortuoso')),
                                DropdownMenuItem(value: 2, child: Text('2 - Fuste Levemente Torturoso')),
                                DropdownMenuItem(value: 3, child: Text('3 - Fuste Reto')),
                              ],
                              onChanged: (value) {
                                setState(() {
                                  _selectedFormaFuste = value;
                                });
                              },
                              validator: (value) {
                                if (value == null) {
                                  return 'Selecione um código';
                                }
                                return null;
                              },
                              icon: Icon(Icons.arrow_drop_down, color: Colors.green.shade700),
                              isExpanded: true,
                              dropdownColor: Colors.white,
                              style: TextStyle(color: Colors.black87, fontSize: 16),
                            ),
                          ),
                          SizedBox(height: 16),

                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.9),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: DropdownButtonFormField<int>(
                              value: _selectedPosiSoc,
                              decoration: InputDecoration(
                                labelText: 'Estrato',
                                labelStyle: TextStyle(color: Colors.grey.shade700),
                                prefixIcon: Icon(Icons.tag, color: Colors.green.shade700),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                filled: true,
                                fillColor: Colors.transparent,
                                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              ),
                              items: const [
                                DropdownMenuItem(value: 0, child: Text('0 - Não Atribuido')),
                                DropdownMenuItem(value: 1, child: Text('1 - Estrato Inferior')),
                                DropdownMenuItem(value: 2, child: Text('2 - Estrato Médio')),
                                DropdownMenuItem(value: 3, child: Text('3 - Estrato Superior')),
                              ],
                              onChanged: (value) {
                                setState(() {
                                  _selectedPosiSoc = value;
                                });
                              },
                              validator: (value) {
                                if (value == null) {
                                  return 'Selecione um código';
                                }
                                return null;
                              },
                              icon: Icon(Icons.arrow_drop_down, color: Colors.green.shade700),
                              isExpanded: true,
                              dropdownColor: Colors.white,
                              style: TextStyle(color: Colors.black87, fontSize: 16),
                            ),
                          ),
                          SizedBox(height: 16),

                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.9),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: DropdownButtonFormField<int>(
                              value: _selectedFito,
                              decoration: InputDecoration(
                                labelText: 'Fitossanidade',
                                labelStyle: TextStyle(color: Colors.grey.shade700),
                                prefixIcon: Icon(Icons.tag, color: Colors.green.shade700),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                filled: true,
                                fillColor: Colors.transparent,
                                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              ),
                              items: const [
                                DropdownMenuItem(value: 0, child: Text('0 - Não Atribuido')),
                                DropdownMenuItem(value: 1, child: Text('1 - Fitossanidade Ruim')),
                                DropdownMenuItem(value: 2, child: Text('2 - Fitossanidade Média')),
                                DropdownMenuItem(value: 3, child: Text('3 - Fitossanidade Boa')),
                              ],
                              onChanged: (value) {
                                setState(() {
                                  _selectedFito = value;
                                });
                              },
                              validator: (value) {
                                if (value == null) {
                                  return 'Selecione um código';
                                }
                                return null;
                              },
                              icon: Icon(Icons.arrow_drop_down, color: Colors.green.shade700),
                              isExpanded: true,
                              dropdownColor: Colors.white,
                              style: TextStyle(color: Colors.black87, fontSize: 16),
                            ),
                          ),

                          SizedBox(height: 16),

                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.9),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: DropdownButtonFormField<int>(
                              value: _selectedPosiCopa,
                              decoration: InputDecoration(
                                labelText: 'Posição da Copa',
                                labelStyle: TextStyle(color: Colors.grey.shade700),
                                prefixIcon: Icon(Icons.tag, color: Colors.green.shade700),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                filled: true,
                                fillColor: Colors.transparent,
                                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              ),
                              items: const [
                                DropdownMenuItem(value: 0, child: Text('0 - Não Atribuido')),
                                DropdownMenuItem(value: 1, child: Text('1 - Sem Iluminação Direta')),
                                DropdownMenuItem(value: 2, child: Text('2 - Alguma Iluminação Natural')),
                                DropdownMenuItem(value: 3, child: Text('3 - Iluminação Superior Parcial')),
                                DropdownMenuItem(value: 4, child: Text('4 - Iluminação Superior Completa')),
                                DropdownMenuItem(value: 5, child: Text('5 - Emergente')),
                              ],
                              onChanged: (value) {
                                setState(() {
                                  _selectedPosiCopa = value;
                                });
                              },
                              validator: (value) {
                                if (value == null) {
                                  return 'Selecione um código';
                                }
                                return null;
                              },
                              icon: Icon(Icons.arrow_drop_down, color: Colors.green.shade700),
                              isExpanded: true,
                              dropdownColor: Colors.white,
                              style: TextStyle(color: Colors.black87, fontSize: 16),
                            ),
                          ),
                          SizedBox(height: 16),

                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.9),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: DropdownButtonFormField<int>(
                              value: _selectedFormaCopa,
                              decoration: InputDecoration(
                                labelText: 'Forma da Copa',
                                labelStyle: TextStyle(color: Colors.grey.shade700),
                                prefixIcon: Icon(Icons.tag, color: Colors.green.shade700),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                filled: true,
                                fillColor: Colors.transparent,
                                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              ),
                              items: const [
                                DropdownMenuItem(value: 0, child: Text('0 - Não Atribuido')),
                                DropdownMenuItem(value: 1, child: Text('1 - Forma Intolerável')),
                                DropdownMenuItem(value: 2, child: Text('2 - Forma Pobre')),
                                DropdownMenuItem(value: 3, child: Text('3 - Forma Tolerável')),
                                DropdownMenuItem(value: 4, child: Text('4 - Boa Forma')),
                                DropdownMenuItem(value: 5, child: Text('5 - Forma Perfeita')),
                              ],
                              onChanged: (value) {
                                setState(() {
                                  _selectedFormaCopa = value;
                                });
                              },
                              validator: (value) {
                                if (value == null) {
                                  return 'Selecione um código';
                                }
                                return null;
                              },
                              icon: Icon(Icons.arrow_drop_down, color: Colors.green.shade700),
                              isExpanded: true,
                              dropdownColor: Colors.white,
                              style: TextStyle(color: Colors.black87, fontSize: 16),
                            ),
                          ),
                          SizedBox(height: 16),

                          _buildTextField(
                            controller: _observationController,
                            label: 'Observações',
                            icon: Icons.numbers,
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
        contentPadding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
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