test_that("N is assigned to the first cash/perennial harvest after it", {
  d <- function(x) as.Date(x)
  rot <- tibble::tibble(MGT_combo = "u", rot_start = d("2011-01-01"), rot_end = d("2014-12-31"))
  crop <- tibble::tibble(
    MGT_combo    = "u",
    CD_cat       = c("cash", "cover", "cash", "cash"),
    CD_name      = c("corn", "rye", "soybean", "corn"),
    CD_harv_date = d(c("2011-10-10", NA, "2012-10-01", "2013-10-15")),
    CD_term_date = d(c(NA, "2012-05-01", NA, NA)))
  amend <- tibble::tibble(
    MGT_combo = "u",
    SA_date   = d(c("2011-04-29", "2012-04-10", "2012-10-16", "2013-05-06", "2014-04-01")),
    SA_cat    = c("Organic", "Organic", "Organic", "Fertilizer", "Fertilizer"),
    SA_N      = c(150, 145, 100, 80, 50),
    SA_units  = "lbs/acre")
  out <- SHMI:::.prepare_n_rate(amend, crop, rot)
  ap <- out$n_applications
  expect_equal(ap$crop_year, c(2011L, 2012L, 2013L, 2013L, NA))   # fall 2012 -> 2013 crop
  expect_equal(nrow(out$n_rate), 3)
  r13 <- out$n_rate[out$n_rate$crop_year == 2013, ]
  expect_equal(r13$crop, "corn")
  expect_equal(r13$n_events, 2L)
  expect_true("n_after_last_harvest" %in% out$assumptions$type)
  # calendar totals unchanged: 2012 holds both 2012 applications
  expect_equal(out$n_rate_calendar$n_events[out$n_rate_calendar$year == 2012], 2L)
})
