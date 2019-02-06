MODULE VCA_GF_NORMAL
  USE VCA_GF_SHARED
  USE VCA_AUX_FUNX
  implicit none
  private


  public :: build_gf_normal
  public :: build_sigma_normal


  integer                   :: istate
  integer                   :: isector,jsector
  integer                   :: idim,idimUP,idimDW
  integer                   :: jdim,jdimUP,jdimDW
  real(8),allocatable       :: vvinit(:),vvloc(:)
  complex(8),allocatable    :: cvinit(:)
  real(8),allocatable       :: alfa_(:),beta_(:)
  integer                   :: ialfa,ibeta
  integer                   :: jalfa,jbeta
  integer                   :: r
  integer                   :: i,iup,idw
  integer                   :: j,jup,jdw  
  integer                   :: m,mup,mdw
  real(8)                   :: sgn,norm2,norm0
  integer                   :: Nitermax,Nlanc,vecDim


contains



  !+------------------------------------------------------------------+
  !                        NORMAL
  !+------------------------------------------------------------------+
  subroutine build_gf_normal()
    integer :: iorb,jorb,ispin,i
    integer :: Nstates
    integer :: isite,jsite,ibath,icomposite,jbath,jcomposite
    logical :: MaskBool
    !
    if(allocated(impGmatrix))deallocate(impGmatrix)
    allocate(impGmatrix(Nlat,Nlat,Nspin,Nspin,Norb,Norb))
    !
    if(MPIMASTER)call start_timer
    ! 
    Nstates = state_list%size
    !Spin-Orbital diagonal:
    do ispin=1,Nspin
       do iorb=1,Norb
          write(LOGfile,"(A)")"Get impG_l"//str(iorb)//"_s"//str(ispin)
          !
          do isite=1,Nlat
             !site-digonal:
             call GFmatrix_allocate(impGmatrix(isite,isite,ispin,ispin,iorb,iorb),Nstate=Nstates) !2= add,del exc. c^+_i|psi>             
             call lanc_build_gf_normal_main(isite,iorb,ispin)
             !site-off-diagonal:
             do jsite=1,Nlat
                if(isite==jsite)cycle   !this is not elegant but who cares?
                call GFmatrix_allocate(impGmatrix(isite,jsite,ispin,ispin,iorb,iorb),Nstate=Nstates)!4=add,del exc. (c^+_i + c^+_j)/(c^+_i +ic^+_j)|psi>
                call lanc_build_gf_normal_mix_main(isite,jsite,iorb,ispin)
             enddo
          enddo
          !
          !nondiagonal trick
          do isite=1,Nlat
             do jsite=1,Nlat
                if(isite==jsite)cycle
                !impGmats(isite,jsite,ispin,ispin,iorb,iorb,:) = 0.5d0*(impGmats(isite,jsite,ispin,ispin,iorb,iorb,:) &
                !     - (one-xi)*impGmats(isite,isite,ispin,ispin,iorb,iorb,:) - (one-xi)*impGmats(jsite,jsite,ispin,ispin,iorb,iorb,:))
                !impGreal(isite,jsite,ispin,ispin,iorb,iorb,:) = 0.5d0*(impGreal(isite,jsite,ispin,ispin,iorb,iorb,:) &
                !     - (one-xi)*impGreal(isite,isite,ispin,ispin,iorb,iorb,:) - (one-xi)*impGreal(jsite,jsite,ispin,ispin,iorb,iorb,:))
                impGmats(isite,jsite,ispin,ispin,iorb,iorb,:) = 0.5d0*(impGmats(isite,jsite,ispin,ispin,iorb,iorb,:) &
                     - impGmats(isite,isite,ispin,ispin,iorb,iorb,:) - impGmats(jsite,jsite,ispin,ispin,iorb,iorb,:))
                impGreal(isite,jsite,ispin,ispin,iorb,iorb,:) = 0.5d0*(impGreal(isite,jsite,ispin,ispin,iorb,iorb,:) &
                     - impGreal(isite,isite,ispin,ispin,iorb,iorb,:) - impGreal(jsite,jsite,ispin,ispin,iorb,iorb,:))        
             enddo
          enddo
          !do isite=2,Nlat
          !  do jsite=1,isite-1
          !      write(LOGfile,*)"Symmetry provides G_cluster_I"//str(isite,3)//"_J"//str(jsite,3)
          !      impGmats(isite,jsite,ispin,ispin,iorb,iorb,:) = impGmats(jsite,isite,ispin,ispin,iorb,iorb,:)
          !      impGreal(isite,jsite,ispin,ispin,iorb,iorb,:) = impGreal(jsite,isite,ispin,ispin,iorb,iorb,:)       
          !  enddo
          !enddo
       enddo
    enddo
    if(MPIMASTER)call stop_timer(LOGfile)
  end subroutine build_gf_normal






  !################################################################
  !################################################################
  !################################################################
  !################################################################






  subroutine lanc_build_gf_normal_main(isite,iorb,ispin)
    integer,intent(in)          :: iorb,ispin,isite
    integer,dimension(2*Ns_Ud)  :: Indices
    integer,dimension(2*Ns_Ud)  :: Jndices
    integer,dimension(Ns_Ud)    :: iDimUps,iDimDws
    integer,dimension(Ns_Ud)    :: jDimUps,jDimDws
    integer,dimension(2,Ns_Orb) :: Nud
    integer,dimension(2)        :: Iud,Jud
    integer                     :: is
    type(sector_map)            :: HI(2*Ns_Ud),HJ(2*Ns_Ud)
    !
    !if(vca_total_ud)then
       ialfa = 1
    !   iorb1 = iorb
    !else
       !ialfa = iorb
       !iorb1 = 1
    !endif
    ibeta  = ialfa + (ispin-1)*Ns_Ud
    !
    is = imp_state_index(isite,iorb)
    !
    write(LOGfile,*)"Solving G_cluster_I"//str(isite,3)//"_J"//str(isite,3)
    !
    do istate=1,state_list%size
       call GFmatrix_allocate(impGmatrix(isite,isite,ispin,ispin,iorb,iorb),istate=istate,Nchan=2) !2= add,del exc. c^+_i|psi> 
       !print*,istate
       isector    =  es_return_sector(state_list,istate)
       state_e    =  es_return_energy(state_list,istate)
