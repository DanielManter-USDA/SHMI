# compute_diversity(): Shannon entropy (hill = 1) scaled by log(max_div).

test_that("a single species scores 0", {
  out <- compute_diversity(win("Corn", "2017-01-01", "2017-12-31"))
  expect_equal(out$Diversity, 0)
})

test_that("two species with equal days score log(2)/log(10)", {
  crop <- dplyr::bind_rows(
    win("Corn",    "2016-05-01", "2016-09-30"),
    win("Soybean", "2017-05-01", "2017-09-30")
  )
  out <- compute_diversity(crop)
  expect_equal(out$Diversity, 100 * log(2) / log(10), tolerance = 1e-8)
})

test_that("overlapping episodes of the same species count once", {
  crop <- dplyr::bind_rows(
    win("Rye",   "2017-01-01", "2017-06-30"),
    win("Rye",   "2017-03-01", "2017-12-31"),   # union with above = full year
    win("Vetch", "2017-01-01", "2017-12-31")
  )
  out <- compute_diversity(crop)
  expect_equal(out$Diversity, 100 * log(2) / log(10), tolerance = 1e-8)
})

test_that("a duplicated row does not change diversity", {
  crop <- dplyr::bind_rows(
    win("Corn",    "2016-05-01", "2016-09-30"),
    win("Soybean", "2017-05-01", "2017-09-30")
  )
  expect_equal(
    compute_diversity(dplyr::bind_rows(crop, crop[1, ]))$Diversity,
    compute_diversity(crop)$Diversity
  )
})

test_that("placeholder '8-species' expands to 8 equal species", {
  out <- compute_diversity(win("8-species", "2017-01-01", "2017-12-31"))
  expect_equal(out$Diversity, 100 * log(8) / log(10), tolerance = 1e-8)
})

test_that("fallow is excluded from diversity", {
  crop <- dplyr::bind_rows(
    win("Corn",   "2016-05-01", "2016-09-30"),
    win("fallow", "2017-01-01", "2017-12-31")
  )
  expect_equal(compute_diversity(crop)$Diversity, 0)
})

test_that("richness (hill = 0) is scaled by max_div, not log(max_div)", {
  crop <- dplyr::bind_rows(
    win("Corn",    "2016-05-01", "2016-09-30"),
    win("Soybean", "2017-05-01", "2017-09-30"),
    win("Wheat",   "2017-10-01", "2018-06-30")
  )
  out <- compute_diversity(crop, hill = 0, max_div = 10)
  expect_equal(out$Diversity, 30)
})

# ---- Species identity and placeholder mixtures (item 5) ----

test_that("full names are distinct species ('Rye' vs 'Rye, Cereal')", {
  crop <- dplyr::bind_rows(
    win("Rye",         "2017-01-01", "2017-12-31"),   # 365 days each
    win("Rye, Cereal", "2018-01-01", "2018-12-31")
  )
  expect_equal(compute_diversity(crop)$Diversity, 100 * log(2) / log(10),
               tolerance = 1e-8)
})

test_that("extra whitespace does not create a new species", {
  crop <- dplyr::bind_rows(
    win("Rye, Cereal",   "2016-01-01", "2016-12-31"),
    win(" Rye,  Cereal", "2017-01-01", "2017-12-31")
  )
  expect_equal(compute_diversity(crop)$Diversity, 0)
})

test_that("count-first placeholder spellings all expand", {
  for (nm in c("8-species", "8 species", "8species", "8-spp", "8-Species mix")) {
    out <- compute_diversity(win(nm, "2017-01-01", "2017-12-31"))
    expect_equal(out$Diversity, 100 * log(8) / log(10), tolerance = 1e-8,
                 info = nm)
  }
})

test_that("'Species 1' / 'Species 2' are two named species, not placeholders", {
  crop <- dplyr::bind_rows(
    win("Species 1", "2017-01-01", "2017-12-31"),
    win("Species 2", "2017-01-01", "2017-12-31")
  )
  expect_equal(compute_diversity(crop)$Diversity, 100 * log(2) / log(10),
               tolerance = 1e-8)
})

test_that("'Multi-species' without a count is a single named entry", {
  out <- compute_diversity(win("Multi-species", "2017-01-01", "2017-12-31"))
  expect_equal(out$Diversity, 0)
})

test_that(".placeholder_n recognizes counts only in count-first names", {
  expect_equal(
    .placeholder_n(c("8-species", "5 spp", "Species 2", "species-8",
                     "Multi-species", "Corn", NA)),
    c(8L, 5L, NA, NA, NA, NA, NA)
  )
})
