import 'package:flutter/material.dart';

import 'src/app.dart';
import 'src/features/steps/step_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Start pedometer in background — failures are handled gracefully inside.
  StepService.instance.init();
  runApp(const FlexiCurlApp());
}
