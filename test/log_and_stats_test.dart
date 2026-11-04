import 'package:community/models/community_post.dart';
import 'package:community/repositories/post_repository.dart';
import 'package:community/screens/safety_log_screen.dart';
import 'package:community/screens/statistics_dashboard_screen.dart';
import 'package:community/services/auth_service.dart';
import 'package:community/widgets/stat_widgets.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _User implements User {
  @override
  String get uid => 'me';
  @override
  dynamic noSuchMethod(Invocation i) => null;
}

class _Auth implements AuthService {
  @override
  User? get currentUser => _User();
  @override
  dynamic noSuchMethod(Invocation i) => null;
}

final _now = DateTime.now();

CommunityPost _post(
  String id,
  String author,
  int daysAgo,
  List<PostCategory> categories,
  PostSeverity severity,
) => CommunityPost(
  id: id,
  authorName: author,
  authorId: author,
  content: 'Report $id',
  createdAt: _now.subtract(Duration(days: daysAgo, minutes: 5)),
  likes: 0,
  category: categories.first,
  categories: categories,
  severity: severity,
);

class _Repo extends ExamplePostRepository {
  @override
  Stream<List<CommunityPost>> getPostsStream() => Stream.value([
    _post('1', 'me', 0, [PostCategory.theft], PostSeverity.high),
    _post('2', 'me', 3, [
      PostCategory.theft,
      PostCategory.assault,
    ], PostSeverity.critical),
    _post('3', 'me', 20, [PostCategory.fire], PostSeverity.low),
    _post('4', 'aisha', 1, [PostCategory.vandalism], PostSeverity.medium),
    _post('5', 'aisha', 60, [PostCategory.theft], PostSeverity.low),
    // Announcements are not incidents.
    _post('6', 'aisha', 0, [PostCategory.general], PostSeverity.low),
  ]);
}

void main() {
  testWidgets('Safety log shows only your reports, with filters', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: SafetyLogScreen(authService: _Auth(), postRepository: _Repo()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('You have reported 3 incidents.'), findsOneWidget);
    expect(find.bySemanticsLabel('3 Total reports'), findsOneWidget);
    expect(find.bySemanticsLabel('2 This week'), findsOneWidget);
    expect(find.bySemanticsLabel('2 Urgent'), findsOneWidget);
    expect(find.text('Report 4'), findsNothing); // someone else's

    await tester.tap(find.widgetWithText(FilterPill, 'Urgent'));
    await tester.pumpAndSettle();
    expect(find.text('Report 3'), findsNothing); // routine
    expect(find.text('Report 1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Crime stats: ranges, types and severity', (tester) async {
    tester.view.physicalSize = const Size(390, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(home: StatisticsDashboardScreen(postRepository: _Repo())),
    );
    await tester.pumpAndSettle();

    // Default: last 30 days → posts 1–4 (not the 60-day one or the
    // announcement).
    expect(find.bySemanticsLabel('4 Incidents'), findsOneWidget);
    expect(find.bySemanticsLabel('2 Urgent or critical'), findsOneWidget);
    // Theft counted in posts 1 and 2 → most common.
    expect(find.bySemanticsLabel('Theft Most common'), findsOneWidget);
    expect(find.bySemanticsLabel('Theft: 2'), findsOneWidget);
    expect(find.bySemanticsLabel('Assault: 1'), findsOneWidget);

    await tester.tap(find.text('7 days'));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('3 Incidents'), findsOneWidget);

    await tester.tap(find.text('All time'));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('5 Incidents'), findsOneWidget);
    expect(find.bySemanticsLabel('Theft: 3'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
