# Lumen

> A elegant, native PDF reader for macOS — built for researchers, students, and power users.

![Platform](https://img.shields.io/badge/platform-macOS%2014%2B-blue)
![Swift](https://img.shields.io/badge/Swift-5.9-orange)
![License](https://img.shields.io/badge/License-MIT-green)

## Why Lumen?

**macOS Preview is basic. Skim lacks polish. PDF Expert is expensive and slow.**

| Feature | Lumen | Preview | Skim | PDF Expert |
|---------|:-----:|:-------:|:----:|:----------:|
| Annotation tools | Native UI | Limited | Basic | Yes (paid) |
| Bookmark management | Yes | No | No | Yes |
| Full-text search | Instant | Slow | Basic | Yes |
| Large PDF support | Optimized | Struggles | Variable | Heavy |
| Native macOS feel | SwiftUI | Yes | X11-based | Electron |
| Free & Open Source | Yes | Yes | Yes | No ($12/mo) |

Lumen combines the simplicity of Preview with the power of paid apps — all in a lightweight, native macOS package.

## Features

- **Annotation Tools** — Highlight, underline, strikethrough, and sticky notes. Finally, annotate PDFs without paying for Adobe or losing your highlights when files sync.

- **Bookmark Management** — Never lose your place again. Organize reading progress with named bookmarks and find them instantly.

- **Full-Text Search** — Find any word or phrase across entire documents in milliseconds. No more scrolling through 500-page papers manually.

- **Outline Navigation** — Jump directly to chapters and sections. Built-in PDF bookmarks make navigation effortless.

- **Thumbnail Sidebar** — Visual page previews let you navigate intuitively. Find the page you need at a glance.

- **Recent Files** — Pick up right where you left off. Quick access to your last opened documents on launch.

## Quick Start

```bash
# Clone the repository
git clone https://github.com/goodjin/Lumen.git
cd Lumen

# Open in Xcode
open Lumen.xcodeproj

# Build and run (Cmd+R)
```

## Requirements

- macOS 14.0 or later
- Apple Silicon or Intel (Rosetta)

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
