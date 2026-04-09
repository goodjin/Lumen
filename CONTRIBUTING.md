# Contributing to Lumen

Thank you for your interest in contributing to Lumen! This document provides guidelines and instructions for contributing to this project.

## Building the Project

### Prerequisites

- macOS 14.0 or later
- Xcode 15.0 or later
- Swift 5.9 or later

### Local Build Steps

```bash
# 1. Clone the repository
git clone https://github.com/goodjin/Lumen.git
cd Lumen

# 2. Open the project in Xcode
open Lumen.xcodeproj

# 3. Select a scheme and run (Cmd+R)
# For testing, select the "LumenTests" scheme
```

## Code Style

We use standard Swift conventions and recommend the following tools to maintain code quality:

### SwiftFormatter

Run `swift-format` before committing to ensure consistent formatting:

```bash
# Format a single file
swift format -i path/to/File.swift

# Format the entire project
swift format -i --recursive Lumen/
```

### SwiftLint

This project uses SwiftLint for linting. Install it via Homebrew:

```bash
brew install swiftlint
```

Run the linter:

```bash
swiftlint
```

## Pull Request Process

1. **Fork the repository** — Create your own fork of the repo
2. **Create a branch** — Use a descriptive branch name:
   - `feat/your-feature-name`
   - `fix/your-bug-fix`
   - `refactor/your-refactor`
3. **Make your changes** — Follow the code style guidelines
4. **Write tests** — Ensure tests pass (see Testing section)
5. **Commit your changes** — Use Conventional Commits format (see below)
6. **Push to your fork** — `git push origin your-branch-name`
7. **Open a Pull Request** — Fill out the PR template
8. **Review** — Address any feedback from maintainers
9. **Merge** — Once approved, maintainers will merge your PR

## Testing

Tests are located in `LumenTests/` and can be run from Xcode:

```bash
# Via Xcode
# Product > Test (Cmd+U)

# Via command line
xcodebuild test -scheme LumenTests -destination 'platform=macOS'
```

### Running Specific Tests

```bash
# Run a specific test file
xcodebuild test -scheme LumenTests -only-testing:LumenTests/FileServiceTests

# Run tests matching a pattern
xcodebuild test -scheme LumenTests -only-testing:LumenTests/DocumentRepositoryTests/testLoadRecentDocuments
```

All new features should include appropriate tests. Bug fixes should include a test case that verifies the fix.

## Good First Issues

New contributors looking for a starting point can look for issues labeled with `good first issue`. These issues are typically:

- Well-defined and contained in scope
- Have clear acceptance criteria
- Require minimal context to get started

Visit our [issues page](https://github.com/goodjin/Lumen/labels/good%20first%20issue) to find opportunities to contribute.

## Commit Message Format

This project follows [Conventional Commits](https://www.conventionalcommits.org/) specification:

```
<type>(<scope>): <description>

[optional body]

[optional footer(s)]
```

### Types

| Type | Description |
|------|-------------|
| `feat` | A new feature |
| `fix` | A bug fix |
| `docs` | Documentation only changes |
| `style` | Changes that do not affect code meaning (formatting) |
| `refactor` | Code change that neither fixes a bug nor adds a feature |
| `test` | Adding or correcting tests |
| `chore` | Maintenance tasks (dependencies, build config) |

### Examples

```
feat(search): add case-insensitive search option

fix(annotation): prevent crash when deleting last annotation
```

## License

By contributing to Lumen, you agree that your contributions will be licensed under the MIT License.
