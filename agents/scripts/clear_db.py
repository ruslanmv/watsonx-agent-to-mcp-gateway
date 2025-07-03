#!/usr/bin/env python3
"""
clear_db.py

A simple script to wipe the entire MCP Gateway SQLite database (mcp.db).
Use this before re-registering agents to start from a clean slate.
"""
import os
from sqlalchemy import create_engine, MetaData

# Path to your MCP Gateway SQLite database file
DB_PATH = os.getenv('MCP_DB_PATH', 'mcp.db')

def clear_database(db_path: str):
    """
    Reflects all tables in the SQLite database and drops them.
    """
    engine = create_engine(f"sqlite:///{db_path}")
    metadata = MetaData()
    # Reflect existing tables
    metadata.reflect(bind=engine)
    if not metadata.tables:
        print(f"No tables found in {db_path}. Nothing to do.")
        return

    # Drop all tables
    metadata.drop_all(bind=engine)
    print(f"Dropped {len(metadata.tables)} tables from {db_path}.")

if __name__ == '__main__':
    if not os.path.isfile(DB_PATH):
        print(f"Database file '{DB_PATH}' does not exist.")
        exit(1)

    clear_database(DB_PATH)
    print("Database cleared. You can now reinitialize or add new agents.")
