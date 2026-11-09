"""Use only the byte-verified official Gradle distribution in this ephemeral runner."""
import hashlib
from pathlib import Path
import re
import sys

EXPECTED='b266d5ff6b90eada6dc3b20cb090e3731302e553a27c5d3e4df1f0d76beaff06'
archive=Path(sys.argv[1]).resolve()
with archive.open('rb') as f:
    digest=hashlib.file_digest(f,'sha256').hexdigest()
if digest != EXPECTED:
    raise SystemExit('Gradle distribution SHA-256 mismatch')
props=Path('android/gradle/wrapper/gradle-wrapper.properties')
text=props.read_text(encoding='utf-8-sig')
if 'distributionSha256Sum='+EXPECTED not in text:
    raise SystemExit('Expected pinned wrapper checksum missing')
text,count=re.subn(r'^distributionUrl=.*$',lambda _: 'distributionUrl='+archive.as_uri().replace(':','\\:'),text,flags=re.M)
if count != 1:
    raise SystemExit('Unexpected Gradle wrapper layout')
props.write_text(text,encoding='utf-8')
print('Using verified official Gradle 9.3.1 binary distribution; checksum enforcement retained.')
