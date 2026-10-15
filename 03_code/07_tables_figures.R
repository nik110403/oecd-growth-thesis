# scripts/07_tables_figures.R
# Run from the project root, after 06_regressions.R.
# Produces the regression/robustness/GMM tables as Pandoc MARKDOWN (06_tables/*.md, with
# pandoc-crossref captions {#tbl:...}) and the break coefficient plot (05_figures/).
# Tables are built from coef_test() CR2 + Satterthwaite output so the standard errors and
# significance stars match the numbers reported in the text exactly.

library(dplyr); library(stringr); library(ggplot2); library(tibble)
library(plm); library(clubSandwich)

models <- readRDS("02_data/processed/models.rds")

# ── Helpers ───────────────────────────────────────────────────────────────────
star <- function(p) ifelse(is.na(p), "", ifelse(p < 0.01, "***", ifelse(p < 0.05, "**", ifelse(p < 0.1, "*", ""))))

# Tidy a plm model with CR2 cluster-robust SEs (Satterthwaite p-values).
tidy_cr2 <- function(m) {
  ct <- coef_test(m, vcov = "CR2", cluster = "individual")
  data.frame(term = rownames(ct), b = ct$beta, se = ct$SE, p = ct$p_Satt, stringsAsFactors = FALSE)
}
gof_plm <- function(m) c(`Observations` = format(stats::nobs(m), big.mark = ""),
                         `Within R\\textsuperscript{2}` = sprintf("%.3f", as.numeric(summary(m)$r.squared["rsq"])))

# Assemble a multi-model markdown table (estimate row + SE row per term) with a crossref caption.
make_table <- function(models, collabels, term_order, term_labels, gof_fun, tidy_fun,
                       caption, label, file) {
  tids <- lapply(models, tidy_fun)
  ncol <- length(models)
  line <- function(cells) paste0("| ", paste(cells, collapse = " | "), " |")
  header <- line(c("", collabels))
  sep    <- paste0("|", paste(rep(" --- ", ncol + 1), collapse = "|"), "|")
  body <- character(0)
  for (t in term_order) {
    est <- vapply(tids, function(d) { i <- match(t, d$term)
      if (is.na(i)) "" else sprintf("%.3f%s", d$b[i], star(d$p[i])) }, character(1))
    se  <- vapply(tids, function(d) { i <- match(t, d$term)
      if (is.na(i)) "" else sprintf("(%.3f)", d$se[i]) }, character(1))
    body <- c(body, line(c(term_labels[[t]], est)), line(c("", se)))
  }
  gof <- lapply(models, gof_fun)
  for (g in names(gof[[1]]))
    body <- c(body, line(c(g, vapply(gof, function(x) x[[g]], character(1)))))
  writeLines(c(header, sep, body, "", paste0(": ", caption, " {#", label, "}")), file)
}

# ── Variable labels ───────────────────────────────────────────────────────────
labs <- list(
  ln_gdppc_lag = "Log GDP p.c. (lag)", inv_share = "Investment share",
  ln_hc = "Log human capital", pop_growth_pwt = "Population growth",
  emp_growth = "Employment growth", inv_share_lag = "Investment share (lag)",
  `ln_gdppc_lag:post_2008` = "Log GDP p.c. (lag) $\\times$ post-2008",
  `inv_share:post_2008`    = "Investment share $\\times$ post-2008",
  `ln_hc:post_2008`        = "Log human capital $\\times$ post-2008",
  `pop_growth_pwt:post_2008` = "Population growth $\\times$ post-2008",
  `ln_gdppc_lag:post_2010` = "Log GDP p.c. (lag) $\\times$ post-2010",
  `inv_share:post_2010`    = "Investment share $\\times$ post-2010",
  `ln_hc:post_2010`        = "Log human capital $\\times$ post-2010",
  `pop_growth_pwt:post_2010` = "Population growth $\\times$ post-2010")

# ── Table: main regressions (baseline + breaks + employment robustness) ────────
make_table(
  models    = list(models$base, models$break08, models$break10, models$emp, models$invlag),
  collabels = c("(1) Baseline", "(2) Break 2008", "(3) Break 2010", "(4) Emp.", "(5) Inv. lag"),
  term_order = c("ln_gdppc_lag", "inv_share", "inv_share_lag", "ln_hc", "pop_growth_pwt", "emp_growth",
                 "ln_gdppc_lag:post_2008", "inv_share:post_2008", "ln_hc:post_2008", "pop_growth_pwt:post_2008",
                 "ln_gdppc_lag:post_2010", "inv_share:post_2010", "ln_hc:post_2010", "pop_growth_pwt:post_2010"),
  term_labels = labs, gof_fun = gof_plm, tidy_fun = tidy_cr2,
  caption = "Conditional growth regressions and the post-2008 structural break. Dependent variable: GDP per capita growth. Column (5) replaces the contemporaneous investment share with its one-year lag. CR2 cluster-robust standard errors (by country, Satterthwaite dof) in parentheses; country and year fixed effects included. \\*\\*\\* p<0.01, \\*\\* p<0.05, \\* p<0.1.",
  label = "tbl:reg", file = "06_tables/regressions.md")

