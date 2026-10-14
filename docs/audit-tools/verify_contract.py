"""Offline document checks. No backend requests, migrations, or notifications."""
from pathlib import Path
import json, re
import yaml
from openapi_spec_validator import validate_spec
from jsonschema import Draft4Validator, FormatChecker
from referencing import Registry, Resource
from referencing.jsonschema import DRAFT4

root=Path(__file__).resolve().parents[2]
spec=yaml.safe_load((root/'docs/rescue-platform-openapi.yaml').read_text(encoding='utf-8'))
validate_spec(spec)
checks=1
assert spec['x-implementation-status']=='proposal-only'; checks+=1
assert spec['servers'][0]['url']=='https://api.rescue-platform.invalid/v1'; checks+=1
assert spec['security']==[{'bearerAuth':[]}]; checks+=1
ids=[]; ops=[]
for path,item in spec['paths'].items():
    for method,op in item.items():
        ops.append((path,method,op)); ids.append(op['operationId'])
        assert op['x-status']=='proposal-not-implemented'; checks+=1
        if not path.startswith('/auth/'):
            assert 'security' not in op or op['security']; checks+=1
        if path.startswith('/organizations/{organization_id}'):
            assert any(p.get('$ref','').endswith('/OrganizationId') for p in op['parameters']); checks+=1
        if method in ['post','put','patch'] and not path.startswith('/auth/'):
            assert any(p.get('$ref','').endswith('/IdempotencyKey') for p in op['parameters']); checks+=1
        if any(p.get('$ref','').endswith('/IfMatch') for p in op['parameters']):
            assert '412' in op['responses'] and '428' in op['responses']; checks+=1
        assert '401' in op['responses'] and '429' in op['responses']; checks+=1
assert len(ids)==len(set(ids)); checks+=1
assert len(ops)==26; checks+=1
assert spec['components']['parameters']['Limit']['schema']['maximum']==100; checks+=1
assert spec['components']['schemas']['AlertResponseRequest']['properties']['response']['enum']==['going','not_going']; checks+=1
for path,method,op in ops:
    if op['operationId'] in ['createAlertDraft','dispatchAlert','closeAlert']:
        assert op['x-required-permissions']==['alerts.issue']; checks+=1

# OpenAPI nullable -> JSON Schema union only for these schema example checks.
def nullable(value):
    if isinstance(value,list):return [nullable(x) for x in value]
    if not isinstance(value,dict):return value
    out={k:nullable(v) for k,v in value.items() if k!='nullable'}
    if value.get('nullable') and isinstance(out.get('type'),str):out['type']=[out['type'],'null']
    return out
document=nullable(spec)
registry=Registry().with_resource('urn:rescue-platform:contract',Resource.from_contents(document,default_specification=DRAFT4))
def verify(name,data,valid=True):
    global checks
    validator=Draft4Validator({'$ref':'urn:rescue-platform:contract#/components/schemas/'+name},registry=registry,format_checker=FormatChecker())
    errors=list(validator.iter_errors(data))
    assert (not errors)==valid,(name,errors)
    checks+=1
verify('LoginRequest',{'email':'audit@example.invalid','password':'fake-password'})
verify('LoginRequest',{'email':'bad','password':'fake'},False)
verify('ProfilePatch',{'display_name':'Teszt Tag'})
verify('ProfilePatch',{'display_name':'Tag','role':'admin'},False)
verify('ProfilePatch',{},False)
verify('AlertResponseRequest',{'response':'going'})
verify('AlertResponseRequest',{'response':'not_going'})
verify('AlertResponseRequest',{'response':'available'},False)
verify('AlertResponseRequest',{'response':'going','membership_id':'spoofed'},False)
verify('ParticipationRequest',{'response':'going','role':'excon'})
verify('ParticipationRequest',{'response':'going','role':'admin'},False)
verify('CoinBalance',{'organization_id':'11111111-1111-4111-8111-111111111111','membership_id':'22222222-2222-4222-8222-222222222222','unit':'RC','balance':-10,'as_of':'2026-10-14T12:00:00Z','ledger_version':'v1'})
verify('CoinBalance',{'organization_id':'11111111-1111-4111-8111-111111111111','membership_id':'22222222-2222-4222-8222-222222222222','unit':'LRC','balance':10,'as_of':'2026-10-14T12:00:00Z','ledger_version':'v1'},False)
print(json.dumps({'status':'passed','checks':checks,'paths':len(spec['paths']),'operations':len(ops),'schemas':len(spec['components']['schemas']),'scope':'OpenAPI and offline schema checks only; no implemented API behavior asserted'}))
