class MockProductSearcher {
  constructor() {
    // Mock data for demonstration purposes
    this.mockData = {
      'samsung s25 ultra': [
        {
          title: 'Samsung Galaxy S25 Ultra 256GB - Titanium Gray',
          price: 1199.99,
          link: 'https://www.amazon.com/samsung-s25-ultra',
          image: 'https://images.samsung.com/is/image/samsung/assets/us/smartphones/galaxy-s25-ultra/images/galaxy-s25-ultra-highlights-camera.jpg',
          platform: 'Amazon',
          currency: 'USD'
        },
        {
          title: 'Samsung Galaxy S25 Ultra 512GB Unlocked',
          price: 1399.99,
          link: 'https://www.ebay.com/itm/samsung-s25-ultra-512gb',
          image: 'https://images.samsung.com/is/image/samsung/assets/us/smartphones/galaxy-s25-ultra/images/galaxy-s25-ultra-highlights-camera.jpg',
          platform: 'eBay',
          currency: 'USD'
        },
        {
          title: 'SAMSUNG Galaxy S25 Ultra 5G Smartphone 256GB',
          price: 1099.00,
          link: 'https://www.aliexpress.com/item/samsung-galaxy-s25-ultra.html',
          image: 'https://images.samsung.com/is/image/samsung/assets/us/smartphones/galaxy-s25-ultra/images/galaxy-s25-ultra-highlights-camera.jpg',
          platform: 'AliExpress',
          currency: 'USD'
        },
        {
          title: 'Samsung S25 Ultra Case + Screen Protector Bundle',
          price: 89.99,
          link: 'https://www.amazon.com/samsung-s25-ultra-case',
          image: 'https://m.media-amazon.com/images/I/71abc123def.jpg',
          platform: 'Amazon',
          currency: 'USD'
        },
        {
          title: 'Samsung Galaxy S25 Ultra 1TB Storage - Black',
          price: 1599.99,
          link: 'https://www.ebay.com/itm/samsung-s25-ultra-1tb',
          image: 'https://images.samsung.com/is/image/samsung/assets/us/smartphones/galaxy-s25-ultra/images/galaxy-s25-ultra-highlights-camera.jpg',
          platform: 'eBay',
          currency: 'USD'
        },
        {
          title: 'Galaxy S25 Ultra Wireless Charger Stand',
          price: 49.99,
          link: 'https://www.aliexpress.com/item/galaxy-s25-charger.html',
          image: 'https://ae01.alicdn.com/kf/S12345678901234567890.jpg',
          platform: 'AliExpress',
          currency: 'USD'
        }
      ],
      'iphone 15 pro': [
        {
          title: 'Apple iPhone 15 Pro 128GB - Natural Titanium',
          price: 999.99,
          link: 'https://www.amazon.com/apple-iphone-15-pro',
          image: 'https://store.storeimages.cdn-apple.com/4982/as-images.apple.com/is/iphone-15-pro-natural-titanium.jpg',
          platform: 'Amazon',
          currency: 'USD'
        },
        {
          title: 'iPhone 15 Pro Max 256GB Unlocked',
          price: 1199.99,
          link: 'https://www.ebay.com/itm/iphone-15-pro-max',
          image: 'https://store.storeimages.cdn-apple.com/4982/as-images.apple.com/is/iphone-15-pro-max-natural-titanium.jpg',
          platform: 'eBay',
          currency: 'USD'
        },
        {
          title: 'Apple iPhone 15 Pro 256GB Blue Titanium',
          price: 1099.99,
          link: 'https://www.aliexpress.com/item/iphone-15-pro.html',
          image: 'https://store.storeimages.cdn-apple.com/4982/as-images.apple.com/is/iphone-15-pro-blue-titanium.jpg',
          platform: 'AliExpress',
          currency: 'USD'
        }
      ],
      'macbook pro': [
        {
          title: 'MacBook Pro 14-inch M3 Chip 8GB RAM 512GB SSD',
          price: 1999.99,
          link: 'https://www.amazon.com/macbook-pro-14-m3',
          image: 'https://store.storeimages.cdn-apple.com/4982/as-images.apple.com/is/mbp-14-spacegray.jpg',
          platform: 'Amazon',
          currency: 'USD'
        },
        {
          title: 'Apple MacBook Pro 16-inch M3 Max 18GB 1TB',
          price: 3499.99,
          link: 'https://www.ebay.com/itm/macbook-pro-16-m3-max',
          image: 'https://store.storeimages.cdn-apple.com/4982/as-images.apple.com/is/mbp-16-spacegray.jpg',
          platform: 'eBay',
          currency: 'USD'
        }
      ]
    };
  }

  async searchAllPlatforms(query) {
    console.log(`Searching for: ${query}`);
    
    // Simulate network delay
    await this.delay(2000);
    
    const normalizedQuery = query.toLowerCase().trim();
    
    // Find matching products
    let products = [];
    
    for (const [key, items] of Object.entries(this.mockData)) {
      if (this.queryMatches(normalizedQuery, key)) {
        products = products.concat(items);
      }
    }
    
    // If no exact match, provide some generic results
    if (products.length === 0) {
      products = this.generateGenericResults(query);
    }
    
    console.log(`Found ${products.length} products for query: ${query}`);
    return products;
  }

  queryMatches(query, key) {
    const queryWords = query.split(/\s+/);
    const keyWords = key.split(/\s+/);
    
    return queryWords.some(qWord => 
      keyWords.some(kWord => 
        kWord.includes(qWord) || qWord.includes(kWord)
      )
    );
  }

  generateGenericResults(query) {
    const basePrice = Math.floor(Math.random() * 1000) + 100;
    
    return [
      {
        title: `${query} - Premium Model`,
        price: basePrice + 200,
        link: `https://www.amazon.com/s?k=${encodeURIComponent(query)}`,
        image: null,
        platform: 'Amazon',
        currency: 'USD'
      },
      {
        title: `${query} - Standard Edition`,
        price: basePrice,
        link: `https://www.ebay.com/sch/i.html?_nkw=${encodeURIComponent(query)}`,
        image: null,
        platform: 'eBay',
        currency: 'USD'
      },
      {
        title: `${query} - Budget Option`,
        price: basePrice - 100,
        link: `https://www.aliexpress.com/w/wholesale-${encodeURIComponent(query)}.html`,
        image: null,
        platform: 'AliExpress',
        currency: 'USD'
      },
      {
        title: `${query} Accessories Bundle`,
        price: Math.floor(basePrice * 0.3),
        link: `https://www.amazon.com/s?k=${encodeURIComponent(query)}+accessories`,
        image: null,
        platform: 'Amazon',
        currency: 'USD'
      }
    ];
  }

  delay(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
  }
}

module.exports = MockProductSearcher;