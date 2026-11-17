"""Require Apple's explicit validation/upload success, even if altool exits zero."""
import os
import plistlib
import subprocess
import sys


def success_response(output):
    start = output.find('<?xml')
    end = output.find('</plist>', start)
    if start < 0 or end < 0:
        raise ValueError('Apple returned no structured result')
    result = plistlib.loads(output[start:end + len('</plist>')].encode())
    if not result.get('success-message') or result.get('product-errors'):
        raise ValueError('Apple did not confirm success')
    return result['success-message']


def main():
    for operation in ('--validate-app', '--upload-app'):
        result = subprocess.run([
            'xcrun', 'altool', operation, '-f', sys.argv[1], '-t', 'ios',
            '--apiKey', os.environ['API_KEY_ID'],
            '--apiIssuer', os.environ['API_ISSUER_ID'],
            '--output-format', 'xml',
        ], capture_output=True, text=True)
        output = result.stdout + '\n' + result.stderr
        print(output, flush=True)
        if result.returncode:
            raise SystemExit('Apple command failed: ' + operation)
        try:
            message = success_response(output)
        except (ValueError, plistlib.InvalidFileException) as error:
            raise SystemExit(f'{operation}: {error}') from error
        print('APPLE_CONFIRMED', operation, message, flush=True)


if __name__ == '__main__':
    main()
