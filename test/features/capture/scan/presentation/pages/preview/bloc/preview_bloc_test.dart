import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/features/capture/scan/presentation/pages/preview/bloc/preview_bloc.dart';
import 'package:image/image.dart' as img;

import '../../../../../../../helpers/log_capture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final logs = captureLogs();
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('hw_preview_bloc_'));
  tearDown(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  PreviewBloc initialized(List<String> images, {PageRotatedCallback? onTurn}) {
    final bloc = PreviewBloc(onPageRotated: onTurn);
    addTearDown(bloc.close);
    bloc.add(PreviewInitialized(initialPageIndex: 0, images: images));
    return bloc;
  }

  Future<ui.Image> decode(String path) async {
    final codec = await ui.instantiateImageCodec(File(path).readAsBytesSync());
    return (await codec.getNextFrame()).image;
  }

  test('starts with the given pages and page', () async {
    final bloc = PreviewBloc();
    addTearDown(bloc.close);

    bloc.add(const PreviewInitialized(initialPageIndex: 1, images: ['a', 'b']));
    await pumpEventQueue();

    expect(bloc.state.images, ['a', 'b']);
    expect(bloc.state.currentPageIndex, 1);
    expect(bloc.state.hasChanges, isFalse);
  });

  test('follows the page shown', () async {
    final bloc = initialized(['a', 'b']);

    bloc.add(const PreviewPageChanged(pageIndex: 1));
    await pumpEventQueue();

    expect(bloc.state.currentPageIndex, 1);
  });

  test('a deleted page leaves the list; the last one stays', () async {
    final bloc = initialized(['a', 'b']);

    bloc.add(const PreviewPageChanged(pageIndex: 1));
    bloc.add(const PreviewPageDeleted(pageIndex: 1));
    await pumpEventQueue();
    expect(bloc.state.images, ['a']);
    expect(bloc.state.currentPageIndex, 0);
    expect(bloc.state.hasChanges, isTrue);

    bloc.add(const PreviewPageDeleted(pageIndex: 0));
    await pumpEventQueue();
    expect(bloc.state.images, ['a']);
  });

  test('pages are reordered', () async {
    final bloc = initialized(['a', 'b', 'c']);

    bloc.add(const PreviewPagesReordered(oldIndex: 0, newIndex: 2));
    await pumpEventQueue();

    expect(bloc.state.images, ['b', 'c', 'a']);
    expect(bloc.state.hasChanges, isTrue);
  });

  test('reorder mode goes back to the first page when it ends', () async {
    final bloc = initialized(['a', 'b']);

    bloc.add(const PreviewPageChanged(pageIndex: 1));
    bloc.add(const PreviewReorderModeToggled(enabled: true));
    await pumpEventQueue();
    expect(bloc.state.isReordering, isTrue);
    expect(bloc.state.currentPageIndex, 1);

    bloc.add(const PreviewReorderModeToggled(enabled: false));
    await pumpEventQueue();
    expect(bloc.state.isReordering, isFalse);
    expect(bloc.state.currentPageIndex, 0);
  });

  testWidgets('a turned page is turned on disk and reported', (tester) async {
    final page = File('${dir.path}/page.png')
      ..writeAsBytesSync(img.encodePng(img.Image(width: 4, height: 2)));
    final turns = <(String, int)>[];

    await tester.runAsync(() async {
      final bloc = initialized([
        page.path,
      ], onTurn: (path, quarterTurns) => turns.add((path, quarterTurns)));
      bloc.add(const PreviewPageRotated(pageIndex: 0));
      await bloc.stream.firstWhere((s) => s.hasChanges);

      final turned = await decode(page.path);
      expect((turned.width, turned.height), (2, 4));
      expect(bloc.state.isRotating, isFalse);
    });

    expect(turns, [(page.path, 1)]);
  });

  testWidgets('a page that cannot be turned is logged and not reported', (
    tester,
  ) async {
    final page = File('${dir.path}/page.png')..writeAsBytesSync([1, 2, 3]);
    final turns = <(String, int)>[];

    await tester.runAsync(() async {
      final bloc = initialized([
        page.path,
      ], onTurn: (path, quarterTurns) => turns.add((path, quarterTurns)));
      bloc.add(const PreviewPageRotated(pageIndex: 0));
      await bloc.stream.firstWhere((s) => s.isRotating);
      await bloc.stream.firstWhere((s) => !s.isRotating);

      expect(bloc.state.hasChanges, isFalse);
    });

    expect(turns, isEmpty);
    expect(logs, loggedWarning('Turning the preview page failed'));
  });

  test('a second turn while one runs is dropped', () async {
    final bloc = initialized(['missing.png']);
    await pumpEventQueue();

    bloc
      ..add(const PreviewPageRotated(pageIndex: 0))
      ..add(const PreviewPageRotated(pageIndex: 0));
    await bloc.stream.firstWhere((s) => !s.isRotating);
    await pumpEventQueue();

    expect(
      logs.where((e) => '${e.message}'.contains('Turning the preview page')),
      hasLength(1),
    );
  });
}
