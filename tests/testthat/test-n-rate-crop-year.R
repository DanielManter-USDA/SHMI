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

test_that("N spread just before a perennial is plowed down goes to the next crop", {
  d <- function(x) as.Date(x)
  rot <- tibble::tibble(MGT_combo = "u", rot_start = d("2011-01-01"), rot_end = d("2013-12-31"))
  crop <- tibble::tibble(
    MGT_combo    = "u",
    CD_cat       = c("perennial", "cash"),
    CD_name      = c("alfalfa", "corn"),
    CD_plant_date = d(c("2011-04-15", "2013-05-10")),
    CD_harv_date = d(c(NA, "2013-10-20")),
    CD_term_date = d(c("2012-11-15", NA)))
  amend <- tibble::tibble(
    MGT_combo = "u",
    SA_date   = d(c("2011-11-01", "2012-10-25")),       # manure on the stand; manure before plow-down
    SA_cat    = "Organic", SA_N = c(100, 180), SA_units = "lbs/acre")
  out <- SHMI:::.prepare_n_rate(amend, crop, rot)
  ap <- out$n_applications
  expect_equal(ap$crop, c("alfalfa", "corn"))
  expect_equal(ap$crop_year, c(2012L, 2013L))
  expect_true("n_plowdown_next_crop" %in% out$assumptions$type)
  old <- SHMI:::.prepare_n_rate(amend, crop, rot, plowdown_days = 0)
  expect_equal(old$n_applications$crop, c("alfalfa", "alfalfa"))
})

test_that("fall manure before a spring plow-down goes to the next crop", {
  d <- function(x) as.Date(x)
  rot <- tibble::tibble(MGT_combo = "u", rot_start = d("2014-01-01"), rot_end = d("2017-12-31"))
  crop <- tibble::tibble(
    MGT_combo     = "u",
    CD_cat        = c("annual", "perennial", "annual"),
    CD_name       = c("corn", "alfalfa", "corn"),
    CD_plant_date = d(c("2014-05-01", "2015-04-15", "2017-04-25")),
    CD_harv_date  = d(c("2014-10-20", NA, "2017-11-01")),
    CD_term_date  = d(c(NA, "2017-04-10", NA)))
  amend <- tibble::tibble(
    MGT_combo = "u",
    SA_date   = d(c("2015-11-05", "2016-11-06")),       # topdressed on the stand; fall manure 155 days before plow-down
    SA_cat    = "Organic", SA_N = c(200, 240), SA_units = "lbs/acre")
  out <- SHMI:::.prepare_n_rate(amend, crop, rot)
  ap <- out$n_applications
  expect_equal(ap$crop, c("alfalfa", "corn"))
  expect_equal(ap$crop_year, c(2017L, 2017L))
  old <- SHMI:::.prepare_n_rate(amend, crop, rot, plowdown_days = 90)
  expect_equal(old$n_applications$crop, c("alfalfa", "alfalfa"))
})
