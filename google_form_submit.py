"""
Submit responses to a Google Form you own (for testing / your own forms only).

SETUP:
1. Open your form in "Preview" mode (click the eye icon or "Send" -> link without /edit).
2. Open browser DevTools (F12) -> Network tab.
3. Submit the form once manually and find the "formResponse" request.
   - The request URL is your FORM_RESPONSE_URL.
   - Request payload or Form Data shows entry IDs (e.g. entry.123456789 = "Answer").
4. Or: Right-click form -> "View Page Source", search for "entry." to find entry IDs.
5. Fill in FORM_RESPONSE_URL and ENTRIES below.

Multi-section forms: Google often only submits one section per request. You may need
to call submit_form() once per section or use the form's "Continue" flow.
"""

import requests

# --- CONFIG: Replace with your form's values ---
# Full URL to which the form is submitted (ends with /formResponse)
FORM_RESPONSE_URL = "https://docs.google.com/forms/d/e/YOUR_FORM_ID/formResponse"

# Map each question's entry ID (number only) to the value to submit.
# Get entry IDs from form HTML (search for "name=\"entry.XXXXX\"") or Network tab.
# Example: {"123456789": "My School", "987654321": "Grade 1"}
ENTRIES = {
    # "entry_id": "value",
}

# Optional: custom User-Agent (some forms block default scripts)
HEADERS = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
    "Referer": FORM_RESPONSE_URL.replace("/formResponse", "/viewform"),
}


def submit_form(entries: dict) -> bool:
    """Submit one response to the form. Returns True if submission was accepted."""
    if not FORM_RESPONSE_URL or "YOUR_FORM_ID" in FORM_RESPONSE_URL:
        print("Error: Set FORM_RESPONSE_URL to your form's submit URL.")
        return False
    if not entries:
        print("Error: ENTRIES is empty. Add entry IDs and values.")
        return False

    payload = {f"entry.{eid}": str(val) for eid, val in entries.items()}
    # Required for some forms
    payload["draftResponse"] = "[]"
    payload["pageHistory"] = "0"

    try:
        r = requests.post(
            FORM_RESPONSE_URL,
            data=payload,
            headers=HEADERS,
            timeout=10,
        )
        # Google often returns 200 even on success; no response body
        if r.status_code == 200:
            print("Submission sent (status 200). Check your form responses.")
            return True
        print(f"Unexpected status: {r.status_code}")
        return False
    except Exception as e:
        print(f"Request failed: {e}")
        return False


if __name__ == "__main__":
    if not ENTRIES:
        print("Edit this script: set FORM_RESPONSE_URL and fill ENTRIES with your form's entry IDs and values.")
        exit(1)
    submit_form(ENTRIES)
