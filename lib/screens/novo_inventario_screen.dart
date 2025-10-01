import 'package:flutter/material.dart';
import '../models/inventario.dart';
import '../models/parcela.dart';
import '../database/database_helper.dart';
import 'lista_parcelas_screen.dart';

class NovoInventarioScreen extends StatefulWidget {
  @override
  _NovoInventarioScreenState createState() => _NovoInventarioScreenState();
}

class _NovoInventarioScreenState extends State<NovoInventarioScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nomeController = TextEditingController();
  final _blocosController = TextEditingController();
  final _parcelasController = TextEditingController();
  final _faixasController = TextEditingController();
  final _dapMinimoController = TextEditingController(text: '10.0'); // Valor padrão

  Future<void> _criarInventario() async {
    if (_formKey.currentState!.validate()) {
      final inventario = Inventario(
        nome: _nomeController.text,
        numeroBlocos: int.parse(_blocosController.text),
        numeroParcelas: int.parse(_parcelasController.text),
        numeroFaixas: int.parse(_faixasController.text),
        dapMinimo: double.parse(_dapMinimoController.text), // NOVO
        dataCriacao: DateTime.now(),
      );

      final dbHelper = DatabaseHelper();
      final inventarioId = await dbHelper.insertInventario(inventario);

      // Gerar combinações de parcelas
      final parcelas = <Parcela>[];
      for (int bloco = 1; bloco <= inventario.numeroBlocos; bloco++) {
        for (int parcelaNum = 1; parcelaNum <= inventario.numeroParcelas; parcelaNum++) {
          for (int faixa = 1; faixa <= inventario.numeroFaixas; faixa++) {
            parcelas.add(Parcela(
              inventarioId: inventarioId,
              bloco: bloco,
              parcela: parcelaNum,
              faixa: faixa,
            ));
          }
        }
      }

      await dbHelper.insertParcelas(parcelas);

      // Navegar para a tela de parcelas
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => ListaParcelasScreen(inventarioId: inventarioId),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Novo Inventário'),
        backgroundColor: Colors.green,
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nomeController,
                decoration: InputDecoration(
                  labelText: 'Nome do Inventário',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor, insira um nome';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _blocosController,
                decoration: InputDecoration(
                  labelText: 'Número de Blocos',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor, insira o número de blocos';
                  }
                  if (int.tryParse(value) == null) {
                    return 'Por favor, insira um número válido';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _parcelasController,
                decoration: InputDecoration(
                  labelText: 'Número de Parcelas',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor, insira o número de parcelas';
                  }
                  if (int.tryParse(value) == null) {
                    return 'Por favor, insira um número válido';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _faixasController,
                decoration: InputDecoration(
                  labelText: 'Número de Faixas',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor, insira o número de faixas';
                  }
                  if (int.tryParse(value) == null) {
                    return 'Por favor, insira um número válido';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),
              // NOVO CAMPO: DAP Mínimo
              TextFormField(
                controller: _dapMinimoController,
                decoration: InputDecoration(
                  labelText: 'DAP Mínimo (cm)',
                  border: OutlineInputBorder(),
                  helperText: 'Árvores com DAP abaixo deste valor não serão incluídas',
                ),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor, insira o DAP mínimo';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Por favor, insira um número válido';
                  }
                  return null;
                },
              ),
              SizedBox(height: 24),
              ElevatedButton(
                onPressed: _criarInventario,
                child: Text('Criar Inventário'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}