import Foundation
import Darwin

public enum BoundedProcess {
    public static func run(executable: String, arguments: [String], timeout: TimeInterval, maxBytes: Int) -> Data? {
        guard timeout.isFinite, timeout > 0, maxBytes > 0 else { return nil }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        let inherited = ProcessInfo.processInfo.environment
        var environment = ["PATH": "/usr/bin:/bin:/usr/sbin:/sbin", "LANG": "en_US.UTF-8"]
        for key in ["HOME", "TMPDIR", "__CF_USER_TEXT_ENCODING"] {
            if let value = inherited[key] { environment[key] = value }
        }
        process.environment = environment
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        process.standardInput = FileHandle.nullDevice
        defer {
            try? pipe.fileHandleForReading.close()
            try? pipe.fileHandleForWriting.close()
        }
        do { try process.run() } catch { return nil }
        try? pipe.fileHandleForWriting.close()
        defer {
            if process.isRunning {
                process.terminate()
                _ = Darwin.kill(process.processIdentifier, SIGKILL)
            }
            process.waitUntilExit()
        }
        let descriptor = pipe.fileHandleForReading.fileDescriptor
        guard fcntl(descriptor, F_SETFL, O_NONBLOCK) != -1 else { return nil }
        let deadline = ProcessInfo.processInfo.systemUptime + timeout
        var output = Data()
        var bytes = [UInt8](repeating: 0, count: 4096)
        while ProcessInfo.processInfo.systemUptime < deadline {
            var descriptorState = pollfd(fd: descriptor, events: Int16(POLLIN | POLLHUP), revents: 0)
            let ready = Darwin.poll(&descriptorState, 1, 20)
            if ready < 0 {
                if errno == EINTR { continue }
                return nil
            }
            if ready == 0 { continue }
            let count = bytes.withUnsafeMutableBytes { buffer in Darwin.read(descriptor, buffer.baseAddress, buffer.count) }
            if count > 0 {
                guard output.count + count <= maxBytes else { return nil }
                output.append(contentsOf: bytes.prefix(count))
            } else if count == 0 {
                while process.isRunning && ProcessInfo.processInfo.systemUptime < deadline {
                    Thread.sleep(forTimeInterval: 0.01)
                }
                guard !process.isRunning else { return nil }
                process.waitUntilExit()
                return process.terminationStatus == 0 ? output : nil
            } else if errno != EAGAIN && errno != EINTR {
                return nil
            }
        }
        return nil
    }
}
