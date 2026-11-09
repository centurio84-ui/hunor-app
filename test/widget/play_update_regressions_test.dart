import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:hunor_app/api/staging_api.dart';
import 'package:hunor_app/models/api_error.dart';
import 'package:hunor_app/models/event_participation.dart';
import 'package:hunor_app/services/app_store.dart';
import 'package:hunor_app/views/calendar_page.dart';
import '../api/staging_api_test.dart' show MemoryVault, defaults, json, orgA, ready;

const eventId = '55555555-5555-4555-8555-555555555559';
const title = 'Fiktív frissítési próba';
Map<String, dynamic> rules() => {
  'organization_id': orgA, 'event_id': eventId,
  'publication_state': 'published', 'registration_open': true,
  'cancellation_open': true, 'capacity': 2, 'available_places': 2,
};
Future<AppStore> makeStore({bool missingCapability=false, bool missingRegistration=false}) async {
  var rejected = false;
  final api = StagingApi(vault: MemoryVault(), client: MockClient((r) async {
    final p = r.url.path;
    if (p.endsWith('/organizations')) return json({'items':[{'id':orgA,'name':'Fiktív A','slug':'fixture-a','status':'active'}],'page':{'next_cursor':null}});
    if (p.endsWith('/events')) return json({'items':[{'id':eventId,'organization_id':orgA,'title':title,'starts_at':DateTime.now().add(const Duration(days:10)).toUtc().toIso8601String(),'ends_at':DateTime.now().add(const Duration(days:11)).toUtc().toIso8601String(),'version':1}],'page':{'next_cursor':null}});
    if (p.endsWith('/registration')) return missingRegistration ? json({'code':'SERVICE_UNAVAILABLE'},503) : json(rules());
    if (p.endsWith('/participation/me')) {
      if (r.method=='PUT') {rejected=true;return json({'code':'VERSION_CONFLICT','message':'Fiktív verzióütközés'},412);}
      return json({'organization_id':orgA,'event_id':eventId,'membership_id':'44444444-4444-4444-8444-444444444444','response':rejected?'not_going':null,'version':rejected?2:0});
    }
    if (p.endsWith('/capabilities/me')) return missingCapability ? json({'code':'NOT_FOUND'},404) : json({'organization_id':orgA,'membership_id':'44444444-4444-4444-8444-444444444444','permissions_version':1,'authorization_version':'2026-10-22.1','allowed_actions':{'events.read':true,'events.participate_self':true}});
    return defaults(r);
  }));
  final store=AppStore(api:api);await store.initialize();await store.signIn('member@example.invalid','fixture-password');return store;
}
void main() {
 test('missing or unknown server facts fail closed',(){
  for(final state in [null,'unknown','cancelled','archived']) {
   final data={...rules()};if(state==null){data.remove('publication_state');}else{data['publication_state']=state;}
   final dto=EventRegistrationInfo.fromJson(data);
   expect(dto.isRegistrationOpen,isFalse);expect(dto.isCancellationOpen,isFalse);
  }
  final missing=EventRegistrationInfo.fromJson({...rules()}..remove('registration_open')..remove('cancellation_open'));
  expect(missing.isRegistrationOpen,isFalse);expect(missing.isCancellationOpen,isFalse);
  expect(EventRegistrationInfo.fromJson({...rules(),'registration_open':false}).isRegistrationOpen,isFalse);
 });
 test('zero capacity is full; null unlimited; cancellation independent',(){
  final zero=EventRegistrationInfo.fromJson({...rules(),'capacity':0,'available_places':0});
  expect(zero.isFull,isTrue);expect(zero.isCancellationOpen,isTrue);
  final unlimited=EventRegistrationInfo.fromJson({...rules(),'capacity':null,'available_places':null});
  expect(unlimited.hasCapacityLimit,isFalse);expect(unlimited.isFull,isFalse);
 });
 test('initial news cursor is replaced on later pages, limit preserved',()async{
  final seen=<String>[];
  final api=await ready(handler:(r){
   if(r.url.path.endsWith('/news')) {
    expect(r.url.queryParameters['limit'],'1');expect(r.url.queryParametersAll['cursor']!.length,1);
    final cursor=r.url.queryParameters['cursor']!;seen.add(cursor);
    return json({'items':[{'id':cursor=='start'?'99999999-9999-4999-8999-000000000001':'99999999-9999-4999-8999-000000000002','organization_id':orgA,'title':'Fiktív hír','summary':'','content':'','audience':'members','published_at':'2026-11-09T08:00:00Z'}],'page':{'next_cursor':cursor=='start'?'next':null}});
   }
   return defaults(r);
  });
  expect((await api.getNews(limit:1,cursor:'start')).length,2);expect(seen,['start','next']);
 });
 test('store conflict refreshes state, clears old success and rejects',()async{
  final store=await makeStore();store.lastResponseMessage='Korábbi siker';
  await expectLater(store.respondToEvent(eventId,true),throwsA(isA<PreconditionFailedException>()));
  expect(store.lastResponseMessage,isEmpty);expect(store.eventParticipations[eventId]?.version,2);expect(store.eventResponses[eventId],'not_going');store.dispose();
 });
 for(final missing in ['capability','registration']) {
  testWidgets('missing $missing disables event mutations',(tester)async{
   tester.view.physicalSize=const Size(1000,1400);tester.view.devicePixelRatio=1;
   addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
   final store=await makeStore(missingCapability:missing=='capability',missingRegistration:missing=='registration');
   await tester.pumpWidget(ChangeNotifierProvider.value(value:store,child:const MaterialApp(home:Scaffold(body:CalendarPage()))));await tester.pumpAndSettle();
   await tester.tap(find.text(title));await tester.pumpAndSettle();
   expect(tester.widget<FilledButton>(find.ancestor(of:find.text('Részt veszek'),matching:find.byWidgetPredicate((w)=>w is FilledButton)).first).onPressed,isNull);
   expect(tester.widget<OutlinedButton>(find.ancestor(of:find.text('Nem veszek részt'),matching:find.byWidgetPredicate((w)=>w is OutlinedButton)).first).onPressed,isNull);
  });
 }
 testWidgets('412 never shows a successful application snackbar',(tester)async{
  tester.view.physicalSize=const Size(1000,1400);tester.view.devicePixelRatio=1;
  addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
  final store=await makeStore();
  await tester.pumpWidget(ChangeNotifierProvider.value(value:store,child:const MaterialApp(home:Scaffold(body:CalendarPage()))));await tester.pumpAndSettle();
  await tester.tap(find.text(title));await tester.pumpAndSettle();await tester.tap(find.text('Részt veszek'));await tester.pumpAndSettle();
  expect(find.text('Sikeres eseményjelentkezés!'),findsNothing);
  expect(find.textContaining('Hiba a jelentkezéskor:'),findsOneWidget);expect(store.lastResponseMessage,isEmpty);
 });
}
