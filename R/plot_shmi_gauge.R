#' Plot gauges of SHMI and its sub-indices for one management unit
#'
#' Draws five vertical gauges, for Cover, Diversity, Inverse Disturbance,
#' Organic Inputs, and overall SHMI. Each gauge shows the 0-100 scale in five
#' bands ("very low" to "very high") with a pointer at the unit's score.
#'
#' @param shmi A data frame of scores with `SHMI`, `Cover`, `Diversity`,
#'   `InvDist`, and `OrgInput`, and `MGT_combo` if units are selected by name,
#'   such as `build_shmi()$indicator_df`.
#' @param MGT_combo Optional management unit to plot. Overrides `row`.
#' @param row Row of `shmi` to plot when `MGT_combo` is not given.
#'
#' @return Draws the plot and invisibly returns the arranged grob from
#'   [gridExtra::grid.arrange()].
#'
#' @seealso [plot_shmi_lollipop()], [build_shmi()]
#'
#' @examples
#' scores <- data.frame(MGT_combo = "field_1", SHMI = 62.3, Cover = 71.2,
#'                      Diversity = 45.0, InvDist = 88.9, OrgInput = 33.1)
#' plot_shmi_gauge(scores)
#'
#' @export
plot_shmi_gauge <- function(shmi,
                            MGT_combo = NULL,
                            row = 1) {

  # ---- Selection logic ----
  if (!is.null(MGT_combo)) {

    if (!"MGT_combo" %in% names(shmi)) {
      stop("Column `MGT_combo` not found in `shmi`.", call. = FALSE)
    }

    idx <- which(shmi$MGT_combo == MGT_combo)

    if (length(idx) == 0) {
      stop("No rows match MGT_combo = '", MGT_combo, "'.", call. = FALSE)
    }
    if (length(idx) > 1) {
      stop("Multiple rows match MGT_combo = '", MGT_combo,
           "'. Please ensure uniqueness.", call. = FALSE)
    }

  } else {
    if (row < 1 || row > nrow(shmi)) {
      stop("`row` is out of bounds.", call. = FALSE)
    }
    idx <- row
  }

  # Extract selected row
  x <- shmi[idx, , drop = FALSE]

  # ---- Validate required columns ----
  req <- c("SHMI", "Cover", "Diversity", "InvDist", "OrgInput")
  missing <- setdiff(req, names(x))
  if (length(missing) > 0) {
    stop("Missing required columns: ", paste(missing, collapse = ", "),
         call. = FALSE)
  }

  # Round values
  x <- x |>
    dplyr::mutate(
      SHMI      = round(SHMI, 1),
      Cover     = round(Cover, 1),
      Diversity = round(Diversity, 1),
      InvDist   = round(InvDist, 1),
      OrgInput = round(OrgInput, 1)
    )

  # ---- Score bins ----
  scores <- factor(
    c("very low", "low", "medium", "high", "very high"),
    levels = c("very low", "low", "medium", "high", "very high"),
    ordered = TRUE
  )

  # Background bar (5 x 20 = 100)
  bar_df <- data.frame(points = rep(20, 5), scores = scores)

  base_plot <- function() {
    ggplot2::ggplot(bar_df, ggplot2::aes(x = 1, y = points, fill = scores)) +
      ggplot2::geom_bar(
        position = "stack", stat = "identity",
        show.legend = FALSE, color = "black"
      ) +
      ggplot2::scale_fill_brewer(palette = "RdYlGn", direction = -1) +
      ggplot2::theme(
        panel.background = ggplot2::element_blank(),
        panel.grid.major = ggplot2::element_blank(),
        panel.grid.minor = ggplot2::element_blank(),
        axis.line = ggplot2::element_blank(),
        axis.ticks = ggplot2::element_blank(),
        axis.text = ggplot2::element_blank(),
        axis.title = ggplot2::element_text(size = 16, face = "bold"),
        plot.margin = ggplot2::margin(t = 20, r = 5, b = 5, l = 5, "points")
      )
  }

  # ---- Helper to build each panel ----
  panel <- function(value, xlab) {
    base_plot() +
      .gauge_pointer(x, value) +
      ggplot2::geom_label(
        inherit.aes = FALSE,
        data = x,
        ggplot2::aes(x = 1, y = value, label = value),
        size = 6, colour = "black"
      ) +
      ggplot2::scale_x_discrete(position = "top") +
      ggplot2::labs(x = xlab, y = NULL) +
      ggplot2::theme(plot.background = ggplot2::element_rect(
        fill = "grey80", color = "grey80"
      ))
  }

  p1 <- panel(x$Cover,     "\nCover")
  p2 <- panel(x$Diversity, "\nDiversity")
  p3 <- panel(x$InvDist,   "Inverse\nDisturbance")
  p4 <- panel(x$OrgInput,   "\nOrgInput")

  # ---- Overall SHMI panel ----
  p5 <- base_plot() +
    ggplot2::geom_text(
      ggplot2::aes(label = scores, x = 1.6, y = seq(10, 90, by = 20)),
      size = 5, angle = 90
    ) +
    .gauge_pointer(x, x$SHMI) +
    ggplot2::geom_label(
      inherit.aes = FALSE,
      data = x,
      ggplot2::aes(x = 1, y = SHMI, label = SHMI),
      size = 6, colour = "black"
    ) +
    ggplot2::scale_x_discrete(position = "top") +
    ggplot2::labs(x = "Overall\nSHMI", y = NULL) +
    ggplot2::theme(plot.background = ggplot2::element_rect(
      fill = "grey80", color = "grey80"
    ))

  # ---- Arrange 1x5 ----
  gridExtra::grid.arrange(p1, p2, p3, p4, p5, nrow = 1)
}


# Right-pointing arrow marking a score on a gauge. Drawn as a segment with a
# closed arrowhead rather than a Unicode symbol, which fails on graphics
# devices without Unicode support (for example the pdf device used by
# R CMD check).
.gauge_pointer <- function(data, value) {
  ggplot2::geom_segment(
    inherit.aes = FALSE,
    data = data,
    ggplot2::aes(x = 0.15, xend = 0.5, y = value, yend = value),
    arrow = ggplot2::arrow(type = "closed", length = ggplot2::unit(0.35, "cm")),
    linewidth = 1.2, colour = "black"
  )
}
