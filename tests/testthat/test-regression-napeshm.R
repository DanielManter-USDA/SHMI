# End-to-end tests on the NAPESHM test workbook.
#
# Place the workbook at tests/testthat/testdata/NAPESHM_test.xlsx.
#
# Test 1 checks the development version on its own (bounds, ceiling).
# Test 2 compares the development version against the installed SHMI
# package, run in a separate R process. It writes the full unit-by-unit
# comparison to tests/testthat/_compare/installed_vs_dev.csv and records a
# summary as a snapshot (tests/testthat/_snaps/regression-napeshm.md):
#   - first run: the snapshot is created (review it!)
#   - later runs: the test fails if the set of changes vs. installed differs
#   - accept intended changes with testthat::snapshot_accept("regression-napeshm")
# After you install a new release, the installed version catches up and the
# snapshot should shrink to "no units moved"; accept it then.

napeshm_path <- test_path("testdata", "NAPESHM_test.xlsx")
settings     <- list(dist_meth = "STIR")   # EPA cannot run on NAPESHM (no depths)
tol          <- 0.01
pillars      <- c("SHMI", "Cover", "Diversity", "InvDist", "OrgInput")

test_that("NAPESHM (development version) runs with valid scores", {
  skip_on_cran()
  skip_if_not(file.exists(napeshm_path), "NAPESHM workbook not in testdata/")
  
  df <- run_shmi_dev(napeshm_path, settings, expert_mode = TRUE)$scores
  
  expect_equal(nrow(df), 508)
  expect_equal(sum(duplicated(df$MGT_combo)), 0)
  expect_false(anyNA(df[pillars]))
  for (p in pillars) expect_true(all(df[[p]] >= 0 & df[[p]] <= 100), info = p)
  
  # Without organic inputs SHMI cannot exceed the sum of the other weights
  ceiling_no_org <- 100 * (0.4481 + 0.0904 + 0.1431)
  expect_true(all(df$SHMI[df$OrgInput == 0] <= ceiling_no_org + 1e-8))
})

test_that("NAPESHM: development vs installed version", {
  skip_on_cran()
  skip_if_not(file.exists(napeshm_path), "NAPESHM workbook not in testdata/")
  skip_if_not_installed("callr")
  # Under R CMD check the dev version is the installed one; nothing to compare
  skip_if(nzchar(Sys.getenv("_R_CHECK_PACKAGE_NAME_")), "Running under R CMD check")
  
  inst_ver <- installed_shmi_version()
  skip_if(is.na(inst_ver), "SHMI is not installed in the library")
  
  installed <- run_shmi_installed(napeshm_path, settings, expert_mode = TRUE)
  dev       <- run_shmi_dev(napeshm_path, settings, expert_mode = TRUE)$scores
  cmp       <- compare_scores(installed, dev, pillars)
  
  # Full comparison for inspection
  out_dir <- test_path("_compare")
  dir.create(out_dir, showWarnings = FALSE)
  utils::write.csv(cmp, file.path(out_dir, "installed_vs_dev.csv"), row.names = FALSE)
  
  # Same management units in both versions
  expect_setequal(dev$MGT_combo, installed$MGT_combo)
  
  # Summary of what moved (rounded so the snapshot is stable)
  d_cols <- paste0("d_", pillars)
  by_pillar <- data.frame(
    pillar      = pillars,
    units_moved = vapply(d_cols, function(d) sum(abs(cmp[[d]]) > tol, na.rm = TRUE), numeric(1)),
    max_up      = vapply(d_cols, function(d) round(max(c(0, cmp[[d]]), na.rm = TRUE), 2), numeric(1)),
    max_down    = vapply(d_cols, function(d) round(min(c(0, cmp[[d]]), na.rm = TRUE), 2), numeric(1)),
    row.names   = NULL
  )
  
  moved <- cmp[!is.na(cmp$d_SHMI) & abs(cmp$d_SHMI) > tol,
               c("MGT_combo", "SHMI_installed", "SHMI_dev", d_cols)]
  moved <- moved[order(-abs(moved$d_SHMI), moved$MGT_combo), ]
  moved[-1] <- lapply(moved[-1], round, 2)
  
  expect_snapshot({
    cat("Units compared:", nrow(cmp), "\n")
    cat("Units with |change in SHMI| >", tol, ":", nrow(moved), "\n\n")
    print(by_pillar, row.names = FALSE)
    cat("\nUnits whose SHMI moved (largest first):\n")
    if (nrow(moved) == 0) cat("none\n") else print(moved, row.names = FALSE)
  })
})