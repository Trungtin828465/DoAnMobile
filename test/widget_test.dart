import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:doan/models/user_model.dart';
import 'package:doan/screens/room_layout_screen.dart';

void main() {
  testWidgets('Room layout setup form renders', (WidgetTester tester) async {
    tester.binding.window.physicalSizeTestValue = const Size(1400, 2200);
    tester.binding.window.devicePixelRatioTestValue = 1.0;
    addTearDown(() {
      tester.binding.window.clearPhysicalSizeTestValue();
      tester.binding.window.clearDevicePixelRatioTestValue();
    });

    final testUser = User(
      id: 'test-user-id',
      email: 'test@example.com',
      fullName: 'Test User',
      createdAt: DateTime(2026, 1, 1),
    );

    await tester.pumpWidget(
      MaterialApp(home: RoomLayoutScreen(user: testUser)),
    );

    expect(find.text('Phòng'), findsOneWidget);
    expect(find.text('Kích thước phòng'), findsOneWidget);
    expect(find.text('Chiều dài (W), mm'), findsOneWidget);
    expect(find.text('Chiều rộng (D), mm'), findsOneWidget);
    expect(find.text('Chiều cao (H), mm'), findsOneWidget);
    expect(find.text('Tạo phòng'), findsOneWidget);
  });
}
