/// App-wide barrel for Duo.
///
/// Import `package:one_one_app/one_one.dart` instead of per-file `dart:`,
/// package, and `lib/` imports. Extra imports are only needed for aliases
/// (`http`, `image`) or name clashes (`LogLevel`, LiveKit `ConnectionState`).
/// When you add a new library file under `lib/`, export it here.
library;

// Dart SDK
export 'dart:async';
export 'dart:collection';
export 'dart:convert';
export 'dart:io';
export 'dart:isolate';
export 'dart:math';
export 'dart:typed_data';
export 'dart:ui' show ImageFilter;

// Flutter
export 'package:flutter/foundation.dart';
export 'package:flutter/material.dart';
export 'package:flutter/scheduler.dart';
export 'package:flutter/services.dart';
export 'package:flutter/widgets.dart';
export 'package:flutter_localizations/flutter_localizations.dart';

// Third party
export 'package:archive/archive.dart'
    hide EncryptionType, ZLibDecoder, ZLibEncoder;
export 'package:audioplayers/audioplayers.dart';
export 'package:cached_network_image/cached_network_image.dart'
    hide timeDilation;
export 'package:connectivity_plus/connectivity_plus.dart';
export 'package:firebase_analytics/firebase_analytics.dart';
export 'package:firebase_auth/firebase_auth.dart';
export 'package:firebase_core/firebase_core.dart';
export 'package:firebase_crashlytics/firebase_crashlytics.dart';
export 'package:firebase_database/firebase_database.dart';
export 'package:firebase_performance/firebase_performance.dart';
export 'package:firebase_remote_config/firebase_remote_config.dart';
export 'package:flutter_foreground_task/flutter_foreground_task.dart';
export 'package:flutter_screenutil/flutter_screenutil.dart';
export 'package:google_fonts/google_fonts.dart';
export 'package:google_sign_in/google_sign_in.dart';
export 'package:image_cropper/image_cropper.dart';
export 'package:image_picker/image_picker.dart';
export 'package:livekit_client/livekit_client.dart'
    hide ConnectionState, Priority, TimeoutException, EncryptionType;
export 'package:livekit_noise_filter/livekit_noise_filter.dart';
export 'package:lottie/lottie.dart';
export 'package:flutter_contacts/flutter_contacts.dart';
export 'package:lucide_flutter/lucide_flutter.dart';
export 'package:package_info_plus/package_info_plus.dart';
export 'package:path_provider/path_provider.dart';
export 'package:permission_handler/permission_handler.dart' hide ServiceStatus;
export 'package:purchases_flutter/purchases_flutter.dart' hide LogLevel;
export 'package:purchases_ui_flutter/purchases_ui_flutter.dart';
export 'package:record/record.dart';
export 'package:share_plus/share_plus.dart';
export 'package:shared_preferences/shared_preferences.dart';
export 'package:uuid/uuid.dart';

// App shell
export 'app/accent_theme.dart';
export 'app/app_config.dart';
export 'app/brand_splash_screen.dart';
export 'app/display_name_screen.dart';
export 'app/firebase_setup_blocked_screen.dart';
export 'app/google_auth_screen.dart';
export 'app/native_splash_bridge.dart';
export 'app/one_one_app.dart';
export 'app/profile_picture_screen.dart';
export 'app/setup_permission_screen.dart';
export 'app/startup_gate_screen.dart';
export 'app/startup_performance.dart';

// Core — firebase
export 'core/firebase/analytics_events.dart';
export 'core/firebase/app_database.dart';
export 'core/firebase/app_telemetry.dart';
export 'core/firebase/crashlytics_service.dart';
export 'core/firebase/firebase_analytics_service.dart';
export 'core/firebase/firebase_bootstrap.dart';
export 'core/firebase/firebase_performance_service.dart';

// Core — logging
export 'core/logging/crash_report_pending.dart';
export 'core/logging/debug_logs_sheet.dart';
export 'core/logging/device_log_bundle.dart';
export 'core/logging/device_log_report.dart';
export 'core/logging/livekit_lifecycle_logger.dart';
export 'core/logging/log_level.dart';
export 'core/logging/log_line.dart';
export 'core/logging/log_manager.dart';
export 'core/logging/operational_log.dart';
export 'core/logging/post_crash_report_dialog.dart';
export 'core/logging/send_feedback_sheet.dart';
export 'core/logging/user_facing_copy.dart';

// Core
export 'core/maps.dart';

// Core — market / locale
export 'core/market/locale_controller.dart';
export 'core/market/market.dart';
export 'core/market/market_config.dart';
export 'core/market/market_controller.dart';
export 'core/market/market_resolver.dart';
export 'core/market/market_ui.dart';

// Localization
export 'l10n/l10n.dart';

// Core — network
export 'core/network/api_client.dart';

// Core — storage
export 'core/storage/cloudinary_delivery.dart';
export 'core/storage/profile_photo_optimizer.dart';
export 'core/storage/profile_photo_storage.dart';

// Core — ui
export 'core/ui/bottom_system_inset.dart';
export 'core/ui/faded_horizontal_row.dart';

