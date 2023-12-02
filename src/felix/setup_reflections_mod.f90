!%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
!
! Felix
!
! Richard Beanland, Keith Evans & Rudolf A Roemer
!
! (C) 2013-17, all rights reserved
!
! Version: 2.0
! Date: 19-12-2022
! Time:    :TIME:
! Status:  :RLSTATUS:
! Build: cRED
! Author:  r.beanland@warwick.ac.uk
! 
!%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
!
!  Felix is free software: you can redistribute it and/or modify
!  it under the terms of the GNU General Public License as published by
!  the Free Software Foundation, either version 3 of the License, or
!  (at your option) any later version.
!  
!  Felix is distributed in the hope that it will be useful,
!  but WITHOUT ANY WARRANTY; without even the implied warranty of
!  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
!  GNU General Public License for more details.
!  
!  You should have received a copy of the GNU General Public License
!  along with Felix.  If not, see <http://www.gnu.org/licenses/>.
!
!%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

!>
!! Module-description: 
!!
MODULE setup_reflections_mod

  IMPLICIT NONE
  PRIVATE
  PUBLIC :: HKLMake,HKLList

  CONTAINS
  
  !!$%%HKLMake%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  !>
  !! Procedure-description:
  !! 1) Fills the beam pool list RgPoolList for each frame (global variable)
  !! 2) Fills the list of output reflections IgOutList & writes to hkl_list.txt
  !! 3) Makes a set of simple kinematic frames
  !!
  !! Major-Authors: Richard Beanland (2023)
  !!  
  SUBROUTINE HKLMake(RDevLimit, RGOutLimit, IErr)   

    USE MyNumbers
    USE message_mod
    USE myMPI

    ! global inputs/outputs
    USE SPARA, ONLY : SPrintString,SChemicalFormula
    USE IPARA, ONLY : INhkl,IgOutList,IgPoolList,IhklLattice,INFrames,InLattice,ILN,IByteSize,ISort
    USE RPARA, ONLY : RXDirO,RYDirO,RZDirO,RarVecO,RbrVecO,RcrVecO,RarMag,RbrMag,RcrMag,RFrameAngle,RBigK,&
        RgLatticeO,RgPoolSg,RgMagLattice
    USE CPARA, ONLY : CFgLattice
    USE Iconst
    USE IChannels, ONLY : IChOutIhkl,IChOutIM
    
    IMPLICIT NONE

    REAL(RKIND),INTENT(IN) :: RDevLimit, RGOutLimit, RShell
    INTEGER(IKIND) :: IErr,ind,jnd,knd,lnd,mnd,ISim,Ix,Iy,ILocalFrameMin,ILocalFrameMax,&
                      ILocalNFrames,IMaxNg,inda, indb, indc,Ig(INFrames*INhkl,ITHREE),Ifound
    INTEGER(IKIND), DIMENSION(:), ALLOCATABLE :: Inum,Ipos,ILocalgPool,ITotalgPool
    REAL(RKIND) :: RAngle,Rk(INFrames,ITHREE),Rk0(INFrames,ITHREE),Rp(INFrames,ITHREE),RSg,Rphi,Rg(ITHREE),RInst,RIkin,&
                   RKplusg(ITHREE),RgMag
    REAL(RKIND), DIMENSION(:,:), ALLOCATABLE :: RSim
    REAL(RKIND), DIMENSION(:), ALLOCATABLE :: RLocalSgPool,RTotalSgPool
    CHARACTER(200) :: path
    CHARACTER(100) :: fString
   
    !-1------------------------------------------------------------------
    ! calculate reflection list g by g
    !--------------------------------------------------------------------
    ! this produces a list of g-vectors Ig and two flags indicating which frame they appear
    ! in the beam pool and the output list
    ! we make a matrix of the incident k-vectors for each frame
    DO ind = 1,INFrames
      RAngle = REAL(ILocalFrameMin+ind-2)*DEG2RADIAN*RFrameAngle
      ! Rk is the k-vector for the incident beam, which we write here in the orthogonal frame O
      Rk(ind,:) = RBigK*(RZDirO*COS(RAngle)+RXDirO*SIN(RAngle))
      ! the 000 beam is the first g-vector in every frame
    END DO
    Ig(1,:) = (/0,0,0/) 
    lnd = 2  ! index counting g's as they are included in the list    
    ! we work our way out in shells of 0.1 A^-1, starting with 2* the smallest reciprocal lattice vector
    RShell = MINVAL( (/RarMag,RbrMag,RcrMag/) )
    mnd = 1 ! shell count
    inda=NINT(REAL(mnd)*RShell/RarMag)
    indb=NINT(REAL(mnd)*RShell/RbrMag)
    indc=NINT(REAL(mnd)*RShell/RcrMag)
    DO ind = -inda,inda
      DO jnd = -indb,indb
        DO knd = -indc,indc
          Ifound = 0  ! flag to indicate this g-vector is active
          Rg = ind*RarVecO + jnd*RbrVecO + knd*RcrVecO
          RgMag = SQRT(DOT_PRODUCT(Rg,Rg))
          ! Is this g-vector in the current shell
          IF (RgMag.GT.REAL(mnd-1)*RShell.AND.RgMag.LE.REAL(mnd)*RShell.AND.RgMag.LE.RLatticeLimit)
            ! go through the frames and see if it appears
            ! Calculate Sg by getting the vector k0, which is coplanar with k and g and
            ! corresponds to an incident beam at the Bragg condition
            ! First we need the vector component of k perpendicular to g, which we call p 
            Rp = Rk - MATMUL(Rk,Rg)*Rg/RgMag
            ! and now make k0 by adding vectors parallel to g and p
            ! i.e. k0 = (p/|p|)*(k^2-g^2/4)^0.5 - g/2