#ifdef _MPI
       if(MpiStatus)then
          state_cvec => es_return_cvector(MpiComm,state_list,istate) 
       else
          state_cvec => es_return_cvector(state_list,istate)
       endif
#else
       state_cvec => es_return_cvector(state_list,istate)
#endif
       !
       idim  = getdim(isector)
       call get_DimUp(isector,iDimUps)
       call get_DimDw(isector,iDimDws)
       iDimUp = product(iDimUps)
       iDimDw = product(iDimDws)
       call build_sector(isector,HI)
       !
       !
       !ADD ONE PARTICLE:
       jsector = getCDGsector(ialfa,ispin,isector)
       if(jsector/=0)then 
          !
          jdim   = getdim(jsector)
          call get_DimUp(jsector,jDimUps)
          call get_DImDw(jsector,jDimDws)
          jDimUp = product(jDimUps)
          jDimDw = product(jDimDws)
          !The Op|gs> is worked out by the master only:
          if(MpiMaster)then
             if(verbose==3)write(LOGfile,"(A,I6)")' add particle:',jsector
             !
             allocate(vvinit(jdim)) ; vvinit=zero
             !
             call build_sector(jsector,HJ)
             do i=1,iDim
                call state2indices(i,[iDimUps,iDimDws],Indices)
                iud(1)   = HI(ialfa)%map(Indices(ialfa))
                iud(2)   = HI(ialfa+Ns_Ud)%map(Indices(ialfa+Ns_Ud))
                nud(1,:) = Bdecomp(iud(1),Ns_Orb)
                nud(2,:) = Bdecomp(iud(2),Ns_Orb)
                !
                if(Nud(ispin,is)/=0)cycle
                call cdg(is,iud(ispin),r,sgn)
                Jndices        = Indices
                Jndices(ibeta) = binary_search(HJ(ibeta)%map,r)
                call indices2state(Jndices,[jDimUps,jDimDws],j)
                !
                vvinit(j) = sgn*state_cvec(i)
             enddo
             call delete_sector(jsector,HJ)
             !
             norm2=dot_product(vvinit,vvinit)
             if(verbose==3)write(LOGfile,"(A,F6.4)")' Add particle - Norm vvinit: ',norm2
             vvinit=vvinit/sqrt(norm2)
          endif
          !
          nlanc=min(jdim,lanc_nGFiter)
          allocate(alfa_(nlanc),beta_(nlanc))
          alfa_=0.d0
          beta_=0.d0
          call build_Hv_sector(jsector)
#ifdef _MPI
          if(MpiStatus)then
             if(MpiComm /= MPI_COMM_NULL)call Bcast_MPI(MpiComm,norm2)
             vecDim = vecDim_Hv_sector(jsector)
             allocate(vvloc(vecDim))
             if(MpiComm /= MPI_COMM_NULL) call scatter_vector_MPI(MpiComm,vvinit,vvloc)
             call sp_lanc_tridiag(MpiComm,spHtimesV_p,vvloc,alfa_,beta_)
          else
             call sp_lanc_tridiag(spHtimesV_p,vvinit,alfa_,beta_)
          endif
#else
          call sp_lanc_tridiag(spHtimesV_p,vvinit,alfa_,beta_)
