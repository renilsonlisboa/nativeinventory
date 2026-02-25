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
        title: Text(
          'Editar ${widget.parcela.identificador}',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.green.shade700,
        elevation: 4,
        shadowColor: Colors.black26,
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _salvarParcela,
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
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                // Área rolável com os cards e campos
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Card de identificação da parcela
                        Card(
                          elevation: 4,
                          shadowColor: Colors.black26,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.info, color: Colors.blue.shade700),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Identificação da Parcela',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue.shade800,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                _buildInfoRow('Bloco', widget.parcela.bloco.toString()),
                                _buildInfoRow('Parcela', widget.parcela.parcela.toString()),
                                _buildInfoRow('Faixa', widget.parcela.faixa.toString()),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Campo Valor das Árvores
                        Card(
                          elevation: 4,
                          shadowColor: Colors.black26,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Informações da Parcela',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green.shade800,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: _valorController,
                                  decoration: InputDecoration(
                                    labelText: 'Observações Adicionais',
                                    prefixIcon: Icon(Icons.add_alert, color: Colors.green.shade700),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(color: Colors.grey.shade300),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(color: Colors.green.shade700, width: 2),
                                    ),
                                    filled: true,
                                    fillColor: Colors.white.withOpacity(0.9),
                                  ),
                                  maxLines: 3,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Switch de concluída
                        Card(
                          elevation: 4,
                          shadowColor: Colors.black26,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: SwitchListTile(
                            title: Text(
                              'Parcela Concluída',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey.shade800,
                              ),
                            ),
                            value: _concluida,
                            onChanged: (bool value) {
                              setState(() {
                                _concluida = value;
                              });
                            },
                            secondary: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: _concluida ? Colors.green.shade100 : Colors.grey.shade200,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                _concluida ? Icons.check_circle : Icons.radio_button_unchecked,
                                color: _concluida ? Colors.green.shade700 : Colors.grey.shade700,
                              ),
                            ),
                            activeColor: Colors.green.shade700,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          ),
                        ),
                        // Espaço extra no final para garantir que o conteúdo não fique escondido atrás do botão
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),

                // Botão Salvar fixo na parte inferior
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton.icon(
                    onPressed: _salvarParcela,
                    icon: const Icon(Icons.save, size: 24),
                    label: const Text(
                      'Salvar Parcela',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      foregroundColor: Colors.white,
                      elevation: 8,
                      shadowColor: Colors.green.shade700.withOpacity(0.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: Colors.grey.shade900,
            ),
          ),
        ],
      ),
    );
  }
}