# Reproduce every number in the README. DATA must point at the unzipped DocILE annotated-trainval.
DATA ?= data
MODEL ?= claude-sonnet-5-5
PY = python3 -W ignore -m

.PHONY: test coverage inject run report audit trace site all
test:      ; pytest -q
coverage:  ; $(PY) ledgerproof.coverage $(DATA) --split train --out reports
inject:    ; $(PY) ledgerproof.inject $(DATA) --split val --out reports
run:       ; $(PY) ledgerproof.run $(DATA) --model $(MODEL) --split val   # needs ANTHROPIC_API_KEY; cached after the first run
report:    ; $(PY) ledgerproof.report $(DATA)
audit:     ; $(PY) ledgerproof.audit $(DATA) run --model $(MODEL)
trace:     ; $(PY) ledgerproof.trace $(DATA) 48f7d5b440cd46a0bca2db5d --plant-uid 9 --plant-text '$$1,800.00' && cp docs/results.json reports/injections_val_summary.json site/public/data/
site:      ; cd site && npm ci && npm run build
all: test coverage inject run report
