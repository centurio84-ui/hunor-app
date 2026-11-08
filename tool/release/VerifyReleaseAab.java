import java.io.*;
import java.nio.file.*;
import java.security.*;
import java.security.cert.*;
import java.util.*;
import java.util.jar.*;

class VerifyReleaseAab {
    static String hex(byte[] bytes) { return HexFormat.of().formatHex(bytes); }
    static String digest(java.security.cert.Certificate cert) throws Exception {
        return hex(MessageDigest.getInstance("SHA-256").digest(cert.getEncoded()));
    }
    static boolean debugCertificate(X509Certificate cert) {
        String dn = cert.getSubjectX500Principal().getName().toLowerCase(Locale.ROOT);
        return dn.contains("cn=android debug") || dn.contains("cn=androiddebug");
    }
    public static void main(String[] args) throws Exception {
        if (args.length != 4) throw new IllegalArgumentException("AAB keystore alias report.json required");
        String password = System.getenv("ANDROID_KEYSTORE_PASSWORD");
        if (password == null || password.isEmpty()) throw new IllegalStateException("Missing signing password");
        char[] chars = password.toCharArray();
        KeyStore keys;
        try { keys = KeyStore.getInstance(new File(args[1]), chars); }
        finally { Arrays.fill(chars, '\0'); }
        var expected = (X509Certificate) keys.getCertificate(args[2]);
        if (expected == null || debugCertificate(expected)) throw new SecurityException("Release certificate missing or debug certificate configured");
        expected.checkValidity();
        String expectedHash = digest(expected), actualHash = null;
        long verifiedEntries = 0;
        try (JarFile jar = new JarFile(args[0], true)) {
            var entries = jar.entries();
            byte[] buffer = new byte[65536];
            while (entries.hasMoreElements()) {
                JarEntry entry = entries.nextElement();
                if (entry.isDirectory()) continue;
                try (InputStream in = jar.getInputStream(entry)) { while (in.read(buffer) != -1) {} }
                String name = entry.getName().toUpperCase(Locale.ROOT);
                if (name.equals("META-INF/MANIFEST.MF") || name.matches("META-INF/[^/]+\\.(SF|RSA|DSA|EC)")) continue;
                CodeSigner[] signers = entry.getCodeSigners();
                if (signers == null || signers.length != 1) throw new SecurityException("Unsigned or unexpected multiple signer entry");
                var leaf = (X509Certificate) signers[0].getSignerCertPath().getCertificates().get(0);
                if (debugCertificate(leaf)) throw new SecurityException("Debug signer rejected");
                actualHash = digest(leaf);
                if (!MessageDigest.isEqual(expected.getEncoded(), leaf.getEncoded())) throw new SecurityException("AAB signer differs from configured release keystore");
                verifiedEntries++;
            }
        }
        if (verifiedEntries == 0) throw new SecurityException("AAB has no signed payload entries");
        String json = "{\n  \"crypto_verified\": true,\n  \"release_keystore_match\": true,\n  \"debug_signer\": false,\n  \"signed_payload_entries\": " + verifiedEntries + ",\n  \"expected_signer_sha256\": \"" + expectedHash + "\",\n  \"actual_signer_sha256\": \"" + actualHash + "\"\n}\n";
        Files.writeString(Path.of(args[3]), json);
        System.out.println("Verified signed AAB payload; signer matches existing release keystore; debug signer rejected.");
        System.out.println("Release certificate SHA-256: " + expectedHash);
    }
}
