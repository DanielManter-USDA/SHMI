# SHMI 1.0: sub-indices and build_shmi()

rb1 <- data.frame(MGT_combo = "u1", rot_start = as.Date("2020-01-01"), rot_end = as.Date("2021-12-31"),
                  rot_start_yr = 2020L, rot_end_yr = 2021L)
climate_for <- function(units, tavg = c(-5, -3, 3, 10, 16, 21, 24, 23, 18, 11, 4, -2),
                        prec = c(30, 30, 50, 80, 100, 110, 100, 90, 80, 60, 50, 35), irrigated = FALSE) {
  cl <- data.frame(MGT_combo = units)
  cl[sprintf("tavg_%02d", 1:12)] <- as.list(tavg)
  cl[sprintf("prec_%02d", 1:12)] <- as.list(prec)
  cl$irrigated <- irrigated
  cl
}

test_that("official weights sum to 1", {
  expect_equal(sum(shmi_weights()), 1)
  expect_named(shmi_weights(), c("Cover", "OrgInput", "Diversity", "InvDist"))
})

test_that("Diversity is average annual species richness", {
  cs <- data.frame(MGT_combo = "u1", CD_name = c("Corn", "Soybean"),
                   crop_start = as.Date(c("2020-05-01", "2021-05-01")),
                   crop_end   = as.Date(c("2020-10-01", "2021-10-01")))
  expect_equal(compute_diversity(cs, rb1)$Richness, 1)          # rotation of single crops
  expect_equal(compute_diversity(cs, rb1)$Diversity, 0)
  cc <- rbind(cs, data.frame(MGT_combo = "u1", CD_name = c("Rye", "Rye"),
                             crop_start = as.Date(c("2020-10-15", "2021-10-15")),
                             crop_end   = as.Date(c("2020-12-31", "2021-12-31"))))
  expect_equal(compute_diversity(cc, rb1)$Richness, 2)          # cover crop every year
  expect_equal(compute_diversity(cc, rb1)$Diversity, 100 / 7, tolerance = 1e-9)
  mix <- data.frame(MGT_combo = "u1", CD_name = c("8-species", "Fallow"),
                    crop_start = as.Date(c("2020-01-01", "2021-01-01")),
                    crop_end   = as.Date(c("2021-12-31", "2021-12-31")))
  expect_equal(compute_diversity(mix, rb1)$Diversity, 100)      # 8 species, fallow ignored
})

test_that("growing season: warm and not dry, unless irrigated", {
  cl <- climate_for("u1", prec = c(30, 30, 50, 80, 100, 10, 100, 90, 80, 60, 50, 35))  # June dry
  expect_false(growing_months(cl)["u1", "Jun"])
  expect_true(growing_months(cl)["u1", "Jul"])
  expect_false(growing_months(cl)["u1", "Jan"])                 # too cold
  cl$irrigated <- TRUE
  expect_true(growing_months(cl)["u1", "Jun"])
})

test_that("Cover weights the growing and non-growing seasons", {
  rb <- rb1[1, ]; rb$rot_end <- as.Date("2020-12-31"); rb$rot_end_yr <- 2020L
  cl <- climate_for("u1")
  act <- growing_months(cl)["u1", ]
  # plants exactly in the growing months of 2020 (April-October here)
  crop <- data.frame(MGT_combo = "u1", CD_name = "Corn",
                     crop_start = as.Date("2020-04-01"), crop_end = as.Date("2020-10-31"))
  expect_equal(unname(which(act)), 4:10)
  cv <- compute_cover(crop, rb, cl)
  expect_equal(cv$Cover_growing, 100)
  expect_equal(cv$Cover_nongrowing, 0)
  expect_equal(cv$Cover, 86.0)
  expect_error(compute_cover(crop, rb, climate_for("other")), "No climate")
})

