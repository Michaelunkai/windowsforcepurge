# Use an official Python runtime as a parent image
FROM python:3.9-slim

# Set the working directory in the container
WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    gcc \
    && rm -rf /var/lib/apt/lists/*

# Copy the requirements file and install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy the rest of the application code
COPY . .

# Create necessary directories
RUN mkdir -p /app/backend/uploads \
    && mkdir -p /app/backend/logs \
    && mkdir -p /app/app/static/uploads \
    && mkdir -p /app/app/static/css \
    && mkdir -p /app/app/static/js \
    && mkdir -p /app/app/templates

# Create startup script
RUN echo '#!/bin/bash\n\
echo "🚀 TodoNotes - Beautiful Task & Note Management"\n\
echo "=" | tr -d "\\n"; for i in {1..50}; do echo -n "="; done; echo\n\
echo "🔥 Starting TodoNotes server..."\n\
echo "🌐 Application will be available at: http://localhost:7777"\n\
echo "📱 Dashboard: http://localhost:7777"\n\
echo "📝 Tasks: http://localhost:7777/tasks"\n\
echo "📒 Notes: http://localhost:7777/notes"\n\
echo "=" | tr -d "\\n"; for i in {1..50}; do echo -n "="; done; echo\n\
echo "✅ Server is starting... Please wait a moment for full startup!"\n\
echo "🎯 Open your browser and navigate to: http://localhost:7777"\n\
echo "=" | tr -d "\\n"; for i in {1..50}; do echo -n "="; done; echo\n\
\n\
# Start the application\n\
exec uvicorn app.main:app --host 0.0.0.0 --port 7777\n\
' > /app/start.sh && chmod +x /app/start.sh

# Expose the port the app runs on
EXPOSE 7777

# Set environment variable for port
ENV PORT=7777

# Run the startup script
CMD ["/app/start.sh"]