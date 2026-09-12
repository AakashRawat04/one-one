import 'package:flutter_test/flutter_test.dart';

import 'package:one_one_app/one_one.dart';

void main() {
  testWidgets('startup underlay matches native splash color and has no logo', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: BrandSplashScreen()));

    expect(find.byType(Image), findsNothing);

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.backgroundColor, BrandSplashScreen.backgroundColor);
  });

  testWidgets('GoogleAuthScreen initializing does not paint a Flutter logo', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: GoogleAuthScreen(initializing: true)),
    );

    expect(find.byType(Image), findsNothing);
    expect(find.text('Welcome to Duo'), findsNothing);
    expect(find.byType(BrandSplashScreen), findsOneWidget);
  });

  testWidgets('welcome screen uses localized copy', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(393, 873),
        minTextAdapt: true,
        builder: (context, child) {
          return MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('en'),
            home: child,
          );
        },
        child: const GoogleAuthScreen(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Welcome to Duo'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.byType(BrandSplashScreen), findsNothing);
  });
}
