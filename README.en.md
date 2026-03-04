# Xiaohongshu Search and Summarizer

An AI agent skill designed to seamlessly extract, analyze, and synthesize high-quality multi-modal content (text, images, and user comments) from Xiaohongshu (小红书). 

Due to aggressive anti-scraping mechanisms, direct HTTP requests to Xiaohongshu often fail. This skill relies on `playwright-cli` to simulate real user behavior within a headed browser, bypassing blocks to retrieve valuable data. Furthermore, it leverages the Multi-Modal capabilities of Language Models (LLMs) to natively "read" graphs, charts, and text extracted from the social platform, yielding a highly contextual synthesis report.

## ✨ Features

- **Anti-Scraping Bypass**: Utilizes `playwright-cli` in a headed mode window to act as a human user.
- **Deep Extraction**: Automatically clicks through post covers, scrolls to load lazy content, and navigates image sliders to capture every detail.
- **Comments Included**: Gathers the top comments, filtering out noise, to provide community sentiment and crowd-sourced insights.
- **Offline Artifacts**: Downloads high-resolution images (`.webp` or `.jpg`) and raw post details into a fully localized markdown format (`[keyword]_raw_data.md`).
- **AI-Powered Synthesis**: The LLM agent physically "views" the downloaded pictures and reads the textual data, transforming isolated posts into a beautifully synthesized, cross-referenced comprehensive analytical report.

## 🛠 Prerequisites

Ensure the following dependencies are installed and available in your system's `PATH`:
- [playwright-cli](https://playwright.dev/docs/cli)
- `python3` (with the `requests` library installed for fetching images)

## 🚀 Usage

This skill is intended to be used by an AI Agent, but it provides a standalone collection script that can also be executed manually.

### 1. Data Collection Phase

Run the underlying Bash wrapper script to initialize the Playwright scraper:

```bash
./scripts/run.sh "YOUR KEYWORD" [MAX_POSTS] [OUTPUT_DIRECTORY]
```

- `YOUR KEYWORD`: The topic you want to research (e.g., "AI tools").
- `MAX_POSTS`: The number of top-ranking posts to scrape (default is `10`).
- `OUTPUT_DIRECTORY`: The path where the raw data and downloaded images will be stored (default is `./`).

**Example:**
```bash
./scripts/run.sh "openclaw使用场景" 10 "./xhs_report_openclaw_scenarios"
```

### 2. AI Synthesis Phase (Agent Task)

Once the script finishes fetching data into `<OUTPUT_DIRECTORY>/[keyword]_raw_data.md`, the AI Agent takes over:
1. It reads the raw markdown data.
2. It uses its vision capabilities (via a file reading tool) to inspect the downloaded images.
3. It intelligently categorizes themes, deduplicates information, evaluates community comments, and weaves the pictures into a detailed, summarized markdown report: `<OUTPUT_DIRECTORY>/[keyword]_synthesis.md`.

## ⚠️ Known Issues & Troubleshooting

- **Login Wall**: Xiaohongshu may pause the session with a login challenge. If the script appears stuck and a browser window prompts for login, quickly perform the authentication manually. The script will wait until the page is loaded.
- **Element Timeout**: Xiaohongshu frequently updates its DOM structure. If the scraper throws "Timeout waiting for selector" errors, the CSS selectors in `run.sh` (the embedded JS script) might need updating.

---

*[Read this in Chinese (简体中文)](README.md)*
