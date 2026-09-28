# Intensive-tillage end rule and the related data checks

win <- function(...) {
  tibble::tibble(
    MGT_combo = "u1", episode_id = 1L, CD_cat = "Annual", CD_name = "Rye",
    crop_start = as.Date("2016-10-05"), crop_end = as.Date("2017-12-31"),
    start_imputed = FALSE, end_imputed = TRUE, ...)
}
stir <- function(dates, values) {
  tibble::tibble(MGT_combo = "u1", SD_date = as.Date(dates), SD_mixeff = values)
}

test_that("same-day STIR >= 80 ends a crop without an end date", {
  d <- stir(c("2017-05-01", "2017-05-01", "2017-05-01"), c(42, 30, 36))   # 108
  out <- SHMI:::.end_at_intensive_tillage(win(), d, "STIR")
  expect_equal(out$windows$crop_end, as.Date("2017-05-01"))
  expect_equal(out$assumptions$type, "end_intensive_tillage")
  expect_match(out$assumptions$message, "2017-12-31")                    # old end reported
})

test_that("tillage below the threshold, or on the planting day, does not end the crop", {
  light <- stir(c("2017-05-01", "2017-06-01"), c(37, 42))                # separate days
  expect_equal(SHMI:::.end_at_intensive_tillage(win(), light, "STIR")$windows$crop_end,
               as.Date("2017-12-31"))
  same_day <- stir(c("2016-10-05", "2016-10-05"), c(65, 37))             # before planting
  expect_equal(SHMI:::.end_at_intensive_tillage(win(), same_day, "STIR")$windows$crop_end,
               as.Date("2017-12-31"))
})

test_that("crops with a recorded end are never changed", {
  d <- stir(c("2017-05-01", "2017-05-01"), c(65, 37))
  w <- win(); w$end_imputed <- FALSE
  expect_equal(SHMI:::.end_at_intensive_tillage(w, d, "STIR")$windows$crop_end, w$crop_end)
  expect_equal(nrow(SHMI:::.end_at_intensive_tillage(w, d, "STIR")$assumptions), 0)
})

test_that("the rule picks the first intensive day and respects an earlier imputed end", {
  d <- stir(c("2017-03-01", "2017-03-01", "2017-04-01", "2017-04-01"), c(50, 40, 60, 60))
  expect_equal(SHMI:::.end_at_intensive_tillage(win(), d, "STIR")$windows$crop_end,
               as.Date("2017-03-01"))
  w <- win(); w$crop_end <- as.Date("2017-02-01")                      # next planting earlier
  expect_equal(SHMI:::.end_at_intensive_tillage(w, d, "STIR")$windows$crop_end,
               as.Date("2017-02-01"))
})

test_that("EPA uses the daily tillage intensity with threshold 0.252", {
  deep    <- tibble::tibble(MGT_combo = "u1", SD_date = as.Date("2017-05-01"),
                            SD_mixeff = 0.95, SD_depth = 8)               # ~0.64
  shallow <- tibble::tibble(MGT_combo = "u1", SD_date = as.Date("2017-05-01"),
                            SD_mixeff = 0.5, SD_depth = 4)                # ~0.17
  expect_equal(SHMI:::.end_at_intensive_tillage(win(), deep, "EPA")$windows$crop_end,
               as.Date("2017-05-01"))
  expect_equal(SHMI:::.end_at_intensive_tillage(win(), shallow, "EPA")$windows$crop_end,
               as.Date("2017-12-31"))
})

test_that("EPA daily intensity matches compute_disturbance's arithmetic", {
  d <- tibble::tibble(MGT_combo = "u1", SD_date = as.Date("2017-05-01"),
                      SD_mixeff = c(0.3, 0.9), SD_depth = c(3, 8))
  # shallow first: S = 0.3*7.62 = 2.286; then 0.9*(20.32 - 2.286) = 16.23; total 18.52 cm
  expect_equal(SHMI:::.daily_tillage(d, "EPA")$intensity, (2.286 + 0.9 * (20.32 - 2.286)) / 30,
               tolerance = 1e-6)
})

test_that("method 'none' switches the rule off; 'auto' picks the scale from the data", {
  d <- stir(c("2017-05-01", "2017-05-01"), c(65, 37))
  expect_equal(SHMI:::.end_at_intensive_tillage(win(), d, "none")$windows$crop_end,
               as.Date("2017-12-31"))
  expect_equal(SHMI:::.tillage_method(d, "auto"), "STIR")
  epa <- tibble::tibble(MGT_combo = "u1", SD_date = as.Date("2017-05-01"),
                        SD_mixeff = 0.5, SD_depth = 4)
  expect_equal(SHMI:::.tillage_method(epa, "auto"), "EPA")
  expect_equal(SHMI:::.tillage_method(d[0, ], "auto"), "none")
})

test_that("light tillage before a window-end imputation is flagged", {
  rb <- tibble::tibble(MGT_combo = "u1", rot_end = as.Date("2017-12-31"))
  out <- SHMI:::.check_light_tillage_end(win(), stir("2017-05-01", 37), rb)
  expect_equal(out$type, "end_window_light_tillage")
  expect_match(out$message, "2017-05-01")
  expect_equal(nrow(SHMI:::.check_light_tillage_end(win(), stir("2018-05-01", 37), rb)), 0)
})

test_that("imputed planting dates list candidate disturbance dates", {
  w <- win(); w$start_imputed <- TRUE
  w$crop_start <- as.Date("2017-05-19"); w$crop_end <- as.Date("2018-05-26"); w$end_imputed <- FALSE
  d <- stir(c("2017-11-01", "2018-01-10", "2018-01-10"), c(37, 4, 2.4))
  out <- SHMI:::.check_imputed_start(w, d)
  expect_equal(out$type, "start_imputed_candidates")
  expect_match(out$message, "2018-01-10 \\(6.4\\)")
  w$CD_cat <- "Perennial"
  expect_equal(nrow(SHMI:::.check_imputed_start(w, d)), 0)
})

test_that("units without crops are flagged", {
  rb <- tibble::tibble(MGT_combo = c("u1", "u2"), rot_start = as.Date("2018-01-01"),
                       rot_end = as.Date("2018-12-31"))
  out <- SHMI:::.check_no_crops(rb, win())
  expect_equal(out$MGT_combo, "u2")
  expect_equal(out$type, "no_crop_records")
})
