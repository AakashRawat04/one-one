import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';

import 'spike_keys.dart';
import 'walkie_foreground_task.dart';

class OneOnePhase1App extends StatelessWidget {
  const OneOnePhase1App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'One One',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xff00c2a8),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: const WithForegroundTask(child: Phase1SpikeScreen()),
    );
  }
}

class Phase1SpikeScreen extends StatefulWidget {
  const Phase1SpikeScreen({super.key});

  @override
  State<Phase1SpikeScreen> createState() => _Phase1SpikeScreenState();
}

class _Phase1SpikeScreenState extends State<Phase1SpikeScreen> {
  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _tokenController = TextEditingController();
  final List<String> _events = <String>[];

  String _serviceState = 'idle';
  String _permissionState = 'not checked';
  String _heartbeat = 'none';
  bool _isBusy = false;

  @override
  void initState() {
    super.initState();
    FlutterForegroundTask.addTaskDataCallback(_onTaskData);
    _initForegroundService();
    _refreshServiceState();
  }

  @override
  void dispose() {
    FlutterForegroundTask.removeTaskDataCallback(_onTaskData);
    _urlController.dispose();
    _tokenController.dispose();
    super.dispose();
  }

  void _initForegroundService() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'walkie_service',
        channelName: 'Walkie online mode',
        channelDescription: 'Persistent notification while One One is online.',
        onlyAlertOnce: true,
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(5000),
        autoRunOnBoot: false,
        autoRunOnMyPackageReplaced: false,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  }

  Future<void> _refreshServiceState() async {
    bool running = false;
    try {
      running = await FlutterForegroundTask.isRunningService;
    } catch (error) {
      _addEvent('Service state unavailable in this environment: $error');
    }
    if (!mounted) return;
    setState(() {
      _serviceState = running ? 'service running' : 'idle';
    });
  }

  Future<void> _requestPermissions() async {
    setState(() {
      _isBusy = true;
      _permissionState = 'checking';
    });

    try {
      final notificationPermission =
          await FlutterForegroundTask.checkNotificationPermission();
      if (notificationPermission != NotificationPermission.granted) {
        await FlutterForegroundTask.requestNotificationPermission();
      }

      final micPermission = await Permission.microphone.request();

      if (Platform.isAndroid &&
          !await FlutterForegroundTask.isIgnoringBatteryOptimizations) {
        await FlutterForegroundTask.requestIgnoreBatteryOptimization();
      }

      final refreshedNotificationPermission =
          await FlutterForegroundTask.checkNotificationPermission();

      setState(() {
        _permissionState =
            'notifications: ${refreshedNotificationPermission.name}, '
            'mic: ${micPermission.name}';
      });
      _addEvent('Permissions checked: $_permissionState');
    } catch (error) {
      setState(() {
        _permissionState = 'permission error';
      });
      _addEvent('Permission error: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
        });
      }
    }
  }

  Future<void> _goOnline() async {
    final url = _urlController.text.trim();
    final token = _tokenController.text.trim();

    if (url.isEmpty || token.isEmpty) {
      _addEvent('LiveKit URL and token are required.');
      return;
    }

    setState(() {
      _isBusy = true;
      _serviceState = 'starting';
    });

    try {
      await FlutterForegroundTask.saveData(key: liveKitUrlKey, value: url);
      await FlutterForegroundTask.saveData(key: liveKitTokenKey, value: token);
      await FlutterForegroundTask.saveData(
        key: serviceSessionIdKey,
        value: const Uuid().v4(),
      );

      final running = await FlutterForegroundTask.isRunningService;
      final ServiceRequestResult result = running
          ? await FlutterForegroundTask.restartService()
          : await FlutterForegroundTask.startService(
              serviceId: 101,
              serviceTypes: const [
                ForegroundServiceTypes.mediaPlayback,
              ],
              notificationTitle: 'One One is online',
              notificationText: 'Connecting to LiveKit',
              notificationButtons: const [
                NotificationButton(id: 'stop', text: 'Go away'),
              ],
              notificationInitialRoute: '/',
              callback: walkieForegroundServiceCallback,
            );

      if (result is ServiceRequestFailure) {
        _addEvent('Failed to start foreground service: ${result.error}');
        setState(() {
          _serviceState = 'service start failed';
        });
      } else {
        _addEvent('Foreground service requested.');
        await _refreshServiceState();
      }
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
        });
      }
    }
  }

  Future<void> _goAway() async {
    setState(() {
      _isBusy = true;
      _serviceState = 'stopping';
    });

    try {
      FlutterForegroundTask.sendDataToTask({
        taskCommandKey: taskCommandDisconnect,
      });
      await FlutterForegroundTask.stopService();
      _addEvent('Foreground service stop requested.');
    } catch (error) {
      _addEvent('Failed to stop service cleanly: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
          _serviceState = 'idle';
        });
      }
    }
  }

  void _onTaskData(Object data) {
    if (data is! Map) {
      _addEvent('Task data: $data');
      return;
    }

    final type = data[taskEventTypeKey]?.toString() ?? 'event';
    final status = data[taskStatusKey]?.toString();
    final message = data[taskMessageKey]?.toString();
    final heartbeatCount = data[taskHeartbeatCountKey]?.toString();

    setState(() {
      if (status != null) {
        _serviceState = status;
      }
      if (heartbeatCount != null) {
        _heartbeat = heartbeatCount;
      }
    });

    final eventParts = <String>[type];
    if (status != null) {
      eventParts.add(status);
    }
    if (message != null && message.isNotEmpty) {
      eventParts.add(message);
    }
    if (heartbeatCount != null) {
      eventParts.add('heartbeat $heartbeatCount');
    }

    _addEvent(eventParts.join(' | '));
  }

  void _addEvent(String event) {
    if (!mounted) return;
    setState(() {
      _events.insert(0, '${TimeOfDay.now().format(context)}  $event');
      if (_events.length > 30) {
        _events.removeRange(30, _events.length);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Phase 1 Audio Spike'),
        backgroundColor: colors.inversePrimary,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _StatusPanel(
              serviceState: _serviceState,
              permissionState: _permissionState,
              heartbeat: _heartbeat,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _urlController,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'LiveKit URL',
                hintText: 'wss://your-livekit-host',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _tokenController,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Temporary LiveKit token',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton.icon(
                  onPressed: _isBusy ? null : _requestPermissions,
                  icon: const Icon(Icons.verified_user_outlined),
                  label: const Text('Check permissions'),
                ),
                FilledButton.icon(
                  onPressed: _isBusy ? null : _goOnline,
                  icon: const Icon(Icons.radio_button_checked),
                  label: const Text('Go online'),
                ),
                OutlinedButton.icon(
                  onPressed: _isBusy ? null : _goAway,
                  icon: const Icon(Icons.radio_button_unchecked),
                  label: const Text('Go away'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text('Event log', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (_events.isEmpty)
              const Text('No events yet.')
            else
              for (final event in _events)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(event),
                ),
          ],
        ),
      ),
    );
  }
}

class _StatusPanel extends StatelessWidget {
  const _StatusPanel({
    required this.serviceState,
    required this.permissionState,
    required this.heartbeat,
  });

  final String serviceState;
  final String permissionState;
  final String heartbeat;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Online receive mode',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          _StatusRow(label: 'Service', value: serviceState),
          _StatusRow(label: 'Permissions', value: permissionState),
          _StatusRow(label: 'Heartbeat', value: heartbeat),
        ],
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(label, style: Theme.of(context).textTheme.labelLarge),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
