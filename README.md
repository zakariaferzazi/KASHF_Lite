# KASHF Lite

> **AI-Powered Market Intelligence & Research Workspace**

KASHF Lite is an AI-powered research and investigation workspace designed to synthesize data on companies, brands, products, influencers, and markets—all from a single place. 

Instead of manually digging through search engines, social media platforms, news sites, and public directories, KASHF Lite automates the heavy lifting: gathering public data, structuring evidence, and leveraging AI to generate deep, actionable insights.

*Note: This MVP focuses on validating the core investigation experience prior to full enterprise expansion.*

---

## 🎯 Target Audience

KASHF Lite is built for professionals who rely on market intelligence:

* **Founders & Entrepreneurs** – Uncover market gaps and validate ideas.
* **Investors & Analysts** – Fast-track due diligence and competitive mapping.
* **Marketing Agencies & Researchers** – Track brand sentiment, campaigns, and trends.
* **Sales Teams** – Gather prospect intelligence and account insights.
* **Creators & Journalists** – Analyze influencer metrics and track public narratives.

---

## 🔬 Supported Investigation Types

| Type | Focus Areas | Key AI Deliverables |
| :--- | :--- | :--- |
| **Companies** | Structure, employees, tech stack, press, competitors | SWOT Analysis, Risk Assessment |
| **Brands** | Visual identity, campaigns, positioning, customer sentiment | Sentiment Analysis, Market Positioning |
| **Products** | Features, customer reviews, pricing models, market demand | Opportunity Detection, Feature Gap Analysis |
| **Influencers** | Reach, audience demographics, engagement, brand deals | Authenticity Score, Content Trends |

---

## ⚙️ Core Workflow

```text
  [ Search ]
      │
      ▼
┌──────────────────────────┐
│ Collect Public Info      │  (Web, Social, News)
└─────────────┬────────────┘
              │
              ▼
┌──────────────────────────┐
│ Organize & Validate      │  (Structuring Sources & Evidence)
└─────────────┬────────────┘
              │
              ▼
┌──────────────────────────┐
│ AI Analysis & Insights   │  (OpenRouter Processing)
└─────────────┬────────────┘
              │
              ▼
┌──────────────────────────┐
│ Generate Core Card       │  (Unified Dashboard View)
└─────────────┬────────────┘
              │
              ▼
  [ Save ] ──► [ Monitor ] ──► [ Export Report ]
  ```

## 🚀 Key Features (MVP)

* **Unified Multi-Source Search:** Query by Company Name, Brand, Product, Influencer handle, or URL.
* **Comprehensive Investigation Cards:** Consolidates overview, evidence, AI confidence scores, source links, and entity relationships into a single view.
* **Automated AI Intelligence:** Instantly generate executive summaries, SWOT analyses, risk assessments, and even content/reel scripts.
* **Continuous Monitoring:** Set alerts for news, product updates, campaign launches, and competitor movements.
* **Report Generation:** Export structured reports for client decks or internal reviews.
* **Modern Mobile-First UI:** Minimalist, card-based dark theme optimized for speed and clarity.

---

## 🛠 Tech Stack

* **Frontend:** [Flutter](https://flutter.dev/) (Cross-platform, mobile-first design)
* **AI Orchestration:** [OpenRouter API](https://openrouter.ai/)
* **Backend:** Lightweight REST API for request handling and asynchronous data processing
* **Data Gathering:** Automated public source ingestion with optional Python-based scraping services

---

## 🎨 UI & Design Principles

* **Palette:** Deep Navy, Accent Blue, and Clean White
* **Theme:** Native Dark Mode with high contrast and premium typography
* **Layout:** Card-based architecture focused on quick scannability and clean spacing

---

## 🗺 Application Architecture (Screens)

* **Dashboard (Home):** Quick search bar, recent investigations, active AI queues, and monitoring updates.
* **Investigation View:** Multi-tab view covering Overview, Sources, Evidence, Relationships, Timelines, and AI Summaries.
* **Monitoring Hub:** Real-time updates on saved entities.
* **Reports & Settings:** Custom report builder, export options, theme settings, and API configuration.

---

## 📄 License

Distributed under the MIT License. See `LICENSE` for more information.