import 'package:block/main.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Stands in for the Kotlin side, answering with the same shapes it sends.
void _mockNative(TestWidgetsFlutterBinding binding) {
  binding.defaultBinaryMessenger.setMockMethodCallHandler(
    const MethodChannel('com.example.block/native'),
    (call) async {
      switch (call.method) {
        case 'getInstalledApps':
          return [
            {'package': 'com.instagram.android', 'label': 'Instagram', 'icon': null},
            {'package': 'com.google.android.youtube', 'label': 'YouTube', 'icon': null},
            {'package': 'com.twitter.android', 'label': 'X', 'icon': null},
          ];
        case 'isServiceEnabled':
          return true;
        default:
          return null;
      }
    },
  );
}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    _mockNative(binding);
  });

  /// A tall phone-ish surface so the whole editor is built without scrolling.
  void tallScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(600, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  testWidgets('create a block with a website and see it on the home screen',
      (tester) async {
    tallScreen(tester);
    await tester.pumpWidget(const ProviderScope(child: BlockApp()));
    await tester.pumpAndSettle();

    expect(find.text('How it works'), findsOneWidget);

    await tester.tap(find.text('Create your first block'));
    await tester.pumpAndSettle();
    expect(find.text('Time slot'), findsOneWidget);

    // Saving with nothing selected is rejected with a clear message.
    await tester.tap(find.text('Lock it in'));
    await tester.pumpAndSettle();
    expect(find.text('Add at least one app or website to block.'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'Study time');
    await tester.enterText(
        find.byType(TextField).last, 'https://www.youtube.com/watch?v=1');
    await tester.tap(find.byTooltip('Add'));
    await tester.pumpAndSettle();
    expect(find.text('youtube.com'), findsOneWidget);

    await tester.tap(find.text('Lock it in'));
    // Not pumpAndSettle: depending on the real clock the new block may be
    // live, and a live card pulses forever.
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 400));
    }

    expect(find.text('Study time'), findsOneWidget);
    expect(find.text('youtube.com'), findsOneWidget);
    expect(find.text('Your blocks'), findsOneWidget);
    expect(find.text('How it works'), findsNothing);
  });

  testWidgets('rejects something that is not a website', (tester) async {
    tallScreen(tester);
    await tester.pumpWidget(const ProviderScope(child: BlockApp()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create your first block'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).last, 'not a site');
    await tester.tap(find.byTooltip('Add'));
    await tester.pumpAndSettle();
    expect(find.textContaining("doesn't look like a website"), findsOneWidget);
  });

  testWidgets('a deep link previews as the whole site, and offers its app',
      (tester) async {
    tallScreen(tester);
    await tester.pumpWidget(const ProviderScope(child: BlockApp()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create your first block'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).last, 'https://x.com/home?ref=1');
    await tester.pumpAndSettle();
    expect(find.textContaining('Blocks everything on x.com'), findsOneWidget);

    await tester.tap(find.byTooltip('Add'));
    await tester.pumpAndSettle();
    expect(find.text('x.com'), findsOneWidget); // stored as the bare site

    // X's own app would open x.com/home directly, so it is suggested.
    expect(find.textContaining('opens these links too'), findsOneWidget);
    await tester.tap(find.text('Block app'));
    await tester.pumpAndSettle();
    expect(find.textContaining('opens these links too'), findsNothing);
    expect(find.text('Change apps'), findsOneWidget);
    // Let flutter_animate's just-started timer for the new chip fire.
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('pick apps from the installed list', (tester) async {
    tallScreen(tester);
    await tester.pumpWidget(const ProviderScope(child: BlockApp()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Create your first block'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose apps'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'insta');
    await tester.pumpAndSettle();
    expect(find.text('Instagram'), findsOneWidget);
    expect(find.text('YouTube'), findsNothing);

    await tester.tap(find.text('Instagram'));
    await tester.pumpAndSettle();
    expect(find.text('Add 1 app'), findsOneWidget);
    await tester.tap(find.text('Add 1 app'));
    await tester.pumpAndSettle();

    expect(find.text('Instagram'), findsOneWidget); // now a tag in the editor
    expect(find.text('Change apps'), findsOneWidget);
  });

  testWidgets('time wheel sets the start time', (tester) async {
    tallScreen(tester);
    await tester.pumpWidget(const ProviderScope(child: BlockApp()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create your first block'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('From'));
    await tester.pumpAndSettle();
    expect(find.text('Block starts at'), findsOneWidget);

    await tester.tap(find.text('Set time'));
    await tester.pumpAndSettle();
    expect(find.text('Block starts at'), findsNothing);
    expect(find.textContaining('9:00'), findsWidgets);
  });
}
