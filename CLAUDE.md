# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Hunch is a Swift command-line tool and library for interacting with the Notion.so API. It provides both a library (`HunchKit`) for programmatic access and a CLI tool (`hunch`) for command-line operations.

## Build and Development Commands

### Building
```bash
swift build                    # Debug build
swift build -c release         # Release build
swift build --platform macos   # Platform-specific build
```

### Testing
```bash
swift test                     # Run all tests
swift test --verbose           # Run with verbose output
swift test --filter BlockTests # Run specific test class
```

### Running
```bash
# Set your Notion API key first
export NOTION_KEY="your_notion_api_key"

# Run the CLI tool
swift run hunch [command] [options]

# Available commands:
# - database: Query and list Notion databases
# - page: Work with individual Notion pages
# - blocks: Work with Notion blocks
# - export: Export database pages to markdown files
# - activity: Track Notion activity
```

### Linting
```bash
./format-files.sh              # Run SwiftLint with auto-fix
swiftlint                      # Check for lint issues only
```

## Architecture Overview

### Package Structure
- **Sources/HunchKit/**: Core library with API client and models
  - `APIs/`: API client implementations (HunchAPI, NotionAPI)
  - `NotionItems/`: Model types for Notion objects (Block, Page, Database, etc.)
  - `Helpers/`: Utilities including file downloaders and renderers
  - `Lists/`: Collection types for paginated results
  
- **Sources/hunch/**: CLI executable
  - `Commands/`: Individual command implementations using ArgumentParser
  - `Hunch.swift`: Main entry point with command registration

### Key Design Patterns
1. **Async/Await**: All API calls use Swift's modern concurrency
2. **Command Pattern**: CLI commands implemented as ArgumentParser ParsableCommands
3. **Repository Pattern**: NotionAPI serves as centralized API access point
4. **Renderer Pattern**: Multiple renderer implementations for different output formats

### API Integration
- Uses Notion API version 2021-05-13
- Token-based authentication via NOTION_KEY environment variable
- Built-in rate limiting and retry logic with exponential backoff
- Comprehensive error handling with descriptive error types

### Output Formats
The tool supports multiple output formats via the `--format` option:
- `id`: Simple ID listing
- `smalljsonl`: Minimal JSON Lines format
- `jsonl`: Full JSON Lines format (default)
- `markdown`: Rich markdown with asset downloading

### Export Feature
The export command (`hunch export`) is the most complex feature:
- Downloads all assets (images, videos, files) to local directories
- Fetches YouTube transcripts when YouTube URLs are found
- Creates `.localized` folders with Base.strings files
- Preserves page metadata in markdown frontmatter
- Creates `.webloc` files for easy access to original Notion pages
- Handles nested block structures recursively

## Testing Approach

Tests are organized by feature in the Tests/HunchKitTests directory. Key testing patterns:
- Comprehensive encoding/decoding tests for all block types
- Helper methods for common assertions (e.g., `assertRoundtrip`)
- Focus on model serialization and API response handling

## Development Tips

1. **Environment Setup**: Always set `NOTION_KEY` before running the tool
2. **API Rate Limits**: The tool handles rate limiting automatically, but be mindful of Notion's API limits
3. **Asset Downloads**: When working on export features, assets are downloaded to `assets/` subdirectories
4. **Error Handling**: Check error types in NotionAPI for comprehensive error cases
5. **Adding New Block Types**: Follow the pattern in `NotionItems/Block.swift` and add corresponding tests

## Code Style

- SwiftLint is configured with custom rules (see .swiftlint.yml)
- Line length warning at 140 characters
- Use descriptive variable names (identifier_name rule is disabled for flexibility)
- Follow existing patterns for consistency