const axios = require('axios');
const cheerio = require('cheerio');
const puppeteer = require('puppeteer');

class ImprovedProductSearcher {
  constructor() {
    this.userAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';
    this.timeout = 15000;
    this.maxRetries = 2;
  }

  async searchAllPlatforms(query) {
    console.log(`Starting comprehensive search for: ${query}`);
    
    const searchPromises = [
      this.searchWithRetry(() => this.searchAmazon(query), 'Amazon'),
      this.searchWithRetry(() => this.searchEbay(query), 'eBay'),
      this.searchWithRetry(() => this.searchAliExpress(query), 'AliExpress'),
      this.searchWithRetry(() => this.searchWish(query), 'Wish'),
      this.searchWithRetry(() => this.searchOverstock(query), 'Overstock'),
    ];

    const results = await Promise.allSettled(searchPromises);
    
    const allProducts = results
      .filter(result => result.status === 'fulfilled' && result.value && result.value.length > 0)
      .flatMap(result => result.value);

    console.log(`Found ${allProducts.length} total products`);
    return allProducts;
  }

  async searchWithRetry(searchFunction, platformName) {
    let lastError;
    
    for (let attempt = 1; attempt <= this.maxRetries; attempt++) {
      try {
        console.log(`Attempting ${platformName} search (attempt ${attempt}/${this.maxRetries})`);
        const results = await searchFunction();
        console.log(`${platformName} search successful: ${results.length} products found`);
        return results;
      } catch (error) {
        lastError = error;
        console.error(`${platformName} search failed (attempt ${attempt}):`, error.message);
        
        if (attempt < this.maxRetries) {
          await this.delay(1000 * attempt); // Progressive delay
        }
      }
    }
    
    console.error(`${platformName} search failed after ${this.maxRetries} attempts`);
    return [];
  }

  delay(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
  }

  async searchAmazon(query) {
    const browser = await puppeteer.launch({ 
      headless: 'new',
      args: [
        '--no-sandbox', 
        '--disable-setuid-sandbox',
        '--disable-dev-shm-usage',
        '--disable-accelerated-2d-canvas',
        '--no-first-run',
        '--no-zygote',
        '--single-process',
        '--disable-gpu'
      ]
    });
    
    try {
      const page = await browser.newPage();
      await page.setUserAgent(this.userAgent);
      await page.setViewport({ width: 1366, height: 768 });
      
      const searchUrl = `https://www.amazon.com/s?k=${encodeURIComponent(query)}&ref=nb_sb_noss`;
      
      await page.goto(searchUrl, { 
        waitUntil: 'networkidle2', 
        timeout: this.timeout 
      });

      await page.waitForSelector('[data-component-type="s-search-result"]', { timeout: 5000 });

      const products = await page.evaluate(() => {
        const items = [];
        const productElements = document.querySelectorAll('[data-component-type="s-search-result"]');
        
        productElements.forEach((element, index) => {
          if (index >= 15) return;
          
          const titleElement = element.querySelector('h2 a span');
          const priceElement = element.querySelector('.a-price-whole') || 
                              element.querySelector('.a-price .a-offscreen');
          const linkElement = element.querySelector('h2 a');
          const imageElement = element.querySelector('.s-image');
          
          if (titleElement && priceElement && linkElement) {
            const title = titleElement.textContent?.trim();
            const priceText = priceElement.textContent || priceElement.innerText;
            const price = parseFloat(priceText.replace(/[^0-9.]/g, ''));
            const link = linkElement.href;
            const image = imageElement?.src;
            
            if (title && price > 0 && link) {
              items.push({
                title,
                price,
                link: link.startsWith('http') ? link : `https://amazon.com${link}`,
                image: image || null,
                platform: 'Amazon',
                currency: 'USD'
              });
            }
          }
        });
        
        return items;
      });

      return products;
    } finally {
      await browser.close();
    }
  }

  async searchEbay(query) {
    try {
      const searchUrl = `https://www.ebay.com/sch/i.html?_nkw=${encodeURIComponent(query)}&_sacat=0&LH_BIN=1&_sop=15`;
      
      const response = await axios.get(searchUrl, {
        headers: { 
          'User-Agent': this.userAgent,
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
          'Accept-Language': 'en-US,en;q=0.5',
          'Accept-Encoding': 'gzip, deflate',
          'DNT': '1',
          'Connection': 'keep-alive',
          'Upgrade-Insecure-Requests': '1'
        },
        timeout: this.timeout
      });
      
      const $ = cheerio.load(response.data);
      const products = [];
      
      $('.s-item').each((i, element) => {
        if (i >= 15 || i === 0) return; // Skip first item (usually ad)
        
        const $el = $(element);
        const title = $el.find('.s-item__title').text().trim();
        const priceText = $el.find('.s-item__price').text().trim();
        const link = $el.find('.s-item__link').attr('href');
        const image = $el.find('.s-item__image img').attr('src');
        
        if (title && priceText && link && !title.includes('Shop on eBay')) {
          const price = parseFloat(priceText.replace(/[^0-9.]/g, ''));
          
          if (price > 0) {
            products.push({
              title,
              price,
              link,
              image,
              platform: 'eBay',
              currency: 'USD'
            });
          }
        }
      });
      
      return products;
    } catch (error) {
      throw error;
    }
  }

