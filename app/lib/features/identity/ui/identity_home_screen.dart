import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:livekit_client/livekit_client.dart';

import '../../../app/accent_theme.dart';
import '../../../core/firebase/app_database.dart';
import '../../groups/data/group_repository.dart';
import '../../groups/ui/waiting_for_group_members_screen.dart';
import 'no_groups_screen.dart';
import '../../groups/models/group_invite_result.dart';
import '../../groups/models/group_member_summary.dart';
import '../../groups/models/group_summary.dart';
import '../../online/data/online_repository.dart';
import '../../online/models/online_session.dart';
import '../../talk/data/talk_repository.dart';
import '../../talk/models/talk_session.dart';
import '../data/identity_repository.dart';
import '../models/identity_session.dart';
import 'settings_screen.dart';

class IdentityHomeScreen extends StatefulWidget {
  const IdentityHomeScreen({
    super.key,
    required this.initialSession,
    required this.identityRepository,
  });

  final IdentitySession initialSession;
  final IdentityRepository identityRepository;

  @override
  State<IdentityHomeScreen> createState() => _IdentityHomeScreenState();
}

class _IdentityHomeScreenState extends State<IdentityHomeScreen> {
  final GroupRepository _groupRepository = GroupRepository();
  final OnlineRepository _onlineRepository = OnlineRepository();
  final TalkRepository _talkRepository = TalkRepository();
  final TextEditingController _groupNameController = TextEditingController(
    text: 'Friends',
  );
  final TextEditingController _inviteCodeController = TextEditingController();

  late IdentitySession _session = widget.initialSession;
  List<GroupSummary> _groups = const [];
  List<GroupMemberSummary> _members = const [];
  Map<String, _Availability> _availability = const {};
  GroupSummary? _selectedGroup;
  GroupInviteResult? _latestInvite;
  StreamSubscription<DatabaseEvent>? _availabilitySubscription;

  OnlineSession? _onlineSession;
  TalkSession? _talkSession;
  Room? _room;
  EventsListener<RoomEvent>? _roomListener;
  Timer? _heartbeatTimer;

  bool _loadingGroups = true;
  bool _busy = false;
  bool _talkBusy = false;
  String _state = 'away';
  String? _message;

  @override
  void initState() {
    super.initState();
    AccentThemeController.setAccentKey(_session.settings.accentColorKey);
    unawaited(_loadGroups());
  }

  @override
  void dispose() {
    _groupNameController.dispose();
    _inviteCodeController.dispose();
    _availabilitySubscription?.cancel();
    _heartbeatTimer?.cancel();
    final activeTalk = _talkSession;
    if (activeTalk != null) {
      unawaited(_talkRepository.stopTalk(activeTalk, reason: 'screen_closed'));
    }
    unawaited(_disconnectLiveKit());
    super.dispose();
  }

  Future<void> _loadGroups() async {
    setState(() => _loadingGroups = true);
    try {
      final resolution = await _groupRepository.resolveGroupEntry(_session.userId);
      if (!mounted) return;

      if (resolution.kind != GroupEntryKind.home &&
          (ModalRoute.of(context)?.isCurrent ?? true)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          unawaited(_replaceWithGroupEntry(resolution));
        });
        return;
      }

      final groups = resolution.groups;
      final selected = _resolveSelectedGroup(groups);

      if (!mounted) return;
      setState(() {
        _groups = groups;
        _selectedGroup = selected;
        _latestInvite = null;
        if (selected == null) {
          _members = const [];
          _availability = const {};
        }
      });

