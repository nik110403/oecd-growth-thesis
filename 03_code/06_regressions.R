# scripts/06_regressions.R
# Run from the project root.
#
# Estimates the conditional-growth regressions and the post-2008 structural-break
# tests. Saves all fitted objects to 02_data/processed/models.rds for 07_tables_figures.R.
#
# FRAMING NOTE (see 01_notes/02_method_notes.md): this is an *annual within-country*
# fixed-effects panel, not a cross-country growth regression. It tests whether the
# short-run conditional comovement between the Solow regressors and growth shifted
# after 2008 — it does not estimate long-run convergence in the Barro/MRW sense.

# tidyverse components (loaded individually to avoid the meta-package's
# system-font build dependencies; behaviour is identical)
library(dplyr); library(tidyr); library(readr); library(stringr)
library(purrr); library(tibble); library(ggplot2)
library(plm)
library(clubSandwich)   # CR2 cluster-robust SEs with Satterthwaite dof (few clusters)
library(lmtest)
library(sandwich)

panel <- readRDS("02_data/processed/panel_final.rds")
# Lagged investment share (within country): investment enters one year back so it
# cannot respond to current-year growth — a check on the contemporaneous-simultaneity
# concern around the baseline investment coefficient. (Existing models are unaffected:
# they do not reference inv_share_lag.)
panel <- panel |>
  group_by(countrycode) |>
  arrange(year, .by_group = TRUE) |>
  mutate(inv_share_lag = dplyr::lag(inv_share)) |>  # dplyr::lag — plm masks lag()
  ungroup()
pdata <- pdata.frame(panel, index = c("countrycode", "year"))

# Helper: CR2 cluster-robust coefficient test (clustered on country, 24 clusters).
cr2 <- function(m) coef_test(m, vcov = "CR2", cluster = "individual")

# ── Model 1 — Baseline two-way FE (population growth = Solow n) ────────────────
f_base <- gdppc_growth ~ ln_gdppc_lag + inv_share + ln_hc + pop_growth_pwt
m_base <- plm(f_base, data = pdata, model = "within", effect = "twoways")

cat("\n===== Model 1: baseline (twoway FE) =====\n")
print(cr2(m_base))

# Driscoll-Kraay alternative (robust to cross-sectional dependence) — report both.
cat("\n--- Model 1: Driscoll-Kraay SEs ---\n")
print(coeftest(m_base, vcov = function(x) vcovSCC(x, type = "HC0", maxlag = 3)))

# ── Model 2 — Structural break at a KNOWN date (post-2008 and post-2010) ───────
# Year FE absorb the post_* main effect; the interactions are still identified.
f_break <- function(p)
  reformulate(c("ln_gdppc_lag", "inv_share", "ln_hc", "pop_growth_pwt",
                paste0(p, ":", c("ln_gdppc_lag", "inv_share", "ln_hc", "pop_growth_pwt"))),
              response = "gdppc_growth")

m_break08 <- plm(f_break("post_2008"), data = pdata, model = "within", effect = "twoways")
m_break10 <- plm(f_break("post_2010"), data = pdata, model = "within", effect = "twoways")

cat("\n===== Model 2a: break at 2008 =====\n");  print(cr2(m_break08))
cat("\n===== Model 2b: break at 2010 =====\n");  print(cr2(m_break10))

# Joint CR2 Wald test: did ANY structural coefficient change? (H0: all interactions = 0)
cat("\n--- Joint test of break (post_2008 interactions = 0), CR2 ---\n")
print(Wald_test(m_break08,
                constraints = constrain_zero("post_2008", reg_ex = TRUE),
                vcov = "CR2", cluster = "individual"))

# ── Per-coefficient minimum detectable effect (MDE) ────────────────────────────
# Exact MDE replacing the back-of-envelope ~0.17 in the Discussion. For each
# post-2008 interaction, the smallest true slope shift detectable at 80% power
# under a two-sided 5% test, given its CR2 SE and Satterthwaite df:
#   MDE = (t_{0.975, df} + t_{0.80, df}) * SE.
cat("\n--- Per-coefficient MDE (80% power, two-sided 5%), break at 2008 ---\n")
ct08 <- cr2(m_break08)
ix   <- grepl(":post_2008", rownames(ct08))
mde  <- data.frame(
  term     = sub(":post_2008", "", rownames(ct08)[ix]),
  estimate = ct08$beta[ix],
  SE       = ct08$SE[ix],
  df_Satt  = ct08$df_Satt[ix]
)
mde$MDE <- (qt(0.975, mde$df_Satt) + qt(0.80, mde$df_Satt)) * mde$SE
print(mde, digits = 3, row.names = FALSE)

