#!/bin/bash

# TodoNotes Docker One-Liner Runner
echo "🚀 TodoNotes Docker One-Liner Setup & Run"
echo "========================================"

# Stop any existing container
echo "🛑 Stopping any existing TodoNotes containers..."
docker stop todonotes 2>/dev/null || true
docker rm todonotes 2>/dev/null || true

# Build the image
echo "🏗️  Building TodoNotes Docker image..."
docker build -t todonotes .

# Run the container
echo "🚀 Starting TodoNotes container..."
docker run -d \
  --name todonotes \
  -p 7777:7777 \
  -v "$(pwd)/backend/uploads:/app/backend/uploads" \
  -v "$(pwd)/backend/logs:/app/backend/logs" \
  todonotes

# Show the logs with URL info
echo "📋 Container started! Showing startup logs..."
sleep 2
docker logs todonotes

echo ""
echo "🎉 TodoNotes is now running!"
echo "🌐 Open your browser to: http://localhost:7777"
echo ""
echo "🔧 Management commands:"
echo "   • Stop: docker stop todonotes"
echo "   • View logs: docker logs -f todonotes" 
echo "   • Restart: docker restart todonotes"
echo "   • Remove: docker rm todonotes"