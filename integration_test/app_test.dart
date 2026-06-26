import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:swapscout/pages/trips_dashboard.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  
  late HttpServer server;
  String tripStatus = 'accepted';

  setUpAll(() async {
    // Start local server to mock API
    server = await HttpServer.bind('127.0.0.1', 8000);
    server.listen((HttpRequest request) {
      final path = request.uri.path;
      
      // Default headers
      request.response.headers.contentType = ContentType.json;
      
      if (path == '/users/me') {
        request.response
          ..statusCode = 200
          ..write(jsonEncode({'id': 1, 'name': 'Integration Test User'}))
          ..close();
      } else if (path == '/swap-requests/me') {
        request.response
          ..statusCode = 200
          ..write(jsonEncode([
            {
              'id': 999,
              'status': tripStatus,
              'host_id': 2,
              'requester_id': 1,
              'start_date': '2023-01-01',
              'end_date': '2023-01-05',
              'host': {'id': 2, 'name': 'Host'},
              'requester': {'id': 1, 'name': 'Test User'},
              'host_home': {'id': 10, 'title': 'Host Home'},
              'requester_home': {'id': 11, 'title': 'My Home'},
            }
          ]))
          ..close();
      } else if (path.startsWith('/reviews/swap-request/')) {
        // Return 404 to indicate no review has been left yet
        request.response
          ..statusCode = 404
          ..write('{"detail": "Not found"}')
          ..close();
      } else {
        request.response
          ..statusCode = 404
          ..close();
      }
    });
    
    // Set a dummy token to avoid auth errors in ApiClient
    const storage = FlutterSecureStorage();
    FlutterSecureStorage.setMockInitialValues({'access_token': 'dummy-token'});
  });

  tearDownAll(() async {
    await server.close(force: true);
  });

  testWidgets('test_tc_5_2_trust_review_lockout', (WidgetTester tester) async {
    // 1. Start with status 'accepted'
    tripStatus = 'accepted';
    
    // Pump the TripsDashboardPage
    await tester.pumpWidget(const MaterialApp(
      home: TripsDashboardPage(),
    ));
    await tester.pumpAndSettle();
    
    // Switch to 'Past Trips' tab
    await tester.tap(find.text('Past Trips'));
    await tester.pumpAndSettle();
    
    // Ensure "Leave Review" button is NOT visible 
    // (since it's accepted, it won't be in the past trips list)
    expect(find.text('Leave Review'), findsNothing);
    expect(find.byType(OutlinedButton), findsNothing);
    expect(find.text('No requests found.'), findsOneWidget); // because list is empty
    
    // 2. Update status to 'completed'
    tripStatus = 'completed';
    
    // 3. Trigger a reload by dragging the empty list to trigger RefreshIndicator
    await tester.drag(find.text('No requests found.'), const Offset(0, 300));
    await tester.pumpAndSettle();
    
    // 4. Assert "Leave Review" button is now visible and clickable
    expect(find.text('No requests found.'), findsNothing);
    expect(find.text('Leave Review'), findsOneWidget);
    expect(find.byType(OutlinedButton), findsWidgets);
  });
}
