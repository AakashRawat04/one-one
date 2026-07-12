import 'dart:async';
import 'dart:ui';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:livekit_client/livekit_client.dart';

import '../../../app/accent_theme.dart';
import '../../../core/firebase/app_database.dart';
import '../../groups/data/group_repository.dart';
import '../../groups/models/group_invite_result.dart';
import '../../groups/models/group_member_summary.dart';
import '../../groups/models/group_summary.dart';
import '../../groups/ui/waiting_for_group_members_screen.dart';
import '../../online/data/online_repository.dart';
import '../../online/models/online_session.dart';
import '../../talk/data/talk_repository.dart';
import '../../talk/models/talk_session.dart';
import '../data/identity_repository.dart';
import '../models/identity_session.dart';
import 'group_action_screen.dart';
import 'no_groups_screen.dart';
import 'profile_avatar.dart';
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

  late IdentitySession _session = widget.initialSession;
  List<GroupSummary> _groups = const [];
  List<GroupMemberSummary> _members = const [];
  Map<String, _Availability> _availability = const {};
  GroupSummary? _selectedGroup;
  StreamSubscription<DatabaseEvent>? _availabilitySubscription;

  OnlineSession? _onlineSession;
  TalkSession? _talkSession;
  Room? _room;
  EventsListener<RoomEvent>? _roomListener;
  Timer? _heartbeatTimer;

  late final PageController _carouselController = PageController(
    viewportFraction: 0.78,
  );
  int _carouselIndex = 0;

  bool _loadingGroups = true;
  bool _busy = false;
  bool _talkBusy = false;
  bool _talkPressed = false;
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
    _carouselController.dispose();
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
        if (selected == null) {
          _members = const [];
          _availability = const {};
        }
      });
      _syncCarouselToSelectedGroup();

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
      _members = const [];
      _availability = const {};
    });
    await _loadMembers(group.groupId);
    _listenToAvailability(group.groupId);
  }

  Future<void> _onGroupCarouselChanged(int index) async {
    if (index < 0 || index >= _groups.length) return;
    final group = _groups[index];
    setState(() => _carouselIndex = index);

    if (group.groupId == _selectedGroup?.groupId) return;

    if (_isOnline) {
      await _goAway();
      if (!mounted) return;
    }

    await _selectGroup(group.groupId);
  }

  void _syncCarouselToSelectedGroup() {
    final selected = _selectedGroup;
    if (selected == null || _groups.isEmpty) return;
    final index = _groups.indexWhere((group) => group.groupId == selected.groupId);
    if (index < 0) return;

    _carouselIndex = index;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_carouselController.hasClients) return;
      if (_carouselController.page?.round() != index) {
        _carouselController.jumpToPage(index);
      }
    });
  }

  void _openCreateGroup() {
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 320),
        reverseTransitionDuration: const Duration(milliseconds: 260),
        pageBuilder: (context, animation, secondaryAnimation) {
          return GroupActionScreen(
            mode: GroupActionMode.createGroup,
            session: _session,
            identityRepository: widget.identityRepository,
          );
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final offset = Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
          );
          return SlideTransition(position: offset, child: child);
        },
      ),
    );
  }

  Future<void> _createInvite() async {
    final group = _selectedGroup;
    if (group == null) return;

    await _runBusy(() async {
      final invite = await _groupRepository.createInvite(group.groupId);
      if (!mounted) return;
      setState(() => _message = 'Invite created');
      await _showShareInviteSheet(invite);
    });
  }

  Future<void> _showShareInviteSheet(GroupInviteResult invite) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xff141414),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(24.w, 20.h, 24.w, 24.h),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Invite friends',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  'Share this group PIN so they can join',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14.sp,
                  ),
                ),
                SizedBox(height: 20.h),
                GestureDetector(
                  onTap: () async {
                    await Clipboard.setData(
                      ClipboardData(text: invite.inviteCode),
                    );
                    if (!context.mounted) return;
                    Navigator.of(context).pop();
                    if (!mounted) return;
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      const SnackBar(content: Text('PIN copied')),
                    );
                  },
                  child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(
                      horizontal: 20.w,
                      vertical: 18.h,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xff1f1f1f),
                      borderRadius: BorderRadius.circular(18.r),
                      border: Border.all(
                        color: const Color.fromRGBO(255, 255, 255, 0.12),
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          invite.inviteCode,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 32.sp,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 6,
                          ),
                        ),
                        SizedBox(height: 8.h),
                        Text(
                          'tap to copy',
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openGroupPicker() {
    if (_groups.isEmpty) return;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xff141414),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      builder: (context) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 24.h),
            children: [
              Padding(
                padding: EdgeInsets.only(bottom: 8.h, left: 8.w),
                child: Text(
                  'Your groups',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              for (final group in _groups)
                ListTile(
                  onTap: () {
                    Navigator.of(context).pop();
                    final index = _groups.indexWhere(
                      (item) => item.groupId == group.groupId,
                    );
                    if (index >= 0) {
                      unawaited(_onGroupCarouselChanged(index));
                      if (_carouselController.hasClients) {
                        _carouselController.animateToPage(
                          index,
                          duration: const Duration(milliseconds: 280),
                          curve: Curves.easeOutCubic,
                        );
                      }
                    }
                  },
                  title: Text(
                    group.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  trailing: group.groupId == _selectedGroup?.groupId
                      ? const Icon(Icons.check_rounded, color: Colors.white)
                      : null,
                ),
            ],
          ),
        );
      },
    );
  }

  void _togglePresence() {
    if (_busy) return;
    if (_isOnline) {
      unawaited(_goAway());
    } else {
      unawaited(_goOnline());
    }
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

    _talkPressed = true;
    setState(() {
      _talkBusy = true;
      _message = null;
    });

    TalkSession? startedTalk;
    try {
      startedTalk = await _talkRepository.startTalk(session);
      if (!_talkPressed) {
        await _talkRepository.stopTalk(startedTalk, reason: 'released_early');
        await _setMicrophoneEnabled(false);
        if (!mounted) return;
        setState(() {
          _talkSession = null;
          _state = 'live';
        });
        return;
      }

      await _setMicrophoneEnabled(true);
      if (_session.settings.hapticsEnabled) {
        unawaited(HapticFeedback.mediumImpact());
      }
      if (!mounted) return;

      if (!_talkPressed) {
        await _setMicrophoneEnabled(false);
        await _talkRepository.stopTalk(startedTalk, reason: 'released_early');
        setState(() {
          _talkSession = null;
          _state = 'live';
        });
        return;
      }

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
    _talkPressed = false;
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

  bool get _isOnline => _onlineSession != null;

  List<GroupMemberSummary> get _friends {
    return _members
        .where((member) => member.userId != _session.userId)
        .toList(growable: false);
  }

  List<_CarouselItem> get _carouselItems {
    final selfAvailability = _isOnline
        ? _Availability(
            desiredState: 'online',
            effectiveState: _state,
            canReceiveLiveAudio: true,
          )
        : _Availability.away;

    return [
      for (final group in _groups)
        _CarouselItem.group(
          group: group,
          displayName: _session.user.displayName,
          profilePhotoUrl: _session.user.profilePhotoUrl,
          profilePhotoBase64: _session.user.profilePhotoBase64,
          availability: group.groupId == _selectedGroup?.groupId
              ? selfAvailability
              : _Availability.away,
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final accent = accentColorForKey(_session.settings.accentColorKey);
    final warnings = _setupWarnings();
    final items = _carouselItems;
    final focusedGroup = _selectedGroup;
    // Local session is the source of truth — remote availability can lag after goAway.
    final live = _isOnline && (_state == 'live' || _state == 'talking');
    final inviteAction = _busy || focusedGroup == null
        ? null
        : () => unawaited(_createInvite());

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          _HomeBackdrop(
            profilePhotoUrl: _session.user.profilePhotoUrl,
            profilePhotoBase64: _session.user.profilePhotoBase64,
            accent: accent,
          ),
          SafeArea(
            child: Column(
              children: [
                _TopChrome(
                  onSettings: _openSettings,
                  onSetup: _openSetupWarnings,
                  hasSetupWarnings: warnings.isNotEmpty,
                  busy: _busy,
                  online: _isOnline,
                  onTogglePresence: _togglePresence,
                ),
                SizedBox(height: 8.h),
                _FriendsStrip(
                  friends: _friends,
                  availability: _availability,
                  onInvite: inviteAction,
                ),
                if (_message != null) ...[
                  SizedBox(height: 10.h),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24.w),
                    child: Text(
                      _message!,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12.sp,
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                if (focusedGroup != null)
                  _CarouselCaption(
                    displayName: _session.user.displayName,
                    isLive: live,
                    isTalking: _state == 'talking',
                    groupName: focusedGroup.name,
                    onTapName: _groups.length > 1 ? _openGroupPicker : null,
                  ),
                SizedBox(height: 10.h),
                SizedBox(
                  height: 200.h,
                  child: _ExperienceCarousel(
                    controller: _carouselController,
                    items: items,
                    index: _carouselIndex,
                    talkEnabled: _isOnline && !_busy,
                    talkActive: _talkSession != null,
                    talkBusy: _talkBusy,
                    accent: accent,
                    onPageChanged: (index) {
                      unawaited(_onGroupCarouselChanged(index));
                    },
                    onTalkStart: _startTalking,
                    onTalkStop: () => _stopTalking(),
                    onCreateGroup: _openCreateGroup,
                  ),
                ),
                SizedBox(height: 18.h),
                Text(
                  _isOnline
                      ? 'hold to talk · release to let others speak'
                      : 'go online to start talking',
                  style: TextStyle(
                    color: const Color.fromRGBO(255, 255, 255, 0.55),
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 28.h),
              ],
            ),
          ),
          if (_loadingGroups)
            const ColoredBox(
              color: Color(0x88000000),
              child: Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }
}

class _HomeBackdrop extends StatelessWidget {
  const _HomeBackdrop({
    required this.profilePhotoUrl,
    required this.profilePhotoBase64,
    required this.accent,
  });

  final String? profilePhotoUrl;
  final String? profilePhotoBase64;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final hasPhoto = (profilePhotoUrl?.trim().isNotEmpty ?? false) ||
        (profilePhotoBase64?.trim().isNotEmpty ?? false);

    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: Colors.black),
        if (hasPhoto)
          Opacity(
            opacity: 0.5,
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 32, sigmaY: 32),
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: 400,
                  height: 800,
                  child: ProfileAvatar(
                    profilePhotoUrl: profilePhotoUrl,
                    profilePhotoBase64: profilePhotoBase64,
                    radius: 200,
                    backgroundColor: Colors.black,
                  ),
                ),
              ),
            ),
          ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.25),
                Colors.black.withValues(alpha: 0.5),
                Colors.black.withValues(alpha: 0.85),
                Color.lerp(Colors.black, accent, 0.14)!,
              ],
              stops: const [0, 0.35, 0.72, 1],
            ),
          ),
        ),
      ],
    );
  }
}

