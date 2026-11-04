import 'package:community/models/community_post.dart';
import 'package:community/repositories/post_repository.dart';
import 'package:community/screens/report_incident_screen.dart';
import 'package:community/services/auth_service.dart';
import 'package:community/services/storage_service.dart';
import 'package:community/widgets/post_media.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';

class _Auth implements AuthService {
  @override
  dynamic noSuchMethod(Invocation i) => null;
}

class _FailingStorage implements StorageService {
  @override
  Future<List<String>> uploadImages(List<XFile> images) async =>
      throw Exception('bucket not found');

  @override
  dynamic noSuchMethod(Invocation i) => null;
}

class _Repo extends ExamplePostRepository {
  final posted = <CommunityPost>[];
  @override
  Future<void> addPost(CommunityPost post) async => posted.add(post);
}

void main() {
  test('Categories are saved and read back', () {
    final post = CommunityPost(
      id: '',
      authorName: 'A',
      authorId: 'a',
      content: 'x',
      createdAt: DateTime(2026),
      likes: 0,
      category: PostCategory.theft,
      categories: const [PostCategory.theft, PostCategory.assault],
    );
    final map = post.toMap();
    expect(map['category'], 'theft');
    expect(map['categories'], ['theft', 'assault']);

    final read = CommunityPost.fromMap(map, 'id');
    expect(read.categories, [PostCategory.theft, PostCategory.assault]);
    expect(read.categoriesLabel, 'Theft, Assault');

    // Older posts saved before multi-select only have "category".
    final old = CommunityPost.fromMap({'category': 'fire'}, 'id');
    expect(old.categories, [PostCategory.fire]);
  });

  testWidgets('Posts without photos show the bundled default image', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PostImages(
          post: CommunityPost(
            id: '1',
            authorName: 'A',
            authorId: 'a',
            content: 'x',
            createdAt: DateTime(2026),
            likes: 0,
          ),
        ),
      ),
    );
    final image = tester.widget<Image>(find.byType(Image));
    expect((image.image as AssetImage).assetName, kDefaultPostImage);
  });

  testWidgets('Several categories can be picked and are posted together', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(420, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = _Repo();
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ReportIncidentScreen(
                      authService: _Auth(),
                      postRepository: repo,
                      initialLocation: const LatLng(0.3, 32.5),
                      storageService: _FailingStorage(),
                    ),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('Theft'));
    await tester.tap(find.bySemanticsLabel('Assault'));
    await tester.tap(find.bySemanticsLabel('Fire'));
    await tester.tap(find.bySemanticsLabel('Fire')); // tap again to remove
    await tester.pump();
    await tester.enterText(find.byType(TextFormField), 'Two men took a bag');
    await tester.tap(find.text('Post report'));
    await tester.pumpAndSettle();

    expect(repo.posted, hasLength(1));
    expect(repo.posted.single.category, PostCategory.theft);
    expect(repo.posted.single.categories, [
      PostCategory.theft,
      PostCategory.assault,
    ]);
  });
}
