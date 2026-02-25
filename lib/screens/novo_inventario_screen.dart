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
  final _areaController = TextEditingController();
  final _blocosController = TextEditingController();
  final _parcelasController = TextEditingController();
  final _faixasController = TextEditingController();
  final _anoMedicaoController = TextEditingController();
  final _dapMinimoController = TextEditingController(text: '10.0');

  @override
  void initState() {
    super.initState();
    _anoMedicaoController.text = DateTime.now().year.toString();
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _areaController.dispose();
    _blocosController.dispose();
    _parcelasController.dispose();
    _faixasController.dispose();
    _anoMedicaoController.dispose();
    _dapMinimoController.dispose();
    super.dispose();
  }

  Future<void> _criarInventario() async {
    if (_formKey.currentState!.validate()) {
      try {
        final inventario = Inventario(
          nome: _nomeController.text,
          areaInventariada: double.parse(_areaController.text),
          numeroBlocos: int.parse(_blocosController.text),
          numeroParcelas: int.parse(_parcelasController.text),
          numeroFaixas: int.parse(_faixasController.text),
          ano: int.parse(_anoMedicaoController.text),
          dapMinimo: double.parse(_dapMinimoController.text),
          dataCriacao: DateTime.now(),
        );

        final dbHelper = DatabaseHelper();
        final inventarioId = await dbHelper.insertInventario(inventario);

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

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ListaParcelasScreen(inventarioId: inventarioId),
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao criar inventário: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Novo Inventário',
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                // Card principal com o formulário
                Card(
                  elevation: 4,
                  shadowColor: Colors.black26,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Título do formulário
                        Text(
                          'Informações do Inventário',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade800,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Preencha os dados para criar um novo inventário florestal',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        SizedBox(height: 24),

                        // Campo Nome
                        _buildTextField(
                          controller: _nomeController,
                          label: 'Título do Inventário',
                          icon: Icons.forest,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Por favor, insira um nome';
                            }
                            return null;
                          },
                        ),
                        SizedBox(height: 16),

                        // Campo Área
                        _buildTextField(
                          controller: _areaController,
                          label: 'Área do Inventário (ha)',
                          icon: Icons.square_foot,
                          keyboardType: TextInputType.numberWithOptions(decimal: true),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Por favor, insira a área';
                            }
                            if (double.tryParse(value) == null) {
                              return 'Por favor, insira um número válido';
                            }
                            return null;
                          },
                        ),
                        SizedBox(height: 16),

                        // Campo Blocos
                        _buildTextField(
                          controller: _blocosController,
                          label: 'Número de Blocos',
                          icon: Icons.grid_view,
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

                        // Campo Parcelas
                        _buildTextField(
                          controller: _parcelasController,
                          label: 'Número de Parcelas',
                          icon: Icons.view_agenda,
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

                        // Campo Faixas
                        _buildTextField(
                          controller: _faixasController,
                          label: 'Número de Faixas',
                          icon: Icons.view_stream,
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

                        // Campo Ano
                        _buildTextField(
                          controller: _anoMedicaoController,
                          label: 'Ano da Medição',
                          icon: Icons.calendar_today,
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Por favor, insira o ano da medição';
                            }
                            final year = int.tryParse(value);
                            if (year == null) {
                              return 'Por favor, insira um ano válido';
                            }
                            if (year < 1900 || year > DateTime.now().year + 1) {
                              return 'Ano fora do intervalo esperado';
                            }
                            return null;
                          },
                        ),
                        SizedBox(height: 16),

                        // Campo DAP Mínimo
                        _buildTextField(
                          controller: _dapMinimoController,
                          label: 'DAP Mínimo (cm)',
                          icon: Icons.straighten,
                          keyboardType: TextInputType.numberWithOptions(decimal: true),
                          helperText: 'Árvores com DAP abaixo deste valor não serão incluídas',
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
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 24),

                // Botão Criar (verde)
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton.icon(
                    onPressed: _criarInventario,
                    icon: Icon(Icons.add_circle_outline, size: 24),
                    label: Text(
                      'Criar Inventário',
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
                      padding: EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                    ),
                  ),
                ),
                SizedBox(height: 12),

                // Botão Cancelar (delineado)
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.cancel_outlined, color: Colors.blue.shade700),
                    label: Text(
                      'Cancelar',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.blue.shade700,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.blue.shade700, width: 1.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                    ),
                  ),
                ),
                SizedBox(height: 16),

                // Texto de rodapé
                Text(
                  'Todos os campos são obrigatórios',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Método auxiliar para construir campos de texto padronizados
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    String? helperText,
    required String? Function(String?) validator,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey.shade700),
        prefixIcon: Icon(icon, color: Colors.green.shade700),
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
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.red.shade700),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.red.shade700, width: 2),
        ),
        helperText: helperText,
        helperStyle: TextStyle(color: Colors.grey.shade600, fontSize: 12),
        filled: true,
        fillColor: Colors.white.withOpacity(0.9),
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      keyboardType: keyboardType,
      validator: validator,
    );
  }
}