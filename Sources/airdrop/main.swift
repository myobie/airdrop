import AppKit
import Darwin
import Foundation

enum CLIError: LocalizedError {
    case missingTextValue
    case duplicateTextInput
    case emptyTextInput
    case invalidStandardInput
    case missingPath(String)
    case unsupportedItems

    var errorDescription: String? {
        switch self {
        case .missingTextValue:
            return "Missing value for --text."
        case .duplicateTextInput:
            return "Provide text via stdin or --text, not both."
        case .emptyTextInput:
            return "Text input is empty after trimming whitespace."
        case .invalidStandardInput:
            return "Standard input is not valid UTF-8 text."
        case .missingPath(let path):
            return "Path does not exist: \(path)"
        case .unsupportedItems:
            return "AirDrop cannot share this combination of items."
        }
    }
}

final class ShareRequest {
    let dryRun: Bool
    let items: [Any]
    private let temporaryFiles: [URL]

    init(dryRun: Bool, items: [Any], temporaryFiles: [URL] = []) {
        self.dryRun = dryRun
        self.items = items
        self.temporaryFiles = temporaryFiles
    }

    func cleanupTemporaryFiles() {
        let fileManager = FileManager.default

        for fileURL in temporaryFiles where fileManager.fileExists(atPath: fileURL.path) {
            try? fileManager.removeItem(at: fileURL)
        }
    }
}

@MainActor
final class ShareDelegate: NSObject, NSSharingServiceDelegate {
    private let request: ShareRequest

    init(request: ShareRequest) {
        self.request = request
    }

    func sharingService(_ sharingService: NSSharingService, didShareItems items: [Any]) {
        request.cleanupTemporaryFiles()
        print("Share completed.")
        NSApp.terminate(nil)
    }

    func sharingService(_ sharingService: NSSharingService, didFailToShareItems items: [Any], error: any Error) {
        request.cleanupTemporaryFiles()
        fputs("Share failed: \(error.localizedDescription)\n", stderr)
        NSApp.terminate(nil)
        exit(1)
    }
}

@MainActor
func usage() {
    let program = (CommandLine.arguments.first as NSString?)?.lastPathComponent ?? "airdrop"
    print("Usage:")
    print("  \(program) [--dry-run] [--text <text-or-url>] [<path> ...]")
    print("  <command> | \(program) [--dry-run] [<path> ...]")
    print("")
    print("Positional arguments must be existing file paths.")
    print("Text input comes from either --text or stdin, is trimmed, and is shared as a URL when it matches a full link.")
    print("Other text is written to a temporary /tmp/*.txt file and shared as a file.")
    print("Use --dry-run to print the parsed items instead of opening AirDrop.")
}

@MainActor
func expandedPath(from argument: String) -> String {
    (argument as NSString).expandingTildeInPath
}

@MainActor
func validatedFileURLs(from arguments: [String]) throws -> [URL] {
    let fileManager = FileManager.default

    return try arguments.map { argument in
        let expandedPath = expandedPath(from: argument)
        guard fileManager.fileExists(atPath: expandedPath) else {
            throw CLIError.missingPath(expandedPath)
        }

        return URL(fileURLWithPath: expandedPath)
    }
}

@MainActor
func standardInputText() throws -> String? {
    guard isatty(FileHandle.standardInput.fileDescriptor) == 0 else {
        return nil
    }

    let data = FileHandle.standardInput.readDataToEndOfFile()
    guard !data.isEmpty else {
        return nil
    }

    guard let text = String(data: data, encoding: .utf8) else {
        throw CLIError.invalidStandardInput
    }

    return text
}

@MainActor
func normalizedText(_ text: String) throws -> String {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else {
        throw CLIError.emptyTextInput
    }

    return trimmed
}

@MainActor
func detectedURL(from text: String) -> URL? {
    let range = NSRange(text.startIndex..<text.endIndex, in: text)
    guard
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue),
        let match = detector.firstMatch(in: text, options: [], range: range),
        match.range.location == 0,
        match.range.length == range.length,
        let url = match.url,
        !url.isFileURL
    else {
        return nil
    }

    return url
}

