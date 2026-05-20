import 'package:flutter/material.dart';
import '../models/parcela.dart';
import '../database/database_helper.dart';

class AdicionarParcelasScreen extends StatefulWidget {
  final int inventarioId;

  const AdicionarParcelasScreen({Key? key, required this.inventarioId})
      : super(key: key);

  @override
  _AdicionarParcelasScreenState createState() =>
      _AdicionarParcelasScreenState();
}

class _AdicionarParcelasScreenState extends State<AdicionarParcelasScreen> {
  final _formKey = GlobalKey<FormState>();

  final _qtdBlocosController = TextEditingController();
  final _inicioBlocoController = TextEditingController(text: '1');
  final _qtdParcelasController = TextEditingController();
  final _inicioParcelaController = TextEditingController(text: '1');
  final _qtdFaixasController = TextEditingController();
  final _inicioFaixaController = TextEditingController(text: '1');

  bool _salvando = false;
  List<_PreviewItem> _preview = [];
  bool _mostrarPreview = false;
  List<Parcela> _parcelasExistentes = [];

  @override
  void initState() {
    super.initState();
    _carregarParcelasExistentes();
  }

  @override
  void dispose() {
    _qtdBlocosController.dispose();
    _inicioBlocoController.dispose();
    _qtdParcelasController.dispose();
    _inicioParcelaController.dispose();
    _qtdFaixasController.dispose();
    _inicioFaixaController.dispose();
    super.dispose();
  }

  Future<void> _carregarParcelasExistentes() async {
    final parcelas = await DatabaseHelper()
        .getParcelasByInventario(widget.inventarioId);
    setState(() {
      _parcelasExistentes = parcelas;
    });
  }

  void _gerarPreview() {
    if (!_formKey.currentState!.validate()) return;

    final qtdBlocos = int.parse(_qtdBlocosController.text.trim());
    final inicioBloco = int.parse(_inicioBlocoController.text.trim());
    final qtdParcelas = int.parse(_qtdParcelasController.text.trim());
    final inicioParcela = int.parse(_inicioParcelaController.text.trim());
    final qtdFaixas = int.parse(_qtdFaixasController.text.trim());
    final inicioFaixa = int.parse(_inicioFaixaController.text.trim());

    final itens = <_PreviewItem>[];

    for (int b = inicioBloco; b < inicioBloco + qtdBlocos; b++) {
      for (int p = inicioParcela; p < inicioParcela + qtdParcelas; p++) {
        for (int f = inicioFaixa; f < inicioFaixa + qtdFaixas; f++) {
          final identificador = 'B${b}P${p}F$f';
          final jaExiste = _parcelasExistentes.any(
                (e) => e.bloco == b && e.parcela == p && e.faixa == f,
          );
          itens.add(_PreviewItem(
            bloco: b,
            parcela: p,
            faixa: f,
            identificador: identificador,
            duplicada: jaExiste,
          ));
        }
      }
    }

    setState(() {
      _preview = itens;
      _mostrarPreview = true;
    });
  }

