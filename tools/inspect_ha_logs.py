import urllib.request
import sys

sys.stdout.reconfigure(encoding='utf-8')

with open('d:/Git_Repositories/HaSSD06/.ha_token', 'r', encoding='utf-8') as f:
    token = f.read().strip()

url = 'http://192.168.10.6:8123/api/error_log'
req = urllib.request.Request(url, headers={'Authorization': 'Bearer ' + token, 'Content-Type': 'text/plain'})

try:
    with urllib.request.urlopen(req, timeout=12) as resp:
        log_text = resp.read().decode('utf-8', errors='replace')
        print(f"=== HA SYSTEM ERROR LOG ({len(log_text.splitlines())} lines) ===")
        lines = log_text.splitlines()
        
        # Look for rpi, gpio, fan, srat, and general errors
        matched_lines = []
        for i, line in enumerate(lines):
            if any(k in line.lower() for k in ['gpio', 'rpi', 'fan', 'srat', 'acpi', 'raspberry', 'pwm', 'custom_components']):
                # Grab a few context lines before and after
                start = max(0, i - 2)
                end = min(len(lines), i + 4)
                matched_lines.extend(lines[start:end])
                matched_lines.append("---")
        
        if matched_lines:
            print("\n".join(matched_lines[:150]))
        else:
            print("[+] No direct matches for keywords in error_log. Showing last 50 lines of log:")
            print("\n".join(lines[-50:]))
            
        with open('ha_error_log.txt', 'w', encoding='utf-8') as lf:
            lf.write(log_text)
        print("\n[+] Full raw log saved to 'HaSSD06/ha_error_log.txt'")

except Exception as e:
    print(f"[-] Error fetching log: {e}")
