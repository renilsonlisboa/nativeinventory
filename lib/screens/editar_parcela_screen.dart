import 'package:flutter/material.dart';
import '../models/parcela.dart';
import '../database/database_helper.dart';

class EditarParcelaScreen extends StatefulWidget {
  final Parcela parcela;

  const EditarParcelaScreen({Key? key, required this.parcela}) : super(key: key);

  @override
  _EditarParcelaScreenState createState() => _EditarParcelaScreenState();
}

class _EditarParcelaScreenState extends State<EditarParcelaScreen> {
  final _formKey = GlobalKey<FormState>();
  final _valorController = TextEditingController();
  bool _concluida = false;

  @override
  void initState() {
    super.initState();
    _valorController.text = widget.parcela.valorArvores ?? '';
    _concluida = widget.parcela.concluida;
  }

  Future<void> _salvarParcela() async {
    if (_formKey.currentState!.validate()) {
      final parcelaAtualizada = Parcela(
        id: widget.parcela.id,
        inventarioId: widget.parcela.inventarioId,
        bloco: widget.parcela.bloco,
        parcela: widget.parcela.parcela,
        faixa: widget.parcela.faixa,
        valorArvores: _valorController.text.isEmpty ? null : _valorController.text,
        concluida: _concluida,
      );

      await DatabaseHelper().updateParcela(parcelaAtualizada);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Editar ${widget.parcela.identificador}'),
        backgroundColor: Colors.green,
        actions: [
          IconButton(
            icon: Icon(Icons.save),
            onPressed: _salvarParcela,
          ),
        ],
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Identificação da Parcela',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text('Bloco: ${widget.parcela.bloco}'),
                      Text('Parcela: ${widget.parcela.parcela}'),
                      Text('Faixa: ${widget.parcela.faixa}'),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 20),
              TextFormField(
                controller: _valorController,
                decoration: InputDecoration(
                  labelText: 'Valor das Árvores',
                  hintText: 'Digite o valor encontrado na parcela...',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              SizedBox(height: 20),
              SwitchListTile(
                title: Text('Parcela Concluída'),
                value: _concluida,
                onChanged: (bool value) {
                  setState(() {
                    _concluida = value;
                  });
                },
                secondary: Icon(
                  _concluida ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: _concluida ? Colors.green : Colors.grey,
                ),
              ),
              SizedBox(height: 20),
              Center(
                child: ElevatedButton.icon(
                  icon: Icon(Icons.save),
                  label: Text('Salvar Parcela'),
                  onPressed: _salvarParcela,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green, // CORRIGIDO
                    padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}