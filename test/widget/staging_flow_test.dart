import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:hunor_app/api/staging_api.dart';
import 'package:hunor_app/services/app_store.dart';
import 'package:hunor_app/views/login_page.dart';
import '../api/staging_api_test.dart' show MemoryVault, session, defaults, json, orgA, alert;

void main(){
 testWidgets('staging login is labeled, empty and has no mock quick login',(tester)async{
  final store=AppStore(api:StagingApi(vault:MemoryVault(),client:MockClient((r)async=>defaults(r))));
  await tester.pumpWidget(ChangeNotifierProvider.value(value:store,child:const MaterialApp(home:LoginPage())));
  expect(find.text('STAGING · kizárólag fiktív tesztfiókok'),findsOneWidget);
  expect(find.text('Gyors belépés (Mock fiók)'),findsNothing);
  for(final field in tester.widgetList<TextField>(find.byType(TextField))){expect(field.controller!.text,isEmpty);}
 });
 test('AppStore loads canonical server data without fabricated member rows; local-only mutations blocked',()async{
  final vault=MemoryVault();
  final api=StagingApi(vault:vault,client:MockClient((r)async{
   if(r.url.path.endsWith('/organizations'))return json({'items':[{'id':orgA,'name':'Fiktív A','slug':'a','status':'active'}],'page':{'next_cursor':null}});
   if(r.url.path.endsWith('/events'))return json({'items':[{'id':'55555555-5555-4555-8555-555555555555','organization_id':orgA,'title':'Teszt esemény','starts_at':'2026-10-22T12:00:00Z'}],'page':{'next_cursor':null}});
   if(r.url.path.endsWith('/alerts'))return json({'items':[{'id':alert,'organization_id':orgA,'title':'Teszt riasztás','kind':'operational','status':'active'}],'page':{'next_cursor':null}});
   if(r.url.path.endsWith('/balance'))return json({'organization_id':orgA,'membership_id':'44444444-4444-4444-8444-444444444444','unit':'RC','balance':120,'as_of':'2026-10-22T12:00:00Z','ledger_version':'fixture'});
   return defaults(r);
  }));
  final store=AppStore(api:api);await store.initialize();expect(store.isAuthenticated,isFalse);
  await store.signIn('member@example.invalid','fixture-password');expect(store.errorMessage,isNull);expect(store.isAuthenticated,isTrue);expect(store.currentOrganization!.id,orgA);expect(api.currentOrganizationId,orgA);expect(store.coinBalance!.balance,120);expect(store.events.single.title,'Teszt esemény');expect(store.alerts.single.type,'alert');expect(store.members,isEmpty);
  expect(store.alertResponses[alert],'available');
  await expectLater(store.createEvent('not supported',DateTime.now(),'',''),throwsA(isA<Exception>()));expect(store.events.length,1);
  final logout=store.signOut();expect(store.currentUser,isNull);expect(store.events,isEmpty);expect(store.isAuthenticated,isFalse);await logout;expect(vault.value,isNull);
 });
 test('login finishing after logout cannot restore old credentials',()async{
  final pending=Completer<http.Response>(),vault=MemoryVault();
  final api=StagingApi(vault:vault,client:MockClient((r)async=>r.url.path.endsWith('/auth/sessions')?pending.future:defaults(r)));
  final login=api.login('member@example.invalid','fixture-password');
  final assertion=expectLater(login,throwsA(isA<Exception>()));
  // Allow login to begin after its intentional local session cleanup.
  await Future<void>.delayed(Duration.zero);await api.revokeCurrentSession();pending.complete(http.Response(jsonEncode(session()),200));await assertion;
  expect(api.isAuthenticated,isFalse);expect(vault.value,isNull);
 });
}
