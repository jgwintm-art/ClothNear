#!/usr/bin/env python3
"""
Writes lib/config/api_secrets.dart from environment variables (CI).

PayMongo secret key is intentionally NOT written here — it lives in
Firebase Secret Manager and is accessed server-side only (Cloud Functions).
The Flutter bundle only needs GEMINI_API_KEY.
"""
import json
import os
from pathlib import Path

key = os.environ.get("GEMINI_API_KEY", "").strip()
paymongo_key = os.environ.get("PAYMONGO_SECRET_KEY", "").strip()

if not key:
    raise SystemExit("GEMINI_API_KEY environment variable is empty")


out = Path(__file__).resolve().parents[1] / "lib" / "config" / "api_secrets.dart"
out.write_text(
    f"""
abstract class ApiSecrets {{
  static const String geminiApiKey = {json.dumps(key)};
  static const String geminiModel = 'gemini-2.5-flash';
  static const String paymongoSecretKey = '';
}}
""",
    encoding="utf-8",
)

print(f"api_secrets.dart written (PayMongo key kept server-side: {not bool(paymongo_key)})")
