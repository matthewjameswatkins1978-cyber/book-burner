# Book Burner 0.1 Capture Edition

**Status:** `CODE COMPLETE, PHYSICAL ACCEPTANCE PENDING`

Book Burner is a professional native iOS application engineered for high-speed physical book capture, photo inventorying, location tracking, and self-contained ZIP/CSV/JSON export. Built for collectors, book dealers, and library audits, Book Burner prioritizes lightning-fast capture loops, atomic file persistence, resilient offline caching, and robust local provenance.

---

## Architecture Overview

Book Burner follows a rigorous domain-driven modular architecture designed around SwiftUI, SwiftData, and VisionKit:

```
BookBurner/
├── App/                  # App entry point & root tab navigation
├── Domain/               # Pure domain models & identification
│   ├── Books/            # BookCopy, BookPhoto
│   ├── Identification/   # BBID allocation, ISBNDecoder (ISBN-10/13, cleaning)
│   ├── Locations/        # StorageLocation (room, shelf, bin)
│   └── Metadata/         # BookMetadata & CompositeMetadataService
├── Features/             # Feature-driven UI views & state machines
│   ├── BookDetail/       # Single book inspector & editor
│   ├── Books/            # Filterable, searchable inventory list
│   ├── Capture/          # High-speed barcode scanning & photo capture state machine
│   ├── Export/           # ZIP archive generation & system share sheet integration
│   └── Locations/        # Location picker & management
├── Infrastructure/       # Persistence, archiving, and photo storage services
│   ├── Archiving/        # RFC-4180 CSV & schema-versioned JSON export service
│   └── Photos/           # Atomic 4-stage photo storage service
└── Integrations/         # External API adapters (Google Books & Open Library)
```

### Key Architectural Pillars
- **Strict Separation of Concerns:** Domain models are decoupled from UI and persistence frameworks.
- **Human-Readable Unique IDs (`BB ID`):** Monotonic, human-readable IDs formatted as `BB-000001`, `BB-000002` that persist across app restarts and are never reallocated after deletions. ISBN is *not* used as primary entity identity, allowing duplicate scanning of identical ISBNs.
- **Atomic Photo Storage:** Full-resolution photos are stored outside SwiftData in app-managed directories using a 4-stage atomic pipeline: Temporary write $\rightarrow$ cryptographic/size verification $\rightarrow$ atomic rename/move to permanent storage $\rightarrow$ persistent record commit.
- **Non-Blocking Capture Loop:** Shutter capture and persistence complete instantly (<50ms). Asynchronous metadata enrichment runs in the background without blocking the capture loop or UI responsiveness.

---

## Swift Concurrency Model

Book Burner strictly adheres to modern Swift concurrency (`async`/`await`, `@MainActor`, and `Sendable` conformances):
- **UI Isolation:** All SwiftUI views and view models operate on the `@MainActor`.
- **Background Workers:** Network adapters, metadata fallback chains, and archive compression execute off the main thread in structured asynchronous tasks.
- **Zero Strict Concurrency Warnings:** The codebase compiles cleanly under Swift's strict concurrency checking without bypassing type safety or disabling warnings.

---

## Secrets Configuration Guide

API keys and sensitive configuration are excluded from Git repository tracking via `.gitignore` and `Secrets.xcconfig`.

1. Copy the example configuration file:
   ```bash
   cp Secrets.xcconfig.example Secrets.xcconfig
   ```
2. Open `Secrets.xcconfig` and populate your API credentials:
   ```xcconfig
   GOOGLE_BOOKS_API_KEY = your_actual_google_books_api_key_here
   ```
3. `Secrets.xcconfig` is listed in `.gitignore` and will never be committed to source control.

---

## Export Schema Specification

Inventory exports are packaged into a self-contained ZIP archive named `BookBurner-YYYY-MM-DD.zip` containing:

### 1. `books.csv`
- RFC-4180 compliant CSV file with UTF-8 encoding (including BOM support and special character escaping for commas, quotes, and international Unicode/Welsh characters).
- Columns: `bb_id`, `isbn`, `title`, `authors`, `publisher`, `published_date`, `page_count`, `location`, `status`, `photo_relative_path`, `timestamp`, `provenance`.

### 2. `books.json`
- Schema-versioned rich JSON payload containing an array of book copy objects with complete metadata provenance, capture timestamps, location attributes, and relative photo paths.

### 3. `manifest.json`
- Export metadata summary containing export timestamp, app version (`0.1`), total record count, schema version (`1.0`), and checksum verification data.

