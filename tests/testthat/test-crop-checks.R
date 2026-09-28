# Data checks and category handling in .build_crop_windows()

rb <- data.frame(MGT_combo = "u1",
                 rot_start = as.Date("2017-01-01"), rot_end = as.Date("2018-12-31"))

crop_row <- function(name, cat, plant = NA, harv = NA, term = NA, unit = "u1") {
  data.frame(MGT_combo = unit, CD_cat = cat, CD_name = name,
             CD_plant_date = as.Date(plant), CD_harv_date = as.Date(harv),
             CD_term_date = as.Date(term), stringsAsFactors = FALSE)
}
types <- function(res) res$assumptions$type

test_that("categories are matched case- and whitespace-insensitively", {
  crop <- rbind(
    crop_row("Corn",     "Annual",       "2017-05-01", "2017-10-01"),
    crop_row("Soybean",  "CASH ",        "2018-05-01", "2018-10-01"),
    crop_row("Rye",      "Cover",        "2017-10-05", NA, "2018-04-20"),
    crop_row("Alfalfa",  " PERENNIAL",   "2017-01-01", "2017-06-01"),
    crop_row("Poplar",   "Woody Perennial", "2017-01-01", NA, "2018-12-31"),
    crop_row("Fallow",   "fallow",       "2017-01-01", NA, "2017-04-30")
  )
  res <- SHMI:::.build_crop_windows(crop, rb)
  cats <- setNames(res$windows$CD_cat, res$windows$CD_name)
  expect_equal(unname(cats[c("Corn", "Soybean", "Rye")]), rep("Annual", 3))
  expect_equal(unname(cats[c("Alfalfa", "Poplar")]), rep("Perennial", 2))
  expect_equal(unname(cats["Fallow"]), "Fallow")
  # perennial: harvest does not end the stand
  expect_true(res$windows$end_imputed[res$windows$CD_name == "Alfalfa"])
  # annual: ends at harvest
  expect_equal(res$windows$crop_end[res$windows$CD_name == "Corn"], as.Date("2017-10-01"))
})

test_that("missing and unrecognized categories are treated as annual and flagged", {
  crop <- rbind(crop_row("Corn",  NA,         "2017-05-01", "2017-10-01"),
                crop_row("Wheat", "perenial", "2017-10-10", "2018-07-01"))
  res <- SHMI:::.build_crop_windows(crop, rb)
  expect_true(all(res$windows$CD_cat == "Annual"))
  expect_equal(res$windows$crop_end[res$windows$CD_name == "Wheat"], as.Date("2018-07-01"))
  expect_true(all(c("missing_category", "unknown_category") %in% types(res)))
})

test_that("usually-annual species coded perennial are flagged", {
  crop <- rbind(crop_row("Oats",    "perennial", "2017-04-12", "2017-07-17"),
                crop_row("Alfalfa", "perennial", "2017-04-12", NA, "2018-11-26"))
  res <- SHMI:::.build_crop_windows(crop, rb)
  flagged <- res$assumptions$name[res$assumptions$type == "check_category_perennial"]
  expect_equal(flagged, "Oats")
})

test_that("ryegrass is not mistaken for cereal rye", {
  expect_true(SHMI:::.is_usually_annual(c("Rye", "Rye, Cereal", "Corn", "Oats")) |> all())
  expect_false(any(SHMI:::.is_usually_annual(c("Ryegrass, perennial", "Wheatgrass, intermediate",
                                               "Alfalfa"))))
})

test_that("placeholder species names are flagged", {
  crop <- rbind(crop_row("Species 1", "perennial", "2017-01-01", NA, "2018-12-31"),
                crop_row("unknown",   "cover",     "2017-10-01", NA, "2018-04-01"),
                crop_row("Clover, Red", "cover",   "2017-10-01", NA, "2018-04-01"))
  res <- SHMI:::.build_crop_windows(crop, rb)
  expect_setequal(res$assumptions$name[res$assumptions$type == "placeholder_name"],
                  c("Species 1", "unknown"))
})

test_that("annual episodes longer than 400 days are flagged; winter annuals are not", {
  rb2 <- data.frame(MGT_combo = "u1", rot_start = as.Date("2016-01-01"),
                    rot_end = as.Date("2017-12-31"))
  crop <- rbind(crop_row("Rye",    "cover", "2016-10-05"),                       # no end -> rot_end
                crop_row("Canola", "cash",  "2016-08-20", "2017-08-20"))         # 366 days
  res <- SHMI:::.build_crop_windows(crop, rb2)
  long <- res$assumptions$name[res$assumptions$type == "annual_long_episode"]
  expect_equal(long, "Rye")
})
