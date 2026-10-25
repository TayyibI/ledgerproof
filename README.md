# Ledgerproof

**How much do checks with no opinion catch when a language model extracts real business documents?**

A model reads a document and proposes values, each with the OCR words it took them from. Then
deterministic judges (arithmetic, checksums, calendars) either prove each value consistent with the
rest of the page or decline to. A commit policy decides what gets written without a person. Nothing
here asks a model whether another model was right.

Everything is measured on 500 held-out documents from the
[DocILE benchmark](https://github.com/rossumai/docile): real invoices and orders with human labels.

[![The one-minute film: one invoice through the pipeline, then 500. Click to watch on YouTube.](docs/film-preview.gif)](https://youtu.be/DdQvodrPBPE)

**[Watch the one-minute film on YouTube](https://youtu.be/DdQvodrPBPE)** (56 s; the animation above is a silent preview). The film is rendered from the run's own data files; the [mp4 is also in this repo](docs/ledgerproof-film.mp4).

What each commit policy costs<img width="1280" height="736" alt="tradeoff" src="https://github.com/user-attachments/assets/a59bf23f-558c-4c7d-b98a-ce1e454766bb" />


## Result

On 500 held-out documents, with Claude Sonnet 5.5 and Claude Haiku 5.5 proposing the values:

| model | policy | values written | disagree with the human label | errors kept from the system | correct values automated |
|---|---|---:|---:|---:|---:|
| Sonnet 5.5 | commit everything | 4,132 | 246 (6.0%, 95% CI 4.9–7.2) | 0% | 100% |
| Sonnet 5.5 | commit unless a judge objects | 3,757 | 212 (5.6%, 4.6–6.9) | 14% | 91% |
| Sonnet 5.5 | **commit only verified** | 2,116 | **44 (2.1%, 1.3–3.2)** | 82% | 53% |
| Haiku 5.5 | commit everything | 5,385 | 326 (6.1%, 5.0–7.3) | 0% | 100% |
| Haiku 5.5 | commit unless a judge objects | 4,823 | 260 (5.4%, 4.3–6.6) | 20% | 90% |
| Haiku 5.5 | **commit only verified** | 2,668 | **50 (1.9%, 1.2–2.7)** | 85% | 52% |

Intervals come from a bootstrap over documents. On the 480 documents that the 20-document pilot never
touched, every silent rate is within 0.2 points of these (`docs/results.json`).

The page crops show more than the label comparison does. A first-pass audit (see *Audit* below)
looked at all 44 values that Sonnet's strict policy wrote against the human label:

- **none is a misread number.**
- 19 are the same naming question: on agency invoices that print *Gross → commission → Net*,
  which one is "the gross total". DocILE's own labels answer it both ways.
- 17 are cases where the model's value is right and the label or line alignment is off. For
  example, a Rate column labelled as *line tax*: the model filed "$20" (2 spots × $20 = $40) as
  the unit price, which is right.
- 5 are a single tax row filed as the tax total.
- 3 are unclear.

The real misreadings, such as an OCR digit copied faithfully, a broken span or the wrong date
picked, sit in the values that no judge could verify. In a random 40 of the 202 such errors,
**15 are clearly real and 3 more probably are**. The strict policy sends all of them to a person.

What that means:

- **A verified value is almost never a misread one.** Planting one realistic error into a value
  the judges had verified leaves it verified 1.5% of the time (258 of 17,298), as the second chart
  shows. Arithmetic does not care how plausible a wrong digit looks.
- **The judges are a certificate, not a filter.** Committing everything a judge doesn't object to
  removes only 14–20% of errors. Most errors fall on values that no identity reaches: dates,
  references, a total printed alone. The judges' value is that they certify about half of the
  correct values, so a person reviews the rest instead of everything.
- **Arithmetic cannot check a name.** If the model files the right number under the wrong field
  ("Net" as `amount_total_net` when the schema means the payable), every identity still holds.
  That has to be settled in the field definitions, not by a judge.
- **Review is not eliminated.** Every document has a date, and no deterministic check verifies a
  date. So only 3–4% of documents pass with every value verified. The judges shrink each review to
  the unverifiable fields.
- **The cheap model is enough here.** Haiku 5.5 matched Sonnet 5.5 within the intervals on every
  rate and proposed more values, for about a tenth of the cost: $0.56 against $6.19 for 500
  documents. Both are estimates from token counts and list prices; Haiku's is a lower bound, since
  its listed price is a "from" price.

![Planted errors](docs/injection.png)

## How it works

```
OCR words ──► model proposes {field, value, cited word ids}   (strict JSON schema)
          ──► grounding: the value must equal the cited words
          ──► judges: pass / fail / abstain, and which printed values each pass used
          ──► status per value: verified · flagged · unchecked ──► commit policy
```

| judge | identity |
|---|---|
| `line_arithmetic` | quantity × unit price (− discount) = line amount; per-100 or per-1,000 pricing only with evidence on the line |
| `line_tax` | line net + tax = gross, or net × (1 + rate) = gross |
| `lines_sum` | line amounts add up to the total, subtotal rows excluded |
| `net_tax_gross` | total net + total tax = total gross |
| `tax_details` | tax rows: net × rate = tax, and the rows sum to the totals |
| `amount_due` | total gross − paid = amount due |
| `repeated_totals_agree` | a total printed twice shows one value |
| `iban_checksum` | ISO 13616 mod 97 |
| `date_order` | due date not before issue date (flags only; see below) |

Rules that keep a pass honest:

- **Tolerances come only from printed precision.** A value written to cents is exact to half a
  cent. Unit prices are exact: 99.6% of labelled training lines match to the cent.
- **Ambiguous numbers are resolved by evidence from the same document.** For example, `1,234`
  is read using the decimal separator the rest of the document uses.
- **A pass vouches only for the printed values its identity used**, not for every field it read.
- **A pass that uses one printed word on both sides vouches for nothing.** For example, a "line
  item" that is the total's own word.
- **One domain rule, found on the training split:** US broadcast invoices state gross before and
  net after a 15% agency commission. Every pass that relies on it says so.

## How it was measured

- **Data.** DocILE annotated train (5,180 documents) for all development; validation (500) held
  out. Before building anything I set a kill criterion: at least half the training documents must
  allow an arithmetic check. 3,885 of 5,180 (75%) did.
- **Truth.** Each proposed value is *correct*, *wrong* (the field is labelled there and the value
  contradicts it), *mislabelled* (the cited words sit on a label of a different field: a real
  value under the wrong name) or *unlabelled*.
  - DocILE does not label every printed value. Unlabelled values are kept out of the rates and
    audited by sample.
  - Three conventions are not errors: net vs gross for a line; net vs gross for a total on a
    tax-free document; and unit price vs amount on a line that prints one money value and no
    quantity.
  - Scoring the human labels against themselves gives 6,870 of 6,870 correct.
- **Error injection.** One realistic error at a time is planted into real labelled documents, and
  the frozen judges are rerun. The error types were fixed before any result: transposed digits,
  OCR digit confusion, dropped digit, lost decimal separator, sign flip, value from the
  neighbouring row, another total, day/month swap.

## Development log

What broke, and what changed. Git tags mark each freeze.

1. **Calibrating on train labels.** Judges fail on human labels too, and early on they failed
   often:

   | judge | false alarms, before → after |
   |---|---|
   | `lines_sum` | 25.6% → 17.4% |
   | `line_tax` | 46.6% → 1.4% |
   | `net_tax_gross` | 26% → 15% |

   The fixes were the agency-commission rule, subtotal rows and tax-free lines. Many of the
   remaining failures are OCR errors in the labels themselves ("110400" for 1,104.00).
2. **First validation injection: 21.3% silent.**
   - The judges let through:

     | error or field | silent |
     |---|---:|
     | sign flips | 55% |
     | corrupted quantities | 47% |
     | corrupted unit prices | 39% |
     | lost decimal separators | 31% |

   - Causes: free ×0.01/×0.001 price scales, a rounding allowance on unit prices, a pass crediting
     every field it read, and no sign check.
   - I fixed them using train data only, then reran validation once: **2.5% silent** (tag
     `judges-v1`). Validation has therefore been looked at twice for the judges. The second look
     only tested fixes made on train.
3. **Attribution (`judges-v2`).** On train, 41–43% of corrupted dates were still "verified":
   `date_order` passed on other copies of the date and got credit for one it never parsed.
   - Every pass now records the exact printed values it used.
   - `date_order` can flag but never verify.
   - Verdicts did not change. Validation injection went to **1.5% silent**.
4. **Model pilot (first 20 validation documents).** Scoring by value alone counted label gaps
   and conventions as model errors. That led to the four truth categories, location matching for
   *mislabelled*, and the self-agreement rule. Results are also reported without these 20
   documents.
5. **Full validation run.** Two scoring artifacts were found and fixed:
   - "3Spots": the OCR glues a unit onto the number, and the label selects only the 3.
   - Single-price lines.

   Both fixes turned "errors" into correct values. Most of those errors had been counted as
   *caught* under the strict policy, so the fixes make the judges look worse, not better. The
   scorer was then frozen.

## Known blind spots

- **Swapping a total for another total on the same page:** 16.5% silent. Swapping gross for
  net-after-commission is invisible because the commission rule accepts both.
- **The sign of a payment.** It is read as an absolute value, because both conventions occur.
- **Names.** Above: the judges certify numbers, not which field a number belongs to.
- **Dates** are never verified, so they always go to review.
- **The data.** US documents only (political TV-ad invoices and tobacco-litigation archives), old
  and typed. The one domain rule comes from that world.
- **The audit is a first pass by Claude**, an AI model, made from page crops. It still has to be
  confirmed by hand (see *Audit*).

## Audit

The audit sheets are local HTML pages, one verdict per case with a download button:

- `python -m ledgerproof.audit data run --model claude-sonnet-5-5` covers every value the strict
  policy wrote against the label, plus a sample of the unlabelled ones.
- `python -m ledgerproof.audit data labels` covers judge failures on the human labels.

They embed DocILE page crops, so they are written to `audit/` and not committed.
The first-pass classification (document ids and categories only) is in
`reports/audit_first_pass_claude-sonnet-5-5.json`.

## Run

```bash
pip install -e ".[dev,models,report]"
pytest                                   # 42 tests, including property-based ones

# DocILE (token from https://docile.rossum.ai; keep it out of the repo)
./download_dataset.sh "$DOCILE_TOKEN" annotated-trainval data --unzip   # script from the DocILE repo

python -m ledgerproof.coverage data --split train          # how much is checkable
python -m ledgerproof.inject data --split val              # error injection, frozen judges
python -m ledgerproof.run data --model claude-sonnet-5-5 --split val   # needs ANTHROPIC_API_KEY
python -m ledgerproof.report data                          # tables, intervals, charts
```

- Responses are cached by a hash of (model, prompt, document), so a rerun is free and gives
  identical numbers.
- The API call does not set a temperature, so a new run can differ slightly.
- Sonnet processed 500 documents in under 4 minutes with 8 parallel requests.

## Demo site and film

`site/` replays one real document through the pipeline, then the 500-document results. Every
number on it is read from files the pipeline writes; nothing is typed in by hand.

```bash
make trace                 # export one document's run (needs DocILE) and copy the result files
cd site && npm ci && npm run build
python3 -m http.server 4173 --directory dist &   # dist/index.html: the site; dist/video.html: the film
python3 scripts/render_film.py                    # renders the film frame by frame (Playwright + ffmpeg)
```

The site shows the scanned DocILE page and the OCR trace, so those two files are gitignored and
the site is not hosted publicly until the dataset's organisers confirm it can be shown. The film
shows the values re-typeset, not the scan, and is the public version of the same story.

## Data

DocILE is not redistributed here. `tests/fixtures/docile-sample` holds one annotation file from the
MIT-licensed DocILE repository. Committed reports contain aggregates, document ids and categories,
not document content.
