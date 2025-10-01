import 'package:flutter/material.dart';
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
  final List<Arvore> _arvoresSelecionadas = [];

  @override
  void initState() {
    super.initState();
    _carregarArvores();
  }

  void _carregarArvores() {
    setState(() {
      _futureArvores = DatabaseHelper().getArvoresByParcela(widget.parcelaId);
    });
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
      _carregarArvores();
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
      _carregarArvores();
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
      _carregarArvores();
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
      _carregarArvores();
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
                    onPressed: _carregarArvores,
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
                  columns: const [
                    DataColumn(label: Text('Nº')),
                    DataColumn(label: Text('Código')),
                    DataColumn(label: Text('X')),
                    DataColumn(label: Text('Y')),
                    DataColumn(label: Text('Família')),
                    DataColumn(label: Text('Nome Científico')),
                    DataColumn(label: Text('DAP')),
                    DataColumn(label: Text('HT')),
                    DataColumn(label: Text('Ações')),
                  ],
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
                      cells: [
                        DataCell(Text(arvore.numeroArvore.toString())),
                        DataCell(Text(arvore.codigo)),
                        DataCell(Text(arvore.x.toStringAsFixed(2))),
                        DataCell(Text(arvore.y.toStringAsFixed(2))),
                        DataCell(Text(arvore.familia)),
                        DataCell(Text(arvore.nomeCientifico)),
                        DataCell(Text(arvore.dap.toStringAsFixed(2))),
                        DataCell(Text(arvore.ht.toStringAsFixed(2))),
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit, color: Colors.blue, size: 20),
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
                        ),
                      ],
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
}