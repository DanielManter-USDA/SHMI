# Plots: SHMI_base shown when present, tables with SHMI alone still work
test_that("gauge and lollipop accept scores with or without SHMI_base", {
  pdf(NULL); on.exit(grDevices::dev.off())
  s <- data.frame(MGT_combo = c("a", "b"), SHMI = c(62.3, 63.7), SHMI_base = c(62.3, 48.1),
                  Cover = c(71.2, 50), Diversity = c(45, 30), InvDist = c(88.9, 70))
  expect_s3_class(plot_shmi_gauge(s, MGT_combo = "b"), "gtable")
  expect_s3_class(plot_shmi_gauge(s[, names(s) != "SHMI_base"]), "gtable")
  expect_error(plot_shmi_gauge(s[, c("MGT_combo", "SHMI")]), "Missing required")
  expect_s3_class(plot_shmi_lollipop(s), "ggplot")
  expect_s3_class(plot_shmi_lollipop(s[, c("MGT_combo", "SHMI")]), "ggplot")
})
