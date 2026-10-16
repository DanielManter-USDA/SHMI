# Plot gauges of SHMI and its sub-indices for one management unit

Draws vertical gauges for Cover, Diversity, Inverse Disturbance,
SHMI_base (when the data have `SHMI_base`) and SHMI, which adds the
organic amendment bonus to SHMI_base. Each gauge shows the 0-100 scale
in five bands ("very low" to "very high") with a pointer at the unit's
score.

## Usage

``` r
plot_shmi_gauge(shmi, MGT_combo = NULL, row = 1)
```

## Arguments

- shmi:

  A data frame of scores with `SHMI`, `Cover`, `Diversity` and
  `InvDist`, optionally `SHMI_base`, and `MGT_combo` if units are
  selected by name, such as `build_shmi()$indicator_df`.

- MGT_combo:

  Optional management unit to plot. Overrides `row`.

- row:

  Row of `shmi` to plot when `MGT_combo` is not given.

## Value

Draws the plot and invisibly returns the arranged grob from
[`gridExtra::grid.arrange()`](https://rdrr.io/pkg/gridExtra/man/arrangeGrob.html).

## See also

[`plot_shmi_lollipop()`](https://danielmanter-usda.github.io/SHMI/reference/plot_shmi_lollipop.md),
[`build_shmi()`](https://danielmanter-usda.github.io/SHMI/reference/build_shmi.md)

## Examples

``` r
scores <- data.frame(MGT_combo = "field_1", SHMI = 73.6, SHMI_base = 62.3,
                     Cover = 71.2, Diversity = 45.0, InvDist = 88.9)
plot_shmi_gauge(scores)

```
