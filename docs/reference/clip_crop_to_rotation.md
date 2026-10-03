# Clip crop episodes to each unit's rotation window

Truncates `crop_start` / `crop_end` to `rot_start` / `rot_end` and drops
episodes entirely outside the window, so every sub-index uses the same
evaluation window.

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
