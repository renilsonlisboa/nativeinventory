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

  // ✅ Controle de exibição: vivas (false) ou mortas (true)
  bool _mostrarMortas = false;

  // Altura fixa para as linhas (células)
  static const double _rowHeight = 50;

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
    final todasArvores =
    await DatabaseHelper().getArvoresByParcela(widget.parcelaId);

    // ✅ Filtra por status de morte
    final arvores = todasArvores
        .where((a) =>
    _mostrarMortas
        ? (a.infoMorte ?? 0) == 1
        : (a.infoMorte ?? 0) == 0)
        .toList();

    _todasArvores = arvores;

    for (final arvore in arvores) {
      final historico =
      await DatabaseHelper().getCapHistoricoByArvore(arvore.id!);
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

  /// Constrói a lista de cabeçalhos das colunas roláveis (todas exceto a primeira)
  List<Widget> _buildScrollableHeaders() {
    final colunasBasicas = [
      'Fuste',
      'Código',
      'X',
      'Y',
      'Família',
      'Nome Científico',
      'Nome Popular'
    ];

    final headers = <Widget>[];

    // Colunas básicas
    for (final label in colunasBasicas) {
      headers.add(_buildHeaderCell(label));
    }

    // Colunas de anos históricos (exceto o atual)
    for (final ano in _anosUnicos.where((a) => a != _anoAtual)) {
      headers.add(_buildHeaderCell('CAP $ano', fontSize: 12));
    }

    // Colunas atuais (CAP atual, HC, HT, Ações)
    headers.add(
        _buildHeaderCell('CAP $_anoAtual', color: Colors.green, fontSize: 12));
    headers.add(_buildHeaderCell('HC'));
    headers.add(_buildHeaderCell('HT'));
    headers.add(_buildHeaderCell('Fuste'));
    headers.add(_buildHeaderCell('Estrato'));
    headers.add(_buildHeaderCell('Fitos.'));
    headers.add(_buildHeaderCell('Pos'));
    headers.add(_buildHeaderCell('Forma'));
    headers.add(_buildHeaderCell('Ações'));

    return headers;
  }

  /// Constrói uma célula de cabeçalho padronizada
  Widget _buildHeaderCell(String text, {Color? color, double fontSize = 14}) {
    return Container(
      width: 100,
      height: _rowHeight,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        color: Colors.blue.shade50,
      ),
      child: Text(
        text,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: color,
          fontSize: fontSize,
        ),
        textAlign: TextAlign.center,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  /// Constrói a lista de células de dados para uma árvore (colunas roláveis)
  List<Widget> _buildScrollableCellsForArvore(Arvore arvore) {
    final capsArvore = _capsPorArvore[arvore.id!] ?? {};

    final cells = <Widget>[];

    cells.add(_buildDataCell(arvore.numeroFuste.toString(), arvore));
    cells.add(_buildDataCell(arvore.codigo, arvore));
    cells.add(_buildDataCell(arvore.x.toStringAsFixed(2), arvore));
    cells.add(_buildDataCell(arvore.y.toStringAsFixed(2), arvore));
    cells.add(_buildDataCell(arvore.familia, arvore, maxLines: 2));
    cells.add(_buildDataCell(arvore.nomeCientifico, arvore, maxLines: 2));
    cells.add(_buildDataCell(arvore.nomePopular ?? '-', arvore, maxLines: 2));

    // Colunas de anos históricos
    for (final ano in _anosUnicos.where((a) => a != _anoAtual)) {
      final cap = capsArvore[ano];
      cells.add(
        _buildDataCell(
          cap != null ? cap.toStringAsFixed(1) : '-',
          arvore,
          color: _getCorCrescimento(arvore.id!, ano),
          textAlign: TextAlign.center,
        ),
      );
    }

    // Colunas atuais
    final capAtual = capsArvore[_anoAtual];
    cells.add(
      _buildDataCell(
        capAtual != null ? capAtual.toStringAsFixed(1) : '-',
        arvore,
        color: Colors.green,
        fontWeight: FontWeight.bold,
        textAlign: TextAlign.center,
      ),
    );
    cells.add(_buildDataCell(arvore.hc.toStringAsFixed(2), arvore));
    cells.add(_buildDataCell(arvore.ht.toStringAsFixed(2), arvore));
    cells.add(_buildDataCell(
        arvore.formaFuste == 0 ? '-' : arvore.formaFuste.toString(), arvore));
    cells.add(_buildDataCell(
        arvore.posiSoc == 0 ? '-' : arvore.posiSoc.toString(), arvore));
    cells.add(_buildDataCell(
        arvore.fitossanidade == 0 ? '-' : arvore.fitossanidade.toString(),
        arvore));
    cells.add(_buildDataCell(
        arvore.posiCopa == 0 ? '-' : arvore.posiCopa.toString(), arvore));
    cells.add(_buildDataCell(
        arvore.formaCopa == 0 ? '-' : arvore.formaCopa.toString(), arvore));
    cells.add(_buildActionCell(arvore));
    return cells;
  }

  /// Constrói uma célula de dados padronizada, que abre a edição ao ser clicada
  Widget _buildDataCell(
      String text,
      Arvore arvore, {
        Color? color,
        FontWeight? fontWeight,
        TextAlign textAlign = TextAlign.left,
        int maxLines = 1,
      }) {
    return GestureDetector(
      onTap: () => _editarArvore(arvore),
      child: Container(
        width: 100,
        height: _rowHeight,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: color,
            fontWeight: fontWeight,
            fontSize: 13,
          ),
          textAlign: textAlign,
          maxLines: maxLines,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  /// Célula especial para a coluna de ações (apenas o botão de excluir)
  Widget _buildActionCell(Arvore arvore) {
    return Container(
      width: 100,
      height: _rowHeight,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: IconButton(
        icon: const Icon(Icons.delete, color: Colors.red, size: 20),
        onPressed: () => _excluirArvore(arvore),
        tooltip: 'Excluir',
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
      ),
    );
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
          // ✅ Botão de alternância: vivas / mortas
          IconButton(
            icon: Icon(
              _mostrarMortas ? Icons.person_off : Icons.park,
              color: _mostrarMortas ? Colors.red.shade200 : Colors.white,
            ),
            tooltip: _mostrarMortas
                ? 'Exibindo árvores mortas'
                : 'Exibindo árvores vivas',
            onPressed: () {
              setState(() {
                _mostrarMortas = !_mostrarMortas;
              });
              _carregarArvoresEHistoricos();
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
                        valueColor:
                        AlwaysStoppedAnimation<Color>(Colors.green),
                      ),
                    );
                  } else if (snapshot.hasError) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error,
                              color: Colors.red.shade700, size: 64),
                          const SizedBox(height: 16),
                          const Text(
                            'Erro ao carregar árvores',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
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
                          Icon(Icons.forest,
                              size: 64, color: Colors.green.shade200),
                          const SizedBox(height: 16),
                          Text(
                            _mostrarMortas
                                ? 'Nenhuma árvore morta cadastrada'
                                : 'Nenhuma árvore cadastrada',
                            style: TextStyle(
                                fontSize: 18, color: Colors.grey.shade700),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Parcela: ${widget.identificadorParcela}',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                          if (!_mostrarMortas) ...[
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
                        ],
                      ),
                    );
                  } else {
                    final arvores =
                    _isSearching ? _arvoresFiltradas : snapshot.data!;

                    if (_isSearching && arvores.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.search_off, size: 64, color: Colors.grey),
                            SizedBox(height: 16),
                            Text(
                              'Nenhuma árvore encontrada',
                              style:
                              TextStyle(fontSize: 18, color: Colors.grey),
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
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.vertical,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // --- COLUNA FIXA (esquerda) ---
                              Column(
                                children: [
                                  // Cabeçalho da coluna fixa
                                  Container(
                                    width: 80,
                                    height: _rowHeight,
                                    alignment: Alignment.center,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 4),
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                          color: Colors.grey.shade300),
                                      color: Colors.blue.shade50,
                                    ),
                                    child: const Text(
                                      'Arv.',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  // Células da coluna fixa (número da árvore)
                                  ...arvores.map((arvore) {
                                    return GestureDetector(
                                      onTap: () => _editarArvore(arvore),
                                      child: Container(
                                        width: 80,
                                        height: _rowHeight,
                                        alignment: Alignment.center,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 4),
                                        decoration: BoxDecoration(
                                          border: Border.all(
                                              color: Colors.grey.shade300),
                                        ),
                                        child: Text(
                                          arvore.numeroArvore.toString(),
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ],
                              ),

                              // --- COLUNAS ROLÁVEIS (direita) ---
                              Expanded(
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Column(
                                    crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                    children: [
                                      // Linha de cabeçalhos das colunas roláveis
                                      Row(
                                        children: _buildScrollableHeaders(),
                                      ),
                                      // Linhas de dados
                                      ...arvores.map((arvore) {
                                        return Row(
                                          children:
                                          _buildScrollableCellsForArvore(
                                              arvore),
                                        );
                                      }).toList(),
                                    ],
                                  ),
                                ),
                              ),
                            ],
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
    );
  }
}