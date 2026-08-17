import os
import json
import re
from datetime import datetime, timezone, timedelta

p_history = r"c:\Users\fragi\Videos\PalengkeGoAPP\docs\archive\compiled_history.md"
p_changelog = r"c:\Users\fragi\Videos\PalengkeGoAPP\CHANGELOG.md"

print("Reading compiled history to extract changelog entries by date...")

# Map of date -> list of session details
daily_entries = {}

current_date = None
current_session_id = None
current_role = None
current_text = []

def parse_date_from_heading(line):
    # e.g., Timestamp / Date: May 27, 2026 at 01:00:11 AM PHT
    m = re.search(r'\*\*Timestamp / Date:\*\*\s*([A-Za-z]+\s+\d+,\s+\d{4})', line)
    if m:
        return m.group(1).strip()
    return None

with open(p_history, "r", encoding="utf-8", errors="ignore") as f:
    for line in f:
        if line.startswith("### Session "):
            # New session
            m_id = re.search(r'`([^`]+)`', line)
            if m_id:
                current_session_id = m_id.group(1)
        elif line.startswith("   **Timestamp / Date:**"):
            d = parse_date_from_heading(line)
            if d:
                current_date = d
                if current_date not in daily_entries:
                    daily_entries[current_date] = []

print("Dates found in history:")
for d in daily_entries.keys():
    print(" -", d)