#endif
          call delete_Hv_sector()
          call add_to_lanczos_gf_normal(one*norm2,state_e,alfa_,beta_,1,isite,isite,iorb,ispin,1,istate)
          !
          deallocate(alfa_,beta_)
          if(allocated(vvinit))deallocate(vvinit)          
          if(allocated(vvloc))deallocate(vvloc)
       else
          call GFmatrix_allocate(impGmatrix(isite,isite,ispin,ispin,iorb,iorb),istate=istate,ichan=1,Nexc=0)
       endif
       !
       !REMOVE ONE PARTICLE:
       jsector = getCsector(ialfa,ispin,isector)
       if(jsector/=0)then
          !            
          jdim   = getdim(jsector)
          call get_DimUp(jsector,jDimUps)
          call get_DImDw(jsector,jDimDws)
          jDimUp = product(jDimUps)
          jDimDw = product(jDimDws)
          !
          if(MpiMaster)then
             if(verbose==3)write(LOGfile,"(A,I6)")' del particle:',jsector
             allocate(vvinit(jdim)) ; vvinit=zero
             !
             call build_sector(jsector,HJ)
             do i=1,iDim
                call state2indices(i,[iDimUps,iDimDws],Indices)
                iud(1)   = HI(ialfa)%map(Indices(ialfa))
                iud(2)   = HI(ialfa+Ns_Ud)%map(Indices(ialfa+Ns_Ud))
                nud(1,:) = Bdecomp(iud(1),Ns_Orb)
                nud(2,:) = Bdecomp(iud(2),Ns_Orb)
                !
                if(nud(ispin,is)/=1)cycle
                call c(is,iud(ispin),r,sgn)
                Jndices        = Indices
                Jndices(ibeta) = binary_search(HJ(ibeta)%map,r)
                call indices2state(Jndices,[jDimUps,jDimDws],j)
                !
                vvinit(j) = sgn*state_cvec(i)
             enddo
             call delete_sector(jsector,HJ)
             !
             norm2=dot_product(vvinit,vvinit)
             if(verbose==3)write(LOGfile,"(A,F6.4)")' Remove particle - Norm vvinit: ',norm2
             vvinit=vvinit/sqrt(norm2)
          endif
          !
          nlanc=min(jdim,lanc_nGFiter)
          allocate(alfa_(nlanc),beta_(nlanc))
          alfa_=0.d0
          beta_=0.d0
          call build_Hv_sector(jsector)
#ifdef _MPI
          if(MpiStatus)then
             if(MpiComm /= MPI_COMM_NULL)call Bcast_MPI(MpiComm,norm2)
             vecDim = vecDim_Hv_sector(jsector)
             allocate(vvloc(vecDim))
             if(MpiComm /= MPI_COMM_NULL) call scatter_vector_MPI(MpiComm,vvinit,vvloc)
             call sp_lanc_tridiag(MpiComm,spHtimesV_p,vvloc,alfa_,beta_)
          else
             call sp_lanc_tridiag(spHtimesV_p,vvinit,alfa_,beta_)
          endif
#else
          call sp_lanc_tridiag(spHtimesV_p,vvinit,alfa_,beta_)
#endif
          call delete_Hv_sector()
          call add_to_lanczos_gf_normal(one*norm2,state_e,alfa_,beta_,-1,isite,isite,iorb,ispin,2,istate)
          !
          deallocate(alfa_,beta_)
          if(allocated(vvinit))deallocate(vvinit)          
          if(allocated(vvloc))deallocate(vvloc)
       else
          call GFmatrix_allocate(impGmatrix(isite,isite,ispin,ispin,iorb,iorb),istate=istate,ichan=2,Nexc=0)
       endif
       !
       !
       nullify(state_cvec)
       call delete_sector(isector,HI)
       !
    enddo
    return
  end subroutine lanc_build_gf_normal_main



  !################################################################
  !################################################################
  !################################################################
  !################################################################






  subroutine lanc_build_gf_normal_mix_main(isite,jsite,iorb,ispin)
    integer                     :: iorb,jorb,ispin,isite,jsite,istate,is,js
    integer,dimension(2*Ns_Ud)  :: Indices
    integer,dimension(2*Ns_Ud)  :: Jndices
    integer,dimension(Ns_Ud)    :: iDimUps,iDimDws
    integer,dimension(Ns_Ud)    :: jDimUps,jDimDws
    integer,dimension(2,Ns_Orb) :: Nud
    integer,dimension(2)        :: iud,jud
    type(sector_map)            :: HI(2*Ns_Ud),HJ(2*Ns_Ud)
    !
!    if(vca_total_ud)then
       ialfa = 1
       jalfa = 1
