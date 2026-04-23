# Windows Platform Notes

> **Status:** Placeholder — fill in when targeting Windows.

This file will document Windows-specific rules for any project being ported to or built natively for Windows.

## Topics to Document

- [ ] Win32 / WinUI / WinAppSDK patterns
- [ ] Windows Credential Manager (replacement for Keychain)
- [ ] Windows Hello (replacement for Touch ID / Face ID)
- [ ] Win32 clipboard APIs (replacement for NSPasteboard)
- [ ] SetCursor() / cursor management (replacement for NSCursor)
- [ ] WinUI theme APIs (replacement for NSAppearance)
- [ ] GetLastInputInfo() (replacement for NSEvent idle detection)
- [ ] Windows Event Log (replacement for OSLog)
- [ ] Path handling (backslash separators, drive letters vs Unix paths)
- [ ] AppPaths utility: FileManager vs Windows path APIs
- [ ] Cross-compile build system (Swift on Windows, or alternative)

## Reference

See `Style Guide/platform-notes/Apple Apps.md` for the macOS equivalents these will replace.

When you have concrete rules, replace this stub with the same structure as `Apple Apps.md`.
