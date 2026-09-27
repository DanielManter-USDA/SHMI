# compute_cover(): union of overlapping windows, season weighting.
# Official weights sum to 1, so a fully covered summer alone scores
# 100 * 0.3755 = 37.55.

rb17 <- rot("2017-01-01", "2017-12-31")

test_that("full-year cover scores 100", {
  out <- compute_cover(win("Rye", "2017-01-01", "2017-12-31"), rb17)
  expect_equal(out$Cover, 100, tolerance = 1e-8)
})

test_that("covering exactly one season scores that season's weight", {
  out <- compute_cover(win("Corn", "2017-06-01", "2017-08-31"), rb17)
  expect_equal(out$Cover, 37.55, tolerance = 1e-6)
})

test_that("a two-species mixture on the same window counts each day once", {
  crop <- dplyr::bind_rows(
    win("Oats", "2017-06-01", "2017-08-31"),
    win("Pea",  "2017-06-01", "2017-08-31")
  )
  expect_equal(compute_cover(crop, rb17)$Cover, 37.55, tolerance = 1e-6)
})

test_that("relay overlap counts each day once", {
  crop <- dplyr::bind_rows(
    win("Wheat",   "2017-06-01", "2017-07-31"),
    win("Soybean", "2017-07-01", "2017-08-31")
  )
  expect_equal(compute_cover(crop, rb17)$Cover, 37.55, tolerance = 1e-6)
})

test_that("fallow contributes no cover", {
  out <- compute_cover(win("fallow", "2017-01-01", "2017-12-31"), rb17)
  expect_equal(out$Cover, 0)
})

test_that("a unit with no crop rows scores 0", {
  rb <- dplyr::bind_rows(rb17, rot("2017-01-01", "2017-12-31", MGT_combo = "U2"))
  out <- compute_cover(win("Rye", "2017-01-01", "2017-12-31"), rb)
  expect_equal(out$Cover[out$MGT_combo == "U2"], 0)
})

test_that("fallow-only reference units are kept and score 0 alongside cropped units", {
  crop <- dplyr::bind_rows(
    win("Corn",   "2017-05-01", "2017-09-30", MGT_combo = "U1"),
    win("fallow", "2017-01-01", "2017-12-31", MGT_combo = "REF")
  )
  rb <- dplyr::bind_rows(
    rot("2017-01-01", "2017-12-31", MGT_combo = "U1"),
    rot("2017-01-01", "2017-12-31", MGT_combo = "REF")
  )
  out <- compute_cover(crop, rb)

  expect_setequal(out$MGT_combo, c("U1", "REF"))
  expect_equal(out$Cover[out$MGT_combo == "REF"], 0)
  expect_gt(out$Cover[out$MGT_combo == "U1"], 0)
})
