"""Seed Gradle's content-addressed cache with the unchanged official Kotlin jar."""
import hashlib
from pathlib import Path
import shutil
import sys

source = Path(sys.argv[1])
sha256 = '9588fa696ac5507af764fd5660df6894185e12704ec1bc3f5cb772af4987f295'
sha1 = 'b13aed5cf8412f9ee9d1e4db21bdcfebcc24f606'
with source.open('rb') as stream:
    if hashlib.file_digest(stream, 'sha256').hexdigest() != sha256:
        raise SystemExit('Official Kotlin release SHA-256 mismatch')
with source.open('rb') as stream:
    if hashlib.file_digest(stream, 'sha1').hexdigest() != sha1:
        raise SystemExit('Maven Central Kotlin SHA-1 mismatch')
target = Path.home() / '.gradle/caches/modules-2/files-2.1/org.jetbrains.kotlin/kotlin-compiler-embeddable/2.2.21' / sha1 / source.name
target.parent.mkdir(parents=True, exist_ok=True)
shutil.copyfile(source, target)
print('Official Kotlin 2.2.21 compiler cached; SHA-256 and Maven checksum verified.')
