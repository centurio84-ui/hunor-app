"""Resolve validated build inputs. This script does not connect to any API."""
import os
import re
from pathlib import Path
from urllib.parse import urlparse

STAGING_URL = 'https://xbcutdkqswfzkubkozng.supabase.co/functions/v1/rescue-platform-staging/v1'

def resolve(env):
    target = env.get('INPUT_TARGET_ENV') or 'staging'
    number = env.get('INPUT_BUILD_NUMBER') or '10002'
    version = env.get('INPUT_VERSION_NAME') or '1.0.1'
    if target not in ('staging', 'production'):
        raise ValueError('Invalid environment')
    if not re.fullmatch(r'[1-9][0-9]{0,9}', number) or not 10002 <= int(number) <= 2100000000:
        raise ValueError('Invalid Android build number')
    if not re.fullmatch(r'[0-9]+\.[0-9]+\.[0-9]+(?:[-+][A-Za-z0-9.-]+)?', version):
        raise ValueError('Invalid version name')
    if target == 'staging':
        url = (env.get('STAGING_API_URL') or STAGING_URL).rstrip('/')
        if url != STAGING_URL:
            raise ValueError('Staging API must be the approved isolated endpoint')
    else:
        url = env.get('PRODUCTION_API_URL', '').rstrip('/')
        parsed = urlparse(url)
        if not url or parsed.scheme != 'https' or not parsed.hostname or parsed.username or parsed.password or parsed.query or parsed.fragment or '\n' in url or '\r' in url or parsed.hostname == 'xbcutdkqswfzkubkozng.supabase.co':
            raise ValueError('Approved HTTPS production API required; no staging fallback')
    return {'TARGET_ENV':target, 'BUILD_NUMBER':number, 'VERSION_NAME':version, 'BUILD_API_URL':url}

if __name__ == '__main__':
    values = resolve(os.environ)
    with Path(os.environ['GITHUB_ENV']).open('a', encoding='utf-8') as f:
        f.write(''.join(k+'='+v+'\n' for k,v in values.items()))
    print('Validated build inputs; API URL is not logged.')
