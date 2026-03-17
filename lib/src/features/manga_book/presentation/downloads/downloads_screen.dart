// Copyright (c) 2022 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../utils/extensions/custom_extensions.dart';
import '../../../../utils/misc/toast/toast.dart';
import '../../../../widgets/emoticons.dart';
import '../../data/downloads/downloads_repository.dart';
import '../../data/local_downloads/local_downloads_service.dart';
import '../../domain/downloads/downloads_model.dart';
import 'controller/downloads_controller.dart';
import 'widgets/download_progress_list_tile.dart';
import 'widgets/downloads_fab.dart';
import 'widgets/local_downloads_list.dart';
class DownloadsScreen extends ConsumerWidget {
  const DownloadsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final toast = ref.watch(toastProvider);
    final downloadsChapterIds = ref.watch(downloadsChapterIdsProvider);
    final downloadsGlobalStatus = ref.watch(downloaderStateProvider);
    final showDownloadsFAB = ref.watch(showDownloadsFABProvider);
    final localDownloadedIds = ref.watch(localDownloadedChapterIdsProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.downloads),
        actions: [
          IconButton(
            onPressed: () => ref.invalidate(localDownloadedChapterIdsProvider),
            icon: const Icon(Icons.refresh_rounded),
          ),
          if ((downloadsChapterIds).isNotBlank)
            IconButton(
              onPressed: () => AsyncValue.guard(
                ref.read(downloadsRepositoryProvider).clearDownloads,
              ),
              icon: const Icon(Icons.delete_sweep_rounded),
            ),
          localDownloadedIds.maybeWhen(
            data: (ids) => ids.isNotEmpty
                ? IconButton(
                    onPressed: () async {
                      final ok = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Delete offline downloads?'),
                              content: Text(
                                'This will remove ${ids.length} offline chapter(s) from this device.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.of(context).pop(false),
                                  child: const Text('Cancel'),
                                ),
                                FilledButton(
                                  onPressed: () =>
                                      Navigator.of(context).pop(true),
                                  child: const Text('Delete'),
                                ),
                              ],
                            ),
                          ) ??
                          false;
                      if (!ok) return;
                      final service = ref.read(localDownloadsServiceProvider);
                      for (final id in ids) {
                        await service.deleteChapter(id);
                      }
                      ref.invalidate(localDownloadedChapterIdsProvider);
                    },
                    icon: const Icon(Icons.delete_outline_rounded),
                  )
                : const SizedBox.shrink(),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      floatingActionButton: showDownloadsFAB
          ? DownloadsFab(
              status:
                  downloadsGlobalStatus.valueOrNull ?? DownloaderState.STARTED)
          : null,
      body: DefaultTabController(
        length: 2,
        child: Column(
          children: [
            const TabBar(
              tabs: [
                Tab(icon: Icon(Icons.cloud_download_rounded), text: 'Server'),
                Tab(icon: Icon(Icons.download_done_rounded), text: 'Offline'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  downloadsGlobalStatus.showUiWhenData(
                    context,
                    (data) {
                      if (data == null) {
                        return Emoticons(
                            title: context.l10n.errorSomethingWentWrong);
                      } else if (downloadsChapterIds.isBlank) {
                        return Emoticons(title: context.l10n.noDownloads);
                      } else {
                        final downloadsCount =
                            (downloadsChapterIds.length).getValueOnNullOrNegative();
                        return RefreshIndicator(
                          onRefresh: () =>
                              ref.refresh(downloadStatusProvider.future),
                          child: ListView.builder(
                            itemExtent: 104,
                            itemBuilder: (context, index) {
                              if (index == downloadsCount) return const Gap(104);
                              final chapterId = downloadsChapterIds[index];
                              return DownloadProgressListTile(
                                key: ValueKey("$chapterId"),
                                index: index,
                                downloadsCount: downloadsCount,
                                chapterId: chapterId,
                                toast: toast,
                              );
                            },
                            itemCount: downloadsCount + 1,
                          ),
                        );
                      }
                    },
                    showGenericError: true,
                  ),
                  _OfflineTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The Offline tab content — storage-size header + downloads list.
class _OfflineTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storageSizeAsync = ref.watch(offlineStorageSizeProvider);

    return Column(
      children: [
        // Storage info banner
        storageSizeAsync.maybeWhen(
          data: (bytes) {
            if (bytes == 0) return const SizedBox.shrink();
            final mb = bytes / (1024 * 1024);
            final label = mb >= 1
                ? '${mb.toStringAsFixed(1)} MB used on device'
                : '${(bytes / 1024).toStringAsFixed(0)} KB used on device';
            return Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: context.theme.colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.6),
              child: Row(
                children: [
                  Icon(
                    Icons.storage_rounded,
                    size: 16,
                    color: context.theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: context.theme.textTheme.labelMedium?.copyWith(
                      color: context.theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            );
          },
          orElse: () => const SizedBox.shrink(),
        ),
        const Expanded(child: LocalDownloadsList()),
      ],
    );
  }
}
