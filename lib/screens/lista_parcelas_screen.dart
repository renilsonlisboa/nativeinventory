import 'package:flutter/material.dart';
import '../models/parcela.dart';
import '../database/database_helper.dart';
import 'editar_parcela_screen.dart';
import 'tabela_arvores_screen.dart';

class ListaParcelasScreen extends StatefulWidget {
  final int inventarioId;

  const ListaParcelasScreen({Key? key, required this.inventarioId}) : super(key: key);

  @override
  _ListaParcelasScreenState createState() => _ListaParcelasScreenState();
}

class _ListaParcelasScreenState extends State<ListaParcelasScreen> {
  List<Parcela> _todasParcelas = [];
  List<Parcela> _parcelasFiltradas = [];
  bool _carregando = true;
  bool _mostrarFiltros = false; // controle para mostrar/ocultar filtros

  // Filtros
  int? _filtroBloco;
  int? _filtroParcela;
  int? _filtroFaixa;

  @override
  void initState() {
    super.initState();
    _carregarParcelas();
  }

  Future<void> _carregarParcelas() async {
    setState(() {
      _carregando = true;
    });

    try {
      final parcelas = await DatabaseHelper().getParcelasByInventario(widget.inventarioId);

      parcelas.sort((a, b) {
        if (a.bloco != b.bloco) return a.bloco.compareTo(b.bloco);
        if (a.parcela != b.parcela) return a.parcela.compareTo(b.parcela);
        return a.faixa.compareTo(b.faixa);
      });

      setState(() {
        _todasParcelas = parcelas;
        _parcelasFiltradas = parcelas;
        _carregando = false;
      });
    } catch (e) {
      setState(() {
        _carregando = false;
      });
    }
  }

  void _aplicarFiltros() {
    List<Parcela> resultado = _todasParcelas;

    if (_filtroBloco != null) {
      resultado = resultado.where((p) => p.bloco == _filtroBloco).toList();
    }
    if (_filtroParcela != null) {
      resultado = resultado.where((p) => p.parcela == _filtroParcela).toList();
    }
    if (_filtroFaixa != null) {
      resultado = resultado.where((p) => p.faixa == _filtroFaixa).toList();
    }

    resultado.sort((a, b) {
      if (a.bloco != b.bloco) return a.bloco.compareTo(b.bloco);
      if (a.parcela != b.parcela) return a.parcela.compareTo(b.parcela);
      return a.faixa.compareTo(b.faixa);
    });

    setState(() {
      _parcelasFiltradas = resultado;
    });
  }

  void _limparFiltros() {
    setState(() {
      _filtroBloco = null;
      _filtroParcela = null;
      _filtroFaixa = null;
      _parcelasFiltradas = _todasParcelas;
    });
  }

  void _refreshList() {
    _carregarParcelas();
  }

  List<int> _obterValoresUnicos(List<Parcela> parcelas, int Function(Parcela) seletor) {
    return parcelas.map(seletor).toSet().toList()..sort();
  }

