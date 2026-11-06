import 'package:community/widgets/overlap_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Content over the header can be tapped where they overlap', (
    tester,
  ) async {
    final taps = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              OverlapHeader(
                overlap: 30,
                header: GestureDetector(
                  onTap: () => taps.add('header'),
                  child: Container(height: 100, color: Colors.purple),
                ),
                child: GestureDetector(
                  key: const ValueKey('body'),
                  onTap: () => taps.add('body'),
                  child: Container(height: 80, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    final body = tester.getRect(find.byKey(const ValueKey('body')));
    // The body starts 30 px up inside the header…
    expect(body.top, 70);
    // …and a tap in that overlapping band reaches the body.
    await tester.tapAt(Offset(body.center.dx, body.top + 10));
    // Above the overlap, the header still gets taps.
    await tester.tapAt(Offset(body.center.dx, 20));
    expect(taps, ['body', 'header']);
    // Total height: header 100 + body 80 − overlap 30.
    expect(tester.getSize(find.byType(OverlapHeader)).height, 150);
  });

  testWidgets('PinnedHeader keeps the header still while the body scrolls', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final taps = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PinnedHeader(
            overlap: 28,
            header: Container(
              key: const ValueKey('header'),
              height: 150,
              color: Colors.purple,
            ),
            body: ListView(
              children: [
                for (var i = 0; i < 30; i++)
                  GestureDetector(
                    onTap: () => taps.add('row $i'),
                    child: SizedBox(height: 60, child: Text('Row $i')),
                  ),
              ],
            ),
          ),
        ),
      ),
    );

    final headerBefore = tester.getRect(find.byKey(const ValueKey('header')));
    final rowBefore = tester.getTopLeft(find.text('Row 5'));
    // The sheet starts 28 px up, over the header's lower edge, and the
    // list starts a small gap below the sheet's rounded edge.
    expect(
      tester.getTopLeft(find.text('Row 0')).dy,
      150 - 28 + PinnedHeader.topGap,
    );

    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pumpAndSettle();

    // Header did not move; the content did.
    expect(tester.getRect(find.byKey(const ValueKey('header'))), headerBefore);
    // (The drag gesture uses its first few pixels to start, so ~280.)
    expect(
      tester.getTopLeft(find.text('Row 5')).dy,
      lessThan(rowBefore.dy - 250),
    );

    // A tap in the overlap band reaches the list, not the header.
    await tester.tapAt(const Offset(20, 150 - 28 + PinnedHeader.topGap + 10));
    expect(taps, hasLength(1));
  });
}
