# Code notes

## Status
Full pipeline (01–09) runs end-to-end. Verified 2026-06-16 on a 24×24 balanced panel
(576 obs, no missing key variables). Run all scripts **from the project root** — paths are
relative to it. Run `00_install_packages.R` once first. (04 writes the CSV with base
`write.csv` rather than `readr::write_csv`, so it does not depend on the `vroom` shared library.)

## Scripts

### 01_load_pwt.R
Loads pwt110.dta (PWT 11.0) from 02_data/raw/ using haven::read_dta().
Filters to 24 OECD pre-1995 members and years 1995–2019.
Keeps only: countrycode, country, year, rgdpna, pop, hc, csh_i, emp.
Saves to 02_data/processed/pwt_filtered.rds.

Countries included:
AUS AUT BEL CAN DNK FIN FRA DEU GRC IRL ITA JPN
NLD NZL NOR PRT ESP SWE CHE TUR GBR USA MEX ISL

Sample notes:
- Turkey (TUR) and Mexico (MEX) borderline — kept in main sample, dropped in robustness.
- Iceland (ISL) IS in the main sample; robustness check drops it. Luxembourg excluded.

### 02_load_wdi.R
Reads the pinned raw WDI pull (SP.POP.GROW, 24 countries, 1995-2019) from the latest dated folder
in 02_data/raw/wdi/ (no internet needed). `Rscript 03_code/02_load_wdi.R --live` instead pulls the
World Bank API via wbstats, saves a new dated raw folder and proceeds from it.
Saves to 02_data/processed/wdi_popgrowth.rds. Caution: the shipped processed file is the June 2026
pull the thesis used; the pinned raw pull (2026-10-01) is a later vintage (9 of 600 values differ,
max abs. difference 0.452 pp), so re-running 02 overwrites it with the later vintage. WDI enters
only the cross-check in 04 and the `pop_growth_wb` column of panel_final.csv, not any table.

### 03_construct_variables.R
Constructs all analysis variables from pwt_filtered.rds:
- gdppc       = rgdpna / pop               (GDP per capita, mn 2017 USD)
- gdppc_growth = (gdppc - lag) / lag       (dependent variable)
- inv_share   = csh_i                      (investment share, direct from PWT)
- ln_hc       = log(hc)                    (log human capital index)
- pop_growth_pwt = (pop - lag) / lag       (BASELINE labour input — Solow n)
- emp_growth  = (emp - lag) / lag          (robustness only — procyclical/endogenous)
- ln_gdppc_lag = log(lag(gdppc))           (convergence term for Solow)
- post_2008   = 1 if year >= 2008
- post_2010   = 1 if year >= 2010          (alternative break date — both reported)

1995 dropped due to lagging — panel runs 1996–2019.
Saves to 02_data/processed/panel_constructed.rds.

### 04_merge_check.R
Merges WDI population growth onto the PWT panel; cross-checks emp vs pop growth correlation
and merge completeness. Saves 02_data/processed/panel_final.rds (+ .csv).

### 05_descriptives.R
Summary-statistics table -> 06_tables/descriptives.md (Pandoc markdown, {#tbl:desc} caption);
pre/post-2008 descriptive panel -> 06_tables/descriptives_prepost.md ({#tbl:descpp}: sample means
and SDs before vs after 2008, the headline 2.5% -> 0.6% level shift and 1.9 -> 2.9pp volatility rise);
panel balance check; descriptive figures -> 05_figures/growth_trend.png, growth_prepost.png,
growth_by_country.png.

### 06_regressions.R
Two-way FE conditional-growth regressions (plm) + post-2008 structural-break tests.
- Baseline (population growth) + CR2 cluster-robust SEs (clubSandwich) and Driscoll-Kraay.
- Known-date break (post_2008 / post_2010 interactions) + joint CR2 Wald test.
- Unknown-date break: sup-Wald scan over candidate years 2001–2015 (Andrews 1993; Bai 1998).
- Per-coefficient minimum detectable effect (MDE) for the post-2008 interactions at 80% power
  (two-sided 5%, Satterthwaite df): the investment-interaction MDE is 0.169, above the baseline
  investment slope of 0.163 — the quantified power limitation reported in the Discussion.
- Split-sample per the thesis agreement: pre (1996–2007) vs post (2010–2019), 2008–09 excluded.
- Robustness: drop IRL / TUR+MEX / ISL; employment-growth labour var; lagged investment share
  (inv_share_lag, breaks the contemporaneous-simultaneity feedback); difference GMM (pgmm).
Saves fitted objects to 02_data/processed/models.rds. See 01_notes/02_method_notes.md.

### 07_tables_figures.R
Pandoc markdown tables with crossref captions -> 06_tables/regressions.md (incl. the lagged
investment-share column), robustness.md, splitsample.md, gmm.md; per-year sup-Wald scan ->
06_tables/supwald.md ({#tbl:supwald}) and 05_figures/supwald_scan.png (so the unknown-break result
is verifiable, not asserted); post-2008 coefficient plot -> 05_figures/break_coefficients.png
(CR2 95% CIs using Satterthwaite t critical values). All tables use CR2 SEs.

### 08_diagnostics.R
Panel diagnostics -> 06_tables/diagnostics.txt: Hausman (FE vs RE), Pesaran CD on BOTH the
one-way FE model (raw dependence, z = 34.9) and the two-way estimating specification (net of
year effects, z = -0.42, n.s.), Wooldridge/Breusch-Godfrey serial-correlation tests.

### 09_projections.R
Conditional long-run projections (the thesis-agreement final step). Full-sample slopes iterated
2020–2045 from observed 2019 levels; regressors held at 2015–19 country means; common era
component drawn from pre-crisis / post-crisis / full windows. The split-window models are NOT
iterated forward (their convergence terms are Nickell-dominated at T = 10–12).
-> 05_figures/projections.png, 02_data/processed/projections.rds.

## Decisions resolved
1. PWT version: **11.0**.
2. Labour variable: **population growth** baseline, employment growth robustness.
3. Standard errors: **CR2** (primary) + Driscoll-Kraay (secondary) — not plain clustered (24 clusters).
4. TUR/MEX & ISL: **kept** in main sample, dropped in robustness.

## Still to decide
- Headline break date (2008 vs 2010) — both reported; sup-Wald scan informs it.

## Packages used
Loaded as individual tidyverse components (not the meta-package, which needs system font
libraries): dplyr, tidyr, readr, purrr, stringr, tibble, ggplot2.
Plus: haven, wbstats, skimr, stargazer, plm, clubSandwich, car.