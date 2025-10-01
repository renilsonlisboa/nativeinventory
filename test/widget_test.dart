import 'package:flutter_test/flutter_test.dart';
import 'package:nativeninventory/main.dart';

void main() {
  testWidgets('Teste básico do aplicativo', (WidgetTester tester) async {
    // CORREÇÃO: Remover o 'const' pois MyApp() não é um construtor constante
    await tester.pumpWidget(MyApp());

    // Verificar se o app inicia corretamente
    expect(find.text('Sistema de Inventário'), findsOneWidget);
    expect(find.text('Iniciar Novo Inventário'), findsOneWidget);
    expect(find.text('Continuar Inventário'), findsOneWidget);
  });

  testWidgets('Teste de navegação para novo inventário', (WidgetTester tester) async {
    await tester.pumpWidget(MyApp());

    // Verificar se o botão de novo inventário existe
    expect(find.text('Iniciar Novo Inventário'), findsOneWidget);

    // Clicar no botão de novo inventário
    await tester.tap(find.text('Iniciar Novo Inventário'));
    await tester.pumpAndSettle();

    // Verificar se navegou para a tela de novo inventário
    expect(find.text('Novo Inventário'), findsOneWidget);
    expect(find.text('Nome do Inventário'), findsOneWidget);
  });

  testWidgets('Teste de navegação para lista de inventários', (WidgetTester tester) async {
    await tester.pumpWidget(MyApp());

    // Verificar se o botão de continuar inventário existe
    expect(find.text('Continuar Inventário'), findsOneWidget);

    // Clicar no botão de continuar inventário
    await tester.tap(find.text('Continuar Inventário'));
    await tester.pumpAndSettle();

    // Verificar se navegou para a tela de lista de inventários
    expect(find.text('Inventários Existentes'), findsOneWidget);
  });
}