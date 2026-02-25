import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Import necessário para SystemChrome
import 'screens/tela_inicial.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Configura o modo imersivo para ocultar a barra de navegação e status
  SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.immersiveSticky, // Modo imersivo com gesto para reaparecer
  );
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sistema de Inventário',
      theme: ThemeData(
        primarySwatch: Colors.green,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: TelaInicial(),
    );
  }
}