# Raw WDI pull

- Indicator: SP.POP.GROW (Population growth, annual %), World Bank WDI, via R package wbstats (wb_data)
- Countries (ISO2): AU AT BE CA DK FI FR DE GR IE IT JP NL NZ NO PT ES SE CH TR GB US MX IS (24)
- Years: 1995-2019 (600 rows)
- Downloaded: 2026-10-01 (WDI last_updated field: 2026-07-13)
- File: wdi_SP.POP.GROW_raw.csv is the unprocessed wb_data() output.
- This is a LATER vintage than the June 2026 pull that the thesis used (stored processed in
  02_data/processed/wdi_popgrowth.rds). 9 of 600 values differ (GBR 2013-2019, ITA 2018-2019);
  max absolute difference 0.4523 percentage points (ITA 2018/2019). WDI is a cross-check only
  in the thesis (04_merge_check.R); no table depends on it.
