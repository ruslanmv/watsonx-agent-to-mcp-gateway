# tests/test_server.py
import os
from dotenv import load_dotenv
import server

# Load environment variables from .env
load_dotenv()

if __name__ == "__main__":
    query = "What is IBM Cloud?"
    print(f"▶ Sending query: {query}\n")
    try:
        response = server.chat(query)
        print(f"💬 Response: {response}")
    except Exception as e:
        print(f"❌ Error during chat(): {e}")