!       iorb1 = iorb
!       jorb1 = jorb
!    else
!       ialfa = iorb
!       jalfa = jorb
!       iorb1 = 1
!       jorb1 = 1
!    endif
    ibeta  = ialfa + (ispin-1)*Ns_Ud
    jbeta  = jalfa + (ispin-1)*Ns_Ud
    !
    is = imp_state_index(isite,iorb)
    js = imp_state_index(jsite,iorb)
    !
    write(LOGfile,*)"Solving G_cluster_I"//str(isite,3)//"_J"//str(jsite,3)
    !
    do istate=1,state_list%size
       call GFmatrix_allocate(impGmatrix(isite,jsite,ispin,ispin,iorb,iorb),istate=istate,Nchan=2) !2= add,del exc. c^+_i|psi> 
       isector    =  es_return_sector(state_list,istate)
       state_e    =  es_return_energy(state_list,istate)
#ifdef _MPI
       if(MpiStatus)then
          state_cvec => es_return_cvector(MpiComm,state_list,istate)
       else
          state_cvec => es_return_cvector(state_list,istate)
       endif
#else
       state_cvec => es_return_cvector(state_list,istate)
#endif
       !
       !
       idim  = getdim(isector)
       call get_DimUp(isector,iDimUps)
       call get_DimDw(isector,iDimDws)
       call build_sector(isector,HI)
       !
       !
       !EVALUATE (c^+_is + c^+_js)|gs>
       jsector = getCDGsector(ialfa,ispin,isector)
       if(jsector/=0)then
          !
          jdim   = getdim(jsector)
          call get_DimUp(jsector,jDimUps)
          call get_DImDw(jsector,jDimDws)
          !
          if(MpiMaster)then
             if(verbose==3)write(LOGfile,"(A,I15)")' add particle cdg_is+cdg_js:',jsector
             allocate(vvinit(jdim)) ; vvinit=zero
             !
             call build_sector(jsector,HJ)
             do i=1,iDim
                call state2indices(i,[iDimUps,iDimDws],Indices)
                iud(1)   = HI(ialfa)%map(Indices(ialfa))
                iud(2)   = HI(ialfa+Ns_Ud)%map(Indices(ialfa+Ns_Ud))
                nud(1,:) = Bdecomp(iud(1),Ns_Orb)
                nud(2,:) = Bdecomp(iud(2),Ns_Orb)
                !
                if(nud(ispin,is)/=0)cycle
                call cdg(is,iud(ispin),r,sgn)
                !
                Jndices        = Indices
                Jndices(ibeta) = binary_search(HJ(ibeta)%map,r)
                call indices2state(Jndices,[jDimUps,jDimDws],j)
                !
                vvinit(j) = sgn*state_cvec(i)
             enddo
             do i=1,iDim
                call state2indices(i,[iDimUps,iDimDws],Indices)
                iud(1)   = HI(jalfa)%map(Indices(jalfa))
                iud(2)   = HI(jalfa+Ns_Ud)%map(Indices(jalfa+Ns_Ud))
                nud(1,:) = Bdecomp(iud(1),Ns_Orb)
                nud(2,:) = Bdecomp(iud(2),Ns_Orb)
                !
                if(nud(ispin,js)/=0)cycle
                call cdg(js,iud(ispin),r,sgn)
                !
                Jndices        = Indices
                Jndices(jbeta) = binary_search(HJ(jbeta)%map,r)
                call indices2state(Jndices,[jDimUps,jDimDws],j)
                !
                vvinit(j) = vvinit(j) + sgn*state_cvec(i)
             enddo
             call delete_sector(jsector,HJ)
             !
             norm2=dot_product(vvinit,vvinit)
             if(verbose==3)write(LOGfile,"(A,F6.4)")' Add particle - Norm vvinit: ',norm2
             vvinit=vvinit/sqrt(norm2)
          endif
          !
          nlanc=min(jdim,lanc_nGFiter)
          allocate(alfa_(nlanc),beta_(nlanc))
          alfa_=0.d0
          beta_=0.d0          
          call build_Hv_sector(jsector)
#ifdef _MPI
          if(MpiStatus)then
             if(MpiComm /= MPI_COMM_NULL)call Bcast_MPI(MpiComm,norm2)    
             vecDim = vecDim_Hv_sector(jsector)
             allocate(vvloc(vecDim))
             if(MpiComm /= MPI_COMM_NULL) call scatter_vector_MPI(MpiComm,vvinit,vvloc)
             call sp_lanc_tridiag(MpiComm,spHtimesV_p,vvloc,alfa_,beta_)
          else
             call sp_lanc_tridiag(spHtimesV_p,vvinit,alfa_,beta_)
          endif
#else
          call sp_lanc_tridiag(spHtimesV_p,vvinit,alfa_,beta_)
