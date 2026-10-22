import 'dart:async';
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import '../models/api_error.dart';
import '../models/coin_balance.dart';
import '../models/installation.dart';
import '../models/organization.dart';
import '../models/rescue_alert.dart';
import '../models/rescue_event.dart';
import '../models/user_profile.dart';
import 'rescue_platform_api.dart';

const stagingBase = 'https://xbcutdkqswfzkubkozng.supabase.co/functions/v1/rescue-platform-staging/v1';
abstract class SessionVault {
  Future<String?> read();
  Future<void> write(String value);
  Future<void> clear();
}
class DeviceSessionVault implements SessionVault {
  static const _key = 'rescue.staging.session.v1';
  final FlutterSecureStorage storage;
  DeviceSessionVault({FlutterSecureStorage? storage}) : storage = storage ?? const FlutterSecureStorage(aOptions: AndroidOptions(encryptedSharedPreferences: true), iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock_this_device));
  @override Future<String?> read() => storage.read(key: _key);
  @override Future<void> write(String value) => storage.write(key: _key, value: value);
  @override Future<void> clear() => storage.delete(key: _key);
}
class NetworkUnavailable extends ApiException {
  const NetworkUnavailable() : super(statusCode: 0, code: 'OFFLINE', message: 'Nincs kapcsolat a staging szerverrel.');
}
class ResponsePending extends ApiException {
  const ResponsePending() : super(statusCode: 0, code: 'PENDING_SYNC', message: 'Válasz a készüléken mentve, szerveres megerősítésre vár.');
}
const unsupportedStaging = ApiException(statusCode: 503, code: 'NOT_SUPPORTED', message: 'Ez a művelet még nem támogatott a staging API-ban. Nem történt mentés.');