  void _abrirTabelaArvores(Parcela parcela) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => TabelaArvoresScreen(
          parcelaId: parcela.id!,
          inventarioId: widget.inventarioId,
          identificadorParcela: parcela.identificador,
        ),
      ),
    );
  }

  // Constrói o cabeçalho com botão de filtro e contador
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Parcelas',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.green.shade800,
              ),
            ),
          ),
          // Botão para alternar filtros
          IconButton(
            icon: Icon(
              _mostrarFiltros ? Icons.filter_alt_off : Icons.filter_alt,
              color: Colors.green.shade700,
            ),
            onPressed: () {
              setState(() {
                _mostrarFiltros = !_mostrarFiltros;
              });
            },
            tooltip: _mostrarFiltros ? 'Ocultar filtros' : 'Mostrar filtros',
          ),
          // Chip com contagem
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Text(
              '${_parcelasFiltradas.length} de ${_todasParcelas.length}',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.blue.shade800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltros() {
    if (_todasParcelas.isEmpty) return SizedBox.shrink();

    final blocosUnicos = _obterValoresUnicos(_todasParcelas, (p) => p.bloco);
    final parcelasUnicas = _obterValoresUnicos(_todasParcelas, (p) => p.parcela);
    final faixasUnicas = _obterValoresUnicos(_todasParcelas, (p) => p.faixa);

    return AnimatedContainer(
      duration: Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      height: _mostrarFiltros ? null : 0,
      child: _mostrarFiltros
          ? Card(
        margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        elevation: 4,
        shadowColor: Colors.black26,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.filter_list, color: Colors.green.shade700),
                  SizedBox(width: 8),
                  Text(
                    'Filtros',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade800,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth > 600) {
                    return Row(
                      children: [
                        Expanded(child: _buildDropdownBloco(blocosUnicos)),
                        SizedBox(width: 12),
                        Expanded(child: _buildDropdownParcela(parcelasUnicas)),
                        SizedBox(width: 12),
                        Expanded(child: _buildDropdownFaixa(faixasUnicas)),
                      ],
                    );
                  } else {
                    return Column(
                      children: [
                        _buildDropdownBloco(blocosUnicos),
                        SizedBox(height: 12),
                        _buildDropdownParcela(parcelasUnicas),
                        SizedBox(height: 12),
                        _buildDropdownFaixa(faixasUnicas),
                      ],
                    );
                  }
                },
              ),
              SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: Icon(Icons.clear),
                      label: Text('Limpar'),
                      onPressed: _limparFiltros,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey.shade700,
                        side: BorderSide(color: Colors.grey.shade400),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: Icon(Icons.forest),
                      label: Text('Ver Todas'),
                      onPressed: _limparFiltros,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade700,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      )
          : SizedBox.shrink(),
    );
  }

  Widget _buildDropdownBloco(List<int> blocosUnicos) {
    return DropdownButtonFormField<int>(
      value: _filtroBloco,
      decoration: InputDecoration(
        labelText: 'Bloco',
        labelStyle: TextStyle(color: Colors.grey.shade700),
        prefixIcon: Icon(Icons.grid_view, color: Colors.green.shade700, size: 20),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.green.shade700, width: 2),
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        isDense: true,
      ),
      items: [
        DropdownMenuItem(
          value: null,
          child: Text('Todos'),
        ),
        ...blocosUnicos.map((bloco) => DropdownMenuItem(
          value: bloco,
          child: Text('Bloco $bloco'),
        )),
      ],
      onChanged: (value) {
        setState(() => _filtroBloco = value);
        _aplicarFiltros();
      },
    );
  }

  Widget _buildDropdownParcela(List<int> parcelasUnicas) {
    return DropdownButtonFormField<int>(
      value: _filtroParcela,
      decoration: InputDecoration(
        labelText: 'Parcela',
        labelStyle: TextStyle(color: Colors.grey.shade700),
        prefixIcon: Icon(Icons.view_agenda, color: Colors.green.shade700, size: 20),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.green.shade700, width: 2),
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        isDense: true,
      ),
      items: [
        DropdownMenuItem(value: null, child: Text('Todas')),
        ...parcelasUnicas.map((parcela) => DropdownMenuItem(
          value: parcela,
          child: Text('Parcela $parcela'),
        )),
      ],
      onChanged: (value) {
        setState(() => _filtroParcela = value);
        _aplicarFiltros();
      },
    );
  }

  Widget _buildDropdownFaixa(List<int> faixasUnicas) {
    return DropdownButtonFormField<int>(
      value: _filtroFaixa,
      decoration: InputDecoration(
        labelText: 'Faixa',
        labelStyle: TextStyle(color: Colors.grey.shade700),
        prefixIcon: Icon(Icons.view_stream, color: Colors.green.shade700, size: 20),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.green.shade700, width: 2),
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        isDense: true,
      ),
      items: [
        DropdownMenuItem(value: null, child: Text('Todas')),
        ...faixasUnicas.map((faixa) => DropdownMenuItem(
          value: faixa,
          child: Text('Faixa $faixa'),
        )),
      ],
      onChanged: (value) {
        setState(() => _filtroFaixa = value);
        _aplicarFiltros();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Parcelas do Inventário',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.green.shade700,
        elevation: 4,
        shadowColor: Colors.black26,
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
        child: Column(
          children: [
            _buildHeader(),
            _buildFiltros(),
            Expanded(
              child: _carregando
                  ? Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.green.shade700),
                ),
              )
                  : _parcelasFiltradas.isEmpty
                  ? Center(
                child: Card(
                  elevation: 4,
                  shadowColor: Colors.black26,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  margin: EdgeInsets.all(24),
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.forest,
                          size: 64,
                          color: Colors.green.shade200,
                        ),
                        SizedBox(height: 16),
                        Text(
                          _todasParcelas.isEmpty
                              ? 'Nenhuma parcela encontrada.'
                              : 'Nenhuma parcela corresponde aos filtros.',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        if (_todasParcelas.isNotEmpty) ...[
                          SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _limparFiltros,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green.shade700,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text('Limpar Filtros'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              )
                  : ListView.builder(
                padding: EdgeInsets.all(16),
                itemCount: _parcelasFiltradas.length,
                itemBuilder: (context, index) {
                  final parcela = _parcelasFiltradas[index];
                  return _buildParcelaCard(parcela);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildParcelaCard(Parcela parcela) {
    return Card(
      margin: EdgeInsets.symmetric(vertical: 6, horizontal: 0),
      elevation: 4,
      shadowColor: Colors.black26,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      color: parcela.concluida ? Colors.green.shade50 : Colors.white,
      child: InkWell(
        onTap: () => _abrirTabelaArvores(parcela),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              // Avatar com status
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: parcela.concluida ? Colors.green.shade100 : Colors.grey.shade200,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  parcela.concluida ? Icons.check : Icons.forest,
                  color: parcela.concluida ? Colors.green.shade700 : Colors.grey.shade700,
                  size: 28,
                ),
              ),
              SizedBox(width: 16),
              // Conteúdo principal
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      parcela.identificador,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade800,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                    SizedBox(height: 4),
                    FutureBuilder<int>(
                      future: DatabaseHelper().getArvoresCountByParcela(parcela.id!),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return Text('Carregando...', style: TextStyle(fontSize: 13, color: Colors.grey));
                        }
                        final count = snapshot.data ?? 0;
                        return Row(
                          children: [
                            Icon(Icons.eco, size: 16, color: Colors.green.shade600),
                            SizedBox(width: 4),
                            Text(
                              '$count árvore(s)',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    if (parcela.valorArvores != null)
                      Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: Text(
                          'Valor: ${parcela.valorArvores}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              // Ícones de ação
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(Icons.table_chart, color: Colors.blue.shade700),
                    onPressed: () => _abrirTabelaArvores(parcela),
                    tooltip: 'Ver árvores',
                    splashRadius: 24,
                  ),
                  IconButton(
                    icon: Icon(Icons.edit, color: Colors.orange.shade700),
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => EditarParcelaScreen(parcela: parcela),
                        ),
                      );
                      _refreshList();
                    },
                    tooltip: 'Editar parcela',
                    splashRadius: 24,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}