#endif
          call delete_Hv_sector()
          call add_to_lanczos_gf_normal(one*norm2,state_e,alfa_,beta_,1,isite,jsite,iorb,ispin,1,istate)
          !
          deallocate(alfa_,beta_)
          if(allocated(vvinit))deallocate(vvinit)          
          if(allocated(vvloc))deallocate(vvloc)
       else
          call GFmatrix_allocate(impGmatrix(isite,jsite,ispin,ispin,iorb,iorb),istate=istate,ichan=1,Nexc=0)
       endif
       !
       !EVALUATE (c_is + c_js)|gs>
       jsector = getCsector(ialfa,ispin,isector)
       if(jsector/=0)then
          !
          jdim   = getdim(jsector)
          call get_DimUp(jsector,jDimUps)
          call get_DImDw(jsector,jDimDws)
          !
          if(MpiMaster)then
             if(verbose==3)write(LOGfile,"(A,I15)")' del particle c_is+c_js:',jsector
             allocate(vvinit(jdim)) ; vvinit=zero
             !
             call build_sector(jsector,HJ)
             do i=1,iDim
                call state2indices(i,[iDimUps,iDimDws],Indices)
                iud(1)   = HI(ialfa)%map(Indices(ialfa))
                iud(2)   = HI(ialfa+Ns_Ud)%map(Indices(ialfa+Ns_Ud))
                nud(1,:) = Bdecomp(iud(1),Ns_Orb)
                nud(2,:) = Bdecomp(iud(2),Ns_Orb)
                !
                if(nud(ispin,is)/=1)cycle
                call c(is,iud(ispin),r,sgn)
                !
                Jndices        = Indices
                Jndices(ibeta) = binary_search(HJ(ibeta)%map,r)
                call indices2state(Jndices,[jDimUps,jDimDws],j)
                !
                vvinit(j) = sgn*state_cvec(i)
             enddo
             do i=1,iDim
                call state2indices(i,[iDimUps,iDimDws],Indices)
                iud(1)   = HI(jalfa)%map(Indices(jalfa))
                iud(2)   = HI(jalfa+Ns_Ud)%map(Indices(jalfa+Ns_Ud))
                nud(1,:) = Bdecomp(iud(1),Ns_Orb)
                nud(2,:) = Bdecomp(iud(2),Ns_Orb)
                !
                if(nud(ispin,js)/=1)cycle
                call c(js,iud(ispin),r,sgn)
                !
                Jndices        = Indices
                Jndices(jbeta) = binary_search(HJ(jbeta)%map,r)
                call indices2state(Jndices,[jDimUps,jDimDws],j)
                !
                vvinit(j) = vvinit(j) + sgn*state_cvec(i)
             enddo
             call delete_sector(jsector,HJ)
             !
             norm2=dot_product(vvinit,vvinit)
             if(verbose==3)write(LOGfile,"(A,F6.4)")' Del particle - Norm vvinit: ',norm2
             vvinit=vvinit/sqrt(norm2)
          endif
          !
          nlanc=min(jdim,lanc_nGFiter)
          allocate(alfa_(nlanc),beta_(nlanc))
          alfa_=0.d0
          beta_=0.d0
          call build_Hv_sector(jsector)
#ifdef _MPI
          if(MpiStatus)then
             if(MpiComm /= MPI_COMM_NULL)call Bcast_MPI(MpiComm,norm2)
             vecDim = vecDim_Hv_sector(jsector)
             allocate(vvloc(vecDim))
             if(MpiComm /= MPI_COMM_NULL) call scatter_vector_MPI(MpiComm,vvinit,vvloc)
             call sp_lanc_tridiag(MpiComm,spHtimesV_p,vvloc,alfa_,beta_)
          else
             call sp_lanc_tridiag(spHtimesV_p,vvinit,alfa_,beta_)
          endif
#else
          call sp_lanc_tridiag(spHtimesV_p,vvinit,alfa_,beta_)
