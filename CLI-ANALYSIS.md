# Hunch CLI Consistency & Usability Report

## 1. Where the CLI Is Consistent

**Format option.** 10 of 13 commands share `--format / -f` with type `Hunch.Format` defaulting to `.id`. The four format values (`id`, `smalljsonl`, `jsonl`, `markdown`) are consistent. Commands that use it: `database`, `page`, `blocks`, `search`, `update-page`, `create-page`, `comments`, `append-blocks`, `delete-block`, `users`.

**Limit option.** Commands that list items (`database`, `page`, `search`, `users`) all use `--limit / -l` as `Int?` with the same nil-defaults-to-`.max` pattern.

**Output path.** Both `export` and `export-page` (and `activity`) use `--output-dir / -o` defaulting to `"./notion_export"` (or `"./activity_export"`).

**Renderer pipeline.** All standard commands use the same `Hunch.output(list:format:)` method, giving uniform rendering behavior.

**Error handling (catch blocks).** Most commands use `fatalError("error: \(error.localizedDescription)")` in their catch blocks.

---

## 2. Where the CLI Is Inconsistent

### 2a. ID argument: `@Argument` vs `--id` option

| Command | How the primary ID is passed | Style |
|---------|------------------------------|-------|
| `database` | `@Argument entityId: String?` (positional, optional) | positional |
| `page` | `@Option --id / -i` (named option) | option |
| `blocks` | `@Argument pageId: String` (positional, required) | positional |
| `search` | `@Argument query: String?` (positional, optional) | positional |
| `export` | `@Argument databaseId: String` (positional, required) | positional |
| `export-page` | `@Argument id: String` (positional, required) | positional |
| `update-page` | `@Argument pageId: String` (positional, required) | positional |
| `create-page` | `@Option --database / -d` (named option, required) | option |
| `comments` | `@Argument blockId: String` (positional, required) | positional |
| `append-blocks` | `@Argument blockId: String` (positional, required) | positional |
| `delete-block` | `@Argument blockId: String` (positional, required) | positional |
| `users` | `@Option --id / -i` (named option) | option |

**Problem:** `page` and `users` use `--id` as an option to dual-purpose the command (list vs retrieve). Every other command uses a positional argument. This means `hunch page --id <X>` but `hunch blocks <X>` - an inconsistent pattern for the same conceptual operation (fetch-by-id).

### 2b. Dual-mode commands (list vs retrieve) differ in structure

- **`database`**: positional arg + `--schema` flag. Without `--schema`, the arg is a parent filter. With `--schema`, the arg is a database ID to retrieve. The same argument means different things depending on a flag.
- **`page`**: `--id` retrieves one page, `--database` lists from a database. No ID means "list all pages."
- **`users`**: `--id` retrieves one user, otherwise lists all.
- **`blocks`**: Always requires a positional ID, always fetches children. No dual mode.
- **`comments`**: Positional ID for the block, `--add` switches from list to create.

There's no consistent pattern for "retrieve one vs list many."

### 2c. Error handling is mixed and inconsistent

| Pattern | Commands |
|---------|----------|
| `fatalError("error: ...")` | `database`, `page`, `blocks`, `search`, `users`, `update-page`, `create-page`, `comments`, `append-blocks`, `delete-block` |
| `print("error: ..."); return` | `database` (schema validation), `update-page` (missing args), `append-blocks` (stdin failure) |
| `throws` (proper ArgumentParser) | `export`, `export-page`, `activity` |
| `print("error: ...")` in renderer | `Hunch.output()` |

**Problems:**
- `fatalError` crashes the process instead of producing a clean non-zero exit code. An AI agent or script parsing output gets a crash trace instead of a structured error.
- Validation errors sometimes `print` + `return` (exit code 0), sometimes `fatalError` (crash), and sometimes `throw` (clean exit). No consistency.
- `export` and `export-page` correctly mark `run()` as `throws`, which lets ArgumentParser handle errors gracefully. Most other commands swallow errors in a do/catch and `fatalError`.

### 2d. Exit codes

Because most commands use `fatalError`, the exit code is always a crash signal rather than a conventional non-zero exit code. Commands that `print("error:..."); return` exit with code 0 despite failing. There is no reliable way to detect success vs failure from the exit code.

### 2e. Export commands have massive code duplication

`ExportCommand` and `ExportPageCommand` share ~200 lines of nearly identical code (asset downloading, caching, markdown generation, property extraction, webloc writing, transcript handling). Each has private copies of `writeWebloc`, `findYouTubeUrl`, `addTimestamp`, `fetchAndCacheTranscript`, and the entire `selectProperties` mapping block.

### 2f. Format names are not intuitive

