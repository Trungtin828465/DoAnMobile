// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:doan/screens/room_designer_screen.dart';

void main() {
  testWidgets('Room designer renders and allows adding an item', (
    WidgetTester tester,
  ) async {
    tester.binding.window.physicalSizeTestValue = const Size(1400, 2200);
    tester.binding.window.devicePixelRatioTestValue = 1.0;
    addTearDown(() {
      tester.binding.window.clearPhysicalSizeTestValue();
      tester.binding.window.clearDevicePixelRatioTestValue();
    });

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: RoomDesignerScreen())),
    );

    expect(find.text('Room 3D Designer'), findsOneWidget);
    expect(find.text('Sofa'), findsOneWidget);

    await tester.tap(find.text('Tao nen phong'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sofa'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Dang chon:'), findsOneWidget);
  });
}
