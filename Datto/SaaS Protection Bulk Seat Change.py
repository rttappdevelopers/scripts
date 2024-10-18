#! /bin/env python3
# Leverage Datto SaaS Protection API to bulk change settings for multiple organizations
# Reference: https://portal.dattobackup.com/integrations/api

import os
try:
    import requests
except ImportError:
    import os
    os.system('pip install requests')
    import requests
from urllib.parse import urlparse, parse_qs

# Ask user to input the API key
api_pubkey = input('Enter your Datto API public key: ')
api_privkey = input('Enter your Datto API private key: ')

if not api_pubkey or not api_privkey:
    raise ValueError("API keys are required")

# Ask user to input URL of the customer dashboard page in Datto SaaS Protection
input_url = input('Enter the URL of the customer dashboard page in Datto SaaS Protection: ')

# Extract the saasCustomerId and externalSubscriptionId from the URL
parsed_url = urlparse(input_url)
path_parts = parsed_url.path.split('/')
query_params = parse_qs(parsed_url.query)

saasCustomerId = path_parts[1] if len(path_parts) > 1 else None
externalSubscriptionId = query_params.get('external_customer_id', [None])[0]

if not saasCustomerId or not externalSubscriptionId:
    raise ValueError("Invalid URL format")

# Display the saasCustomerId and externalSubscriptionId
print(f'saasCustomerId: {saasCustomerId}')
print(f'externalSubscriptionId: {externalSubscriptionId}')

# Set the URL for the API
url = f'https://api.datto.com/v1/saas/{saasCustomerId}/{externalSubscriptionId}/bulkSeatChange'

# Set the headers
headers = {
    'Content-Type': 'application/json', 
    'x-api-key': api_pubkey,
    'x-api-secret': api_privkey
}

# Get comma separated list of seats to change
seats = input('Enter the seats to change separated by commas: ')
seat_ids = [seat.strip() for seat in seats.split(',')]

# Request action from list: license, unlicense, pause
action = input('Enter the action to perform (license, unlicense, pause): ')

# Set the payload
payload = {
    'seat_type': 'user',
    'action_type': action,
    'ids': seat_ids
}

# Example of making a request (uncomment to use)
response = requests.put(url, headers=headers, json=payload)

# Check if the response is valid JSON
try:
    response_json = response.json()
    print(response_json)
except requests.exceptions.JSONDecodeError as e:
    print(f"Failed to decode JSON response: {response.text}")
    print(f"Error: {str(e)}")