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
                                  facet_var = NULL,
                                  label = FALSE,
                                  add_lm = TRUE,
                                  point_size = 3,
                                  text_size = 3) {

  # ---- validation ----
  required_cols <- c("MGT_combo", "MGT_study", "MGT_farm", "MGT_field", "MGT_trt",
                     "CD_name", "yield_kg_ha")

  missing <- setdiff(required_cols, names(yield_df))
  if (length(missing) > 0) {
    stop("yield_df is missing required columns: ",
         paste(missing, collapse = ", "), call. = FALSE)
  }
  if (nrow(yield_df) == 0) {
    stop("yield_df has zero rows; nothing to plot.", call. = FALSE)
  }

  # ---- summarize to (MGT_combo × crop × facet_var) ----
  group_vars <- c("MGT_combo", "MGT_study", "MGT_farm", "MGT_field", "MGT_trt",
                  "crop" = "CD_name")

  if (!is.null(facet_var)) {
    missing_fv <- setdiff(facet_var, names(yield_df))
    if (length(missing_fv) > 0) {
      stop("facet_var not found in data: ", paste(missing_fv, collapse = ", "), call. = FALSE)
    }
    group_vars <- c(group_vars, facet_var)
  }

  yield_summary <- yield_df %>%
    dplyr::group_by(dplyr::across(all_of(group_vars))) %>%
    dplyr::summarize(
      mean_yield = mean(yield_kg_ha, na.rm = TRUE),
      var_yield  = stats::var(yield_kg_ha, na.rm = TRUE),
      log_mean   = log(mean_yield),
      log_var    = log(var_yield),
      .groups = "drop"
    )

  # ---- crop filtering ----
  if (!is.null(crop)) {
    yield_summary <- yield_summary %>% dplyr::filter(crop == !!crop)
    if (nrow(yield_summary) == 0) {
      stop("No yield data found for crop '", crop, "'.", call. = FALSE)
    }
  }

  # ---- remove non-finite log values ----
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

  # ---- facet-aware regression line + annotation ----
  if (add_lm) {

    # Fit TL model per facet group
    facet_groups <- if (is.null(facet_var)) {
      list(yield_summary)
    } else {
      split(yield_summary, yield_summary[facet_var])
    }

    # Build annotation data frame
    ann <- purrr::map_dfr(facet_groups, function(df) {

      # ---- skip empty or single-point groups ----
      if (nrow(df) < 2) {
        # Return an annotation placeholder so facet still renders cleanly
        out <- tibble::tibble(
          log_mean = -Inf,
          log_var  = Inf,
          label    = "Insufficient data",
          !!!df[1, facet_var, drop = FALSE]
        )
        return(out)
      }

      # ---- safe regression ----
      fit <- try(lm(log_var ~ log_mean, data = df), silent = TRUE)

      if (inherits(fit, "try-error")) {
        out <- tibble::tibble(
          log_mean = -Inf,
          log_var  = Inf,
          label    = "Model failed",
          !!!df[1, facet_var, drop = FALSE]
        )
        return(out)
      }

      sm  <- summary(fit)

      b    <- coef(fit)[["log_mean"]]
      b_se <- sm$coefficients["log_mean", "Std. Error"]
      r2   <- sm$r.squared

      tibble::tibble(
        log_mean = -Inf,
        log_var  = Inf,
        label    = sprintf("b = %.3f ± %.3f\nR² = %.3f", b, b_se, r2),
        !!!df[1, facet_var, drop = FALSE]
      )
    })

    p <- p +
      ggplot2::geom_smooth(
        method = "lm",
        se = TRUE,
        color = "steelblue",
        linewidth = 0.8,
        na.rm = TRUE
      ) +
      ggplot2::geom_text(
        data = ann,
        ggplot2::aes(label = label),
        hjust = -0.1, vjust = 1.2,
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
  if (!is.null(facet_var)) {
    p <- p + ggplot2::facet_wrap(vars(!!!rlang::syms(facet_var)), scales = "free")
  }

  return(p)
}

