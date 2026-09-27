# Rules in .build_crop_windows(): one test per rule / assumption type.

test_that("cover crop with no plant date mid-rotation starts at previous harvest", {
  crop <- crop_rows(
    CD_cat  = c("cash", "cover", "cash"),
    CD_name = c("Corn", "Rye", "Soybean"),
    plant   = c("2016-05-01", NA, "2017-05-10"),
    harv    = c("2016-10-01", NA, "2017-10-05"),
    term    = c(NA, "2017-04-15", NA)
  )
  res <- .build_crop_windows(crop, rot("2016-01-01", "2017-12-31"))

  expect_equal(ep(res, "Rye")$crop_start, as.Date("2016-10-01"))
  expect_equal(ep(res, "Rye")$crop_end,   as.Date("2017-04-15"))
  expect_true(has_flag(res, "Rye", "start_prev_end"))
})

test_that("frost-seeded relay at record start: wheat keeps rotation start", {
  # Wheat planted the fall before the record; clover frost-seeded into it
  crop <- crop_rows(
    CD_cat  = c("cash", "cash", "cash"),
    CD_name = c("Wheat, Winter", "Clover, Red", "Corn"),
    plant   = c(NA, "2016-03-15", "2017-04-30"),
    harv    = c("2016-06-20", "2016-06-20", "2017-09-15")
  )
  res <- .build_crop_windows(crop, rot("2016-01-01", "2017-12-31"))

  expect_equal(ep(res, "Wheat, Winter")$crop_start, as.Date("2016-01-01"))
  expect_equal(ep(res, "Clover, Red")$crop_start,   as.Date("2016-03-15"))
  expect_true(has_flag(res, "Wheat, Winter", "start_rot_start"))
})

test_that("mixture with no plant dates at record start: all members start at rotation start", {
  crop <- crop_rows(
    CD_cat  = c("cover", "cover"),
    CD_name = c("Oats", "Rye"),
    term    = c("2016-03-20", "2016-03-20")
  )
  res <- .build_crop_windows(crop, rot("2016-01-01", "2016-12-31"))

  expect_equal(ep(res, "Oats")$crop_start, as.Date("2016-01-01"))
  expect_equal(ep(res, "Rye")$crop_start,  as.Date("2016-01-01"))
})

test_that("perennial cuttings without plant dates attach to the stand", {
  crop <- crop_rows(
    CD_cat  = "perennial",
    CD_name = "Alfalfa",
    plant   = c("2016-04-15", NA, NA, NA),
    harv    = c("2016-07-13", "2016-08-30", "2017-06-29", "2017-08-29"),
    term    = c(NA, NA, NA, "2017-11-02")
  )
  res <- .build_crop_windows(crop, rot("2016-01-01", "2017-12-31"))

  expect_equal(nrow(ep(res, "Alfalfa")), 1)
  expect_equal(ep(res, "Alfalfa")$crop_start, as.Date("2016-04-15"))
  expect_equal(ep(res, "Alfalfa")$crop_end,   as.Date("2017-11-02"))
  expect_true(has_flag(res, "Alfalfa", "perennial_rows_attached"))
})

test_that("perennial with no termination ends at the next planting", {
  crop <- crop_rows(
    CD_cat  = c("perennial", "perennial", "perennial", "cash"),
    CD_name = c("Alfalfa", "Alfalfa", "Alfalfa", "Corn"),
    plant   = c("2016-04-15", NA, NA, "2018-05-01"),
    harv    = c("2016-07-13", "2016-08-30", "2017-06-29", "2018-10-01")
  )
  res <- .build_crop_windows(crop, rot("2016-01-01", "2018-12-31"))

  expect_equal(ep(res, "Alfalfa")$crop_end, as.Date("2018-05-01"))
  expect_true(has_flag(res, "Alfalfa", "end_next_planting"))
})

test_that("perennial harvest after a later planting keeps the stand alive (intercrop evidence)", {
  # Rye interseeded into alfalfa in fall 2016; alfalfa still cut in 2017
  crop <- crop_rows(
    CD_cat  = c("perennial", "cover", "perennial"),
    CD_name = c("Alfalfa", "Rye", "Alfalfa"),
    plant   = c("2016-04-15", "2016-09-15", NA),
    harv    = c("2016-07-13", NA, "2017-06-29"),
    term    = c(NA, "2017-04-15", NA)
  )
  res <- .build_crop_windows(crop, rot("2016-01-01", "2017-12-31"))

  expect_equal(nrow(ep(res, "Alfalfa")), 1)
  expect_true(ep(res, "Alfalfa")$crop_end > as.Date("2017-06-29"))
})

