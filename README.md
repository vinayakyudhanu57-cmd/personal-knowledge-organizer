# Personal Knowledge Organizer

A clean, functional personal knowledge-management application built with an **R backend** and a modern, responsive **vanilla HTML/CSS/JavaScript frontend**. It enables users to save, organize, search, filter, and revisit notes, concepts, tutorials, articles, and references.

Its key distinguishing feature is **Related Notes Discovery**: the application identifies notes connected through shared tags, calculates transparent overlap scores using set theory in R, and explains exactly why the items are related.

---

## 1. Main Features

- **Full Knowledge Lifecycle**: Add, view, edit, and delete notes, concepts, articles, websites, tutorials, and books.
- **Related Notes Discovery**: Computes set intersection and weighted Jaccard similarity across note tags in base R, providing a deterministic match score and clear natural-language explanation.
- **Search & Multi-Criteria Filtering**: Case-insensitive keyword matching across titles and note contents, combined with filters for Topic, Item Type, Tags, and Importance.
- **Reliable CSV Persistence**: Persistent data storage in `data/knowledge_items.csv` with RFC 4180 quotation handling for newlines, quotes, commas, and Unicode characters.
- **Curated Digital Library UI**: Distinctive warm ivory and muted teal light theme styled after a personal notebook, with quick tag filtering, collapsible overview dashboard, and modal detail views.
- **Zero Heavy Dependencies**: Pure base R logic, minimal `plumber` and `jsonlite` API integration, and vanilla JavaScript without client-side frameworks.

---

## 2. Technology Stack & R Concepts Used

- **R (>= 4.0.0)**:
  - **Lists & Data Frames**: Structured representations of knowledge items.
  - **String Operations**: Keyword matching (`grepl`), regex sanitization, and tag normalization (`strsplit`, `gsub`, `trimws`).
  - **Set Operations**: Tag comparisons using `intersect()`, `union()`, and `unique()`.
  - **Vectorized Functional Transforms**: Type-safe processing using `vapply()`, `lapply()`, and `order()`.
  - **CSV File I/O**: `read.csv()` and `write.csv()` with strict encoding and column preservation.
- **Plumber & jsonlite**: Lightweight HTTP REST API routing and JSON serialization.
- **HTML5 / CSS3 / Vanilla JavaScript**: Semantic structure, responsive grid layout, and interactive client communication without external UI libraries.

---

## 3. Related Notes Discovery Algorithm

The Related Notes Discovery system is **deterministic, explainable, and grounded in set theory** (no artificial intelligence, embeddings, or external APIs are used):

1. **Tag Extraction**: For any target note $A$, extract its normalized tag set $T_A$.
2. **Set Intersection**: For each candidate note $B$ ($B \neq A$) with tag set $T_B$, compute the shared tags:
   $$S = T_A \cap T_B$$
3. **Filtering**: If $|S| = 0$, note $B$ is excluded from the related notes list.
4. **Weighted Overlap Score**:
   - Each tag $t$ receives a specificity weight based on its inverse frequency in the knowledge base:
     $$w(t) = 1 + \ln\left(\frac{N + 1}{\text{freq}(t) + 1}\right)$$
   - The match percentage is computed as the weighted Jaccard ratio:
     $$\text{Score}(A, B) = \text{round}\left(\frac{\sum_{t \in S} w(t)}{\sum_{t \in T_A \cup T_B} w(t)} \times 100\right)$$
5. **Transparent Explanation**: For each discovered note, the system outputs the shared tags, match percentage, and a plain explanation (e.g., *"Shares 2 tags ('r', 'architecture') — 28% weighted tag overlap (33% Jaccard index)."*).

---

## 4. Folder Structure

```text
personal-knowledge-organizer/
├── .gitignore               # Ignored R session and OS files
├── README.md                # Project documentation and instructions
├── R/
│   ├── functions.R          # Core business logic, search, set math, CSV handling
│   └── main.R               # Plumber API server, CLI demo, and test runner
├── data/
│   └── knowledge_items.csv  # Persistent CSV data storage
├── screenshots/             # Application screenshots
├── tests/
│   └── test-cases.md        # Comprehensive test specification matrix
└── web/
    ├── index.html           # Semantic HTML structure & accessible modals
    ├── style.css            # Light theme styling (warm ivory, muted teal, sage)
    └── script.js            # Vanilla JS API client & real-time search
```

---

## 5. Setup and Execution (Windows)

### Prerequisites
- **R (version 4.0 or higher)** installed on Windows (e.g. from [CRAN](https://cran.r-project.org/)).
- Required R packages: `plumber` and `jsonlite`.

To install the required R packages, open Windows Command Prompt or PowerShell and run:
```powershell
Rscript -e "install.packages(c('plumber', 'jsonlite'), repos='https://cloud.r-project.org')"
```

### Running the Web Application
Navigate to the project directory and start the server:
```powershell
cd C:\Users\DELL\Desktop\r_projects\personal-knowledge-organizer
Rscript R/main.R
```

Once started, open your web browser and navigate to:
```text
http://127.0.0.1:8000
```

To stop the server, press `Ctrl + C` in the terminal.

---

## 6. CLI Demo & Automated Testing

### Running the Automated Test Suite
To execute the comprehensive test suite covering data loading, tag normalization, search, validation, related notes scoring, and CRUD persistence:
```powershell
Rscript R/main.R --test
```
*(All 31 test assertions will run and report status.)*

### Running the Terminal Demo
To preview sample data search and tag-based related notes discovery directly in your terminal:
```powershell
Rscript R/main.R --demo
```

---
