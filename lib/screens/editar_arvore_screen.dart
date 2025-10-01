import 'package:flutter/material.dart';
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

  // Listas para armazenar os valores únicos
  List<String> _familiasUnicas = [];
  List<String> _nomesCientificosUnicos = [];
  bool _carregandoOpcoes = true;

  // Controladores para o autocomplete
  final _familiaFocusNode = FocusNode();
  final _nomeCientificoFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _carregarDapMinimo();
    _carregarOpcoesUnicas();

    if (widget.arvore != null) {
      _numeroController.text = widget.arvore!.numeroArvore.toString();
      _codigoController.text = widget.arvore!.codigo;
      _xController.text = widget.arvore!.x.toString();
      _yController.text = widget.arvore!.y.toString();
      _familiaController.text = widget.arvore!.familia;
      _nomeCientificoController.text = widget.arvore!.nomeCientifico;
      _dapController.text = widget.arvore!.dap.toString();
      _htController.text = widget.arvore!.ht.toString();
    }
  }

  Future<void> _carregarDapMinimo() async {
    final inventario = await DatabaseHelper().getInventario(widget.inventarioId);
    if (inventario != null) {
      setState(() {
        _dapMinimo = inventario.dapMinimo;
      });
    }
  }

  Future<void> _carregarOpcoesUnicas() async {
    try {
      final dbHelper = DatabaseHelper();
      final familias = await dbHelper.getFamiliasUnicas();
      final nomes = await dbHelper.getNomesCientificosUnicos();

      setState(() {
        _familiasUnicas = familias;
        _nomesCientificosUnicos = nomes;
        _carregandoOpcoes = false;
      });
    } catch (e) {
      setState(() {
        _carregandoOpcoes = false;
      });
    }
  }

  void _validarDAP(String value) {
    final dap = double.tryParse(value) ?? 0.0;
    setState(() {
      _dapAbaixoMinimo = dap < _dapMinimo && dap > 0;
    });
  }

  Future<void> _salvarArvore() async {
    if (_formKey.currentState!.validate()) {
      final dapInserido = double.parse(_dapController.text);

      // Verificar se o DAP está abaixo do mínimo
      if (dapInserido < _dapMinimo) {
        final bool? confirmar = await _mostrarAvisoDapMinimo(dapInserido);
        if (confirmar != true) {
          return; // Usuário cancelou
        }
      }

      final arvore = Arvore(
        id: widget.arvore?.id,
        parcelaId: widget.parcelaId,
        numeroArvore: int.parse(_numeroController.text),
        codigo: _codigoController.text,
        x: double.parse(_xController.text),
        y: double.parse(_yController.text),
        familia: _familiaController.text,
        nomeCientifico: _nomeCientificoController.text,
        dap: dapInserido,
        ht: double.parse(_htController.text),
      );

      final dbHelper = DatabaseHelper();
      if (widget.arvore == null) {
        await dbHelper.insertArvore(arvore);
      } else {
        await dbHelper.updateArvore(arvore);
      }

      Navigator.pop(context, true);
    }
  }

  Future<bool?> _mostrarAvisoDapMinimo(double dapInserido) async {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.warning, color: Colors.orange),
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
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text('Salvar Mesmo Assim'),
            ),
          ],
        );
      },
    );
  }

  // Widget personalizado para campo com sugestões - CORRIGIDO
  Widget _buildCampoComSugestoes({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String label,
    required List<String> sugestoes,
    required IconData icone,
    bool carregando = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: controller,
          focusNode: focusNode,
          decoration: InputDecoration(
            labelText: label,
            border: OutlineInputBorder(),
            suffixIcon: Icon(Icons.arrow_drop_down),
            prefixIcon: Icon(icone),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Por favor, insira $label';
            }
            return null;
          },
        ),
        if (focusNode.hasFocus && controller.text.isNotEmpty)
          _buildListaSugestoes(controller, focusNode, sugestoes, carregando),
      ],
    );
  }

  // MÉTODO CORRIGIDO - Agora recebe o focusNode como parâmetro
  Widget _buildListaSugestoes(
      TextEditingController controller,
      FocusNode focusNode, // Parâmetro adicionado
      List<String> sugestoes,
      bool carregando,
      ) {
    final sugestoesFiltradas = sugestoes
        .where((sugestao) =>
        sugestao.toLowerCase().contains(controller.text.toLowerCase()))
        .toList();

    if (carregando) {
      return Card(
        child: ListTile(
          leading: CircularProgressIndicator(strokeWidth: 2),
          title: Text('Carregando opções...'),
        ),
      );
    }

    if (sugestoesFiltradas.isEmpty) {
      return Card(
        child: ListTile(
          leading: Icon(Icons.search_off, color: Colors.grey),
          title: Text('Nenhuma opção encontrada'),
          subtitle: Text('Digite para buscar ou adicione um novo valor'),
        ),
      );
    }

    return Card(
      elevation: 4,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: 200),
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: sugestoesFiltradas.length,
          itemBuilder: (context, index) {
            final sugestao = sugestoesFiltradas[index];
            return ListTile(
              leading: Icon(Icons.check, color: Colors.green, size: 20),
              title: Text(sugestao),
              onTap: () {
                controller.text = sugestao;
                focusNode.unfocus(); // Agora o focusNode está disponível
              },
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.arvore == null ? 'Nova Árvore' : 'Editar Árvore'),
        backgroundColor: Colors.green,
        actions: [
          IconButton(
            icon: Icon(Icons.save),
            onPressed: _salvarArvore,
          ),
        ],
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // Indicador de DAP mínimo
              Card(
                color: _dapAbaixoMinimo ? Colors.orange[50] : Colors.green[50],
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(
                        _dapAbaixoMinimo ? Icons.warning : Icons.info,
                        color: _dapAbaixoMinimo ? Colors.orange : Colors.green,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _dapAbaixoMinimo
                              ? 'DAP abaixo do mínimo (${_dapMinimo} cm)'
                              : 'DAP mínimo do inventário: ${_dapMinimo} cm',
                          style: TextStyle(
                            color: _dapAbaixoMinimo ? Colors.orange[800] : Colors.green[800],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 16),

              TextFormField(
                controller: _numeroController,
                decoration: InputDecoration(
                  labelText: 'Número da Árvore',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor, insira o número da árvore';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _codigoController,
                decoration: InputDecoration(
                  labelText: 'Código',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor, insira o código';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _xController,
                decoration: InputDecoration(
                  labelText: 'Coordenada X',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor, insira a coordenada X';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _yController,
                decoration: InputDecoration(
                  labelText: 'Coordenada Y',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor, insira a coordenada Y';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),

              // CAMPO FAMÍLIA COM SUGESTÕES
              _buildCampoComSugestoes(
                controller: _familiaController,
                focusNode: _familiaFocusNode,
                label: 'Família',
                sugestoes: _familiasUnicas,
                icone: Icons.category,
                carregando: _carregandoOpcoes,
              ),
              SizedBox(height: 16),

              // CAMPO NOME CIENTÍFICO COM SUGESTÕES
              _buildCampoComSugestoes(
                controller: _nomeCientificoController,
                focusNode: _nomeCientificoFocusNode,
                label: 'Nome Científico',
                sugestoes: _nomesCientificosUnicos,
                icone: Icons.eco,
                carregando: _carregandoOpcoes,
              ),
              SizedBox(height: 16),

              TextFormField(
                controller: _dapController,
                decoration: InputDecoration(
                  labelText: 'DAP (cm)',
                  border: OutlineInputBorder(),
                  errorText: _dapAbaixoMinimo ? 'DAP abaixo do mínimo' : null,
                  suffixText: 'cm',
                ),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                onChanged: _validarDAP,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor, insira o DAP';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Por favor, insira um número válido';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _htController,
                decoration: InputDecoration(
                  labelText: 'HT',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor, insira o HT';
                  }
                  return null;
                },
              ),
              SizedBox(height: 24),
              ElevatedButton(
                onPressed: _salvarArvore,
                child: Text('Salvar Árvore'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _familiaFocusNode.dispose();
    _nomeCientificoFocusNode.dispose();
    super.dispose();
  }
}