test_that("annual with different harvest and termination dates ends at the earlier", {
  crop <- crop_rows("cash", "Corn", plant = "2016-05-01",
                    harv = "2016-09-01", term = "2016-10-15")
  res <- .build_crop_windows(crop, rot("2016-01-01", "2016-12-31"))

  expect_equal(ep(res, "Corn")$crop_end, as.Date("2016-09-01"))
  expect_true(has_flag(res, "Corn", "annual_harv_term_conflict"))
})

test_that("cash crop with only a termination date uses it and is flagged", {
  crop <- crop_rows("cash", "Corn", plant = "2016-05-01", term = "2016-10-01")
  res <- .build_crop_windows(crop, rot("2016-01-01", "2016-12-31"))

  expect_equal(ep(res, "Corn")$crop_end, as.Date("2016-10-01"))
  expect_true(has_flag(res, "Corn", "annual_term_only"))
})

test_that("cover crop with only a termination date is not flagged", {
  crop <- crop_rows("cover", "Rye", plant = "2016-10-01", term = "2016-12-01")
  res <- .build_crop_windows(crop, rot("2016-01-01", "2016-12-31"))

  expect_false(has_flag(res, "Rye", "annual_term_only"))
})

test_that("last crop with no end date runs to rotation end", {
  crop <- crop_rows(
    CD_cat  = c("cash", "cover"),
    CD_name = c("Corn", "Rye"),
    plant   = c("2016-05-01", "2016-10-20"),
    harv    = c("2016-10-01", NA)
  )
  res <- .build_crop_windows(crop, rot("2016-01-01", "2016-12-31"))

  expect_equal(ep(res, "Rye")$crop_end, as.Date("2016-12-31"))
  expect_true(has_flag(res, "Rye", "end_rot_end"))
})

test_that("repeat harvests of one annual planting are one episode", {
  crop <- crop_rows(
    CD_cat  = "cash",
    CD_name = "Sorghum, Forage",
    plant   = c("2016-05-15", NA),
    harv    = c("2016-07-01", "2016-08-20")
  )
  res <- .build_crop_windows(crop, rot("2016-01-01", "2016-12-31"))

  expect_equal(nrow(ep(res, "Sorghum, Forage")), 1)
  expect_equal(ep(res, "Sorghum, Forage")$crop_end, as.Date("2016-08-20"))
  expect_true(has_flag(res, "Sorghum, Forage", "annual_multi_harvest"))
})

test_that("the same annual in consecutive years stays two episodes", {
  crop <- crop_rows(
    CD_cat  = "cash",
    CD_name = "Corn",
    plant   = c("2016-04-22", "2017-04-22"),
    harv    = c("2016-10-21", "2017-10-21")
  )
  res <- .build_crop_windows(crop, rot("2016-01-01", "2017-12-31"))

  expect_equal(nrow(ep(res, "Corn")), 2)
})

test_that("usually-perennial species entered as annual is flagged", {
  crop <- crop_rows("cash", "Alfalfa", plant = "2016-04-01", harv = "2016-07-01")
  res <- .build_crop_windows(crop, rot("2016-01-01", "2016-12-31"))

  expect_true(has_flag(res, "Alfalfa", "check_category"))
})

test_that("rows with no dates are ignored and flagged", {
  crop <- crop_rows(
    CD_cat  = c("cash", "cash"),
    CD_name = c("Corn", "Soybean"),
    plant   = c("2016-05-01", NA),
    harv    = c("2016-10-01", NA)
  )
  res <- .build_crop_windows(crop, rot("2016-01-01", "2016-12-31"))

  expect_equal(nrow(ep(res, "Soybean")), 0)
  expect_true(has_flag(res, "Soybean", "row_no_dates"))
})

test_that("assumption levels and messages are always filled", {
  crop <- crop_rows(
    CD_cat  = c("cash", "cover"),
    CD_name = c("Corn", "Rye"),
    plant   = c(NA, "2016-10-20"),
    harv    = c("2016-10-01", NA)
  )
  res <- .build_crop_windows(crop, rot("2016-01-01", "2016-12-31"))

  expect_false(anyNA(res$assumptions$level))
  expect_false(anyNA(res$assumptions$message))
})
