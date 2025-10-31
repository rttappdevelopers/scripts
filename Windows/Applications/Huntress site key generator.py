#!/usr/bin/env python3
import re
import sys
import argparse

def create_huntress_key(client_name):
    """
    Formats a client name into a Huntress-style org key.
    - Converts to lowercase
    - Finds all alphanumeric "words"
    - Joins them with a single hyphen
    """
    # Find all sequences of letters and numbers
    words = re.findall(r'\w+', client_name.lower())
    
    # Join all found words with a single hyphen
    org_key = '-'.join(words)
    
    return org_key

def process_lines(input_stream):
    """
    Reads from the given stream (file or stdin), processes each line,
    and prints the resulting key.
    """
    for line in input_stream:
        name = line.strip()
        if name:  # Skip any blank lines
            key = create_huntress_key(name)
            print(key)

def main():
    """
    Main function to parse arguments and decide the input source.
    """
    parser = argparse.ArgumentParser(
        description="Converts a list of client names into Huntress-style org keys.",
        epilog="If no file is specified, it reads from standard input (stdin)."
    )
    
    # 'nargs='?' means the argument is optional (0 or 1).
    # 'type=argparse.FileType('r')' is great: it handles opening the file
    # or defaulting to sys.stdin for us.
    parser.add_argument(
        'input_file',
        nargs='?',
        type=argparse.FileType('r'),
        default=sys.stdin,
        help='A file containing client names, one per line. Reads from stdin if omitted.'
    )
    
    args = parser.parse_args()
    
    # On Windows, you might need this for stdin to work correctly with Ctrl+Z
    if args.input_file is sys.stdin and sys.platform == "win32":
        import msvcrt
        msvcrt.setmode(sys.stdin.fileno(), 0x8000) # O_BINARY

    # args.input_file is now an open file handle, either to your file or to sys.stdin
    # We use 'with' to ensure it's closed automatically
    with args.input_file as f:
        if f is sys.stdin and f.isatty():
            # If we are in an interactive TTY, print a helper message.
            # f.isatty() is false when piping (e.g., cat file | script)
            print("Type or paste list of names.", file=sys.stderr)
            print("Press Ctrl+D (Linux/macOS) or Ctrl+Z+Enter (Windows) to finish.", file=sys.stderr)
        
        process_lines(f)

if __name__ == "__main__":
    main()