# JupyterHub Database Test - Two Cell Version

## Cell 1: Install Dependencies
Run this cell first and wait for it to complete:

```python
import subprocess
import sys

print("Installing psycopg2-binary...")
subprocess.check_call([sys.executable, "-m", "pip", "install", "psycopg2-binary"])
print("✅ Installation complete! Now run Cell 2.")
```

## Cell 2: Test Database Connection
After Cell 1 completes, run this cell:

```python
import psycopg2
from datetime import datetime

# Database configuration
DB_HOST = "127.0.0.1"
DB_PORT = "5432"
DB_NAME = "jupyterhub_db"
DB_USER = "jupyter-user-sa@suman-110797.iam"

def test_database_connection():
    """Test connection to Cloud SQL database"""
    print(f"Connecting to database: {DB_NAME}")
    print(f"Using IAM user: {DB_USER}")
    print("-" * 60)
    
    try:
        # Connect to database
        conn = psycopg2.connect(
            host=DB_HOST,
            port=DB_PORT,
            database=DB_NAME,
            user=DB_USER,
            password="ignored-by-proxy",
            sslmode='disable'
        )
        conn.autocommit = True
        print("✅ Connected successfully!")
        
        cur = conn.cursor()
        
        # Create table if it doesn't exist
        print("\n📝 Creating table 'test_data' (if not exists)...")
        cur.execute("""
            CREATE TABLE IF NOT EXISTS test_data (
                id SERIAL PRIMARY KEY,
                message TEXT,
                created_at TIMESTAMP DEFAULT NOW()
            )
        """)
        print("✅ Table ready!")
        
        # Insert test data
        test_message = f"Hello from JupyterHub user at {datetime.now()}"
        print(f"\n💾 Inserting data: '{test_message}'")
        cur.execute("INSERT INTO test_data (message) VALUES (%s)", (test_message,))
        print("✅ Data inserted!")
        
        # Fetch and display recent data
        print("\n📊 Fetching last 5 records:")
        cur.execute("SELECT * FROM test_data ORDER BY id DESC LIMIT 5")
        rows = cur.fetchall()
        
        print("-" * 60)
        for row in rows:
            print(f"ID: {row[0]}, Message: {row[1]}, Created: {row[2]}")
        print("-" * 60)
        
        # Get total count
        cur.execute("SELECT COUNT(*) FROM test_data")
        count = cur.fetchone()[0]
        print(f"\n📈 Total records in database: {count}")
        
        cur.close()
        conn.close()
        print("\n✅ Test completed successfully!")
        print("\n🎉 Your JupyterHub can now connect to Cloud SQL PostgreSQL!")
        
    except Exception as e:
        print(f"\n❌ Error: {e}")
        import traceback
        traceback.print_exc()
        raise

# Run the test
test_database_connection()
```

## Alternative: Single Cell with Kernel Restart

If you prefer a single cell, use this (requires kernel restart):

```python
import subprocess
import sys

# Install package
subprocess.check_call([sys.executable, "-m", "pip", "install", "psycopg2-binary"])

# Restart kernel to pick up new package
print("⚠️ Please restart the kernel (Kernel -> Restart) and then run the Cell 2 code above.")
```
