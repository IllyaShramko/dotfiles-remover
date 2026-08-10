import SwiftUI

enum AppLanguage: String, CaseIterable, Identifiable {
    case english = "en"
    case ukrainian = "uk"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .english: return "English"
        case .ukrainian: return "Українська"
        }
    }

    var flagEmoji: String {
        switch self {
        case .english: return "🇬🇧"
        case .ukrainian: return "🇺🇦"
        }
    }
}

final class LanguageManager: ObservableObject {
    @AppStorage("appLanguage") var currentLanguage: AppLanguage = .ukrainian {
        willSet {
            objectWillChange.send()
        }
    }

    static let shared = LanguageManager()

    var l10n: L10n {
        L10n(currentLanguage)
    }
}

struct L10n {
    let language: AppLanguage

    init(_ language: AppLanguage) {
        self.language = language
    }

    var headerSubtitle: String {
        switch language {
        case .english:
            return "Find and remove all hidden files (.DS_Store, ._*, .Thumbs.db, etc.) from a selected folder"
        case .ukrainian:
            return "Пошук та видалення всіх прихованих файлів (.DS_Store, ._*, .Thumbs.db тощо) з обраної папки"
        }
    }

    var selectFolderButton: String {
        switch language {
        case .english:
            return "Select Folder…"
        case .ukrainian:
            return "Вибрати папку…"
        }
    }

    var dropZoneTitle: String {
        switch language {
        case .english:
            return "Drag and drop folder here"
        case .ukrainian:
            return "Перетягніть сюди папку"
        }
    }

    var dropZoneSubtitle: String {
        switch language {
        case .english:
            return "to scan for hidden files"
        case .ukrainian:
            return "для пошуку прихованих файлів"
        }
    }

    var scanningTitle: String {
        switch language {
        case .english:
            return "Scanning folder…"
        case .ukrainian:
            return "Сканування папки…"
        }
    }

    var scanningSubtitle: String {
        switch language {
        case .english:
            return "Counting hidden system files"
        case .ukrainian:
            return "Підрахунок прихованих системних файлів"
        }
    }

    var cardTotalFiles: String {
        switch language {
        case .english:
            return "Total Files"
        case .ukrainian:
            return "Усього файлів"
        }
    }

    var cardImages: String {
        switch language {
        case .english:
            return "Images"
        case .ukrainian:
            return "Зображень"
        }
    }

    var cardHiddenFiles: String {
        switch language {
        case .english:
            return "Hidden Files"
        case .ukrainian:
            return "Прихованих файлів"
        }
    }

    func cardImagesSubtitle(_ count: Int) -> String? {
        guard count > 0 else { return nil }
        switch language {
        case .english:
            return "Hidden images: \(count)"
        case .ukrainian:
            return "Прихованих зображень: \(count)"
        }
    }

    var confirmPrompt: String {
        switch language {
        case .english:
            return "Do you want to delete hidden files?"
        case .ukrainian:
            return "Бажаєте видалити приховані файли?"
        }
    }

    var cancelButton: String {
        switch language {
        case .english:
            return "Cancel"
        case .ukrainian:
            return "Скасувати"
        }
    }

    func deleteButton(_ count: Int) -> String {
        switch language {
        case .english:
            return "Delete (\(count))"
        case .ukrainian:
            return "Видалити (\(count))"
        }
    }

    var folderCleanTitle: String {
        switch language {
        case .english:
            return "No hidden files found — folder is clean!"
        case .ukrainian:
            return "Прихованих файлів не знайдено — папка вже чиста!"
        }
    }

    var backButton: String {
        switch language {
        case .english:
            return "Back"
        case .ukrainian:
            return "Назад"
        }
    }

    var cleaningTitle: String {
        switch language {
        case .english:
            return "Deleting hidden files…"
        case .ukrainian:
            return "Видалення прихованих файлів…"
        }
    }

    var cleaningSubtitle: String {
        switch language {
        case .english:
            return "Removing hidden files from the folder"
        case .ukrainian:
            return "Видалення прихованих файлів із папки"
        }
    }

    var errorTitle: String {
        switch language {
        case .english:
            return "An Error Occurred"
        case .ukrainian:
            return "Сталася помилка"
        }
    }

    var doneTitle: String {
        switch language {
        case .english:
            return "Cleaning Complete!"
        case .ukrainian:
            return "Очищення завершено!"
        }
    }

    func doneSubtitleSuccess(_ count: Int) -> String {
        switch language {
        case .english:
            return "Successfully removed hidden files: \(count)"
        case .ukrainian:
            return "Успішно видалено прихованих файлів: \(count)"
        }
    }

    var doneSubtitleEmpty: String {
        switch language {
        case .english:
            return "No hidden files found."
        case .ukrainian:
            return "Прихованих файлів не знайдено."
        }
    }

    var doneButton: String {
        switch language {
        case .english:
            return "Done"
        case .ukrainian:
            return "Готово"
        }
    }

    var menuLanguage: String {
        switch language {
        case .english:
            return "Language"
        case .ukrainian:
            return "Мова"
        }
    }

}
