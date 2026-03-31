#!/bin/env python3
# Scan a list of domains supplied by an input file named domainlist.txt and check for MX, SPF, DMARC, and DKIM records; note any domains that are missing any one of these records
# Prerequisite: dnspython, install it with pip install dnspython
# Hide deprecation warnings
import warnings
warnings.filterwarnings('ignore', category=DeprecationWarning)

import dns.resolver
import os
import sys

sourcefile='domainlist.txt'

# Open the file containing the list of domains
# Check for sourcefile and error out if it is missing or empty with a message stating the file is needed
if not os.path.isfile(sourcefile):
    print(f'{sourcefile} is missing')
    sys.exit(1)
elif os.stat(sourcefile).st_size == 0:
    print(f'{sourcefile} is empty')
    sys.exit(1)

with open(sourcefile) as f:
    domains = f.read().splitlines()

# Create a list of domains that are missing any one of the records
missing_records = []

# Loop through the list of domains

with open('domainreport.txt', 'w') as report:
    for domain in domains:
        # Check for MX records
        try:
            mx_records = dns.resolver.query(domain, 'MX')
        except dns.resolver.NXDOMAIN:
            print(f'{domain} has no MX records', file=report)
            print(f'{domain} has no MX records')
            continue
        except dns.resolver.NoAnswer:
            print(f'{domain} has no MX records', file=report)
            print(f'{domain} has no MX records')
            missing_records.append(domain)
            continue
        except dns.resolver.NoNameservers:
            print(f'{domain} has no nameservers', file=report)
            print(f'{domain} has no nameservers')
            continue
        except dns.exception.Timeout:
            print(f'{domain} has timed out', file=report)
            print(f'{domain} has timed out')
            continue
        else:
            print(f'{domain} has MX records', file=report)
            print(f'{domain} has MX records')

        # Check for SPF records
        try:
            spf_records = dns.resolver.query(domain, 'TXT')
        except dns.resolver.NXDOMAIN:
            print(f'{domain} has no SPF records', file=report)
            print(f'{domain} has no SPF records')
            continue
        except dns.resolver.NoAnswer:
            print(f'{domain} has no SPF records', file=report)
            print(f'{domain} has no SPF records')
            missing_records.append(domain)
            continue
        except dns.resolver.NoNameservers:
            print(f'{domain} has no nameservers', file=report)
            print(f'{domain} has no nameservers')
            continue
        except dns.exception.Timeout:
            print(f'{domain} has timed out', file=report)
            print(f'{domain} has timed out')
            continue
        else:
            print(f'{domain} has SPF records', file=report)
            print(f'{domain} has SPF records')

        # Check for DMARC records
        try:
            dmarc_records = dns.resolver.query('_dmarc.' + domain, 'TXT')
        except dns.resolver.NXDOMAIN:
            print(f'{domain} has no DMARC records', file=report)
            print(f'{domain} has no DMARC records')
            continue
        except dns.resolver.NoAnswer:
            print(f'{domain} has no DMARC records', file=report)
            print(f'{domain} has no DMARC records')
            missing_records.append(domain)
            continue
        except dns.resolver.NoNameservers:
            print(f'{domain} has no nameservers', file=report)
            print(f'{domain} has no nameservers')
            continue
        except dns.exception.Timeout:
            print(f'{domain} has timed out', file=report)
            print(f'{domain} has timed out')
            continue
        else:
            print(f'{domain} has DMARC records', file=report)
            print(f'{domain} has DMARC records')

        # Check for DKIM records
        dkim_found = False
        selectors = ['s1', 's2', 'k1', 'k2', 'selector1', 'selector2']
        for selector in selectors:
            try:
                dkim_records = dns.resolver.query(f'{selector}._domainkey.{domain}', 'TXT')
            except dns.resolver.NXDOMAIN:
                continue
            except dns.resolver.NoAnswer:
                continue
            except dns.resolver.NoNameservers:
                continue
            except dns.exception.Timeout:
                continue
            else:
                dkim_found = True
                print(f'{domain} has DKIM records for {selector}', file=report)
                print(f'{domain} has DKIM records for {selector}')
        if not dkim_found:
            print(f'{domain} has no DKIM records', file=report)
            print(f'{domain} has no DKIM records')
            missing_records.append(domain)
            continue

    # Print the list of domains that are missing any one of the records
    print(f'\nDomains missing records:\n{missing_records}', file=report)
    print(f'\nDomains missing records:\n{missing_records}')

# Exit the program
