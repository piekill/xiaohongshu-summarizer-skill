#!/bin/bash
KEYWORD="$1"
MAX_POSTS="${2:-10}"
OUTPUT_DIR="${3:-.}"

if [ -z "$KEYWORD" ]; then
    echo "Usage: ./run.sh <keyword> [max_posts] [output_dir]"
    exit 1
fi

# Validate MAX_POSTS is a positive integer within bounds
if ! [[ "$MAX_POSTS" =~ ^[0-9]+$ ]] || [ "$MAX_POSTS" -lt 1 ] || [ "$MAX_POSTS" -gt 50 ]; then
    echo "Error: max_posts must be a positive integer between 1 and 50."
    exit 1
fi

mkdir -p "$OUTPUT_DIR"

SCRIPT_PATH="/tmp/xhs_scrape_$$.js"

export KEYWORD MAX_POSTS
cat << 'EOF' > "$SCRIPT_PATH"
async page => {
    const keyword = encodeURIComponent(process.env.KEYWORD || "");
    const maxPosts = parseInt(process.env.MAX_POSTS || "10", 10);
    await page.goto(\`https://www.xiaohongshu.com/search_result?keyword=\${keyword}&source=web_explore_feed\`, { waitUntil: 'domcontentloaded' });
    await page.waitForTimeout(4000); 

    const maxPostsLimit = 10;
    const results = [];
    
    // get the note items covers
    const items = page.locator('.note-item a.cover').filter({ hasNotText: '' }); 
    const count = await items.count();
    
    for (let i = 0; i < Math.min(count, maxPosts); i++) {
        try {
            await page.evaluate((index) => {
                const links = document.querySelectorAll('.note-item a.cover');
                if (links[index]) links[index].removeAttribute('target');
            }, i);
            await items.nth(i).click({ force: true, timeout: 5000 });
        } catch(e) { continue; }
        
        // Wait for modal detail to appear
        try {
            await page.waitForSelector('#detail-title', { timeout: 3000 });
        } catch(e) {}
        await page.waitForTimeout(1000);
        
        // Click through sliders
        try {
            let nextBtn = page.locator('.swiper-button-next');
            while(await nextBtn.isVisible() && !await nextBtn.isDisabled()) {
                await nextBtn.click({ force: true });
                await page.waitForTimeout(300);
            }
        } catch(e) {}

        const data = await page.evaluate(() => {
            const elTitle = document.querySelector('#detail-title');
            const title = elTitle ? elTitle.innerText : '';
            const elDesc = document.querySelector('#detail-desc');
            const desc = elDesc ? elDesc.innerText : '';
            
            let imgUrls = [];
            const swiperImgs = document.querySelectorAll('.note-slider .swiper-slide:not(.swiper-slide-duplicate) img');
            swiperImgs.forEach(img => {
                if (img.src && !img.src.includes('avatar') && !imgUrls.includes(img.src)) {
                    imgUrls.push(img.src);
                }
            });
            
            if (imgUrls.length === 0) {
                 const singleImg = document.querySelector('.media-container img');
                 if (singleImg && singleImg.src && !singleImg.src.includes('avatar')) {
                     imgUrls.push(singleImg.src);
                 }
            }
            
            // Extract comments
            let commentsRes = [];
            let commentEls = document.querySelectorAll('.comment-item');
            if (commentEls.length === 0) {
                commentEls = document.querySelectorAll('[class*="commentItem"]');
            }
            if (commentEls.length === 0) {
                commentEls = document.querySelectorAll('.parent-comment');
            }
            
            commentEls.forEach(el => {
                let userEl = el.querySelector('.name');
                let user = userEl ? userEl.innerText : 'User';
                let contentEl = el.querySelector('.content');
                let content = contentEl ? contentEl.innerText.trim() : '';
                
                if(!content){
                    // Fallback cleanup
                    content = el.innerText.replace(user, '').trim();
                    content = content.replace(/^[:：]/, '').trim().substring(0, 150);
                }
                
                if (content && commentsRes.length < 5) {
                    commentsRes.push({ user, content });
                }
            });
            
            return { title, desc, images: imgUrls, comments: commentsRes };
        });
        
        if (data.title || data.desc || data.images.length > 0) {
            results.push(data);
        }
        
        try {
            const closeBtn = page.locator('.close-box');
            if (await closeBtn.count() > 0) {
                await closeBtn.first().click({ force: true, timeout: 2000 });
            } else {
                 throw new Error("No close box");
            }
        } catch (e) {
            await page.keyboard.press('Escape');
            await page.waitForTimeout(1000); 
            if (page.url().includes("/explore/")) {
                await page.goBack();
            }
        }
        await page.waitForTimeout(1500);
    }
    
    return JSON.stringify(results, null, 2);
}
EOF

echo "Running Xiaohongshu scraper for keyword: $KEYWORD"
playwright-cli run-code "$(< "$SCRIPT_PATH")" > "$OUTPUT_DIR/xhs_data.json"

echo "Parsing results and downloading images..."
python3 "$(dirname "$0")/parse.py" "$KEYWORD" "$OUTPUT_DIR/xhs_data.json" "$OUTPUT_DIR"
rm -f "$SCRIPT_PATH"
echo "Raw markdown and artifacts saved to $OUTPUT_DIR"
