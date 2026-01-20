#!/usr/bin/env python3
import csv
import os
import re
import sys
from pathlib import Path
from typing import List, Dict, Tuple, Optional
import codecs

class ITGlueImportValidator:
    """Validates IT Glue CSV import files for common errors."""
    
    # Common IT Glue CSV templates and their required fields
    # Based on actual IT Glue templates - they use 'organization' (lowercase, no underscore)
    REQUIRED_FIELDS = {
        'configurations': ['organization', 'configuration_type_name', 'name'],
        'contacts': ['organization', 'first_name', 'last_name'],
        'locations': ['organization', 'name'],
        'passwords': ['organization', 'name', 'username', 'password'],  # username and password ARE required!
        'flexible_assets': ['organization', 'flexible_asset_type_name', 'name'],
        'organizations': ['name'],
        'ssl_certificates': ['organization', 'name'],
        'certificates': ['organization', 'name']
    }
    
    # Fields that should not be blank even if not technically "required"
    RECOMMENDED_FIELDS = {
        'passwords': ['password_category']  # Strongly recommended but not required
    }
    
    # Known valid password categories in IT Glue
    VALID_PASSWORD_CATEGORIES = [
        'General',
        'Administrative',
        'Database',
        'Email',
        'Network',
        'Application',
        'Service Account',
        'Vendor',
        'VPN',
        'Web Application',
        'SSH Key',
        'API Key'
    ]
    
    def __init__(self, csv_path: str):
        self.csv_path = csv_path
        self.errors: List[str] = []
        self.warnings: List[str] = []
        self.fixes: List[Dict] = []  # Track fixable issues
        self.filename = os.path.basename(csv_path)
        self.file_type: Optional[str] = None
        # Track rows with empty required fields for fixing
        self.empty_required_fields: Dict[str, List[int]] = {}
        
    def validate(self) -> Tuple[bool, List[str], List[str]]:
        """Run all validations on the CSV file."""
        print(f"\n{'='*60}")
        print(f"Validating: {self.filename}")
        
        # Check if file exists and is readable
        if not self._check_file_exists():
            print(f"{'='*60}\n")
            return False, self.errors, self.warnings
        
        # Check file encoding
        has_bom = self._check_encoding()
        
        # Read and validate CSV structure
        try:
            with open(self.csv_path, 'r', encoding='utf-8-sig', newline='') as f:
                reader = csv.DictReader(f)
                rows = list(reader)
                headers = reader.fieldnames
                
                if not headers:
                    self.errors.append("CSV file has no headers")
                    print(f"{'='*60}\n")
                    return False, self.errors, self.warnings
                
                # Detect file type from headers first, then filename
                self._detect_file_type(headers)
                
                # Display detected file type
                if self.file_type:
                    print(f"Detected Type: {self.file_type.replace('_', ' ').title()}")
                else:
                    print(f"Detected Type: Unknown (validation may be limited)")
                print(f"{'='*60}\n")
                
                # Run all validation checks
                self._check_bom(headers, has_bom)
                self._check_required_fields(headers)
                self._check_incomplete_rows(rows, headers)  # NEW: Check for rows with only org name
                self._check_empty_required_fields(rows, headers)
                self._check_recommended_fields(rows, headers)
                self._check_spaces_in_empty_cells(rows, headers)
                self._check_special_characters(rows, headers)
                self._check_line_breaks(rows, headers)
                self._check_duplicate_rows(rows)
                self._check_duplicate_names(rows)
                self._check_organization_names(rows)
                self._check_organization_exists(rows)
                self._check_url_fields(rows, headers)
                self._check_email_fields(rows, headers)
                self._check_date_fields(rows, headers)
                self._check_commas_in_fields(rows, headers)
                self._check_field_length(rows, headers)
                self._check_password_categories(rows, headers)
                self._check_header_case(headers)
                self._check_extra_columns(headers)
                self._check_hidden_characters(rows, headers)
                self._check_row_count(rows)
                self._check_column_count(headers, rows)
                self._check_quotes_balance(rows, headers)
                self._check_trailing_delimiters(rows, headers)
                
        except UnicodeDecodeError:
            self.errors.append("File encoding error. File must be UTF-8 encoded.")
            self.errors.append("  → Save as 'CSV UTF-8' (NOT 'CSV UTF-8 with BOM')")
            self.fixes.append({
                'type': 'encoding',
                'message': 'Convert file to UTF-8 encoding'
            })
        except csv.Error as e:
            self.errors.append(f"CSV parsing error: {str(e)}")
            self.errors.append("This usually means the CSV structure is malformed (unclosed quotes, inconsistent columns, etc.)")
        except AttributeError as e:
            self.errors.append(f"Data structure error: {str(e)}")
            self.errors.append("This usually means a field value is None/NULL where text was expected. Check for empty cells in required fields.")
        except Exception as e:
            self.errors.append(f"Unexpected error: {str(e)}")
            self.errors.append(f"Error type: {type(e).__name__}")
        
        # Print results
        self._print_results()
        
        # Offer to fix issues
        if self.fixes and (self.errors or self.warnings):
            self._offer_fixes()
        
        return len(self.errors) == 0, self.errors, self.warnings
    
    def _detect_file_type(self, headers: List[str]):
        """Detect file type from headers first, then filename."""
        # Check headers for type-specific fields
        header_lower = [h.lower() for h in headers]
        
        if 'configuration_type_name' in header_lower:
            self.file_type = 'configurations'
        elif 'first_name' in header_lower and 'last_name' in header_lower:
            self.file_type = 'contacts'
        elif 'address_1' in header_lower or 'city' in header_lower:
            self.file_type = 'locations'
        elif 'password' in header_lower and 'username' in header_lower:
            self.file_type = 'passwords'
        elif 'flexible_asset_type_name' in header_lower:
            self.file_type = 'flexible_assets'
        elif 'issued_by' in header_lower or 'valid_until' in header_lower:
            self.file_type = 'ssl_certificates'
        elif 'organization' not in header_lower and 'name' in header_lower:
            # Organizations don't have organization field
            self.file_type = 'organizations'
        else:
            # Fall back to filename detection
            for key in self.REQUIRED_FIELDS.keys():
                if key in self.filename.lower().replace(' ', '_').replace('-', '_'):
                    self.file_type = key
                    break
    
    def _check_file_exists(self) -> bool:
        """Check if file exists and is readable."""
        if not os.path.exists(self.csv_path):
            self.errors.append(f"File not found: {self.csv_path}")
            return False
        if not os.path.isfile(self.csv_path):
            self.errors.append(f"Path is not a file: {self.csv_path}")
            return False
        if os.path.getsize(self.csv_path) == 0:
            self.errors.append("File is empty")
            return False
        return True
    
    def _check_encoding(self) -> bool:
        """Check file encoding and return True if BOM detected."""
        try:
            with open(self.csv_path, 'rb') as f:
                raw_data = f.read(4)
                # Check for BOM
                if raw_data.startswith(b'\xef\xbb\xbf'):
                    return True
        except Exception as e:
            self.warnings.append(f"Could not check encoding: {str(e)}")
        return False
    
    def _check_bom(self, headers: List[str], has_bom: bool):
        """Check for BOM in headers."""
        if has_bom or (headers and headers[0].startswith('\ufeff')):
            self.errors.append("File has UTF-8 BOM (Byte Order Mark) - IT Glue imports WILL FAIL")
            self.errors.append("  → BOM is an invisible character that breaks IT Glue imports")
            self.errors.append("  → Use the 'Create Fixed File' option below to remove it")
            self.errors.append("  → Or manually: Save as 'CSV UTF-8' (NOT 'CSV UTF-8 with BOM')")
            self.fixes.append({
                'type': 'bom',
                'message': 'Remove UTF-8 BOM from file'
            })
    
    def _check_spaces_in_empty_cells(self, rows: List[Dict], headers: List[str]):
        """Check for spaces, tabs, or whitespace in cells that should be empty."""
        for idx, row in enumerate(rows, start=2):
            for field, value in row.items():
                if value and isinstance(value, str):
                    # Check if value is ONLY whitespace (spaces, tabs, etc.)
                    if value and not value.strip():
                        self.errors.append(f"Row {idx}, Field '{field}': Contains only whitespace (spaces/tabs)")
                        self.errors.append(f"  → IT Glue requires empty cells to be COMPLETELY EMPTY")
                        self.errors.append(f"  → Delete the spaces/tabs from this cell")
                        self.fixes.append({
                            'type': 'whitespace_only',
                            'row': idx,
                            'field': field
                        })
    
    def _check_trailing_delimiters(self, rows: List[Dict], headers: List[str]):
        """Check for trailing commas/delimiters that create phantom columns."""
        # Read raw file to check for trailing commas
        try:
            with open(self.csv_path, 'r', encoding='utf-8-sig') as f:
                lines = f.readlines()
                
            expected_commas = len(headers) - 1
            
            for idx, line in enumerate(lines[1:], start=2):  # Skip header
                if line.strip():  # Skip empty lines
                    # Count commas not inside quotes
                    comma_count = 0
                    in_quotes = False
                    for char in line:
                        if char == '"':
                            in_quotes = not in_quotes
                        elif char == ',' and not in_quotes:
                            comma_count += 1
                    
                    if comma_count > expected_commas:
                        self.warnings.append(f"Row {idx}: Has {comma_count - expected_commas} extra comma(s) at end of line")
                        self.warnings.append(f"  → This creates phantom empty columns")
                        self.warnings.append(f"  → Remove trailing commas from this row")
                        self.fixes.append({
                            'type': 'trailing_delimiters',
                            'row': idx
                        })
        except Exception:
            pass  # Skip if we can't read the raw file
    
    def _check_required_fields(self, headers: List[str]):
        """Check for required fields based on file type."""
        if self.file_type and self.file_type in self.REQUIRED_FIELDS:
            required = self.REQUIRED_FIELDS[self.file_type]
            header_lower = [h.lower() for h in headers]
            
            # Check for case-insensitive matches
            missing = []
            for field in required:
                if field.lower() not in header_lower:
                    missing.append(field)
            
            if missing:
                self.errors.append(f"Missing required fields: {', '.join(missing)}")
                self.errors.append(f"  → Detected file type: '{self.file_type}'")
                self.errors.append(f"  → Current headers: {', '.join(headers)}")
                
                if self.file_type == 'passwords':
                    self.errors.append(f"  → For passwords, IT Glue REQUIRES: organization, name, username, password")
                    self.errors.append(f"  → If you don't have username/password, you cannot import without them")
                
                self.errors.append(f"  → Add these columns to your CSV file")
                
                # Offer to add missing columns
                self.fixes.append({
                    'type': 'add_columns',
                    'columns': missing
                })
                
                # Check for common mistakes
                if 'organization' in missing and 'Organization' in headers:
                    self.errors.append(f"  → Note: Field names are case-sensitive. Use lowercase 'organization'")
        elif not self.file_type:
            self.warnings.append(f"Could not determine file type from headers or filename")
            self.warnings.append(f"  → Known types: {', '.join(self.REQUIRED_FIELDS.keys())}")
            self.warnings.append(f"  → Current headers: {', '.join(headers) if headers else 'None'}")
            self.warnings.append(f"  → Ensure your CSV has the correct headers for the import type")
            self.warnings.append(f"  → Or rename file to include type (e.g., 'contacts.csv', 'passwords.csv')")
    
    def _check_header_case(self, headers: List[str]):
        """Check that headers match expected case."""
        if not self.file_type or self.file_type not in self.REQUIRED_FIELDS:
            return
        
        expected_fields = self.REQUIRED_FIELDS[self.file_type]
        
        # Also check common optional fields for passwords
        if self.file_type == 'passwords':
            expected_fields = expected_fields + ['password_category', 'url', 'notes']
        
        for expected in expected_fields:
            for header in headers:
                if header.lower() == expected.lower() and header != expected:
                    self.errors.append(f"Header case mismatch: '{header}' should be '{expected}'")
                    self.errors.append(f"  → IT Glue is case-sensitive with field names")
                    self.errors.append(f"  → This WILL cause the import to fail")
                    self.fixes.append({
                        'type': 'header_case',
                        'original': header,
                        'correct': expected
                    })
    
    def _check_empty_required_fields(self, rows: List[Dict], headers: List[str]):
        """Check for empty values in required fields."""
        if not self.file_type:
            return
            
        required_fields = self.REQUIRED_FIELDS.get(self.file_type, [])
        
        # Create case-insensitive mapping of headers
        header_map = {h.lower(): h for h in headers}
        
        # Get actual header names for required fields
        actual_fields = []
        for req_field in required_fields:
            if req_field.lower() in header_map:
                actual_fields.append(header_map[req_field.lower()])
        
        for idx, row in enumerate(rows, start=2):
            for field in actual_fields:
                if field in row:
                    value = row.get(field)
                    if value is None or (isinstance(value, str) and not value.strip()):
                        self.errors.append(f"Row {idx}: Required field '{field}' is empty")
                        self.errors.append(f"  → Every row MUST have a value for '{field}'")
                        
                        # Track for fixing
                        if field not in self.empty_required_fields:
                            self.empty_required_fields[field] = []
                        self.empty_required_fields[field].append(idx)
                        
                        if self.file_type == 'passwords' and field.lower() in ['username', 'password']:
                            self.errors.append(f"  → You can use a placeholder like 'N/A' or '(See Notes)'")
        
        # Add fixes for empty required fields
        for field, rows_list in self.empty_required_fields.items():
            self.fixes.append({
                'type': 'fill_required_field',
                'field': field,
                'rows': rows_list,
                'count': len(rows_list)
            })
    
    def _check_recommended_fields(self, rows: List[Dict], headers: List[str]):
        """Check for empty values in recommended (but not strictly required) fields."""
        if not self.file_type or self.file_type not in self.RECOMMENDED_FIELDS:
            return
            
        recommended = self.RECOMMENDED_FIELDS[self.file_type]
        header_map = {h.lower(): h for h in headers}
        
        # Get actual header names for recommended fields
        actual_fields = []
        for rec_field in recommended:
            if rec_field.lower() in header_map:
                actual_fields.append(header_map[rec_field.lower()])
        
        empty_count = {field: 0 for field in actual_fields}
        
        for idx, row in enumerate(rows, start=2):
            for field in actual_fields:
                if field in row:
                    value = row.get(field)
                    if value is None or (isinstance(value, str) and not value.strip()):
                        empty_count[field] += 1
                        if empty_count[field] <= 3:  # Only show first 3 examples
                            self.warnings.append(f"Row {idx}: Recommended field '{field}' is empty")
                            if self.file_type == 'passwords':
                                self.warnings.append(f"  → Password category helps organize passwords in IT Glue")
        
        # Summary if many empty and offer to fill with defaults
        for field, count in empty_count.items():
            if count > 0:
                if count > 3:
                    self.warnings.append(f"Field '{field}' is empty in {count} total rows")
                    self.warnings.append(f"  → Consider filling in these values before import")
                
                # Offer to fill empty fields with default values
                self.fixes.append({
                    'type': 'fill_recommended_field',
                    'field': field,
                    'count': count
                })
    
    def _check_duplicate_names(self, rows: List[Dict]):
        """Check for duplicate names within the same organization."""
        if not rows:
            return
        
        # Find name and organization fields
        name_field = None
        org_field = None
        for key in rows[0].keys():
            if key.lower() == 'name':
                name_field = key
            if key.lower() == 'organization':
                org_field = key
        
        if not name_field:
            return
        
        # Track name+org combinations
        seen = {}
        for idx, row in enumerate(rows, start=2):
            name = row.get(name_field, '').strip() if row.get(name_field) else ''
            org = row.get(org_field, '').strip() if row.get(org_field) else 'NO_ORG'
            
            if name:
                key = (org, name)
                if key in seen:
                    self.warnings.append(f"Row {idx}: Duplicate name '{name}' in organization '{org}'")
                    self.warnings.append(f"  → First seen in row {seen[key]}")
                    self.warnings.append(f"  → IT Glue may reject duplicates or update existing entries")
                else:
                    seen[key] = idx
    
    def _check_column_count(self, headers: List[str], rows: List[Dict]):
        """Check that all rows have the same number of columns."""
        expected_count = len(headers)
        
        for idx, row in enumerate(rows, start=2):
            actual_count = len([v for v in row.values() if v is not None])
            if actual_count != expected_count:
                # Check if it's just trailing empty columns
                non_empty = sum(1 for v in row.values() if v and str(v).strip())
                if non_empty > 0:  # Only warn if there's actual data
                    self.warnings.append(f"Row {idx}: Column count mismatch")
                    self.warnings.append(f"  → Expected {expected_count} columns, found data in {non_empty}")
                    self.warnings.append(f"  → This may indicate malformed CSV structure")
    
    def _check_quotes_balance(self, rows: List[Dict], headers: List[str]):
        """Check for unbalanced quotes in fields."""
        for idx, row in enumerate(rows, start=2):
            for field, value in row.items():
                if value and isinstance(value, str):
                    # Count quotes
                    quote_count = value.count('"')
                    if quote_count % 2 != 0:
                        self.errors.append(f"Row {idx}, Field '{field}': Unbalanced quotes detected")
                        self.errors.append(f"  → Value: {value[:100]}..." if len(value) > 100 else f"  → Value: {value}")
                        self.errors.append(f"  → Unbalanced quotes will break CSV parsing")
                        self.errors.append(f"  → Escape quotes by doubling them (\"\") or remove them")
    
    def _check_organization_exists(self, rows: List[Dict]):
        """Check that organization names are not obviously invalid."""
        if not rows:
            return
        
        # Find the organization field
        org_field = None
        for key in rows[0].keys():
            if key.lower() == 'organization':
                org_field = key
                break
        
        if not org_field:
            return
        
        for idx, row in enumerate(rows, start=2):
            org_name = row.get(org_field, '').strip() if row.get(org_field) else ''
            if org_name:
                # Check for placeholder names
                placeholders = ['test', 'example', 'sample', 'your organization', 'org name', 'company name']
                if org_name.lower() in placeholders:
                    self.errors.append(f"Row {idx}: Organization name looks like a placeholder: '{org_name}'")
                    self.errors.append(f"  → Replace with EXACT organization name from IT Glue")
                    self.errors.append(f"  → Go to IT Glue → Organizations → Copy name exactly")
                
                # Check for very short names
                if len(org_name) < 2:
                    self.errors.append(f"Row {idx}: Organization name is too short: '{org_name}'")
                    self.errors.append(f"  → Minimum 2 characters required")
                
                # Check for special characters that might cause issues
                if any(char in org_name for char in ['<', '>', '|', '\\', '/', '*', '?', ':']):
                    self.warnings.append(f"Row {idx}: Organization name contains special characters: '{org_name}'")
                    self.warnings.append(f"  → Special characters may cause lookup failures in IT Glue")
                    self.warnings.append(f"  → Organization name must EXACTLY match the name in IT Glue")
                
                # Check for leading/trailing whitespace (after strip)
                original = row.get(org_field, '')
                if original != original.strip():
                    self.errors.append(f"Row {idx}: Organization name has leading/trailing spaces: '{org_name}'")
                    self.errors.append(f"  → Remove all leading/trailing spaces")
                    self.errors.append(f"  → Organization name must EXACTLY match IT Glue")
    
    def _check_password_categories(self, rows: List[Dict], headers: List[str]):
        """Check password category values if this is a password import."""
        if self.file_type != 'passwords':
            return
        
        # Find password_category field (case-insensitive)
        category_field = None
        for header in headers:
            if header.lower() == 'password_category':
                category_field = header
                break
        
        if not category_field:
            return
        
        for idx, row in enumerate(rows, start=2):
            category = row.get(category_field, '').strip() if row.get(category_field) else ''
            if category and category not in self.VALID_PASSWORD_CATEGORIES:
                self.warnings.append(f"Row {idx}: Unknown password_category: '{category}'")
                self.warnings.append(f"  → Valid categories: {', '.join(self.VALID_PASSWORD_CATEGORIES)}")
                self.warnings.append(f"  → IT Glue may reject this import if category doesn't exist")
    
    def _check_extra_columns(self, headers: List[str]):
        """Check for unexpected columns that might cause issues."""
        # Common columns that shouldn't be in imports
        problematic_columns = ['id', 'created_at', 'updated_at', 'resource_url', 'organization_id']
        
        for header in headers:
            if header.lower() in problematic_columns:
                self.warnings.append(f"Column '{header}' found in CSV")
                self.warnings.append(f"  → This is typically an export-only field")
                self.warnings.append(f"  → IT Glue may ignore or reject this column during import")
    
    def _check_hidden_characters(self, rows: List[Dict], headers: List[str]):
        """Check for non-printable and hidden characters."""
        for idx, row in enumerate(rows, start=2):
            for field, value in row.items():
                if value:
                    # Check for zero-width characters
                    zero_width_chars = ['\u200b', '\u200c', '\u200d', '\ufeff']
                    for char in zero_width_chars:
                        if char in value:
                            self.warnings.append(f"Row {idx}, Field '{field}': Contains zero-width/invisible character")
                            self.warnings.append(f"  → This can cause matching failures in IT Glue")
                            self.fixes.append({
                                'type': 'hidden_chars',
                                'row': idx,
                                'field': field
                            })
    
    def _check_row_count(self, rows: List[Dict]):
        """Check if row count seems reasonable."""
        if len(rows) == 0:
            self.errors.append("CSV has headers but no data rows")
            self.errors.append("  → Add at least one data row to import")
        elif len(rows) > 5000:
            self.warnings.append(f"CSV has {len(rows)} rows - this is a large import")
            self.warnings.append("  → Consider splitting into smaller batches (500-1000 rows)")
            self.warnings.append("  → Large imports may timeout or fail")
            self.warnings.append("  → Test with 5-10 rows first to ensure format is correct")
    
    def _check_special_characters(self, rows: List[Dict], headers: List[str]):
        """Check for problematic special characters."""
        problematic_chars = {
            '\x00': 'NULL character (\\x00)',
            '\r\r': 'Double carriage return (\\r\\r)',
            '\n\n': 'Double line feed (\\n\\n)'
        }
        
        for idx, row in enumerate(rows, start=2):
            for field, value in row.items():
                if value:
                    for char, char_name in problematic_chars.items():
                        if char in value:
                            self.warnings.append(f"Row {idx}, Field '{field}': Contains {char_name}")
                            self.warnings.append(f"  → This can cause CSV parsing errors")
                            self.fixes.append({
                                'type': 'special_chars',
                                'row': idx,
                                'field': field,
                                'char': char_name
                            })
    
    def _check_line_breaks(self, rows: List[Dict], headers: List[str]):
        """Check for line breaks in fields - these need to be properly quoted."""
        for idx, row in enumerate(rows, start=2):
            for field, value in row.items():
                if value and ('\n' in value or '\r' in value):
                    # Line breaks need proper quoting
                    self.warnings.append(f"Row {idx}, Field '{field}': Contains line breaks")
                    self.warnings.append(f"  → Will be properly quoted in fixed file")
                    self.fixes.append({
                        'type': 'line_breaks',
                        'row': idx,
                        'field': field
                    })
    
    def _check_duplicate_rows(self, rows: List[Dict]):
        """Check for duplicate rows."""
        seen = set()
        for idx, row in enumerate(rows, start=2):
            # Create a tuple of the row for comparison
            row_tuple = tuple(sorted(row.items()))
            if row_tuple in seen:
                self.warnings.append(f"Row {idx}: Appears to be a duplicate of a previous row")
                self.warnings.append(f"  → This will create duplicate entries in IT Glue")
            seen.add(row_tuple)
    
    def _check_organization_names(self, rows: List[Dict]):
        """Check organization name consistency."""
        # Find the organization field (case-insensitive)
        org_field = None
        if rows:
            for key in rows[0].keys():
                if key.lower() == 'organization':
                    org_field = key
                    break
        
        if org_field:
            org_names = set()
            for row in rows:
                org_name = row.get(org_field, '').strip() if row.get(org_field) else ''
                if org_name:
                    org_names.add(org_name)
            
            if len(org_names) > 1:
                self.warnings.append(f"Multiple organization names found: {', '.join(sorted(org_names))}")
                self.warnings.append(f"  → Importing multiple organizations in one file may cause issues")
                self.warnings.append(f"  → Consider splitting into separate files per organization")
                self.warnings.append(f"  → Ensure ALL organization names EXACTLY match IT Glue")
    
    def _check_url_fields(self, rows: List[Dict], headers: List[str]):
        """Check URL field formatting."""
        url_fields = [h for h in headers if 'url' in h.lower() or 'website' in h.lower()]
        
        for idx, row in enumerate(rows, start=2):
            for field in url_fields:
                value = row.get(field, '').strip() if row.get(field) else ''
                if not value:
                    continue
                
                # Check for spaces in URL
                if ' ' in value:
                    # Check if it looks like domain credentials (not a real URL)
                    if not value.startswith('http://') and not value.startswith('https://'):
                        self.errors.append(f"Row {idx}, Field '{field}': Contains spaces and doesn't look like a URL: '{value}'")
                        self.errors.append(f"  → This appears to be credentials or text, not a URL")
                        self.errors.append(f"  → URLs should start with 'http://' or 'https://'")
                        self.errors.append(f"  → If this is a domain/username (like 'Domain Admin ABCD.local'), move to notes field")
                        self.errors.append(f"  → If this is a real URL with spaces, they will be encoded as %20")
                    else:
                        self.warnings.append(f"Row {idx}, Field '{field}': URL contains spaces: '{value}'")
                        self.warnings.append(f"  → Spaces will be encoded as %20")
                    
                    self.fixes.append({
                        'type': 'url_spaces',
                        'row': idx,
                        'field': field
                    })
                
                # Check for obviously wrong URL patterns
                # "Domain Admin something.local" or "something.local username"
                if '.local' in value.lower() and not value.startswith('http'):
                    self.errors.append(f"Row {idx}, Field '{field}': Looks like domain credentials, not a URL: '{value}'")
                    self.errors.append(f"  → Move this to the 'notes' field instead")
                    self.errors.append(f"  → URL field should contain actual web addresses")
                
                # Check for service account patterns
                if 'srvc_' in value.lower() or 'svc_' in value.lower() or 'service' in value.lower():
                    self.warnings.append(f"Row {idx}, Field '{field}': Looks like service account info, not a URL: '{value}'")
                    self.warnings.append(f"  → Consider moving to 'username' or 'notes' field")
    
    def _check_email_fields(self, rows: List[Dict], headers: List[str]):
        """Check email field formatting."""
        email_fields = [h for h in headers if 'email' in h.lower()]
        email_pattern = re.compile(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$')
        
        for idx, row in enumerate(rows, start=2):
            for field in email_fields:
                value = row.get(field, '').strip() if row.get(field) else ''
                if value and not email_pattern.match(value):
                    self.errors.append(f"Row {idx}, Field '{field}': Invalid email format: '{value}'")
                    self.errors.append(f"  → Email must be in format: user@domain.com")
    
    def _check_date_fields(self, rows: List[Dict], headers: List[str]):
        """Check date field formatting."""
        date_fields = [h for h in headers if 'date' in h.lower() or 'created' in h.lower() or 'updated' in h.lower() or 'valid_until' in h.lower()]
        
        for idx, row in enumerate(rows, start=2):
            for field in date_fields:
                value = row.get(field, '').strip() if row.get(field) else ''
                if value:
                    # IT Glue requires ISO 8601 format: YYYY-MM-DD
                    if not re.match(r'^\d{4}-\d{2}-\d{2}$', value):
                        self.errors.append(f"Row {idx}, Field '{field}': Date format must be YYYY-MM-DD (ISO 8601), found: '{value}'")
                        self.errors.append(f"  → Example: 2026-01-14")
                        self.errors.append(f"  → NOT: 01/14/2026 or 14-Jan-2026")
    
    def _check_commas_in_fields(self, rows: List[Dict], headers: List[str]):
        """Check for commas in fields that need to be quoted."""
        for idx, row in enumerate(rows, start=2):
            for field, value in row.items():
                if value and ',' in value:
                    self.warnings.append(f"Row {idx}, Field '{field}': Contains comma(s)")
                    self.warnings.append(f"  → Will be properly quoted in fixed file")
                    self.fixes.append({
                        'type': 'commas_in_field',
                        'row': idx,
                        'field': field
                    })
    
    def _check_field_length(self, rows: List[Dict], headers: List[str]):
        """Check for excessively long field values."""
        MAX_LENGTH = 65535  # Common database text field limit
        
        for idx, row in enumerate(rows, start=2):
            for field, value in row.items():
                if value and len(value) > MAX_LENGTH:
                    self.errors.append(f"Row {idx}, Field '{field}': Value exceeds maximum length ({len(value)} characters)")
                    self.errors.append(f"  → Maximum allowed: {MAX_LENGTH} characters")
                elif value and len(value) > 10000:
                    self.warnings.append(f"Row {idx}, Field '{field}': Very long value ({len(value)} characters)")
                    self.warnings.append(f"  → Consider breaking into smaller chunks if possible")
    
    def _print_results(self):
        """Print validation results."""
        if self.errors:
            print(f"\n❌ ERRORS FOUND ({len(self.errors)}) - IMPORT WILL FAIL:")
            for error in self.errors:
                print(f"  {error}")
        
        if self.warnings:
            print(f"\n⚠️  WARNINGS ({len(self.warnings)}) - MAY CAUSE IMPORT ISSUES:")
            for warning in self.warnings:
                print(f"  {warning}")
        
        if not self.errors and not self.warnings:
            print("\n✅ No issues found! File appears ready for import.")
            print("   → Test with 5-10 rows first to verify")
        elif not self.errors:
            print("\n✅ No critical errors found (only warnings)")
            print("   → File may import, but review warnings above")
            print("   → Test with 5-10 rows first to verify")
        else:
            print("\n❌ CRITICAL ERRORS FOUND - Fix these before attempting import")
        
        print()
    
    def _offer_fixes(self):
        """Offer to automatically fix issues."""
        fixable_types = set(fix['type'] for fix in self.fixes)
        
        if not fixable_types:
            return
        
        print(f"\n{'='*60}")
        print("AUTOMATIC FIXES AVAILABLE")
        print(f"{'='*60}")
        
        if 'add_columns' in fixable_types:
            missing_columns = []
            for fix in self.fixes:
                if fix['type'] == 'add_columns':
                    missing_columns.extend(fix['columns'])
            print(f"\n  • Add missing required columns: {', '.join(missing_columns)}")
        
        if 'fill_required_field' in fixable_types:
            for fix in self.fixes:
                if fix['type'] == 'fill_required_field':
                    print(f"  • Fill {fix['count']} empty '{fix['field']}' fields with placeholder value")
        
        if 'fill_recommended_field' in fixable_types:
            for fix in self.fixes:
                if fix['type'] == 'fill_recommended_field':
                    print(f"  • Fill {fix['count']} empty '{fix['field']}' fields with default value")
        
        if 'header_case' in fixable_types:
            print("  • Fix header case (lowercase required)")
        
        if 'bom' in fixable_types:
            print("  • Remove UTF-8 BOM (CRITICAL)")
        if 'whitespace_only' in fixable_types:
            print("  • Remove whitespace-only cells (CRITICAL)")
        if 'special_chars' in fixable_types:
            print("  • Remove problematic special characters (double line feeds, etc.)")
        if 'line_breaks' in fixable_types:
            print("  • Properly quote fields with line breaks")
        if 'commas_in_field' in fixable_types:
            print("  • Properly quote fields with commas")
        if 'url_spaces' in fixable_types:
            print("  • Encode URL spaces as %20")
        if 'hidden_chars' in fixable_types:
            print("  • Remove hidden/zero-width characters")
        if 'trailing_delimiters' in fixable_types:
            print("  • Remove trailing commas/delimiters")
        
        response = input("\nWould you like to create a fixed version of this file? (y/n): ").strip().lower()
        
        if response == 'y':
            self._apply_fixes()
    
    def _apply_fixes(self):
        """Apply fixes and create a new file."""
        try:
            output_path = self.csv_path.replace('.csv', '_fixed.csv')
            
            # Read the file
            with open(self.csv_path, 'r', encoding='utf-8-sig', newline='') as f:
                reader = csv.DictReader(f)
                headers = list(reader.fieldnames)
                rows = list(reader)
            
            # Track what we fixed
            fixes_applied = set()
            fill_defaults = {}
            
            # Fix header case first
            header_fixes = {}
            for fix in self.fixes:
                if fix['type'] == 'header_case':
                    header_fixes[fix['original']] = fix['correct']
            
            if header_fixes:
                new_headers = []
                for h in headers:
                    if h in header_fixes:
                        new_headers.append(header_fixes[h])
                        fixes_applied.add('header_case_fixed')
                    else:
                        new_headers.append(h)
                headers = new_headers
                
                # Also update rows to use new header names
                for row in rows:
                    for old_name, new_name in header_fixes.items():
                        if old_name in row:
                            row[new_name] = row.pop(old_name)
            
            # Check if we need to add missing columns
            missing_columns = []
            for fix in self.fixes:
                if fix['type'] == 'add_columns':
                    missing_columns.extend(fix['columns'])
            
            # Add missing columns to headers
            if missing_columns:
                # Get default values for missing columns
                default_values = {}
                
                if self.file_type == 'passwords':
                    if 'password_category' in missing_columns:
                        print("\n  Password category is recommended. Options:")
                        for i, cat in enumerate(self.VALID_PASSWORD_CATEGORIES, 1):
                            print(f"    {i}. {cat}")
                        
                        choice = input("\n  Enter number for default category (or press Enter for 'General'): ").strip()
                        if choice.isdigit() and 1 <= int(choice) <= len(self.VALID_PASSWORD_CATEGORIES):
                            default_values['password_category'] = self.VALID_PASSWORD_CATEGORIES[int(choice) - 1]
                        else:
                            default_values['password_category'] = 'General'
                        
                        print(f"  → Using '{default_values['password_category']}' as default category")
                
                # Add columns to headers
                for col in missing_columns:
                    if col not in headers:
                        headers.append(col)
                
                # Add default values to all rows
                for row in rows:
                    for col in missing_columns:
                        if col not in row:
                            row[col] = default_values.get(col, '')
                
                fixes_applied.add('columns_added')
            
            # Handle empty REQUIRED fields (like username/password)
            for fix in self.fixes:
                if fix['type'] == 'fill_required_field':
                    field = fix['field']
                    count = fix['count']
                    
                    print(f"\n  {count} rows have empty REQUIRED field '{field}'.")
                    
                    if field.lower() == 'username':
                        print("  Options for empty username fields:")
                        print("    1. N/A")
                        print("    2. (No Username)")
                        print("    3. Password Only")
                        print("    4. (See Notes)")
                        print("    5. Enter custom value")
                        print("    6. Skip (leave empty - IMPORT MAY FAIL)")
                        
                        choice = input("\n  Enter option (1-6, or press Enter for 'N/A'): ").strip()
                        
                        if choice == '2':
                            fill_defaults[field] = '(No Username)'
                        elif choice == '3':
                            fill_defaults[field] = 'Password Only'
                        elif choice == '4':
                            fill_defaults[field] = '(See Notes)'
                        elif choice == '5':
                            custom = input("  Enter custom value: ").strip()
                            fill_defaults[field] = custom if custom else 'N/A'
                        elif choice == '6':
                            fill_defaults[field] = None
                            print("  → WARNING: Empty usernames may cause import to fail!")
                        else:
                            fill_defaults[field] = 'N/A'
                        
                        if fill_defaults.get(field):
                            print(f"  → Will use '{fill_defaults[field]}' for {count} empty username fields")
                    
                    elif field.lower() == 'password':
                        print("  Options for empty password fields:")
                        print("    1. (See Notes)")
                        print("    2. N/A")
                        print("    3. (No Password)")
                        print("    4. ********")
                        print("    5. Enter custom value")
                        print("    6. Skip (leave empty - IMPORT MAY FAIL)")
                        
                        choice = input("\n  Enter option (1-6, or press Enter for '(See Notes)'): ").strip()
                        
                        if choice == '2':
                            fill_defaults[field] = 'N/A'
                        elif choice == '3':
                            fill_defaults[field] = '(No Password)'
                        elif choice == '4':
                            fill_defaults[field] = '********'
                        elif choice == '5':
                            custom = input("  Enter custom value: ").strip()
                            fill_defaults[field] = custom if custom else '(See Notes)'
                        elif choice == '6':
                            fill_defaults[field] = None
                            print("  → WARNING: Empty passwords may cause import to fail!")
                        else:
                            fill_defaults[field] = '(See Notes)'
                        
                        if fill_defaults.get(field):
                            print(f"  → Will use '{fill_defaults[field]}' for {count} empty password fields")
                    
                    else:
                        # Generic required field
                        print(f"  Options for empty '{field}' fields:")
                        print("    1. N/A")
                        print("    2. (Not Specified)")
                        print("    3. Enter custom value")
                        print("    4. Skip (leave empty - IMPORT MAY FAIL)")
                        
                        choice = input("\n  Enter option (1-4, or press Enter for 'N/A'): ").strip()
                        
                        if choice == '2':
                            fill_defaults[field] = '(Not Specified)'
                        elif choice == '3':
                            custom = input("  Enter custom value: ").strip()
                            fill_defaults[field] = custom if custom else 'N/A'
                        elif choice == '4':
                            fill_defaults[field] = None
                        else:
                            fill_defaults[field] = 'N/A'
                        
                        if fill_defaults.get(field):
                            print(f"  → Will use '{fill_defaults[field]}' for {count} empty {field} fields")
            
            # Handle empty RECOMMENDED fields (like password_category)
            for fix in self.fixes:
                if fix['type'] == 'fill_recommended_field':
                    field = fix['field']
                    count = fix['count']
                    
                    print(f"\n  {count} rows have empty recommended field '{field}'.")
                    
                    if field.lower() == 'password_category':
                        print("  Options for default password_category:")
                        for i, cat in enumerate(self.VALID_PASSWORD_CATEGORIES, 1):
                            print(f"    {i}. {cat}")
                        print(f"    {len(self.VALID_PASSWORD_CATEGORIES) + 1}. Skip (leave empty)")
                        
                        choice = input(f"\n  Enter option (1-{len(self.VALID_PASSWORD_CATEGORIES) + 1}, or press Enter for 'General'): ").strip()
                        
                        if choice.isdigit():
                            idx = int(choice) - 1
                            if 0 <= idx < len(self.VALID_PASSWORD_CATEGORIES):
                                fill_defaults[field] = self.VALID_PASSWORD_CATEGORIES[idx]
                            else:
                                fill_defaults[field] = None  # Skip
                        else:
                            fill_defaults[field] = 'General'
                        
                        if fill_defaults.get(field):
                            print(f"  → Will use '{fill_defaults[field]}' for {count} empty password_category fields")
                        else:
                            print(f"  → Will leave password_category fields empty")
            
            # Apply fixes to rows
            for row in rows:
                # Fill empty required/recommended fields with defaults
                for field, default_value in fill_defaults.items():
                    if default_value:
                        # Find the actual field name (case-insensitive)
                        actual_field = None
                        for key in row.keys():
                            if key.lower() == field.lower():
                                actual_field = key
                                break
                        
                        if actual_field:
                            current_value = row.get(actual_field)
                            if current_value is None or (isinstance(current_value, str) and not current_value.strip()):
                                row[actual_field] = default_value
                                fixes_applied.add('empty_fields_filled')
                
                for field in list(row.keys()):
                    value = row.get(field)
                    if value is not None:
                        original_value = value
                        
                        # Convert to string if needed
                        if not isinstance(value, str):
                            value = str(value)
                        
                        # Remove whitespace-only values (make them empty)
                        if value and not value.strip():
                            row[field] = ''
                            fixes_applied.add('whitespace_only_removed')
                            continue
                        
                        # Strip leading/trailing whitespace from all non-empty fields
                        value = value.strip()
                        if value != original_value:
                            fixes_applied.add('whitespace_trimmed')
                        
                        # Remove problematic characters
                        if '\x00' in value:
                            value = value.replace('\x00', '')
                            fixes_applied.add('null_chars_removed')
                        
                        # Replace double line feeds with single
                        if '\r\r' in value:
                            value = value.replace('\r\r', '\r')
                            fixes_applied.add('double_linefeeds_fixed')
                        if '\n\n' in value:
                            value = value.replace('\n\n', '\n')
                            fixes_applied.add('double_linefeeds_fixed')
                        
                        # Remove zero-width and hidden characters
                        zero_width_chars = ['\u200b', '\u200c', '\u200d', '\ufeff']
                        for char in zero_width_chars:
                            if char in value:
                                value = value.replace(char, '')
                                fixes_applied.add('hidden_chars_removed')
                        
                        # Fix URLs with internal spaces (after trimming)
                        # But ONLY if it looks like a real URL (starts with http)
                        if 'url' in field.lower() and ' ' in value:
                            if value.startswith('http://') or value.startswith('https://'):
                                # Real URL with spaces - encode them
                                value = value.replace(' ', '%20')
                                fixes_applied.add('url_spaces_encoded')
                            else:
                                # Doesn't look like a URL - clear it out (user needs to fix manually)
                                # We'll leave it as-is but flag it - the validation will catch it
                                pass
                        
                        # Update the row with fixed value
                        row[field] = value
            
            # Write fixed file without BOM
            with open(output_path, 'wb') as f:
                # Write header
                header_line = ','.join(headers) + '\n'
                f.write(header_line.encode('utf-8'))
                
                # Write rows
                for row in rows:
                    row_values = []
                    for header in headers:
                        value = row.get(header, '')
                        if value is None:
                            value = ''
                        # Escape quotes and wrap in quotes if contains comma, quote, or newline
                        if value and (',' in value or '"' in value or '\n' in value or '\r' in value):
                            value = '"' + value.replace('"', '""') + '"'
                            fixes_applied.add('fields_quoted')
                        row_values.append(value)
                    row_line = ','.join(row_values) + '\n'
                    f.write(row_line.encode('utf-8'))
            
            # Print summary
            print(f"\n✅ Fixed file created: {os.path.basename(output_path)}")
            print(f"   Location: {output_path}")
            print(f"\n   Fixes applied:")
            
            if 'header_case_fixed' in fixes_applied:
                print(f"   • Fixed header case to lowercase")
            if 'columns_added' in fixes_applied:
                print(f"   • Added missing columns: {', '.join(missing_columns)}")
            if 'empty_fields_filled' in fixes_applied:
                filled_info = [f"'{f}' → '{v}'" for f, v in fill_defaults.items() if v]
                if filled_info:
                    print(f"   • Filled empty fields: {', '.join(filled_info)}")
            if 'whitespace_only_removed' in fixes_applied:
                print(f"   • Removed whitespace-only cells (made them empty)")
            if 'null_chars_removed' in fixes_applied:
                print(f"   • Removed NULL characters")
            if 'double_linefeeds_fixed' in fixes_applied:
                print(f"   • Fixed double line feeds (\\n\\n → \\n)")
            if 'fields_quoted' in fixes_applied:
                print(f"   • Properly quoted fields with commas/line breaks")
            if 'whitespace_trimmed' in fixes_applied:
                print(f"   • Trimmed leading/trailing whitespace")
            if 'url_spaces_encoded' in fixes_applied:
                print(f"   • Encoded URL spaces as %20 (only for http/https URLs)")
            if 'hidden_chars_removed' in fixes_applied:
                print(f"   • Removed hidden/zero-width characters")
            
            print(f"   • UTF-8 BOM removed (saved without BOM)")
            
            # Verify the fix worked
            with open(output_path, 'rb') as f:
                first_bytes = f.read(3)
                if first_bytes == b'\xef\xbb\xbf':
                    print(f"\n⚠️  WARNING: BOM still present! Please report this issue.")
                else:
                    print(f"   • Verified: No BOM in output file ✓")
            
            print(f"\n   Next steps:")
            print(f"   1. Review the fixed file: {os.path.basename(output_path)}")
            print(f"   2. MANUALLY FIX any URL fields that contain credentials (marked in validation)")
            print(f"   3. Delete any incomplete rows (only org name filled)")
            print(f"   4. Test import with first 5-10 rows only")
            print(f"   5. If successful, import the full file")
            
        except Exception as e:
            print(f"\n❌ Error creating fixed file: {str(e)}")
            import traceback
            traceback.print_exc()


def get_csv_files(script_dir: Path, provided_path: str = None) -> List[Path]:
    """Get CSV files to validate, prompting user if needed."""
    
    # If a specific file was provided as argument
    if provided_path:
        csv_path = Path(provided_path)
        if csv_path.exists() and csv_path.suffix.lower() == '.csv':
            return [csv_path]
        else:
            print(f"Error: '{provided_path}' is not a valid CSV file.")
            return []
    
    # Look for CSV files in the script directory
    csv_files = list(script_dir.glob('*.csv'))
    
    if csv_files:
        return csv_files
    
    # No CSV files found, prompt user
    print("No CSV files found in the IT Glue folder.")
    print("\nPlease provide the path to your CSV file:")
    print("  1. Enter full path (e.g., C:\\path\\to\\file.csv)")
    print("  2. Drag and drop the file here")
    print("  3. Press Enter to exit")
    
    user_input = input("\nFile path: ").strip().strip('"\'')
    
    if not user_input:
        return []
    
    csv_path = Path(user_input)
    if csv_path.exists() and csv_path.suffix.lower() == '.csv':
        return [csv_path]
    else:
        print(f"\nError: '{user_input}' is not a valid CSV file.")
        return []


def main():
    """Main function to validate CSV files."""
    script_dir = Path(__file__).parent
    
    # Check if filename was provided as command line argument
    provided_path = sys.argv[1] if len(sys.argv) > 1 else None
    
    csv_files = get_csv_files(script_dir, provided_path)
    
    if not csv_files:
        print("\nNo files to validate. Exiting.")
        return
    
    print(f"\nFound {len(csv_files)} CSV file(s) to validate\n")
    
    results = []
    for csv_file in csv_files:
        validator = ITGlueImportValidator(str(csv_file))
        is_valid, errors, warnings = validator.validate()
        results.append((csv_file.name, is_valid, len(errors), len(warnings)))
    
    # Summary
    if len(csv_files) > 1:
        print(f"\n{'='*60}")
        print("VALIDATION SUMMARY")
        print(f"{'='*60}")
        for filename, is_valid, error_count, warning_count in results:
            status = "✅ PASS" if is_valid else "❌ FAIL"
            print(f"{status} | {filename} | Errors: {error_count}, Warnings: {warning_count}")
        print()


if __name__ == "__main__":
    main()