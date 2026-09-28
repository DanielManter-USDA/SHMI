# NAPESHM: development vs installed version

    Code
      cat("Units compared:", nrow(cmp), "\n")
    Output
      Units compared: 508 
    Code
      cat("Units with |change in SHMI| >", tol, ":", nrow(moved), "\n\n")
    Output
      Units with |change in SHMI| > 0.01 : 0 
      
    Code
      print(by_pillar, row.names = FALSE)
    Output
          pillar units_moved max_up max_down
            SHMI           0      0        0
           Cover           0      0        0
       Diversity           0      0        0
         InvDist           0      0        0
        OrgInput           0      0        0
    Code
      cat("\nUnits whose SHMI moved (largest first):\n")
    Output
      
      Units whose SHMI moved (largest first):
    Code
      if (nrow(moved) == 0) cat("none\n") else print(moved, row.names = FALSE)
    Output
      none

