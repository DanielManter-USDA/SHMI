# Unit normalization, yield conversion (including bushels), and N rates.

test_that("unit strings from the template and free text normalize correctly", {
  input <- c("lbs/acre", "kgs/hectare", "bushels/acre", "tons acre-1",
             "Mg ha-1", "lbs acre-1 N", "kg ha-1", "tonnes/hectare",
             "gallons acre-1", "kg per plot")
  expected <- c("lb/acre", "kg/ha", "bu/acre", "ton/acre",
                "t/ha", "lb/acre", "kg/ha", "t/ha",
                "gallons/acre", "kg/plot")
  expect_equal(.normalize_rate_unit(input), expected)
})

test_that("mass-per-area units convert to kg/ha", {
  conv <- .convert_rate_kg_ha(c(100, 1, 1), c("lbs/acre", "t/ha", "kg/ha"))
  expect_equal(conv$value, c(112.085, 1000, 1), tolerance = 1e-4)
  expect_true(all(conv$status == "converted"))
})

test_that("bushels convert with the crop's test weight", {
  conv <- .convert_rate_kg_ha(c(180, 55, 70), rep("bushels/acre", 3),
                              crop_name = c("Corn", "Soybean, Double-cropped",
                                            "Wheat, Winter"))
  expect_equal(conv$value, c(11298.2, 3698.8, 4707.6), tolerance = 1e-4)
  expect_equal(conv$lb_per_bu, c(56, 60, 60))
})

test_that("bushels for a crop without a test weight are not converted", {
  conv <- .convert_rate_kg_ha(50, "bushels/acre", crop_name = "Ryegrass")
  expect_true(is.na(conv$value))
  expect_equal(conv$status, "bushels_not_converted")
})

test_that("bushels are not converted when no crop name is given", {
  conv <- .convert_rate_kg_ha(180, "bushels/acre")
  expect_equal(conv$status, "bushels_not_converted")
})

test_that("unknown, missing, and non-numeric values get distinct statuses", {
  conv <- .convert_rate_kg_ha(c(5, 5, "abc"), c("gallons acre-1", NA, "kg/ha"))
  expect_equal(conv$status, c("unknown_units", "missing_units", "no_value"))
})

test_that(".prepare_yield keeps raw values and logs bushel conversions", {
  crop <- crop_rows(
    CD_cat = c("cash", "cash"), CD_name = c("Corn", "Ryegrass"),
    plant = c("2017-05-01", "2017-04-01"), harv = c("2017-10-01", "2017-06-01"),
    yield = c(180, 50), yield_units = c("bushels/acre", "bushels/acre")
  )
  out <- .prepare_yield(crop, rot("2017-01-01", "2017-12-31"))

  expect_equal(out$yield$CD_yield, c(180, 50))
  expect_equal(out$yield$yield_status, c("converted", "bushels_not_converted"))
  expect_setequal(out$assumptions$type,
                  c("yield_bushels_test_weight", "yield_bushels_not_converted"))
})

test_that(".prepare_yield drops yields outside the rotation bounds", {
  crop <- crop_rows("cash", "Corn", plant = "2015-05-01", harv = "2015-10-01",
                    yield = 10000, yield_units = "kg/ha")
  out <- .prepare_yield(crop, rot("2017-01-01", "2017-12-31"))
  expect_equal(nrow(out$yield), 0)
})

test_that(".prepare_n_rate: unconvertible year is NA, partial year is a lower bound", {
  amend <- tibble::tibble(
    MGT_combo = "U1",
    SA_date   = as.Date(c("2017-05-01", "2018-05-01", "2018-06-01")),
    SA_N      = c(5, 100, 5),
    SA_units  = c("gallons acre-1", "lbs acre-1 N", "gallons acre-1"),
    SA_source = "manure"
  )
  out <- .prepare_n_rate(amend)$n_rate

  expect_true(is.na(out$N_kg_ha_yr[out$year == 2017]))
  expect_equal(out$N_kg_ha_yr[out$year == 2018], 112.085, tolerance = 1e-4)
  expect_equal(out$n_unconverted[out$year == 2018], 1)
})

test_that(".prepare_n_rate: amendments without SA_N are not reported as zero", {
  amend <- tibble::tibble(MGT_combo = "U1", SA_date = as.Date("2017-05-01"),
                          SA_N = NA_real_, SA_units = "tons acre-1")
  expect_equal(nrow(.prepare_n_rate(amend)$n_rate), 0)
})

test_that(".prepare_n_rate flags implausibly high converted rates", {
  amend <- tibble::tibble(MGT_combo = "U1", SA_date = as.Date("2017-05-01"),
                          SA_N = 150, SA_units = "tons acre-1", SA_source = "manure")
  out <- .prepare_n_rate(amend)
  expect_true("n_rate_implausible" %in% out$assumptions$type)
})
