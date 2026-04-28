#' Plot yield stability using Taylor's Law
#'
#' Creates a log-mean vs. log-variance plot of yield for each management
#' unit and crop, based on the output of `prepare_shmi_yield()`. This is
#' the canonical visualization of Taylor's Law and is useful for comparing
#' yield stability across crops and management units.
#'
#' This version includes:
#'   * explicit removal of non-finite log values (e.g., zero variance)
#'   * warnings about dropped rows
#'   * correct filtering when a single crop is selected
#'   * consistent behavior between faceted and filtered plots
#'
#' @param yield_df A tibble returned by `prepare_shmi_yield()`, containing
#'   columns `MGT_combo`, `crop`, `log_mean`, and `log_var`.
#' @param crop Optional character string specifying a single crop to plot.
#'   If `NULL` (default), all crops are plotted.
#' @param facet Logical; if TRUE (default), facet by crop. Ignored when a
#'   single crop is selected.
#' @param label Logical; if TRUE, label points with `MGT_combo`. Default FALSE.
#' @param add_lm Logical; if TRUE, add a linear regression line. Default TRUE.
#' @param point_size Numeric; size of points. Default 3.
#' @param text_size Numeric; size of text labels (if `label = TRUE`). Default 3.
#'
#' @return A ggplot2 object.
#'
#' @export
plot_yield_stability <- function(yield_df,
                                 crop = NULL,
                                 facet = TRUE,
                                 label = FALSE,
                                 add_lm = TRUE,
                                 point_size = 3,
                                 text_size = 3) {

  # ---- validation ----
  required_cols <- c("MGT_combo", "crop", "log_mean", "log_var")

  missing <- setdiff(required_cols, names(yield_df))
  if (length(missing) > 0) {
    stop(
      "yield_df is missing required columns: ",
      paste(missing, collapse = ", "),
      call. = FALSE
    )
  }
  if (nrow(yield_df) == 0) {
    stop("yield_df has zero rows; nothing to plot.", call. = FALSE)
  }

  # ---- crop filtering (ALWAYS applied first) ----
  if (!is.null(crop)) {

    message("Requested crop: '", crop, "'")
    message("Unique crops in data: ", paste(sort(unique(yield_df$crop)), collapse = ", "))

    # use base R subsetting to avoid any tidy-eval issues
    keep <- yield_df$crop == crop
    yield_df <- yield_df[keep, , drop = FALSE]

    message("Rows after filtering: ", nrow(yield_df))

    if (nrow(yield_df) == 0) {
      stop("No yield data found for crop '", crop, "'.", call. = FALSE)
    }
  }

  # ---- handle zero variance and non-finite logs ----
  bad_rows <- yield_df %>%
    dplyr::filter(!is.finite(log_mean) | !is.finite(log_var))

  if (nrow(bad_rows) > 0) {
    warning(
      "Removed ", nrow(bad_rows), " rows with non-finite log values (",
      "e.g., zero variance or missing yield). These rows would otherwise ",
      "cause inconsistent behavior between faceted and filtered plots."
    )
  }

  yield_df <- yield_df %>%
    dplyr::filter(is.finite(log_mean), is.finite(log_var))

  if (nrow(yield_df) == 0) {
    stop("All rows were removed due to non-finite log values.", call. = FALSE)
  }

  # ---- base plot ----
  p <- ggplot2::ggplot(
    yield_df,
    ggplot2::aes(x = log_mean, y = log_var)
  ) +
    ggplot2::geom_point(size = point_size, alpha = 0.8) +
    ggplot2::theme_bw(base_size = 14) +
    ggplot2::labs(
      x = "log(mean yield)",
      y = "log(variance of yield)",
      title = if (is.null(crop)) {
        "Yield Stability (Taylor's Law)"
      } else {
        paste0("Yield Stability (Taylor's Law): ", crop)
      }
    )

  # ---- regression line ----
  if (add_lm) {
    p <- p +
      ggplot2::geom_smooth(
        method = "lm",
        se = TRUE,
        color = "steelblue",
        linewidth = 0.8
      )
  }

  # ---- labels ----
  if (label) {
    p <- p +
      ggplot2::geom_text(
        ggplot2::aes(label = MGT_combo),
        size = text_size,
        vjust = -0.5
      )
  }

  # ---- faceting ----
  if (facet) {
    p <- p + ggplot2::facet_wrap(~ crop, scales = "free")
  }

  return(p)
}