!            Rk0 = SQRT(RBigK**2-QUARTER*RgMag**2)*Rp/SQRT(DOT_PRODUCT(Rp,Rp)) - HALF*Rg
            ! The angle phi between k and k0 is how far we are from the Bragg condition
!            Rphi = ACOS(DOT_PRODUCT(Rk,Rk0)/(RBigK**2))
            ! and now Sg is 2g sin(phi/2), with the sign of K-|K+g|
!            RKplusg = Rk + Rg
1            RSg = TWO*RgMag*SIN(HALF*Rphi)*SIGN(ONE,RBigK-SQRT(DOT_PRODUCT(RKplusg,RKplusg)))
          END IF
        END DO
      END DO
    END DO
    IF(my_rank.EQ.))PRINT*,Rp

  END SUBROUTINE HKLmake

  !!$%%HKLList%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  !>
  !! Procedure-description: List the frames for each reflection
  !!
  !! Major-Authors: Richard Beanland (2023)
  !!  
  SUBROUTINE HKLList( IErr )

    ! This procedure is called once in felixrefine setup
    ! 1) get unique g's in all pools
    ! 2) make a new list of unique g's and associated parameters and delete reciprocal lattice
    ! 3) save a set of kinematic rocking curves
    
    USE MyNumbers
    USE message_mod

    ! global parameters
    USE IPARA, ONLY : ILN,INFrames,ISort,INhkl,IgPoolList,IgOutList,Ihkl,IhklLattice,INoOfHKLsAll
    USE SPARA, ONLY : SPrintString,SChemicalFormula
    USE RPARA, ONLY : RgO,RgMag,RgLatticeO,RgMagLattice,RgPoolSg
    USE CPARA, ONLY : CFg,CFgLattice
    USE IChannels, ONLY : IChOutIhkl

    IMPLICIT NONE

    REAL(RKIND) :: RInst,RIkin
    INTEGER(IKIND) :: ind,jnd,knd,lnd,Iy,IErr,Imin,Imax
    INTEGER(IKIND), DIMENSION(:), ALLOCATABLE :: IFullgList,IReducedgList,IUniquegList
    CHARACTER(200) :: path
    CHARACTER(100) :: fString

    !-1------------------------------------------------------------------
    ! first get a list of pool reflections without duplicates, IUniquegList
    ind = INFrames*INhkl
    ALLOCATE(IFullgList(ind), STAT=IErr)  ! everything
    ALLOCATE(IReducedgList(ind), STAT=IErr)  ! unique reflections in an oversize matrix
    IF(l_alert(IErr,"HKLlist","allocations 1")) RETURN
    IFullgList = RESHAPE(IgPoolList,[ind])
    !now the list of unique reflections
    Imin = 0
    Imax = MAXVAL(IFullgList)
    ind = 0
    DO WHILE (Imin.LT.Imax)
        ind = ind+1
        Imin = MINVAL(IFullgList, MASK=IFullgList.GT.Imin)
        IReducedgList(ind) = Imin
    END DO
    ALLOCATE(IUniquegList(ind), STAT=IErr)
    IF(l_alert(IErr,"HKLlist","allocations 2")) RETURN
    IUniquegList = IReducedgList(1:ind)
    IF(l_alert(IErr,"HKLlist","allocate IUniquegList")) RETURN
    ! Tidy up
    DEALLOCATE(IFullgList,IReducedgList)
    INoOfHKLsAll = ind
    WRITE(SPrintString, FMT='(I5,A19)') ind, " pool reflections"
    CALL message(LS,SPrintString)

    !-2------------------------------------------------------------------
    ! Make reduced lists of hkl, g-vector, |g| and Fg so we can deallocate the reciprocal lattice
    ALLOCATE(Ihkl(INoOfHKLsAll,ITHREE), STAT=IErr)  ! Miller indices
    ALLOCATE(RgO(INoOfHKLsAll,ITHREE), STAT=IErr)  ! g-vector, orthogonal frame
    ALLOCATE(RgMag(INoOfHKLsAll), STAT=IErr)  ! |g|
    ALLOCATE(CFg(INoOfHKLsAll), STAT=IErr)  ! Fg
    IF(l_alert(IErr,"HKLlist","allocations 3")) RETURN
    DO jnd = 1,INoOfHKLsAll
      Ihkl(jnd,:) = IhklLattice(IUniquegList(jnd),:)
      RgO(jnd,:) = RgLatticeO(IUniquegList(jnd),:)
      RgMag(jnd) = RgMagLattice(IUniquegList(jnd))
      CFg(jnd) = CFgLattice(IUniquegList(jnd))
    END DO
    ! Change the indices for IgPoolList and IgOutList
    ! For a frame [j] and a given reflection in the beam pool [i,j],
    ! we find hkl, g, |g| and Fg at the index given in IgPoolList[i,j].
    ! IgOutList[i,j] gives the number of the output reflection.
    lnd = 0  ! counter for output reflections
    DO ind = 1,INoOfHKLsAll
      Iy = 1  ! flag for counting
      DO jnd = 1, INhkl
        DO knd = 1, INFrames
          IF (IgPoolList(jnd,knd).EQ.IUniquegList(ind)) IgPoolList(jnd,knd) = ind
          IF (IgOutList(jnd,knd).EQ.IUniquegList(ind)) THEN
            IF (Iy.EQ.1) THEN  ! we only count the first appearance
              lnd = lnd + 1
              Iy = 0
            END IF
            IgOutList(jnd,knd) = lnd
          END IF
        END DO
      END DO
    END DO
    WRITE(SPrintString, FMT='(I5,A19)') lnd, " output reflections"
    CALL message(LS,SPrintString)

    !-3------------------------------------------------------------------
    ! kinematic rocking curves  
    RInst = 3000.0  ! instrument broadening term
    IF(my_rank.EQ.0) THEN
      CALL message(LS,dbg3,"Writing kinematic rocking curves")
      path = SChemicalFormula(1:ILN) // "/hkl_K-rocks.txt"
      OPEN(UNIT=IChOutIhkl, ACTION='WRITE', POSITION='APPEND', STATUS= 'UNKNOWN', &
          FILE=TRIM(ADJUSTL(path)),IOSTAT=IErr)
      WRITE(IChOutIhkl,*) "List of kinematic rocking curves"
      DO ind = 1,lnd
        Iy = 1
        DO knd = 1,INFrames
          DO jnd = 1,INhkl
            IF (IgOutList(jnd,knd).EQ.ind) THEN
              IF (Iy.EQ.1) THEN
                WRITE(fString,"(3(I3,1X))") Ihkl(IgPoolList(jnd,knd),:)
                WRITE(IChOutIhkl,*) TRIM(ADJUSTL(fString))
                Iy = 0
              END IF
              RIkin = CFg(IgPoolList(jnd,knd))*CONJG(CFg(IgPoolList(jnd,knd))) * &
                  EXP(-RInst*RgPoolSg(jnd,knd)*RgPoolSg(jnd,knd)) ! Gaussian shape of reflection with Sg
              WRITE(fString,"(I4,A3,F7.3)") knd," : ",RIkin
              WRITE(IChOutIhkl,*) TRIM(ADJUSTL(fString))
            END IF
          END DO
        END DO    
      END DO
      CLOSE(IChOutIhkl,IOSTAT=IErr)
    END IF
    
 
  END SUBROUTINE HKLList
  
  !%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  !>
  !! Procedure-description: Sorts Rhkl array into descending order
  !!
  !! Major-Authors: Keith Evans (2014), Richard Beanland (2016)
  !!
  SUBROUTINE HKLSort(LocalRhkl,N,IErr )

    !--------------------------------------------------------------------
    !	Sort: is based on ShellSort from "Numerical Recipes", routine SHELL().
    !---------------------------------------------------------------------  

    USE MyNumbers
      
    USE SConst; USE IConst
    USE IPara; USE RPara

    USE IChannels

    USE MPI
    USE MyMPI

    IMPLICIT NONE

    INTEGER (IKIND) :: IErr,NN,M,L,K,J,I,LOGNB2,ind
    INTEGER (IKIND),INTENT(IN) :: N
    REAL(RKIND),INTENT(INOUT) :: LocalRhkl(N,ITHREE)
    REAL(RKIND) :: RhklSearch(ITHREE), RhklCompare(ITHREE)
    REAL(RKIND) :: ALN2I,LocalTINY,dummy
    PARAMETER (ALN2I=1.4426950D0, LocalTINY=1.D-5)

    LOGNB2=INT(LOG(REAL(N))*ALN2I+LocalTINY)
    M=N
    DO NN=1,LOGNB2
      M=M/2
      K=N-M
      DO J=1,K
        I=J
3       CONTINUE
        L=I+M
        RhklSearch = LocalRhkl(L,1)*RarVecO + &
           LocalRhkl(L,2)*RbrVecO+LocalRhkl(L,3)*RcrVecO    
        RhklCompare = LocalRhkl(I,1)*RarVecO + &
           LocalRhkl(I,2)*RbrVecO+LocalRhkl(I,3)*RcrVecO
        IF( DOT_PRODUCT(RhklSearch(:),RhklSearch(:)) .LT. &
              DOT_PRODUCT(RhklCompare(:),RhklCompare(:))) THEN
          DO ind=1,ITHREE
            dummy=LocalRhkl(I,ind)
            LocalRhkl(I,ind)=LocalRhkl(L,ind)
            LocalRhkl(L,ind)=dummy
          ENDDO
          I=I-M
          IF(I.GE.1) GOTO 3
        ENDIF
      ENDDO
    ENDDO
    
    RETURN

  END SUBROUTINE HKLSort
  
END MODULE setup_reflections_mod