      // If this is the first load and the user has no groups, navigate
      // to the dedicated no-groups screen so the new UI is shown.
      if (groups.isEmpty && (ModalRoute.of(context)?.isCurrent ?? true)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _replaceWithGroupEntry(const GroupEntryResolution.noGroups());
        });
        return;
      }

      if (selected != null) {
        await _loadMembers(selected.groupId);
        _listenToAvailability(selected.groupId);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _message = error.toString());
    } finally {
      if (mounted && _loadingGroups) {
        setState(() => _loadingGroups = false);
      }
    }
  }

  Future<void> _replaceWithGroupEntry(GroupEntryResolution resolution) async {
    switch (resolution.kind) {
      case GroupEntryKind.noGroups:
        await Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => NoGroupsScreen(
              session: _session,
              identityRepository: widget.identityRepository,
            ),
          ),
        );
      case GroupEntryKind.waiting:
        final group = resolution.group!;
        final invite = await _groupRepository.createInvite(group.groupId);
        if (!mounted) return;
        await Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => WaitingForGroupMembersScreen(
              group: group,
              invite: invite,
              session: _session,
              identityRepository: widget.identityRepository,
            ),
          ),
        );
      case GroupEntryKind.home:
        break;
    }
  }

  Future<void> _loadMembers(String groupId) async {
    final members = await _groupRepository.loadGroupMembers(groupId);
    if (!mounted) return;
    setState(() => _members = members);
  }

  void _listenToAvailability(String groupId) {
    unawaited(_availabilitySubscription?.cancel());
    _availabilitySubscription = AppDatabase.instance()
        .ref('memberAvailability/$groupId')
        .onValue
        .listen((event) {
          final value = event.snapshot.value;
          final next = <String, _Availability>{};

          if (value is Map<Object?, Object?>) {
            for (final entry in value.entries) {
              final raw = entry.value;
              if (raw is Map<Object?, Object?>) {
                next[entry.key.toString()] = _Availability.fromJson(raw);
              }
            }
          }

          if (!mounted) return;
          setState(() => _availability = next);
        });
  }

  Future<void> _selectGroup(String groupId) async {
    final group = _groups.firstWhere((item) => item.groupId == groupId);
    setState(() {
      _selectedGroup = group;
      _latestInvite = null;
      _members = const [];
      _availability = const {};
    });
    await _loadMembers(group.groupId);
    _listenToAvailability(group.groupId);
  }

  Future<void> _createGroup() async {
    await _runBusy(() async {
      final group = await _groupRepository.createGroup(
        _groupNameController.text.trim(),
      );
      await _loadGroups();
      if (!mounted) return;
      setState(() {
        _selectedGroup = group;
        _message = 'Group ready';
      });
    });
  }

  Future<void> _joinInvite() async {
    await _runBusy(() async {
      final groupId = await _groupRepository.joinInvite(
        _inviteCodeController.text.trim(),
      );
      await _loadGroups();
      if (_groups.isEmpty) {
        throw StateError('Joined group, but group sync has not completed yet.');
      }
      final group = _groups.firstWhere(
        (item) => item.groupId == groupId,
        orElse: () => _selectedGroup ?? _groups.first,
      );
      await _selectGroup(group.groupId);
      if (!mounted) return;
      setState(() => _message = 'Joined group');
    });
  }

  Future<void> _createInvite() async {
    final group = _selectedGroup;
    if (group == null) return;

    await _runBusy(() async {
      final invite = await _groupRepository.createInvite(group.groupId);
      if (!mounted) return;
      setState(() {
        _latestInvite = invite;
        _message = 'Invite created';
      });
    });
  }

  Future<void> _goOnline() async {
    final group = _selectedGroup;
    if (group == null) {
      setState(() => _message = 'Create or join a group first.');
      return;
    }

    setState(() {
      _busy = true;
      _state = 'connecting';
      _message = null;
    });

    OnlineSession? createdSession;
    try {
      createdSession = await _onlineRepository.goOnline(
        identity: _session,
        group: group,
      );
      await _connectLiveKit(createdSession);
      await _onlineRepository.markLive(createdSession);
      _heartbeatTimer?.cancel();
      _heartbeatTimer = Timer.periodic(const Duration(seconds: 10), (_) {
        final activeSession = _onlineSession;
        if (activeSession != null) {
          unawaited(_onlineRepository.heartbeat(activeSession));
        }
      });

      if (!mounted) return;
      setState(() {
        _onlineSession = createdSession;
        _state = 'live';
        _message = 'Live';
      });
    } catch (error) {
      await _disconnectLiveKit();
      if (createdSession != null) {
        try {
          await _onlineRepository.goAway(createdSession);
        } catch (_) {
          // Best-effort cleanup after a failed connect.
        }
      }
      if (!mounted) return;
      setState(() {
        _state = 'away';
        _message = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _goAway() async {
    final session = _onlineSession;
    if (session == null) {
      setState(() => _state = 'away');
      return;
    }

    await _runBusy(() async {
      final activeTalk = _talkSession;
      if (activeTalk != null) {
        await _talkRepository.stopTalk(activeTalk, reason: 'going_away');
      }
      _heartbeatTimer?.cancel();
      _heartbeatTimer = null;
      await _disconnectLiveKit();
      await _onlineRepository.goAway(session);
      if (!mounted) return;
      setState(() {
        _onlineSession = null;
        _talkSession = null;
        _state = 'away';
        _message = 'Away';
      });
    });
  }

  Future<void> _startTalking() async {
    final session = _onlineSession;
    if (session == null || _talkSession != null || _talkBusy) return;

    setState(() {
      _talkBusy = true;
      _message = null;
    });

    TalkSession? startedTalk;
    try {
      startedTalk = await _talkRepository.startTalk(session);
      await _setMicrophoneEnabled(true);
      if (_session.settings.hapticsEnabled) {
        unawaited(HapticFeedback.mediumImpact());
      }
      if (!mounted) return;
      setState(() {
        _talkSession = startedTalk;
        _state = 'talking';
        _message = 'Talking';
      });
    } catch (error) {
      if (startedTalk != null) {
        await _talkRepository.stopTalk(startedTalk, reason: 'mic_failed');
      }
      if (!mounted) return;
      setState(() {
        _talkSession = null;
        _state = _onlineSession == null ? 'away' : 'live';
        _message = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() => _talkBusy = false);
      }
    }
  }

  Future<void> _stopTalking({String reason = 'released'}) async {
    final talkSession = _talkSession;
    if (talkSession == null) return;

    setState(() {
      _talkSession = null;
      _state = 'live';
    });

    Object? stopError;
    try {
      await _setMicrophoneEnabled(false);
    } catch (error) {
      stopError = error;
    }

    try {
      if (_session.settings.hapticsEnabled) {
        unawaited(HapticFeedback.selectionClick());
      }
      await _talkRepository.stopTalk(talkSession, reason: reason);
    } catch (error) {
      stopError ??= error;
    }

    if (stopError != null) {
      if (!mounted) return;
      setState(() => _message = 'Talk stop failed: $stopError');
    }
  }

  Future<void> _connectLiveKit(OnlineSession session) async {
    await _disconnectLiveKit();
    final speakerOn = _session.settings.audioOutputPreference != 'earpiece';
    final room = Room(
      roomOptions: RoomOptions(
        adaptiveStream: false,
        dynacast: false,
        defaultAudioOutputOptions: AudioOutputOptions(speakerOn: speakerOn),
      ),
    );

    _room = room;
    _attachRoomListener(room);

    setState(() {
      _state = 'connecting';
      _message = 'Connecting to LiveKit';
    });

    await room
        .connect(
          session.livekitServerUrl,
          session.livekitToken,
          connectOptions: const ConnectOptions(autoSubscribe: true),
        )
        .timeout(const Duration(seconds: 20));

    try {
      await room.setSpeakerOn(speakerOn);
    } catch (_) {
      // Non-fatal. LiveKit can still use the platform default route.
    }

    final localParticipant = room.localParticipant;
    if (localParticipant == null) {
      throw StateError('LiveKit connected without a local participant.');
    }

    await localParticipant
        .setMicrophoneEnabled(false)
        .timeout(const Duration(seconds: 8));
  }

  void _attachRoomListener(Room room) {
    _roomListener = room.createListener()
      ..on<RoomConnectedEvent>((_) {
        _setMessage('LiveKit connected');
      })
      ..on<RoomReconnectingEvent>((_) {
        _setStateAndMessage('reconnecting', 'LiveKit reconnecting');
      })
      ..on<RoomReconnectedEvent>((_) {
        _setStateAndMessage('live', 'LiveKit reconnected');
      })
      ..on<RoomDisconnectedEvent>((event) {
        _setStateAndMessage(
          'disconnected',
          'LiveKit disconnected: ${event.reason}',
        );
      })
      ..on<ParticipantConnectedEvent>((event) {
        _setMessage('${event.participant.identity} joined');
      })
      ..on<TrackSubscribedEvent>((event) {
        final isAudio = event.track is RemoteAudioTrack;
        _setMessage(
          isAudio
              ? 'Audio subscribed from ${event.participant.identity}'
              : 'Track subscribed from ${event.participant.identity}',
        );
      })
      ..on<ActiveSpeakersChangedEvent>((event) {
        final remoteSpeakers = event.speakers.where(
          (speaker) => speaker.identity != room.localParticipant?.identity,
        );
        if (remoteSpeakers.isNotEmpty) {
          _setMessage('Receiving voice');
        }
      });
  }

  Future<void> _disconnectLiveKit() async {
    final room = _room;
    _room = null;
    _roomListener?.dispose();
    _roomListener = null;

    try {
      final localParticipant = room?.localParticipant;
      if (localParticipant != null) {
        await localParticipant.setMicrophoneEnabled(false);
      }
    } catch (_) {
      // Ignore cleanup failures.
    }

    await room?.disconnect();
  }

  Future<void> _setMicrophoneEnabled(bool enabled) async {
    final participant = _room?.localParticipant;
    if (participant == null) {
      throw StateError('LiveKit is not connected yet.');
    }

    await participant
        .setMicrophoneEnabled(enabled)
        .timeout(const Duration(seconds: 8));
  }

  Future<void> _runBusy(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _message = null;
    });

    try {
      await action();
    } catch (error) {
      if (!mounted) return;
      setState(() => _message = error.toString());
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  void _setMessage(String message) {
    if (!mounted) return;
    setState(() => _message = message);
  }

  void _setStateAndMessage(String state, String message) {
    if (!mounted) return;
    setState(() {
      _state = state;
      _message = message;
    });
  }

  GroupSummary? _resolveSelectedGroup(List<GroupSummary> groups) {
    if (groups.isEmpty) return null;

    final currentGroup = _selectedGroup;
    if (currentGroup == null) return groups.first;

    for (final group in groups) {
      if (group.groupId == currentGroup.groupId) return group;
    }

    return groups.first;
  }

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SettingsScreen(
          session: _session,
          identityRepository: widget.identityRepository,
          onSessionChanged: (session) {
            setState(() => _session = session);
          },
        ),
      ),
    );
  }

  void _openSetupWarnings() {
    final warnings = _setupWarnings();
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            children: [
              Text('Setup', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              if (warnings.isEmpty)
                const _SetupLine(ok: true, text: 'Ready for foreground voice')
              else
                for (final warning in warnings)
                  _SetupLine(ok: false, text: warning),
              const SizedBox(height: 8),
              const _SetupLine(
                ok: false,
                text:
                    'Closed-app receive is not enabled in this simplified APK.',
              ),
            ],
          ),
        );
      },
    );
  }

  List<String> _setupWarnings() {
    final warnings = <String>[];
    if (_groups.isEmpty) {
      warnings.add('Create or join a group.');
    }
    if (!_session.device.micPermissionGranted && _onlineSession == null) {
      warnings.add('Microphone permission has not been confirmed.');
    }
    if (!_session.device.notificationPermissionGranted) {
      warnings.add(
        'Notification permission is missing for future background mode.',
      );
    }
    if (!_session.device.batteryOptimizationIgnored) {
      warnings.add('Battery optimization may interrupt background mode.');
    }
    return warnings;
  }

  _Availability get _currentAvailability {
    return _availability[_session.userId] ??
        _Availability(
          desiredState: _onlineSession == null ? 'away' : 'online',
          effectiveState: _state,
          canReceiveLiveAudio: _onlineSession != null,
        );
  }

  bool get _isOnline => _onlineSession != null;

  @override
  Widget build(BuildContext context) {
    final warnings = _setupWarnings();

    return Scaffold(
      appBar: AppBar(
        title: const Text('One One'),
        actions: [
          IconButton(
            tooltip: 'Setup',
            onPressed: _openSetupWarnings,
            icon: Icon(
              warnings.isEmpty
                  ? Icons.check_circle_outline
                  : Icons.error_outline,
            ),
          ),
          IconButton(
            tooltip: 'Settings',
            onPressed: _openSettings,
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadGroups,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
            children: [
              _StateHeader(
                displayName: _session.user.displayName,
                state: _state,
                availability: _currentAvailability,
              ),
              const SizedBox(height: 16),
              _GroupSection(
                loading: _loadingGroups,
                busy: _busy,
                groups: _groups,
                selectedGroup: _selectedGroup,
                groupNameController: _groupNameController,
                inviteCodeController: _inviteCodeController,
                latestInvite: _latestInvite,
                onSelectGroup: _selectGroup,
                onCreateGroup: _createGroup,
                onJoinInvite: _joinInvite,
                onCreateInvite: _createInvite,
              ),
              const SizedBox(height: 20),
              _TalkButton(
                enabled: _isOnline && !_busy,
                active: _talkSession != null,
                busy: _talkBusy,
                accentColor: accentColorForKey(
                  _session.settings.accentColorKey,
                ),
                onStart: _startTalking,
                onStop: () => _stopTalking(),
              ),
              const SizedBox(height: 16),
              _OnlineControl(
                busy: _busy,
                online: _isOnline,
                onGoOnline: _goOnline,
                onGoAway: _goAway,
              ),
              if (_message != null) ...[
                const SizedBox(height: 12),
                Text(_message!, textAlign: TextAlign.center),
              ],
              if (warnings.isNotEmpty) ...[
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _openSetupWarnings,
                  icon: const Icon(Icons.error_outline),
                  label: Text('${warnings.length} setup item(s) need review'),
                ),
              ],
              const SizedBox(height: 24),
              _FriendStatusList(
                currentUserId: _session.userId,
                members: _members,
                availability: _availability,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StateHeader extends StatelessWidget {
  const _StateHeader({
    required this.displayName,
    required this.state,
    required this.availability,
  });

  final String displayName;
  final String state;
  final _Availability availability;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final live = availability.isLive || state == 'live' || state == 'talking';

    return Row(
      children: [
        CircleAvatar(
          radius: 22,
          backgroundColor: live
              ? colors.primary
              : colors.surfaceContainerHighest,
          child: Icon(
            live ? Icons.wifi_tethering : Icons.wifi_tethering_off,
            color: live ? colors.onPrimary : colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text(
                state == 'talking' ? 'Talking now' : availability.label,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _GroupSection extends StatelessWidget {
  const _GroupSection({
    required this.loading,
    required this.busy,
    required this.groups,
    required this.selectedGroup,
    required this.groupNameController,
    required this.inviteCodeController,
    required this.latestInvite,
    required this.onSelectGroup,
    required this.onCreateGroup,
    required this.onJoinInvite,
    required this.onCreateInvite,
  });

  final bool loading;
  final bool busy;
  final List<GroupSummary> groups;
  final GroupSummary? selectedGroup;
  final TextEditingController groupNameController;
  final TextEditingController inviteCodeController;
  final GroupInviteResult? latestInvite;
  final ValueChanged<String> onSelectGroup;
  final Future<void> Function() onCreateGroup;
  final Future<void> Function() onJoinInvite;
  final Future<void> Function() onCreateInvite;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const LinearProgressIndicator();
    }

    if (groups.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Set up group', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          TextField(
            controller: groupNameController,
            decoration: const InputDecoration(
              labelText: 'Group name',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: busy ? null : () => unawaited(onCreateGroup()),
            icon: const Icon(Icons.group_add_outlined),
            label: const Text('Create group'),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: inviteCodeController,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              labelText: 'Invite code',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: busy ? null : () => unawaited(onJoinInvite()),
            icon: const Icon(Icons.login),
            label: const Text('Join group'),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: selectedGroup?.groupId,
                decoration: const InputDecoration(
                  labelText: 'Group',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final group in groups)
                    DropdownMenuItem(
                      value: group.groupId,
                      child: Text(group.name, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: busy || selectedGroup == null
                    ? null
                    : (value) {
                        if (value != null) onSelectGroup(value);
                      },
              ),
            ),
            const SizedBox(width: 10),
            IconButton.filledTonal(
              tooltip: 'Create invite',
              onPressed: busy || selectedGroup == null
                  ? null
                  : () => unawaited(onCreateInvite()),
              icon: const Icon(Icons.ios_share),
            ),
          ],
        ),
        if (latestInvite != null) ...[
          const SizedBox(height: 10),
          SelectableText(
            'Invite code: ${latestInvite!.inviteCode}',
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ],
      ],
    );
  }
}

class _TalkButton extends StatelessWidget {
  const _TalkButton({
    required this.enabled,
    required this.active,
    required this.busy,
    required this.accentColor,
    required this.onStart,
    required this.onStop,
  });

  final bool enabled;
  final bool active;
  final bool busy;
  final Color accentColor;
  final Future<void> Function() onStart;
  final Future<void> Function() onStop;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final backgroundColor = active
        ? colors.error
        : enabled
        ? accentColor
        : colors.surfaceContainerHighest;
    final foregroundColor = active || enabled
        ? Colors.white
        : colors.onSurfaceVariant;

    return GestureDetector(
      onTapDown: enabled && !busy ? (_) => onStart() : null,
      onTapUp: enabled ? (_) => onStop() : null,
      onTapCancel: enabled ? () => onStop() : null,
      child: Container(
        height: 156,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              active ? Icons.mic : Icons.mic_none,
              size: 54,
              color: foregroundColor,
            ),
            const SizedBox(height: 10),
            Text(
              busy
                  ? 'WAIT'
                  : active
                  ? 'TALKING'
                  : 'HOLD TO TALK',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: foregroundColor,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnlineControl extends StatelessWidget {
  const _OnlineControl({
    required this.busy,
    required this.online,
    required this.onGoOnline,
    required this.onGoAway,
  });

  final bool busy;
  final bool online;
  final VoidCallback onGoOnline;
  final VoidCallback onGoAway;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: busy || online ? null : onGoOnline,
            icon: const Icon(Icons.radio_button_checked),
            label: const Text('Go online'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: busy || !online ? null : onGoAway,
            icon: const Icon(Icons.radio_button_unchecked),
            label: const Text('Go away'),
          ),
        ),
      ],
    );
  }
}

class _FriendStatusList extends StatelessWidget {
  const _FriendStatusList({
    required this.currentUserId,
    required this.members,
    required this.availability,
  });

  final String currentUserId;
  final List<GroupMemberSummary> members;
  final Map<String, _Availability> availability;

  @override
  Widget build(BuildContext context) {
    final friends = members
        .where((member) => member.userId != currentUserId)
        .toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Friends', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (friends.isEmpty)
          const Text('Invite a friend to start talking.')
        else
          for (final friend in friends)
            _FriendRow(
              member: friend,
              availability: availability[friend.userId] ?? _Availability.away,
            ),
      ],
    );
  }
}

class _FriendRow extends StatelessWidget {
  const _FriendRow({required this.member, required this.availability});

  final GroupMemberSummary member;
  final _Availability availability;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final statusColor = availability.isLive
        ? colors.primary
        : availability.effectiveState == 'talking'
        ? colors.error
        : colors.outline;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(Icons.circle, size: 12, color: statusColor),
      title: Text(
        member.displayName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(availability.label),
    );
  }
}

class _SetupLine extends StatelessWidget {
  const _SetupLine({required this.ok, required this.text});

  final bool ok;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            ok ? Icons.check_circle : Icons.error_outline,
            color: ok ? colors.primary : colors.error,
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class _Availability {
  const _Availability({
    required this.desiredState,
    required this.effectiveState,
    required this.canReceiveLiveAudio,
  });

  static const _Availability away = _Availability(
    desiredState: 'away',
    effectiveState: 'away',
    canReceiveLiveAudio: false,
  );

  final String desiredState;
  final String effectiveState;
  final bool canReceiveLiveAudio;

  factory _Availability.fromJson(Map<Object?, Object?> data) {
    return _Availability(
      desiredState: data['desiredState']?.toString() ?? 'away',
      effectiveState: data['effectiveState']?.toString() ?? 'away',
      canReceiveLiveAudio: data['canReceiveLiveAudio'] == true,
    );
  }

  bool get isLive {
    return canReceiveLiveAudio ||
        effectiveState == 'live' ||
        effectiveState == 'talking' ||
        effectiveState == 'connected';
  }

  String get label {
    return switch (effectiveState) {
      'talking' => 'Talking',
      'live' => 'Live',
      'connected' => 'Live',
      'connecting' => 'Connecting',
      'listening' => 'Listening',
      'away' => 'Away',
      _ => desiredState == 'online' ? 'Online' : 'Away',
    };
  }
}
