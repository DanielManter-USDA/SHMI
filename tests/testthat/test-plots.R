# Plots: SHMI+ shown when present, older score tables still work
test_that("gauge and lollipop accept scores with or without SHMI+", {
  pdf(NULL); on.exit(grDevices::dev.off())
  s <- data.frame(MGT_combo = c("a", "b"), SHMI = c(62.3, 48.1), SHMI_plus = c(62.3, 63.7),
                  Cover = c(71.2, 50), Diversity = c(45, 30), InvDist = c(88.9, 70))
  expect_s3_class(plot_shmi_gauge(s, MGT_combo = "b"), "gtable")
  expect_s3_class(plot_shmi_gauge(s[, names(s) != "SHMI_plus"]), "gtable")
  expect_error(plot_shmi_gauge(s[, c("MGT_combo", "SHMI")]), "Missing required")
  expect_s3_class(plot_shmi_lollipop(s), "ggplot")
  expect_s3_class(plot_shmi_lollipop(s[, c("MGT_combo", "SHMI")]), "ggplot")
})
