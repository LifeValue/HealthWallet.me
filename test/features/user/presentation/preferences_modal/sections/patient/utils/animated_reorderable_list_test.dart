import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_wallet/features/user/presentation/preferences_modal/sections/patient/utils/animated_reorderable_list.dart';

const _rowHeight = 50.0;
const _spacing = 8.0;

const _slideDelay = Duration(milliseconds: 180);
const _animation = Duration(milliseconds: 225);
const _fadeDelay = Duration(milliseconds: 90);

/// A frame at 60 fps. An animation ends on the first frame after its
/// duration, so a move is only over a frame or two after its timings add up.
const _frame = Duration(milliseconds: 16);
final _wholeMove = _slideDelay + _animation + _fadeDelay + _frame * 3;

void main() {
  late List<(String, int, int)> reorders;

  setUp(() => reorders = []);

  /// Shows [items] as rows of text saying whether each is being moved.
  Future<void> showList(
    WidgetTester tester,
    List<String> items, {
    bool reportReorders = true,
  }) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: AnimatedReorderableList<String>(
          items: items,
          itemIdExtractor: (item) => item,
          itemHeight: _rowHeight,
          itemSpacing: _spacing,
          onReorder: reportReorders
              ? (id, from, to) => reorders.add((id, from, to))
              : null,
          itemBuilder: (context, item, index, isBeingMoved) => SizedBox(
            height: _rowHeight,
            child: Text('$index $item${isBeingMoved ? ' moving' : ''}'),
          ),
        ),
      ),
    ),
  );

  /// Moves the row [from] to where [to] is, as the list's owner would.
  void reorder(WidgetTester tester, String from, String to) {
    // The state class is private to the list; handleReorder is its only way
    // in.
    final dynamic list = tester.state(
      find.byType(AnimatedReorderableList<String>),
    );
    list.handleReorder(from, to);
  }

  Finder row(String text) => find.text(text);

  /// Draws frames at 60 fps for [duration].
  Future<void> play(WidgetTester tester, Duration duration) async {
    for (var t = Duration.zero; t < duration; t += _frame) {
      await tester.pump(_frame);
    }
  }

  /// How far the row is shifted down (up when negative).
  double slideOf(WidgetTester tester, String text) => tester
      .widget<Transform>(
        find.ancestor(of: row(text), matching: find.byType(Transform)).first,
      )
      .transform
      .getTranslation()
      .y;

  double opacityOf(WidgetTester tester, String text) => tester
      .widget<Opacity>(
        find.ancestor(of: row(text), matching: find.byType(Opacity)).first,
      )
      .opacity;

  testWidgets('shows every item in order, none of them moving', (
    tester,
  ) async {
    await showList(tester, ['a', 'b', 'c']);

    expect(row('0 a'), findsOneWidget);
    expect(row('1 b'), findsOneWidget);
    expect(row('2 c'), findsOneWidget);
    expect(find.textContaining('moving'), findsNothing);
    expect(
      tester.getTopLeft(row('1 b')).dy - tester.getTopLeft(row('0 a')).dy,
      _rowHeight,
    );
  });

  testWidgets('moving an item reports where it moved from and to', (
    tester,
  ) async {
    await showList(tester, ['a', 'b', 'c']);

    reorder(tester, 'c', 'a');
    expect(reorders, [('c', 2, 0)]);

    // The move runs on its own timers; let it end before the test does.
    await play(tester, _wholeMove);
  });

  testWidgets('moving an item onto itself or to an item not listed does '
      'nothing', (tester) async {
    await showList(tester, ['a', 'b', 'c']);

    reorder(tester, 'b', 'b');
    reorder(tester, 'b', 'z');
    reorder(tester, 'z', 'a');
    await tester.pump(const Duration(seconds: 1));
    await showList(tester, ['a', 'b', 'c']);

    expect(reorders, isEmpty);
    expect(find.textContaining('moving'), findsNothing);
  });

  testWidgets('a moved item waits, slides across the rows it passes while '
      'faded, then comes back in place', (tester) async {
    await showList(tester, ['a', 'b', 'c']);

    reorder(tester, 'c', 'a');
    await tester.pump();

    // Still waiting: drawn as usual when the list is drawn again.
    await tester.pump(_slideDelay - const Duration(milliseconds: 10));
    await showList(tester, ['a', 'b', 'c']);
    expect(row('2 c'), findsOneWidget);

    // Halfway: shifted up toward the first row and faded.
    await tester.pump(const Duration(milliseconds: 10));
    await tester.pump(_animation ~/ 2);
    await showList(tester, ['a', 'b', 'c']);
    expect(row('2 c moving'), findsOneWidget);
    expect(row('0 a'), findsOneWidget);
    final halfway = slideOf(tester, '2 c moving');
    expect(halfway, lessThan(0));
    expect(halfway, greaterThan(-2 * (_rowHeight + _spacing)));
    expect(opacityOf(tester, '2 c moving'), closeTo(0.3, 0.01));

    // Done, and put back after a short pause.
    await tester.pump(_animation);
    await tester.pump(_fadeDelay);
    await showList(tester, ['a', 'b', 'c']);
    expect(row('2 c'), findsOneWidget);
    expect(find.textContaining('moving'), findsNothing);
  });

  testWidgets('a moved item slides down when it moves down the list', (
    tester,
  ) async {
    await showList(tester, ['a', 'b', 'c'], reportReorders: false);

    reorder(tester, 'a', 'b');
    await tester.pump();
    await tester.pump(_slideDelay);
    await tester.pump(_animation * 0.8);
    await showList(tester, ['a', 'b', 'c'], reportReorders: false);

    expect(slideOf(tester, '0 a moving'), greaterThan(0));
    expect(reorders, isEmpty);

    await play(tester, _wholeMove);
  });

  testWidgets('an item removed before it starts moving is left alone', (
    tester,
  ) async {
    await showList(tester, ['a', 'b', 'c']);

    reorder(tester, 'c', 'a');
    await showList(tester, ['a', 'b']);
    await play(tester, _wholeMove);

    expect(row('0 a'), findsOneWidget);
    expect(row('1 b'), findsOneWidget);
    expect(find.textContaining('c'), findsNothing);
    expect(find.textContaining('moving'), findsNothing);
  });

  testWidgets('items added later are shown, and the list can be closed '
      'while showing them', (tester) async {
    await showList(tester, ['a']);
    await showList(tester, ['b', 'a', 'd']);

    expect(row('0 b'), findsOneWidget);
    expect(row('2 d'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    expect(find.byType(AnimatedReorderableList<String>), findsNothing);
  });
}
