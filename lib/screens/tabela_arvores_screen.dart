import 'package:flutter/material.dart';
import 'dart:async';
import '../models/arvore.dart';
import '../database/database_helper.dart';
import 'editar_arvore_screen.dart';

class TabelaArvoresScreen extends StatefulWidget {
  final int parcelaId;
  final int inventarioId;
  final String identificadorParcela;

  const TabelaArvoresScreen({
    Key? key,
    required this.parcelaId,
    required this.inventarioId,
    required this.identificadorParcela,
  }) : super(key: key);

  @override
  _TabelaArvoresScreenState createState() => _TabelaArvoresScreenState();
}

class _TabelaArvoresScreenState extends State<TabelaArvoresScreen> {
  late Future<List<Arvore>> _futureArvores;
  final Map<int, Map<int, double>> _capsPorArvore = {};
  List<int> _anosUnicos = [];
  int _anoAtual = DateTime.now().year;

  final TextEditingController _searchController = TextEditingController();
  List<Arvore> _todasArvores = [];
  List<Arvore> _arvoresFiltradas = [];
  bool _isSearching = false;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _carregarArvoresEHistoricos();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _filtrarArvores();
    });
  }

  void _filtrarArvores() {
    final query = _searchController.text.trim();

    if (query.isEmpty) {
      setState(() {
        _isSearching = false;
        _arvoresFiltradas = [];
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    final filtered = _todasArvores.where((arvore) {
      final numero = arvore.numeroArvore.toString();
      return numero.contains(query);
    }).toList();

    setState(() {
      _arvoresFiltradas = filtered;
    });
  }

  Future<void> _carregarArvoresEHistoricos() async {
    setState(() {
      _futureArvores = _carregarArvoresComHistoricos();
      _isSearching = false;
      _arvoresFiltradas = [];
    });
  }

  Future<List<Arvore>> _carregarArvoresComHistoricos() async {
    final arvores = await DatabaseHelper().getArvoresByParcela(widget.parcelaId);
    _todasArvores = arvores;

    for (final arvore in arvores) {
      final historico = await DatabaseHelper().getCapHistoricoByArvore(arvore.id!);
      _capsPorArvore[arvore.id!] = {};
      for (final item in historico) {
        _capsPorArvore[arvore.id!]![item.ano] = item.cap;
      }
    }

    final todosAnos = <int>{};
    for (final arvore in arvores) {
      final caps = _capsPorArvore[arvore.id!];
      if (caps != null) {
        todosAnos.addAll(caps.keys);
      }
    }

    _anosUnicos = todosAnos.toList()..sort();
    if (_anosUnicos.isNotEmpty) {
      _anoAtual = _anosUnicos.last;
    }

    return arvores;
  }

  void _adicionarArvore() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditarArvoreScreen(
          parcelaId: widget.parcelaId,
          inventarioId: widget.inventarioId,
        ),
      ),
    );

    if (result == true) {
      _carregarArvoresEHistoricos();
      _searchController.clear();
    }
  }

  void _editarArvore(Arvore arvore) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditarArvoreScreen(
          parcelaId: widget.parcelaId,
          inventarioId: widget.inventarioId,
          arvore: arvore,
        ),
      ),
    );

    if (result == true) {
      _carregarArvoresEHistoricos();
    }
  }

  void _excluirArvore(Arvore arvore) async {
    final confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Exclusão'),
        content: Text('Deseja excluir a árvore ${arvore.numeroArvore}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await DatabaseHelper().deleteArvore(arvore.id!);
      _carregarArvoresEHistoricos();
    }
  }

  List<DataColumn> _buildColunas() {
    final colunasBasicas = [
      const DataColumn(label: Text('Nº', style: TextStyle(fontWeight: FontWeight.bold))),
      const DataColumn(label: Text('Código', style: TextStyle(fontWeight: FontWeight.bold))),
      const DataColumn(label: Text('X', style: TextStyle(fontWeight: FontWeight.bold))),
      const DataColumn(label: Text('Y', style: TextStyle(fontWeight: FontWeight.bold))),
      const DataColumn(label: Text('Família', style: TextStyle(fontWeight: FontWeight.bold))),
      const DataColumn(label: Text('Nome Científico', style: TextStyle(fontWeight: FontWeight.bold))),
    ];

    final colunasAnosHistoricos = _anosUnicos.where((ano) => ano != _anoAtual).map((ano) {
      return DataColumn(
        label: Text(
          'CAP $ano',
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
      );
    }).toList();

    final colunasAtuais = [
      DataColumn(
        label: Text(
          'CAP $_anoAtual',
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green),
          textAlign: TextAlign.center,
        ),
      ),
      const DataColumn(label: Text('HT', style: TextStyle(fontWeight: FontWeight.bold))),
      const DataColumn(label: Text('Ações', style: TextStyle(fontWeight: FontWeight.bold))),
    ];

    return [...colunasBasicas, ...colunasAnosHistoricos, ...colunasAtuais];
  }

  DataCell _criarCelulaComClique(Widget child, Arvore arvore) {
    return DataCell(
      GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _editarArvore(arvore),
        child: child,
      ),
    );
  }

  List<DataCell> _buildCelulasComClique(Arvore arvore) {
    final capsArvore = _capsPorArvore[arvore.id!] ?? {};

    final celulasBasicas = [
      _criarCelulaComClique(Text(arvore.numeroArvore.toString()), arvore),
      _criarCelulaComClique(Text(arvore.codigo), arvore),
      _criarCelulaComClique(Text(arvore.x.toStringAsFixed(2)), arvore),
      _criarCelulaComClique(Text(arvore.y.toStringAsFixed(2)), arvore),
      _criarCelulaComClique(Text(arvore.familia), arvore),
      _criarCelulaComClique(Text(arvore.nomeCientifico), arvore),
    ];

    final anosHistoricos = _anosUnicos.where((ano) => ano != _anoAtual).toList();
    final celulasAnosHistoricos = anosHistoricos.map((ano) {
      final cap = capsArvore[ano];
      return _criarCelulaComClique(
        cap != null
            ? Text(
          cap.toStringAsFixed(1),
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _getCorCrescimento(arvore.id!, ano),
          ),
        )
            : const Text(
          '-',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey),
        ),
        arvore,
      );
    }).toList();

    final capAtual = capsArvore[_anoAtual];
    final celulasAtuais = [
      _criarCelulaComClique(
        capAtual != null
            ? Text(
          capAtual.toStringAsFixed(1),
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.green,
          ),
        )
            : const Text(
          '-',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey),
        ),
        arvore,
      ),
      _criarCelulaComClique(Text(arvore.ht.toStringAsFixed(2)), arvore),
      DataCell(
        IconButton(
          icon: const Icon(Icons.delete, color: Colors.red, size: 20),
          onPressed: () => _excluirArvore(arvore),
          tooltip: 'Excluir',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
      ),
    ];

    return [...celulasBasicas, ...celulasAnosHistoricos, ...celulasAtuais];
  }

  Color _getCorCrescimento(int arvoreId, int ano) {
    final caps = _capsPorArvore[arvoreId];
    if (caps == null) return Colors.black;

    final anos = caps.keys.toList()..sort();
    final indexAtual = anos.indexOf(ano);

    if (indexAtual <= 0) return Colors.black;

    final capAtual = caps[ano]!;
    final capAnterior = caps[anos[indexAtual - 1]]!;

    if (capAtual > capAnterior) {
      return Colors.green;
    } else if (capAtual < capAnterior) {
      return Colors.red;
    } else {
      return Colors.orange;
    }
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Pesquisar por número da árvore...',
          prefixIcon: const Icon(Icons.search, color: Colors.green),
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
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
            icon: const Icon(Icons.clear),
            onPressed: () {
              _searchController.clear();
              setState(() {
                _isSearching = false;
                _arvoresFiltradas = [];
              });
            },
          )
              : null,
          filled: true,
          fillColor: Colors.white.withOpacity(0.9),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Árvores - ${widget.identificadorParcela}',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.green.shade700,
        elevation: 4,
        shadowColor: Colors.black26,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _adicionarArvore,
            tooltip: 'Adicionar árvore',
          ),
          if (_anosUnicos.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.info),
              onPressed: _mostrarLegenda,
              tooltip: 'Legenda das cores',
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
        child: Column(
          children: [
            _buildSearchBar(),
            Expanded(
              child: FutureBuilder<List<Arvore>>(
                future: _futureArvores,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                      ),
                    );
                  } else if (snapshot.hasError) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error, color: Colors.red.shade700, size: 64),
                          const SizedBox(height: 16),
                          const Text(
                            'Erro ao carregar árvores',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Erro: ${snapshot.error}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.red),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _carregarArvoresEHistoricos,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green.shade700,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text('Tentar Novamente'),
                          ),
                        ],
                      ),
                    );
                  } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.forest, size: 64, color: Colors.green.shade200),
                          const SizedBox(height: 16),
                          Text(
                            'Nenhuma árvore cadastrada',
                            style: TextStyle(fontSize: 18, color: Colors.grey.shade700),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Parcela: ${widget.identificadorParcela}',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.add),
                            label: const Text('Adicionar Primeira Árvore'),
                            onPressed: _adicionarArvore,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green.shade700,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  } else {
                    final arvores = _isSearching ? _arvoresFiltradas : snapshot.data!;

                    if (_isSearching && arvores.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.search_off, size: 64, color: Colors.grey),
                            const SizedBox(height: 16),
                            const Text(
                              'Nenhuma árvore encontrada',
                              style: TextStyle(fontSize: 18, color: Colors.grey),
                            ),
                          ],
                        ),
                      );
                    }

                    return Card(
                      margin: const EdgeInsets.all(8),
                      elevation: 4,
                      shadowColor: Colors.black26,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.vertical,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            headingRowColor: MaterialStateProperty.all(Colors.blue.shade50),
                            dataRowColor: MaterialStateProperty.resolveWith<Color?>(
                                  (Set<MaterialState> states) {
                                if (states.contains(MaterialState.selected)) {
                                  return Colors.green.shade100.withOpacity(0.5);
                                }
                                return null;
                              },
                            ),
                            columns: _buildColunas(),
                            rows: arvores.map((arvore) {
                              return DataRow(
                                cells: _buildCelulasComClique(arvore),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _adicionarArvore,
        child: const Icon(Icons.add),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  void _mostrarLegenda() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Legenda das Cores - CAP'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildItemLegenda(Colors.green, 'Crescimento positivo'),
            _buildItemLegenda(Colors.red, 'Crescimento negativo'),
            _buildItemLegenda(Colors.orange, 'Sem mudança'),
            _buildItemLegenda(Colors.black, 'Primeira medição'),
            _buildItemLegenda(Colors.grey, 'Sem dados'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fechar'),
          ),
        ],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
    );
  }

  Widget _buildItemLegenda(Color cor, String texto) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: cor,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 8),
          Text(texto),
        ],
      ),
    );
  }
}