test_that("Organic Inputs counts years with an amendment or animals", {
  amend  <- data.frame(MGT_combo = "u1", SA_date = as.Date("2020-04-01"), SA_cat = "Organic")
  animal <- data.frame(MGT_combo = "u1", AD_start_date = as.Date("2020-11-01"), AD_end_date = as.Date("2021-02-01"))
  none   <- animal[0, ]
  expect_equal(compute_orginput(rb1, amend, none)$OrgInput, 50)
  expect_equal(compute_orginput(rb1, amend, animal)$OrgInput, 100)   # grazing spans both years
})

# ---- Disturbance: T-DISC ----
rb20 <- data.frame(MGT_combo = "u1", rot_start_yr = 2020L, rot_end_yr = 2020L)
pass <- function(date, equip = NA, me = NA, depth = NA, stir = NA)
  data.frame(MGT_combo = "u1", SD_date = as.Date(date), SD_equip = equip, SD_mixeff = me, SD_depth = depth,
             SD_stir = stir)

test_that("T-DISC tables are complete", {
  imp <- tdisc_implements(); mp <- tdisc_mapping()
  expect_true(nrow(imp) >= 90)
  expect_true(all(c("implement", "mixing_efficiency", "depth_cm") %in% names(imp)))
  expect_true(all(toupper(mp$implement) %in% toupper(imp$implement)))
})

test_that("an implement name takes T-DISC values; class upper bound scores the interval", {
  d <- compute_disturbance(pass("2020-04-15", "HARROW, DISK, TANDEM, HEAVYDUTY"), rb20)
  expect_equal(d$TI, 0.4)                       # 0.8 x 15 cm / 30
  expect_equal(d$InvDist, 100 * (1 - 0.449))    # class J
  expect_equal(d$designation, "CT")
  expect_error(compute_disturbance(pass("2020-04-15", "NO SUCH IMPLEMENT"), rb20), "No T-DISC values")
})

test_that("overrides: either value alone, both together, or a user implement table", {
  disk <- "HARROW, DISK, TANDEM, HEAVYDUTY"                       # T-DISC: 0.8 at 15 cm
  dep <- compute_disturbance(pass("2020-04-15", disk, depth = 4), rb20)
  expect_equal(dep$TI, 0.8 * 4 * 2.54 / 30)                         # T-DISC mixing efficiency, user depth
  mix <- compute_disturbance(pass("2020-04-15", disk, me = 0.5), rb20)
  expect_equal(mix$TI, 0.5 * 15 / 30)                               # user mixing efficiency, T-DISC depth
  bare <- compute_disturbance(pass("2020-04-15", me = 0.5, depth = 4), rb20)
  expect_equal(bare$TI, 0.5 * 4 * 2.54 / 30)                        # both values need no implement
  expect_error(compute_disturbance(pass("2020-04-15", me = 0.5), rb20), "implement name|no implement")
})

test_that("an operation mapped to several implements takes both overrides or neither", {
  op <- "Drill or air seeder, double disk"                          # drill + light tandem disk
  expect_gt(compute_disturbance(pass("2020-04-15", op), rb20)$TI, 0.2)
  expect_error(compute_disturbance(pass("2020-04-15", op, depth = 2), rb20), "several T-DISC implements")
  expect_equal(compute_disturbance(pass("2020-04-15", op, me = 0.1, depth = 2), rb20)$TI, 0.1 * 2 * 2.54 / 30)
})

test_that("STIR-like values in SD_mixeff are rejected for EPA scoring", {
  expect_error(compute_disturbance(pass("2020-04-15", "PLOW, CHISEL", me = 39), rb20), "SD_stir")
})

test_that("a pass's own values, then the user's implement table, override T-DISC", {
  own <- compute_disturbance(pass("2020-04-15", "HARROW, DISK, TANDEM, HEAVYDUTY", 0.5, 4), rb20)
  expect_equal(own$TI, 0.5 * 4 * 2.54 / 30)
  mine <- data.frame(implement = "harrow, disk, tandem, heavyduty", mixing_efficiency = 0.6, depth_cm = 10)
  usr <- compute_disturbance(pass("2020-04-15", "HARROW, DISK, TANDEM, HEAVYDUTY"), rb20, implements = mine)
  expect_equal(usr$TI, 0.2)
})

