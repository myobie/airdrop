import AppKit
import Foundation

@MainActor
final class ShareDelegate: NSObject, NSSharingServiceDelegate {
    func sharingService(_ sharingService: NSSharingService, didShareItems items: [Any]) {
        print("Share completed.")
        NSApp.terminate(nil)
    }

    func sharingService(_ sharingService: NSSharingService, didFailToShareItems items: [Any], error: any Error) {
        fputs("Share failed: \(error.localizedDescription)\n", stderr)
        NSApp.terminate(nil)
        exit(1)
    }
}

@MainActor
func usage() {
    let program = (CommandLine.arguments.first as NSString?)?.lastPathComponent ?? "airdrop"
    print("Usage: \(program) <path> [<path> ...]")
    print("Opens the macOS AirDrop sharing flow for one or more files.")
}

@MainActor
func validatedURLs(from arguments: [String]) throws -> [URL] {
    guard !arguments.isEmpty else {
        usage()
        exit(64)
    }

    if arguments.contains("--help") || arguments.contains("-h") {
        usage()
        exit(0)
    }

    let fileManager = FileManager.default

    return try arguments.map { argument in
        let expandedPath = (argument as NSString).expandingTildeInPath
        guard fileManager.fileExists(atPath: expandedPath) else {
            struct MissingPathError: LocalizedError {
                let path: String

                var errorDescription: String? {
                    "Path does not exist: \(path)"
                }
            }

            throw MissingPathError(path: expandedPath)
        }

        return URL(fileURLWithPath: expandedPath)
    }
}

@MainActor
func main() {
    do {
        let urls = try validatedURLs(from: Array(CommandLine.arguments.dropFirst()))

        let application = NSApplication.shared
        application.setActivationPolicy(.accessory)
        application.activate(ignoringOtherApps: true)

        guard let service = NSSharingService(named: .sendViaAirDrop) else {
            fputs("AirDrop service is unavailable on this Mac.\n", stderr)
            exit(1)
        }

        let delegate = ShareDelegate()
        service.delegate = delegate
        service.perform(withItems: urls)

        withExtendedLifetime((service, delegate)) {
            application.run()
        }
    } catch {
        fputs("\(error.localizedDescription)\n", stderr)
        exit(1)
    }
}

main()
