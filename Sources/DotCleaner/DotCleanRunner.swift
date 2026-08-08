import Foundation

/// Статистика по папке до удаления.
struct FolderStats: Equatable {
    let totalFiles: Int
    let dotUnderscoreFiles: Int
    let imageFiles: Int
    let imageDotUnderscoreFiles: Int
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

    /// Считает все файлы, картинки и файлы вида "._*" рекурсивно в указанной папке.
    static func scan(folder: URL) -> FolderStats {
        guard let enumerator = FileManager.default.enumerator(
            at: folder,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: []
        ) else {
            return FolderStats(totalFiles: 0, dotUnderscoreFiles: 0, imageFiles: 0, imageDotUnderscoreFiles: 0)
        }

        var total = 0
        var dotUnderscore = 0
        var imageFiles = 0
        var imageDotUnderscore = 0

        for case let fileURL as URL in enumerator {
            let values = try? fileURL.resourceValues(forKeys: [.isRegularFileKey])
            guard values?.isRegularFile == true else { continue }

            total += 1
            let filename = fileURL.lastPathComponent
            let ext = fileURL.pathExtension.lowercased()
            let isDotUnderscore = filename.hasPrefix("._")
            let isImage = imageExtensions.contains(ext)

            if isDotUnderscore {
                dotUnderscore += 1
                if isImage {
                    imageDotUnderscore += 1
                }
            } else if isImage {
                imageFiles += 1
            }
        }

        return FolderStats(
            totalFiles: total,
            dotUnderscoreFiles: dotUnderscore,
            imageFiles: imageFiles,
            imageDotUnderscoreFiles: imageDotUnderscore
        )
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

    /// Запускает /usr/bin/dot_clean для указанной папки и возвращает, сколько файлов "._*" исчезло.
    /// beforeCount — количество "._*" файлов, полученное на этапе сканирования (чтобы не сканировать дважды).
    static func run(on folderURL: URL, beforeCount: Int, completion: @escaping (DotCleanResult) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/dot_clean")
            process.arguments = [folderURL.path]

            let stderrPipe = Pipe()
            process.standardError = stderrPipe
            process.standardOutput = Pipe()

            do {
                try process.run()
                process.waitUntilExit()

                let errData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                let errString = String(data: errData, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                // Гарантированно подчищаем оставшиеся файлы "._*", если dot_clean пропустил их (например, сиротские "._*.jpg" без исходного файла)
                removeRemainingDotUnderscoreFiles(in: folderURL)

                let afterStats = scan(folder: folderURL)
                let removed = max(0, beforeCount - afterStats.dotUnderscoreFiles)

                if process.terminationStatus != 0 && removed == 0 {
                    DispatchQueue.main.async {
                        completion(DotCleanResult(
                            removedCount: 0,
                            success: false,
                            errorMessage: errString?.isEmpty == false ? errString : "dot_clean завершился с ошибкой (код \(process.terminationStatus))"
                        ))
                    }
                    return
                }

                DispatchQueue.main.async {
                    completion(DotCleanResult(removedCount: removed, success: true, errorMessage: nil))
                }
            } catch {
                removeRemainingDotUnderscoreFiles(in: folderURL)
                let afterStats = scan(folder: folderURL)
                let removed = max(0, beforeCount - afterStats.dotUnderscoreFiles)

                DispatchQueue.main.async {
                    if removed > 0 {
                        completion(DotCleanResult(removedCount: removed, success: true, errorMessage: nil))
                    } else {
                        completion(DotCleanResult(removedCount: 0, success: false, errorMessage: error.localizedDescription))
                    }
                }
            }
        }
    }

    /// Удаляет рекурсивно оставшиеся скрытые файлы типа "._*", если dot_clean не смог удалить их.
    private static func removeRemainingDotUnderscoreFiles(in folder: URL) {
        guard let enumerator = FileManager.default.enumerator(
            at: folder,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: []
        ) else { return }

        for case let fileURL as URL in enumerator {
            if fileURL.lastPathComponent.hasPrefix("._") {
                try? FileManager.default.removeItem(at: fileURL)
            }
        }
    }
}
