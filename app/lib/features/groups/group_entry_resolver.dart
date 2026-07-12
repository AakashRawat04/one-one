import 'package:flutter/material.dart';

import '../identity/data/identity_repository.dart';
import '../identity/models/identity_session.dart';
import '../identity/ui/identity_home_screen.dart';
import '../identity/ui/no_groups_screen.dart';
import 'data/group_repository.dart';

Future<Widget> resolveGroupEntryScreen({
  required IdentitySession session,
  required IdentityRepository identityRepository,
  GroupRepository? groupRepository,
}) async {
  final repository = groupRepository ?? GroupRepository();
  final resolution = await repository.resolveGroupEntry(session.userId);

  switch (resolution.kind) {
    case GroupEntryKind.noGroups:
      return NoGroupsScreen(
        session: session,
        identityRepository: identityRepository,
      );
    case GroupEntryKind.home:
      return IdentityHomeScreen(
        initialSession: session,
        identityRepository: identityRepository,
      );
    case GroupEntryKind.waiting:
      return IdentityHomeScreen(
        initialSession: session,
        identityRepository: identityRepository,
      );
  }
}
