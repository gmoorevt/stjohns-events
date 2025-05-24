import os
from dotenv import load_dotenv, find_dotenv
import aiohttp
import asyncio
import json

# Print current working directory and .env file location
print(f"\nCurrent working directory: {os.getcwd()}")
env_path = find_dotenv()
print(f"Looking for .env file at: {env_path}")

# Load environment variables
load_dotenv()

# Get credentials from environment
EVENTBRITE_API_KEY = os.getenv("EVENTBRITE_API_KEY")
EVENTBRITE_OAUTH_TOKEN = os.getenv("EVENTBRITE_OAUTH_TOKEN")
EVENTBRITE_ORG_ID = os.getenv("EVENTBRITE_ORG_ID")
EVENT_ID = "1367969235809"  # Your event ID

# Print all environment variables (masking sensitive values)
print("\nEnvironment Variables:")
print("EVENTBRITE_API_KEY:", "✓" if EVENTBRITE_API_KEY else "✗", f"({len(EVENTBRITE_API_KEY) if EVENTBRITE_API_KEY else 0} chars)")
print("EVENTBRITE_OAUTH_TOKEN:", "✓" if EVENTBRITE_OAUTH_TOKEN else "✗", f"({len(EVENTBRITE_OAUTH_TOKEN) if EVENTBRITE_OAUTH_TOKEN else 0} chars)")
print("EVENTBRITE_ORG_ID:", "✓" if EVENTBRITE_ORG_ID else "✗", f"({EVENTBRITE_ORG_ID if EVENTBRITE_ORG_ID else 'not set'})")

async def test_credentials():
    print("\n=== Testing Eventbrite Credentials ===")
    print(f"API Key present: {bool(EVENTBRITE_API_KEY)}")
    print(f"OAuth Token present: {bool(EVENTBRITE_OAUTH_TOKEN)}")
    print(f"Organization ID present: {bool(EVENTBRITE_ORG_ID)}")
    
    if not EVENTBRITE_API_KEY or not EVENTBRITE_OAUTH_TOKEN:
        print("\n❌ Error: Missing required credentials")
        print("Please ensure EVENTBRITE_API_KEY and EVENTBRITE_OAUTH_TOKEN are set in your .env file")
        return False
    
    # Test the API by fetching event details
    url = f"https://www.eventbriteapi.com/v3/events/{EVENT_ID}"
    headers = {
        "Authorization": f"Bearer {EVENTBRITE_OAUTH_TOKEN}",
        "Accept": "application/json"
    }
    
    try:
        print("\nTesting API connection...")
        async with aiohttp.ClientSession() as session:
            async with session.get(url, headers=headers) as resp:
                if resp.status == 200:
                    data = await resp.json()
                    print("\n✅ Successfully connected to Eventbrite API!")
                    print(f"\nEvent Details:")
                    print(f"Name: {data.get('name', {}).get('text', 'N/A')}")
                    print(f"Status: {data.get('status', 'N/A')}")
                    print(f"Start: {data.get('start', {}).get('local', 'N/A')}")
                    print(f"URL: {data.get('url', 'N/A')}")
                    return True
                else:
                    error_text = await resp.text()
                    print(f"\n❌ API Error: {resp.status}")
                    print(f"Response: {error_text}")
                    return False
    except Exception as e:
        print(f"\n❌ Error connecting to Eventbrite API: {str(e)}")
        return False

if __name__ == "__main__":
    success = asyncio.run(test_credentials())
    if not success:
        print("\nPlease check your credentials and try again.")
        exit(1) 