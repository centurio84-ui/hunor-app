import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:hunor_app/api/staging_api.dart';
import 'package:hunor_app/models/api_error.dart';
import 'package:hunor_app/models/event_participation.dart';
import 'package:hunor_app/services/app_store.dart';
import 'staging_api_test.dart' show MemoryVault, session, defaults, json, orgA, orgB;

void main() {
  group('CODEX-017 / 018 Staging Engagement Integration Tests', () {
    const testEventId = '55555555-5555-4555-8555-555555555559';
    const testNewsId = '77777777-7777-4777-8777-777777777777';

    test('StagingApi handles event registration, participation, and PUT responses', () async {
      int participationVersion = 0;
      String? currentParticipationStatus;

      final api = StagingApi(
        vault: MemoryVault(),
        client: MockClient((http.Request r) async {
          final path = r.url.path;

          // Esemény regisztrációs ablak és kapacitás lekérése
          if (path.endsWith('/events/$testEventId/registration')) {
            return json({
              'organization_id': orgA,
              'event_id': testEventId,
              'publication_state': 'published',
              'registration_opens_at': '2026-11-01T00:00:00Z',
              'registration_closes_at': '2026-11-20T00:00:00Z',
              'cancellation_closes_at': '2026-11-19T00:00:00Z',
              'capacity': 2,
              'available_places': currentParticipationStatus == 'going' ? 1 : 2,
              'registration_open': true,
              'cancellation_open': true,
              'rules_version': 1,
              'version': 1,
            });
          }

          // Saját részvétel lekérése
          if (path.endsWith('/events/$testEventId/participation/me') && r.method == 'GET') {
            return json({
              'organization_id': orgA,
              'event_id': testEventId,
              'membership_id': '44444444-4444-4444-8444-444444444444',
              'response': currentParticipationStatus,
              'responded_at': currentParticipationStatus != null ? '2026-11-09T10:00:00Z' : null,
              'version': participationVersion,
            });
          }

          // Saját részvétel módosítása (PUT)
          if (path.endsWith('/events/$testEventId/participation/me') && r.method == 'PUT') {
            final expectedIfMatch = r.headers['if-match'];
            if (expectedIfMatch != '"v$participationVersion"') {
              return json({'code': 'VERSION_CONFLICT', 'message': 'Stale version'}, 412);
            }
            final body = jsonDecode(r.body) as Map<String, dynamic>;
            currentParticipationStatus = body['response'] as String;
            participationVersion++;

            return json({
              'organization_id': orgA,
              'event_id': testEventId,
              'membership_id': '44444444-4444-4444-8444-444444444444',
              'response': currentParticipationStatus,
              'responded_at': '2026-11-09T10:05:00Z',
              'version': participationVersion,
            });
          }

          return defaults(r);
        }),
      );

      await api.login('member@example.invalid', 'fixture-password');
      await api.switchOrganization(orgA);

      // 1. Regisztrációs adatok olvasása
      final regInfo = await api.getEventRegistrationInfo(testEventId);
      expect(regInfo.eventId, testEventId);
      expect(regInfo.maxCapacity, 2);
      expect(regInfo.remainingSeats, 2);
      expect(regInfo.isRegistrationOpen, isTrue);

      // 2. Kezdeti részvétel (v0)
      final initialPart = await api.getMyEventParticipation(testEventId);
      expect(initialPart.version, 0);
      expect(initialPart.response, isNull);

      // 3. Eseményre jelentkezés (going -> v1)
      final goingPart = await api.setMyEventParticipation(
        eventId: testEventId,
        response: EventParticipationStatus.going,
        expectedVersion: 0,
      );
      expect(goingPart.version, 1);
      expect(goingPart.isGoing, isTrue);

      // 4. Lemondás (not_going -> v2)
      final notGoingPart = await api.setMyEventParticipation(
        eventId: testEventId,
        response: EventParticipationStatus.notGoing,
        expectedVersion: 1,
      );
      expect(notGoingPart.version, 2);
      expect(notGoingPart.isNotGoing, isTrue);

      // 5. Version conflict (412) kezelése régi verzióval
      await expectLater(
        api.setMyEventParticipation(
          eventId: testEventId,
          response: EventParticipationStatus.going,
          expectedVersion: 0, // stale
        ),
        throwsA(isA<PreconditionFailedException>()),
      );
    });

    test('StagingApi handles news list and detailed item with fallback aliases', () async {
      final api = StagingApi(
        vault: MemoryVault(),
        client: MockClient((http.Request r) async {
          final path = r.url.path;

          if (path.endsWith('/news')) {
            return json({
              'items': [
                {
                  'content_id': testNewsId,
                  'organization_id': orgA,
                  'title': '[TESZT] Mobilos hírfolyam',
                  'lead': 'Rövid összefoglaló',
                  'body': 'Részletes hírtartalom szövege a mentőtagok számára.',
                  'author_display_name': 'Gyakorlatvezető',
                  'created_at': '2026-11-09T08:00:00Z',
                  'audience': 'members',
                  'is_pinned': true,
                  'tags': ['gyakorlat', 'staging'],
                }
              ],
              'page': {'next_cursor': null},
            });
          }

          if (path.endsWith('/news/$testNewsId')) {
            return json({
              'content_id': testNewsId,
              'organization_id': orgA,
              'title': '[TESZT] Mobilos hírfolyam részlet',
              'summary': 'Kanonikus summary mező',
              'content': 'Kanonikus content mező részlete.',
              'author_name': 'Műveleti tiszt',
              'published_at': '2026-11-09T09:00:00Z',
              'audience': 'members',
              'is_pinned': true,
              'tags': ['kiemelt'],
            });
          }

          return defaults(r);
        }),
      );

      await api.login('member@example.invalid', 'fixture-password');
      await api.switchOrganization(orgA);

      // Hírek listázása
      final newsList = await api.getNews();
      expect(newsList.length, 1);
      final item = newsList.first;
      expect(item.id, testNewsId);
      expect(item.title, '[TESZT] Mobilos hírfolyam');
      expect(item.summary, 'Rövid összefoglaló');
      expect(item.content, 'Részletes hírtartalom szövege a mentőtagok számára.');
      expect(item.authorName, 'Gyakorlatvezető');
      expect(item.isPinned, isTrue);

      // Hír részleteinek lekérése
      final detail = await api.getNewsItem(testNewsId);
      expect(detail.id, testNewsId);
      expect(detail.title, '[TESZT] Mobilos hírfolyam részlet');
      expect(detail.summary, 'Kanonikus summary mező');
      expect(detail.content, 'Kanonikus content mező részlete.');
      expect(detail.authorName, 'Műveleti tiszt');
    });

    test('AppStore integration loads staging events, participation and news, and executes respondToEvent', () async {
      int partVersion = 0;
      String? currentResponse;

      final api = StagingApi(
        vault: MemoryVault(),
        client: MockClient((http.Request r) async {
          final path = r.url.path;

          if (path.endsWith('/organizations')) {
            return json({
              'items': [
                {'id': orgA, 'name': 'HUNOR Fiktív Staging', 'slug': 'hunor', 'status': 'active'}
              ],
              'page': {'next_cursor': null},
            });
          }

          if (path.endsWith('/events')) {
            return json({
              'items': [
                {
                  'id': testEventId,
                  'organization_id': orgA,
                  'title': '[TESZT] Mobilos jelentkezési gyakorlat',
                  'description': 'Kétéves terepi gyakorlat',
                  'location': 'Budapest, Laktanya',
                  'starts_at': '2026-11-15T09:00:00Z',
                  'ends_at': '2026-11-15T17:00:00Z',
                  'version': 1,
                }
              ],
              'page': {'next_cursor': null},
            });
          }

          if (path.endsWith('/events/$testEventId/registration')) {
            return json({
              'organization_id': orgA,
              'event_id': testEventId,
              'publication_state': 'published',
              'registration_opens_at': '2026-11-01T00:00:00Z',
              'registration_closes_at': '2026-11-20T00:00:00Z',
              'capacity': 2,
              'available_places': currentResponse == 'going' ? 1 : 2,
              'registration_open': true,
              'cancellation_open': true,
              'rules_version': 1,
              'version': 1,
            });
          }

          if (path.endsWith('/events/$testEventId/participation/me')) {
            if (r.method == 'PUT') {
              final body = jsonDecode(r.body) as Map<String, dynamic>;
              currentResponse = body['response'] as String;
              partVersion++;
            }
            return json({
              'organization_id': orgA,
              'event_id': testEventId,
              'membership_id': '44444444-4444-4444-8444-444444444444',
              'response': currentResponse,
              'responded_at': currentResponse != null ? '2026-11-09T11:00:00Z' : null,
              'version': partVersion,
            });
          }

          if (path.endsWith('/news')) {
            return json({
              'items': [
                {
                  'content_id': testNewsId,
                  'organization_id': orgA,
                  'title': '[TESZT] Mobilos hírfolyam',
                  'lead': 'Staging hír bevezető',
                  'body': 'Staging hír törzs',
                  'author_display_name': 'Műveletvezető',
                  'created_at': '2026-11-09T08:00:00Z',
                  'audience': 'members',
                  'is_pinned': true,
                  'tags': [],
                }
              ],
              'page': {'next_cursor': null},
            });
          }

          return defaults(r);
        }),
      );

      final store = AppStore(api: api);
      await store.initialize();
      expect(store.isAuthenticated, isFalse);

      await store.signIn('member@example.invalid', 'fixture-password');
      expect(store.isAuthenticated, isTrue);

      // Esemény és hír betöltődött
      expect(store.events.length, 1);
      expect(store.events.first.id, testEventId);
      expect(store.events.first.title, '[TESZT] Mobilos jelentkezési gyakorlat');
      expect(store.news.length, 1);
      expect(store.news.first.id, testNewsId);

      // Esemény regisztráció és részvétel jelen van
      expect(store.eventRegistrations[testEventId]?.maxCapacity, 2);
      expect(store.eventParticipations[testEventId]?.version, 0);

      // Jelentkezés az eseményre az AppStore-on keresztül
      await store.respondToEvent(testEventId, true);
      expect(store.eventResponses[testEventId], 'going');
      expect(store.eventParticipations[testEventId]?.version, 1);
      expect(store.eventParticipations[testEventId]?.isGoing, isTrue);

      // Lemondás az eseményről az AppStore-on keresztül
      await store.respondToEvent(testEventId, false);
      expect(store.eventResponses[testEventId], 'not_going');
      expect(store.eventParticipations[testEventId]?.version, 2);
      expect(store.eventParticipations[testEventId]?.isNotGoing, isTrue);
    });
  });
}
