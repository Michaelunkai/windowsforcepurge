class SimpleShippingValidator {
  constructor() {
    // Simplified shipping rules for demonstration
    this.shippingRules = {
      'Amazon': { shipsToIsrael: true, shippingCost: 15, shippingTime: '5-10 days', details: 'Amazon ships internationally' },
      'eBay': { shipsToIsrael: true, shippingCost: 20, shippingTime: '7-14 days', details: 'Most eBay sellers ship internationally' },
      'AliExpress': { shipsToIsrael: true, shippingCost: 0, shippingTime: '15-30 days', details: 'AliExpress ships to Israel with free shipping on most items' },
      'BangGood': { shipsToIsrael: true, shippingCost: 5, shippingTime: '10-20 days', details: 'BangGood ships worldwide including Israel' },
      'Gearbest': { shipsToIsrael: true, shippingCost: 8, shippingTime: '15-25 days', details: 'Gearbest ships worldwide including Israel' },
      'Wish': { shipsToIsrael: true, shippingCost: 10, shippingTime: '10-25 days', details: 'Wish ships to Israel' },
      'Overstock': { shipsToIsrael: true, shippingCost: 25, shippingTime: '10-15 days', details: 'Overstock ships internationally' },
      'Newegg': { shipsToIsrael: false, shippingCost: 0, details: 'Newegg primarily ships within US' }
    };
  }

  async validateShippingToIsrael(products) {
    console.log(`Validating shipping for ${products.length} products`);
    
    const validatedProducts = products.map(product => {
      const shippingRule = this.shippingRules[product.platform] || {
        shipsToIsrael: true,
        shippingCost: 15,
        shippingTime: '7-21 days',
        details: 'International shipping available'
      };
      
      const totalPrice = product.price + (shippingRule.shippingCost || 0);
      
      return {
        ...product,
        shipsToIsrael: shippingRule.shipsToIsrael,
        shippingCost: shippingRule.shippingCost,
        shippingTime: shippingRule.shippingTime,
        totalPrice: totalPrice,
        shippingDetails: shippingRule.details
      };
    });
    
    console.log(`Validated ${validatedProducts.length} products, ${validatedProducts.filter(p => p.shipsToIsrael).length} ship to Israel`);
    
    return validatedProducts;
  }
}

module.exports = SimpleShippingValidator;