# ── Unknown break point — sup-Wald search (Andrews 1993; Bai 1998) ────────────
# Don't pre-impose 2008/2010: scan candidate break years 2001-2015 (trimming ~5
# years at each end of 1996-2019 so both regimes keep enough observations),
# take the year that MAXIMISES the joint Wald stat on the interactions.
trim_years <- 2001:2015
supwald <- map_dfr(trim_years, function(by) {
  d  <- transform(panel, brk = as.integer(year >= by))
  pd <- pdata.frame(d, index = c("countrycode", "year"))
  m  <- plm(reformulate(c("ln_gdppc_lag", "inv_share", "ln_hc", "pop_growth_pwt",
                          paste0("brk:", c("ln_gdppc_lag", "inv_share", "ln_hc", "pop_growth_pwt"))),
                        response = "gdppc_growth"),
            data = pd, model = "within", effect = "twoways")
  w <- Wald_test(m, constraints = constrain_zero("brk", reg_ex = TRUE),
                 vcov = "CR2", cluster = "individual")
  tibble(break_year = by, Fstat = w$Fstat, df_num = w$df_num, df_denom = w$df_denom, p = w$p_val)
})
cat("\n===== Unknown-break sup-Wald scan =====\n")
print(as.data.frame(supwald), digits = 3)
cat(sprintf("\n-> sup-Wald at break_year = %d (F = %.2f)\n",
            supwald$break_year[which.max(supwald$Fstat)], max(supwald$Fstat)))
cat("NOTE: compare the sup-statistic to Andrews (1993) critical values (or a\n",
    "bootstrap null distribution) — the naive p-values above are NOT valid for the\n",
    "max-selected statistic.\n")

# ── Robustness 1 — alternative labour input (employment growth) ───────────────
m_emp <- plm(gdppc_growth ~ ln_gdppc_lag + inv_share + ln_hc + emp_growth,
             data = pdata, model = "within", effect = "twoways")

# ── Robustness 2 — sample exclusions (IRL "leprechaun", TUR/MEX, ISL) ──────────
fit_excl <- function(drop) {
  pd <- pdata.frame(filter(panel, !countrycode %in% drop), index = c("countrycode", "year"))
  plm(f_base, data = pd, model = "within", effect = "twoways")
}
m_no_irl <- fit_excl("IRL")
m_no_turmex <- fit_excl(c("TUR", "MEX"))
m_no_isl <- fit_excl("ISL")

# ── Robustness 2b — lagged investment share (contemporaneous simultaneity) ─────
# Investment one year back cannot respond to current-year growth. If the baseline
# investment association is partly reverse causation, the lagged coefficient attenuates.
m_invlag <- plm(gdppc_growth ~ ln_gdppc_lag + inv_share_lag + ln_hc + pop_growth_pwt,
                data = pdata, model = "within", effect = "twoways")
cat("\n===== Robustness: lagged investment share =====\n"); print(cr2(m_invlag))

# ── Robustness 3 — split-sample estimation per the thesis agreement ───────────
# The agreement specifies separate estimation for the pre-crisis (to 2007) and
# post-crisis (from 2010) windows, excluding 2008-09, with the coefficient
# vectors compared. The interaction model above is the formal version of that
# comparison; the split is reported so the agreed design is also run directly.
fit_window <- function(yrs) {
  pd <- pdata.frame(filter(panel, year %in% yrs), index = c("countrycode", "year"))
  plm(f_base, data = pd, model = "within", effect = "twoways")
}
m_pre  <- fit_window(1996:2007)
m_post <- fit_window(2010:2019)
cat("\n===== Split sample: pre-crisis (1996-2007) =====\n");  print(cr2(m_pre))
cat("\n===== Split sample: post-crisis (2010-2019) =====\n"); print(cr2(m_post))

# ── Robustness 4 — difference GMM for the convergence/Nickell-bias term ────────
# With country FE and a lagged-level convergence term, the within estimator of
# ln_gdppc_lag is biased downward in a short-T panel (Nickell 1981). Difference GMM
# (Arellano-Bond 1991) instruments it with deeper lags. Treated as a robustness
# check; wrapped so a finicky instrument set cannot abort the whole script.
m_gmm <- tryCatch(
  pgmm(gdppc_growth ~ ln_gdppc_lag + inv_share + ln_hc + pop_growth_pwt |
         lag(ln_gdppc_lag, 2:3),
       data = pdata, effect = "twoways", model = "onestep",
       transformation = "d", collapse = TRUE),  # collapse + short lags: limit instrument
                                                 # count so the Sargan test has power
  error = function(e) { message("pgmm failed: ", conditionMessage(e)); NULL }
)
if (!is.null(m_gmm)) { cat("\n===== Robustness: difference GMM =====\n"); print(summary(m_gmm)) }

# ── Save fitted objects for the tables/figures script ─────────────────────────
models <- list(
  base = m_base, break08 = m_break08, break10 = m_break10,
  emp = m_emp, no_irl = m_no_irl, no_turmex = m_no_turmex, no_isl = m_no_isl,
  invlag = m_invlag,
  pre = m_pre, post = m_post,
  gmm = m_gmm, supwald = supwald
)
saveRDS(models, "02_data/processed/models.rds")
cat("\nSaved fitted models to 02_data/processed/models.rds\n")
