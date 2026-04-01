import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:naijapulse/core/connectivity/connectivity_cubit.dart';
import 'package:naijapulse/core/sync/sync_cubit.dart';

class ConnectivitySyncBanner extends StatelessWidget {
  const ConnectivitySyncBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ConnectivityCubit, ConnectivityState>(
      builder: (context, connectivityState) {
        return BlocBuilder<SyncCubit, SyncState>(
          builder: (context, syncState) {
            final colorScheme = Theme.of(context).colorScheme;
            String? message;
            Color? backgroundColor;
            Color? foregroundColor;

            if (!connectivityState.isOnline) {
              message = 'You are offline. Showing cached data.';
              backgroundColor = colorScheme.errorContainer;
              foregroundColor = colorScheme.onErrorContainer;
            } else if (syncState.status == SyncStatus.syncing) {
              message = 'Syncing latest updates...';
              backgroundColor = colorScheme.primaryContainer;
              foregroundColor = colorScheme.onPrimaryContainer;
            } else if (syncState.status == SyncStatus.failed &&
                syncState.errorMessage != null) {
              message = syncState.errorMessage;
              backgroundColor = colorScheme.errorContainer;
              foregroundColor = colorScheme.onErrorContainer;
            } else {
              message = null;
            }

            if (message == null) {
              return const SizedBox.shrink();
            }

            return Container(
              width: double.infinity,
              color: backgroundColor,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: foregroundColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            );
          },
        );
      },
    );
  }
}
