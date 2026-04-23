# Apple Platform Notes

> **When This Applies:** Read this file for any project targeting Apple platforms (macOS, iOS, watchOS, tvOS). These rules apply in addition to the Unified Standards and your App Style Guide.

---

## Concurrency

- **@MainActor isolation**: ViewModels that update published properties must be `@MainActor` isolated. Use `@MainActor class MyViewModel: ObservableObject`.
- **Swift 6 Sendable**: All types that cross actor boundaries must conform to `Sendable`. Mark value types as `Sendable` with `@unchecked Sendable` only when you can manually prove thread safety.
- **Task cancellation**: Long-running tasks must check `Task.isCancelled` and clean up. Use `.task` modifier — SwiftUI cancels it automatically on view disappear.
- **async/await patterns**: Prefer `async/await` over callback-based APIs. Use `withCheckedContinuation` to bridge legacy callback APIs.

---

## Platform Abstraction (macOS Cross-Platform Portability)

This codebase must be written at an abstraction level that makes it feasible to port to Windows. SwiftUI views and pure Swift logic are inherently cross-platform. The risk is direct dependency on Apple-only frameworks. When touching any of the areas below, **always code against an abstraction layer** so the Apple implementation can be swapped for a Windows equivalent without rewriting business logic.

### macOS-only dependencies and their required abstractions

| Dependency | Current Usage | Abstraction Strategy |
|------------|--------------|---------------------|
| **Keychain (`Security` framework)** | Credential storage, retrieval, deletion | `KeychainStore` acts as the abstraction. On Windows, swap internals to Windows Credential Manager / DPAPI. Do not call `SecItem*` APIs outside of `KeychainStore`. |
| **Biometrics (`LocalAuthentication`)** | `LAContext` for Touch ID / Face ID | Keep biometric calls inside `KeychainStore`. On Windows, replace with Windows Hello. The public API stays the same. |
| **Clipboard (`NSPasteboard`)** | Copy to clipboard | Extract into a `ClipboardService` protocol or utility. On Windows, use Win32 clipboard APIs. |
| **Cursor control (`NSCursor`)** | Resize handle hover cursor | Wrap in a `CursorManager` utility or SwiftUI ViewModifier. On Windows, use `SetCursor()` / WinUI equivalents. |
| **App windows (`NSApp`, `NSAppearance`)** | Theme switching | Extract into a `ThemeManager` service. On Windows, use WinUI theme APIs. |
| **Event monitoring (`NSEvent`)** | Idle detection for auto-lock | Extract into a `UserActivityMonitor` protocol. On Windows, use `GetLastInputInfo()` or similar. |
| **System logging (`OSLog`, `os.Logger`)** | Log sinks | Already wrapped behind `#if os(macOS)` conditionals. On Windows, route to Event Log or file-only logging. The `AppLog` facade is platform-agnostic. |
| **macOS SwiftUI scenes** | `Settings {}`, `Window(id:)`, `.windowStyle(.hiddenTitleBar)` | App-entry-point concerns. On Windows, the `@main` App struct will need a platform-specific variant. Business logic and views remain shared. |
| **macOS SwiftUI environments** | `@Environment(\.openSettings)`, `@Environment(\.openWindow)` | Wrap in a `NavigationService` or app-level coordinator that can be implemented differently per platform. |

### Rules for new code

1. **Never call Apple-only APIs from Views or ViewModels directly.** Route through a service/utility layer. If you need the clipboard, call a `ClipboardService`, not `NSPasteboard`.
2. **Never add new `import AppKit` or `import Cocoa` statements** outside of dedicated platform-adapter files. If you need AppKit functionality, create or extend an existing adapter in `Utilities/` or `Services/`.
3. **Use `#if os(macOS)` / `#if os(Windows)` only in platform-adapter files**, never in Views, ViewModels, or business logic. The adapter provides a unified API; the consumer doesn't know which platform it's on.
4. **SwiftUI modifiers that are macOS-only** (`.help()`, `.onHover`, `.windowStyle`) are acceptable in Views — SwiftUI for Windows will either support them or they degrade gracefully. But if a modifier controls critical behavior, wrap it.
5. **File I/O paths**: Use `FileManager` APIs, not hardcoded `/Users/` paths. On Windows, paths use backslashes and different root structures.
6. **Networking and database layers** should be abstracted behind protocols — this enables platform-specific implementations.

### Existing abstractions that are already correct (example patterns)
- `KeychainStore` — single file encapsulating all Security framework calls
- `SessionManager` — single file encapsulating NSEvent monitoring
- Platform-agnostic log facade with platform sinks behind `#if os` conditionals

### When in doubt
If you're about to type `NS` or `import AppKit` in a file that isn't already a platform adapter — stop. Create or extend an adapter instead.

---

## Logging Architecture

Use `docs/logging/apple-logging-plan.md` as the canonical logging strategy.

At a high level:
- `macOS`: complete multi-sink logging stack from day one
- `iOS`: lean structured logger with runtime debug controls
- `watchOS`: deferred for now (no template logging stack yet)

