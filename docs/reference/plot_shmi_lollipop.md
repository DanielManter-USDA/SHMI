# Plot SHMI values for multiple management units (lollipop chart)

When more than one MGT_combo is present, this function plots only the
overall SHMI values using a clean horizontal lollipop chart.

## Usage

``` r
plot_shmi_lollipop(shmi)
```

## Arguments

- shmi:

  A data frame containing at least: - \`MGT_combo\` - \`SHMI\`

## Value

A ggplot lollipop chart.
