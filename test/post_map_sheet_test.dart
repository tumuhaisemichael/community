import 'package:community/models/community_post.dart';
import 'package:community/repositories/post_repository.dart';
import 'package:community/services/auth_service.dart';
import 'package:community/widgets/post_card.dart';
import 'package:community/widgets/post_map_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

class _Auth implements AuthService {
  @override
  dynamic noSuchMethod(Invocation i) => null;
}

void main() {
  testWidgets('View on map opens a pull-up map on the same page', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    // Map tiles cannot download in tests; ignore only those image errors.
    final original = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.library == 'image resource service') return;
      original?.call(details);
    };
    addTearDown(() => FlutterError.onError = original);
    final observer = _RouteCounter();
    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: [observer],
        home: Scaffold(
          body: SingleChildScrollView(
            child: PostCard(
              post: CommunityPost(
                id: '1',
                authorName: 'Maya',
                authorId: 'a',
                content: 'Someone checking car doors',
                createdAt: DateTime.now(),
                likes: 0,
                category: PostCategory.suspiciousPerson,
                severity: PostSeverity.high,
                latitude: 0.35,
                longitude: 32.583,
              ),
              authService: _Auth(),
              postRepository: const ExamplePostRepository(),
              currentLocation: const LatLng(0.3476, 32.5825),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('View on map'));
    await tester.pumpAndSettle();

    expect(find.byType(PostMapSheet), findsOneWidget);
    expect(find.text('Get directions'), findsOneWidget);
    // Opened as a sheet over the card, not as a new full page.
    expect(observer.pushedPages, 0);
    expect(find.byType(PostCard), findsOneWidget);

    final close = find.byTooltip('Close');
    await tester.tap(close);
    await tester.pumpAndSettle();
    expect(find.byType(PostMapSheet), findsNothing);
  });
}

class _RouteCounter extends NavigatorObserver {
  int pushedPages = 0;
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PageRoute && previousRoute != null) pushedPages++;
  }
}
