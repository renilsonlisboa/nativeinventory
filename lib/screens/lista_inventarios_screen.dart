import 'package:flutter/material.dart';
import '../models/inventario.dart';
import '../database/database_helper.dart';
import 'lista_parcelas_screen.dart';
import 'exportar_screen.dart';
import 'importar_screen.dart';

class ListaInventariosScreen extends StatefulWidget {
  @override
  _ListaInventariosScreenState createState() => _ListaInventariosScreenState();
}

class _ListaInventariosScreenState extends State<ListaInventariosScreen> {
  late Future<List<Inventario>> _futureInventarios;

  @override
  void initState() {
    super.initState();
    _futureInventarios = DatabaseHelper().getInventarios();
  }

  void _refreshList() {
    setState(() {
      _futureInventarios = DatabaseHelper().getInventarios();
    });
  }

  Future<void> _deletarInventario(Inventario inventario) async {
    final bool? confirmado = await _mostrarConfirmacaoDelecao(inventario);

    if (confirmado == true) {
      try {
        await DatabaseHelper().deleteInventario(inventario.id!);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Inventário "${inventario.nome}" deletado com sucesso'),
            backgroundColor: Colors.green.shade700,
          ),
        );

        _refreshList();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao deletar inventário: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  Future<bool?> _mostrarConfirmacaoDelecao(Inventario inventario) async {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.warning, color: Colors.red.shade700),
              SizedBox(width: 8),
              Text('Confirmar Exclusão'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Tem certeza que deseja deletar o inventário:'),
              SizedBox(height: 8),
              Text(
                '"${inventario.nome}"',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              SizedBox(height: 12),
              Text(
                'Esta ação não pode ser desfeita! Todos os dados das parcelas e árvores serão perdidos permanentemente.',
                style: TextStyle(
                  color: Colors.red.shade700,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text('Deletar'),
            ),
          ],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Inventários Existentes',
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
        child: FutureBuilder<List<Inventario>>(
          future: _futureInventarios,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.green.shade700),
                ),
              );
            } else if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 64, color: Colors.red.shade700),
                    SizedBox(height: 16),
                    Text(
                      'Erro ao carregar inventários',
                      style: TextStyle(fontSize: 18, color: Colors.grey.shade700),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '${snapshot.error}',
                      style: TextStyle(color: Colors.grey.shade600),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return Center(
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
                        Icon(Icons.inventory_2, size: 80, color: Colors.green.shade200),
                        SizedBox(height: 16),
                        Text(
                          'Nenhum inventário encontrado',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade800,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Crie um novo inventário para começar',
                          style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            } else {
              return ListView.builder(
                padding: EdgeInsets.all(12),
                itemCount: snapshot.data!.length,
                itemBuilder: (context, index) {
                  final inventario = snapshot.data![index];
                  return FutureBuilder<int>(
                    future: DatabaseHelper().getParcelasConcluidasCount(inventario.id!),
                    builder: (context, progressSnapshot) {
                      final concluidas = progressSnapshot.data ?? 0;
                      final totalParcelas = inventario.numeroBlocos *
                          inventario.numeroFaixas *
                          inventario.numeroParcelas;
                      final double progresso = totalParcelas > 0
                          ? concluidas / totalParcelas
                          : 0.0;

                      return Card(
                        margin: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        elevation: 4,
                        shadowColor: Colors.black26,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ListaParcelasScreen(
                                  inventarioId: inventario.id!,
                                ),
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Padding(
                            padding: EdgeInsets.all(12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Avatar com ícone
                                Container(
                                  width: 50,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade100,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.forest,
                                    color: Colors.green.shade700,
                                    size: 30,
                                  ),
                                ),
                                SizedBox(width: 12),
                                // Conteúdo principal
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        inventario.nome,
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.green.shade800,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        '${inventario.numeroBlocos} Blocos · ${inventario.numeroFaixas} Faixas · ${inventario.numeroParcelas} Parcelas',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey.shade600,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                      ),
                                      SizedBox(height: 8),
                                      // Barra de progresso
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: LinearProgressIndicator(
                                          value: progresso,
                                          backgroundColor: Colors.grey.shade300,
                                          valueColor: AlwaysStoppedAnimation<Color>(
                                            progresso >= 1.0
                                                ? Colors.green.shade700
                                                : progresso > 0.5
                                                ? Colors.blue.shade700
                                                : progresso > 0.0
                                                ? Colors.orange.shade700
                                                : Colors.grey.shade500,
                                          ),
                                          minHeight: 8,
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        '$concluidas de $totalParcelas parcelas concluídas',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: progresso >= 1.0
                                              ? Colors.green.shade700
                                              : Colors.grey.shade700,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                      ),
                                    ],
                                  ),
                                ),
                                // Menu de opções
                                PopupMenuButton(
                                  icon: Icon(Icons.more_vert, color: Colors.grey.shade700),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  itemBuilder: (context) => [
                                    PopupMenuItem(
                                      child: ListTile(
                                        leading: Icon(Icons.arrow_forward_ios,
                                            color: Colors.green.shade700, size: 20),
                                        title: Text('Abrir Inventário'),
                                        onTap: () {
                                          Navigator.pop(context);
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => ListaParcelasScreen(
                                                inventarioId: inventario.id,
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                    PopupMenuItem(
                                      child: ListTile(
                                        leading: Icon(Icons.download,
                                            color: Colors.purple.shade700, size: 20),
                                        title: Text('Exportar Dados'),
                                        onTap: () {
                                          Navigator.pop(context);
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => ExportarScreen(
                                                inventarioId: inventario.id!,
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                    PopupMenuItem(
                                      child: ListTile(
                                        leading: Icon(Icons.upload,
                                            color: Colors.orange.shade700, size: 20),
                                        title: Text('Importar Dados'),
                                        onTap: () {
                                          Navigator.pop(context);
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => ImportarScreen(
                                                inventarioId: inventario.id!,
                                                nomeInventario: inventario.nome,
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                    PopupMenuItem(
                                      child: ListTile(
                                        leading: Icon(Icons.delete,
                                            color: Colors.red.shade700, size: 20),
                                        title: Text(
                                          'Deletar Inventário',
                                          style: TextStyle(color: Colors.red.shade700),
                                        ),
                                        onTap: () {
                                          Navigator.pop(context);
                                          _deletarInventario(inventario);
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            }
          },
        ),
      ),
    );
  }
}