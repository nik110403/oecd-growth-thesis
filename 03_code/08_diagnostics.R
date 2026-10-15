# scripts/08_diagnostics.R
# Run from the project root, after 04_merge_check.R.
# Panel diagnostics that justify the chosen specification (FE vs RE, the use of
# Driscoll-Kraay SEs, and the treatment of serial correlation). Writes a text
# report to 06_tables/diagnostics.txt.

library(plm)

panel <- readRDS("02_data/processed/panel_final.rds")
pdata <- pdata.frame(panel, index = c("countrycode", "year"))
f_base <- gdppc_growth ~ ln_gdppc_lag + inv_share + ln_hc + pop_growth_pwt

fe  <- plm(f_base, data = pdata, model = "within", effect = "individual")
fe2 <- plm(f_base, data = pdata, model = "within", effect = "twoways")

report <- character(0)
add <- function(...) report <<- c(report, paste0(...), "")
grab <- function(expr) paste(capture.output(print(expr)), collapse = "\n")

# ── Hausman test: fixed vs random effects ─────────────────────────────────────
# (The thesis uses two-way FE on substantive grounds; this documents the choice.)
add("===== Hausman test (FE vs RE) =====")
haus <- tryCatch({
  re <- plm(f_base, data = pdata, model = "random", effect = "individual")
  grab(phtest(fe, re))
}, error = function(e) paste("RE model not estimable:", conditionMessage(e)))
add(haus)

# ── Pesaran CD: cross-sectional dependence ────────────────────────────────────
# A significant result justifies Driscoll-Kraay SEs (robust to cross-sectional dep.).
# Run on BOTH the one-way FE model (raw dependence, incl. common shocks) and the
# two-way model actually estimated (residual dependence net of the year effects).
add("===== Pesaran CD test (one-way FE: raw cross-sectional dependence) =====")
add(grab(pcdtest(fe, test = "cd")))
add("===== Pesaran CD test (two-way FE: net of year effects) =====")
add(grab(pcdtest(fe2, test = "cd")))

# ── Serial correlation ────────────────────────────────────────────────────────
add("===== Wooldridge test for serial correlation (FE panels) =====")
add(grab(pwartest(fe)))
add("===== Breusch-Godfrey / Wooldridge (pbgtest) =====")
add(grab(pbgtest(fe)))

writeLines(report, "06_tables/diagnostics.txt")
cat(paste(report, collapse = "\n"))
cat("\nWrote 06_tables/diagnostics.txt\n")
