import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vangogh/app/aprimorar_video_app.dart';
import 'package:vangogh/features/trim/presentation/widgets/trim_timeline.dart';

Future<void> _skipLaunch(WidgetTester tester) async {
  await tester.tap(find.text('Pular'));
  await tester.pumpAndSettle();
}

Future<void> _boot(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const ProviderScope(child: AprimorarVideoApp()));
}

Future<void> _scrollTo(WidgetTester tester, Finder target) async {
  await tester.scrollUntilVisible(
    target,
    200,
    scrollable: find.byType(Scrollable).first,
  );
}

Finder _tab(String label) =>
    find.descendant(of: find.byType(Row).last, matching: find.text(label));

void main() {
  testWidgets('abertura cinematográfica pode ser pulada', (tester) async {
    await _boot(tester);

    expect(find.text('VANGOGH'), findsOneWidget);
    expect(find.text('ESTÚDIO DE CINEMA NO SEU BOLSO'), findsOneWidget);

    await _skipLaunch(tester);
    expect(find.text('Importar vídeo ou fotos'), findsOneWidget);
  });

  testWidgets('a abertura termina sozinha', (tester) async {
    await _boot(tester);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text('Importar vídeo ou fotos'), findsOneWidget);
  });

  testWidgets('estúdio mostra as três ferramentas', (tester) async {
    await _boot(tester);
    await _skipLaunch(tester);

    expect(find.text('Seu vídeo,\nnível cinema.'), findsOneWidget);
    await _scrollTo(tester, find.text('Melhores momentos'));
    expect(find.text('Aprimorar'), findsWidgets);
    expect(find.text('Melhores momentos'), findsOneWidget);
    expect(find.text('Cortar'), findsWidgets);
  });

  testWidgets('navega pelas abas', (tester) async {
    await _boot(tester);
    await _skipLaunch(tester);

    await tester.tap(_tab('Aprimorar'));
    await tester.pumpAndSettle();
    expect(find.text('Traga um vídeo ou fotos'), findsOneWidget);
    expect(find.text('Vídeo'), findsOneWidget);
    expect(find.text('Fotos'), findsOneWidget);

    await tester.tap(_tab('Momentos'));
    await tester.pumpAndSettle();
    expect(find.text('Escolha um vídeo longo'), findsOneWidget);

    await tester.tap(_tab('Cortar'));
    await tester.pumpAndSettle();
    expect(find.text('Escolha um vídeo para começar'), findsOneWidget);
    expect(find.byType(TrimTimeline), findsNothing);

    await tester.tap(_tab('Biblioteca'));
    await tester.pumpAndSettle();
    expect(find.text('Nada por aqui ainda'), findsOneWidget);
  });

  testWidgets('ferramenta da tela inicial abre a aba certa', (tester) async {
    await _boot(tester);
    await _skipLaunch(tester);

    await _scrollTo(tester, find.text('Melhores momentos'));
    await tester.tap(find.text('Melhores momentos'));
    await tester.pumpAndSettle();
    expect(find.text('Escolha um vídeo longo'), findsOneWidget);
  });
}
