const https = require('https');
const readline = require('readline');

// Create a readline interface to read from stdin
const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout,
  terminal: false
});

// Keep track of whether we've sent the initialize message
let initialized = false;

// Function to send request to Zapier MCP server
function sendToZapier(data) {
  const options = {
    hostname: 'mcp.zapier.com',
    port: 443,
    path: '/api/mcp/s/NDc0NGUxZmQtNjZmMi00NGRjLWJjZDEtN2ZlYzZlMDhlZjI2OmY4M2U3ZTRlLTA4OTQtNGM3OS05MTM4LWQxOTY1MTFmM2EzMg==/mcp',
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Accept': 'application/json,text/event-stream'
    }
  };

  const req = https.request(options, (res) => {
    res.on('data', (chunk) => {
      process.stdout.write(chunk);
    });

    res.on('end', () => {
      // Send a newline to indicate end of response
      process.stdout.write('\n');
    });
  });

  req.on('error', (error) => {
    console.error('Error:', error);
  });

  req.write(data);
  req.end();
}

// Send initialization message
function sendInitialize() {
  if (!initialized) {
    const initMessage = JSON.stringify({
      jsonrpc: "2.0",
      method: "initialize",
      params: {
        protocolVersion: "2024-01-01",
        capabilities: {}
      },
      id: 1
    });
    
    sendToZapier(initMessage);
    initialized = true;
  }
}

// Send initialization message when the script starts
sendInitialize();

// Read from stdin and send to Zapier
rl.on('line', (input) => {
  // If this is the first message after initialization, it might be a ping
  // Let's just forward all messages to the Zapier server
  sendToZapier(input);
});