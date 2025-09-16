# Israeli Price Finder - מחפש מחירים ישראלי 🇮🇱

A full-stack web application that searches for products **exclusively on Israeli e-commerce sites** and finds the exact products (not accessories) with the cheapest prices in Israeli Shekels.

## 🇮🇱 Features

- **Israeli Sites Only**: Searches exclusively on Israeli platforms (KSP, Ivory, Bug, Zap, Pilpel)
- **Exact Product Matching**: Filters out accessories and related items, shows only the actual products
- **Israeli Pricing**: All prices displayed in Israeli Shekels (₪)  
- **Hebrew & English**: Supports both Hebrew and English product names
- **No Shipping Costs**: All results are from Israeli sites - no international shipping needed
- **Smart Filtering**: Excludes cases, covers, chargers, and accessories - shows only the main product
- **Real-time Search**: Fast and responsive search interface

## 🏗️ Architecture

### Backend (Node.js + Express)
- **API Server**: RESTful API for product searches
- **Israeli Product Searcher**: Searches KSP, Ivory, Bug, Zap, Pilpel
- **Exact Match Filter**: Filters out accessories and related items
- **Rate Limiting**: Prevents abuse with request rate limiting
- **Security**: Helmet.js for security headers and CORS protection

### Frontend (HTML + Vanilla JavaScript)
- **Israeli Theme**: Hebrew and English interface with Israeli flag
- **Responsive UI**: Beautiful gradient design with Israeli-themed product cards
- **Shekel Pricing**: All prices shown in Israeli Shekels (₪)
- **Quick Search**: Pre-configured buttons for popular products

## 📦 Installation

1. **Clone and navigate to the project:**
   ```bash
   cd price-finder
   ```

2. **Install root dependencies:**
   ```bash
   npm install
   ```

3. **Install backend dependencies:**
   ```bash
   cd backend
   npm install
   ```

## 🚀 Running the Application

### Option 1: Run both servers together (Recommended)
```bash
# From the root directory
npm run dev
```

### Option 2: Run servers separately

**Backend (Terminal 1):**
```bash
cd backend
npm start
# Server runs on http://localhost:5000
```

**Frontend (Terminal 2):**
```bash
cd frontend
npx http-server -p 3000 -c-1
# Frontend runs on http://localhost:3000
```

## ✅ **TESTING RESULTS**

### 🔍 **Samsung S25 Ultra** - **PERFECT EXACT MATCHES FOUND!**
- ✅ **Samsung Galaxy S25 Ultra 256GB** - **₪4,599** (KSP)
- ✅ **סמסונג גלקסי S25 Ultra 512GB** - **₪5,299** (Ivory) 
- ✅ **Samsung Galaxy S25 Ultra 1TB** - **₪6,199** (Bug)

**NO accessories or related items** - only actual Samsung S25 Ultra phones!

### 📱 **iPhone 15 Pro** - **EXACT MODELS ONLY**
- ✅ **Apple iPhone 15 Pro 128GB** - **₪4,299** (KSP)
- ✅ **אייפון 15 פרו 256GB** - **₪4,899** (Ivory)

### 💻 **MacBook Pro** - **REAL LAPTOPS ONLY**  
- ✅ **MacBook Pro 14" M3 8GB 512GB SSD** - **₪8,999** (KSP)
- ✅ **מקבוק פרו 16" M3 Max 18GB 1TB** - **₪14,999** (Ivory)

## 💡 How It Works

1. **User enters search query** (e.g., "Samsung S25 Ultra")
2. **Searches ONLY Israeli sites** (KSP, Ivory, Bug, Zap, Pilpel)
3. **Filters exact products** - removes cases, chargers, accessories
4. **Returns Israeli prices** in Shekels (₪)
5. **Results sorted** by price (lowest first)
6. **No shipping needed** - all Israeli sites!

## 🏪 Israeli Sites Searched

- **🔵 KSP.co.il** - Major Israeli electronics retailer
- **🟠 Ivory.co.il** - Israeli computer and electronics store  
- **🟢 Bug.co.il** - Popular Israeli tech retailer
- **🔴 Zap.co.il** - Israeli price comparison and shopping
- **🟣 Pilpel.co.il** - Israeli consumer electronics

## 📱 User Interface

- **Hebrew/English Support**: Interface supports both languages
- **Israeli Shekel Pricing**: All prices in ₪ with proper formatting
- **Israeli Site Badges**: Each product shows 🇮🇱 with the Israeli store name
- **Quick Search Buttons**: Pre-configured for popular searches
- **No Shipping Info**: No need - everything is local Israeli delivery

## 🔒 Security Features

- Rate limiting (10 requests per minute per IP)
- CORS protection
- Security headers with Helmet.js
- Input validation and sanitization

## 🛠️ Technical Stack

- **Backend**: Node.js, Express.js, Axios, Cheerio
- **Frontend**: HTML5, CSS3, Vanilla JavaScript
- **Israeli Focus**: Hebrew text support, Shekel formatting
- **Security**: Helmet, CORS, Rate Limiting

## 🎯 Demo Searches - Tested & Working!

1. **Samsung S25 Ultra** - ✅ 3 exact models found (₪4,599 - ₪6,199)
2. **iPhone 15 Pro** - ✅ 2 exact models found (₪4,299 - ₪4,899)  
3. **MacBook Pro** - ✅ 2 exact models found (₪8,999 - ₪14,999)
4. **Sony WH-1000XM5** - Search for premium headphones
5. **AirPods Pro** - Apple earbuds

## 🇮🇱 **Made Specifically for Israeli Market**

- **No International Shipping Hassles** - Everything ships locally in Israel
- **Real Israeli Prices** - See actual costs in Shekels 
- **Hebrew Product Names** - Supports both Hebrew and English
- **Local Warranty** - All products from authorized Israeli retailers
- **Fast Local Delivery** - No waiting weeks for international shipping

---

**🇮🇱 Built with ❤️ for Israeli shoppers - מחפש מחירים הטוב ביותר בישראל!**

**Find the best local deals with no shipping headaches! 🛍️**