class _TopChrome extends StatelessWidget {
  const _TopChrome({
    required this.onSettings,
    required this.onSetup,
    required this.hasSetupWarnings,
    required this.busy,
    required this.online,
    required this.onTogglePresence,
  });

  final VoidCallback onSettings;
  final VoidCallback onSetup;
  final bool hasSetupWarnings;
  final bool busy;
  final bool online;
  final VoidCallback onTogglePresence;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(12.w, 4.h, 12.w, 0),
      child: SizedBox(
        height: 52.h,
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                _GlassIconButton(
                  tooltip: hasSetupWarnings ? 'Settings / Setup' : 'Settings',
                  icon: Icons.settings_outlined,
                  onPressed: onSettings,
                  onLongPress: onSetup,
                ),
                if (hasSetupWarnings)
                  Positioned(
                    top: -2,
                    right: -2,
                    child: GestureDetector(
                      onTap: onSetup,
                      child: Container(
                        width: 14.w,
                        height: 14.w,
                        decoration: const BoxDecoration(
                          color: Color(0xffff5a5f),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            Expanded(
              child: Center(
                child: Image.asset(
                  'assets/logo.png',
                  height: 44.h,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            _StatusToggle(
              busy: busy,
              online: online,
              onToggle: onTogglePresence,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusToggle extends StatelessWidget {
  const _StatusToggle({
    required this.busy,
    required this.online,
    required this.onToggle,
  });

  final bool busy;
  final bool online;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: busy ? 0.65 : 1,
      child: Tooltip(
        message: online ? 'Tap to go away' : 'Tap to go online',
        child: Material(
          color: const Color.fromRGBO(255, 255, 255, 0.12),
          borderRadius: BorderRadius.circular(18.r),
          child: InkWell(
            onTap: busy ? null : onToggle,
            borderRadius: BorderRadius.circular(18.r),
            child: Container(
              width: 72.w,
              height: 30.h,
              padding: EdgeInsets.all(2.w),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18.r),
                border: Border.all(
                  color: const Color.fromRGBO(255, 255, 255, 0.22),
                ),
              ),
              child: Stack(
                children: [
                  AnimatedAlign(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    alignment:
                        online ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      width: 34.w,
                      height: double.infinity,
                      decoration: BoxDecoration(
                        color: online ? const Color(0xff7CFF6B) : Colors.white,
                        borderRadius: BorderRadius.circular(14.r),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: Center(
                          child: Text(
                            '🌙',
                            style: TextStyle(fontSize: 11.sp),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Center(
                          child: Text(
                            busy ? '…' : '🟢',
                            style: TextStyle(fontSize: 11.sp),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  const _GlassIconButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.onLongPress,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(22.r),
        child: Container(
          width: 44.w,
          height: 44.w,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: onPressed == null
                ? const Color.fromRGBO(255, 255, 255, 0.06)
                : const Color.fromRGBO(0, 0, 0, 0.35),
            border: Border.all(
              color: const Color.fromRGBO(255, 255, 255, 0.18),
            ),
          ),
          child: Icon(
            icon,
            color: onPressed == null ? Colors.white38 : Colors.white,
            size: 20.sp,
          ),
        ),
      ),
    );
  }
}

class _FriendsStrip extends StatelessWidget {
  const _FriendsStrip({
    required this.friends,
    required this.availability,
    required this.onInvite,
  });

  final List<GroupMemberSummary> friends;
  final Map<String, _Availability> availability;
  final VoidCallback? onInvite;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 20.w),
          child: Text(
            'friends',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14.sp,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ),
        SizedBox(height: 10.h),
        SizedBox(
          height: 78.h,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            children: [
              for (final friend in friends) ...[
                _FriendChip(
                  name: friend.displayName,
                  availability:
                      availability[friend.userId] ?? _Availability.away,
                ),
                SizedBox(width: 12.w),
              ],
              _AddFriendChip(onTap: onInvite),
            ],
          ),
        ),
      ],
    );
  }
}

class _FriendChip extends StatelessWidget {
  const _FriendChip({required this.name, required this.availability});

  final String name;
  final _Availability availability;

  @override
  Widget build(BuildContext context) {
    final live = availability.isLive;
    final initial = name.trim().isEmpty
        ? '?'
        : name.trim().substring(0, 1).toUpperCase();

    return Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 52.w,
              height: 52.w,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xff2a2a2a),
                border: Border.all(
                  color: live ? const Color(0xff7CFF6B) : Colors.white24,
                  width: 2,
                ),
              ),
              child: Text(
                initial,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Positioned(
              right: -4,
              bottom: -2,
              child: Text(live ? '🟢' : '🌙', style: TextStyle(fontSize: 14.sp)),
            ),
          ],
        ),
        SizedBox(height: 4.h),
        SizedBox(
          width: 56.w,
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white70,
              fontSize: 10.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _AddFriendChip extends StatelessWidget {
  const _AddFriendChip({required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: onTap == null ? 0.45 : 1,
        child: Column(
          children: [
            Container(
              width: 52.w,
              height: 52.w,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white54,
                  width: 1.5,
                ),
              ),
              child: Icon(Icons.add, color: Colors.white, size: 24.sp),
            ),
            SizedBox(height: 4.h),
            Text(
              'invite',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 10.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CarouselCaption extends StatelessWidget {
  const _CarouselCaption({
    required this.displayName,
    required this.isLive,
    required this.isTalking,
    required this.groupName,
    required this.onTapName,
  });

  final String displayName;
  final bool isLive;
  final bool isTalking;
  final String? groupName;
  final VoidCallback? onTapName;

  @override
  Widget build(BuildContext context) {
    final name = displayName.trim().isEmpty ? 'you' : displayName.toLowerCase();

    return Column(
      children: [
        GestureDetector(
          onTap: onTapName,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('👋', style: TextStyle(fontSize: 18.sp)),
              SizedBox(width: 6.w),
              Text(
                (groupName ?? name).toLowerCase(),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22.sp,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (onTapName != null) ...[
                SizedBox(width: 4.w),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: Colors.white,
                  size: 22.sp,
                ),
              ],
            ],
          ),
        ),
        SizedBox(height: 2.h),
        Text(
          name,
          style: TextStyle(
            color: Colors.white54,
            fontSize: 12.sp,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 10.h),
        if (isLive || isTalking)
          Container(
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 7.h),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18.r),
            ),
            child: Text(
              isTalking ? '🎙️ talking!' : '👀 is here!',
              style: TextStyle(
                color: Colors.black,
                fontSize: 13.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
      ],
    );
  }
}

class _ExperienceCarousel extends StatelessWidget {
  const _ExperienceCarousel({
    required this.controller,
    required this.items,
    required this.index,
    required this.talkEnabled,
    required this.talkActive,
    required this.talkBusy,
    required this.accent,
    required this.onPageChanged,
    required this.onTalkStart,
    required this.onTalkStop,
    required this.onCreateGroup,
  });

  final PageController controller;
  final List<_CarouselItem> items;
  final int index;
  final bool talkEnabled;
  final bool talkActive;
  final bool talkBusy;
  final Color accent;
  final ValueChanged<int> onPageChanged;
  final Future<void> Function() onTalkStart;
  final Future<void> Function() onTalkStop;
  final VoidCallback onCreateGroup;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Row(
        children: [
          const Spacer(),
          _DashedAddCircle(onTap: onCreateGroup, compact: true),
          SizedBox(width: 16.w),
        ],
      );
    }

    return Row(
      children: [
        SizedBox(width: 20.w),
        Expanded(
          child: PageView.builder(
            controller: controller,
            itemCount: items.length,
            onPageChanged: onPageChanged,
            itemBuilder: (context, itemIndex) {
              final item = items[itemIndex];
              final selected = itemIndex == index;

              return AnimatedScale(
                scale: selected ? 1.0 : 0.78,
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                child: Center(
                  child: _MainAvatarCircle(
                    item: item,
                    selected: selected,
                    talkEnabled: talkEnabled && selected,
                    talkActive: talkActive && selected,
                    talkBusy: talkBusy,
                    accent: accent,
                    onTalkStart: onTalkStart,
                    onTalkStop: onTalkStop,
                  ),
                ),
              );
            },
          ),
        ),
        _DashedAddCircle(onTap: onCreateGroup, compact: true),
        SizedBox(width: 16.w),
      ],
    );
  }
}

class _MainAvatarCircle extends StatelessWidget {
  const _MainAvatarCircle({
    required this.item,
    required this.selected,
    required this.talkEnabled,
    required this.talkActive,
    required this.talkBusy,
    required this.accent,
    required this.onTalkStart,
    required this.onTalkStop,
  });

  final _CarouselItem item;
  final bool selected;
  final bool talkEnabled;
  final bool talkActive;
  final bool talkBusy;
  final Color accent;
  final Future<void> Function() onTalkStart;
  final Future<void> Function() onTalkStop;

  @override
  Widget build(BuildContext context) {
    final size = selected ? 158.w : 118.w;
    final live = item.availability.isLive || talkActive;

    Widget circle = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: talkActive ? accent : Colors.white,
          width: selected ? 3.5 : 2,
        ),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ]
            : null,
      ),
      child: ClipOval(
        child: Stack(
          fit: StackFit.expand,
          children: [
            ProfileAvatar(
              profilePhotoUrl: item.profilePhotoUrl,
              profilePhotoBase64: item.profilePhotoBase64,
              radius: size / 2,
              backgroundColor: const Color(0xff2a2a2a),
              fallback: Icon(
                Icons.person_outline,
                color: Colors.white70,
                size: size * 0.4,
              ),
            ),
            if (talkActive)
              ColoredBox(
                color: accent.withValues(alpha: 0.28),
                child: Icon(
                  Icons.mic,
                  color: Colors.white,
                  size: size * 0.28,
                ),
              ),
          ],
        ),
      ),
    );

    if (talkEnabled) {
      circle = Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: talkBusy
            ? null
            : (_) {
                unawaited(onTalkStart());
              },
        onPointerUp: (_) {
          unawaited(onTalkStop());
        },
        onPointerCancel: (_) {
          unawaited(onTalkStop());
        },
        child: circle,
      );
    }

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        circle,
        if (live && selected) ...[
          Positioned(
            top: -4,
            right: 10,
            child: Text('✨', style: TextStyle(fontSize: 22.sp)),
          ),
          Positioned(
            top: 18,
            right: -2,
            child: Text('✨', style: TextStyle(fontSize: 16.sp)),
          ),
        ],
      ],
    );
  }
}

class _DashedAddCircle extends StatelessWidget {
  const _DashedAddCircle({
    required this.onTap,
    required this.compact,
  });

  final VoidCallback? onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final size = compact ? 84.w : 110.w;
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: onTap == null ? 0.45 : 1,
        child: CustomPaint(
          painter: _DashedCirclePainter(
            color: const Color.fromRGBO(255, 255, 255, 0.7),
          ),
          child: SizedBox(
            width: size,
            height: size,
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(10.w),
                child: Text(
                  '+ create\nnew group',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: compact ? 10.sp : 12.sp,
                    fontWeight: FontWeight.w600,
                    height: 1.15,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedCirclePainter extends CustomPainter {
  const _DashedCirclePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;

    final radius = size.shortestSide / 2;
    const dashCount = 28;
    const dashSweep = 0.12;
    const gapSweep = (6.28318530718 / dashCount) - dashSweep;
    var start = 0.0;

    for (var i = 0; i < dashCount; i++) {
      canvas.drawArc(
        Rect.fromCircle(center: size.center(Offset.zero), radius: radius),
        start,
        dashSweep,
        false,
        paint,
      );
      start += dashSweep + gapSweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DashedCirclePainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _CarouselItem {
  const _CarouselItem({
    required this.group,
    required this.displayName,
    required this.availability,
    this.profilePhotoUrl,
    this.profilePhotoBase64,
  });

  factory _CarouselItem.group({
    required GroupSummary group,
    required String displayName,
    required String? profilePhotoUrl,
    required String? profilePhotoBase64,
    required _Availability availability,
  }) {
    return _CarouselItem(
      group: group,
      displayName: displayName,
      profilePhotoUrl: profilePhotoUrl,
      profilePhotoBase64: profilePhotoBase64,
      availability: availability,
    );
  }

  final GroupSummary group;
  final String displayName;
  final _Availability availability;
  final String? profilePhotoUrl;
  final String? profilePhotoBase64;
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
