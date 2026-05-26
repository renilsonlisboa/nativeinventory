import 'package:flutter/material.dart';
import '../models/parcela.dart';
import '../database/database_helper.dart';
import 'lista_parcelas_screen.dart';

class ListaBlocosScreen extends StatefulWidget {
  final int inventarioId;
  final String nomeInventario;

  const ListaBlocosScreen({
    Key? key,
    required this.inventarioId,
    required this.nomeInventario,
  }) : super(key: key);

  @override
  _ListaBlocosScreenState createState() => _ListaBlocosScreenState();
}

class _ListaBlocosScreenState extends State<ListaBlocosScreen> {
  List<_BlocoInfo> _blocos = [];
  bool _carregando = true;

  @override
  void initState() {
    super.initState();
    _carregarBlocos();
  }

  Future<void> _carregarBlocos() async {
    setState(() => _carregando = true);

    try {
      final parcelas =
      await DatabaseHelper().getParcelasByInventario(widget.inventarioId);

      // Agrupa por número de bloco
      final Map<int, List<Parcela>> porBloco = {};
      for (final p in parcelas) {
        porBloco.putIfAbsent(p.bloco, () => []).add(p);
      }

      final blocos = porBloco.entries.map((e) {
        final total = e.value.length;
        final concluidas = e.value.where((p) => p.concluida).length;
        return _BlocoInfo(
          numero: e.key,
          totalParcelas: total,
          parcelasConcluidas: concluidas,
        );
      }).toList()
        ..sort((a, b) => a.numero.compareTo(b.numero));

      setState(() {
        _blocos = blocos;
        _carregando = false;
      });
    } catch (e) {
      setState(() => _carregando = false);
    }
  }

  void _abrirParcelas(int bloco) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ListaParcelasScreen(
          inventarioId: widget.inventarioId,
          filtroBloco: bloco,
        ),
      ),
    ).then((_) => _carregarBlocos());
  }

  Future<void> _marcarBlocoConcluido(_BlocoInfo bloco, bool concluir) async {
    final acao = concluir ? 'concluir' : 'reabrir';
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              concluir ? Icons.check_circle_outline : Icons.undo,
              color: concluir ? Colors.green.shade700 : Colors.orange.shade700,
            ),
            const SizedBox(width: 8),
            Text(concluir ? 'Concluir bloco' : 'Reabrir bloco'),
          ],
        ),
        content: Text(
          concluir
              ? 'Deseja marcar todas as ${bloco.totalParcelas} parcelas do Bloco ${bloco.numero} como concluídas?'
              : 'Deseja reabrir todas as parcelas do Bloco ${bloco.numero}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor:
              concluir ? Colors.green.shade700 : Colors.orange.shade700,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(concluir ? 'Concluir' : 'Reabrir'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    try {
      final parcelas = await DatabaseHelper()
          .getParcelasByInventario(widget.inventarioId);
      final parcelasDoBloco =
      parcelas.where((p) => p.bloco == bloco.numero).toList();

      for (final parcela in parcelasDoBloco) {
        final atualizada = parcela.copyWith(concluida: concluir);
        await DatabaseHelper().updateParcela(atualizada);
      }

      await _carregarBlocos();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              concluir
                  ? 'Bloco ${bloco.numero} marcado como concluído!'
                  : 'Bloco ${bloco.numero} reaberto!',
            ),
            backgroundColor:
            concluir ? Colors.green.shade700 : Colors.orange.shade700,
            behavior: SnackBarBehavior.floating,
            shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao $acao o bloco: $e'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
          widget.nomeInventario,
          style: const TextStyle(fontWeight: FontWeight.w600),
          overflow: TextOverflow.ellipsis,
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
        child: _carregando
            ? Center(
          child: CircularProgressIndicator(
            valueColor:
            AlwaysStoppedAnimation<Color>(Colors.green.shade700),
          ),
        )
            : _blocos.isEmpty
            ? Center(
          child: Card(
            elevation: 4,
            shadowColor: Colors.black26,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            margin: const EdgeInsets.all(24),
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.grid_view,
                      size: 64, color: Colors.green.shade200),
                  const SizedBox(height: 16),
                  Text(
                    'Nenhum bloco encontrado.',
                    style: TextStyle(
                        fontSize: 18, color: Colors.grey.shade700),
                  ),
                ],
              ),
            ),
          ),
        )
            : Column(
          children: [
            // Lista de blocos
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                itemCount: _blocos.length,
                itemBuilder: (context, index) {
                  final bloco = _blocos[index];
                  return _buildBlocoCard(bloco);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBlocoCard(_BlocoInfo bloco) {
    final progresso = bloco.totalParcelas > 0
        ? bloco.parcelasConcluidas / bloco.totalParcelas
        : 0.0;

    final corProgresso = progresso >= 1.0
        ? Colors.green.shade700
        : progresso > 0.5
        ? Colors.blue.shade700
        : progresso > 0.0
        ? Colors.orange.shade700
        : Colors.grey.shade400;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      elevation: 4,
      shadowColor: Colors.black26,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () => _abrirParcelas(bloco.numero),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              // Ícone circular
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: progresso >= 1.0
                      ? Colors.green.shade100
                      : Colors.grey.shade200,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  progresso >= 1.0 ? Icons.check_circle : Icons.grid_view,
                  color: progresso >= 1.0
                      ? Colors.green.shade700
                      : Colors.grey.shade700,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              // Conteúdo
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bloco ${bloco.numero}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: progresso,
                        backgroundColor: Colors.grey.shade300,
                        valueColor:
                        AlwaysStoppedAnimation<Color>(corProgresso),
                        minHeight: 7,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${bloco.parcelasConcluidas} de ${bloco.totalParcelas} parcelas concluídas',
                      style: TextStyle(
                        fontSize: 13,
                        color: progresso >= 1.0
                            ? Colors.green.shade700
                            : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              // Botão de concluir / reabrir
              IconButton(
                tooltip: progresso >= 1.0 ? 'Reabrir bloco' : 'Concluir bloco',
                style: IconButton.styleFrom(
                  backgroundColor: progresso >= 1.0
                      ? Colors.green.shade100
                      : Colors.grey.shade100,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                icon: Icon(
                  progresso >= 1.0 ? Icons.check_circle : Icons.check_circle_outline,
                  color: progresso >= 1.0
                      ? Colors.green.shade700
                      : Colors.grey.shade500,
                  size: 26,
                ),
                onPressed: () =>
                    _marcarBlocoConcluido(bloco, progresso < 1.0),
              ),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }
}

class _BlocoInfo {
  final int numero;
  final int totalParcelas;
  final int parcelasConcluidas;

  _BlocoInfo({
    required this.numero,
    required this.totalParcelas,
    required this.parcelasConcluidas,
  });
}