@MainActor
func temporaryTextFileURL() -> URL {
    URL(fileURLWithPath: "/tmp", isDirectory: true)
        .appendingPathComponent("airdrop-\(ProcessInfo.processInfo.globallyUniqueString).txt")
}

@MainActor
func temporaryTextFile(for text: String) throws -> URL {
    let fileURL = temporaryTextFileURL()
    try text.write(to: fileURL, atomically: true, encoding: .utf8)
    return fileURL
}

@MainActor
func resolvedShareRequest(from arguments: [String]) throws -> ShareRequest {
    var positionalArguments: [String] = []
    var textArgument: String?
    var dryRun = false
    var index = 0
    var parsingOptions = true

    while index < arguments.count {
        let argument = arguments[index]

        if parsingOptions {
            if argument == "--" {
                parsingOptions = false
                index += 1
                continue
            }

            if argument == "--help" || argument == "-h" {
                usage()
                exit(0)
            }

            if argument == "--dry-run" {
                dryRun = true
                index += 1
                continue
            }

            if argument == "--text" {
                guard textArgument == nil else {
                    throw CLIError.duplicateTextInput
                }

                let nextIndex = index + 1
                guard nextIndex < arguments.count else {
                    throw CLIError.missingTextValue
                }

                textArgument = arguments[nextIndex]
                index += 2
                continue
            }

            if argument.hasPrefix("--text=") {
                guard textArgument == nil else {
                    throw CLIError.duplicateTextInput
                }

                textArgument = String(argument.dropFirst("--text=".count))
                index += 1
                continue
            }
        }

        positionalArguments.append(argument)
        index += 1
    }

    let stdinText = try standardInputText()
    if textArgument != nil && stdinText != nil {
        throw CLIError.duplicateTextInput
    }

    var items: [Any] = []
    var temporaryFiles: [URL] = []

    if let rawText = textArgument ?? stdinText {
        let text = try normalizedText(rawText)
        if let url = detectedURL(from: text) {
            items.append(url)
        } else {
            let fileURL = try temporaryTextFile(for: text)
            temporaryFiles.append(fileURL)
            items.append(fileURL)
        }
    }

    items.append(contentsOf: try validatedFileURLs(from: positionalArguments))

    guard !items.isEmpty else {
        usage()
        exit(64)
    }

    return ShareRequest(dryRun: dryRun, items: items, temporaryFiles: temporaryFiles)
}

@MainActor
func describe(_ item: Any) -> String {
    switch item {
    case let url as URL where url.isFileURL:
        return "file: \(url.path)"
    case let url as URL:
        return "url: \(url.absoluteString)"
    case let text as String:
        return "text: \(String(reflecting: text))"
    case let text as NSString:
        return "text: \(String(reflecting: text as String))"
    default:
        return "\(type(of: item)): \(String(describing: item))"
    }
}

@MainActor
func printDryRun(for items: [Any]) {
    print("Would share \(items.count) item(s):")

    for (index, item) in items.enumerated() {
        print("\(index + 1). \(describe(item))")
    }
}

@MainActor
func main() {
    do {
        let request = try resolvedShareRequest(from: Array(CommandLine.arguments.dropFirst()))
        defer {
            request.cleanupTemporaryFiles()
        }

        if request.dryRun {
            printDryRun(for: request.items)
            return
        }

        let application = NSApplication.shared
        application.setActivationPolicy(.accessory)
        application.activate(ignoringOtherApps: true)

        guard let service = NSSharingService(named: .sendViaAirDrop) else {
            fputs("AirDrop service is unavailable on this Mac.\n", stderr)
            exit(1)
        }

        let delegate = ShareDelegate(request: request)
        service.delegate = delegate
        guard service.canPerform(withItems: request.items) else {
            throw CLIError.unsupportedItems
        }

        service.perform(withItems: request.items)

        withExtendedLifetime((service, delegate)) {
            application.run()
        }
    } catch {
        fputs("\(error.localizedDescription)\n", stderr)
        exit(1)
    }
}

main()
