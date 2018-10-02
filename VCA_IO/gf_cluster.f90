  subroutine vca_gf_cluster_scalar(zeta,gf)
    complex(8)                                                          :: zeta
    complex(8),dimension(Nlat,Nlat,Nspin,Nspin,Norb,Norb),intent(inout) :: gf
    complex(8)                                                          :: green
    integer                                                             :: ispin
    integer                                                             :: ilat,jlat
    integer                                                             :: iorb,jorb
    integer                                                             :: iexc,Nexc
    integer                                                             :: ichan,Nchannel
    integer                                                             :: i,is,js
    real(8)                                                             :: weight,de
    !
    if(.not.allocated(impGmatrix))stop "vca_gf_cluster ERROR: impGmatrix not allocated!"
    !
    gf = zero
    !
    do ilat=1,Nlat
       do jlat=1,Nlat
          do iorb=1,Norb
             do ispin=1,Nspin
                !
                green = zero
                Nchannel = size(impGmatrix(ilat,jlat,ispin,ispin,iorb,iorb)%channel)
                do ichan=1,Nchannel
                   Nexc  = size(impGmatrix(ilat,jlat,ispin,ispin,iorb,iorb)%channel(ichan)%poles)
                   do iexc=1,Nexc
                      weight = impGmatrix(ilat,jlat,ispin,ispin,iorb,iorb)%channel(ichan)%weight(iexc)
                      de     = impGmatrix(ilat,jlat,ispin,ispin,iorb,iorb)%channel(ichan)%poles(iexc)
                      green = green + weight/(zeta-de)
                   enddo
                enddo
                gf(ilat,jlat,ispin,ispin,iorb,iorb) = green
             enddo
          enddo
       enddo
    enddo
    !
  end subroutine vca_gf_cluster_scalar

  subroutine vca_gf_cluster_array(zeta,gf)
    complex(8),dimension(:)                                                        :: zeta
    complex(8),dimension(Nlat,Nlat,Nspin,Nspin,Norb,Norb,size(zeta)),intent(inout) :: gf
    complex(8),dimension(Nlat,Nlat,Nspin,Nspin,Norb,Norb)                          :: green
    integer                                                                        :: ispin
    integer                                                                        :: ilat,jlat
    integer                                                                        :: iorb,jorb
    integer                                                                        :: iexc,Nexc
    integer                                                                        :: ichan,Nchannel
    integer                                                                        :: i,is,js
    real(8)                                                                        :: weight,de
    !
    if(.not.allocated(impGmatrix))stop "vca_gf_cluster ERROR: impGmatrix not allocated!"
    !
    gf = zero
    do i=1,size(zeta)
       call vca_gf_cluster_scalar(zeta(i),green)
       gf(:,:,:,:,:,:,i) = green
    enddo
    !
  end subroutine vca_gf_cluster_array