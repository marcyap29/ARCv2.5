import 'package:flutter/foundation.dart';
import 'package:my_app/main/bootstrap.dart';
import 'package:my_app/models/enums/flavor.dart';
import 'package:my_app/app/app.dart';

void main() {
  // Automatically detect environment: debug = development, release = production
  final flavor = kDebugMode ? Flavor.development : Flavor.production;
  
  bootstrap(
    builder: () => const App(),
    flavor: flavor,
  );
}