import sys
import json
import requests

# URL for the Zapier MCP server
ZAPIER_MCP_URL = "https://mcp.zapier.com/api/mcp/s/NDc0NGUxZmQtNjZmMi00NGRjLWJjZDEtN2ZlYzZlMDhlZjI2OmY4M2U3ZTRlLTA4OTQtNGM3OS05MTM4LWQxOTY1MTFmM2EzMg==/mcp"

def send_to_zapier(data):
    headers = {
        "Content-Type": "application/json",
        "Accept": "application/json,text/event-stream"
    }
    
    try:
        response = requests.post(ZAPIER_MCP_URL, data=data, headers=headers, stream=True)
        for line in response.iter_lines():
            if line:
                sys.stdout.write(line.decode('utf-8') + '\n')
                sys.stdout.flush()
    except Exception as e:
        sys.stderr.write(f"Error: {str(e)}\n")
        sys.stderr.flush()

if __name__ == "__main__":
    for line in sys.stdin:
        send_to_zapier(line)