class StagingApi implements RescuePlatformApi {
  final http.Client client;
  final SessionVault vault;
  final Uri base;
  Map<String, dynamic>? _session;
  String? _org;
  int _generation = 0;
  Future<void>? _refreshing;
  Future<void>? _syncing;
  Future<void> _storage = Future.value();
  final List<Map<String, dynamic>> _queue = [];
  final Map<String, int> _versions = {};
  StagingApi({http.Client? client, SessionVault? vault, String baseUrl = stagingBase}) : client = client ?? http.Client(), vault = vault ?? DeviceSessionVault(), base = Uri.parse(baseUrl) {
    if (baseUrl != stagingBase) throw ArgumentError('Only the approved HTTPS staging API is permitted.');
  }
  @override bool get isAuthenticated => _session != null;
  @override String? get currentOrganizationId => _org;
  String? get userId => (_session?['user'] as Map?)?['id'] as String?;
  List<Map<String, dynamic>> get pendingResponses => _queue.where((q) => q['user_id'] == userId && q['organization_id'] == _org).map((q) => Map<String, dynamic>.unmodifiable(q)).toList();
  void _same(int generation, [String? org]) { if (generation != _generation || (org != null && org != _org)) throw const UnauthorizedException(); }
  Future<void> _persist() {
    final generation = _generation;
    final value = _session == null ? null : jsonEncode({'session': _session, 'queue': _queue});
    final work = _storage.catchError((Object _) {}).then((_) async { if (generation != _generation) return; if(value == null) { await vault.clear(); } else { await vault.write(value); } });
    _storage = work; return work;
  }
  Future<void> _forget() async { _generation++; _session = null; _org = null; _queue.clear(); _versions.clear(); await _persist(); }
  Future<void> restore() async {
    final text = await vault.read(); if (text == null) return;
    try {
      final data = jsonDecode(text) as Map<String, dynamic>;
      _session = Map<String, dynamic>.from(data['session'] as Map);
      _queue.addAll((data['queue'] as List).map((q) => Map<String, dynamic>.from(q as Map)).where((q) => q['user_id'] == userId));
      await request('/me');
    } on NetworkUnavailable { rethrow; } on ApiException catch(e) { if(e.statusCode == 401) await _forget(); rethrow; } catch (_) { await _forget(); throw const UnauthorizedException(); }
  }
  Future<void> login(String email, String password) async {
    await _forget(); final generation = _generation;
    final data = await _raw('POST', '/auth/sessions', body: {'email': email, 'password': password});
    _same(generation); _session = data; await _persist();
  }
  Future<Map<String, dynamic>> _raw(String method, String path, {Map<String, dynamic>? body, String? token, Map<String,String> headers = const {}}) async {
    final req = http.Request(method, Uri.parse('$base$path'))..followRedirects = false;
    req.headers.addAll({'accept': 'application/json', if(token != null) 'authorization': 'Bearer $token', ...headers});
    if(body != null) { req.headers['content-type'] = 'application/json'; req.body = jsonEncode(body); }
    http.Response response;
    try { response = await http.Response.fromStream(await client.send(req).timeout(const Duration(seconds: 15))).timeout(const Duration(seconds: 15)); } on Exception { throw const NetworkUnavailable(); }
    Map<String,dynamic> data = {};
    try { if(response.body.isNotEmpty) data = jsonDecode(response.body) as Map<String,dynamic>; } catch (_) { throw const ApiException(statusCode: 503, code: 'INVALID_RESPONSE', message: 'A szerver válasza nem értelmezhető.'); }
    if(response.statusCode < 200 || response.statusCode >= 300) {
      if(response.statusCode == 401) throw const UnauthorizedException();
      throw ApiException(statusCode: response.statusCode, code: data['code']?.toString() ?? 'API_ERROR', message: 'A műveletet a staging szerver elutasította (${response.statusCode}, ${data['code'] ?? 'API_ERROR'}).', requestId: data['request_id']?.toString());
    }
    return data;
  }
  Future<void> _refresh(String rejectedToken) async {
    if(_session?['access_token'] != rejectedToken) return;
    if(_refreshing != null) return _refreshing!;
    final generation = _generation;
    final future = () async {
      try { final next = await _raw('POST','/auth/refresh',body:{'refresh_token':_session!['refresh_token']}); _same(generation); _session = next; await _persist(); }
      on ApiException catch(e) { if(e.statusCode == 401 && generation == _generation) await _forget(); rethrow; }
    }();
    _refreshing = future;
    try { await future; } finally { if(identical(_refreshing,future)) _refreshing = null; }
  }
  Future<Map<String,dynamic>> request(String path, {String method = 'GET', Map<String,dynamic>? body, Map<String,String> headers = const {}}) async {
    if(_session == null) throw const UnauthorizedException();
    final generation = _generation, token = _session!['access_token'] as String;
    try { final data = await _raw(method,path,token:token,body:body,headers:headers); _same(generation); return data; }
    on ApiException catch(e) {
      if(e.statusCode != 401 || generation != _generation) rethrow;
      await _refresh(token); _same(generation);
      try { final data = await _raw(method,path,token:_session!['access_token'],body:body,headers:headers); _same(generation); return data; }
      on ApiException catch(e) { if(e.statusCode == 401 && generation == _generation) await _forget(); rethrow; }
    }
  }
  Future<List<Map<String,dynamic>>> _pages(String path) async {
    final items = <Map<String,dynamic>>[], cursors = <String>{}; String? cursor;
    do {
      final data = await request(path + (cursor == null ? '' : '?cursor=${Uri.encodeQueryComponent(cursor)}'));
      items.addAll((data['items'] as List).map((e) => Map<String,dynamic>.from(e as Map)));
      cursor = (data['page'] as Map?)?['next_cursor'] as String?;
      if(cursor != null && !cursors.add(cursor)) throw const ApiException(statusCode:503,code:'INVALID_CURSOR',message:'Hibás lapozási válasz.');
    } while(cursor != null);
    return items;
  }
  String _tenant() { if(_org == null) throw const ForbiddenException(); return '/organizations/$_org'; }
  void _uuid(String value) { if(!RegExp(r'^[a-fA-F0-9-]{36}$').hasMatch(value)) throw ArgumentError('UUID required'); }
  @override Future<UserProfile> getMyProfile() async => UserProfile.fromJson(await request('/me'));
  @override Future<List<Organization>> getMyOrganizations() async => (await _pages('/organizations')).map((w) => Organization.fromJson({...w,'code':(w['slug'] as String).toUpperCase(),'active':w['status']=='active'})).toList();
  @override Future<Membership> getMyOrganizationMembership(String organizationId) async { _uuid(organizationId); final w = await request('/organizations/$organizationId/members/me'); return Membership.fromJson({...w,'membership_status':w['membership_status']=='left'?'revoked':w['membership_status']}); }
  @override Future<void> switchOrganization(String organizationId) async { _uuid(organizationId); final generation = _generation; _org=null; clearTenantCache(); final membership=await getMyOrganizationMembership(organizationId); _same(generation); if(!membership.isApproved) throw const ForbiddenException(); _org=organizationId; }
  @override void clearTenantCache() { _versions.clear(); }
  @override Future<List<RescueEvent>> getEvents() async { final org=_org,generation=_generation,path=_tenant(); final rows=await _pages('$path/events'); _same(generation,org); return rows.map(RescueEvent.fromJson).toList(); }
  @override Future<RescueEvent> getEvent(String eventId) async { _uuid(eventId); return RescueEvent.fromJson(await request('${_tenant()}/events/$eventId')); }
  RescueAlert _alert(Map<String,dynamic> w) => RescueAlert.fromJson({...w,'type':w['kind']=='operational'?'alert':w['kind']});
  @override Future<List<RescueAlert>> getAlerts() async { final org=_org,generation=_generation,path=_tenant(); final rows=await _pages('$path/alerts'); _same(generation,org); return rows.map(_alert).toList(); }
  @override Future<RescueAlert> getAlert(String alertId) async { _uuid(alertId); return _alert(await request('${_tenant()}/alerts/$alertId')); }
  Future<AlertResponse> getMyResponse(String alertId) async { _uuid(alertId); final org=_org,generation=_generation; final data=await request('${_tenant()}/alerts/$alertId/response/me'); _same(generation,org); final response=AlertResponse.fromJson(data); _versions[alertId]=response.version; return response; }
  @override Future<CoinBalance> getCoinBalance() async { final org=_org,generation=_generation,path=_tenant(); final member=await getMyOrganizationMembership(_org!); _same(generation,org); return CoinBalance.fromJson(await request('$path/members/${member.id}/rescue-coins/balance')); }
  Future<List<Membership>> getMembers() async => (await _pages('${_tenant()}/members')).map(Membership.fromJson).toList();
  @override Future<AlertResponse> setMyAlertResponse({required String alertId,required String response,int? expectedVersion,String? idempotencyKey}) async {
    _uuid(alertId); if(!['going','not_going'].contains(response)) throw ArgumentError('Invalid response');
    final org=_org,generation=_generation; _tenant();
    if(_queue.any((q)=>q['user_id']==userId&&q['organization_id']==org&&q['alert_id']==alertId)) throw const ResponsePending();
    final version=expectedVersion??_versions[alertId]??(await getMyResponse(alertId)).version; _same(generation,org);
    final item=<String,dynamic>{'user_id':userId,'organization_id':org,'alert_id':alertId,'response':response,'version':version,'key':idempotencyKey??const Uuid().v4(),'created_at':DateTime.now().toUtc().toIso8601String(),'blocked':false};
    _queue.add(item); await _persist();
    return _send(item);
  }
  Future<AlertResponse> _send(Map<String,dynamic> item) async {
    final generation=_generation,org=_org; if(item['user_id']!=userId||item['organization_id']!=org) throw const ForbiddenException();
    try {
      final w=await request('/organizations/$org/alerts/${item['alert_id']}/response/me',method:'PUT',body:{'response':item['response']},headers:{'if-match':'"v${item['version']}"','idempotency-key':item['key']});
      _same(generation,org); _queue.remove(item); final r=AlertResponse.fromJson(w); _versions[r.alertId]=r.version; await _persist(); return r;
    } on ApiException catch(e) {
      if(generation!=_generation) rethrow;
      if(e.statusCode==0||e.statusCode==429||e.statusCode>=500) { await _persist(); throw const ResponsePending(); }
      if(_queue.contains(item)) { item['blocked']=true; item['error']=e.code; await _persist(); } rethrow;
    }
  }
  Future<void> syncResponses() async {
    if(_syncing!=null) return _syncing!;
    final generation=_generation,org=_org;
    final future=() async { for(final item in List<Map<String,dynamic>>.from(_queue)) { _same(generation,org); if(item['user_id']!=userId||item['organization_id']!=org||item['blocked']==true) continue;
      if(DateTime.now().toUtc().difference(DateTime.parse(item['created_at'])).inHours>=24) { item['blocked']=true; item['error']='REPLAY_WINDOW_EXPIRED'; await _persist(); continue; }
      try { await _send(item); } on ResponsePending { break; } on ApiException catch(e) { if(e.statusCode==401) rethrow; }
    }}(); _syncing=future; try { await future; } finally { if(identical(_syncing,future)) _syncing=null; }
  }
  Future<void> discardPending(String key) async { _queue.removeWhere((q)=>q['key']==key&&q['user_id']==userId&&q['organization_id']==_org); await _persist(); }
  @override Future<void> revokeCurrentSession() async { final token=_session?['access_token'] as String?; await _forget(); if(token!=null) { try { await _raw('DELETE','/auth/sessions/current',token:token); } on Exception { /* Local logout is final even offline; remote revocation may be unavailable. */ } } }
  @override Future<RescueAlert> dispatchAlert({required String title,required String message,required String type,DateTime? expiresAt}) async => throw unsupportedStaging;
  @override Future<void> acknowledgeAlert(String alertId,{String? idempotencyKey}) async { _uuid(alertId); await request('${_tenant()}/alerts/$alertId/acknowledgement/me',method:'PUT',headers:{'idempotency-key':idempotencyKey??const Uuid().v4()}); }
  @override Future<Installation> registerMyInstallation({required String installationId,required String platform,required String provider,required String token,String? label,String? environment}) async => throw unsupportedStaging;
  @override Future<Installation> updateMyInstallation({required String installationId,required String provider,required String token}) async => throw unsupportedStaging;
  @override Future<DeviceReceipt> confirmDeviceReceipt({required String deliveryId,required String receiptToken}) async => throw unsupportedStaging;
}
