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
}
