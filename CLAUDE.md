# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Hunch is a Swift command-line tool and library for interacting with the Notion.so API. It provides a library (`HunchKit`) for programmatic access and a CLI tool (`hunch`) for command-line operations.

## Build and Development Commands

```bash
swift build                          # Debug build
swift test                           # Run all tests
swift test --filter BlockTests       # Run specific test class
swift test --filter testBookmarkBlock # Run a single test
./format-files.sh                    # SwiftLint auto-fix then lint check
mint install adamwulf/hunch@main --force  # Install globally via Mint
```

The CLI requires `NOTION_KEY` environment variable set to a Notion API token:
```bash
swift run hunch databases [--limit N] [--format jsonl]
swift run hunch pages --id <pageId>
swift run hunch blocks <pageId> [--format markdown]
swift run hunch export <databaseId> --output-dir <path>
```

## Architecture

### Two-Layer API Design

- **`NotionAPI`** (singleton) — Low-level HTTP client. Handles auth headers, rate limiting with exponential backoff (max 3 retries), and JSON encoding/decoding. Uses `withCheckedContinuation` to bridge callback-based URLSession to async/await. Targets Notion API version `2021-05-13`.
- **`HunchAPI`** (singleton, wraps `NotionAPI`) — High-level facade. Handles cursor-based pagination automatically and recursive block tree fetching (populates `Block.children` when `hasChildren` is true).

### Discriminated Union Pattern

The codebase models Notion's polymorphic types using Swift enums with associated values:

- **`Block`** has a `BlockType` enum (determines which JSON field to decode) and a `BlockTypeObject` enum (wraps the type-specific struct like `ParagraphBlock`, `CodeBlock`, etc.). Custom `Codable` implementation switches on `BlockType` to encode/decode the correct field.
- **`Property`** uses the same pattern for 23+ property types. Decoding failures produce `.null` instead of throwing, allowing partial data loading.
- **`Parent`** discriminates between `database`, `page`, `block`, and `workspace` parent types.

### Adding a New Block Type

Six changes in `Block.swift` plus a test:

1. Add case to `BlockType` enum (e.g., `case myType = "my_type"`)
2. Create the block struct (e.g., `public struct MyTypeBlock: Codable { ... }`)
3. Add case to `BlockTypeObject` enum (e.g., `case myType(MyTypeBlock)`)
4. Add `CodingKey` (e.g., `case myType = "my_type"`)
5. Add decode branch in `init(from:)` switch
6. Add encode branch in `encode(to:)` switch
7. Add encode/decode test in `Tests/HunchKitTests/BlockTests.swift`

### Renderer Strategy

The `Renderer` protocol has a single `render(_ items: [NotionItem]) -> String` method. Four implementations: `IDRenderer`, `SmallJSONRenderer`, `FullJSONRenderer`, `MarkdownRenderer`. The CLI's `--format` option selects which renderer to use.

`MarkdownRenderer` is the most complex — it recursively renders block trees, tracks nesting depth for indentation, manages list state transitions, and maps downloaded asset URLs to local paths.

### CLI Commands

Commands use Swift ArgumentParser's `AsyncParsableCommand`. The entry point (`Sources/hunch/Hunch.swift`) registers all subcommands and provides a shared `output()` method that selects the renderer.

`ExportCommand` and `ExportPageCommand` are the most complex commands — they orchestrate fetching pages/blocks, downloading assets via `FileDownloader` (SHA256-hashed filenames for caching), fetching YouTube transcripts, generating markdown with frontmatter, and creating `.localized` folder structures.

### Pagination Lists

`PageList`, `BlockList`, and `DatabaseList` share the same structure: `results` array, `nextCursor`, and `hasMore`. `HunchAPI` loops on these until `nextCursor` is nil.

## Testing Patterns

Tests focus on model serialization roundtrips. `BlockTests` creates a `Block` with a specific `BlockTypeObject`, encodes to JSON, decodes back, and asserts key properties match. `PropertyTests` verifies property type decoding including null/missing value handling. Use `assertEncodeDecode` helper for simple Codable roundtrip checks.

## Code Style

- SwiftLint configured in `.swiftlint.yml` — line length warning at 140, error at 500
- Many strict rules disabled (see `.swiftlint.yml`): `identifier_name`, `force_cast`, `force_try`, `cyclomatic_complexity`, `type_body_length`, `file_length`, `nesting`, etc.
- `public internal(set)` is used extensively on model properties to allow mutation within the package while keeping the public API read-only
