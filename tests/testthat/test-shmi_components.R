p_cols <- c("p_winter", "p_spring", "p_summer", "p_fall")
cover_from <- function(comp, w) 100 * as.vector(as.matrix(comp[, p_cols]) %*% (w / sum(w)))
aligned   <- function(x, ids_x, ids_ref) x[match(ids_ref, ids_x)]
rand_w    <- function(k) stats::runif(k, 0.01, 1)

example_inputs <- function() prepare_shmi_inputs(get_shmi_example(), verbose = FALSE)

# Synthetic units covering the edge cases, including episodes outside the window
edge_crop <- data.frame(
  MGT_combo  = c("a", "a", "a", "b", "c", "c"),
  CD_name    = c("Wheat", "Clover", "Fallow", "fallow", "Alfalfa", "Rye"),
  crop_start = as.Date(c("2019-10-01", "2020-03-01", "2020-07-01", "2019-01-01",
                         "2017-04-01", "2020-10-01")),
  crop_end   = as.Date(c("2020-06-30", "2020-05-31", "2020-09-30", "2020-12-31",
                         "2020-08-31", "2021-05-31"))
)
edge_rb <- data.frame(MGT_combo = c("a", "b", "c"),
                      rot_start = as.Date(c("2019-06-15", "2019-06-15", "2019-01-01")),
                      rot_end   = as.Date("2020-12-31"))

# ---- Regression against frozen SHMI 1.1.0 --------------------------------

test_that("clip_to_rotation = FALSE reproduces 1.1.0 compute_cover exactly", {
  inp <- example_inputs()
  set.seed(1)
  for (dat in list(list(inp$crop, inp$rot_bounds), list(edge_crop, edge_rb))) {
    comp <- compute_cover_components(dat[[1]], dat[[2]], clip_to_rotation = FALSE)
    for (i in 1:20) {
      w   <- rand_w(4)
      ref <- legacy_compute_cover_v110(dat[[1]], dat[[2]], w[1], w[2], w[3], w[4])
      ref <- ref[ref$MGT_combo %in% comp$MGT_combo, ]
      expect_equal(aligned(cover_from(comp, w), comp$MGT_combo, ref$MGT_combo),
                   ref$Cover, tolerance = 1e-8)
    }
  }
})

test_that("clipping changes nothing when all episodes lie inside the window", {
  inp  <- example_inputs()
  comp <- compute_cover_components(inp$crop, inp$rot_bounds, TRUE)
  skip_if(any(comp$outside_days > 0), "example data has episodes outside the window")
  legacy <- compute_cover_components(inp$crop, inp$rot_bounds, FALSE)
  expect_equal(as.matrix(comp[, p_cols]), as.matrix(legacy[, p_cols]), tolerance = 1e-12)
})

test_that("clipping bounds proportions to [0, 1]; legacy does not", {
  clip   <- compute_cover_components(edge_crop, edge_rb, TRUE)
  legacy <- compute_cover_components(edge_crop, edge_rb, FALSE)
  expect_true(all(as.matrix(clip[, p_cols]) <= 1 + 1e-12))
  expect_gt(clip$outside_days[clip$MGT_combo == "c"], 0)
  expect_gt(max(as.matrix(legacy[legacy$MGT_combo == "c", p_cols])), 1)
  expect_equal(unlist(clip[clip$MGT_combo == "b", p_cols]), rep(0, 4), ignore_attr = TRUE)
})

test_that("refactored compute_cover = weighted components, and matches 1.1.0 doc example", {
  w_off <- c(0.1259, 0.1260, 0.3755, 0.3726)
  crop <- data.frame(MGT_combo = "field_1", CD_name = c("Corn", "Rye"),
                     crop_start = as.Date(c("2020-05-01", "2020-10-15")),
                     crop_end   = as.Date(c("2020-09-30", "2020-12-31")))
  rb <- data.frame(MGT_combo = "field_1", rot_start = as.Date("2020-01-01"),
                   rot_end = as.Date("2020-12-31"))
  expect_equal(compute_cover(crop, rb)$Cover, legacy_compute_cover_v110(crop, rb)$Cover,
               tolerance = 1e-10)
  expect_equal(round(compute_cover(crop, rb)$Cover, 1), 77.6)
  expect_no_error(compute_cover(crop, rb, 1, 0, 0, 0))        # zero weights allowed
  expect_error(compute_cover(crop, rb, -1, 1, 1, 1))
})

