import 'package:flutter_test/flutter_test.dart';
import 'package:hunor_app/api/mock_rescue_platform_api.dart';
import 'package:hunor_app/services/app_store.dart';

void main() {
  group('CODEX-017 & CODEX-018: Eseményjelentkezés és Hírek tesztjei', () {
    late MockRescuePlatformApi api;
    late AppStore store;

    setUp(() {
      api = MockRescuePlatformApi();
      store = AppStore(api: api);
    });

    test('Eseményregisztráció és részvétel lekérése mock API-val', () async {
      await store.initialize();
      expect(store.isAuthenticated, isTrue);

      final events = store.events;
      expect(events.isNotEmpty, isTrue);

      final testEvent = events.first;
      final regInfo = await api.getEventRegistrationInfo(testEvent.id);
      expect(regInfo.eventId, testEvent.id);
      expect(regInfo.maxCapacity, 20);
      expect(regInfo.remainingSeats, 12);
      expect(regInfo.isRegistrationOpen, isTrue);

      final participation = await api.getMyEventParticipation(testEvent.id);
      expect(participation.eventId, testEvent.id);
      expect(participation.response, isNull);
      expect(participation.version, 0);
    });

    test('Sikeres részvételi jelentkezés és lemondás növeli a verziót', () async {
      await store.initialize();
      final testEventId = store.events.first.id;

      // 1. Jelentkezés
      await store.respondToEvent(testEventId, true);
      expect(store.eventResponses[testEventId], 'going');
      expect(store.eventParticipations[testEventId]?.version, 1);
      expect(store.eventParticipations[testEventId]?.isGoing, isTrue);

      // 2. Lemondás
      await store.respondToEvent(testEventId, false);
      expect(store.eventResponses[testEventId], 'not_going');
      expect(store.eventParticipations[testEventId]?.version, 2);
      expect(store.eventParticipations[testEventId]?.isNotGoing, isTrue);
    });

    test('Hírek lekérése szigorú szervezeti izolációval (tenant-isolation)', () async {
      await store.initialize();
      expect(store.currentOrganization?.id, MockRescuePlatformApi.orgAId);

      // HUNOR szervezethez tartozó hírek ellenőrzése
      final hunorNews = store.news;
      expect(hunorNews.isNotEmpty, isTrue);
      for (final n in hunorNews) {
        expect(n.organizationId, MockRescuePlatformApi.orgAId);
      }
      expect(hunorNews.any((n) => n.id == 'news-001'), isTrue);

      // Szervezetváltás BMSZ-re
      await store.switchOrganization(MockRescuePlatformApi.orgBId);
      expect(store.currentOrganization?.id, MockRescuePlatformApi.orgBId);

      // BMSZ hírek ellenőrzése - nem tartalmazhatja a HUNOR híreket
      final bmszNews = store.news;
      for (final n in bmszNews) {
        expect(n.organizationId, MockRescuePlatformApi.orgBId);
      }
      expect(bmszNews.any((n) => n.id == 'news-001'), isFalse);
      expect(bmszNews.any((n) => n.id == 'news-003'), isTrue);
    });

    test('Kijelentkezéskor az eseményjelentkezések és a hírek is ürülnek', () async {
      await store.initialize();
      final testEventId = store.events.first.id;
      await store.respondToEvent(testEventId, true);

      expect(store.news.isNotEmpty, isTrue);
      expect(store.eventParticipations.isNotEmpty, isTrue);

      await store.signOut();

      expect(store.news.isEmpty, isTrue);
      expect(store.eventParticipations.isEmpty, isTrue);
      expect(store.eventRegistrations.isEmpty, isTrue);
      expect(store.isAuthenticated, isFalse);
    });

    test('Fióktörlési kérelem indítása sikeresen üríti a helyi adatokat és a munkamenetet', () async {
      await store.initialize();
      expect(store.isAuthenticated, isTrue);

      await store.requestAccountDeletion(reason: 'Teszt fióktörlés');

      expect(store.isAuthenticated, isFalse);
      expect(store.currentUser, isNull);
      expect(store.currentOrganization, isNull);
      expect(store.news.isEmpty, isTrue);
      expect(store.eventParticipations.isEmpty, isTrue);
    });
  });
}
