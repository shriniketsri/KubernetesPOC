import sys
import requests
import os

def health_check():
    try:
        port = os.getenv('PORT', '3002')
        response = requests.get(f'http://localhost:{port}/health', timeout=2)
        if response.status_code == 200:
            sys.exit(0)
        else:
            sys.exit(1)
    except Exception:
        sys.exit(1)

if __name__ == '__main__':
    health_check()