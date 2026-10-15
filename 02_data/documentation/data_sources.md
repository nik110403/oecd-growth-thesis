# Data Sources

## PWT
Version: 11.0
Date downloaded: 03/25/2026
URL: https://www.rug.nl/ggdc/productivity/pwt/?lang=en

## WDI (cross-check only)
Indicator: SP.POP.GROW (population growth, annual %), World Bank WDI via R package wbstats.
Thesis vintage: pulled June 2026 (exact day not recorded), stored in 02_data/processed/wdi_popgrowth.rds.
Pinned later pull: 2026-10-01 (WDI last_updated 2026-07-13), raw CSV in 02_data/raw/wdi/2026-10-01/.
9 of 600 values differ from the thesis vintage (GBR 2013-2019, ITA 2018-2019); max abs. difference 0.452 pp.

## Known data quality issues

### Ireland — distorted national accounts
IRL 2015 shows gdppc_growth = 23.4%, driven by multinational IP relocation
("leprechaun economics"). IRL 2016–2019 also show implausibly high inv_share
(45–64%) for the same reason. These are genuine CSO Ireland measurement issues,
not errors in PWT. Main sample retains IRL; robustness check excludes it.
Reference: Fitzgerald (2018), Irish national accounts and globalisation.

### Turkey — structural outlier
TUR 2001 (−6.9%) reflects the Turkish banking and currency crisis.
TUR growth volatility is high relative to Western European core.
Retained in main sample; robustness check excludes TUR.

### Iceland — micro-state volatility
ISL inv_share 2005–2006 (47–56%) reflects pre-crisis construction/banking boom.
ISL 2009 (−8.0%) reflects the bank collapse. Population ~300,000.
Retained in main sample; robustness check excludes ISL.