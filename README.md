# LLM-Powered Analytics & RAG Dashboard

Ask business questions in plain English and get grounded, source-cited answers drawn from both **structured data** (SQL tables) and **unstructured text** (customer reviews).

**Stack:** Python · SQL (SQLite) · LangChain · OpenAI API · FAISS · Streamlit · Tableau

> 📊 **Live Tableau dashboard:** _[link coming soon]_
> 🎥 **Demo:** _[GIF / screenshot coming soon]_

---

## What it does

| You ask | The system | You get |
|---|---|---|
| "What was revenue in Nov 2017?" | Writes and runs a read-only SQL query | The number, plus the SQL it ran |
| "Why do customers complain about delivery?" | Searches ~40k reviews semantically with FAISS | A summary citing the reviews it used |
| "Which category has the worst reviews, and why?" | Runs SQL to find the category, then RAG to explain it | Data plus supporting quotes |

A **query router** (one LLM classification call) decides which path each question takes.

## Architecture

```
          Olist CSVs (orders, payments, products, reviews, ...)
                 │
        ┌────────┴──────────┐
        ▼                   ▼
  SQLite warehouse     Review text
  + KPI views          → chunk → embed → FAISS index
        │                   │
        ▼                   ▼
   Text-to-SQL          Retriever (MMR + metadata filters)
        └─────────┬─────────┘
                  ▼
     Query Router (LLM): sql | docs | both
                  ▼
     Grounded answer with citations → Streamlit chat UI

  KPI views → CSV export → Tableau dashboard
```

## Project structure

```
LLM-RAG/
├── app.py                  # Streamlit chat interface
├── src/
│   ├── load_db.py          # Load raw CSVs into SQLite and create KPI views
│   ├── export_tableau.py   # Export KPI views to CSV for Tableau
│   ├── build_index.py      # Embed review text and build the FAISS index
│   ├── rag.py              # Retrieval and grounded answer generation
│   ├── text_to_sql.py      # Natural language → read-only SQL
│   └── router.py           # Route questions to SQL / RAG / both
├── sql/
│   └── kpis.sql            # KPI view definitions
├── eval/
│   ├── questions.json      # Labeled evaluation questions
│   └── run_eval.py         # Retrieval, faithfulness, and routing metrics
└── data/                   # Not tracked in git (see Setup)
    └── raw/
```

## Setup

**Requirements:** Python 3.11+ and an OpenAI API key.

```bash
git clone <your-repo-url>
cd LLM-RAG
python3.11 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

Create a `.env` file in the project root:

```
OPENAI_API_KEY=sk-...
```

### Data

The dataset isn't included in this repo because of its size and license.

1. Download the [Olist Brazilian E-Commerce dataset](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce) from Kaggle.
2. Unzip the CSVs into `data/raw/`.
3. Build the database and the vector index:

```bash
python src/load_db.py          # → data/olist.db
python src/build_index.py      # → index/faiss_reviews (embedding cost < $1)
python src/export_tableau.py   # → data/tableau/*.csv
```

## Usage

```bash
streamlit run app.py
```

Example questions to try:

- What was the average order value per month in 2017?
- What do customers say about late deliveries?
- Which product category has the lowest average review score, and what are the common complaints?
- What is our refund policy for international orders? _(unanswerable, so the app should say it doesn't know)_

Each answer shows how it was produced: the route taken, the SQL query and result table, and/or the source reviews it cited.

## How it works

### 1. SQL analytics layer
Raw CSVs are loaded into SQLite. `sql/kpis.sql` defines KPI views such as monthly revenue, orders, average order value, on-time delivery rate, and review score by category. The same views feed both the Tableau dashboard and the text-to-SQL engine, so the dashboard and the chatbot report the same numbers.

### 2. Semantic search (RAG)
Review comments are wrapped as LangChain `Document`s with metadata (`review_id`, `order_id`, `score`), embedded with `text-embedding-3-small`, and stored in a local FAISS index. Retrieval uses **MMR** (maximal marginal relevance) so the results are relevant but not near-duplicates, and supports **metadata filters**, for example only 1-star reviews.

### 3. Text-to-SQL
The LLM gets the database schema and writes one SQLite query. Two safety measures:
- The database connection is opened **read-only** (`mode=ro`).
- Anything that isn't a `SELECT`/`WITH` statement is rejected.

### 4. Query router
A low-cost, few-shot LLM call labels each question `sql`, `docs`, or `both`. RAG can't reliably do arithmetic, and SQL can't read opinions, so sending each question to the right engine is the first defense against hallucination.

### 5. Prompt design for grounding
The answer prompt tells the model to:
- answer **only** from the retrieved sources,
- cite sources inline (`[1]`, `[2]`),
- reply "I don't have enough information" when the sources don't cover the question,
- respond in English (the source reviews are in Portuguese).

## Evaluation

`eval/questions.json` contains about 30 labeled questions: SQL questions with known answers, topical review questions, and deliberately unanswerable questions.

```bash
python eval/run_eval.py
```

| Metric | What it measures |
|---|---|
| Router accuracy | Was the question sent to the correct engine? |
| SQL accuracy | Did the generated query return the correct result? |
| Precision@k | Fraction of retrieved chunks that are relevant |
| Faithfulness | Share of answers whose claims are all supported by the sources (LLM judge) |
| Correct refusals | Share of unanswerable questions where the model declined instead of guessing |

### Results

_Fill in after running experiments._

| Configuration | Router acc. | Precision@6 | Faithfulness | Correct refusals |
|---|---|---|---|---|
| Baseline (similarity search, k=4, plain prompt) | – | | | |
| + MMR, k=6 | | | | |
| + Metadata filters | | | | |
| + Grounding prompt with citations | | | | |

## Tableau dashboard

Built from the exported KPI views:

- **KPI tiles:** revenue, orders, average order value, on-time delivery %
- **Trends:** monthly revenue and order volume
- **Categories:** revenue vs. average review score
- **Geography:** late-delivery rate by state

_[Screenshot and Tableau Public link coming soon]_

## Limitations & next steps

- Text-to-SQL can still produce wrong but valid queries; showing the SQL lets users verify it.
- The source reviews are in Portuguese; answer quality depends on the model's translation.
- Possible extensions: a reranker (e.g. a cross-encoder), hybrid keyword + vector search, conversation memory, and adding long-form documents such as policies and reports.

## Data source

[Olist Brazilian E-Commerce Public Dataset](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce) (CC BY-NC-SA 4.0).
