# 🚀 Render Deployment Guide for TodoNotes

## ❌ Common Issue: "Build directory does not exist"

If you're seeing this error, it means Render is treating your app as a **Static Site** instead of a **Web Service**.

## ✅ Solution: Deploy as Web Service

### Step 1: Create New Web Service

1. Go to [Render Dashboard](https://dashboard.render.com)
2. Click **"New +"** button
3. Select **"Web Service"** (⚠️ NOT "Static Site")

### Step 2: Connect Repository

1. Connect your GitHub account
2. Select your TodoNotes repository
3. Click **"Connect"**

### Step 3: Configure Settings

**Basic Settings:**
- **Name**: `todonotes-app` (or your preferred name)
- **Region**: Choose closest to your users
- **Branch**: `main` (or your default branch)

**Build & Deploy Settings:**
- **Runtime**: `Python 3`
- **Build Command**: `pip install -r requirements.txt`
- **Start Command**: `python -m uvicorn app.main:app --host 0.0.0.0 --port $PORT`

**Advanced Settings:**
- **Auto-Deploy**: `Yes`
- **Instance Type**: `Free` (or upgrade as needed)

### Step 4: Environment Variables (Optional)

Add these if needed:
- `PYTHON_VERSION`: `3.11.0`
- `PORT`: Leave empty (Render sets this automatically)

### Step 5: Deploy

1. Click **"Create Web Service"**
2. Wait for deployment (usually 2-5 minutes)
3. Your app will be live at: `https://your-app-name.onrender.com`

## 🔍 Troubleshooting

### If you still see "build directory" errors:

1. **Check Service Type**: Make sure it says "Web Service" not "Static Site"
2. **Check Build Command**: Should be `pip install -r requirements.txt`
3. **Check Start Command**: Should be `python -m uvicorn app.main:app --host 0.0.0.0 --port $PORT`

### Alternative: Use render.yaml (Automatic Configuration)

If you have the `render.yaml` file in your repository:
1. Render should automatically detect it
2. All settings will be configured automatically
3. You just need to click "Deploy"

## ✅ Success Indicators

When deployment succeeds, you'll see:
- ✅ "Build succeeded"
- ✅ "Deploy succeeded" 
- ✅ Your app accessible at the provided URL

## 🆘 Still Having Issues?

If you're still having problems:
1. Delete the current service completely
2. Wait 5 minutes
3. Create a brand new "Web Service" (not Static Site)
4. Follow the manual configuration steps above

Your TodoNotes app should then deploy successfully! 🎉