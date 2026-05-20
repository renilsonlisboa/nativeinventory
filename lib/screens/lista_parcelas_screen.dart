import 'package:flutter/material.dart';
import '../models/parcela.dart';
import '../database/database_helper.dart';
import 'tabela_arvores_screen.dart';
import 'adicionar_parcelas_screen.dart'; // ← NOVO IMPORT

class ListaParcelasScreen extends StatefulWidget {
  final int inventarioId;
  final int? filtroBloco;

  const ListaParcelasScreen({
    Key? key,
    required this.inventarioId,
    this.filtroBloco,
  }) : super(key: key);

  @override
  _ListaParcelasScreenState createState() => _ListaParcelasScreenState();
}

class _ListaParcelasScreenState extends State<ListaParcelasScreen> {
  List<Parcela> _todasParcelas = [];
  List<Parcela> _parcelasFiltradas = [];
  bool _carregando = true;

  // Filtros
  int? _filtroBloco;
  int? _filtroParcela;
  int? _filtroFaixa;

  @override
  void initState() {
    super.initState();
    _filtroBloco = widget.filtroBloco;
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
        _carregando = false;
      });
      _aplicarFiltros();
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


  Future<void> _toggleConcluida(Parcela parcela) async {
    try {
      final atualizada = parcela.copyWith(concluida: !parcela.concluida);
      await DatabaseHelper().updateParcela(atualizada);
      _carregarParcelas();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao atualizar parcela'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
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

  // ─── NOVO: abre tela de adição de parcelas ────────────────────────────────
  Future<void> _abrirAdicionarParcelas() async {
    final houveMudanca = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) =>
            AdicionarParcelasScreen(inventarioId: widget.inventarioId),
      ),
    );

    if (houveMudanca == true) {
      // Recarrega a lista e reaplica os filtros
      await _carregarParcelas();
      _aplicarFiltros();
    }
  }

  // ─── Header ───────────────────────────────────────────────────────────────
  Widget _buildDropdownBloco(List<int> blocosUnicos) {
    return DropdownButtonFormField<int>(
      value: _filtroBloco,
      decoration: InputDecoration(
        labelText: 'Bloco',
        labelStyle: TextStyle(color: Colors.grey.shade700),
        prefixIcon: Icon(Icons.grid_view, color: Colors.green.shade700, size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.green.shade700, width: 2),
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        isDense: true,
      ),
      items: [
        DropdownMenuItem(value: null, child: Text('Todos')),
        ...blocosUnicos.map((bloco) =>
            DropdownMenuItem(value: bloco, child: Text('Bloco $bloco'))),
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
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.green.shade700, width: 2),
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        isDense: true,
      ),
      items: [
        DropdownMenuItem(value: null, child: Text('Todas')),
        ...parcelasUnicas.map((parcela) =>
            DropdownMenuItem(value: parcela, child: Text('Parcela $parcela'))),
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
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.green.shade700, width: 2),
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        isDense: true,
      ),
      items: [
        DropdownMenuItem(value: null, child: Text('Todas')),
        ...faixasUnicas.map((faixa) =>
            DropdownMenuItem(value: faixa, child: Text('Faixa $faixa'))),
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
      // ─── NOVO: botão flutuante ──────────────────────────────────────────────
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _abrirAdicionarParcelas,
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text(
          'Adicionar parcelas',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        tooltip: 'Adicionar novas parcelas ao inventário',
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.green.shade50, Colors.blue.shade50],
          ),
        ),
        child: Column(
          children: [
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
                        Icon(Icons.forest, size: 64, color: Colors.green.shade200),
                        SizedBox(height: 16),
                        Text(
                          _todasParcelas.isEmpty
                              ? 'Nenhuma parcela encontrada.'
                              : 'Nenhuma parcela corresponde aos filtros.',
                          style: TextStyle(fontSize: 18, color: Colors.grey.shade700),
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
                // Padding extra no final para o FAB não cobrir o último item
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: parcela.concluida ? Colors.green.shade50 : Colors.white,
      child: InkWell(
        onTap: () => _abrirTabelaArvores(parcela),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
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
                              style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
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
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(
                      parcela.concluida ? Icons.check_circle : Icons.check_circle_outline,
                      color: parcela.concluida ? Colors.green.shade700 : Colors.grey.shade500,
                    ),
                    onPressed: () => _toggleConcluida(parcela),
                    tooltip: parcela.concluida ? 'Marcar como pendente' : 'Concluir parcela',
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