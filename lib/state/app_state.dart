import 'package:flutter/foundation.dart';

class AppSharedState {
  static final ValueNotifier<int> pendingRequestsCount = ValueNotifier<int>(0);
}
