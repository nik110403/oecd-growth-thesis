# Replication package

**Thesis:** The Determinants of Economic Growth after the Global Financial Crisis in OECD Countries
**Author:** Nik Khosravipour
**Post:** https://nikkhosravipour.com/post/the-determinants-of-economic-growth-after-the-global-financial-crisis-in-oecd-countries
**Data:** Penn World Table 11.0; World Bank WDI (population growth, cross-check only; vintage below)
**Sample:** 24 pre-1995 OECD members, 1996–2019, balanced panel (576 observations)

## How to run

All scripts use paths relative to this folder, so run them **from this directory**.

```r
# 1. Install packages once (R >= 4.2 recommended)
Rscript 03_code/00_install_packages.R

# 2. Run the pipeline in order
Rscript 03_code/01_load_pwt.R           # filter PWT 11.0 to the 24-country sample
Rscript 03_code/02_load_wdi.R           # reads the pinned raw WDI pull (offline); add --live to re-pull from the API
Rscript 03_code/03_construct_variables.R
Rscript 03_code/04_merge_check.R
Rscript 03_code/05_descriptives.R
Rscript 03_code/06_regressions.R        # two-way FE regressions + structural-break tests
Rscript 03_code/07_tables_figures.R
Rscript 03_code/08_diagnostics.R
Rscript 03_code/09_projections.R
```

## Data vintages

- **PWT 11.0**: fixed release, downloaded 2026-03-25 (`02_data/raw/pwt110.dta`).
- **WDI population growth (SP.POP.GROW)**: the thesis results rest on the pull made in June 2026,
  stored processed in `02_data/processed/wdi_popgrowth.rds` (exact day not recorded). A later raw
  pull, **downloaded 2026-10-01** (WDI last_updated 2026-07-13), is pinned in
  `02_data/raw/wdi/2026-10-01/`. It differs from the June vintage in 9 of 600 values (GBR 2013-2019,
  ITA 2018-2019; max absolute difference 0.452 percentage points, ITA 2018/2019). WDI is used only
  as a cross-check (`04_merge_check.R`) and as the `pop_growth_wb` column of `panel_final.csv`;
  no regression or table depends on it. The processed file was deliberately NOT replaced.
- Step 02 reads the pinned raw pull offline (`--live` re-pulls the API into a new dated folder).
  Running step 02 therefore overwrites `wdi_popgrowth.rds` with the 2026-10-01 vintage; to keep the
  thesis vintage exactly, skip step 02 and run from step 03 (or restore the shipped file).
- `05_figures/projections.png` and `projection_convergence.png` are the 2026-06-26 re-render
  (step 09 now also writes the convergence scatter).

## Layout

- `03_code/` — the R pipeline (`00`–`09`) and a per-script `README.md`.
- `02_data/raw/` — `pwt110.dta` (PWT 11.0 input); `wdi/<date>/` pinned raw WDI pull.
- `02_data/processed/` — generated `.rds`/`.csv` panels and fitted models (included so outputs
  can be inspected without re-running).
- `02_data/documentation/data_sources.md` — variable provenance.
- `05_figures/`, `06_tables/` — generated figures and tables (the exhibits in the thesis PDF).

## Method (one line)

Annual within-country two-way fixed-effects growth regression on the augmented Solow
determinants, with the post-2008 break entering through slope interactions; CR2 cluster-robust
standard errors with Satterthwaite degrees of freedom (24 clusters), Driscoll-Kraay as a
secondary check, and an unknown-date sup-Wald scan. See `03_code/README.md` for details.

## License and citation

Code and text: CC-BY-4.0 (see `LICENSE`; PWT 11.0 is CC-BY-4.0 by Feenstra, Inklaar and Timmer,
redistributed with attribution). Citation metadata: `CITATION.cff`.
