# Reading workbooks with blank or empty sheets, and the climate cache
#
# Fixtures (tests/testthat/fixtures/), both copies of inst/extdata/SHMI_example.xlsx
# with formulas replaced by their values:
#   blank_term_date.xlsx  every crop ends at harvest: CD_term_date blank in every row
#   no_tillage.xlsx       Soil_Disturbance has its header but no data rows

fixture <- function(f) testthat::test_path("fixtures", f)

test_that("a required column that is blank in every row is kept, as NA dates", {
  # the sheet as read: the blank column survives
  cd <- SHMI:::.safe_read(fixture("blank_term_date.xlsx"), sheet = "Crop_Diversity",
                          required_cols = c("MGT_combo", "CD_plant_date", "CD_term_date"), skip = 3)
  expect_gt(nrow(cd), 0)
  expect_true("CD_term_date" %in% names(cd))
  expect_true(all(is.na(cd$CD_term_date)))
  expect_false(all(is.na(cd$CD_harv_date)))
  # and the whole import runs, with crops ending at harvest
  inp <- prepare_shmi_inputs(fixture("blank_term_date.xlsx"), verbose = FALSE)
  expect_gt(nrow(inp$crop), 0)                        # crop windows
  expect_gt(nrow(inp$harvests), 0)
  expect_false(all(is.na(inp$crop$crop_end)))
})

test_that("validate_excel_input() accepts a blank required column", {
  expect_no_error(validate_excel_input(fixture("blank_term_date.xlsx")))
})

test_that("an empty Soil_Disturbance sheet is read as zero typed rows", {
  inp <- prepare_shmi_inputs(fixture("no_tillage.xlsx"), verbose = FALSE)
  expect_equal(nrow(inp$dist), 0)
  expect_type(inp$dist$MGT_combo, "character")
  expect_s3_class(inp$dist$SD_date, "Date")
  expect_gt(nrow(inp$rot_bounds), 0)
})

test_that("a system with no tillage records scores Inverse disturbance 100", {
  inp <- prepare_shmi_inputs(fixture("no_tillage.xlsx"), verbose = FALSE)
  d <- compute_disturbance(inp$dist, inp$rot_bounds)
  expect_equal(sort(d$MGT_combo), sort(inp$rot_bounds$MGT_combo))
  expect_true(all(d$InvDist == 100))
})

test_that(".safe_read() returns typed columns for a missing sheet", {
  out <- SHMI:::.safe_read(get_shmi_example(), sheet = "No_Such_Sheet",
                           required_cols = c("MGT_combo", "SD_date"), skip = 3)
  expect_equal(nrow(out), 0)
  expect_type(out$MGT_combo, "character")
  expect_s3_class(out$SD_date, "Date")
  # binds with real data from another sheet
  real <- tibble::tibble(MGT_combo = "u1", SD_date = as.Date("2020-01-01"))
  expect_no_error(dplyr::bind_rows(real, out))
})

test_that("N assignment gives no min() warning when no harvest follows an application", {
  amend <- tibble::tibble(MGT_combo = "u1", SA_date = as.Date("2020-11-01"),
                          SA_cat = "Fertilizer", SA_N = 100, SA_units = "kg/ha")
  crop <- tibble::tibble(MGT_combo = "u1", CD_cat = "Annual", CD_name = "Corn",
                         CD_plant_date = as.Date("2020-05-01"),
                         CD_harv_date = as.Date("2020-10-01"), CD_term_date = as.Date(NA))
  rb <- tibble::tibble(MGT_combo = "u1", rot_start = as.Date("2020-01-01"),
                       rot_end = as.Date("2020-12-31"))
  w <- character()
  withCallingHandlers(SHMI:::.prepare_n_rate(amend, crop, rb),
                      warning = function(cnd) { w <<- c(w, conditionMessage(cnd)); invokeRestart("muffleWarning") })
  expect_false(any(grepl("no non-missing arguments", w)))
})

test_that("the climate cache is persistent and can be redirected", {
  withr::local_options(shmi.climate_dir = NULL)
  withr::local_envvar(SHMI_CLIMATE_DIR = "")
  d <- shmi_climate_dir()
  expect_false(startsWith(normalizePath(d, mustWork = FALSE), normalizePath(tempdir(), mustWork = FALSE)))
  expect_equal(basename(d), "worldclim")

  withr::local_options(shmi.climate_dir = file.path("X:", "shared"))
  expect_equal(shmi_climate_dir(), file.path("X:", "shared", "worldclim"))
})
