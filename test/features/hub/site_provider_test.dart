// Copyright (c) 2026 ntthang-dev. All rights reserved.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:modbus_studio/features/hub/site_provider.dart';
import 'package:modbus_studio/src/rust/api/db.dart';

class MockSiteNotifier extends SiteNotifier {
  final List<Site> initialSites;
  final List<ConnectionProfile> initialProfiles;

  MockSiteNotifier({
    this.initialSites = const [],
    this.initialProfiles = const [],
  });

  @override
  SiteState build() {
    return SiteState(
      sites: initialSites,
      profiles: initialProfiles,
      isLoading: false,
    );
  }

  @override
  Future<void> loadAll() async {
    // Simulated load to prevent FFI calls in test environment
  }
}

void main() {
  group('SiteNotifier Unit Tests', () {
    test('Initial selection state is null (All Sites)', () {
      final mockNotifier = MockSiteNotifier();
      final container = ProviderContainer(
        overrides: [
          siteProvider.overrideWith(() => mockNotifier),
        ],
      );
      addTearDown(container.dispose);

      final state = container.read(siteProvider);
      expect(state.selectedSite, isNull);
      expect(state.isLoading, isFalse);
    });

    test('selectSite updates state correctly', () {
      const testSite = Site(id: 42, name: 'Facility A', description: 'Main plant');
      final mockNotifier = MockSiteNotifier(initialSites: [testSite]);
      final container = ProviderContainer(
        overrides: [
          siteProvider.overrideWith(() => mockNotifier),
        ],
      );
      addTearDown(container.dispose);

      container.read(siteProvider.notifier).selectSite(testSite);
      
      final state = container.read(siteProvider);
      expect(state.selectedSite, equals(testSite));
    });

    test('Deselect resets site selection to null', () {
      const testSite = Site(id: 42, name: 'Facility A');
      final mockNotifier = MockSiteNotifier(initialSites: [testSite]);
      final container = ProviderContainer(
        overrides: [
          siteProvider.overrideWith(() => mockNotifier),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(siteProvider.notifier);
      notifier.selectSite(testSite);
      expect(container.read(siteProvider).selectedSite, equals(testSite));

      notifier.selectSite(null);
      expect(container.read(siteProvider).selectedSite, isNull);
    });
  });
}
