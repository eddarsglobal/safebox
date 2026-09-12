import Foundation
import UIKit
import UniformTypeIdentifiers

final class ShareViewController: UIViewController {
    private let appGroup = "group.com.safebox.desktop.share"
    private let statusLabel = UILabel()
    private let doneButton = UIButton(type: .system)
    private var finished = false

    // R58 intake policy. Keep these values aligned with SafeBoxShareInboxBridge.mm.
    private let maxPayloadBytes: Int64 = 512 * 1024 * 1024
    private let maxReadyRequests = 8
    private let maxInboxBytes: Int64 = 1024 * 1024 * 1024
    private let staleReadyAge: TimeInterval = 24 * 60 * 60
    private let staleIncompleteAge: TimeInterval = 60 * 60

    override func viewDidLoad() {
        super.viewDidLoad()
        buildUI()
        stageFirstSupportedAttachment()
    }

    private func buildUI() {
        view.backgroundColor = .systemBackground

        let title = UILabel()
        title.text = "SafeBox"
        title.font = .preferredFont(forTextStyle: .title2)
        title.textAlignment = .center

        statusLabel.text = "Preparing shared file…"
        statusLabel.font = .preferredFont(forTextStyle: .body)
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 0

        doneButton.setTitle("Done", for: .normal)
        doneButton.isHidden = true
        doneButton.addTarget(self, action: #selector(doneTapped), for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [title, statusLabel, doneButton])
        stack.axis = .vertical
        stack.spacing = 18
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    private func stageFirstSupportedAttachment() {
        guard
            let item = extensionContext?.inputItems.compactMap({ $0 as? NSExtensionItem }).first,
            let providers = item.attachments,
            providers.count == 1,
            let provider = providers.first
        else {
            reject("attachment-count", userMessage: "SafeBox accepts one file at a time.")
            return
        }

        if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { [weak self] item, error in
                guard let self else { return }
                if let url = item as? URL {
                    self.stage(url: url)
                } else {
                    self.fail(error?.localizedDescription ?? "The shared file could not be read.")
                }
            }
            return
        }

        let candidate = provider.registeredTypeIdentifiers.first { identifier in
            guard let type = UTType(identifier) else { return false }
            return type.conforms(to: .data) || type.conforms(to: .content)
        }

        guard let typeIdentifier = candidate else {
            reject("unsupported-type", userMessage: "This shared item is not a supported file.")
            return
        }

        provider.loadFileRepresentation(forTypeIdentifier: typeIdentifier) { [weak self] url, error in
            guard let self else { return }
            guard let url else {
                self.fail(error?.localizedDescription ?? "The shared file could not be read.")
                return
            }
            self.stage(url: url)
        }
    }

    private func stage(url: URL) {
        let scoped = url.startAccessingSecurityScopedResource()
        defer {
            if scoped { url.stopAccessingSecurityScopedResource() }
        }

        var request: URL?
        do {
            let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
            guard values.isRegularFile == true, values.isSymbolicLink != true else {
                throw IntakeError.policy("non-regular")
            }
            let sourceSize = Int64(values.fileSize ?? -1)
            guard sourceSize >= 0, sourceSize <= maxPayloadBytes else {
                throw IntakeError.policy("payload-size")
            }
            guard let groupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup) else {
                throw IntakeError.policy("container")
            }

            let inbox = groupURL.appendingPathComponent("ShareInbox", isDirectory: true)
            try createPrivateDirectory(inbox)

            let usage = try cleanupAndMeasureInbox(inbox)
            guard usage.readyCount < maxReadyRequests else {
                throw IntakeError.policy("request-quota")
            }
            guard usage.readyBytes <= maxInboxBytes - sourceSize else {
                throw IntakeError.policy("byte-quota")
            }
            NSLog("SAFEBOX_IOS_SHARE_HARDENING_POLICY_PASS")

            let newRequest = inbox.appendingPathComponent(UUID().uuidString.lowercased(), isDirectory: true)
            request = newRequest
            try createPrivateDirectory(newRequest)

            let name = sanitizedFileName(url.lastPathComponent)
            let destination = newRequest.appendingPathComponent(name, isDirectory: false)
            let partial = newRequest.appendingPathComponent(".payload.partial", isDirectory: false)

            // Copy into a hidden temporary name first. READY is not created until the
            // payload is complete, hardened and atomically renamed into its final name.
            try FileManager.default.copyItem(at: url, to: partial)
            try hardenFile(partial)
            let copiedValues = try partial.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
            let copiedSize = Int64(copiedValues.fileSize ?? -1)
            guard copiedValues.isRegularFile == true,
                  copiedValues.isSymbolicLink != true,
                  copiedSize == sourceSize,
                  copiedSize <= maxPayloadBytes else {
                throw IntakeError.policy("copy-verification")
            }
            try FileManager.default.moveItem(at: partial, to: destination)
            try hardenFile(destination)
            NSLog("SAFEBOX_IOS_SHARE_HARDENING_ATOMIC_COMMIT_PASS")

            let ready = newRequest.appendingPathComponent("READY", isDirectory: false)
            try Data().write(to: ready, options: [.atomic])
            try hardenFile(ready)

            NSLog("SAFEBOX_IOS_SHARE_EXTENSION_STAGE_PASS")
            DispatchQueue.main.async { [weak self] in
                self?.statusLabel.text = "Saved securely for SafeBox. Open SafeBox to continue."
                self?.doneButton.isHidden = false
            }
        } catch IntakeError.policy(let reason) {
            if let request { try? FileManager.default.removeItem(at: request) }
            reject(reason, userMessage: "SafeBox could not accept this shared file.")
        } catch {
            if let request { try? FileManager.default.removeItem(at: request) }
            fail("SafeBox could not stage this file.")
        }
    }

