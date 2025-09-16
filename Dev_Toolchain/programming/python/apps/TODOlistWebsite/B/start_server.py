#!/usr/bin/env python3
"""
Production server startup script for Render deployment
Fallback option if direct uvicorn command doesn't work
"""
import os
import sys

def main():
    """Start the application server"""
    port = int(os.environ.get("PORT", 8000))
    
    print(f"🚀 Starting TodoNotes server on port {port}...")
    print(f"🌐 Server will be available at: http://0.0.0.0:{port}")
    
    try:
        # Import and run the app directly
        import uvicorn
        from app.main import app
        
        uvicorn.run(
            app,
            host="0.0.0.0",
            port=port,
            log_level="info",
            access_log=True
        )
    except ImportError as e:
        print(f"❌ Failed to import required modules: {e}")
        print("💡 Make sure all dependencies are installed: pip install -r requirements.txt")
        sys.exit(1)
    except Exception as e:
        print(f"❌ Server failed to start: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()