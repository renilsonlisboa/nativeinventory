import 'package:flutter/material.dart';
import 'novo_inventario_screen.dart';
import 'lista_inventarios_screen.dart';
import '/services/reflora_service.dart';
import 'admin_taxonomia_screen.dart';

class TelaInicial extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // AppBar com verde principal e transparência suave
      appBar: AppBar(
        title: Text(
          'Sistema de Inventário Florestal',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.green.shade700,
        elevation: 4,
        shadowColor: Colors.black26,
        actions: [
          IconButton(
            icon: Icon(Icons.settings, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => AdminTaxonomiaScreen()),
              );
            },
            tooltip: 'Configurações de Taxonomia',
          ),
        ],
      ),
      // Fundo com gradiente suave (verde claro -> azul claro)
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
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.9),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.green.shade800.withOpacity(0.3),
                        blurRadius: 20,
                        spreadRadius: 2,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Image.asset(
                    'assets/images/teste_logo.png',
                    height: 140,
                    width: 140,
                  ),
                ),
                SizedBox(height: 40),
                Text(
                  'Bem-vindo ao seu APP de Inventário',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.black87,
                    fontWeight: FontWeight.w400,
                    letterSpacing: 0.5,
                  ),
                ),
                SizedBox(height: 48),
                // Botão principal (verde) - iniciar novo inventário
                _buildActionButton(
                  context,
                  icon: Icons.add_circle_outline,
                  label: 'Iniciar Novo Inventário',
                  color: Colors.green.shade700,
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => NovoInventarioScreen()),
                    );
                  },
                ),
                SizedBox(height: 20),
                // Botão secundário (azul) - continuar inventário
                _buildActionButton(
                  context,
                  icon: Icons.play_arrow,
                  label: 'Continuar Inventário',
                  color: Colors.blue.shade700,
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => ListaInventariosScreen()),
                    );
                  },
                ),
                SizedBox(height: 40),
                Text(
                  'Versão Alpha • Dados armazenados localmente',
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

  // Método auxiliar para criar botões padronizados com sombra e estilo arredondado
  Widget _buildActionButton(BuildContext context,
      {required IconData icon,
        required String label,
        required Color color,
        required VoidCallback onPressed}) {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton.icon(
        icon: Icon(icon, size: 26),
        label: Text(
          label,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          elevation: 8,
          shadowColor: color.withOpacity(0.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: EdgeInsets.symmetric(vertical: 12, horizontal: 24),
        ),
      ),
    );
  }
}