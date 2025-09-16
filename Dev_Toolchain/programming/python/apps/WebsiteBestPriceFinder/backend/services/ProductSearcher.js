const axios = require('axios');
const cheerio = require('cheerio');
const puppeteer = require('puppeteer');

class ProductSearcher {
  constructor() {
    this.userAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';
    this.timeout = 10000;
  }

  async searchAllPlatforms(query) {
    const searchPromises = [
      this.searchAmazon(query),
      this.searchEbay(query),
      this.searchAliExpress(query),
      this.searchBangGood(query),
      this.searchGearbest(query),
      this.searchNewegg(query)
    ];

    const results = await Promise.allSettled(searchPromises);
    
    return results
      .filter(result => result.status === 'fulfilled' && result.value.length > 0)
      .flatMap(result => result.value);
  }

  async searchAmazon(query) {
    try {
      const searchUrl = `https://www.amazon.com/s?k=${encodeURIComponent(query)}&ref=nb_sb_noss`;
      
      const browser = await puppeteer.launch({ 
        headless: 'new',
        args: ['--no-sandbox', '--disable-setuid-sandbox']
      });
      const page = await browser.newPage();
      
      await page.setUserAgent(this.userAgent);
      await page.goto(searchUrl, { waitUntil: 'networkidle2' });
      
      const products = await page.evaluate(() => {
        const items = [];
        const productElements = document.querySelectorAll('[data-component-type="s-search-result"]');
        
        productElements.forEach(element => {
          const title = element.querySelector('h2 a span')?.textContent?.trim();
          const priceElement = element.querySelector('.a-price-whole');
          const link = element.querySelector('h2 a')?.href;
          const image = element.querySelector('img')?.src;
          
          if (title && priceElement && link) {
            const price = parseFloat(priceElement.textContent.replace(/[,$]/g, ''));
            items.push({
              title,
              price,
              link: link.startsWith('http') ? link : `https://amazon.com${link}`,
              image,
              platform: 'Amazon',
              currency: 'USD'
            });
          }
        });
        
        return items.slice(0, 10);
      });
      
      await browser.close();
      return products;
      
    } catch (error) {
      console.error('Amazon search error:', error.message);
      return [];
    }
  }