- `smalljsonl` - unclear what "small" means (it's a subset: object, id, description, parent)
- `jsonl` - actually full JSON, but the name doesn't distinguish it from smalljsonl
- `id` - outputs bare IDs, one per line
- `markdown` - only meaningful for blocks; for pages/databases/users it renders via the same protocol but the output is often just a title line

### 2g. The `--format` option is available but meaningless on some commands

- `delete-block` with `--format markdown` - rendering a deleted block as markdown is not useful
- `export` and `export-page` don't support `--format` at all (hardcoded to markdown) but `activity` doesn't either - yet none explains this in help text
- `comments` with `--format markdown` - comments aren't blocks with rich content; markdown rendering is questionable

### 2h. Command naming inconsistencies

- `page` (singular, noun) vs `blocks` (plural, noun) vs `comments` (plural, noun) vs `users` (plural, noun)
- `update-page` (verb-noun) vs `create-page` (verb-noun) vs `append-blocks` (verb-noun) vs `delete-block` (verb-noun, singular!)
- `export` and `export-page` are two separate commands rather than subcommands or flags

### 2i. Sort options differ between commands

- `page`: `--sort-by`, `--sort-direction`, `--sort-timestamp` (three separate options)
- `search`: `--sort-direction` only (no sort-by, always sorts by last_edited_time)
- Other commands: no sort support at all

### 2j. `activity` command is an outlier

The `activity` command parses a local Google Takeout HTML file and downloads YouTube transcripts. It has no `--format` option, no `--limit`, and is fundamentally a different kind of tool (local file processing + YouTube scraping) compared to the Notion API commands. It hardcodes rate-limiting sleeps and progress output to stdout, mixing data and progress on the same stream.

---

## 3. Recommendations for AI Agent Usability

### 3.1 Structured error output to stderr with proper exit codes

**Priority: High.** Replace all `fatalError` calls with `throw` so ArgumentParser handles exit codes cleanly. Output errors to stderr (not stdout). Consider a `--output-format=json` mode where errors are also JSON:
```json
{"error": "Page not found", "code": "object_not_found", "status": 404}
```
An AI agent parsing stdout currently cannot distinguish "no results" from "API error."

### 3.2 Add a `json` output format (array, not JSONL)

**Priority: High.** The current `jsonl` format outputs one JSON object per line. For AI agent consumption, a proper JSON array (`[{...}, {...}]`) is far easier to parse. JSONL requires line-by-line parsing and doesn't compose well with tools like `jq`. Recommend adding `--format json` that wraps results in an array.

### 3.3 Standardize ID argument as positional

**Priority: Medium.** Unify around the positional argument pattern. `hunch page <id>` and `hunch users <id>` instead of `--id`. For list mode, omit the argument. This matches the majority pattern and removes ambiguity.

### 3.4 Separate list and retrieve into subcommands or consistent convention

**Priority: Medium.** Either adopt subcommands (`hunch page list`, `hunch page get <id>`) or consistently use "positional arg present = retrieve, absent = list." The current mix of `--schema`, `--id`, and positional args makes it hard for an AI agent to construct commands programmatically.

### 3.5 Add a `--quiet` / `--verbose` flag and separate progress from data

**Priority: Medium.** The `export` and `activity` commands print progress info to stdout, mixed with output data. AI agents need clean data on stdout and progress/diagnostics on stderr.

### 3.6 Normalize command names

**Priority: Low.** Pick a convention and apply it:
- Nouns for resources: `databases`, `pages`, `blocks`, `comments`, `users`
- Or verb-noun for mutations: keep `create-page`, `update-page`, `delete-block`, `append-blocks` but pluralize `delete-block` to `delete-blocks` (or keep all singular)
- Consider: `blocks delete <id>` as a subcommand instead of a top-level command

### 3.7 Add `--count` or result metadata

**Priority: Low.** For list commands, AI agents benefit from knowing total result counts. A `--count` flag that outputs just the count, or including a count in JSON output metadata, would help agents decide whether to paginate or refine queries.

### 3.8 Deduplicate export commands

**Priority: Low (maintenance).** Extract the shared logic from `ExportCommand` and `ExportPageCommand` into a shared helper. This doesn't affect usability directly but prevents the two commands from diverging in behavior over time.

### 3.9 Improve format names

**Priority: Low.** Consider renaming:
- `smalljsonl` -> `summary` (or `brief`)
- `jsonl` -> `full` (or keep `jsonl` but add `json` for array output)
- `id` -> keep as-is
- `markdown` -> keep as-is

---

## Summary Table

| Area | Current State | Impact on AI Agents |
|------|--------------|-------------------|
| Error handling | `fatalError` crashes, exit code 0 on some failures | Cannot reliably detect errors |
| Error output | Mixed stdout/stderr, no structure | Cannot parse errors programmatically |
| ID passing | Mix of `--id` option and positional arg | Must know per-command syntax |
| List vs retrieve | 3 different patterns across commands | Cannot construct commands generically |
| Output format | JSONL only (no proper JSON array) | Requires custom parsing |
| Progress output | Mixed into stdout | Pollutes data stream |
| Command naming | Inconsistent singular/plural | Minor confusion |

The highest-impact changes for AI agent consumption are (1) proper exit codes via `throw` instead of `fatalError`, (2) structured error output to stderr, and (3) a proper JSON array output format.