#endif
          call delete_Hv_sector()    
          call add_to_lanczos_gf_normal(one*norm2,state_e,alfa_,beta_,-1,isite,jsite,iorb,ispin,2,istate)
          !
          deallocate(alfa_,beta_)
          if(allocated(vvinit))deallocate(vvinit)          
          if(allocated(vvloc))deallocate(vvloc)
       else
          call GFmatrix_allocate(impGmatrix(isite,jsite,ispin,ispin,iorb,iorb),istate=istate,ichan=2,Nexc=0)
       endif
       !
      !EVALUATE (c^+_is + i*c^+_js)|gs>
       !jsector = getCDGsector(ialfa,ispin,isector)
       !if(jsector/=0)then
          
          !jdim   = getdim(jsector)
          !call get_DimUp(jsector,jDimUps)
          !call get_DImDw(jsector,jDimDws)
          
          !if(MpiMaster)then
             !if(verbose==3)write(LOGfile,"(A,I15)")' add particle:',jsector
             !allocate(vvinit(jdim)) ; vvinit=zero
             
             !call build_sector(jsector,HJ)
             !do i=1,iDim
                !call state2indices(i,[iDimUps,iDimDws],Indices)
                !iud(1)   = HI(ialfa)%map(Indices(ialfa))
                !iud(2)   = HI(ialfa+Ns_Ud)%map(Indices(ialfa+Ns_Ud))
                !nud(1,:) = Bdecomp(iud(1),Ns_Orb)
                !nud(2,:) = Bdecomp(iud(2),Ns_Orb)
                
                !if(nud(ispin,is)/=0)cycle
                !call cdg(is,iud(ispin),r,sgn)
                
                !Jndices        = Indices
                !Jndices(ibeta) = binary_search(HJ(ibeta)%map,r)
                !call indices2state(Jndices,[jDimUps,jDimDws],j)
                
                !cvinit(j) = sgn*state_cvec(i)
             !enddo
             !do i=1,iDim
                !call state2indices(i,[iDimUps,iDimDws],Indices)
                !iud(1)   = HI(jalfa)%map(Indices(jalfa))
                !iud(2)   = HI(jalfa+Ns_Ud)%map(Indices(jalfa+Ns_Ud))
                !nud(1,:) = Bdecomp(iud(1),Ns_Orb)
                !nud(2,:) = Bdecomp(iud(2),Ns_Orb)
                
                !if(nud(ispin,js)/=0)cycle
                !call cdg(js,iud(ispin),r,sgn)
                
                !Jndices        = Indices
                !Jndices(jbeta) = binary_search(HJ(jbeta)%map,r)
                !call indices2state(Jndices,[jDimUps,jDimDws],j)
                
                !cvinit(j) = cvinit(j) + xi*sgn*state_cvec(i)
             !enddo
             !call delete_sector(jsector,HJ)
             
             !norm2=dot_product(cvinit,cvinit)
             !cvinit=cvinit/sqrt(norm2)
          !endif
          
          !nlanc=min(jdim,lanc_nGFiter)
          !allocate(alfa_(nlanc),beta_(nlanc))
          !alfa_=0.d0
          !beta_=0.d0          
          !call build_Hv_sector(jsector)
!#ifdef _MPI
          !if(MpiStatus)then
             !if(MpiComm /= MPI_COMM_NULL)call Bcast_MPI(MpiComm,norm2)
             !vecDim = vecDim_Hv_sector(jsector)
             !allocate(vvloc(vecDim))
             !if(MpiComm /= MPI_COMM_NULL) call scatter_vector_MPI(MpiComm,cvinit,vvloc)
             !call sp_lanc_tridiag(MpiComm,spHtimesV_p,vvloc,alfa_,beta_)
          !else
             !call sp_lanc_tridiag(spHtimesV_p,cvinit,alfa_,beta_)
          !endif
!#else
          !call sp_lanc_tridiag(spHtimesV_p,cvinit,alfa_,beta_)
!#endif
          !call delete_Hv_sector()
          !call add_to_lanczos_gf_normal(-xi*norm2,state_e,alfa_,beta_,1,isite,jsite,iorb,ispin,3)
          
          !deallocate(alfa_,beta_)
          !if(allocated(cvinit))deallocate(cvinit)          
          !if(allocated(vvloc))deallocate(vvloc)
       !endif
       
       !EVALUATE (c_js - i*c_js)|gs>
       !jsector = getCsector(ialfa,ispin,isector)
       !if(jsector/=0)then
          
          !jdim   = getdim(jsector)
          !call get_DimUp(jsector,jDimUps)
          !call get_DImDw(jsector,jDimDws)
          
          !if(MpiMaster)then
             !if(verbose==3)write(LOGfile,"(A,I15)")' del particle:',jsector
             !allocate(cvinit(jdim)) ; cvinit=zero
             
             !call build_sector(jsector,HJ)
             !do i=1,iDim
                !call state2indices(i,[iDimUps,iDimDws],Indices)
                !iud(1)   = HI(ialfa)%map(Indices(ialfa))
                !iud(2)   = HI(ialfa+Ns_Ud)%map(Indices(ialfa+Ns_Ud))
                !nud(1,:) = Bdecomp(iud(1),Ns_Orb)
                !nud(2,:) = Bdecomp(iud(2),Ns_Orb)
                
                !if(nud(ispin,is)/=1)cycle
                !call c(is,iud(ispin),r,sgn)
                
                !Jndices        = Indices
                !Jndices(ibeta) = binary_search(HJ(ibeta)%map,r)
                !call indices2state(Jndices,[jDimUps,jDimDws],j)
                
                !cvinit(j) = sgn*state_cvec(i)
             !enddo
             !do i=1,iDim
                !call state2indices(i,[iDimUps,iDimDws],Indices)
                !iud(1)   = HI(jalfa)%map(Indices(jalfa))
                !iud(2)   = HI(jalfa+Ns_Ud)%map(Indices(jalfa+Ns_Ud))
                !nud(1,:) = Bdecomp(iud(1),Ns_Orb)
                !nud(2,:) = Bdecomp(iud(2),Ns_Orb)
                
                !if(nud(ispin,js)/=1)cycle
                !call c(js,iud(ispin),r,sgn)
                
                !Jndices        = Indices
                !Jndices(jbeta) = binary_search(HJ(jbeta)%map,r)
                !call indices2state(Jndices,[jDimUps,jDimDws],j)
                
                !cvinit(j) = cvinit(j) + xi*sgn*state_cvec(i)
             !enddo
             !call delete_sector(jsector,HJ)
             
             !norm2=dot_product(cvinit,cvinit)
             !cvinit=cvinit/sqrt(norm2)
          !endif
          
          !nlanc=min(jdim,lanc_nGFiter)
          !allocate(alfa_(nlanc),beta_(nlanc))
          !alfa_=0.d0
          !beta_=0.d0
          !call build_Hv_sector(jsector)
