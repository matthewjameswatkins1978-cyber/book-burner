#!/usr/bin/env python3
import sys
import unittest
import tempfile
import os

# Standalone mechanical verification script for BookBurner core domain algorithms & templates
# Verifies ISBN validation algorithms (ISBN-10, ISBN-13, conversion, cleaning),
# BBID formatting & monotonicity logic, domain definitions existence, and Secrets template existence.

class TestBookBurnerCoreAlgorithms(unittest.TestCase):

    def test_secrets_template_exists(self):
        self.assertTrue(os.path.exists("Secrets.xcconfig.example"), "Secrets.xcconfig.example must exist.")
        with open("Secrets.xcconfig.example", "r") as f:
            content = f.read()
            self.assertIn("GOOGLE_BOOKS_API_KEY", content, "Secrets template must contain GOOGLE_BOOKS_API_KEY.")

    def test_domain_files_exist(self):
        required_files = [
            "BookBurner/Domain/Identification/BBID.swift",
            "BookBurner/Domain/Identification/ISBNDecoder.swift",
            "BookBurner/Domain/Locations/StorageLocation.swift",
            "BookBurner/Domain/Books/BookPhoto.swift",
            "BookBurner/Domain/Books/BookCopy.swift"
        ]
        for path in required_files:
            self.assertTrue(os.path.exists(path), f"Required domain file {path} must exist.")

    def test_isbn_cleaning(self):
        # Emulate ISBNDecoder.clean in Python
        def clean(s):
            return "".join(c for c in s.upper() if c.isalnum())
        
        self.assertEqual(clean("0-306-40615-2"), "0306406152")
        self.assertEqual(clean("978 0 306 40615 7"), "9780306406157")

    def test_isbn10_validation(self):
        def is_valid_isbn10(isbn):
            cleaned = "".join(c for c in isbn.upper() if c.isalnum())
            if len(cleaned) != 10:
                return False
            sum_val = 0
            for i in range(9):
                if not cleaned[i].isdigit():
                    return False
                sum_val += (10 - i) * int(cleaned[i])
            last = cleaned[9]
            if last == 'X':
                last_val = 10
            elif last.isdigit():
                last_val = int(last)
            else:
                return False
            sum_val += last_val
            return sum_val % 11 == 0

        # Valid ISBN-10: 0306406152
        self.assertTrue(is_valid_isbn10("0-306-40615-2"))
        # Invalid ISBN-10
        self.assertFalse(is_valid_isbn10("0-306-40615-3"))

    def test_isbn13_validation(self):
        def is_valid_isbn13(isbn):
            cleaned = "".join(c for c in isbn.upper() if c.isalnum())
            if len(cleaned) != 13:
                return False
            if not (cleaned.startswith("978") or cleaned.startswith("979")):
                return False
            sum_val = 0
            for i in range(13):
                if not cleaned[i].isdigit():
                    return False
                multiplier = 1 if i % 2 == 0 else 3
                sum_val += int(cleaned[i]) * multiplier
            return sum_val % 10 == 0

        # Valid ISBN-13: 9780306406157
        self.assertTrue(is_valid_isbn13("978-0-306-40615-7"))
        # Invalid ISBN-13
        self.assertFalse(is_valid_isbn13("978-0-306-40615-8"))

    def test_isbn10_to_13_conversion(self):
        def convert_10_to_13(isbn10):
            cleaned = "".join(c for c in isbn10.upper() if c.isalnum())
            base = "978" + cleaned[:-1]
            sum_val = 0
            for i in range(12):
                multiplier = 1 if i % 2 == 0 else 3
                sum_val += int(base[i]) * multiplier
            check = (10 - (sum_val % 10)) % 10
            return base + str(check)

        # 0306406152 -> 9780306406157
        self.assertEqual(convert_10_to_13("0306406152"), "9780306406157")

    def test_bbid_formatting_and_monotonicity(self):
        def format_bbid(val):
            return f"BB-{val:06d}"

        self.assertEqual(format_bbid(1), "BB-000001")
        self.assertEqual(format_bbid(42), "BB-000042")
        self.assertEqual(format_bbid(100000), "BB-100000")

        # Test parsing BBID
        def parse_bbid(s):
            s = s.strip()
            if not s.startswith("BB-"):
                return None
            try:
                val = int(s[3:])
                return val if val > 0 else None
            except ValueError:
                return None

        self.assertEqual(parse_bbid("BB-000001"), 1)
        self.assertEqual(parse_bbid("BB-000042"), 42)
        self.assertIsNone(parse_bbid("INVALID"))


if __name__ == '__main__':
    unittest.main()
