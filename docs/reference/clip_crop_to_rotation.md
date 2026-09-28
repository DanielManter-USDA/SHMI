# Clip crop episodes to each unit's rotation window

Truncates `crop_start` / `crop_end` to `rot_start` / `rot_end` and drops
episodes entirely outside the window. Calling this once in
[`build_shmi()`](https://danielmanter-usda.github.io/SHMI/reference/build_shmi.md),
before
[`compute_cover()`](https://danielmanter-usda.github.io/SHMI/reference/compute_cover.md)
and
[`compute_diversity()`](https://danielmanter-usda.github.io/SHMI/reference/compute_diversity.md),
makes both sub-indices use the same evaluation window as
[`compute_orginput()`](https://danielmanter-usda.github.io/SHMI/reference/compute_orginput.md)
and
[`compute_disturbance()`](https://danielmanter-usda.github.io/SHMI/reference/compute_disturbance.md).

## Usage

``` r
clip_crop_to_rotation(crop, rot_bounds)
```

## Arguments

- crop:

  Species episodes with `MGT_combo`, `crop_start`, `crop_end`.

- rot_bounds:

  Rotation bounds with `MGT_combo`, `rot_start`, `rot_end`.

## Value

`crop`, clipped. Units absent from `rot_bounds` are dropped.
