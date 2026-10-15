# scripts/03_construct_variables.R
# Run from the project root.
# tidyverse components (loaded individually to avoid the meta-package's
# system-font build dependencies; behaviour is identical)
library(dplyr); library(tidyr); library(readr); library(stringr)
library(purrr); library(tibble); library(ggplot2)

pwt <- readRDS("02_data/processed/pwt_filtered.rds")

panel <- pwt |>
  group_by(countrycode) |>
  arrange(year, .by_group = TRUE) |>
  mutate(
    
    # ── Dependent variable ───────────────────────────────────────────────────
    gdppc          = rgdpna / pop,                        # GDP per capita, mn 2017 USD
    gdppc_growth   = (gdppc - lag(gdppc)) / lag(gdppc),  # annual growth rate
    
    # ── Solow regressors ─────────────────────────────────────────────────────
    # Investment share: csh_i is already a fraction of GDP — use directly
    inv_share      = csh_i,
    
    # Human capital: hc is the PWT index (Mincer-based) — use log for elasticity
    ln_hc          = log(hc),
    
    # Labour input. pop_growth_pwt (population growth) is the Solow "n" and is the
    # BASELINE regressor. emp_growth (persons engaged) is procyclical/endogenous to
    # the cycle, so it is kept only as a robustness check, not the preferred measure.
    pop_growth_pwt = (pop - lag(pop)) / lag(pop),
    emp_growth     = (emp - lag(emp)) / lag(emp),
    
    # ── Post-crisis dummies ───────────────────────────────────────────────────
    # DECISION PENDING SUPERVISOR: using both, flag in paper
    post_2008      = as.integer(year >= 2008),
    post_2010      = as.integer(year >= 2010),
    
    # ── Log GDP per capita (for convergence term) ─────────────────────────────
    # In Solow, initial income enters as log(y_0) — use lagged value
    ln_gdppc_lag   = log(lag(gdppc))
    
  ) |>
  ungroup()

# ── Drop 1995 obs: it loses a year to lagging ─────────────────────────────────
panel <- panel |> filter(year >= 1996)

# ── Sanity check: distributions ───────────────────────────────────────────────
library(skimr)
panel |>
  select(gdppc_growth, inv_share, ln_hc, emp_growth, pop_growth_pwt) |>
  skim()

# Any extreme outliers in gdppc_growth worth investigating?
panel |>
  filter(abs(gdppc_growth) > 0.1) |>          # >10% growth or contraction
  select(countrycode, year, gdppc_growth) |>
  arrange(desc(abs(gdppc_growth)))

saveRDS(panel, "02_data/processed/panel_constructed.rds")
