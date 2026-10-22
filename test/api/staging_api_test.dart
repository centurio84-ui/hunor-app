import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:hunor_app/api/staging_api.dart';
import 'package:hunor_app/models/api_error.dart';

const orgA='11111111-1111-4111-8111-111111111111', orgB='22222222-2222-4222-8222-222222222222', alert='66666666-6666-4666-8666-666666666666';
class MemoryVault implements SessionVault {
  String? value;
  @override Future<String?> read() async=>value;
  @override Future<void> write(String text) async{value=text;}
  @override Future<void> clear() async{value=null;}
}
Map<String,dynamic> session([String id='user-a',String token='access-a'])=>{'access_token':token,'refresh_token':'refresh-a','token_type':'Bearer','expires_at':'2030-01-01T00:00:00Z','user':{'id':id,'email':'member@example.invalid','display_name':'Fiktív tag'}};
http.Response json(Object data,[int code=200])=>http.Response(jsonEncode(data),code,headers:{'content-type':'application/json'});
http.Response defaults(http.Request r){
 final path=r.url.path.substring(r.url.path.lastIndexOf('/v1/')+3);
 if(path=='/auth/sessions')return json(session());
 if(path=='/auth/refresh')return json(session('user-a','access-b'));
 if(path=='/auth/sessions/current')return http.Response('',204);
 if(path=='/me')return json({'user':session()['user'],'version':1});
 if(path.endsWith('/members/me'))return json({'id':'44444444-4444-4444-8444-444444444444','organization_id':path.split('/')[2],'user_id':'user-a','membership_status':'approved'});
 if(path.endsWith('/response/me'))return json({'alert_id':alert,'membership_id':'member-a','response':'going','version':3});
 return json({'items':<Object>[],'page':{'next_cursor':null}});
}
Future<StagingApi> ready({MemoryVault? vault,FutureOr<http.Response> Function(http.Request)? handler}) async{
 final api=StagingApi(vault:vault??MemoryVault(),client:MockClient((r)async=>handler==null?defaults(r):await handler(r)));
 await api.login('member@example.invalid','fixture-password');await api.switchOrganization(orgA);return api;
}
void main(){
 test('only exact staging HTTPS endpoint; production, HTTP and redirects cannot be configured',(){
  for(final url in ['https://hun01usar.hu','http://localhost/v1','$stagingBase/','https://embicteneumubwlqqfik.supabase.co']){expect(()=>StagingApi(baseUrl:url,vault:MemoryVault()),throwsArgumentError);}
 });
 test('login persisted in vault, restored through server and logout clears vault even offline',()async{
  final vault=MemoryVault();final api=await ready(vault:vault);expect(vault.value,contains('access-a'));
  final restored=StagingApi(vault:vault,client:MockClient((r)async=>defaults(r)));await restored.restore();expect(restored.isAuthenticated,isTrue);
  final offline=StagingApi(vault:vault,client:MockClient((_)async=>throw http.ClientException('offline')));
  await expectLater(offline.restore(),throwsA(isA<NetworkUnavailable>()));await offline.revokeCurrentSession();expect(offline.isAuthenticated,isFalse);expect(vault.value,isNull);expect(api.isAuthenticated,isTrue);
 });
 test('single-flight refresh for concurrent 401s; no credentials leak to list URLs',()async{
  var refreshes=0;
  final api=await ready(handler:(r)async{
   expect(r.url.query, isNot(contains('access-a')));
   if(r.url.path.endsWith('/auth/refresh')){refreshes++;await Future<void>.delayed(const Duration(milliseconds:20));return json(session('user-a','access-b'));}
   if(r.url.path.endsWith('/me')&&!r.url.path.endsWith('/members/me')&&r.headers['authorization']=='Bearer access-a')return json({},401);
   return defaults(r);
  });
  await Future.wait([api.getMyProfile(),api.getMyProfile(),api.getMyProfile()]);expect(refreshes,1);
 });
 test('refresh denied clears session and queue; no mock fallback',()async{
  final vault=MemoryVault();final api=await ready(vault:vault,handler:(r){if(r.url.path.endsWith('/auth/refresh')||r.url.path.endsWith('/me')&&!r.url.path.endsWith('/members/me'))return json({},401);return defaults(r);});
  await expectLater(api.getMyProfile(),throwsA(isA<UnauthorizedException>()));expect(api.isAuthenticated,isFalse);expect(vault.value,isNull);
 });
 test('canonical DTO mapping and paginated organization list',()async{
  var pages=0;final api=await ready(handler:(r){if(r.url.path.endsWith('/organizations')){pages++;return json({'items':[{'id':pages==1?orgA:orgB,'name':'Fictional','slug':'test-a','status':'active'}],'page':{'next_cursor':pages==1?'opaque-cursor':null}});}return defaults(r);});
  final orgs=await api.getMyOrganizations();expect(orgs.length,2);expect(orgs.first.code,'TEST-A');expect(pages,2);
 });
 test('switch clears previous scope before validating membership and rejects revoked',()async{
  final api=await ready(handler:(r){if(r.url.path.contains(orgB))return json({'code':'MEMBERSHIP_NOT_APPROVED'},403);return defaults(r);});
  await expectLater(api.switchOrganization(orgB),throwsA(isA<ApiException>()));expect(api.currentOrganizationId,isNull);
 });
 test('version precondition and stable key/body survive timeout and restore',()async{
  final vault=MemoryVault();final attempts=<http.Request>[];var offline=true;
  Future<http.Response> handler(http.Request r)async{if(r.method=='PUT'){attempts.add(r);if(offline)throw http.ClientException('timeout');return defaults(r);}return defaults(r);}
  final api=await ready(vault:vault,handler:handler);await api.getMyResponse(alert);
  await expectLater(api.setMyAlertResponse(alertId:alert,response:'going'),throwsA(isA<ResponsePending>()));expect(api.pendingResponses.length,1);
  offline=false;final restarted=StagingApi(vault:vault,client:MockClient(handler));await restarted.restore();await restarted.switchOrganization(orgA);await restarted.syncResponses();
  expect(attempts.length,2);expect(attempts[0].headers['if-match'],'"v3"');expect(attempts[0].headers['idempotency-key'],attempts[1].headers['idempotency-key']);expect(attempts[0].body,attempts[1].body);expect(restarted.pendingResponses,isEmpty);
 });
 test('unknown resource version while offline never invents precondition or queues answer',()async{
  var offline=false;final api=await ready(handler:(r){if(offline)throw http.ClientException('offline');return defaults(r);});offline=true;
  await expectLater(api.setMyAlertResponse(alertId:alert,response:'going'),throwsA(isA<NetworkUnavailable>()));expect(api.pendingResponses,isEmpty);
 });
 test('409/412 are blocked for explicit resolution and never automatically rewritten',()async{
  for(final status in [409,412]){var puts=0;final api=await ready(handler:(r){if(r.method=='PUT'){puts++;return json({'code':'VERSION_CONFLICT'},status);}return defaults(r);});
   await expectLater(api.setMyAlertResponse(alertId:alert,response:'not_going',expectedVersion:1),throwsA(isA<ApiException>()));expect(api.pendingResponses.single['blocked'],true);await api.syncResponses();expect(puts,1);
   await api.discardPending(api.pendingResponses.single['key']);expect(api.pendingResponses,isEmpty);
  }
 });
 test('queue never sent under another tenant or after account change/logout',()async{
  var puts=0;final api=await ready(handler:(r){if(r.method=='PUT'){puts++;throw http.ClientException('offline');}return defaults(r);});
  await expectLater(api.setMyAlertResponse(alertId:alert,response:'going',expectedVersion:1),throwsA(isA<ResponsePending>()));await api.switchOrganization(orgB);await api.syncResponses();expect(puts,1);expect(api.pendingResponses,isEmpty);
  await api.login('other@example.invalid','fixture-other');await api.switchOrganization(orgA);await api.syncResponses();expect(puts,1);expect(api.pendingResponses,isEmpty);
 });
 test('logout invalidates in-flight reads and delayed login cannot revive session',()async{
  final pending=Completer<http.Response>();var hold=false;final vault=MemoryVault();final api=await ready(vault:vault,handler:(r){if(hold&&r.url.path.endsWith('/me')&&!r.url.path.endsWith('/members/me'))return pending.future;return defaults(r);});
  hold=true;final read=api.getMyProfile();final expectation=expectLater(read,throwsA(isA<UnauthorizedException>()));await api.revokeCurrentSession();pending.complete(json({'user':session()['user']}));await expectation;expect(api.isAuthenticated,isFalse);expect(vault.value,isNull);
 });
 test('unsupported dispatch and installations never report a saved operation',()async{
  final api=await ready();await expectLater(api.dispatchAlert(title:'fixture',message:'fixture',type:'alert'),throwsA(isA<ApiException>()));
  await expectLater(api.registerMyInstallation(installationId:'fixture',platform:'android',provider:'fcm',token:'not-real'),throwsA(isA<ApiException>()));
 });
}
