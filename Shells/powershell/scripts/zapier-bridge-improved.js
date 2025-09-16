const https = require('https');
const readline = require('readline');

// Create a readline interface to read from stdin
const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout,
  terminal: false
});

let responseBuffer = '';

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
      // Process the response chunk
      const chunkStr = chunk.toString();
      responseBuffer += chunkStr;
      
      // Check if we have a complete message
      if (responseBuffer.includes('\n\n')) {
        // Send the complete message to stdout
        process.stdout.write(responseBuffer);
        responseBuffer = '';
      }
    });

    res.on('end', () => {
      // Send any remaining data in the buffer
      if (responseBuffer) {
        process.stdout.write(responseBuffer);
        responseBuffer = '';
      }
    });
  });

  req.on('error', (error) => {
    console.error('Error:', error);
  });

  req.write(data);
  req.end();
}

// Read from stdin and send to Zapier
rl.on('line', (input) => {
  sendToZapier(input);
});