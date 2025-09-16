const puppeteer = require('puppeteer');

async function checkGitHubRepo() {
    const browser = await puppeteer.launch({ headless: false });
    const page = await browser.newPage();
    
    try {
        await page.goto('https://github.com/Michaelunkai?tab=repositories');
        
        // Wait for repositories to load - try multiple selectors
        await page.waitForSelector('[data-testid="repository-list"]', { timeout: 15000 }).catch(() => 
            page.waitForSelector('#user-repositories-list', { timeout: 15000 }).catch(() => 
                page.waitForSelector('.Box-row', { timeout: 15000 })
            )
        );
        
        await new Promise(resolve => setTimeout(resolve, 2000)); // Give extra time for content to load
        
        // Try multiple ways to get the first repository
        let firstRepoName = null;
        
        // Method 1: Try data-testid approach
        try {
            const firstRepoElement = await page.$('[data-testid="repository-list"] li:first-child h3 a, [data-testid="repository-list"] div:first-child h3 a');
            if (firstRepoElement) {
                firstRepoName = await page.evaluate(el => el.textContent.trim(), firstRepoElement);
            }
        } catch (e) {}
        
        // Method 2: Try Box-row approach
        if (!firstRepoName) {
            try {
                const firstRepoElement = await page.$('.Box-row:first-child h3 a');
                if (firstRepoElement) {
                    firstRepoName = await page.evaluate(el => el.textContent.trim(), firstRepoElement);
                }
            } catch (e) {}
        }
        
        // Method 3: Try generic repository link
        if (!firstRepoName) {
            try {
                const firstRepoElement = await page.$('a[href*="/Michaelunkai/"]');
                if (firstRepoElement) {
                    const href = await page.evaluate(el => el.href, firstRepoElement);
                    firstRepoName = href.split('/').pop();
                }
            } catch (e) {}
        }
        
        console.log(`First repository name: ${firstRepoName}`);
        console.log(`Expected repository name: study`);
        
        if (firstRepoName === 'study') {
            console.log('✅ SUCCESS: Repository "study" appears first!');
            return true;
        } else {
            console.log('❌ Repository "study" is not first. Current first repo:', firstRepoName);
            return false;
        }
    } catch (error) {
        console.error('Error checking GitHub:', error);
        return false;
    } finally {
        await browser.close();
    }
}

checkGitHubRepo();