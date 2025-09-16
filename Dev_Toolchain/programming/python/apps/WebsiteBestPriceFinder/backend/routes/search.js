const express = require('express');
const router = express.Router();
const IsraeliProductSearcher = require('../services/IsraeliProductSearcher');

router.post('/product', async (req, res) => {
  try {
    const { query } = req.body;
    
    if (!query || query.trim().length < 2) {
      return res.status(400).json({ error: 'Search query must be at least 2 characters long' });
    }

    console.log(`Searching Israeli sites for: ${query}`);
    
    const searcher = new IsraeliProductSearcher();
    
    // Search for exact products across Israeli platforms only
    const searchResults = await searcher.searchAllPlatforms(query);
    
    // Sort by price (lowest first) - no shipping validation needed (all Israeli sites)
    const sortedResults = searchResults
      .filter(result => result.price > 0)
      .sort((a, b) => a.price - b.price);
    
    res.json({
      query,
      totalResults: sortedResults.length,
      results: sortedResults.slice(0, 20), // Return top 20 results
      timestamp: new Date().toISOString(),
      searchedSites: ['KSP', 'Ivory', 'Bug', 'Zap', 'Pilpel']
    });
    
  } catch (error) {
    console.error('Search error:', error);
    res.status(500).json({ 
      error: 'Failed to search Israeli sites for products',
      details: process.env.NODE_ENV === 'development' ? error.message : undefined
    });
  }
});

module.exports = router;