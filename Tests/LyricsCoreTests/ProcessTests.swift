import Foundation
import LyricsCore

struct ProcessTests {
    func run() {
        let output = BoundedProcess.run(executable: "/usr/bin/printf", arguments: ["hello"], timeout: 2, maxBytes: 100)
        expectEqual(output.flatMap { String(data: $0, encoding: .utf8) }, "hello")
        expectNil(BoundedProcess.run(executable: "/usr/bin/false", arguments: [], timeout: 2, maxBytes: 100))
        expectNil(BoundedProcess.run(executable: "/does-not-exist", arguments: [], timeout: 1, maxBytes: 100))
        expectNil(BoundedProcess.run(executable: "/usr/bin/perl", arguments: ["-e", "print 'x' x 10000"], timeout: 2, maxBytes: 100))
        let start = ProcessInfo.processInfo.systemUptime
        expectNil(BoundedProcess.run(executable: "/usr/bin/perl", arguments: ["-e", "$SIG{TERM}='IGNORE'; sleep 10"], timeout: 0.2, maxBytes: 100))
        expectTrue(ProcessInfo.processInfo.systemUptime - start < 2)
        setenv("PERL5OPT", "-MNotAllowed", 1)
        defer { unsetenv("PERL5OPT") }
        let safeOutput = BoundedProcess.run(executable: "/usr/bin/perl", arguments: ["-e", "print exists $ENV{PERL5OPT} ? 'unsafe' : 'safe'"], timeout: 2, maxBytes: 100)
        expectEqual(safeOutput.flatMap { String(data: $0, encoding: .utf8) }, "safe")
    }
}
