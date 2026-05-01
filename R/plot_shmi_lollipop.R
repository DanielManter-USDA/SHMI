#' Plot SHMI values for multiple management units (lollipop chart)
#'
#' @description
#' When more than one MGT_combo is present, this function plots only the
#' overall SHMI values using a clean horizontal lollipop chart.
#'
#' @param shmi A data frame containing at least:
#'   - `MGT_combo`
#'   - `SHMI`
#'
#' @return A ggplot lollipop chart.
#' @export
plot_shmi_lollipop <- function(shmi) {

  # ---- Validate ----
  req <- c("MGT_combo", "SHMI")
  missing <- setdiff(req, names(shmi))
  if (length(missing) > 0) {
    stop("Missing required columns: ", paste(missing, collapse = ", "),
         call. = FALSE)
  }

  # ---- Prepare data ----
  df <- shmi |>
    dplyr::mutate(
      MGT_combo = factor(MGT_combo, levels = MGT_combo[order(SHMI)]),
      SHMI = round(SHMI, 1)
    )

  # ---- Plot ----
  ggplot2::ggplot(df, ggplot2::aes(x = SHMI, y = MGT_combo)) +
    ggplot2::geom_segment(
      ggplot2::aes(x = 0, xend = SHMI, y = MGT_combo, yend = MGT_combo),
      color = "grey70", linewidth = 1
    ) +
    ggplot2::geom_point(
      color = "black", fill = "steelblue", size = 5, shape = 21
    ) +
    ggplot2::geom_text(
      ggplot2::aes(label = SHMI),
      hjust = -0.4, size = 3
    ) +
    ggplot2::scale_x_continuous(limits = c(0, 100),
                                expand = ggplot2::expansion(mult = c(0, 0.1))) +
    ggplot2::labs(
      x = "SHMI",
      y = "Management Unit",
      title = "SHMI Across Management Units"
    ) +
    ggplot2::theme_minimal(base_size = 12) +
    ggplot2::theme(
      panel.grid.major.y = ggplot2::element_blank(),
      panel.grid.minor = ggplot2::element_blank()
    )
}
