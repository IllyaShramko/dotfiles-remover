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
        // contentsOfDirectory с пустыми options явно включает скрытые файлы
        // и каталоги (в том числе начинающиеся с «.»).
        guard let children = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey, .isRegularFileKey],
            options: []
        ) else { return }

        for child in children {
            let values = try? child.resourceValues(forKeys: [.isDirectoryKey, .isRegularFileKey])
            let name = child.lastPathComponent

            if values?.isDirectory == true {
                // Не заходим внутрь скрытых системных каталогов (.Spotlight-V100, .fseventsd и т.п.),
                // но всё равно считаем саму скрытую папку.
                if name.hasPrefix(".") {
                    // Скрытая папка — считаем как 1 скрытый элемент (удалится целиком).
                    total += 1
                    hidden += 1
                } else {
                    scanDirectory(child, total: &total, hidden: &hidden,
                                  imageFiles: &imageFiles, hiddenImage: &hiddenImage)
                }
                continue
            }

            guard values?.isRegularFile == true else { continue }
            total += 1

            let isHidden = name.hasPrefix(".")
            let ext = child.pathExtension.lowercased()
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
    private static func removeHiddenFiles(in folder: URL, removedCount: inout Int, errors: inout [String]) {
        guard let children = try? FileManager.default.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: []
        ) else { return }

        for child in children {
            let name = child.lastPathComponent

            if name.hasPrefix(".") {
                // Скрытый элемент (файл или папка) — удаляем целиком.
                do {
                    try FileManager.default.removeItem(at: child)
                    removedCount += 1
                } catch {
                    errors.append("\(name): \(error.localizedDescription)")
                }
            } else {
                // Обычная (не скрытая) папка — заходим рекурсивно.
                let values = try? child.resourceValues(forKeys: [.isDirectoryKey])
                if values?.isDirectory == true {
                    removeHiddenFiles(in: child, removedCount: &removedCount, errors: &errors)
                }
            }
        }
    }
}
