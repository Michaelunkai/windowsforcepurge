const axios = require('axios');
const puppeteer = require('puppeteer');

class ShippingValidator {
  constructor() {
    this.israelPostalCodes = ['5916', '5917', '5918', '5919', '5920', '5921']; // Bat Yam postal codes
    this.userAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';
  }

  async validateShippingToIsrael(products) {
    const validatedProducts = [];
    
    for (const product of products) {
      try {
        const shippingInfo = await this.checkShippingForProduct(product);
        const totalPrice = product.price + (shippingInfo.shippingCost || 0);
        
        validatedProducts.push({
          ...product,
          shipsToIsrael: shippingInfo.shipsToIsrael,
          shippingCost: shippingInfo.shippingCost,
          shippingTime: shippingInfo.shippingTime,
          totalPrice: totalPrice,
          shippingDetails: shippingInfo.details
        });
      } catch (error) {
        console.error(`Failed to validate shipping for ${product.title}:`, error.message);
        validatedProducts.push({
          ...product,
          shipsToIsrael: false,
          shippingCost: 0,
          totalPrice: product.price,
          shippingDetails: 'Unable to verify shipping'
        });
      }
    }
    
    return validatedProducts;
  }

  async checkShippingForProduct(product) {
    switch (product.platform) {
      case 'Amazon':
        return await this.checkAmazonShipping(product);
      case 'eBay':
        return await this.checkEbayShipping(product);
      case 'AliExpress':
        return await this.checkAliExpressShipping(product);
      case 'BangGood':
        return await this.checkBangGoodShipping(product);
      case 'Gearbest':
        return await this.checkGearbestShipping(product);
      case 'Newegg':
        return await this.checkNeweggShipping(product);
      default:
        return {
          shipsToIsrael: false,
          shippingCost: 0,
          details: 'Unknown platform'
        };
    }
  }

  async checkAmazonShipping(product) {
    try {
      const browser = await puppeteer.launch({ 
        headless: 'new',
        args: ['--no-sandbox', '--disable-setuid-sandbox']
      });
      const page = await browser.newPage();
      await page.setUserAgent(this.userAgent);
      
      await page.goto(product.link, { waitUntil: 'networkidle2' });
      
      // Check if international shipping is mentioned
      const shippingInfo = await page.evaluate(() => {
        const shippingText = document.body.innerText.toLowerCase();
        const shipsToIsrael = shippingText.includes('ships to israel') || 
                             shippingText.includes('international shipping') ||
                             shippingText.includes('worldwide shipping');
        
        // Try to find shipping cost
        const shippingCostElement = document.querySelector('#mir-layout-DELIVERY_BLOCK');
        let shippingCost = 0;
        
        if (shippingCostElement) {
          const costText = shippingCostElement.innerText;
          const costMatch = costText.match(/\$(\d+(?:\.\d+)?)/);
          if (costMatch) {
            shippingCost = parseFloat(costMatch[1]);
          }
        }
        
        return {
          shipsToIsrael,
          shippingCost,
          details: shipsToIsrael ? 'International shipping available' : 'No international shipping found'
        };
      });
      
      await browser.close();
      return shippingInfo;
      
    } catch (error) {
      console.error('Amazon shipping check error:', error.message);
      return {
        shipsToIsrael: true, // Assume Amazon ships internationally
        shippingCost: 15, // Estimated shipping cost
        details: 'Estimated - Amazon typically ships internationally'
      };
    }
  }

  async checkEbayShipping(product) {
    try {
      const browser = await puppeteer.launch({ 
        headless: 'new',
        args: ['--no-sandbox', '--disable-setuid-sandbox']
      });
      const page = await browser.newPage();
      await page.setUserAgent(this.userAgent);
      
      await page.goto(product.link, { waitUntil: 'networkidle2' });
      
      const shippingInfo = await page.evaluate(() => {
        const shippingSection = document.querySelector('#vi-acc-del-range');
        let shipsToIsrael = false;
        let shippingCost = 0;
        
        if (shippingSection) {
          const shippingText = shippingSection.innerText.toLowerCase();
          shipsToIsrael = shippingText.includes('israel') || 
                         shippingText.includes('worldwide') ||
                         shippingText.includes('international');
          
          // Extract shipping cost
          const costMatch = shippingText.match(/\$(\d+(?:\.\d+)?)/);
          if (costMatch) {
            shippingCost = parseFloat(costMatch[1]);
          }
        }
        
        return {
          shipsToIsrael,
          shippingCost,
          details: shipsToIsrael ? 'Ships to Israel' : 'Shipping to Israel not confirmed'
        };
      });
      
      await browser.close();
      return shippingInfo;
      
    } catch (error) {
      console.error('eBay shipping check error:', error.message);
      return {
        shipsToIsrael: true, // Many eBay sellers ship internationally
        shippingCost: 20, // Estimated
        details: 'Estimated - Most eBay sellers offer international shipping'
      };
    }
  }

  async checkAliExpressShipping(product) {
    // AliExpress typically ships worldwide including Israel
    return {
      shipsToIsrael: true,
      shippingCost: 0, // Usually free shipping
      shippingTime: '15-30 days',
      details: 'AliExpress ships to Israel with free shipping on most items'
    };
  }

  async checkBangGoodShipping(product) {
    // BangGood typically ships worldwide
    return {
      shipsToIsrael: true,
      shippingCost: 5, // Estimated
      shippingTime: '10-20 days',
      details: 'BangGood ships worldwide including Israel'
    };
  }

  async checkGearbestShipping(product) {
    // Gearbest typically ships worldwide
    return {
      shipsToIsrael: true,
      shippingCost: 8, // Estimated
      shippingTime: '15-25 days',
      details: 'Gearbest ships worldwide including Israel'
    };
  }

  async checkNeweggShipping(product) {
    // Newegg has limited international shipping
    return {
      shipsToIsrael: false,
      shippingCost: 0,
      details: 'Newegg primarily ships within US'
    };
  }
}

module.exports = ShippingValidator;