# Plot gauges of SHMI and its sub-indices for one management unit

Draws five vertical gauges, for Cover, Diversity, Inverse Disturbance,
Organic Inputs, and overall SHMI. Each gauge shows the 0-100 scale in
five bands ("very low" to "very high") with a pointer at the unit's
score.

## Usage

``` r
plot_shmi_gauge(shmi, MGT_combo = NULL, row = 1)
```

## Arguments

- shmi:

  A data frame of scores with `SHMI`, `Cover`, `Diversity`, `InvDist`,
  and `OrgInput`, and `MGT_combo` if units are selected by name, such as
  `build_shmi()$indicator_df`.

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
scores <- data.frame(MGT_combo = "field_1", SHMI = 62.3, Cover = 71.2,
                     Diversity = 45.0, InvDist = 88.9, OrgInput = 33.1)
plot_shmi_gauge(scores)

```
