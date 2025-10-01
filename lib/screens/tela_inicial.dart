import 'package:flutter/material.dart';
import 'novo_inventario_screen.dart';
import 'lista_inventarios_screen.dart';

class TelaInicial extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Sistema de Inventário'),
        backgroundColor: Colors.green,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/forest_icon.png',
              height: 150,
              width: 150,
            ),
            SizedBox(height: 50),
            SizedBox(
              width: 250,
              height: 60,
              child: ElevatedButton.icon(
                icon: Icon(Icons.add_circle_outline),
                label: Text('Iniciar Novo Inventário', style: TextStyle(fontSize: 16)),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => NovoInventarioScreen()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green, // CORREÇÃO AQUI
                ),
              ),
            ),
            SizedBox(height: 20),
            SizedBox(
              width: 250,
              height: 60,
              child: ElevatedButton.icon(
                icon: Icon(Icons.play_arrow),
                label: Text('Continuar Inventário', style: TextStyle(fontSize: 16)),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => ListaInventariosScreen()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue, // CORREÇÃO AQUI
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}