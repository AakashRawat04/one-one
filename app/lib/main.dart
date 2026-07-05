import 'package:flutter/widgets.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import 'phase1_spike/phase1_spike_app.dart';

void main() {
  FlutterForegroundTask.initCommunicationPort();
  runApp(const OneOnePhase1App());
}
