# Diversity: species richness over a rotation window (default 4 years)
rb_div <- data.frame(MGT_combo = "u1", rot_start = as.Date("2020-01-01"), rot_end = as.Date("2021-12-31"))

test_that("Diversity is species richness over a 4-year rotation window", {
  cs <- data.frame(MGT_combo = "u1", CD_name = c("Corn", "Soybean"),
                   crop_start = as.Date(c("2020-05-01", "2021-05-01")),
                   crop_end   = as.Date(c("2020-10-01", "2021-10-01")))
  expect_equal(compute_diversity(cs, rb_div)$Richness, 2)          # corn-soybean, record <= window
  expect_equal(compute_diversity(cs, rb_div)$Diversity, 100 / 7, tolerance = 1e-9)
  cc <- rbind(cs, data.frame(MGT_combo = "u1", CD_name = c("Rye", "Rye"),
                             crop_start = as.Date(c("2020-10-15", "2021-10-15")),
                             crop_end   = as.Date(c("2020-12-31", "2021-12-31"))))
  expect_equal(compute_diversity(cc, rb_div)$Richness, 3)          # plus a rye cover
  expect_equal(compute_diversity(cc, rb_div)$Diversity, 200 / 7, tolerance = 1e-9)
  mix <- data.frame(MGT_combo = "u1", CD_name = c("8-species", "Fallow"),
                    crop_start = as.Date(c("2020-01-01", "2021-01-01")),
                    crop_end   = as.Date(c("2021-12-31", "2021-12-31")))
  expect_equal(compute_diversity(mix, rb_div)$Diversity, 100)      # 8 species, fallow ignored
})

test_that("the window slides over long records", {
  y <- 2001:2008
  ccaa <- data.frame(MGT_combo = "u1", CD_name = rep(c("Corn", "Corn", "Alfalfa", "Alfalfa"), 2),
                     crop_start = as.Date(sprintf("%d-04-15", y)), crop_end = as.Date(sprintf("%d-10-01", y)))
  rb8 <- data.frame(MGT_combo = "u1", rot_start = as.Date("2001-01-01"), rot_end = as.Date("2008-12-31"))
  expect_equal(compute_diversity(ccaa, rb8, window = 4)$Richness, 2)   # every 4-year span holds both
  expect_equal(compute_diversity(ccaa, rb8, window = 2)$Richness, 10 / 7, tolerance = 1e-9)  # CC and AA spans count 1
})

test_that("window = 1 counts species per calendar year", {
  cs <- data.frame(MGT_combo = "u1", CD_name = c("Corn", "Soybean"),
                   crop_start = as.Date(c("2020-05-01", "2021-05-01")),
                   crop_end   = as.Date(c("2020-10-01", "2021-10-01")))
  expect_equal(compute_diversity(cs, rb_div, window = 1)$Richness, 1)
  expect_equal(compute_diversity(cs, rb_div, window = 1)$Diversity, 0)
  expect_error(compute_diversity(cs, rb_div, window = 0.5), "whole number")
})
