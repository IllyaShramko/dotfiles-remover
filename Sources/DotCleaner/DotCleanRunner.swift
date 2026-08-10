import Foundation

/// Статистика по папке до удаления.
struct FolderStats: Equatable {
    let totalFiles: Int
    let hiddenFiles: Int
    let imageFiles: Int
    let hiddenImageFiles: Int
}

/// Результат выполнения очистки.
struct DotCleanResult {
    let removedCount: Int
    let success: Bool
    let errorMessage: String?
}

enum DotCleanRunner {

    /// Поддерживаемые расширения файлов изображений (.jpg, .jpeg, .png и др.).
    static let imageExtensions: Set<String> = [
        "jpg", "jpeg", "png", "heic", "heif", "webp", "tiff", "tif", "bmp", "gif", "raw", "arw", "cr2", "nef", "dng", "svg"
    ]

    // MARK: - POSIX Directory Listing

    /// Элемент каталога, полученный через POSIX readdir.
    private struct DirectoryEntry {
        let name: String
        let url: URL
        let isDirectory: Bool
        let isFile: Bool
    }

    /// Читает содержимое каталога через POSIX opendir/readdir,
    /// чтобы гарантированно получить ВСЕ элементы, включая скрытые файлы
    /// типа «._*», «.DS_Store» и т.д., которые Foundation API может фильтровать
    /// на файловых системах APFS/HFS+.
    private static func posixContents(of directory: URL) -> [DirectoryEntry] {
        let dirPath = directory.path
        guard let dir = opendir(dirPath) else { return [] }
        defer { closedir(dir) }

        var entries: [DirectoryEntry] = []

        while let entryPtr = readdir(dir) {
            let entry = entryPtr.pointee

            let name = withUnsafeBytes(of: entry.d_name) { ptr in
                String(cString: ptr.baseAddress!.assumingMemoryBound(to: CChar.self))
            }
            guard name != "." && name != ".." else { continue }

            let childURL = directory.appendingPathComponent(name)
            var isDir = entry.d_type == DT_DIR
            var isFile = entry.d_type == DT_REG

            // Для неизвестного типа (DT_UNKNOWN) или симлинков — используем stat,
            // который следует по симлинкам к реальному файлу/каталогу.
            if entry.d_type == DT_UNKNOWN || entry.d_type == DT_LNK {
                var statBuf = stat()
                if stat(childURL.path, &statBuf) == 0 {
                    isDir = (statBuf.st_mode & S_IFMT) == S_IFDIR
                    isFile = (statBuf.st_mode & S_IFMT) == S_IFREG
                }
            }

            entries.append(DirectoryEntry(name: name, url: childURL, isDirectory: isDir, isFile: isFile))
        }
        return entries
    }

    // MARK: - Scanning

    /// Считает все файлы, картинки и скрытые файлы (начинающиеся с «.») рекурсивно в указанной папке.
    static func scan(folder: URL) -> FolderStats {
        var total = 0
        var hidden = 0
        var imageFiles = 0
        var hiddenImage = 0

        scanDirectory(
            folder,
            total: &total,
            hidden: &hidden,
            imageFiles: &imageFiles,
            hiddenImage: &hiddenImage
        )

        return FolderStats(
            totalFiles: total,
            hiddenFiles: hidden,
            imageFiles: imageFiles,
            hiddenImageFiles: hiddenImage
        )
    }

    private static func scanDirectory(
        _ directory: URL,
        total: inout Int,
        hidden: inout Int,
        imageFiles: inout Int,
        hiddenImage: inout Int
    ) {
        let entries = posixContents(of: directory)

        for entry in entries {
            if entry.isDirectory {
                if entry.name.hasPrefix(".") {
                    // Скрытая папка — считаем как 1 скрытый элемент (удалится целиком).
                    total += 1
                    hidden += 1
                } else {
                    scanDirectory(entry.url, total: &total, hidden: &hidden,
                                  imageFiles: &imageFiles, hiddenImage: &hiddenImage)
                }
                continue
            }

            guard entry.isFile else { continue }
            total += 1

            let isHidden = entry.name.hasPrefix(".")
            let ext = entry.url.pathExtension.lowercased()
            let isImage = imageExtensions.contains(ext)

            if isHidden {
                hidden += 1
                if isImage { hiddenImage += 1 }
            } else if isImage {
                imageFiles += 1
            }
        }
    }

    /// Асинхронная версия scan для использования на фоновом потоке.
    static func scanAsync(folder: URL, completion: @escaping (FolderStats) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let stats = scan(folder: folder)
            DispatchQueue.main.async {
                completion(stats)
            }
        }
    }

    // MARK: - Cleaning

    /// Удаляет все скрытые файлы и папки (начинающиеся с «.») в указанной папке рекурсивно.
    /// beforeCount — количество скрытых элементов, полученное на этапе сканирования.
    static func run(on folderURL: URL, beforeCount: Int, completion: @escaping (DotCleanResult) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            var removedCount = 0
            var errors: [String] = []

            removeHiddenFiles(in: folderURL, removedCount: &removedCount, errors: &errors)

            DispatchQueue.main.async {
                if errors.isEmpty {
                    completion(DotCleanResult(removedCount: removedCount, success: true, errorMessage: nil))
                } else if removedCount > 0 {
                    // Частичный успех — что-то удалили, но были ошибки.
                    let combinedErrors = errors.prefix(3).joined(separator: "\n")
                    completion(DotCleanResult(removedCount: removedCount, success: true, errorMessage: combinedErrors))
                } else {
                    let combinedErrors = errors.prefix(3).joined(separator: "\n")
                    completion(DotCleanResult(removedCount: 0, success: false, errorMessage: combinedErrors))
                }
            }
        }
    }

    /// Рекурсивно удаляет все скрытые файлы и папки внутри указанного каталога.
    /// Использует POSIX readdir для гарантированного обнаружения всех скрытых элементов.
    private static func removeHiddenFiles(in folder: URL, removedCount: inout Int, errors: inout [String]) {
        let entries = posixContents(of: folder)

        for entry in entries {
            if entry.name.hasPrefix(".") {
                // Скрытый элемент (файл или папка) — удаляем целиком.
                do {
                    try FileManager.default.removeItem(at: entry.url)
                    removedCount += 1
                } catch {
                    errors.append("\(entry.name): \(error.localizedDescription)")
                }
            } else if entry.isDirectory {
                // Обычная (не скрытая) папка — заходим рекурсивно.
                removeHiddenFiles(in: entry.url, removedCount: &removedCount, errors: &errors)
            }
        }
    }
}
