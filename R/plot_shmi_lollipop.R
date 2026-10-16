#' Plot SHMI across management units
#'
#' Horizontal lollipop chart, one line per management unit, sorted by SHMI.
#' When the data have `SHMI_base`, each line runs from 0 to SHMI_base (blue
#' point) and on to SHMI (orange point), so its last stretch is the organic
#' amendment bonus; units without amendments end at SHMI_base = SHMI.
#'
#' @param shmi A data frame with `MGT_combo` and `SHMI`, and optionally
#'   `SHMI_base`, such as `build_shmi()$indicator_df`.
#'
#' @return A ggplot object.
#'
#' @seealso [plot_shmi_gauge()], [build_shmi()]
#'
#' @examples
#' scores <- data.frame(MGT_combo = c("field_1", "field_2", "field_3"),
#'                      SHMI = c(62.3, 63.7, 80.5), SHMI_base = c(62.3, 48.1, 75.6))
#' plot_shmi_lollipop(scores)
#'
#' @export
plot_shmi_lollipop <- function(shmi) {

  # ---- Validate ----
  req <- c("MGT_combo", "SHMI")
  missing <- setdiff(req, names(shmi))
  if (length(missing) > 0) {
    stop("Missing required columns: ", paste(missing, collapse = ", "),
         call. = FALSE)
  }
  has_base <- "SHMI_base" %in% names(shmi)

  # ---- Prepare data ----
  df <- as.data.frame(shmi)
  df$base <- if (has_base) df$SHMI_base else df$SHMI
  df$MGT_combo <- factor(df$MGT_combo, levels = unique(df$MGT_combo[order(df$SHMI)]))
  pts <- data.frame(MGT_combo = df$MGT_combo, score = round(df$base, 1),
                    what = if (has_base) "SHMI_base" else "SHMI")
  if (has_base) {
    bonus <- df[df$SHMI > df$SHMI_base, , drop = FALSE]
    pts <- rbind(pts, data.frame(MGT_combo = bonus$MGT_combo, score = round(bonus$SHMI, 1),
                                 what = rep("SHMI", nrow(bonus))))
  }
  pts$what <- factor(pts$what, levels = c("SHMI_base", "SHMI"))
  lab <- data.frame(MGT_combo = df$MGT_combo, top = df$SHMI, label = round(df$SHMI, 1))

  # ---- Plot ----
  p <- ggplot2::ggplot(df, ggplot2::aes(y = MGT_combo)) +
    ggplot2::geom_segment(
      ggplot2::aes(x = 0, xend = base, yend = MGT_combo),
      color = "grey70", linewidth = 1
    )
  if (has_base) {
    p <- p + ggplot2::geom_segment(
      ggplot2::aes(x = base, xend = SHMI, yend = MGT_combo),
      color = "#e08a2c", linewidth = 1
    )
  }
  p +
    ggplot2::geom_point(
      data = pts, ggplot2::aes(x = score, y = MGT_combo, fill = what),
      color = "black", size = 5, shape = 21
    ) +
    ggplot2::geom_text(
      data = lab, ggplot2::aes(x = top, y = MGT_combo, label = label),
      hjust = -0.4, size = 3
    ) +
    ggplot2::scale_fill_manual(values = c("SHMI_base" = "steelblue",
                                          "SHMI" = if (has_base) "#e08a2c" else "steelblue"),
                               name = NULL, drop = TRUE) +
    ggplot2::scale_x_continuous(limits = c(0, 100),
                                expand = ggplot2::expansion(mult = c(0, 0.1))) +
    ggplot2::labs(
      x = if (has_base) "SHMI_base, and SHMI with the organic amendment bonus" else "SHMI",
      y = "Management Unit",
      title = "SHMI Across Management Units"
    ) +
    ggplot2::theme_minimal(base_size = 12) +
    ggplot2::theme(
      panel.grid.major.y = ggplot2::element_blank(),
      panel.grid.minor = ggplot2::element_blank(),
      legend.position = if (has_base) "top" else "none"
    )
}