### 4. `photos/` directory
- A folder containing all full-resolution front cover photos corresponding to `photo_relative_path` references in CSV and JSON.

---

## Build, Test & Verification Commands

Book Burner includes a comprehensive suite of automated verification scripts covering core algorithms, metadata parsing, capture workflows, export packaging, and UI state invariants.

### Run End-to-End Verification Runner
```bash
python3 scripts/verify_all.py
```

### Run Individual Verification Subsystems
- **Core Domain & Algorithms:**
  ```bash
  python3 scripts/verify_core.py
  ```
- **Metadata Subsystem & Fallback:**
  ```bash
  python3 scripts/verify_metadata.py
  ```
- **Capture Workflow & State Machine:**
  ```bash
  python3 scripts/verify_capture.py
  ```
- **Export & Archiving Engine:**
  ```bash
  python3 scripts/verify_export.py
  ```
- **UI & Accessibility State:**
  ```bash
  python3 scripts/verify_ui.py
  ```

### Xcode Build & Test
```bash
xcodebuild test -project BookBurner.xcodeproj -scheme BookBurner -destination 'platform=iOS Simulator,name=iPhone 15'
```
*(Note: If using Swift Package Manager directly without an Xcode project wrapper, run `swift test`)*:
```swift
swift test
```

---

## Physical iPhone Acceptance Script (0.1 Capture Edition)

> **Status:** `CODE COMPLETE, PHYSICAL ACCEPTANCE PENDING`

Execute the following 10-step acceptance procedure on Matthew's physical iPhone running iOS 17+.

### Step 1: Permissions & Environment Setup
- Install the Book Burner app build via Xcode on the physical iPhone.
- Grant Camera and Photo Library permissions when prompted.
- Verify that flashlight/torch toggle operates correctly in low-light scanning conditions.

### Step 2: Offline Barcode Scan & Instant Persistence
- Disconnect Wi-Fi and Cellular data (Airplane Mode).
- Scan a physical book barcode with the VisionKit camera scanner.
- Verify near-instantaneous capture feedback (haptic + audio), BB ID allocation (`BB-000001`), and automatic return to scan-ready state without modal confirmation dialogues.

### Step 3: Duplicate ISBN Handling
- Scan two identical copies of the same book consecutively.
- Verify that two distinct `BookCopy` records are created with unique monotonic IDs (`BB-000002`, `BB-000003`) without global ISBN deduplication blocking the second scan.

### Step 4: Unreadable Barcode / "No ISBN" Escape Path
- Encounter a vintage or damaged book without a scannable barcode.
- Tap the quick "No ISBN / Can't Scan" button.
- Verify allocation of a new BB ID, capture of front photo, location inheritance, and marking as `Needs Review`.

### Step 5: Metadata Enrichment & Provider Fallback
- Reconnect network (disable Airplane Mode).
- Trigger metadata lookup. Verify that Google Books lookup succeeds, falling back to Open Library if necessary, without blocking UI interaction. Verify metadata is correctly populated (Title, Author, Publisher, Year).

### Step 6: Storage Location Assignment
- Navigate to Location Picker.
- Assign a batch of scanned books to a specific physical location (`Living Room Shelf A`).
- Verify subsequent scans inherit the active location automatically.

### Step 7: Undo Last Capture Mechanics
- Scan a test book incorrectly.
- Tap the immediate single-step Undo button.
- Verify that the most recent record and associated photo assets are deleted, and the monotonic BB ID sequence preserves its counter without reuse.

### Step 8: Search, Filter & Detail Inspector
- Open the Inventory List view.
- Perform a search across BB ID, title, author, and location.
- Apply status filters (`Unresolved`, `Lookup Pending`, `Needs Review`, `Location`).
- Tap a book row to open the vertically scrolling detail inspector; review photo preview, provenance, location editor, and mark-as-incorrect actions.

### Step 9: Comprehensive Export & Share Sheet
- Tap Export in the main tab view.
- Generate the ZIP archive (`BookBurner-YYYY-MM-DD.zip`).
- Invoke the system share sheet, save to Files, and verify ZIP contents (`books.csv`, `books.json`, `manifest.json`, `photos/`).

### Step 10: High-Volume Physical Pile Tests
- **25-Book Test:** Rapidly scan a clean stack of 25 books consecutively. Verify zero dropped scans, zero freezes, and smooth capture loop performance.
- **Messy ~50-Book Pile Test:** Scan a cluttered pile of 50 books mixing barcodes, missing barcodes, varying lighting conditions, and duplicate ISBNs. Verify stable memory consumption, zero crashes, and correct record counts.
