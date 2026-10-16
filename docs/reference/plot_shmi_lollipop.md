# Plot SHMI and SHMI+ across management units

Horizontal lollipop chart, one line per management unit. Each line runs
from 0 to the unit's SHMI (blue point); when the data have `SHMI_plus`,
the line continues to SHMI+ (orange point), so its last stretch is the
organic amendment bonus. Units are sorted by SHMI+ when present,
otherwise by SHMI.

## Usage

``` r
plot_shmi_lollipop(shmi)
```

## Arguments

- shmi:

  A data frame with `MGT_combo` and `SHMI`, and optionally `SHMI_plus`,
  such as `build_shmi()$indicator_df`.

## Value

A ggplot object.

## See also

[`plot_shmi_gauge()`](https://danielmanter-usda.github.io/SHMI/reference/plot_shmi_gauge.md),
[`build_shmi()`](https://danielmanter-usda.github.io/SHMI/reference/build_shmi.md)

## Examples

``` r
scores <- data.frame(MGT_combo = c("field_1", "field_2", "field_3"),
                     SHMI = c(62.3, 48.1, 75.6), SHMI_plus = c(62.3, 63.7, 80.5))
plot_shmi_lollipop(scores)

```
