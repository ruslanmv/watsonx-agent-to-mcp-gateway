# test/test_server.py
import sys
import os
from pathlib import Path

# Ensure project root is on PYTHONPATH
PROJECT_ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(PROJECT_ROOT))

from dotenv import load_dotenv
import server

# Load environment variables from .env at project root
load_dotenv(dotenv_path=PROJECT_ROOT / '.env')

if __name__ == "__main__":
    query = "What is IBM Cloud?"
    print(f"▶ Sending query: {query}\n")
    try:
        response = server.chat(query)
        print(f"💬 Response: {response}")
    except Exception as e:
        print(f"❌ Error during chat(): {e}")