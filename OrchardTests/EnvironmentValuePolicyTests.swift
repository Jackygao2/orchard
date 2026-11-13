import Testing
@testable import Orchard

@Test("Secret-key matching is case-insensitive and uses the specified substrings")
func secretEnvironmentKeys() {
    for key in ["db_password", "CLIENT_secret", "Api_Token", "private_KEY", "MONKEY"] {
        #expect(EnvironmentValuePolicy.isSecret(key))
        #expect(EnvironmentValuePolicy.displayValue(key: key, value: "fixture", revealed: false) == "••••••••")
        #expect(EnvironmentValuePolicy.displayValue(key: key, value: "fixture", revealed: true) == "fixture")
    }
    for key in ["PATH", "LANG", "TERM"] {
        #expect(!EnvironmentValuePolicy.isSecret(key))
        #expect(EnvironmentValuePolicy.displayValue(key: key, value: "ordinary", revealed: false) == "ordinary")
    }
}

@Test("Environment parsing preserves empty values and equals signs, and rejects malformed entries")
func parseEnvironmentEntry() {
    #expect(EnvironmentValuePolicy.parse("TOKEN=")?.value == "")
    #expect(EnvironmentValuePolicy.parse("PATH=a=b")?.value == "a=b")
    #expect(EnvironmentValuePolicy.parse("=value") == nil)
    #expect(EnvironmentValuePolicy.parse("TOKEN") == nil)
}
