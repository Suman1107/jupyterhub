# Test Employee API with KMS-Encrypted Token
# Run this in a JupyterHub notebook

# Step 1: Install dependencies
import subprocess
import sys

print("Installing dependencies...")
subprocess.check_call([sys.executable, "-m", "pip", "install", "-q", "google-cloud-kms", "requests"])
print("✅ Dependencies installed\n")

# Step 2: Import the API consumer
import sys
sys.path.append('/home/jovyan')

from api_consumer import SecureAPIClient, test_api_access

# Step 3: Your encrypted token (from the token generator)
ENCRYPTED_TOKEN = "CiQAJKndERiJxxc7vkU6rKTiGGI0XQLWVVzHTBxT1hDVMIk/nfASywEAU2A72+3tdAgvA6za3kD/bVFHSUisXJlzY24ojPELNSfXI4jWPTGMbYxWpJr/tRhIpiyu48ME/AvKFaEpmiJIckBrSYwWD3v90SzAKoDouoS7FoOHzjffoCWDXR+aE0lKWlhDCTuBD2U7b1XK8Vig7l3j4JqQq61e5gtwJwjrT8MiINsB+cModr1sU1KXAeJ+qHcmaHtC36mkk9OztfDqKOLFScZh7AHAp4E94BsZvFHPNtLZ+lcvfNhsT+3KEy+jOx3XzjCseNbyvw=="

# Step 4: Test the API access
print("=" * 60)
print("Testing Secure API Access with KMS-Encrypted Token")
print("=" * 60)
print()

try:
    # Create client (this will decrypt the token using KMS)
    client = SecureAPIClient(ENCRYPTED_TOKEN)
    
    print("\n📊 Fetching employees from API...")
    employees = client.get_employees()
    
    if employees:
        print(f"✅ Retrieved {len(employees)} employees")
        for emp in employees:
            print(f"  - {emp['first_name']} {emp['last_name']} ({emp['department']})")
    else:
        print("No employees found. Let's create one!")
        
        # Create a test employee
        new_emp = client.create_employee({
            "first_name": "Alice",
            "last_name": "Johnson",
            "email": "alice.johnson@example.com",
            "department": "Data Science",
            "position": "Data Scientist",
            "salary": 95000
        })
        print(f"\n✅ Created employee: {new_emp['first_name']} {new_emp['last_name']}")
        print(f"   Employee ID: {new_emp['employee_id']}")
    
    print("\n" + "=" * 60)
    print("✅ Complete flow working!")
    print("=" * 60)
    print("\n🎉 Success! You can now:")
    print("  1. Fetch employees: client.get_employees()")
    print("  2. Get employee by ID: client.get_employee(1)")
    print("  3. Create employee: client.create_employee({...})")
    
except Exception as e:
    print(f"\n❌ Error: {str(e)}")
    import traceback
    traceback.print_exc()
