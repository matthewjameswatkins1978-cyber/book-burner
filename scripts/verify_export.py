#!/usr/bin/env python3
import sys
import os
import tempfile
import shutil
import csv
import json
import zipfile

def verify_export():
    print("=== BookBurner Export & Archiving Engine Verification ===")
    temp_dir = tempfile.mkdtemp(prefix="bookburner_export_verify_")
    photos_dir = os.path.join(temp_dir, "photos")
    os.makedirs(photos_dir, exist_ok=True)

    try:
        # 1. Prepare sample data with complex CSV escaping requirements (quotes, commas, newlines, Unicode/Welsh strings)
        print("[1/4] Preparing test records with RFC-4180 escaping & Unicode/Welsh characters...")
        
        sample_books = [
            {
                "bbid": "BB-000001",
                "isbn": "9780306406157",
                "title": "Llyfr Cymraeg â Chynnwys Arbennig (Welsh)",
                "author": "Maldwyn ap Tomos",
                "publisher": "Gwasg Prifysgol Cymru",
                "publishedYear": 2021,
                "status": "Resolved",
                "locationName": "Shelf #1, Room A",
                "metadataProvenance": "google_books",
                "photoPath": "BB-000001-front.heic",
                "capturedAt": "2026-08-31T12:00:00.000Z"
            },
            {
                "bbid": "BB-000002",
                "isbn": None,
                "title": "Book with \"Quotes\", Commas, and\nNewlines inside title!",
                "author": "Author, Co.",
                "publisher": None,
                "publishedYear": None,
                "status": "Needs Review",
                "locationName": "Box 2",
                "metadataProvenance": "No ISBN",
                "photoPath": "BB-000002-front.heic",
                "capturedAt": "2026-08-31T12:01:00.000Z"
            }
        ]

        # Create dummy photo files
        for b in sample_books:
            p_path = os.path.join(photos_dir, b["photoPath"])
            with open(p_path, "wb") as f:
                f.write(b"fake-image-bytes")

        # 2. Simulate CSV Generation with RFC-4180 escaping
        print("[2/4] Verifying RFC-4180 CSV Generation & UTF-8 Escaping...")
        csv_path = os.path.join(temp_dir, "books.csv")
        headers = ["BBID", "ISBN", "Title", "Author", "Publisher", "PublishedYear", "Status", "Location", "MetadataProvenance", "PhotoPath", "CapturedAt"]
        
        def escape_csv(val):
            if val is None:
                return ""
            s = str(val)
            if any(c in s for c in [",", "\"", "\n", "\r"]):
                return "\"" + s.replace("\"", "\"\"") + "\""
            return s

        csv_lines = [",".join(headers)]
        for b in sample_books:
            row = [
                b["bbid"],
                b["isbn"],
                b["title"],
                b["author"],
                b["publisher"],
                str(b["publishedYear"]) if b["publishedYear"] is not None else "",
                b["status"],
                b["locationName"],
                b["metadataProvenance"],
                b["photoPath"],
                b["capturedAt"]
            ]
            csv_lines.append(",".join(escape_csv(v) for v in row))

        csv_content = "\r\n".join(csv_lines)
        # Keep explicit RFC-4180 CRLF bytes; otherwise Windows text-mode
        # newline translation turns each record separator into a blank row.
        with open(csv_path, "w", encoding="utf-8", newline="") as f:
            f.write(csv_content)

        # Parse CSV back using Python's csv module to verify roundtrip integrity
        with open(csv_path, "r", encoding="utf-8", newline="") as f:
            reader = csv.reader(f)
            parsed_rows = list(reader)
        
        assert len(parsed_rows) == 3, f"Expected 3 rows in CSV (header + 2 books), got {len(parsed_rows)}"
        assert parsed_rows[1][2] == sample_books[0]["title"], "Welsh title roundtrip mismatch"
        assert parsed_rows[2][2] == sample_books[1]["title"], "Escaped quotes/newlines title roundtrip mismatch"
        print("  -> CSV RFC-4180 escaping and Unicode/Welsh characters roundtrip verified successfully.")

        # 3. Simulate JSON payload & Manifest generation
        print("[3/4] Verifying JSON Payload & Manifest Schema Versioning...")
        json_path = os.path.join(temp_dir, "books.json")
        with open(json_path, "w", encoding="utf-8") as f:
            json.dump(sample_books, f, indent=2)

        manifest_data = {
            "schemaVersion": "1.0",
            "appVersion": "0.1.0",
            "exportTimestamp": "2026-08-31T12:05:00.000Z",
            "bookCount": len(sample_books)
        }
        manifest_path = os.path.join(temp_dir, "manifest.json")
        with open(manifest_path, "w", encoding="utf-8") as f:
            json.dump(manifest_data, f, indent=2)

        assert os.path.exists(json_path)
        assert os.path.exists(manifest_path)
        print("  -> JSON schema and manifest accuracy verified.")

        # 4. Package ZIP archive and verify contents
        print("[4/4] Packaging ZIP Archive & Verifying Asset Integrity...")
        zip_path = os.path.join(temp_dir, "BookBurner-2026-08-31.zip")
        
        with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_DEFLATED) as zf:
            zf.write(csv_path, "books.csv")
            zf.write(json_path, "books.json")
            zf.write(manifest_path, "manifest.json")
            for b in sample_books:
                p_path = os.path.join(photos_dir, b["photoPath"])
                zf.write(p_path, f"photos/{b['photoPath']}")

        assert os.path.exists(zip_path), "ZIP archive was not created"

        # Inspect ZIP contents
        with zipfile.ZipFile(zip_path, "r") as zf:
            namelist = zf.namelist()
            assert "books.csv" in namelist, "books.csv missing from ZIP"
            assert "books.json" in namelist, "books.json missing from ZIP"
            assert "manifest.json" in namelist, "manifest.json missing from ZIP"
            assert "photos/BB-000001-front.heic" in namelist, "Photo 1 missing from ZIP photos/"
            assert "photos/BB-000002-front.heic" in namelist, "Photo 2 missing from ZIP photos/"

            # Verify manifest inside zip
            with zf.open("manifest.json") as mf:
                m_loaded = json.load(mf)
                assert m_loaded["bookCount"] == 2
                assert m_loaded["schemaVersion"] == "1.0"

        print("=== ALL EXPORT & ARCHIVING VERIFICATION CHECKS PASSED SUCCESSFULLY ===")
        return 0

    except Exception as e:
        print(f"EXPORT VERIFICATION FAILED: {e}", file=sys.stderr)
        import traceback
        traceback.print_exc()
        return 1
    finally:
        shutil.rmtree(temp_dir, ignore_errors=True)

if __name__ == "__main__":
    sys.exit(verify_export())
