#!/usr/bin/env pwsh

# Zapier MCP Server Bridge Script

# Read input from stdin
$inputData = $input | Out-String

# Create headers
$headers = @{
    "Content-Type" = "application/json"
    "Accept" = "application/json, text/event-stream"
}

# Parse the input to get the JSON object
try {
    $jsonInput = $inputData | ConvertFrom-Json
} catch {
    Write-Error "Invalid JSON input"
    exit 1
}

# Ensure it's a proper JSON-RPC request
if (-not $jsonInput.jsonrpc) {
    $jsonInput | Add-Member -Name "jsonrpc" -Value "2.0" -MemberType NoteProperty
}

# Convert back to JSON
$body = $jsonInput | ConvertTo-Json -Depth 10

# Send the input data to the Zapier MCP server
try {
    $response = Invoke-RestMethod -Uri "https://mcp.zapier.com/api/mcp/s/NDc0NGUxZmQtNjZmMi00NGRjLWJjZDEtN2ZlYzZlMDhlZjI2OmY4M2U3ZTRlLTA4OTQtNGM3OS05MTM4LWQxOTY1MTFmM2EzMg==/mcp" -Method Post -Body $body -Headers $headers
    # Output the response
    $response | ConvertTo-Json -Depth 10 -Compress
} catch {
    Write-Error "Error calling Zapier MCP server: $($_.Exception.Message)"
}