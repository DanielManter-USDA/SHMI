# NAPESHM: development vs installed version

    Code
      cat("Units compared:", nrow(cmp), "\n")
    Output
      Units compared: 508 
    Code
      cat("Units with |change in SHMI| >", tol, ":", nrow(moved), "\n\n")
    Output
      Units with |change in SHMI| > 0.01 : 1 
      
    Code
      print(by_pillar, row.names = FALSE)
    Output
          pillar units_moved max_up max_down
            SHMI           1   0.00   -11.92
           Cover           1   0.00   -27.75
       Diversity           1   5.64     0.00
         InvDist           0   0.00     0.00
        OrgInput           0   0.00     0.00
    Code
      cat("\nUnits whose SHMI moved (largest first):\n")
    Output
      
      Units whose SHMI moved (largest first):
    Code
      if (nrow(moved) == 0) cat("none\n") else print(moved, row.names = FALSE)
    Output
                MGT_combo SHMI_installed SHMI_dev d_SHMI d_Cover d_Diversity
       NAPESHM_USPA01_450           54.4    42.48 -11.92  -27.75        5.64
       d_InvDist d_OrgInput
               0          0

