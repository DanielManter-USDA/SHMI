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

## 2. Two scores, three sub-indices

**SHMI** combines three widely recognized levers for improving soil
function, each scored 0-100:

| Sub-index | What it measures | Weight |
|----|----|----|
| Cover | share of days with living plants, in the growing and non-growing seasons set by the site’s climate | 0.687 |
| Diversity | number of plant species in each 4-year span of the record, raised by grazing animals | 0.150 |
| Inverse Disturbance | how little the soil was tilled, computed as in USDA’s T-DISC tool | 0.163 |

Cover does two jobs: living plants protect the soil surface and feed
soil organisms through their roots. Disturbance protects; Diversity
feeds a wider range of organisms. Grazing animals count as part of the
living system: they close up to a quarter of the gap between plant
Diversity and 100.

**SHMI+** adds organic amendments (manure, compost), carbon brought in
from outside the field. An amendment in a share $`p`$ of years closes
$`0.60\,p`$ of the gap between SHMI and 100:

``` math

\text{SHMI+} = \text{SHMI} + 0.60\,p_{amend}\,(100 - \text{SHMI})
```

Amendments are a bonus rather than a weighted sub-index: a field without
them is not marked down for it (SHMI+ = SHMI), no score can exceed 100,
and the bonus is largest where management alone scores lowest.

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
2.  **The weights.** The sub-index weights were fitted to that score by
    non-negative least squares with the amendment bonus in place, so
    SHMI+ is the calibrated score, with each site weighted equally.
    Fitting was repeated 1,000 times on different subsets of sites
    (10-fold cross-validation, repeated 100 times), and each final
    weight is the median. Cover and Diversity share much of their
    information, so Diversity’s weight was fixed at 0.15, within the
    range where held-out fit was unchanged.
3.  **Alternatives.** Other diversity measures (time-weighted Shannon
    diversity, crop rotation, functional richness) and other placements
    of animals and amendments were compared on the same sites, including
    Organic Inputs as a fourth weighted sub-index (SHMI 1.0). Most
    predicted about equally well. The final structure scores a field on
    its own management, treats amendments as a bonus that cannot push a
    score past 100, and lost about 0.01 in held-out R² against the
    four-sub-index version. The grazing share (0.25) and amendment share
    (0.60) were chosen where held-out fit was flat.

------------------------------------------------------------------------

## 4. How well it works

- **Fit to the US data.** SHMI+ correlates with measured soil health at
  r = 0.55 across all plots, SHMI at r = 0.52.
- **Sites it has not seen.** Predicting each site with weights fitted
  without it, SHMI+ explains about a quarter of the differences in soil
  health (R² = 0.26), and ranks practices in the right order at **82% of
  sites**; SHMI alone explains 0.23 and ranks 76% of sites correctly. A
  single prediction is typically within about 13 soil-health points.
- **Another region.** At 16 Mexican sites, never used in calibration,
  SHMI transferred poorly: predictions ran about 20 points low and
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

- built from three practice-based sub-indices that any management record
  can provide, with organic amendments reported as a bonus (SHMI+);
- weighted by calibration against measured soil health on US research
  sites;
- most reliable for comparing practices at the same site;
- transparent: every assumption made while reading the records is
  reported.

For the workflow, see the *SHMI Overview* article; for each sub-index,
see its own article.
