import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../group/models/get_group_model.response.dart';
import '../../group/providers/group_provider.dart';

typedef AccountGroupDetailsBuilder =
    Widget Function(
      BuildContext context,
      GetGroupResponseModel? groupDetails,
      bool isLoading,
      Object? error,
    );

class AccountGroupDetailsLoader extends StatefulWidget {
  const AccountGroupDetailsLoader({
    super.key,
    required this.groupId,
    required this.builder,
  });

  final int groupId;
  final AccountGroupDetailsBuilder builder;

  @override
  State<AccountGroupDetailsLoader> createState() =>
      _AccountGroupDetailsLoaderState();
}

class _AccountGroupDetailsLoaderState extends State<AccountGroupDetailsLoader> {
  late Future<GetGroupResponseModel?> _groupDetailsFuture;

  @override
  void initState() {
    super.initState();
    _loadGroupDetails();
  }

  @override
  void didUpdateWidget(covariant AccountGroupDetailsLoader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.groupId != widget.groupId) {
      _loadGroupDetails();
    }
  }

  void _loadGroupDetails() {
    _groupDetailsFuture = context
        .read<GroupProvider>()
        .getGroupDetailsForAccount(groupId: widget.groupId);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<GetGroupResponseModel?>(
      future: _groupDetailsFuture,
      builder: (context, snapshot) {
        return widget.builder(
          context,
          snapshot.data,
          snapshot.connectionState != ConnectionState.done,
          snapshot.error,
        );
      },
    );
  }
}
