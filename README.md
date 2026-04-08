# Lumen

> An elegant PDF reader for macOS.

![Platform](https://img.shields.io/badge/platform-macOS%2014%2B-blue)
![Swift](https://img.shields.io/badge/Swift-5.9-orange)
![License](https://img.shields.io/badge/License-MIT-green)

## Features

- **Annotation Tools** — Highlight, underline, strikethrough, and sticky notes
- **Bookmark Management** — Organize and navigate your reading progress
- **Full-Text Search** — Quickly find content across documents
- **Outline Navigation** — Jump to chapters and sections
- **Thumbnail Sidebar** — Visual page preview for quick navigation
- **Recent Files** — Quick access to your last opened documents

## Screenshots

*Screenshots coming soon*

## Requirements

- macOS 14.0 or later
- Xcode 15.0 or later

## Installation

### Build from Source

```bash
# Clone the repository
git clone https://github.com/yourusername/Lumen.git
cd Lumen

# Open in Xcode
open Lumen.xcodeproj

# Build and run (Cmd+R)
```

## Architecture

Lumen follows a clean MVVM architecture:

```
Lumen/
├── App/              # Application entry point
├── Features/         # Feature modules
│   ├── Annotation/   # Annotation tools
│   ├── Document/     # Document management
│   ├── Outline/      # Document outline
│   ├── Reader/       # PDF reading view
│   ├── Search/       # Full-text search
│   └── Sidebar/      # Sidebar navigation
├── Infrastructure/    # Data persistence
└── Shared/           # Shared models and extensions
```

## Contributing

Contributions are welcome! Feel free to open issues and pull requests.

## License

MIT License — see [LICENSE](LICENSE) for details.
