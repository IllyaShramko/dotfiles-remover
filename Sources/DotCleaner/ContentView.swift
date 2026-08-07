import SwiftUI
import UniformTypeIdentifiers

/// Этапы работы приложения.
enum Stage {
    case selecting          // выбор папки (drop zone + кнопка)
    case scanning           // идёт подсчёт файлов
    case confirming(FolderStats) // показана статистика, ждём решения пользователя
    case cleaning           // идёт выполнение dot_clean
    case done               // готово (кнопка "Готово" вернёт на первый этап)
}

struct ContentView: View {
    @State private var stage: Stage = .selecting
    @State private var isDropTargeted = false
    @State private var selectedFolder: URL?
    @State private var lastRemovedCount: Int = 0
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 20) {
            Text("DotCleaner")
                .font(.title2)
                .bold()

            Text("Удаляет скрытые файлы «._имя.jpeg», которые создаёт Reblum после авторетуши")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            switch stage {
            case .selecting:
                selectingView
            case .scanning:
                scanningView
            case .confirming(let stats):
                confirmingView(stats: stats)
            case .cleaning:
                cleaningView
            case .done:
                doneView
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.easeInOut(duration: 0.2), value: stageKey)
    }

    // Ключ для анимации переключения этапов
    private var stageKey: String {
        switch stage {
        case .selecting: return "selecting"
        case .scanning: return "scanning"
        case .confirming: return "confirming"
        case .cleaning: return "cleaning"
        case .done: return "done"
        }
    }

    // MARK: - Этап 1: выбор папки

    private var selectingView: some View {
        VStack(spacing: 20) {
            dropZone

            Button {
                selectFolder()
            } label: {
                Label("Выбрать папку…", systemImage: "folder")
                    .frame(maxWidth: .infinity)
            }
            .controlSize(.large)
        }
    }

    private var dropZone: some View {
        RoundedRectangle(cornerRadius: 12)
            .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [6]))
            .foregroundStyle(isDropTargeted ? Color.accentColor : Color.secondary.opacity(0.5))
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isDropTargeted ? Color.accentColor.opacity(0.1) : Color.clear)
            )
            .frame(height: 140)
            .overlay(
                VStack(spacing: 8) {
                    Image(systemName: "tray.and.arrow.down")
                        .font(.system(size: 28))
                        .foregroundStyle(.secondary)
                    Text("Перетащите сюда папку с фотографиями")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            )
            .onDrop(of: [UTType.fileURL], isTargeted: $isDropTargeted) { providers in
                handleDrop(providers: providers)
            }
    }

    // MARK: - Этап 2: сканирование

    private var scanningView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .controlSize(.large)
            Text("Сканирую папку…")
                .foregroundStyle(.secondary)
        }
        .frame(height: 180)
    }

    // MARK: - Этап 3: подтверждение

    private func confirmingView(stats: FolderStats) -> some View {
        VStack(spacing: 16) {
            if let selectedFolder {
                Label(selectedFolder.lastPathComponent, systemImage: "folder.fill")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 6) {
                statRow(label: "Всего файлов:", value: "\(stats.totalFiles)")
                statRow(label: "Скрытых дубликатов:", value: "\(stats.dotUnderscoreFiles)")
            }
            .padding(16)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.secondary.opacity(0.08)))

            if stats.dotUnderscoreFiles > 0 {
                Text("Хотите удалить скрытые дубликаты?")
                    .font(.headline)

                HStack(spacing: 12) {
                    Button("Отменить") {
                        cancelToSelecting()
                    }
                    .controlSize(.large)

                    Button("Удалить") {
                        startCleaning(beforeCount: stats.dotUnderscoreFiles)
                    }
                    .controlSize(.large)
                    .buttonStyle(.borderedProminent)
                }
            } else {
                Text("Скрытых дубликатов не найдено — папка уже чистая.")
                    .foregroundStyle(.secondary)

                Button("Назад") {
                    cancelToSelecting()
                }
                .controlSize(.large)
            }
        }
    }

    private func statRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .bold()
        }
    }

    // MARK: - Этап 4: выполнение очистки

    private var cleaningView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .controlSize(.large)
            Text("Удаляю скрытые дубликаты…")
                .foregroundStyle(.secondary)
        }
        .frame(height: 180)
    }

    // MARK: - Этап 5: результат

    private var doneView: some View {
        VStack(spacing: 16) {
            if let errorMessage {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.red)
                Text("Ошибка")
                    .font(.headline)
                Text(errorMessage)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.green)
                Text("Готово")
                    .font(.headline)
                Text(lastRemovedCount > 0
                     ? "Удалено скрытых файлов: \(lastRemovedCount)"
                     : "Скрытых файлов не найдено.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Button("Готово") {
                cancelToSelecting()
            }
            .controlSize(.large)
            .buttonStyle(.borderedProminent)
        }
    }

    // MARK: - Действия

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }

        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, error in
            guard let data = item as? Data,
                  let url = URL(dataRepresentation: data, relativeTo: nil) else { return }

            var isDirectory: ObjCBool = false
            let exists = FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)

            DispatchQueue.main.async {
                guard exists, isDirectory.boolValue else { return }
                beginScan(folder: url)
            }
        }
        return true
    }

    private func selectFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Выбрать"

        if panel.runModal() == .OK, let url = panel.url {
            beginScan(folder: url)
        }
    }

    private func beginScan(folder: URL) {
        selectedFolder = folder
        stage = .scanning

        DotCleanRunner.scanAsync(folder: folder) { stats in
            stage = .confirming(stats)
        }
    }

    private func startCleaning(beforeCount: Int) {
        guard let selectedFolder else { return }
        stage = .cleaning

        DotCleanRunner.run(on: selectedFolder, beforeCount: beforeCount) { result in
            if result.success {
                lastRemovedCount = result.removedCount
                errorMessage = nil
            } else {
                lastRemovedCount = 0
                errorMessage = result.errorMessage
            }
            stage = .done
        }
    }

    private func cancelToSelecting() {
        selectedFolder = nil
        lastRemovedCount = 0
        errorMessage = nil
        stage = .selecting
    }
}

#Preview {
    ContentView()
}
