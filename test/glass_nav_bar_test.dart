import 'package:community/widgets/glass_nav_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _items = [
  GlassNavItem(
    icon: Icons.home_outlined,
    selectedIcon: Icons.home,
    label: 'Home',
  ),
  GlassNavItem(icon: Icons.map_outlined, selectedIcon: Icons.map, label: 'Map'),
  GlassNavItem(
    icon: Icons.chat_outlined,
    selectedIcon: Icons.chat,
    label: 'Messages',
  ),
  GlassNavItem(
    icon: Icons.person_outline,
    selectedIcon: Icons.person,
    label: 'Me',
  ),
];

Widget _host({
  required int slot,
  required List<String> log,
  ValueChanged<int>? onMoved,
}) => MaterialApp(
  home: Scaffold(
    backgroundColor: const Color(0xFFFCFBFF),
    bottomNavigationBar: GlassNavBar(
      items: _items,
      selectedIndex: 0,
      onSelect: (i) => log.add('tab $i'),
      actionSlot: slot,
      onAction: () => log.add('action'),
      onActionMoved: onMoved ?? (s) => log.add('moved $s'),
    ),
  ),
);

void main() {
  testWidgets('Tapping the action and the tabs calls back', (tester) async {
    final log = <String>[];
    await tester.pumpWidget(_host(slot: 2, log: log));
    await tester.tap(find.byKey(const ValueKey('glass-nav-action')));
    await tester.tap(find.text('Map'));
    await tester.tap(find.text('Me'));
    expect(log, ['action', 'tab 1', 'tab 3']);
  });

  testWidgets('Dragging the action moves it and tabs make room', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final log = <String>[];
    var slot = 2;
    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) => _host(
          slot: slot,
          log: log,
          onMoved: (s) => setState(() {
            slot = s;
            log.add('moved $s');
          }),
        ),
      ),
    );
    final meBefore = tester.getCenter(find.text('Me')).dx;
    final action = find.byKey(const ValueKey('glass-nav-action'));
    // Slots are ~75px wide: drag two slots to the right.
    await tester.drag(action, const Offset(160, 0));
    await tester.pumpAndSettle();
    expect(log, ['moved 4']);
    // "Me" slid left into the space the button left behind.
    expect(tester.getCenter(find.text('Me')).dx, lessThan(meBefore));
    expect(
      tester.getCenter(action).dx,
      greaterThan(tester.getCenter(find.text('Me')).dx),
    );

    await tester.drag(action, const Offset(-400, 0));
    await tester.pumpAndSettle();
    expect(log.last, 'moved 0');
    expect(
      tester.getCenter(action).dx,
      lessThan(tester.getCenter(find.text('Home')).dx),
    );
  });
}
