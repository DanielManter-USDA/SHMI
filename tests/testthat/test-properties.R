# Properties that must hold for any input.

# A unit combining several of the tricky cases
mixed_unit <- function() {
  crop_rows(
    CD_cat  = c("cash", "cash", "cash", "cover", "cover",
                "perennial", "perennial", "perennial", "cash"),
    CD_name = c("Wheat, Winter", "Clover, Red", "Corn", "Oats", "Rye",
                "Alfalfa", "Alfalfa", "Alfalfa", "Soybean"),
    plant   = c(NA, "2016-03-15", "2016-07-10", "2016-10-20", "2016-10-20",
                "2017-04-15", NA, NA, "2019-05-10"),
    harv    = c("2016-06-20", "2016-06-20", "2016-10-01", NA, NA,
                "2017-07-13", "2017-08-30", "2018-06-29", "2019-10-05"),
    term    = c(NA, NA, NA, "2017-04-01", "2017-04-01",
                NA, NA, NA, NA)
  )
}
rb_mixed <- rot("2016-01-01", "2019-12-31")

test_that("crop windows do not depend on input row order", {
  crop <- mixed_unit()
  ref  <- .build_crop_windows(crop, rb_mixed)
  set.seed(1)
  for (k in 1:5) {
    shuffled <- crop[sample(nrow(crop)), ]
    res <- .build_crop_windows(shuffled, rb_mixed)
    expect_equal(canon(dplyr::select(res$windows, -episode_id)),
                 canon(dplyr::select(ref$windows, -episode_id)))
    expect_equal(canon(res$assumptions), canon(ref$assumptions))
  }
})

test_that("CD_seq_num and CD_mix are ignored", {
  crop <- mixed_unit()
  ref  <- .build_crop_windows(crop, rb_mixed)
  junk <- crop %>%
    dplyr::mutate(CD_seq_num = sample(1:3, dplyr::n(), replace = TRUE),
                  CD_mix = sample(c("yes", "no", NA), dplyr::n(), replace = TRUE))
  res <- .build_crop_windows(junk, rb_mixed)
  expect_equal(res$windows, ref$windows)
})

test_that("duplicating a crop row does not change Cover or Diversity", {
  crop <- mixed_unit()
  ref  <- .build_crop_windows(crop, rb_mixed)$windows
  dup  <- .build_crop_windows(dplyr::bind_rows(crop, crop[c(3, 6), ]), rb_mixed)$windows

  expect_equal(compute_cover(dup, rb_mixed)$Cover,
               compute_cover(ref, rb_mixed)$Cover)
  expect_equal(compute_diversity(dup)$Diversity,
               compute_diversity(ref)$Diversity)
})

test_that("crop windows stay inside the rotation bounds and start <= end", {
  w <- .build_crop_windows(mixed_unit(), rb_mixed)$windows
  expect_true(all(w$crop_start <= w$crop_end))
  expect_true(all(w$crop_start >= rb_mixed$rot_start))
  expect_true(all(w$crop_end   <= rb_mixed$rot_end))
})

test_that("pillar scores stay within [0, 100]", {
  w <- .build_crop_windows(mixed_unit(), rb_mixed)$windows
  cov <- compute_cover(w, rb_mixed)$Cover
  div <- compute_diversity(w)$Diversity
  expect_true(all(cov >= 0 & cov <= 100))
  expect_true(all(div >= 0 & div <= 100))
})
