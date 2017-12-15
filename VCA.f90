MODULE VCA

  USE VCA_INPUT_VARS


  USE VCA_AUX_FUNX, only:       &
       vca_los2nnn_reshape,     &
       vca_nnn2los_reshape,     &
       vca_set_Hcluster,        &
       search_chemical_potential


  USE VCA_IO, only:             &
       vca_get_sigma_matsubara, &
       vca_get_gimp_matsubara,  &
       vca_get_sigma_realaxis,  &
       vca_get_gimp_realaxis,   &
       vca_get_dens,            &
       vca_get_mag,             &
       vca_get_docc,            &
       vca_get_sft_potential


  USE VCA_BATH_SETUP, only:     &
       vca_get_bath_dimension


  USE VCA_MAIN, only:           &
       vca_init_solver,         &
       vca_solve


END MODULE VCA