  async searchAliExpress(query) {
    const browser = await puppeteer.launch({ 
      headless: 'new',
      args: [
        '--no-sandbox', 
        '--disable-setuid-sandbox',
        '--disable-dev-shm-usage',
        '--disable-accelerated-2d-canvas',
        '--no-first-run',
        '--no-zygote',
        '--single-process',
        '--disable-gpu'
      ]
    });
    
    try {
      const page = await browser.newPage();
      await page.setUserAgent(this.userAgent);
      await page.setViewport({ width: 1366, height: 768 });
      
      const searchUrl = `https://www.aliexpress.com/w/wholesale-${encodeURIComponent(query.replace(/\s+/g, '-'))}.html`;
      
      await page.goto(searchUrl, { 
        waitUntil: 'networkidle2', 
        timeout: this.timeout 
      });

      // Wait a bit for dynamic content
      await this.delay(3000);

      const products = await page.evaluate(() => {
        const items = [];
        
        // Try multiple selectors as AliExpress changes frequently
        const selectors = [
          '.list--gallery--C2f2tvm > div',
          '.gallery--2upl2j9 > div',
          '[data-product-id]',
          '.product-item'
        ];
        
        let productElements = [];
        for (const selector of selectors) {
          productElements = document.querySelectorAll(selector);
          if (productElements.length > 0) break;
        }
        
        productElements.forEach((element, index) => {
          if (index >= 15) return;
          
          const titleEl = element.querySelector('a[title], h1, h2, h3') || 
                         element.querySelector('[title]') ||
                         element.querySelector('a');
          const priceEl = element.querySelector('[class*="price"], .price-current, .notranslate') ||
                         element.querySelector('[data-spm-anchor-id*="price"]');
          const linkEl = element.querySelector('a[href]');
          const imageEl = element.querySelector('img');
          
          if (titleEl && priceEl && linkEl) {
            const title = titleEl.getAttribute('title') || titleEl.textContent?.trim();
            const priceText = priceEl.textContent?.trim();
            
            if (title && priceText) {
              const price = parseFloat(priceText.replace(/[^0-9.]/g, ''));
              let link = linkEl.href;
              
              if (link && price > 0) {
                if (!link.startsWith('http')) {
                  link = `https:${link}`;
                }
                
                items.push({
                  title: title.substring(0, 200), // Limit title length
                  price,
                  link,
                  image: imageEl?.src || null,
                  platform: 'AliExpress',
                  currency: 'USD'
                });
              }
            }
          }
        });
        
        return items;
      });

      return products;
    } finally {
      await browser.close();
    }
  }

  async searchWish(query) {
    try {
      const searchUrl = `https://www.wish.com/search/${encodeURIComponent(query)}`;
      
      const response = await axios.get(searchUrl, {
        headers: { 
          'User-Agent': this.userAgent,
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
          'Accept-Language': 'en-US,en;q=0.5'
        },
        timeout: this.timeout
      });
      
      const $ = cheerio.load(response.data);
      const products = [];
      
      $('.feed-product').each((i, element) => {
        if (i >= 10) return false;
        
        const $el = $(element);
        const title = $el.find('[data-testid="product-title"]').text().trim() ||
                     $el.find('.ProductTitle').text().trim();
        const priceText = $el.find('[data-testid="product-price"]').text().trim() ||
                         $el.find('.ProductPrice').text().trim();
        const link = $el.find('a[href*="/product/"]').attr('href');
        const image = $el.find('img').attr('src') || $el.find('img').attr('data-src');
        
        if (title && priceText && link) {
          const price = parseFloat(priceText.replace(/[^0-9.]/g, ''));
          
          if (price > 0) {
            products.push({
              title,
              price,
              link: link.startsWith('http') ? link : `https://wish.com${link}`,
              image,
              platform: 'Wish',
              currency: 'USD'
            });
          }
        }
      });
      
      return products;
    } catch (error) {
      throw error;
    }
  }

  async searchOverstock(query) {
    try {
      const searchUrl = `https://www.overstock.com/search?keywords=${encodeURIComponent(query)}`;
      
      const response = await axios.get(searchUrl, {
        headers: { 
          'User-Agent': this.userAgent,
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8'
        },
        timeout: this.timeout
      });
      
      const $ = cheerio.load(response.data);
      const products = [];
      
      $('[data-automation-id="product-result"]').each((i, element) => {
        if (i >= 10) return false;
        
        const $el = $(element);
        const title = $el.find('a[data-automation-id="product-title"]').text().trim();
        const priceText = $el.find('[data-automation-id="product-price"]').text().trim();
        const link = $el.find('a[data-automation-id="product-title"]').attr('href');
        const image = $el.find('img').attr('src');
        
        if (title && priceText && link) {
          const price = parseFloat(priceText.replace(/[^0-9.]/g, ''));
          
          if (price > 0) {
            products.push({
              title,
              price,
              link: link.startsWith('http') ? link : `https://www.overstock.com${link}`,
              image,
              platform: 'Overstock',
              currency: 'USD'
            });
          }
        }
      });
      
      return products;
    } catch (error) {
      throw error;
    }
  }
}

module.exports = ImprovedProductSearcher;