For macOS, every app built on this template ships a complete, multi-sink logging system from day one. This is required infrastructure.

### Why This Matters

The logging system serves three audiences simultaneously:
1. **The developer** via the system log (Console.app / Xcode debugger)
2. **The in-app error console** (`ErrorLog.shared`) — observable, shown in the UI
3. **Companion diagnostics tooling** — tails file logs and reads in-app error stream for support workflows

### Required Files

Build these files in `Utilities/Logging/` at project start:

| File | Purpose |
|------|---------|
| `AppLog.swift` | Facade with category loggers. The only logging API used in app code. |
| `AppLogConfig.swift` | User-configurable verbosity + `AppLogState` thread-safe level store. |
| `AppLogHandler.swift` | `LogHandler` that fans out to all sinks. Defines `LogSink` protocol and `LogRecord`. |
| `LogStore.swift` | Manages log directory URL, current log file URL, rolling log file list, export. |
| `LogFormatter.swift` | Formats `LogRecord` into the string written to file. |
| `LogRedactor.swift` | PII redaction utilities. Scrubs emails, SQL values, tokens from metadata. |
| `Handlers/SystemLogSink.swift` | Writes to Apple's `os.Logger` / OSLog. |
| `Handlers/FileLogSink.swift` | Rolling file log with size + age rotation via `FileLogWriter`. |
| `Handlers/ErrorConsoleLogSink.swift` | Routes `.warning`+ to `ErrorLog.shared` on the main actor. |

And in `Utilities/`:

| File | Purpose |
|------|---------|
| `ErrorLog.swift` | `@Observable @MainActor` in-memory log store. 500-entry cap. Feeds the in-app console and AI panel context. |

### Architecture Diagram

```
AppLog.db.info("...", metadata: [...])
         │
         ▼
  AppLogHandler (LogHandler)
  • Checks AppLogState.minimumLevel() atomically
  • Builds LogRecord
  • Redacts metadata via LogRedactor
         │
    ┌────┴────┬──────────────┐
    ▼         ▼              ▼
SystemLog  FileLog      ErrorConsoleLog
 (OSLog)  (rolling     (→ ErrorLog.shared
           file)         @MainActor)
```

### Fan-Out Sinks

**`SystemLogSink`** — writes to `os.Logger`. Visible in Console.app and Xcode debugger.

**`FileLogSink`** — writes to a rolling file at `~/Application Support/[AppName]/Logs/app.log`. Rotates at 5 MB or 24 hours. Prunes files older than 30 days. Total cap 50 MB.

**`ErrorConsoleLogSink`** — routes `.warning` and above to `ErrorLog.shared` on the main actor. Triggers UI badge indicators and feeds the AI panel.

### `ErrorLog` — In-App Observable Store

`ErrorLog` is an `@Observable @MainActor` singleton holding the last 500 log entries across all levels. Use it to:
- Drive the in-app error console bar
- Feed AI panel context (recent errors and warnings)
- Badge navigation items when new errors occur

```swift
// Log to structured dev log only
AppLog.db.info("Fetched contacts.", metadata: ["count": .stringConvertible(count)])

// Log to both structured log AND in-app console (for user-visible errors)
AppLog.db.error("Failed to fetch lookups.", metadata: ["error": .string(error.localizedDescription)])
ErrorLog.shared.log("Failed to fetch lookups: \(error.localizedDescription)", source: "Contacts", level: .warning)
```

### `AppLog` — The Facade

```swift
enum AppLog {
    static let app    = logger("App")      // lifecycle, startup, migrations
    static let auth   = logger("Auth")     // login, logout, credentials
    static let db     = logger("Database") // queries, fetches, writes
    static let sync   = logger("Sync")     // background sync, reference data
    static let ui     = logger("UI")       // navigation, clipboard, window events
    static let network = logger("Network") // HTTP, external APIs
    static let ai     = logger("AI")       // AI chat, tool calls, provider APIs
}
```

Add domain-specific loggers as needed. Namespace all labels under `[AppName].[Category]`.

### `AppLogConfig` — Verbosity Control

User-configurable verbosity exposed in Settings. Four levels:

| Setting | Minimum Level | Use When |
|---------|--------------|---------|
| Errors Only | `.error` | Production default |
| Warnings + Errors | `.warning` | Investigating reported issues |
| Info + Warnings + Errors | `.info` | Active development |
| Verbose (Debug) | `.debug` | Deep debugging — do not commit |

`AppLogState` holds the minimum level as a `ManagedAtomic<Int>` for `nonisolated` access by log handlers without actor hops.

### Required Logs Settings Controls (macOS)

Every macOS project using this template must expose these controls in `Settings > Logs`:

- `Clear Current Log`: Truncate the active rolling log file only.
- `Reset Log History`: Delete all `.log` files in the app log directory, then recreate the active log file.
- `Clear Status Panel`: Clear only the in-app `ErrorLog` entries and unread-error indicator.

Rules:

- Use `.alert` for destructive confirmations (`Clear Current Log`, `Reset Log History`).
- Each action logs via `AppLog.ui` and shows an immediate user-visible result message.
- Log maintenance operations must not break file logging after completion.

### Log Retention Policy

| Limit | Value |
|-------|-------|
| Max file size before rotation | 5 MB |
| Max age before rotation | 24 hours |
| Max total log directory size | 50 MB |
| Max age for any file | 30 days |

### AppLog Usage Patterns

**Structured metadata — never string interpolation in the message:**

```swift
// WRONG
AppLog.db.info("Fetched \(count) contacts")

// RIGHT
AppLog.db.info("Fetched contacts.", metadata: ["count": .stringConvertible(count)])
```

**Entry + Outcome for any fallible operation:**

```swift
AppLog.db.info("Deleting record.", metadata: ["id": .stringConvertible(id)])
do {
    try await service.delete(id: id)
    AppLog.db.info("Deleted record.", metadata: ["id": .stringConvertible(id)])
} catch {
    AppLog.db.error("Failed to delete record.", metadata: [
        "id": .stringConvertible(id),
        "error": .string(error.localizedDescription)
    ])
}
```

### Bootstrap

Call once at app start, before any logging:

```swift
@main struct MyApp: App {
    init() {
        AppLog.bootstrap()  // must be first
    }
}
```

### iOS Baseline (Quick Rules)

For iOS apps, start with a lean logger service plus an in-app debug panel:

- logger service is iOS-only and isolated from watch targets
- compile-gated with `#if DEBUG || INTERNAL_LOGGING`
- runtime controls:
  - enable/disable logging
  - minimum log level (Error/Warning/Info/Debug)
  - console mirroring toggle
  - clear log
- no raw `print` calls in feature code
- log retention uses a bounded in-memory list unless a file sink is explicitly required

### watchOS Status

watchOS logging is intentionally deferred for now. Do not add a watch logging stack in template projects until a dedicated watch observability spec is in place.

### Never Log
- Passwords, tokens, or API keys — ever
- Full SQL with embedded user values — use `LogRedactor.redactSQL()`
- PII beyond debugging necessity: email local part is OK, full phone/address is not
- Anything that would be embarrassing if shown in a bug report

---

## Data Integrity

### Hard Deletes Allowed (Default)
Hard deletes are allowed by default. Use soft-delete only when the product explicitly requires retention, undo, or rollback semantics.

When soft-delete is required for a feature, document it in the feature spec and data model notes.

Typical hard-delete pattern:
```swift
try await dbService.delete(id: id)
// which runs: DELETE FROM contacts WHERE id = $1
```

### Mutation Logging
All database mutations (INSERT, UPDATE) must be recorded via `MutationLogService`. This captures a JSON snapshot before and after each change, enabling full rollback.

No direct SQL writes. All INSERT/UPDATE operations go through `MutationLogService`. The only exception is the mutation_log table itself.

---

## Build — xcodebuild Policy

Before handing off any implementation work, build the project with `xcodebuild` and report the result:

```bash
xcodebuild -project [AppName].xcodeproj -scheme [SchemeName] build 2>&1 | tail -20
```

Do as many passes as practical so the user encounters as few errors as possible when they test locally.

---

## SwiftUI Patterns

### Data Loading
Use `.task` for all async data loading — never `.onAppear` with `Task { await ... }`:

```swift
// WRONG
.onAppear {
    Task { await viewModel.loadData() }
}

// RIGHT
.task {
    await viewModel.loadData()
}
```

`.onAppear` is acceptable only for synchronous setup (theme restoration, non-async configuration).

### Sheet Dismiss
Always use `@Environment(\.dismiss)` — never set a boolean directly:

```swift
@Environment(\.dismiss) private var dismiss

Button("Cancel") { dismiss() }
```

### Form Grouping
Use `GroupBox` for all form sections — not `Form/Section`, not manual `VStack+Text`:

```swift
GroupBox("Section Label") {
    VStack(alignment: .leading, spacing: [DS_PREFIX]Spacing.compactGap) {
        LabeledField("Field Name", text: $value)
    }
}
```

### Confirmation Dialogs
Use `.alert` for destructive confirmations — not `.confirmationDialog`:

```swift
.alert("Delete Item?", isPresented: $showDelete) {
    Button("Delete", role: .destructive) { delete() }
    Button("Cancel", role: .cancel) {}
} message: {
    Text("This action cannot be undone.")
}
```

### Button Styles
Every button MUST have an explicit `.buttonStyle`:
- `.borderedProminent` — primary actions (with tint)
- `.bordered` — secondary actions (no tint)
- `.plain` — text links (with foreground style)

### Animation Durations
- **0.2s** `.easeInOut` — micro-interactions (sidebar toggle, hover, expand/collapse)
- **0.3s** `.easeInOut` — larger transitions (page transitions, sheet animations)
- Always specify duration and curve — no bare `withAnimation { }`.

### Accessibility
Every icon-only button MUST have `.help("description")` tooltip. No exceptions.

### Split Views
Use `HSplitView` (not `HStack + Divider`) for side-by-side resizable panels.
