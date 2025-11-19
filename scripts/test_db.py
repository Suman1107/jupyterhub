import os
import time
import requests
import sys
import subprocess

try:
    import psycopg2
except ImportError:
    print("Installing psycopg2-binary...")
    subprocess.check_call([sys.executable, "-m", "pip", "install", "psycopg2-binary"])
    import psycopg2

# Configuration
DB_HOST = "127.0.0.1"
DB_PORT = "5432"
DB_NAME = "jupyterhub_db"

def test_db(db_user):
    # Token is handled by Cloud SQL Proxy with --auto-iam-authn
    # We just need to provide the correct DB user
    
    print(f"Connecting to {DB_NAME} as {db_user}...")
    try:
        conn = psycopg2.connect(
            host=DB_HOST,
            port=DB_PORT,
            database=DB_NAME,
            user=db_user,
            password="password-is-ignored-by-proxy",
            sslmode='disable' # Proxy handles encryption
        )
        conn.autocommit = True
        print("Connected!")
        
        cur = conn.cursor()
        
        # Create table
        print("Creating table 'test_data'...")
        cur.execute("CREATE TABLE IF NOT EXISTS test_data (id SERIAL PRIMARY KEY, message TEXT, created_at TIMESTAMP DEFAULT NOW())")
        
        # Insert data
        print("Inserting dummy data...")
        cur.execute("INSERT INTO test_data (message) VALUES ('Hello from JupyterHub!')")
        
        # Fetch data
        print("Fetching data...")
        cur.execute("SELECT * FROM test_data ORDER BY id DESC LIMIT 5")
        rows = cur.fetchall()
        for row in rows:
            print(row)
            
        cur.close()
        conn.close()
        print("Test completed successfully!")
        
    except Exception as e:
        print(f"Error: {e}")
        raise

if __name__ == "__main__":
    import sys
    if len(sys.argv) < 2:
        print("Usage: python test_db.py <db_user>")
        sys.exit(1)
    
    db_user = sys.argv[1]
    test_db(db_user)
