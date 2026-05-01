#' Internal: Plot yield stability using Taylor's Law
#'
#' Creates a log-mean vs. log-variance plot of yield for each management
#' unit and crop, using the yield table produced by
#' \code{prepare_shmi_inputs()} (i.e., \code{inputs$yield}).
#'
#' This function automatically:
#' \itemize{
#'   \item summarizes yield per (MGT_combo × crop)
#'   \item computes mean, variance, log-mean, and log-variance
#'   \item removes non-finite log values (e.g., zero variance)
#'   \item supports optional crop filtering
#'   \item supports faceting and labeling
#' }
#'
#' @param yield_df A tibble from \code{prepare_shmi_inputs()$yield}, containing
#'   columns: \code{MGT_combo}, \code{CD_name}, and \code{yield_kg_ha}.
#'
#' @param crop Optional character string specifying a single crop to plot.
#'   If \code{NULL} (default), all crops are plotted.
#'
#' @param facet Logical; if \code{TRUE} (default), facet by crop. Ignored when a
#'   single crop is selected.
#'
#' @param label Logical; if \code{TRUE}, label points with \code{MGT_combo}.
#'   Default \code{FALSE}.
#'
#' @param add_lm Logical; if \code{TRUE}, add a linear regression line.
#'   Default \code{TRUE}.
#'
#' @param point_size Numeric; size of points. Default \code{3}.
#'
#' @param text_size Numeric; size of text labels (if \code{label = TRUE}).
#'   Default \code{3}.
#'
#' @return A \code{ggplot2} object.
#'
#' @keywords internal
#' @noRd
.plot_yield_stability <- function(yield_df,
                                  crop = NULL,
                                  facet = TRUE,
                                  label = FALSE,
                                  add_lm = TRUE,
                                  point_size = 3,
                                  text_size = 3) {

  # ---- validation ----
  required_cols <- c("MGT_combo", "CD_name", "yield_kg_ha")

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

  # ---- summarize to (MGT_combo × crop) ----
  yield_summary <- yield_df %>%
    dplyr::group_by(MGT_combo, crop = CD_name) %>%
    dplyr::summarize(
      mean_yield = mean(yield_kg_ha, na.rm = TRUE),
      var_yield  = stats::var(yield_kg_ha, na.rm = TRUE),
      log_mean   = log(mean_yield),
      log_var    = log(var_yield),
      .groups = "drop"
    )

  # ---- crop filtering ----
  if (!is.null(crop)) {

    message("Requested crop: '", crop, "'")
    message("Unique crops in data: ", paste(sort(unique(yield_summary$crop)), collapse = ", "))

    keep <- yield_summary$crop == crop
    yield_summary <- yield_summary[keep, , drop = FALSE]

    message("Rows after filtering: ", nrow(yield_summary))

    if (nrow(yield_summary) == 0) {
      stop("No yield data found for crop '", crop, "'.", call. = FALSE)
    }
  }

  # ---- remove non-finite log values ----
  bad_rows <- yield_summary %>%
    dplyr::filter(!is.finite(log_mean) | !is.finite(log_var))

  if (nrow(bad_rows) > 0) {
    warning(
      "Removed ", nrow(bad_rows), " rows with non-finite log values ",
      "(e.g., zero variance or missing yield)."
    )
  }

  yield_summary <- yield_summary %>%
    dplyr::filter(is.finite(log_mean), is.finite(log_var))

  if (nrow(yield_summary) == 0) {
    stop("All rows were removed due to non-finite log values.", call. = FALSE)
  }

  # ---- base plot ----
  p <- ggplot2::ggplot(
    yield_summary,
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
      ) +
      ggpubr::stat_regline_equation(
        aes(label = paste(..eq.label.., ..rr.label.., sep = "~~~~")),
        label.x.npc = "left",
        label.y.npc = "bottom",
        size = 4
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
  if (facet && is.null(crop)) {
    p <- p + ggplot2::facet_wrap(~ crop, scales = "free")
  }

  return(p)
}
