#' Plot SHMI gauge panels (Cover, Diversity, Inverse Disturbance, Animals, Overall SHMI)
#'
#' @description
#' Creates a five horizontal gauge-style plot for SHMI and each sub-index.
#' Each panel shows a 0–100 scale divided into five qualitative score bins
#' ("very low" → "very high") with a pointer and numeric label for the
#' SHMI component.
#'
#' @param shmi A data frame containing SHMI component scores with columns:
#'   - `MGT_combo`
#'   - `SHMI`
#'   - `Cover`
#'   - `Diversity`
#'   - `InvDist`
#'   - `Animals`
#'
#' @param MGT_combo Optional. Character value specifying which management
#'   unit to plot. If supplied, this overrides `row`.
#'
#' @param row Integer row number to plot if `MGT_combo` is not provided.
#'
#' @return A 1×5 panel of ggplot gauge charts.
#' @export
#'
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
  req <- c("SHMI", "Cover", "Diversity", "InvDist", "Animals")
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
      Animals   = round(Animals, 1)
    )

  # ---- Score bins ----
  scores <- factor(
    c("very low", "low", "medium", "high", "very high"),
    levels = c("very low", "low", "medium", "high", "very high"),
    ordered = TRUE
  )

  # Background bar (5 × 20 = 100)
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
      ggplot2::geom_point(
        inherit.aes = FALSE,
        data = x,
        ggplot2::aes(x = 0.5, y = value),
        shape = "\u25BA", size = 10, colour = "black"
      ) +
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
  p4 <- panel(x$Animals,   "\nAnimals")

  # ---- Overall SHMI panel ----
  p5 <- base_plot() +
    ggplot2::geom_text(
      ggplot2::aes(label = scores, x = 1.6, y = seq(10, 90, by = 20)),
      size = 5, angle = 90
    ) +
    ggplot2::geom_point(
      inherit.aes = FALSE,
      data = x,
      ggplot2::aes(x = 0.5, y = SHMI),
      shape = "\u25BA", size = 10, colour = "black"
    ) +
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

  # ---- Arrange 1×5 ----
  gridExtra::grid.arrange(p1, p2, p3, p4, p5, nrow = 1)
}