# ── Table + figure: unknown-date sup-Wald scan ────────────────────────────────
# Exports the per-year joint CR2 Wald statistic so the unknown-break result is
# verifiable rather than asserted.
sw <- models$supwald
sw_md <- c(
  "| Break year | Wald $F$ | $p$ (naive) |",
  "| --- | --- | --- |",
  sprintf("| %d | %.2f | %.3f |", sw$break_year, sw$Fstat, sw$p),
  "",
  ": Unknown-date sup-Wald scan. Joint CR2 Wald statistic on the four break interactions at each candidate year, 2001--2015. The maximum falls at 2001 ($F$ = 2.77, naive $p$ = 0.108), short of the 10\\% level before any correction for the maximum selection. {#tbl:supwald}")
writeLines(sw_md, "06_tables/supwald.md")

p_sw <- ggplot(sw, aes(break_year, Fstat)) +
  geom_line() + geom_point() +
  geom_point(data = sw[which.max(sw$Fstat), ], colour = "red", size = 2.6) +
  labs(title = "Unknown-date sup-Wald scan",
       subtitle = "Joint CR2 Wald F on the break interactions, by candidate year",
       x = NULL, y = "Joint Wald F") +
  theme_minimal()
ggsave("05_figures/supwald_scan.png", p_sw, width = 7, height = 4, dpi = 300)
cat("Wrote 06_tables/supwald.md and 05_figures/supwald_scan.png\n")

# ── Table: robustness, sample exclusions ──────────────────────────────────────
make_table(
  models    = list(models$base, models$no_irl, models$no_turmex, models$no_isl),
  collabels = c("Baseline", "No IRL", "No TUR+MEX", "No ISL"),
  term_order = c("ln_gdppc_lag", "inv_share", "ln_hc", "pop_growth_pwt"),
  term_labels = labs, gof_fun = gof_plm, tidy_fun = tidy_cr2,
  caption = "Robustness: baseline re-estimated dropping flagged countries. CR2 cluster-robust standard errors in parentheses. \\*\\*\\* p<0.01, \\*\\* p<0.05, \\* p<0.1.",
  label = "tbl:rob", file = "06_tables/robustness.md")

# ── Table: split-sample estimation per the thesis agreement ───────────────────
make_table(
  models    = list(models$base, models$pre, models$post),
  collabels = c("Full sample", "Pre: 1996--2007", "Post: 2010--2019"),
  term_order = c("ln_gdppc_lag", "inv_share", "ln_hc", "pop_growth_pwt"),
  term_labels = labs, gof_fun = gof_plm, tidy_fun = tidy_cr2,
  caption = "Split-sample estimation: baseline re-estimated separately on the pre-crisis (1996--2007) and post-crisis (2010--2019) windows, excluding 2008--09. CR2 cluster-robust standard errors in parentheses. \\*\\*\\* p<0.01, \\*\\* p<0.05, \\* p<0.1.",
  label = "tbl:split", file = "06_tables/splitsample.md")

# ── Table: difference GMM ─────────────────────────────────────────────────────
if (!is.null(models$gmm)) {
  sg <- summary(models$gmm)
  tidy_gmm <- function(m) { ct <- sg$coefficients
    data.frame(term = rownames(ct), b = ct[, 1], se = ct[, 2], p = ct[, 4], stringsAsFactors = FALSE) }
  gof_gmm <- function(m) c(
    `Observations` = as.character(sum(lengths(m$residuals))),
    `Countries`    = as.character(length(m$residuals)),
    `Sargan p` = sprintf("%.2f", sg$sargan$p.value),
    `AR(2) p`  = sprintf("%.2f", sg$m2$p.value))
  make_table(
    models = list(models$gmm), collabels = "Difference GMM",
    term_order = c("ln_gdppc_lag", "inv_share", "ln_hc", "pop_growth_pwt"),
    term_labels = labs, gof_fun = gof_gmm, tidy_fun = tidy_gmm,
    caption = "Robustness: difference GMM (Arellano-Bond), instruments collapsed at lags 2--3. Standard errors in parentheses. \\*\\*\\* p<0.01, \\*\\* p<0.05, \\* p<0.1.",
    label = "tbl:gmm", file = "06_tables/gmm.md")
}

# ── Coefficient plot: post-2008 interaction terms with CR2 95% CIs ────────────
# Intervals use the Satterthwaite t critical value (not 1.96) so they match the
# CR2 + Satterthwaite inference reported in the text and tables.
ct <- coef_test(models$break08, vcov = "CR2", cluster = "individual")
break_terms <- ct |>
  tibble::rownames_to_column("term") |>
  filter(str_detect(term, ":post_2008$")) |>
  mutate(term = str_remove(term, ":post_2008$"),
         term = dplyr::recode(term,
           ln_gdppc_lag = "Log GDP p.c. (lag)", inv_share = "Investment share",
           ln_hc = "Log human capital", pop_growth_pwt = "Population growth"),
         crit = qt(0.975, df_Satt),
         lo = beta - crit * SE, hi = beta + crit * SE)

p <- ggplot(break_terms, aes(x = term, y = beta)) +
  geom_hline(yintercept = 0, linetype = "dashed", colour = "grey50") +
  geom_pointrange(aes(ymin = lo, ymax = hi)) +
  coord_flip() +
  labs(title = "Change in growth coefficients after 2008",
       subtitle = "post-2008 interaction terms, CR2 95% CIs (Satterthwaite t)",
       x = NULL, y = "Change in coefficient") +
  theme_minimal()
ggsave("05_figures/break_coefficients.png", p, width = 7, height = 4, dpi = 300)

cat("Wrote 06_tables/{regressions,robustness,splitsample,gmm}.md and 05_figures/break_coefficients.png\n")