  Future<void> _salvar() async {
    if (_preview.isEmpty) return;

    final itensSalvar = _preview.where((i) => !i.duplicada).toList();

    if (itensSalvar.isEmpty) {
      _mostrarSnack(
        'Todas as combinações já existem neste inventário.',
        Colors.orange.shade700,
      );
      return;
    }

    setState(() => _salvando = true);

    try {
      final db = DatabaseHelper();
      int salvos = 0;

      for (final item in itensSalvar) {
        final novaParcela = Parcela(
          inventarioId: widget.inventarioId,
          bloco: item.bloco,
          parcela: item.parcela,
          faixa: item.faixa,
          concluida: false,
        );
        await db.insertParcela(novaParcela);
        salvos++;
      }

      _mostrarSnack(
        '$salvos parcela(s) adicionada(s) com sucesso!',
        Colors.green.shade700,
      );

      await Future.delayed(const Duration(milliseconds: 800));
      if (mounted) Navigator.of(context).pop(true); // retorna true = houve mudança
    } catch (e) {
      _mostrarSnack('Erro ao salvar: $e', Colors.red.shade700);
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  void _mostrarSnack(String mensagem, Color cor) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensagem),
        backgroundColor: cor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ─── Blocos existentes para referência ──────────────────────────────────────
  Widget _buildResumoExistente() {
    if (_parcelasExistentes.isEmpty) return const SizedBox.shrink();

    final blocos = _parcelasExistentes.map((p) => p.bloco).toSet().toList()
      ..sort();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Blocos já cadastrados',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: blocos
                  .map(
                    (b) => Chip(
                  label: Text(
                    'Bloco $b  (${_parcelasExistentes.where((p) => p.bloco == b).length} parcelas)',
                    style: TextStyle(color: Colors.blue.shade800, fontSize: 12),
                  ),
                  backgroundColor: Colors.blue.shade100,
                  side: BorderSide(color: Colors.blue.shade200),
                ),
              )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Formulário ─────────────────────────────────────────────────────────────
  Widget _buildFormulario() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 4,
      shadowColor: Colors.black26,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.add_box, color: Colors.green.shade700),
                  const SizedBox(width: 8),
                  Text(
                    'Novo bloco / faixas',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Qtd. Blocos + Bloco Inicial
              Row(
                children: [
                  Expanded(
                    child: _buildCampoNumerico(
                      controller: _qtdBlocosController,
                      label: 'Qtd. Blocos',
                      icon: Icons.grid_view,
                      hint: 'Ex: 1',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildCampoNumerico(
                      controller: _inicioBlocoController,
                      label: 'Bloco inicial',
                      icon: Icons.start,
                      hint: 'Ex: 1',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Qtd. Parcelas + Parcela Inicial
              Row(
                children: [
                  Expanded(
                    child: _buildCampoNumerico(
                      controller: _qtdParcelasController,
                      label: 'Qtd. Parcelas',
                      icon: Icons.view_agenda,
                      hint: 'Ex: 4',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildCampoNumerico(
                      controller: _inicioParcelaController,
                      label: 'Parcela inicial',
                      icon: Icons.start,
                      hint: 'Ex: 1',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Quantidade de faixas e início
              Row(
                children: [
                  Expanded(
                    child: _buildCampoNumerico(
                      controller: _qtdFaixasController,
                      label: 'Qtd. Faixas',
                      icon: Icons.view_stream,
                      hint: 'Ex: 5',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildCampoNumerico(
                      controller: _inicioFaixaController,
                      label: 'Faixa inicial',
                      icon: Icons.start,
                      hint: 'Ex: 1',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.preview),
                  label: const Text('Gerar pré-visualização'),
                  onPressed: _gerarPreview,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.green.shade800,
                    side: BorderSide(color: Colors.green.shade700, width: 1.5),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCampoNumerico({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required String hint,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: Colors.green.shade700, size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.green.shade700, width: 2),
        ),
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
      validator: (v) {
        if (v == null || v.trim().isEmpty) return 'Obrigatório';
        final n = int.tryParse(v.trim());
        if (n == null || n < 1) return 'Mín: 1';
        return null;
      },
    );
  }

  // ─── Pré-visualização ────────────────────────────────────────────────────────
  Widget _buildPreview() {
    if (!_mostrarPreview || _preview.isEmpty) return const SizedBox.shrink();

    final novas = _preview.where((i) => !i.duplicada).length;
    final duplicadas = _preview.where((i) => i.duplicada).length;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 4,
      shadowColor: Colors.black26,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.list_alt, color: Colors.green.shade700),
                const SizedBox(width: 8),
                Text(
                  'Pré-visualização (${_preview.length} combinações)',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Resumo
            Row(
              children: [
                _buildBadge('$novas novas', Colors.green),
                const SizedBox(width: 8),
                if (duplicadas > 0)
                  _buildBadge('$duplicadas já existem', Colors.orange),
              ],
            ),
            const SizedBox(height: 12),

            // Lista compacta em grid
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _preview
                  .map(
                    (item) => Chip(
                  label: Text(
                    item.identificador,
                    style: TextStyle(
                      fontSize: 12,
                      color: item.duplicada
                          ? Colors.orange.shade800
                          : Colors.green.shade900,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  backgroundColor: item.duplicada
                      ? Colors.orange.shade50
                      : Colors.green.shade50,
                  side: BorderSide(
                    color: item.duplicada
                        ? Colors.orange.shade300
                        : Colors.green.shade300,
                  ),
                  avatar: Icon(
                    item.duplicada ? Icons.warning_amber : Icons.forest,
                    size: 14,
                    color: item.duplicada
                        ? Colors.orange.shade700
                        : Colors.green.shade700,
                  ),
                ),
              )
                  .toList(),
            ),

            if (duplicadas > 0) ...[
              const SizedBox(height: 10),
              Text(
                '⚠ As combinações em laranja já existem e serão ignoradas.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.orange.shade800,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],

            const SizedBox(height: 16),

            // Botão salvar
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: _salvando
                    ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
                    : const Icon(Icons.save),
                label: Text(
                  _salvando
                      ? 'Salvando...'
                      : 'Salvar $novas parcela(s)',
                ),
                onPressed: _salvando || novas == 0 ? null : _salvar,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade700,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade300,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  textStyle: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadge(String texto, MaterialColor cor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: cor.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cor.shade300),
      ),
      child: Text(
        texto,
        style: TextStyle(
            fontSize: 12, fontWeight: FontWeight.w600, color: cor.shade800),
      ),
    );
  }

  // ─── Build ───────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Adicionar Parcelas',
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
            colors: [Colors.green.shade50, Colors.blue.shade50],
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 16),
          children: [
            _buildResumoExistente(),
            _buildFormulario(),
            _buildPreview(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _PreviewItem {
  final int bloco;
  final int parcela;
  final int faixa;
  final String identificador;
  final bool duplicada;

  _PreviewItem({
    required this.bloco,
    required this.parcela,
    required this.faixa,
    required this.identificador,
    required this.duplicada,
  });
}