  async searchEbay(query) {
    try {
      const searchUrl = `https://www.ebay.com/sch/i.html?_nkw=${encodeURIComponent(query)}&_sacat=0&LH_BIN=1`;
      
      const response = await axios.get(searchUrl, {
        headers: { 'User-Agent': this.userAgent },
        timeout: this.timeout
      });
      
      const $ = cheerio.load(response.data);
      const products = [];
      
      $('.s-item').each((i, element) => {
        if (i >= 10) return false;
        
        const title = $(element).find('.s-item__title').text().trim();
        const priceText = $(element).find('.s-item__price').text().trim();
        const link = $(element).find('.s-item__link').attr('href');
        const image = $(element).find('.s-item__image img').attr('src');
        
        if (title && priceText && link && title !== 'Shop on eBay') {
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
      console.error('eBay search error:', error.message);
      return [];
    }
  }

  async searchAliExpress(query) {
    try {
      const searchUrl = `https://www.aliexpress.com/wholesale?SearchText=${encodeURIComponent(query)}`;
      
      const browser = await puppeteer.launch({ 
        headless: 'new',
        args: ['--no-sandbox', '--disable-setuid-sandbox']
      });
      const page = await browser.newPage();
      
      await page.setUserAgent(this.userAgent);
      await page.goto(searchUrl, { waitUntil: 'networkidle2' });
      
      // Wait for products to load
      await page.waitForSelector('._1K8dK', { timeout: 5000 }).catch(() => {});
      
      const products = await page.evaluate(() => {
        const items = [];
        const productElements = document.querySelectorAll('._1K8dK');
        
        productElements.forEach(element => {
          const title = element.querySelector('._18_85')?.textContent?.trim();
          const priceElement = element.querySelector('._3059')?.textContent?.trim();
          const link = element.querySelector('a')?.href;
          const image = element.querySelector('img')?.src;
          
          if (title && priceElement && link) {
            const price = parseFloat(priceElement.replace(/[^0-9.]/g, ''));
            if (price > 0) {
              items.push({
                title,
                price,
                link: link.startsWith('http') ? link : `https:${link}`,
                image,
                platform: 'AliExpress',
                currency: 'USD'
              });
            }
          }
        });
        
        return items.slice(0, 10);
      });
      
      await browser.close();
      return products;
      
    } catch (error) {
      console.error('AliExpress search error:', error.message);
      return [];
    }
  }

  async searchBangGood(query) {
    try {
      const searchUrl = `https://www.banggood.com/search/${encodeURIComponent(query)}.html`;
      
      const response = await axios.get(searchUrl, {
        headers: { 'User-Agent': this.userAgent },
        timeout: this.timeout
      });
      
      const $ = cheerio.load(response.data);
      const products = [];
      
      $('.product-item').each((i, element) => {
        if (i >= 10) return false;
        
        const title = $(element).find('.product-title a').text().trim();
        const priceText = $(element).find('.price-current').text().trim();
        const link = $(element).find('.product-title a').attr('href');
        const image = $(element).find('.product-img img').attr('src');
        
        if (title && priceText && link) {
          const price = parseFloat(priceText.replace(/[^0-9.]/g, ''));
          
          if (price > 0) {
            products.push({
              title,
              price,
              link: link.startsWith('http') ? link : `https://www.banggood.com${link}`,
              image,
              platform: 'BangGood',
              currency: 'USD'
            });
          }
        }
      });
      
      return products;
      
    } catch (error) {
      console.error('BangGood search error:', error.message);
      return [];
    }
  }

  async searchGearbest(query) {
    try {
      const searchUrl = `https://www.gearbest.com/search/${encodeURIComponent(query)}.html`;
      
      const response = await axios.get(searchUrl, {
        headers: { 'User-Agent': this.userAgent },
        timeout: this.timeout
      });
      
      const $ = cheerio.load(response.data);
      const products = [];
      
      $('.gbGoodsItem').each((i, element) => {
        if (i >= 10) return false;
        
        const title = $(element).find('.gbGoodsItem_title a').text().trim();
        const priceText = $(element).find('.gbGoodsItem_price').text().trim();
        const link = $(element).find('.gbGoodsItem_title a').attr('href');
        const image = $(element).find('.gbGoodsItem_img img').attr('src');
        
        if (title && priceText && link) {
          const price = parseFloat(priceText.replace(/[^0-9.]/g, ''));
          
          if (price > 0) {
            products.push({
              title,
              price,
              link: link.startsWith('http') ? link : `https://www.gearbest.com${link}`,
              image,
              platform: 'Gearbest',
              currency: 'USD'
            });
          }
        }
      });
      
      return products;
      
    } catch (error) {
      console.error('Gearbest search error:', error.message);
      return [];
    }
  }

  async searchNewegg(query) {
    try {
      const searchUrl = `https://www.newegg.com/p/pl?d=${encodeURIComponent(query)}`;
      
      const response = await axios.get(searchUrl, {
        headers: { 'User-Agent': this.userAgent },
        timeout: this.timeout
      });
      
      const $ = cheerio.load(response.data);
      const products = [];
      
      $('.item-container').each((i, element) => {
        if (i >= 10) return false;
        
        const title = $(element).find('.item-title').text().trim();
        const priceText = $(element).find('.price-current').text().trim();
        const link = $(element).find('.item-title').attr('href');
        const image = $(element).find('.item-img img').attr('src');
        
        if (title && priceText && link) {
          const price = parseFloat(priceText.replace(/[^0-9.]/g, ''));
          
          if (price > 0) {
            products.push({
              title,
              price,
              link: link.startsWith('http') ? link : `https://www.newegg.com${link}`,
              image,
              platform: 'Newegg',
              currency: 'USD'
            });
          }
        }
      });
      
      return products;
      
    } catch (error) {
      console.error('Newegg search error:', error.message);
      return [];
    }
  }
}

module.exports = ProductSearcher;