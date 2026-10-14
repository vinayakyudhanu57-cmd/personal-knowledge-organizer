# Personal Knowledge Organizer — Test Suite & Verification Matrix

This document records the comprehensive manual and automated test cases covering data persistence, search and filtering, validation rules, related-note discovery, and API endpoints.

All automated test invariants are executed in base R via:
```powershell
Rscript R/main.R --test
```

---

## 1. Test Execution Summary

| Test Category | Invariant Count | Execution Status | Method |
| :--- | :---: | :---: | :--- |
| **Data Persistence & File I/O** | 4 | **Passed** | Automated in `R/main.R` & Manual CSV inspection |
| **Tag Processing & Normalization** | 3 | **Passed** | Automated in `R/main.R` |
| **Validation Rules** | 4 | **Passed** | Automated in `R/main.R` & Web Form UI |
| **Search & Case-Insensitive Filter** | 6 | **Passed** | Automated in `R/main.R` & Frontend Search Bar |
| **Related Notes Discovery Algorithm** | 5 | **Passed** | Automated in `R/main.R` & UI Drawer Inspection |
| **CRUD Operations & Restart Persistence** | 6 | **Passed** | Automated on temporary CSV & Live API |
| **Dashboard Statistics Aggregation** | 3 | **Passed** | Automated in `R/main.R` & Web Overview |
| **Total Test Invariants** | **31** | **All Passed (31/31)** | Verified against R 4.6.1 runtime |

---

## 2. Detailed Test Cases

### TC-01: CSV Data Loading and Schema Integrity
- **Description**: Verify that `load_knowledge_items()` loads existing data from `data/knowledge_items.csv` without loss and guarantees all required columns exist.
- **Input**: `data/knowledge_items.csv` containing 8 initial items.
- **Expected Outcome**: Loaded data frame contains 8 rows and all 10 columns (`id`, `title`, `content`, `item_type`, `topic`, `tags`, `importance`, `source_url`, `created_at`, `updated_at`).
- **Result**: **PASS** (Automated assertion: 8 items loaded, all column names match).

### TC-02: Tag Normalization and Duplicate Stripping
- **Description**: Verify `parse_tags()` splits on commas/semicolons, converts to lowercase, trims whitespace, and removes duplicate tags.
- **Input**: `"R, Data-Science, Web Development; API-design, r"`.
- **Expected Outcome**: Unique vector `["r", "data-science", "web-development", "api-design"]` with clean formatting `"r, data-science, web-development, api-design"`.
- **Result**: **PASS** (Automated assertion).

### TC-03: Input Validation and Boundary Enforcement
- **Description**: Verify validation rejects missing titles, invalid item types, and malformed URLs, while accepting valid records.
- **Test Scenarios**:
  1. Empty title `""` &rarr; Rejected with `"Title is required and cannot be blank."`
  2. Invalid item type `"RandomType"` &rarr; Rejected with allowed types enum error.
  3. Malformed URL `"ftp://broken"` or `"not-a-url"` &rarr; Rejected with URL format error.
  4. Complete valid record &rarr; Returns `valid = TRUE`.
- **Result**: **PASS** (Automated assertions).

### TC-04: Keyword Search across Titles and Note Content
- **Description**: Verify keyword search is case-insensitive and checks both titles and multiline contents in R.
- **Test Scenarios**:
  1. Title match: Query `"vectorized"` matches `"Vectorized Operations and Memory Efficiency in Base R"`.
  2. Content match: Query `"preallocate"` matches item containing preallocation advice in content.
  3. Case insensitivity: Query `"VECTOR"` matches the same item as `"vector"`.
- **Result**: **PASS** (Automated assertions).

### TC-05: Multi-Criteria Combined Filtering
- **Description**: Verify that filtering works when multiple criteria (Topic, Item Type, Importance, Tag) are combined simultaneously.
- **Input**: `topic = "Programming"` AND `importance = "High"`.
- **Expected Outcome**: Only returns items where both criteria hold (e.g. `item_001` and `item_008`).
- **Result**: **PASS** (Automated assertions).

### TC-06: Empty Search Results Handling
- **Description**: Verify that searching for a non-existent keyword returns an empty data frame gracefully without R errors or frontend crashes.
- **Input**: Query `"nonexistent_term_xyz_12345"`.
- **Expected Outcome**: 0 rows returned, frontend renders clean empty state with a single-click "Clear All Filters" button.
- **Result**: **PASS** (Automated and UI tested).

### TC-07: Related Notes Discovery & Deterministic Ranking
- **Description**: Verify that `calculate_related_notes()` correctly identifies notes sharing tags with a target note and scores them deterministically.
- **Target Item**: `item_003` ("Designing Microservices and HTTP REST Endpoints with Plumber", tags: `r, web-development, api-design, architecture`).
- **Discovered Results**:
  1. `item_005` ("Designing Resilient RESTful APIs"): 3 shared tags (`web-development`, `api-design`, `architecture`), Score: 62%.
  2. `item_008` ("Defensive Unit Testing in R"): 2 shared tags (`r`, `architecture`), Score: 28%.
  3. `item_002` ("Functional Data Transformation"): 1 shared tag (`r`), Score: 11%.
  4. `item_001` ("Vectorized Operations"): 1 shared tag (`r`), Score: 11%.
- **Expected Outcome**: Notes ordered descending by score, transparent reasons included, and target item strictly excluded from its own results.
- **Result**: **PASS** (Automated assertion and demo output verified).

### TC-08: Notes Without Tags
- **Description**: Verify behavior when an item has no tags assigned.
- **Input**: Note with `tags = ""`.
- **Expected Outcome**: Returns count = 0 with friendly explanation: `"This note has no tags assigned. Add tags to enable related note discovery."`
- **Result**: **PASS** (Automated assertion).

### TC-09: CRUD Invariants & Special Character / Multiline Quoting
- **Description**: Verify adding, updating, and deleting an item preserves quotes (`"quoted"`), commas, newlines (`\n`), and Unicode symbols (`©, —, →`).
- **Input Record**:
  ```text
  Title: Unit Test "Item" with Special Characters & Commas
  Content: Line 1: Testing multiline persistence.
  Line 2: Comma test, quotes test "quoted", and special chars: ©, —, →.
  Tags: testing, r, architecture
  ```
- **Verification**:
  1. Added to temporary CSV and reloaded &rarr; Exactly preserved with RFC 4180 CSV escaping.
  2. Updated title and importance &rarr; Timestamp `updated_at` updated to today's date.
  3. Deleted by ID &rarr; Removed completely from CSV.
- **Result**: **PASS** (Automated assertions).

### TC-10: Persistence Across Application Restarts
- **Description**: Verify that changes made through the web interface remain after stopping and restarting the R Plumber server.
- **Steps**:
  1. Save a new note via `POST /api/items`.
  2. Inspect `data/knowledge_items.csv` on disk to confirm immediate flush.
  3. Terminate R process and restart.
  4. Reload application at `http://127.0.0.1:8000`.
- **Expected Outcome**: Newly created note is retrieved from disk with intact metadata.
- **Result**: **PASS** (Verified via file I/O).
