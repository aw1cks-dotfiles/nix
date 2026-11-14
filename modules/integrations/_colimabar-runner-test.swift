
// Appended to the patched manager so the probe calls its actual private runner.
extension ColimaManager {
    static func verifySubprocessCapture() async {
        let manager = ColimaManager()
        let result = await manager.runCommand([
            "/bin/sh", "-c",
            "dd if=/dev/zero bs=1048576 count=1 2>/dev/null | tr '\\000' x; printf stderr-marker >&2; exit 23"
        ])
        precondition(result.exitCode == 23, "Lost child exit status")
        precondition(result.output == String(repeating: "x", count: 1_048_576) + "stderr-marker",
                     "Incomplete combined stdout/stderr capture")
        print("ColimaBar runner: captured 1 MiB + stderr; exit status 23")
    }
}

@main
struct RunnerProbe {
    static func main() async {
        await ColimaManager.verifySubprocessCapture()
    }
}
