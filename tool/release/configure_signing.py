"""Create ephemeral Gradle signing inputs from existing GitHub secrets; never log values."""
import base64
import os
from pathlib import Path


def property_value(value):
    out = ''
    for i, c in enumerate(value):
        if c == '\\': out += '\\\\'
        elif c == '\n': out += '\\n'
        elif c == '\r': out += '\\r'
        elif c == '\t': out += '\\t'
        elif c in '=:# !' and (i == 0 or c != ' '): out += '\\' + c
        elif ord(c) > 126 or ord(c) < 32:
            encoded = c.encode('utf-16-be')
            out += ''.join('\\u' + encoded[n:n+2].hex() for n in range(0, len(encoded), 2))
        else: out += c
    return out


def configure(root=Path('.')):
    keys = ['ANDROID_KEYSTORE_BASE64', 'ANDROID_KEYSTORE_PASSWORD', 'ANDROID_KEY_ALIAS', 'ANDROID_KEY_PASSWORD']
    if any(not os.environ.get(k) for k in keys):
        raise SystemExit('Required existing Android signing secrets are missing; release build stopped.')
    keystore = root / 'android/app/release.keystore'
    keystore.write_bytes(base64.b64decode(''.join(os.environ[keys[0]].split()), validate=True))
    keystore.chmod(0o600)
    props = root / 'android/key.properties'
    values = {'storeFile': 'release.keystore', 'storePassword': os.environ[keys[1]],
              'keyAlias': os.environ[keys[2]], 'keyPassword': os.environ[keys[3]]}
    props.write_text(''.join(k+'='+property_value(v)+'\n' for k, v in values.items()), encoding='ascii')
    props.chmod(0o600)
    print('Existing release keystore configured; no new key generated.')

if __name__ == '__main__':
    configure()

