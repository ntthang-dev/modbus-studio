// Copyright (c) 2026 ntthang-dev. All rights reserved.

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:modbus_studio/src/rust/api/db.dart';
import 'package:modbus_studio/providers/connection_provider.dart';

class NodeStatus {
  final bool isOnline;
  final int? latencyMs;
  final String statusMessage;

  const NodeStatus({
    required this.isOnline,
    this.latencyMs,
    required this.statusMessage,
  });

  const NodeStatus.checking()
      : isOnline = false,
        latencyMs = null,
        statusMessage = "Checking...";

  const NodeStatus.offline([String msg = "Offline"])
      : isOnline = false,
        latencyMs = null,
        statusMessage = msg;
}

class SiteState {
  final List<Site> sites;
  final List<ConnectionProfile> profiles;
  final Site? selectedSite; // null means "All Sites"
  final Map<int, NodeStatus> nodeStatuses; // profileId -> NodeStatus
  final bool isLoading;

  SiteState({
    this.sites = const [],
    this.profiles = const [],
    this.selectedSite,
    this.nodeStatuses = const {},
    this.isLoading = false,
  });

  SiteState copyWith({
    List<Site>? sites,
    List<ConnectionProfile>? profiles,
    Site? selectedSite,
    bool clearSelectedSite = false,
    Map<int, NodeStatus>? nodeStatuses,
    bool? isLoading,
  }) {
    return SiteState(
      sites: sites ?? this.sites,
      profiles: profiles ?? this.profiles,
      selectedSite: clearSelectedSite ? null : (selectedSite ?? this.selectedSite),
      nodeStatuses: nodeStatuses ?? this.nodeStatuses,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class SiteNotifier extends Notifier<SiteState> {
  Timer? _sweepTimer;
  static const String _dbPath = "historian.db";

  @override
  SiteState build() {
    ref.onDispose(() {
      _sweepTimer?.cancel();
    });
    // Start loading initial data
    Future.microtask(() => loadAll());
    return SiteState(isLoading: true);
  }

  Future<void> loadAll() async {
    state = state.copyWith(isLoading: true);
    try {
      final loadedSites = await dbGetSites(dbPath: _dbPath);
      final loadedProfiles = await ref.read(connectionProvider.notifier).fetchProfiles();
      
      state = state.copyWith(
        sites: loadedSites,
        profiles: loadedProfiles,
        isLoading: false,
      );
      
      _startOrResetSweep();
    } catch (e) {
      debugPrint("Error loading sites and profiles: $e");
      state = state.copyWith(isLoading: false);
    }
  }

  void selectSite(Site? site) {
    state = state.copyWith(selectedSite: site, clearSelectedSite: site == null);
    _startOrResetSweep();
  }

  Future<void> saveSite(Site site) async {
    try {
      await dbSaveSite(dbPath: _dbPath, site: site);
      await loadAll();
    } catch (e) {
      debugPrint("Error saving site: $e");
      rethrow;
    }
  }

  Future<void> deleteSite(int id) async {
    try {
      await dbDeleteSite(dbPath: _dbPath, id: id);
      if (state.selectedSite?.id == id) {
        state = state.copyWith(clearSelectedSite: true);
      }
      await loadAll();
    } catch (e) {
      debugPrint("Error deleting site: $e");
      rethrow;
    }
  }

  void _startOrResetSweep() {
    _sweepTimer?.cancel();
    _runSweep();
    _sweepTimer = Timer.periodic(const Duration(seconds: 5), (_) => _runSweep());
  }

  Future<void> _runSweep() async {
    final filteredProfiles = state.selectedSite == null
        ? state.profiles
        : state.profiles.where((p) => p.siteId == state.selectedSite!.id).toList();

    if (filteredProfiles.isEmpty) return;

    final updatedStatuses = Map<int, NodeStatus>.from(state.nodeStatuses);

    await Future.wait(filteredProfiles.map((profile) async {
      final profileId = profile.id;
      if (profileId == null) return;

      final config = profile.config;
      if (config.protocolType == 'TCP' || config.protocolType == 'RTU_TCP') {
        final ip = config.ip;
        final port = config.port ?? 502;
        if (ip == null || ip.isEmpty) {
          updatedStatuses[profileId] = const NodeStatus.offline("IP Address Empty");
          return;
        }

        try {
          final stopwatch = Stopwatch()..start();
          final socket = await Socket.connect(ip, port, timeout: const Duration(seconds: 2));
          stopwatch.stop();
          final latency = stopwatch.elapsedMilliseconds;
          socket.destroy();

          updatedStatuses[profileId] = NodeStatus(
            isOnline: true,
            latencyMs: latency,
            statusMessage: "Online",
          );
        } catch (e) {
          updatedStatuses[profileId] = NodeStatus.offline("Offline (${e.toString().split(':').last.trim()})");
        }
      } else {
        updatedStatuses[profileId] = const NodeStatus(
          isOnline: true,
          latencyMs: null,
          statusMessage: "Ready (Serial)",
        );
      }
    }));

    state = state.copyWith(nodeStatuses: updatedStatuses);
  }
}

final siteProvider = NotifierProvider<SiteNotifier, SiteState>(() {
  return SiteNotifier();
});
