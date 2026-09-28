ex <-
  function(...) prepare_shmi_inputs(get_shmi_example(), verbose = FALSE, ...)

test_that("calendar window spans whole years and contains every episode", {
  inp <- ex()
  expect_identical(attr(inp, "rotation_window"), "calendar")
  expect_true(all(format(inp$rot_bounds$rot_start, "%m-%d") == "01-01"))
  expect_true(all(format(inp$rot_bounds$rot_end,   "%m-%d") == "12-31"))
  j <- merge(inp$crop, inp$rot_bounds, by = "MGT_combo")
  expect_true(all(j$crop_start >= j$rot_start & j$crop_end <= j$rot_end))
})

test_that("events window reproduces SHMI 1.1.0 bounds", {
  inp <- ex(rotation_window = "events")
  j <- merge(inp$crop, inp$rot_bounds, by = "MGT_combo")
  first <- tapply(j$crop_start, j$MGT_combo, min)
  expect_true(all(inp$rot_bounds$rot_start <=
                    as.Date(first[inp$rot_bounds$MGT_combo], origin = "1970-01-01")))
})

test_that("override dates are the window boundaries exactly", {
  inp <- ex(start_date_override = "2022-01-01", end_date_override = "2023-12-31")
  expect_true(all(inp$rot_bounds$rot_start == as.Date("2022-01-01")))
  expect_true(all(inp$rot_bounds$rot_end   == as.Date("2023-12-31")))
  expect_message(ex(start_date_override = "2022-03-15"), "calendar-year boundaries")
  expect_error(ex(start_date_override = "2023-01-01", end_date_override = "2022-12-31"))
})

test_that("calendar window never raises Cover relative to the events window", {
  a <- build_shmi(ex())$indicator_df
  b <- suppressMessages(build_shmi(ex(rotation_window = "events"),
                                   settings = list(animal_presence = "start"),
                                   expert_mode = TRUE))$indicator_df
  m <- merge(a[, c("MGT_combo", "Cover")], b[, c("MGT_combo", "Cover")], by = "MGT_combo")
  # a longer window can only add days; it adds covered days only if an
  # episode crosses the old boundary, which cannot happen by construction
  expect_true(all(m$Cover.x <= m$Cover.y + 1e-8))
})

test_that("build_shmi rejects unknown and invalid settings", {
  inp <- ex()
  expect_error(build_shmi(inp, settings = list(w_Winter = 1), expert_mode = TRUE), "Unknown")
  expect_error(build_shmi(inp, settings = list(hill = 3), expert_mode = TRUE), "hill")
  expect_error(build_shmi(inp, settings = list(max_div = 1), expert_mode = TRUE), "max_div")
  expect_error(build_shmi(inp, settings = list(w_cover = -1), expert_mode = TRUE), "Pillar")
  expect_error(build_shmi(inp, settings = list(animal_presence = "all"), expert_mode = TRUE))
  expect_no_error(suppressMessages(
    build_shmi(inp, settings = list(w_winter = 0), expert_mode = TRUE)))
})

test_that("results record the window definition and settings", {
  r <- build_shmi(ex())
  expect_identical(r$rotation_window, "calendar")
  expect_true(all(c("clip_to_rotation", "animal_presence") %in% names(r$settings_used)))
})