// Features — chat
export 'features/chat/data/chat_message_repository.dart';
export 'features/chat/models/group_chat_message.dart';
export 'features/chat/ui/chat_bubble_bar.dart';
export 'features/chat/ui/chat_bubble_feed.dart';

// Features — groups
export 'features/groups/data/group_repository.dart';
export 'features/groups/data/invite_link_bridge.dart';
export 'features/groups/group_service_readiness.dart';
export 'features/groups/models/group_invite_result.dart';
export 'features/groups/models/group_member_summary.dart';
export 'features/groups/models/group_summary.dart';
export 'features/groups/ui/group_home_screen.dart';
export 'features/groups/ui/group_management_screen.dart';
export 'features/groups/ui/invite_contacts_sheet.dart';
export 'features/groups/ui/waiting_for_group_members_screen.dart';

// Features — identity
export 'features/identity/data/avatar_assets.dart';
export 'features/identity/data/device_identity_store.dart';
export 'features/identity/data/identity_home_bootstrap.dart';
export 'features/identity/data/identity_repository.dart';
export 'features/identity/data/last_active_group_store.dart';
export 'features/identity/home_visual_variant.dart';
export 'features/identity/models/app_user_profile.dart';
export 'features/identity/models/haptics_intensity.dart';
export 'features/identity/models/identity_session.dart';
export 'features/identity/models/user_device_record.dart';
export 'features/identity/models/user_settings_record.dart';
export 'features/identity/ui/avatar_picker_grid.dart';
export 'features/identity/ui/group_action_screen.dart';
export 'features/identity/ui/identity_home_screen.dart';
export 'features/identity/ui/legal_document_screen.dart';
export 'features/identity/ui/lucide_audio_icons.dart';
export 'features/identity/ui/no_groups_screen.dart';
export 'features/identity/ui/profile_avatar.dart';
export 'features/identity/ui/profile_photo_editor.dart';
export 'features/identity/ui/settings_screen.dart';

// Features — nudges
export 'features/nudges/data/active_nudge_inbox.dart';
export 'features/nudges/data/active_nudge_sync.dart';
export 'features/nudges/data/android_voice_nudge_bridge.dart';
export 'features/nudges/data/media_volume_store.dart';
export 'features/nudges/data/nudge_delivery_status_store.dart';
export 'features/nudges/data/nudge_repository.dart';
export 'features/nudges/data/voice_nudge_audio.dart';
export 'features/nudges/models/active_nudge.dart';
export 'features/nudges/models/incoming_nudge_status_update.dart';
export 'features/nudges/models/media_volume_reading.dart';
export 'features/nudges/models/nudge_delivery_result.dart';
export 'features/nudges/models/nudge_notification_action.dart';
export 'features/nudges/models/nudge_recipient_response.dart';
export 'features/nudges/models/nudge_target.dart';
export 'features/nudges/nudge_cooldowns.dart';
export 'features/nudges/nudge_failure_memory.dart';
export 'features/nudges/nudge_haptics.dart';
export 'features/nudges/nudge_status_memory.dart';
export 'features/nudges/ui/incoming_nudge_list_sheet.dart';
export 'features/nudges/ui/incoming_nudge_prompt.dart';
export 'features/nudges/ui/nudge_screen.dart';
export 'features/nudges/ui/voice_record_swipe_cancel.dart';

// Features — online
export 'features/online/audio_output_bridge.dart';
export 'features/online/call_audio_route_controller.dart';
export 'features/online/data/active_online_session_store.dart';
export 'features/online/data/online_repository.dart';
export 'features/online/live_session_floating_pip.dart';
export 'features/online/live_session_overlay_controller.dart';
export 'features/online/livekit_connection_warmer.dart';
export 'features/online/livekit_status.dart';
export 'features/online/models/livekit_token_response.dart';
export 'features/online/models/member_availability.dart';
export 'features/online/models/online_session.dart';
export 'features/online/models/prepared_livekit_token.dart';
export 'features/online/peer_reconnect_coordinator.dart';
export 'features/online/presence_config.dart';
export 'features/online/solo_participant_guard.dart';
export 'features/online/ui/online_screen.dart';
export 'features/online/voice_overlay_bridge.dart';
export 'features/online/voice_pip_bridge.dart';

// Features — service_status
export 'features/service_status/service_status_gate.dart';

// Features — subscriptions
export 'features/subscriptions/duo_gate_paywall_screen.dart';
export 'features/subscriptions/eleven_pro_paywall_screen.dart';
export 'features/subscriptions/free_trial_access.dart';
export 'features/subscriptions/free_trial_config.dart';
export 'features/subscriptions/revenue_cat_service.dart';
export 'features/subscriptions/subscriber_access_record.dart';
export 'features/subscriptions/subscriber_access_store.dart';
export 'features/subscriptions/subscription_management_sheet.dart';
export 'features/subscriptions/trial_expired_gate_screen.dart';

// Features — talk
export 'features/talk/data/talk_repository.dart';
export 'features/talk/models/emoji_burst.dart';
export 'features/talk/models/talk_session.dart';
export 'features/talk/talk_feedback.dart';
export 'features/talk/ui/emoji_burst_overlay.dart';

export 'features/widget/duo_home_widget_sync.dart';