test_that("passes in one window combine by the mixing recurrence, not by addition", {
  two <- rbind(pass("2020-04-01", me = 0.5, depth = 4), pass("2020-04-10", me = 0.5, depth = 4))
  d <- compute_disturbance(two, rb20)
  S <- 0.5 * 10.16; S <- S + 0.5 * (10.16 - S)
  expect_equal(d$TI, S / 30)
  expect_equal(d$InvDist, 100 * (1 - 0.268))    # class I
})

test_that("a cash-crop interval is rated by its most intense window", {
  crop <- data.frame(MGT_combo = "u1", CD_name = "Corn", crop_start = as.Date("2020-05-01"),
                     crop_end = as.Date("2020-10-01"))
  harv <- data.frame(MGT_combo = "u1", CD_name = "Corn", CD_cat = "cash", harv_date = as.Date("2020-10-01"))
  dist <- rbind(pass("2020-02-01", "HARROW, DISK, TANDEM, HEAVYDUTY"),   # field preparation: 0.40
                pass("2020-06-15", me = 0.5, depth = 4))                 # after planting: 0.17
  d <- compute_disturbance(dist, rb20, crop = crop, harvests = harv, details = TRUE)
  iv <- attr(d, "intervals")
  expect_equal(nrow(iv), 2)                     # the corn interval, then the rest of 2020
  expect_equal(iv$TI[1], 0.4)
  expect_equal(iv$TI[2], 0)
  expect_equal(d$InvDist, (100 * (1 - 0.449) * 275 + 100 * 91) / 366)
  # the same two passes in one calendar-year window would combine instead
  one <- compute_disturbance(dist, rb20)
  expect_gt(one$TI, 0.4)
})

test_that("STIR is summed within a window and divided by max_stir (135)", {
  d <- compute_disturbance(rbind(pass("2020-04-01", stir = 39), pass("2020-04-20", stir = 28.5)),
                           rb20, dist_meth = "STIR")
  expect_equal(d$TI, (39 + 28.5) / 135)
  expect_equal(d$InvDist, 0)                    # 0.5 is class K
  # workbooks from before SD_stir kept STIR values in SD_mixeff
  old <- data.frame(MGT_combo = "u1", SD_date = as.Date(c("2020-04-01", "2020-04-20")), SD_mixeff = c(39, 28.5))
  expect_equal(compute_disturbance(old, rb20, dist_meth = "STIR")$TI, (39 + 28.5) / 135)
})

test_that("build_shmi combines the sub-indices with the official weights", {
  inp <- prepare_shmi_inputs(get_shmi_example(), verbose = FALSE)
  cl  <- climate_for(inp$mgt$MGT_combo)
  res <- suppressMessages(build_shmi(inp, cl))          # EPA, the default
  dm  <- res$dist_meth
  d   <- res$indicator_df
  w   <- shmi_weights()
  expect_equal(dm, "EPA")
  expect_true(res$official)
  expect_equal(nrow(d), nrow(inp$mgt))
  expect_equal(d$SHMI, w[["Cover"]] * d$Cover + w[["OrgInput"]] * d$OrgInput +
                 w[["Diversity"]] * d$Diversity + w[["InvDist"]] * d$InvDist)
  expect_true(all(d$tillage_designation %in% c("NT", "RT", "CT")))
  for (k in c("SHMI", "Cover", "OrgInput", "Diversity", "InvDist")) {
    expect_true(all(d[[k]] >= 0 & d[[k]] <= 100), info = k)
  }
  expect_error(suppressMessages(build_shmi(inp, cl[-1, ], dist_meth = dm)), "No climate")
  cw <- suppressMessages(build_shmi(inp, cl, dist_meth = dm,
                                    weights = c(Cover = 1, OrgInput = 1, Diversity = 1, InvDist = 1)))
  expect_false(cw$official)
  expect_equal(unname(cw$weights), rep(0.25, 4))
  expect_error(suppressMessages(build_shmi(inp, cl, dist_meth = dm, weights = c(Cover = 1))), "weights")
})