test_that("OrgInput components reproduce 1.1.0 compute_orginput", {
  rb <- data.frame(MGT_combo = c("f1", "f2"), rot_start_yr = c(2019, 2018),
                   rot_end_yr = c(2020, 2021))
  amend <- data.frame(MGT_combo = c("f1", "f2", "f2", "f2"),
                      SA_date = as.Date(c("2019-04-01", "2018-05-01", "2020-05-01", "2016-05-01")),
                      SA_cat = c("Organic", "Organic", "Inorganic", "Organic"))
  animal <- data.frame(MGT_combo = c("f2", "f2"),
                       AD_start_date = as.Date(c("2019-06-01", "2021-06-01")),
                       AD_end_date   = as.Date(c("2020-10-01", NA)))
  comp <- compute_orginput_components(rb, amend, animal, "start")
  set.seed(2)
  for (i in 1:20) {
    w   <- rand_w(2)
    ref <- legacy_compute_orginput_v110(rb, amend, animal, w[1], w[2])
    new <- compute_orginput(rb, amend, animal, w[1], w[2])
    expect_equal(aligned(new$OrgInput, new$MGT_combo, ref$MGT_combo), ref$OrgInput,
                 tolerance = 1e-10)
  }
  expect_equal(round(legacy_compute_orginput_v110(rb[1, ], amend, animal)$OrgInput, 1), 33.1)

  span <- compute_orginput_components(rb, amend, animal, "span")
  expect_equal(comp$p_animal[comp$MGT_combo == "f2"], 2 / 4)   # starts in 2019, 2021
  expect_equal(span$p_animal[span$MGT_combo == "f2"], 3 / 4)   # 2019, 2020, 2021
})

test_that("patched compute_disturbance reproduces 1.1.0 (STIR and EPA, all ti_rep)", {
  set.seed(3)
  rb <- data.frame(MGT_combo = paste0("u", 1:40), rot_start_yr = 2018, rot_end_yr = 2021)
  n  <- 400
  dates <- as.Date("2018-01-01") + sample(0:(4 * 365), n, replace = TRUE)
  units <- sample(rb$MGT_combo, n, replace = TRUE)
  stir <- data.frame(MGT_combo = units, SD_date = dates,
                     SD_mixeff = round(stats::rexp(n, 1 / 40), 1))
  epa  <- data.frame(MGT_combo = units, SD_date = dates,
                     SD_mixeff = round(stats::runif(n), 2),
                     SD_depth  = round(stats::runif(n, 0, 12), 1))
  for (rep in c("max", "min", "mid")) {
    for (ms in c(150, 342, 500)) {
      a <- compute_disturbance(stir, rb, "STIR", max_stir = ms, ti_rep = rep)
      b <- legacy_compute_disturbance_v110(stir, rb, "STIR", max_stir = ms, ti_rep = rep)
      expect_equal(a$InvDist, b$InvDist, tolerance = 1e-10)
    }
    a <- compute_disturbance(epa, rb, "EPA", ti_rep = rep)
    b <- legacy_compute_disturbance_v110(epa, rb, "EPA", ti_rep = rep)
    expect_equal(a$InvDist, b$InvDist, tolerance = 1e-10)
  }
})

test_that("compute_shmi_components passes its internal check on the example", {
  inp <- example_inputs()
  expect_no_error(comp <- compute_shmi_components(inp))
  expect_true(all(c("C_winter", "O_animal", "Diversity", "InvDist") %in% names(comp)))
})
