# Plot SHMI across management units

Horizontal lollipop chart of overall SHMI, one line per management unit,
sorted by score.

## Usage

``` r
plot_shmi_lollipop(shmi)
```

## Arguments

- shmi:

  A data frame with `MGT_combo` and `SHMI`, such as
  `build_shmi()$indicator_df`.

## Value

A ggplot object.

## See also

[`plot_shmi_gauge()`](https://danielmanter-usda.github.io/SHMI/reference/plot_shmi_gauge.md),
[`build_shmi()`](https://danielmanter-usda.github.io/SHMI/reference/build_shmi.md)

## Examples

``` r
scores <- data.frame(MGT_combo = c("field_1", "field_2", "field_3"),
                     SHMI = c(62.3, 48.1, 75.6))
plot_shmi_lollipop(scores)

```
