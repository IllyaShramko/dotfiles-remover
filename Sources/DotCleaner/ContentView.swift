import SwiftUI
import UniformTypeIdentifiers

/// Этапы работы приложения.
enum Stage: Equatable {
    case selecting          // выбор папки (drop zone + кнопка)
    case scanning           // идёт подсчёт файлов
    case confirming(FolderStats) // показана статистика, ждём решения пользователя
    case cleaning           // идёт выполнение dot_clean
    case done               // готово (кнопка "Готово" вернёт на первый этап)
}

struct ContentView: View {
    @State private var stage: Stage = .selecting
    @State private var isDropTargeted = false
    @State private var isHoveringDropZone = false
    @State private var selectedFolder: URL?
    @State private var lastRemovedCount: Int = 0
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 24) {
            // MARK: - Header
            headerView

            // MARK: - Main Content Switcher
            VStack {
                switch stage {
                case .selecting:
                    selectingView
                        .transition(.asymmetric(insertion: .opacity.combined(with: .scale(scale: 0.96)), removal: .opacity))
                case .scanning:
                    scanningView
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                case .confirming(let stats):
                    confirmingView(stats: stats)
                        .transition(.asymmetric(insertion: .opacity.combined(with: .move(edge: .bottom)), removal: .opacity))
                case .cleaning:
                    cleaningView
                        .transition(.opacity)
                case .done:
                    doneView
                        .transition(.asymmetric(insertion: .opacity.combined(with: .scale(scale: 1.04)), removal: .opacity))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(28)
        .frame(minWidth: 500, minHeight: 420)
        .background(
            ZStack {
                Color(NSColor.windowBackgroundColor)

                LinearGradient(
                    colors: [
                        Color.accentColor.opacity(0.07),
                        Color.purple.opacity(0.04),
                        Color.clear
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
            .ignoresSafeArea()
        )
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: stageKey)
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

    // MARK: - Header Component
    private var headerView: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.accentColor.opacity(0.2), Color.purple.opacity(0.15)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 56, height: 56)
                    .overlay(
                        Circle()
                            .stroke(Color.accentColor.opacity(0.3), lineWidth: 1)
                    )
                    .shadow(color: Color.accentColor.opacity(0.15), radius: 8, x: 0, y: 4)

                Image(systemName: "wand.and.stars")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.accentColor, Color.purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            VStack(spacing: 4) {
                Text("DotCleaner")
                    .font(.system(size: 22, weight: .bold, design: .rounded))

                Text("Удаление скрытых файлов картинок («._*.jpg», «._*.png», «._*.jpeg») после авторетуши Reblum")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
        }
    }

    // MARK: - Stage 1: выбор папки
    private var selectingView: some View {
        VStack(spacing: 18) {
            dropZone

            Button {
                selectFolder()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "folder.badge.plus")
                        .font(.system(size: 15, weight: .semibold))
                    Text("Выбрать папку…")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundStyle(.white)
                .padding(.vertical, 10)
                .padding(.horizontal, 24)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.accentColor, Color.accentColor.opacity(0.85)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .shadow(color: Color.accentColor.opacity(0.25), radius: 6, x: 0, y: 3)
                )
            }
            .buttonStyle(.plain)
        }
    }

    private var dropZone: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    isDropTargeted
                    ? Color.accentColor.opacity(0.12)
                    : (isHoveringDropZone ? Color.secondary.opacity(0.08) : Color.secondary.opacity(0.04))
                )

            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(
                    isDropTargeted ? Color.accentColor : Color.secondary.opacity(0.25),
                    style: StrokeStyle(lineWidth: isDropTargeted ? 2.5 : 1.5, dash: isDropTargeted ? [8, 4] : [6, 4])
                )

            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(isDropTargeted ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.1))
                        .frame(width: 56, height: 56)

                    Image(systemName: isDropTargeted ? "arrow.down.doc.fill" : "tray.and.arrow.down.fill")
                        .font(.system(size: 26, weight: .medium))
                        .foregroundStyle(isDropTargeted ? Color.accentColor : Color.secondary)
                        .scaleEffect(isDropTargeted ? 1.15 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isDropTargeted)
                }

                VStack(spacing: 4) {
                    Text("Перетащите сюда папку")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(isDropTargeted ? Color.accentColor : Color.primary)

                    Text("с фотографиями или файлами после ретуши")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(20)
        }
        .frame(height: 165)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHoveringDropZone = hovering
            }
        }
        .onDrop(of: [UTType.fileURL], isTargeted: $isDropTargeted) { providers in
            handleDrop(providers: providers)
        }
    }

    // MARK: - Stage 2: сканирование
    private var scanningView: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .stroke(Color.accentColor.opacity(0.2), lineWidth: 4)
                    .frame(width: 60, height: 60)

                ProgressView()
                    .controlSize(.large)
            }

            VStack(spacing: 4) {
                Text("Сканирование папки…")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                Text("Подсчёт скрытых системных файлов")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(height: 180)
    }

    // MARK: - Stage 3: подтверждение
    private func confirmingView(stats: FolderStats) -> some View {
        VStack(spacing: 18) {
            if let selectedFolder {
                HStack(spacing: 8) {
                    Image(systemName: "folder.fill")
                        .foregroundStyle(Color.accentColor)
                    Text(selectedFolder.lastPathComponent)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(Color.accentColor.opacity(0.1))
                        .overlay(Capsule().stroke(Color.accentColor.opacity(0.2), lineWidth: 1))
                )
            }

            // Карточки статистики
            HStack(spacing: 10) {
                statCard(
                    title: "Всего файлов",
                    value: "\(stats.totalFiles)",
                    icon: "doc.on.doc.fill",
                    color: Color.blue
                )

                statCard(
                    title: "Картинок",
                    value: "\(stats.imageFiles)",
                    subtitle: ".jpg, .png, .jpeg",
                    icon: "photo.on.rectangle.angled",
                    color: Color.purple
                )

                statCard(
                    title: "Скрытые дубликаты",
                    value: "\(stats.dotUnderscoreFiles)",
                    subtitle: stats.imageDotUnderscoreFiles > 0 ? "Картинок: \(stats.imageDotUnderscoreFiles)" : nil,
                    icon: stats.dotUnderscoreFiles > 0 ? "trash.fill" : "checkmark.shield.fill",
                    color: stats.dotUnderscoreFiles > 0 ? Color.orange : Color.green
                )
            }

            if stats.dotUnderscoreFiles > 0 {
                VStack(spacing: 14) {
                    Text("Хотите удалить скрытые дубликаты?")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))

                    HStack(spacing: 12) {
                        Button {
                            cancelToSelecting()
                        } label: {
                            Text("Отмена")
                                .font(.system(size: 13, weight: .medium))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)

                        Button {
                            startCleaning(beforeCount: stats.dotUnderscoreFiles)
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "sparkles")
                                Text("Удалить (\(stats.dotUnderscoreFiles))")
                            }
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.red.opacity(0.9), Color.orange],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .shadow(color: Color.red.opacity(0.3), radius: 5, x: 0, y: 2)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            } else {
                VStack(spacing: 14) {
                    Text("Скрытых дубликатов не найдено — папка уже чистая!")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)

                    Button("Назад") {
                        cancelToSelecting()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
            }
        }
    }

    private func statCard(title: String, value: String, subtitle: String? = nil, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(color)
                Spacer()
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.primary)
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)

                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 9, weight: .regular))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(color.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(color.opacity(0.18), lineWidth: 1)
                )
        )
    }

    // MARK: - Stage 4: выполнение очистки
    private var cleaningView: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.15))
                    .frame(width: 64, height: 64)

                ProgressView()
                    .controlSize(.large)
            }

            VStack(spacing: 4) {
                Text("Удаление скрытых файлов…")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                Text("Выполняется очистка через системную утилиту dot_clean")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(height: 180)
    }

    // MARK: - Stage 5: результат
    private var doneView: some View {
        VStack(spacing: 18) {
            if let errorMessage {
                ZStack {
                    Circle()
                        .fill(Color.red.opacity(0.15))
                        .frame(width: 64, height: 64)
                    Image(systemName: "xmark.octagon.fill")
                        .font(.system(size: 38, weight: .semibold))
                        .foregroundStyle(.red)
                }

                VStack(spacing: 6) {
                    Text("Произошла ошибка")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.red)
                    Text(errorMessage)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                }
            } else {
                ZStack {
                    Circle()
                        .fill(Color.green.opacity(0.15))
                        .frame(width: 64, height: 64)
                        .shadow(color: Color.green.opacity(0.3), radius: 10, x: 0, y: 4)

                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 38, weight: .bold))
                        .foregroundStyle(.green)
                }

                VStack(spacing: 6) {
                    Text("Очистка завершена!")
                        .font(.system(size: 17, weight: .bold, design: .rounded))

                    Text(lastRemovedCount > 0
                         ? "Успешно удалено скрытых файлов: \(lastRemovedCount)"
                         : "Скрытых файлов не обнаружено.")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }

            Button {
                cancelToSelecting()
            } label: {
                Text("Готово")
                    .font(.system(size: 13, weight: .semibold))
                    .padding(.horizontal, 28)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
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