    private func cleanupAndMeasureInbox(_ inbox: URL) throws -> (readyCount: Int, readyBytes: Int64) {
        let fm = FileManager.default
        let now = Date()
        let requests = try fm.contentsOfDirectory(
            at: inbox,
            includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey, .creationDateKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )
        var removed = 0
        var readyCount = 0
        var readyBytes: Int64 = 0

        for request in requests {
            let values = try request.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey, .creationDateKey, .contentModificationDateKey])
            guard values.isDirectory == true, values.isSymbolicLink != true else {
                try? fm.removeItem(at: request)
                removed += 1
                continue
            }
            let date = values.contentModificationDate ?? values.creationDate ?? now
            let age = max(0, now.timeIntervalSince(date))
            let ready = request.appendingPathComponent("READY", isDirectory: false)
            let readyExists = fm.fileExists(atPath: ready.path)
            if readyExists {
                let readyValues = try ready.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
                if readyValues.isRegularFile != true || readyValues.isSymbolicLink == true {
                    try? fm.removeItem(at: request)
                    removed += 1
                    continue
                }
            }
            let isReady = readyExists
            if (isReady && age > staleReadyAge) || (!isReady && age > staleIncompleteAge) {
                try? fm.removeItem(at: request)
                removed += 1
                continue
            }
            guard isReady else { continue }

            let entries = try fm.contentsOfDirectory(
                at: request,
                includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey],
                options: []
            )
            var payloads = 0
            var bytes: Int64 = 0
            for entry in entries where entry.lastPathComponent != "READY" {
                let entryValues = try entry.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
                if entryValues.isRegularFile == true, entryValues.isSymbolicLink != true {
                    payloads += 1
                    bytes += Int64(entryValues.fileSize ?? 0)
                }
            }
            if payloads != 1 || bytes < 0 || bytes > maxPayloadBytes {
                try? fm.removeItem(at: request)
                removed += 1
                continue
            }
            readyCount += 1
            readyBytes += bytes
        }
        NSLog("SAFEBOX_IOS_SHARE_HARDENING_CLEANUP_PASS removed=\(removed)")
        return (readyCount, readyBytes)
    }

    private func createPrivateDirectory(_ url: URL) throws {
        try FileManager.default.createDirectory(
            at: url,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
    }

    private func hardenFile(_ url: URL) throws {
        var attributes: [FileAttributeKey: Any] = [.posixPermissions: 0o600]
        attributes[.protectionKey] = FileProtectionType.complete
        try FileManager.default.setAttributes(attributes, ofItemAtPath: url.path)
    }

    private func sanitizedFileName(_ raw: String) -> String {
        let source = raw.isEmpty ? "shared-file" : raw
        let cleaned = source.unicodeScalars.filter { scalar in
            !CharacterSet.controlCharacters.contains(scalar) && scalar != "/" && scalar != ":" && scalar != "\\"
        }
        let result = String(String.UnicodeScalarView(cleaned)).trimmingCharacters(in: .whitespacesAndNewlines)
        return String((result.isEmpty ? "shared-file" : result).prefix(120))
    }

    private func reject(_ reason: String, userMessage: String) {
        NSLog("SAFEBOX_IOS_SHARE_HARDENING_REJECT: reason=\(reason)")
        fail(userMessage)
    }

    private func fail(_ message: String) {
        NSLog("SAFEBOX_IOS_SHARE_EXTENSION_STAGE_FAIL")
        DispatchQueue.main.async { [weak self] in
            self?.statusLabel.text = message
            self?.doneButton.isHidden = false
        }
    }

    @objc private func doneTapped() {
        guard !finished else { return }
        finished = true
        extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }

    private enum IntakeError: Error {
        case policy(String)
    }
}