test_that("tillage scale is detected from the records", {
  stir   <- data.frame(SD_stir = c(39, 2.4), SD_mixeff = NA, SD_depth = NA)
  legacy <- data.frame(SD_mixeff = c(39, 2.4), SD_depth = NA)
  epa    <- data.frame(SD_mixeff = c(0.8, 0.3), SD_depth = c(4, 2))
  equip  <- data.frame(SD_equip = "PLOW, CHISEL", SD_mixeff = NA, SD_depth = NA, SD_stir = 12)
  expect_equal(SHMI:::.resolve_dist_meth(stir, "auto"), "STIR")
  expect_equal(SHMI:::.resolve_dist_meth(legacy, "auto"), "STIR")
  expect_equal(SHMI:::.resolve_dist_meth(epa, "auto"), "EPA")
  expect_equal(SHMI:::.resolve_dist_meth(equip, "auto"), "EPA")
  expect_equal(SHMI:::.resolve_dist_meth(epa, "STIR"), "STIR")
  # the intensive-tillage rule keeps STIR whenever STIR values are recorded
  expect_equal(SHMI:::.tillage_method(equip), "STIR")
  expect_equal(SHMI:::.tillage_method(data.frame(SD_equip = "PLOW, CHISEL", SD_mixeff = NA)), "EPA")
})

test_that("irrigation and coordinates come from Mgt_Unit", {
  expect_equal(SHMI:::.is_irrigated(c("Sprinkler, Pivot", "None", "", NA, "No", "Drip")),
               c(TRUE, FALSE, FALSE, FALSE, FALSE, TRUE))
  inp <- prepare_shmi_inputs(get_shmi_example(), verbose = FALSE)
  expect_true("irrigated" %in% names(inp$mgt))
  expect_true(all(inp$mgt$irrigated))                       # every example unit is sprinkler-irrigated
  loc <- SHMI:::.climate_locations(inp)
  expect_equal(nrow(loc), nrow(inp$mgt))
  expect_true(all(abs(loc$lat) <= 90 & abs(loc$lon) <= 180))
  expect_error(SHMI:::.climate_locations(list(mgt = data.frame(MGT_combo = "u1"))), "MGT_lat")
})

test_that("a cash crop's termination ends its T-DISC interval when it has no harvest date", {
  inp <- prepare_shmi_inputs(get_shmi_example(), verbose = FALSE)
  expect_gt(nrow(inp$harvests), 0)                          # example crops end by termination only
  expect_true(all(inp$harvests$CD_cat %in% c("annual", "cash", "cover", "perennial", "fallow")))
})

test_that("workbook irrigation is used unless the climate table gives its own", {
  inp <- prepare_shmi_inputs(get_shmi_example(), verbose = FALSE)
  dry_june <- c(20, 25, 50, 70, 110, 10, 95, 85, 70, 50, 35, 25)   # June dry for rain-fed land
  cl_wb  <- climate_for(inp$mgt$MGT_combo, prec = dry_june); cl_wb$irrigated <- NULL
  cl_dry <- climate_for(inp$mgt$MGT_combo, prec = dry_june, irrigated = FALSE)
  from_wb  <- suppressMessages(build_shmi(inp, cl_wb))$indicator_df
  rainfed  <- suppressMessages(build_shmi(inp, cl_dry))$indicator_df
  expect_true(all(from_wb$irrigated))
  expect_false(isTRUE(all.equal(from_wb$Cover_growing, rainfed$Cover_growing)))
})