!#ifdef _MPI
          !if(MpiStatus)then
             !if(MpiComm /= MPI_COMM_NULL)call Bcast_MPI(MpiComm,norm2)
             !vecDim = vecDim_Hv_sector(jsector)
             !allocate(vvloc(vecDim))
             !if(MpiComm /= MPI_COMM_NULL) call scatter_vector_MPI(MpiComm,cvinit,vvloc)
             !call sp_lanc_tridiag(MpiComm,spHtimesV_p,vvloc,alfa_,beta_)
          !else
             !call sp_lanc_tridiag(spHtimesV_p,cvinit,alfa_,beta_)
          !endif
!#else
          !call sp_lanc_tridiag(spHtimesV_p,cvinit,alfa_,beta_)
!#endif
          !call delete_Hv_sector()    
          !call add_to_lanczos_gf_normal(-xi*norm2,state_e,alfa_,beta_,-1,isite,jsite,iorb,ispin,4)
          
          !deallocate(alfa_,beta_)
          !if(allocated(cvinit))deallocate(cvinit)          
          !if(allocated(vvloc))deallocate(vvloc)
       !endif
       
       nullify(state_cvec)
       call delete_sector(isector,HI)
       !
    enddo
    return
  end subroutine lanc_build_gf_normal_mix_main



  !################################################################
  !################################################################
  !################################################################
  !################################################################




subroutine add_to_lanczos_gf_normal(vnorm2,Ei,alanc,blanc,isign,ilat,jlat,iorb,ispin,ichan,istate)
  integer                                    :: ilat,jlat
  complex(8)                                 :: vnorm2,pesoBZ,peso
  real(8)                                    :: Ei,Egs,de
  integer                                    :: nlanc,itype
  real(8),dimension(:)                       :: alanc
  real(8),dimension(size(alanc))             :: blanc 
  integer                                    :: isign,iorb,jorb,ispin,ichan,istate
  real(8),dimension(size(alanc),size(alanc)) :: Z
  real(8),dimension(size(alanc))             :: diag,subdiag
  integer                                    :: i,j,ierr
  complex(8)                                 :: iw
  !
  Egs = state_list%emin       !get the gs energy
  !
  Nlanc = size(alanc)
  !
  if((finiteT).and.(beta*(Ei-Egs).lt.200))then
     pesoBZ = vnorm2*exp(-beta*(Ei-Egs))/zeta_function
  elseif(.not.finiteT)then
     pesoBZ = vnorm2/zeta_function
  else
     pesoBZ=0.d0
  endif
  !
  !pesoBZ = vnorm2/zeta_function
  !if(finiteT)pesoBZ = vnorm2*exp(-beta*(Ei-Egs))/zeta_function
  !
  !
#ifdef _MPI
  if(MpiStatus)then
     if(MpiComm /= MPI_COMM_NULL)call Bcast_MPI(MpiComm,alanc)
     if(MpiComm /= MPI_COMM_NULL)call Bcast_MPI(MpiComm,blanc)
  endif
#endif
  diag             = 0.d0
  subdiag          = 0.d0
  Z                = eye(Nlanc)
  diag(1:Nlanc)    = alanc(1:Nlanc)
  subdiag(2:Nlanc) = blanc(2:Nlanc)
  call tql2(Nlanc,diag,subdiag,Z,ierr)
  !
  call GFmatrix_allocate(impGmatrix(ilat,jlat,ispin,ispin,iorb,iorb),istate=istate,ichan=ichan,Nexc=Nlanc)
  !
  do j=1,nlanc
     de = diag(j)-Ei
     peso = pesoBZ*Z(1,j)*Z(1,j)
     !
     impGmatrix(ilat,jlat,ispin,ispin,iorb,iorb)%state(istate)%channel(ichan)%weight(j) = peso
     impGmatrix(ilat,jlat,ispin,ispin,iorb,iorb)%state(istate)%channel(ichan)%poles(j)  = isign*de
     !
     do i=1,Lmats
        iw=xi*wm(i)
        impGmats(ilat,jlat,ispin,ispin,iorb,iorb,i)=impGmats(ilat,jlat,ispin,ispin,iorb,iorb,i) + peso/(iw-isign*de)
     enddo
     do i=1,Lreal
        iw=dcmplx(wr(i),eps)
        impGreal(ilat,jlat,ispin,ispin,iorb,iorb,i)=impGreal(ilat,jlat,ispin,ispin,iorb,iorb,i) + peso/(iw-isign*de)
     enddo
  enddo
