# compute_disturbance() and the method checks in .check_dist_method().
# With ti_rep = "max": class Z -> 100, class K -> 0.

rb17 <- rot("2017-01-01", "2017-12-31")

test_that("a unit with no disturbance passes scores 100", {
  out <- compute_disturbance(passes("2017-05-01", 0)[0, ], rb17,
                             dist_meth = "STIR", ti_rep = "max")
  expect_equal(out$InvDist, 100)
})

test_that("STIR of zero scores 100 and STIR >= max_stir scores 0", {
  zero <- compute_disturbance(passes("2017-05-01", 0), rb17,
                              dist_meth = "STIR", ti_rep = "max")
  high <- compute_disturbance(passes(c("2017-04-01", "2017-10-01"), c(171, 171)),
                              rb17, dist_meth = "STIR", ti_rep = "max")
  expect_equal(zero$InvDist, 100)
  expect_equal(high$InvDist, 0)
})

test_that("rotation InvDist is the mean of annual values", {
  rb <- rot("2016-01-01", "2017-12-31")
  out <- compute_disturbance(passes("2017-05-01", 342), rb,
                             dist_meth = "STIR", ti_rep = "max")
  expect_equal(out$InvDist, 50)   # 2016: 100, 2017: 0
})

test_that("EPA: three same-day passes use cumulative disturbed depth", {
  # 3 passes, mixeff 0.5, 10 cm: disturbed = 10 * (1 - 0.5^3) = 8.75 cm
  # TI = 8.75 / 30 = 0.292 -> class J -> InvDist = 100 * (1 - 0.449) = 55.1.
  # The pre-fix code gives 7.5 cm -> class H -> 74.8.
  d <- passes(rep("2017-05-01", 3), rep(0.5, 3), depth = rep(10 / 2.54, 3))
  out <- compute_disturbance(d, rb17, dist_meth = "EPA", ti_rep = "max")
  expect_equal(out$InvDist, 55.1, tolerance = 1e-6)
})

test_that("EPA check: passes with mixing but no depth are an error", {
  d <- passes(c("2017-05-01", "2017-06-01"), c(0.5, 0.3), depth = c(4, NA))
  expect_length(.check_dist_method(d, "EPA")$errors, 1)
})

test_that("EPA check: zero-mixing passes do not need a depth", {
  d <- passes(c("2017-05-01", "2017-06-01"), c(0.5, 0), depth = c(4, NA))
  expect_length(.check_dist_method(d, "EPA")$errors, 0)
})

test_that("EPA check: SD_mixeff above 1 (STIR values) is an error", {
  d <- passes("2017-05-01", 39, depth = 4)
  expect_true(any(grepl("expects SD_mixeff in \\[0, 1\\]",
                        .check_dist_method(d, "EPA")$errors)))
})

test_that("STIR check: values that look like proportions give a warning", {
  d <- passes(c("2017-05-01", "2017-06-01"), c(0.5, 0.3))
  chk <- .check_dist_method(d, "STIR")
  expect_length(chk$errors, 0)
  expect_length(chk$warnings, 1)
})
