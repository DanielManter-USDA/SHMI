# compute_orginput(): presence per rotation year, weighted 0.6615 / 0.3385.

rb2 <- rot("2016-01-01", "2017-12-31")
no_amend  <- tibble::tibble(MGT_combo = character(), SA_date = as.Date(character()),
                            SA_cat = character())
no_animal <- tibble::tibble(MGT_combo = character(), AD_start_date = as.Date(character()))

test_that("no organic inputs scores 0", {
  out <- compute_orginput(rb2, no_amend, no_animal)
  expect_equal(out$OrgInput, 0)
})

test_that("an organic amendment in one of two years scores 100 * 0.6615 * 0.5", {
  amend <- tibble::tibble(MGT_combo = "U1", SA_date = as.Date("2016-06-01"),
                          SA_cat = "Organic")
  out <- compute_orginput(rb2, amend, no_animal)
  expect_equal(out$OrgInput, 33.075, tolerance = 1e-8)
})

test_that("non-organic amendments are not counted", {
  amend <- tibble::tibble(MGT_combo = "U1", SA_date = as.Date("2016-06-01"),
                          SA_cat = "Fertilizer")
  expect_equal(compute_orginput(rb2, amend, no_animal)$OrgInput, 0)
})

test_that("amendments and animals in every year score 100", {
  amend  <- tibble::tibble(MGT_combo = "U1", SA_cat = "Organic",
                           SA_date = as.Date(c("2016-06-01", "2017-06-01")))
  animal <- tibble::tibble(MGT_combo = "U1",
                           AD_start_date = as.Date(c("2016-08-01", "2017-08-01")))
  expect_equal(compute_orginput(rb2, amend, animal)$OrgInput, 100, tolerance = 1e-8)
})
