# Food Desk specification — PDF export

The main specification is **`FOOD_DESK_SPECIFICATION.md`**. It includes all functions and user scenarios for the Food Desk mobile app.

## How to generate a PDF

### Option 1: VS Code / Cursor (recommended)

1. Install the **Markdown PDF** extension (by yzane).
2. Open `FOOD_DESK_SPECIFICATION.md`.
3. Right-click in the editor → **Markdown PDF: Export (pdf)**.
4. The PDF is created in the same folder (or as set in the extension settings).

### Option 2: Pandoc (command line)

If you have [Pandoc](https://pandoc.org/) installed:

```bash
cd docs
pandoc FOOD_DESK_SPECIFICATION.md -o FOOD_DESK_SPECIFICATION.pdf
```

For better formatting you can use a PDF engine:

```bash
pandoc FOOD_DESK_SPECIFICATION.md -o FOOD_DESK_SPECIFICATION.pdf --pdf-engine=xelatex
```

### Option 3: Online converter

1. Open [md2pdf](https://www.md2pdf.com/), [CloudConvert](https://cloudconvert.com/md-to-pdf), or similar.
2. Upload `FOOD_DESK_SPECIFICATION.md`.
3. Download the generated PDF.

---

The specification covers:

- All user roles (Customer, Supplier, Admin)
- Every screen and route
- All functions per role
- User scenarios (step-by-step flows)
- Order and pool rules
- How to export to PDF
