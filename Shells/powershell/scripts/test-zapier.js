const https = require('https');

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
    let data = '';
    
    res.on('data', (chunk) => {
      data += chunk;
    });

    res.on('end', () => {
      console.log('Response from Zapier MCP server:');
      console.log(data);
    });
  });

  req.on('error', (error) => {
    console.error('Error:', error);
  });

  req.write(data);
  req.end();
}

// Send a tools/list request to the Zapier MCP server
const requestData = JSON.stringify({
  jsonrpc: "2.0",
  method: "tools/list",
  id: 1
});

console.log('Sending request to Zapier MCP server...');
sendToZapier(requestData);