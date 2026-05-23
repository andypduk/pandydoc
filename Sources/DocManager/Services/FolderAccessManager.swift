import Foundation

final class FolderAccessManager {
    static let shared = FolderAccessManager()

    private let defaults = UserDefaults.standard
    private let bookmarkKey = "com.pandydoc.folderBookmarks"

    private var activeAccess: [URL] = []

    private init() {}

    var grantedFolders: [URL] {
        guard let data = defaults.data(forKey: bookmarkKey),
              let bookmarks = try? NSKeyedUnarchiver.unarchivedObject(ofClasses: [NSArray.self, NSData.self], from: data) as? [Data] else {
            return []
        }

        var folders: [URL] = []
        for bookmarkData in bookmarks {
            var isStale = false
            do {
                let url = try URL(resolvingBookmarkData: bookmarkData, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale)
                if !isStale {
                    folders.append(url)
                }
            } catch {
                continue
            }
        }
        return folders
    }

    func hasAccess(to url: URL) -> Bool {
        let folders = grantedFolders

        for folder in folders {
            if url.path.hasPrefix(folder.path) {
                var isStale = false
                do {
                    let bookmarkData = try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
                    let resolved = try URL(resolvingBookmarkData: bookmarkData, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale)
                    return !isStale && FileManager.default.isReadableFile(atPath: resolved.path)
                } catch {
                    return false
                }
            }
        }

        return FileManager.default.isReadableFile(atPath: url.path)
    }

    func grantAccess(to folderURL: URL) throws {
        let bookmarkData = try folderURL.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)

        var bookmarks: [Data] = []
        if let data = defaults.data(forKey: bookmarkKey),
           let existing = try? NSKeyedUnarchiver.unarchivedObject(ofClasses: [NSArray.self, NSData.self], from: data) as? [Data] {
            bookmarks = existing
        }

        bookmarks.append(bookmarkData)
        let archived = try NSKeyedArchiver.archivedData(withRootObject: bookmarks, requiringSecureCoding: false)
        defaults.set(archived, forKey: bookmarkKey)
    }

    func revokeAccess(for folderURL: URL) {
        guard let data = defaults.data(forKey: bookmarkKey),
              let bookmarks = try? NSKeyedUnarchiver.unarchivedObject(ofClasses: [NSArray.self, NSData.self], from: data) as? [Data] else {
            return
        }

        var filtered: [Data] = []
        for bookmarkData in bookmarks {
            do {
                var isStale = false
                let url = try URL(resolvingBookmarkData: bookmarkData, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale)
                if !isStale && url.path != folderURL.path {
                    filtered.append(bookmarkData)
                }
            } catch {
                continue
            }
        }

        if let archived = try? NSKeyedArchiver.archivedData(withRootObject: filtered, requiringSecureCoding: false) {
            defaults.set(archived, forKey: bookmarkKey)
        }
    }

    func resolveAllBookmarks() {
        for folder in grantedFolders {
            _ = folder.startAccessingSecurityScopedResource()
            activeAccess.append(folder)
        }
    }

    func releaseAllAccess() {
        for url in activeAccess {
            url.stopAccessingSecurityScopedResource()
        }
        activeAccess.removeAll()
    }
}
