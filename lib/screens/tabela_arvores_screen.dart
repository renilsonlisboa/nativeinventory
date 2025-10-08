import 'package:flutter/material.dart';
import '../models/arvore.dart';
import '../models/cap_historico.dart';
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
  final List<Arvore> _arvoresSelecionadas = [];
  final Map<int, Map<int, double>> _capsPorArvore = {};
  List<int> _anosUnicos = [];
  int _anoAtual = DateTime.now().year; // Ano atual como padrão

  @override
  void initState() {
    super.initState();
    _carregarArvoresEHistoricos();
  }

  Future<void> _carregarArvoresEHistoricos() async {
    setState(() {
      _futureArvores = _carregarArvoresComHistoricos();
    });
  }

  // REMOVED THE DUPLICATE METHOD - KEEP ONLY ONE VERSION
  Future<List<Arvore>> _carregarArvoresComHistoricos() async {
    final arvores = await DatabaseHelper().getArvoresByParcela(widget.parcelaId);

    // Carregar históricos de CAP para todas as árvores
    for (final arvore in arvores) {
      final historico = await DatabaseHelper().getCapHistoricoByArvore(arvore.id!);
      _capsPorArvore[arvore.id!] = {};
      for (final item in historico) {
        _capsPorArvore[arvore.id!]![item.ano] = item.cap;
      }
    }

    // Coletar anos únicos de todas as árvores
    final todosAnos = <int>{};
    for (final arvore in arvores) {
      final caps = _capsPorArvore[arvore.id!];
      if (caps != null) {
        todosAnos.addAll(caps.keys);
      }
    }

    _anosUnicos = todosAnos.toList()..sort();

    // Determinar ano atual (o mais recente)
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

  void _excluirArvoresSelecionadas() async {
    if (_arvoresSelecionadas.isEmpty) return;

    final confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Exclusão'),
        content: Text('Deseja excluir ${_arvoresSelecionadas.length} árvore(s)?'),
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
      for (final arvore in _arvoresSelecionadas) {
        await DatabaseHelper().deleteArvore(arvore.id!);
      }
      _arvoresSelecionadas.clear();
      _carregarArvoresEHistoricos();
    }
  }

  List<DataColumn> _buildColunas() {
    // Colunas básicas (primeiras)
    final colunasBasicas = [
      const DataColumn(label: Text('Nº')),
      const DataColumn(label: Text('Código')),
      const DataColumn(label: Text('X')),
      const DataColumn(label: Text('Y')),
      const DataColumn(label: Text('Família')),
      const DataColumn(label: Text('Nome Científico')),
    ];

    // Colunas de CAP históricos (do meio)
    final colunasAnosHistoricos = _anosUnicos.where((ano) => ano != _anoAtual).map((ano) {
      return DataColumn(
        label: Text(
          'CAP $ano',
          style: const TextStyle(fontSize: 12),
          textAlign: TextAlign.center,
        ),
      );
    }).toList();

    // Colunas atuais (últimas)
    final colunasAtuais = [
      DataColumn(
        label: Text(
          'CAP $_anoAtual',
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
      ),
      const DataColumn(label: Text('HT')),
      // REMOVED HC COLUMN SINCE IT DOESN'T EXIST IN ARVORE MODEL
      // const DataColumn(label: Text('HC')),
    ];

    // Coluna de ações
    final colunaAcoes = const DataColumn(label: Text('Ações'));

    return [...colunasBasicas, ...colunasAnosHistoricos, ...colunasAtuais, colunaAcoes];
  }

  List<DataCell> _buildCelulas(Arvore arvore) {
    final capsArvore = _capsPorArvore[arvore.id!] ?? {};

    // Células básicas (primeiras)
    final celulasBasicas = [
      DataCell(Text(arvore.numeroArvore.toString())),
      DataCell(Text(arvore.codigo)),
      DataCell(Text(arvore.x.toStringAsFixed(2))),
      DataCell(Text(arvore.y.toStringAsFixed(2))),
      DataCell(Text(arvore.familia)),
      DataCell(Text(arvore.nomeCientifico)),
    ];

    // Células de CAP históricos (do meio)
    final anosHistoricos = _anosUnicos.where((ano) => ano != _anoAtual).toList();
    final celulasAnosHistoricos = anosHistoricos.map((ano) {
      final cap = capsArvore[ano];
      return DataCell(
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
      );
    }).toList();

    // Células atuais (últimas)
    final capAtual = capsArvore[_anoAtual];
    final celulasAtuais = [
      DataCell(
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
      ),
      DataCell(Text(arvore.ht.toStringAsFixed(2))),
      // REMOVED HC CELL SINCE IT DOESN'T EXIST IN ARVORE MODEL
      // DataCell(Text(arvore.hc?.toStringAsFixed(2) ?? '-')),
    ];

    // Célula de ações
    final celulaAcoes = DataCell(
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.orange, size: 20),
            onPressed: () => _editarArvore(arvore),
            tooltip: 'Editar',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red, size: 20),
            onPressed: () => _excluirArvore(arvore),
            tooltip: 'Excluir',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );

    return [...celulasBasicas, ...celulasAnosHistoricos, ...celulasAtuais, celulaAcoes];
  }

  Color _getCorCrescimento(int arvoreId, int ano) {
    final caps = _capsPorArvore[arvoreId];
    if (caps == null) return Colors.black;

    final anos = caps.keys.toList()..sort();
    final indexAtual = anos.indexOf(ano);

    // Se é o primeiro ano, não tem comparação
    if (indexAtual <= 0) return Colors.black;

    final capAtual = caps[ano]!;
    final capAnterior = caps[anos[indexAtual - 1]]!;

    if (capAtual > capAnterior) {
      return Colors.green; // Crescimento positivo
    } else if (capAtual < capAnterior) {
      return Colors.red; // Crescimento negativo
    } else {
      return Colors.orange; // Sem mudança
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Árvores - ${widget.identificadorParcela}'),
        backgroundColor: Colors.green,
        actions: [
          if (_arvoresSelecionadas.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _excluirArvoresSelecionadas,
              tooltip: 'Excluir selecionadas',
            ),
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
      body: FutureBuilder<List<Arvore>>(
        future: _futureArvores,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, color: Colors.red, size: 64),
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
                  const Icon(Icons.forest, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text(
                    'Nenhuma árvore cadastrada',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Parcela: ${widget.identificadorParcela}',
                    style: const TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Adicionar Primeira Árvore'),
                    onPressed: _adicionarArvore,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                    ),
                  ),
                ],
              ),
            );
          } else {
            final arvores = snapshot.data!;

            return SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: _buildColunas(),
                  rows: arvores.map((arvore) {
                    final isSelected = _arvoresSelecionadas.contains(arvore);
                    return DataRow(
                      selected: isSelected,
                      onSelectChanged: (selected) {
                        setState(() {
                          if (selected == true) {
                            _arvoresSelecionadas.add(arvore);
                          } else {
                            _arvoresSelecionadas.remove(arvore);
                          }
                        });
                      },
                      cells: _buildCelulas(arvore),
                    );
                  }).toList(),
                ),
              ),
            );
          }
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _adicionarArvore,
        child: const Icon(Icons.add),
        backgroundColor: Colors.green,
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
      ),
    );
  }

  Widget _buildItemLegenda(Color cor, String texto) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 16,
            height: 16,
            color: cor,
            margin: const EdgeInsets.only(right: 8),
          ),
          Text(texto),
        ],
      ),
    );
  }
}