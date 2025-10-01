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
            backgroundColor: Colors.green,
          ),
        );

        _refreshList();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao deletar inventário: $e'),
            backgroundColor: Colors.red,
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
              Icon(Icons.warning, color: Colors.red),
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
                  color: Colors.red,
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
                backgroundColor: Colors.red,
              ),
              child: Text(
                'Deletar',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Inventários Existentes'),
        backgroundColor: Colors.blue,
      ),
      body: FutureBuilder<List<Inventario>>(
        future: _futureInventarios,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Erro: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inventory_2, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'Nenhum inventário encontrado',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Crie um novo inventário para começar',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          } else {
            return ListView.builder(
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
                    final double progresso = totalParcelas > 0 ?
                    concluidas / totalParcelas : 0.0;

                    return Card(
                      margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: ListTile(
                        leading: CircleAvatar(
                          child: Icon(Icons.forest),
                          backgroundColor: Colors.green,
                        ),
                        title: Text(
                          inventario.nome,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${inventario.numeroBlocos} Blocos, '
                                  '${inventario.numeroFaixas} Faixas, '
                                  '${inventario.numeroParcelas} Parcelas',
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                            SizedBox(height: 4),
                            LinearProgressIndicator(
                              value: progresso,
                              backgroundColor: Colors.grey[300],
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  progresso >= 1.0 ? Colors.green :
                                  progresso > 0.5 ? Colors.blue :
                                  progresso > 0.0 ? Colors.orange : Colors.grey
                              ),
                            ),
                            Text(
                              '$concluidas/$totalParcelas parcelas concluídas',
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                              style: TextStyle(
                                fontSize: 12,
                                color: progresso >= 1.0 ? Colors.green : Colors.grey[700],
                              ),
                            ),
                          ],
                        ),
                        // MENU POPUP COM TODAS AS OPÇÕES (incluindo deletar)
                        trailing: PopupMenuButton(
                          icon: Icon(Icons.more_vert, size: 20),
                          itemBuilder: (context) => [
                            PopupMenuItem(
                              child: ListTile(
                                leading: Icon(Icons.arrow_forward_ios, size: 20),
                                title: Text('Abrir Inventário'),
                                onTap: () {
                                  Navigator.pop(context);
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => ListaParcelasScreen(
                                        inventarioId: inventario.id!,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            PopupMenuItem(
                              child: ListTile(
                                leading: Icon(Icons.download, color: Colors.purple, size: 20),
                                title: Text('Exportar Dados'),
                                onTap: () {
                                  Navigator.pop(context);
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => ExportarScreen(inventarioId: inventario.id!),
                                    ),
                                  );
                                },
                              ),
                            ),
                            PopupMenuItem(
                              child: ListTile(
                                leading: Icon(Icons.upload, color: Colors.orange, size: 20),
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
                                leading: Icon(Icons.delete, color: Colors.red, size: 20),
                                title: Text(
                                  'Deletar Inventário',
                                  style: TextStyle(color: Colors.red),
                                ),
                                onTap: () {
                                  Navigator.pop(context);
                                  _deletarInventario(inventario);
                                },
                              ),
                            ),
                          ],
                        ),
                        // Mantemos o onTap para toda a linha também funcionar
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
                        isThreeLine: false,
                        dense: true,
                      ),
                    );
                  },
                );
              },
            );
          }
        },
      ),
    );
  }
}