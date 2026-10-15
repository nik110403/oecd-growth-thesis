# scripts/04_merge_check.R
# Run from the project root.
# tidyverse components (loaded individually to avoid the meta-package's
# system-font build dependencies; behaviour is identical)
library(dplyr); library(tidyr); library(readr); library(stringr)
library(purrr); library(tibble); library(ggplot2)

panel  <- readRDS("02_data/processed/panel_constructed.rds")
wdi    <- readRDS("02_data/processed/wdi_popgrowth.rds")

panel_merged <- panel |>
  left_join(wdi, by = c("countrycode", "year"))

# ── Cross-check: PWT emp growth vs WDI population growth ─────────────────────
# These should be correlated but not identical — emp is employment, pop is total
panel_merged |>
  summarise(
    cor_emp_wdi = cor(emp_growth, pop_growth_wb, use = "complete.obs"),
    cor_pop_wdi = cor(pop_growth_pwt, pop_growth_wb, use = "complete.obs")
  )
# Expect pop_growth_pwt ~ pop_growth_wb correlation > 0.95
# emp_growth will diverge more — note this in your methods

# ── Check merge completeness ──────────────────────────────────────────────────
panel_merged |>
  filter(is.na(pop_growth_wb)) |>
  count(countrycode)

saveRDS(panel_merged, "02_data/processed/panel_final.rds")
# base write.csv (not readr::write_csv) to avoid a hard dependency on the vroom
# shared library, which keeps the pipeline portable across R installations.
write.csv(panel_merged, "02_data/processed/panel_final.csv", row.names = FALSE)  # for sharing/backup