end subroutine add_to_lanczos_gf_normal



  !############################################################################################
  !############################################################################################
  !############################################################################################
  !############################################################################################
  !############################################################################################
  !############################################################################################


  subroutine build_sigma_normal
    integer                                                     :: ii,ilat,jlat,ispin,iorb
    complex(8),dimension(:,:,:,:,:,:,:),allocatable             :: invG0mats,invGmats
    complex(8),dimension(:,:,:,:,:,:,:),allocatable             :: invG0real,invGreal
    !
    ! if(.not.allocated(wm))allocate(wm(Lmats))
    ! if(.not.allocated(wr))allocate(wr(Lreal))
    ! wm     = pi/beta*real(2*arange(1,Lmats)-1,8)
    ! wr     = linspace(wini,wfin,Lreal)
    !
    if(.not.allocated(InvG0mats))allocate(invG0mats(Nlat,Nlat,Nspin,Nspin,Norb,Norb,Lmats));invG0mats=zero
    if(.not.allocated(InvG0real))allocate(invG0real(Nlat,Nlat,Nspin,Nspin,Norb,Norb,Lreal));invG0real=zero
    if(.not.allocated(InvGmats))allocate(invGmats(Nlat,Nlat,Nspin,Nspin,Norb,Norb,Lmats));invGmats=zero
    if(.not.allocated(InvGreal))allocate(invGreal(Nlat,Nlat,Nspin,Nspin,Norb,Norb,Lreal));invGreal=zero
    !
    !
    !Get G0^-1
    !invG0mats = invg0_bath_mats(dcmplx(0d0,wm(:)),vca_bath)
    !invG0real = invg0_bath_real(dcmplx(wr(:),eps),vca_bath)
    do ii=1,Lmats
      invG0mats(:,:,:,:,:,:,ii)=vca_lso2nnn_reshape((xi*wm(ii)+xmu)*eye(Nlat*Nspin*Norb)-vca_nnn2lso_reshape(impHloc,Nlat,Nspin,Norb),Nlat,Nspin,Norb)
    enddo
    do ii=1,Lreal
      invG0real(:,:,:,:,:,:,ii)=vca_lso2nnn_reshape((wr(ii)+xmu)*eye(Nlat*Nspin*Norb)-vca_nnn2lso_reshape(impHloc,Nlat,Nspin,Norb),Nlat,Nspin,Norb)
    enddo
    !
    !Get Gimp^-1
    do ilat=1,Nlat
      do jlat=1,Nlat
        do ispin=1,Nspin
          do iorb=1,Norb
             invGmats(ilat,jlat,ispin,ispin,iorb,iorb,:) = one/impGmats(ilat,jlat,ispin,ispin,iorb,iorb,:)
             invGreal(ilat,jlat,ispin,ispin,iorb,iorb,:) = one/impGreal(ilat,jlat,ispin,ispin,iorb,iorb,:)
          enddo
        enddo
      enddo
    enddo
    !Get Sigma functions: Sigma= G0^-1 - G^-1
    impSmats=zero
    impSreal=zero
    do ilat=1,Nlat
      do jlat=1,Nlat
        do ispin=1,Nspin
          do iorb=1,Norb
             impSmats(ilat,jlat,ispin,ispin,iorb,iorb,:) = invG0mats(ilat,jlat,ispin,ispin,iorb,iorb,:) - invGmats(ilat,jlat,ispin,ispin,iorb,iorb,:)
             impSreal(ilat,jlat,ispin,ispin,iorb,iorb,:) = invG0real(ilat,jlat,ispin,ispin,iorb,iorb,:) - invGreal(ilat,jlat,ispin,ispin,iorb,iorb,:)
          enddo
        enddo
      enddo
    enddo
       !
    !
    !Get G0and:
    !impG0mats(:,:,:,:,:,:,:) = g0and_bath_mats(dcmplx(0d0,wm(:)),vca_bath)
    !impG0real(:,:,:,:,:,:,:) = g0and_bath_real(dcmplx(wr(:),eps),vca_bath)
    !!
    !
  end subroutine build_sigma_normal


  !############################################################################################
  !############################################################################################
  !############################################################################################
  !############################################################################################
  !############################################################################################
  !############################################################################################


END MODULE VCA_GF_NORMAL











