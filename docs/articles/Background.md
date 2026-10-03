# SHMI Background

Why SHMI exists, how it was built, and what it can and cannot tell you.

## 1. Why SHMI exists

Soil health is usually judged from laboratory measurements: soil carbon,
microbial activity, aggregate stability and so on. Those tell you how a
soil is doing, but not which management decisions got it there, and they
are expensive to repeat. SHMI starts from the other end: it scores a
field’s **management record** (what was planted when, how the soil was
tilled, what was added) on how strongly those practices are expected to
build soil health.

SHMI’s purpose is to provide:

- a transparent, reproducible score of soil-health management from
  records a farmer or researcher already keeps;
- a way to compare management systems, especially practices at the same
  site, on a common 0-100 scale;
- weights grounded in measured soil health rather than set by opinion.

------------------------------------------------------------------------

## 2. The four sub-indices

SHMI combines four widely recognized levers for improving soil function,
each scored 0-100:

| Sub-index | What it measures | Weight |
|----|----|----|
| Cover | share of days with living plants, in the growing and non-growing seasons set by the site’s climate | 0.400 |
| Organic Inputs | share of years with an organic amendment or grazing animals | 0.317 |
| Diversity | average number of plant species per year | 0.153 |
| Inverse Disturbance | how little the soil was tilled, computed as in USDA’s T-DISC tool | 0.130 |

Cover does two jobs: living plants protect the soil surface and feed
soil organisms through their roots. Disturbance protects; Organic Inputs
and Diversity feed.

------------------------------------------------------------------------

## 3. How the weights were set

The weights were calibrated against measured soil health on **354 US
plots at 74 sites** of the North American Project to Evaluate Soil
Health Measurements (NAPESHM):

1.  **A soil-health score.** Eleven laboratory indicators (carbon and
    nitrogen mineralization, two enzymes, organic carbon, total
    nitrogen, active carbon, ACE protein, slaking, aggregate stability
    and infiltration) were adjusted for climate and soil texture, then
    combined in a structural equation model with three dimensions
    (biological activity, carbon and nitrogen pools, physical condition)
    feeding one overall score.
2.  **The weights.** SHMI’s four sub-indices were fitted to that score
    by non-negative least squares, with each site weighted equally.
    Fitting was repeated 1,000 times on different subsets of sites
    (10-fold cross-validation, repeated 100 times), and each final
    weight is the median. Every weight was positive in every fit.
3.  **Alternatives.** Twelve ways of building the four scores were
    compared on the same sites, including other diversity measures
    (time-weighted Shannon diversity, crop rotation, functional
    richness) and other placements of animals and amendments. Most
    predicted about equally well; the final structure was chosen as the
    one that keeps every established soil-health practice with an
    estimable weight.

------------------------------------------------------------------------

## 4. How well it works

- **Fit to the US data.** SHMI correlates with measured soil health at r
  = 0.58 across all plots.
- **Sites it has not seen.** Predicting each site with weights fitted
  without it, SHMI explains about a quarter of the differences in soil
  health (R² = 0.27), and ranks practices in the right order at **82% of
  sites**. A single prediction is typically within about 13 soil-health
  points.
- **Another region.** At 16 Mexican sites, never used in calibration,
  SHMI transferred poorly: predictions ran about 21 points low and
  ranking within sites was not clearly better than chance. SHMI as
  calibrated is a tool for US systems; other regions need their own
  calibration.

------------------------------------------------------------------------

## 5. Relationship to soil health

SHMI is a **predictor** of soil health from management, not a
measurement of soil health. It cannot see weather, soil history before
the record, fertilizer rates or irrigation amounts, which is why about
three quarters of the differences in measured soil health remain
unexplained. Its strength is comparing management systems, especially
different practices on the same land, where those other factors are
shared.

------------------------------------------------------------------------

## 6. Summary

SHMI is:

- built from four practice-based sub-indices that any management record
  can provide;
- weighted by calibration against measured soil health on US research
  sites;
- most reliable for comparing practices at the same site;
- transparent: every assumption made while reading the records is
  reported.

For the workflow, see the *SHMI Overview* article; for each sub-index,
see its own article.
