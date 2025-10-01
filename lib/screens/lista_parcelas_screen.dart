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

      // Ordenar as parcelas por Bloco → Parcela → Faixa
      parcelas.sort((a, b) {
        if (a.bloco != b.bloco) {
          return a.bloco.compareTo(b.bloco);
        }
        if (a.parcela != b.parcela) {
          return a.parcela.compareTo(b.parcela);
        }
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
      resultado = resultado.where((parcela) => parcela.bloco == _filtroBloco).toList();
    }

    if (_filtroParcela != null) {
      resultado = resultado.where((parcela) => parcela.parcela == _filtroParcela).toList();
    }

    if (_filtroFaixa != null) {
      resultado = resultado.where((parcela) => parcela.faixa == _filtroFaixa).toList();
    }

    // Manter a ordenação mesmo após aplicar filtros
    resultado.sort((a, b) {
      if (a.bloco != b.bloco) {
        return a.bloco.compareTo(b.bloco);
      }
      if (a.parcela != b.parcela) {
        return a.parcela.compareTo(b.parcela);
      }
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

  Widget _buildFiltros() {
    if (_todasParcelas.isEmpty) {
      return SizedBox.shrink();
    }

    final blocosUnicos = _obterValoresUnicos(_todasParcelas, (p) => p.bloco);
    final parcelasUnicas = _obterValoresUnicos(_todasParcelas, (p) => p.parcela);
    final faixasUnicas = _obterValoresUnicos(_todasParcelas, (p) => p.faixa);

    return Card(
      margin: EdgeInsets.all(8),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Filtros',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            // Layout responsivo para os filtros
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth > 600) {
                  return Row(
                    children: [
                      Expanded(
                        child: _buildDropdownBloco(blocosUnicos),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: _buildDropdownParcela(parcelasUnicas),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: _buildDropdownFaixa(faixasUnicas),
                      ),
                    ],
                  );
                } else {
                  // Layout para telas estreitas (vertical)
                  return Column(
                    children: [
                      _buildDropdownBloco(blocosUnicos),
                      SizedBox(height: 16),
                      _buildDropdownParcela(parcelasUnicas),
                      SizedBox(height: 16),
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
                    label: Text('Limpar Filtros'),
                    onPressed: _limparFiltros,
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: Icon(Icons.forest),
                    label: Text('Ver Todas (${_todasParcelas.length})'),
                    onPressed: _limparFiltros,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              'Mostrando ${_parcelasFiltradas.length} de ${_todasParcelas.length} parcelas',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdownBloco(List<int> blocosUnicos) {
    return DropdownButtonFormField<int>(
      value: _filtroBloco,
      decoration: InputDecoration(
        labelText: 'Bloco',
        border: OutlineInputBorder(),
        isDense: true,
      ),
      items: [
        DropdownMenuItem(
          value: null,
          child: Text('Todos os blocos'),
        ),
        ...blocosUnicos.map((bloco) {
          return DropdownMenuItem(
            value: bloco,
            child: Text('Bloco $bloco'),
          );
        }).toList(),
      ],
      onChanged: (value) {
        setState(() {
          _filtroBloco = value;
        });
        _aplicarFiltros();
      },
    );
  }

  Widget _buildDropdownParcela(List<int> parcelasUnicas) {
    return DropdownButtonFormField<int>(
      value: _filtroParcela,
      decoration: InputDecoration(
        labelText: 'Parcela',
        border: OutlineInputBorder(),
        isDense: true,
      ),
      items: [
        DropdownMenuItem(
          value: null,
          child: Text('Todas as parcelas'),
        ),
        ...parcelasUnicas.map((parcela) {
          return DropdownMenuItem(
            value: parcela,
            child: Text('Parcela $parcela'),
          );
        }).toList(),
      ],
      onChanged: (value) {
        setState(() {
          _filtroParcela = value;
        });
        _aplicarFiltros();
      },
    );
  }

  Widget _buildDropdownFaixa(List<int> faixasUnicas) {
    return DropdownButtonFormField<int>(
      value: _filtroFaixa,
      decoration: InputDecoration(
        labelText: 'Faixa',
        border: OutlineInputBorder(),
        isDense: true,
      ),
      items: [
        DropdownMenuItem(
          value: null,
          child: Text('Todas as faixas'),
        ),
        ...faixasUnicas.map((faixa) {
          return DropdownMenuItem(
            value: faixa,
            child: Text('Faixa $faixa'),
          );
        }).toList(),
      ],
      onChanged: (value) {
        setState(() {
          _filtroFaixa = value;
        });
        _aplicarFiltros();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Parcelas do Inventário'),
        backgroundColor: Colors.green,
      ),
      body: Column(
        children: [
          _buildFiltros(),
          Expanded(
            child: _carregando
                ? Center(child: CircularProgressIndicator())
                : _parcelasFiltradas.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.forest, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    _todasParcelas.isEmpty
                        ? 'Nenhuma parcela encontrada.'
                        : 'Nenhuma parcela corresponde aos filtros.',
                  ),
                  if (_todasParcelas.isNotEmpty)
                    TextButton(
                      onPressed: _limparFiltros,
                      child: Text('Limpar filtros'),
                    ),
                ],
              ),
            )
                : ListView.builder(
              itemCount: _parcelasFiltradas.length,
              itemBuilder: (context, index) {
                final parcela = _parcelasFiltradas[index];
                return _buildParcelaCard(parcela);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParcelaCard(Parcela parcela) {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      color: parcela.concluida ? Colors.green[50] : null,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: parcela.concluida ? Colors.green : Colors.grey,
          child: Icon(
            parcela.concluida ? Icons.check : Icons.forest,
            color: Colors.white,
          ),
        ),
        title: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _abrirTabelaArvores(parcela),
          child: Text(
            parcela.identificador,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.blue[700],
              decoration: TextDecoration.underline,
            ),
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (parcela.valorArvores != null)
              Text('Valor: ${parcela.valorArvores}'),
            FutureBuilder<int>(
              future: DatabaseHelper().getArvoresCountByParcela(parcela.id!),
              builder: (context, arvoresSnapshot) {
                if (arvoresSnapshot.connectionState == ConnectionState.waiting) {
                  return Text('Carregando árvores...');
                } else if (arvoresSnapshot.hasError) {
                  return Text('Erro ao carregar árvores');
                } else {
                  final count = arvoresSnapshot.data ?? 0;
                  return Text('$count árvore(s) cadastrada(s)');
                }
              },
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(Icons.table_chart, color: Colors.blue),
              onPressed: () => _abrirTabelaArvores(parcela),
              tooltip: 'Ver árvores',
            ),
            IconButton(
              icon: Icon(Icons.edit, color: Colors.orange),
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
            ),
          ],
        ),
        onTap: () => _abrirTabelaArvores(parcela),
      ),
    );
  }
}