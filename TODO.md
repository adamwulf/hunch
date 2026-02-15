# Test Coverage TODO

Tracks which types have been validated against real Notion API responses vs only tested with hand-crafted JSON.

## Block Types

| Block Type | Static Test | Real API | Notes |
|---|---|---|---|
| paragraph | Y | Y | Multiple pages, with/without rich text |
| heading_1 | Y | Y | With color annotations |
| heading_2 | Y | Y | With underline, italic, link annotations |
| heading_3 | Y | Y | |
| bulleted_list_item | Y | Y | Nested children too |
| numbered_list_item | Y | Y | Nested with children |
| to_do | Y | Y | Both checked=true and checked=false |
| toggle | Y | Y | With and without children |
| child_page | Y | Y | |
| child_database | Y | Y | |
| callout | Y | Y | With emoji icon, with/without children, empty rich_text |
| quote | Y | Y | With nested children |
| table | Y | Y | has_column_header and has_row_header variants |
| table_row | Y | Y | Multi-cell rows |
| divider | Y | Y | Empty object `{}` |
| link_to_page | Y | Y | page_id variant |
| image (hosted) | Y | Y | Notion-hosted file with caption |
| image (external) | Y | - | Only hand-crafted JSON |
| video (external) | Y | Y | YouTube external URL |
| video (hosted) | Y | - | Only hand-crafted JSON |
| file (hosted) | Y | Y | Notion-hosted file (PDF, crash file) |
| file (external) | Y | - | Only hand-crafted JSON |
| pdf (hosted) | Y | Y | With caption |
| pdf (external) | Y | - | Only hand-crafted JSON |
| bookmark | Y | Y | With and without caption |
| breadcrumb | Y | Y | Empty object `{}` |
| embed | Y | Y | URL embed (bsky.app) |
| link_preview | Y | Y | Figma link preview |
| code | Y | Y | With language, caption, multiline content |
| column_list | Y | Y | With 2 column children |
| column | Y | Y | With paragraph children |
| audio (external) | Y | - | Only hand-crafted JSON |
| audio (hosted) | Y | - | Only hand-crafted JSON |
| equation | Y | - | Only hand-crafted JSON |
| synced_block | Y | - | Only hand-crafted JSON (original + reference) |
| template | Y | - | Only hand-crafted JSON |
| table_of_contents | Y | - | Only hand-crafted JSON |
| unsupported | Y | - | Synthetic type, Notion doesn't return this |

## Property Types

| Property Type | Static Test | Real API | Notes |
|---|---|---|---|
| title | Y | Y | "Name" in Example db |
| multi_select | Y | Y | "Tags" in Example db (with values + empty) |
| url | Y | Y | "URL" in Example db (with value + null) |
| formula | Y | Y | "Count" in Example db (number type) |
| number | Y | - | Only hand-crafted JSON |
| select | Y | - | Only hand-crafted JSON |
| date | Y | - | Only hand-crafted JSON |
| people | Y | - | Only hand-crafted JSON |
| file / files | Y | - | Only hand-crafted JSON |
| checkbox | Y | - | Only hand-crafted JSON |
| email | Y | - | Only hand-crafted JSON |
| phone_number | Y | - | Only hand-crafted JSON |
| rich_text | Y | - | Only hand-crafted JSON |
| relation | Y | - | Only hand-crafted JSON |
| rollup | Y | - | Only hand-crafted JSON |
| created_time | Y | - | Only hand-crafted JSON |
| created_by | Y | - | Only hand-crafted JSON |
| last_edited_time | Y | - | Only hand-crafted JSON |
| last_edited_by | Y | - | Only hand-crafted JSON |
| status | Y | - | Only hand-crafted JSON |
| unique_id | Y | - | Only hand-crafted JSON |
| null | Y | Y | Database schema properties decode as null |

## API Endpoints

| Endpoint | Integration Test | Notes |
|---|---|---|
| POST /v1/search | Y | testSearch, testExportExampleDatabaseToTmp |
| POST /v1/databases (list) | Y | testFetchDatabases |
| GET /v1/databases/{id} | Y | testRetrieveDatabaseSchema |
| POST /v1/databases/{id}/query | Y | testAllDatabasePagesDecoding, filter + sort tests |
| GET /v1/pages/{id} | Y | testRetrieveMultiplePages |
| POST /v1/pages | Y | testCreateUpdateArchivePage, testCreatePageWithChildren |
| PATCH /v1/pages/{id} | Y | testCreateUpdateArchivePage (update + archive) |
| GET /v1/blocks/{id}/children | Y | testBlockDecodingAcrossPages, testBlockEncodingRoundtrip |
| PATCH /v1/blocks/{id}/children | Y | testAppendBlockChildren |
| PATCH /v1/blocks/{id} | Y | testUpdateBlock |
| DELETE /v1/blocks/{id} | Y | testDeleteBlock |
| GET /v1/comments | Skipped | 403 - integration token lacks comment read permission |
| POST /v1/comments | Skipped | 403 - integration token lacks comment insert permission |

## Supporting Types

| Type | Static Test | Real API | Notes |
|---|---|---|---|
| Page | Y | Y | All parent types, icon, archived states |
| Database | Y | Y | Schema properties, workspace parent |
| Comment | Y | Skipped | 403 permissions |
| Parent (database) | Y | Y | Pages in Example db |
| Parent (page) | Y | Y | Child pages, block parent |
| Parent (block) | Y | Y | Nested blocks |
| Parent (workspace) | Y | Y | Database parent |
| RichText (plain) | Y | Y | Multiple pages |
| RichText (with link) | Y | Y | duckduckgo.com link in content |
| RichText (with annotations) | Y | Y | bold, italic, underline, code, color, strikethrough |
| RichText (mention) | Y | - | Only hand-crafted JSON (user, page, database, date) |
| User (person) | Y | - | Only hand-crafted JSON |
| User (bot) | Y | - | Only hand-crafted JSON |
| PartialUser | Y | Y | created_by/last_edited_by in blocks |
| Icon (emoji) | Y | Y | Callout blocks with emoji |
| Icon (external) | Y | - | Only hand-crafted JSON |
| Icon (file) | Y | - | Only hand-crafted JSON |
| Color (all 19) | Y | Y | green_background, orange seen in real data |
| Annotation | Y | Y | All annotation fields seen in real data |
| SelectOption | Y | Y | "example" tag in multi_select |
| NotionDate | Y | - | Only hand-crafted JSON |
| Reference | Y | - | Only hand-crafted JSON |
| Link | Y | Y | Links in paragraph rich_text |

## How to Validate Missing Types

To validate the remaining hand-crafted types against real API responses:

1. **Property types**: Add columns to the Example database (or create a new "Property Test" database) with: number, select, date, people, checkbox, email, phone_number, rich_text, relation, rollup, status. Then populate a page with values for each.

2. **Block types**: Add content to an Example db page: an equation block, a synced block, an audio embed, a table of contents. Template blocks are deprecated by Notion.

3. **Comments**: Enable "Read comments" and "Insert comments" capabilities on the Notion integration, then the existing `testCommentCreateAndFetch` will run.

4. **External file variants**: Add an external image (URL), external video, or external PDF to a page.

5. **RichText mentions**: Add an @mention of a user, page, database, or date in a block's text.
