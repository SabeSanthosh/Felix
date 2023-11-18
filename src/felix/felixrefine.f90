!%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
!
! Felix
!
! Richard Beanland, Keith Evans & Rudolf A Roemer
!
! (C) 2013-19, all rights reserved
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
!%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

!>
!! felixrefine
!!
PROGRAM Felixrefine
  
  USE MyNumbers
  USE message_mod
  USE MPI
  USE MyMPI
  USE read_files_mod
  USE read_cif_mod
  USE set_scatter_factors_mod
  USE setup_reflections_mod
  USE setup_space_group_mod
  USE crystallography_mod
  USE ug_matrix_mod
  USE bloch_mod
  USE write_output_mod

  USE IConst; USE RConst; USE SConst
  USE IPara;  USE RPara;  USE CPara; USE SPara;
  USE IChannels

  ! local variable definitions
  IMPLICIT NONE
 
  INTEGER(IKIND) :: IErr,ind,jnd,knd,lnd,mnd,IStartTime
  INTEGER(4) :: IErr4
  REAL(RKIND) :: RGOutLimit,RgPoolLimit

  CHARACTER(40) :: my_rank_string
  CHARACTER(200) :: path,subpath,subsubpath

  !--------------------------------------------------------------------
  ! startup
  !--------------------------------------------------------------------

  ! initialise constants
  CALL Init_Numbers ! constants for calculations
  CALL InitialiseMessage ! constants required for formatted terminal output
  IErr=0

  ! MPI initialization
  CALL MPI_Init(IErr4) 
  IF(l_alert(INT(REAL(IErr4)),"felixrefine","MPI_Init")) CALL abort
  CALL MPI_Comm_rank(MPI_COMM_WORLD,my_rank,IErr4) ! get rank of the current process
  IF(l_alert(INT(REAL(IErr4)),"felixrefine","MPI_Comm_rank")) CALL abort
  CALL MPI_Comm_size(MPI_COMM_WORLD,p,IErr4) ! get size of the current communicator
  IF(l_alert(INT(REAL(IErr4)),"felixrefine","MPI_Comm_size")) CALL abort

  ! startup terminal output
  CALL message(LS,"-----------------------------------------------------------------")
  INCLUDE "version.txt"
!!$#ifdef git
!!$  CALL message(LS,"felixrefine: ", TRIM("GITVERSION"))
!!$  CALL message(LS,"             ", TRIM("GITBRANCH"))
!!$  CALL message(LS,"             ", TRIM("COMPILED"))
!!$#else
!!$  CALL message(LS,"felixrefine: ", "see https://github.com/WarwickMicroscopy/Felix for version")
!!$#endif
  CALL message(LS,"-----------------------------------------------------------------")
  CALL message(LS,"total number of MPI ranks ", p, ", screen messages via rank", my_rank)
  CALL message(LS,"-----------------------------------------------------------------")

  ! timing setup
  CALL SYSTEM_CLOCK( IStartTime,IClockRate )

  !--------------------------------------------------------------------
  ! input section 
  !--------------------------------------------------------------------

  CALL read_cif(IErr) ! felix.cif ! some allocations are here
  IF(l_alert(IErr,"felixrefine","ReadCif")) CALL abort

!  CALL ReadHklFile(IErr) ! the list of hkl's to input/output
!  IF(l_alert(IErr,"felixrefine","ReadHklFile")) CALL abort
  !--------------------------------------------------------------------
  ! allocations for arrays to track frame simulations
!  ALLOCATE(IhklsFrame(INoOfHKLsAll),STAT=IErr) ! Legacy list
!  IF(l_alert(IErr,"felixrefine","allocate IhklsFrame")) CALL abort
!  ALLOCATE(IhklsAll(INoOfHKLsAll),STAT=IErr)! List for full sim
!  IF(l_alert(IErr,"felixrefine","allocate IhklsAll")) CALL abort
!  ALLOCATE(ILiveList(INoOfHKLsAll),STAT=IErr)! List of current output reflections
!  IF(l_alert(IErr,"felixrefine","allocate ILiveList")) CALL abort
!  ALLOCATE(ILACBEDList(INoOfHKLsAll),STAT=IErr)! List of current output containers
!  IF(l_alert(IErr,"felixrefine","allocate ILACBEDList")) CALL abort
  !output tracking flags
!  ILiveList = 0 ! links reflections, see write_outputs for all meanings of this flag
!  ILACBEDList = 0! links a simulation to its output container
!  ILACBEDFlag = 0! indicated whether a container is available (0) or in use (1)

  CALL ReadInpFile(IErr) ! felix.inp
  IF(l_alert(IErr,"felixrefine","ReadInpFile")) CALL abort
  CALL SetMessageMode( IWriteFLAG, IErr )
  IF(l_alert(IErr,"felixrefine","set_message_mod_mode")) CALL abort

  !--------------------------------------------------------------------
  ! Set up output folders: frames, then thicknesses
  !--------------------------------------------------------------------
  IThicknessCount= NINT((RFinalThickness-RInitialThickness)/RDeltaThickness) + 1
  IF (my_rank.EQ.0) THEN
    path = SChemicalFormula(1:ILN)  ! main folder has chemical formula as name
    CALL system('mkdir ' // TRIM(ADJUSTL(path)))
    ! Simulated frames
    WRITE(subpath, FMT="(A,A12)") TRIM(ADJUSTL(path)), "/Simulations"
    CALL system('mkdir ' // TRIM(ADJUSTL(subpath)))
    subpath = ""  !not sure if I need this, but getting some odd behaviour
    ! Folders per frame
!    DO knd = 1,INFrames
!      IF (knd.LT.10) THEN
!        WRITE(subpath, FMT="(A,A3,I1)") TRIM(ADJUSTL(path)), "/F_", knd
!      ELSE IF(knd.LT.100) THEN
!        WRITE(subpath, FMT="(A,A3,I2)") TRIM(ADJUSTL(path)), "/F_", knd
!      ELSE IF(knd.LT.1000) THEN
!        WRITE(subpath, FMT="(A,A3,I3)") TRIM(ADJUSTL(path)), "/F_", knd
!      ELSE
!        WRITE(subpath, FMT="(A,A3,I4)") TRIM(ADJUSTL(path)), "/F_", knd
!      END IF
!      PRINT*,knd,subpath
!      CALL system('mkdir ' // TRIM(ADJUSTL(subpath)))
!      DO ind = 1,IThicknessCount
!        jnd = NINT(RInitialThickness +(ind-1)*RDeltaThickness)/10.0!in nm
!        WRITE(subsubpath, FMT="(A,A,I4,A2)") TRIM(ADJUSTL(subpath)), "/", jnd, "nm"
!        CALL system('mkdir ' // TRIM(ADJUSTL(subsubpath)))
!      END DO
!    END DO
  END IF

  !--------------------------------------------------------------------
  ! set up scattering factors, k-space resolution
  !--------------------------------------------------------------------
  CALL SetScatteringFactors(IScatterFactorMethodFLAG,IErr)
  IF(l_alert(IErr,"felixrefine","SetScatteringFactors")) CALL abort
  ! returns global RScattFactors depending upon scattering method: Kirkland, Peng, etc.

  ! Calculate wave vector magnitude k and relativistic mass
  ! Electron Velocity in metres per second
  RElectronVelocity = &
        RSpeedOfLight*SQRT( ONE - ((RElectronMass*RSpeedOfLight**2) / &
        (RElectronCharge*RAcceleratingVoltage*THOUSAND+RElectronMass*RSpeedOfLight**2))**2 )
  ! Electron WaveLength in Angstroms
  RElectronWaveLength = RPlanckConstant / &
        (  SQRT(TWO*RElectronMass*RElectronCharge*RAcceleratingVoltage*THOUSAND) * &
        SQRT( ONE + (RElectronCharge*RAcceleratingVoltage*THOUSAND) / &
        (TWO*RElectronMass*RSpeedOfLight**2) )  ) * RAngstromConversion
  ! NB --- k=2pi/lambda and exp(i*k.r), physics convention, in reciprocal Angstroms
  RElectronWaveVectorMagnitude = TWOPI/RElectronWaveLength
  !resolution in k-space N.B. in cRED we define convergence angle as half the y-size
  RDeltaK = TWOPI*DEG2RADIAN*RFrameAngle/(RElectronWaveLength*REAL(ISizeX,RKIND))
  ! y-dimension of simulation, taking the input RConvergenceAngle as half-convergence angle
  ISizeY = NINT(TWOPI*TWO*RConvergenceAngle/RDeltaK)
  WRITE(SPrintString, FMT='(A11,I3,1x,A2,I3,A7)') "Simulation ",ISizeX,"x ",ISizeY," pixels"
  CALL message(LS,SPrintString)
  RRelativisticCorrection = ONE/SQRT( ONE - (RElectronVelocity/RSpeedOfLight)**2 )
  RRelativisticMass = RRelativisticCorrection*RElectronMass
  !conversion from Vg to Ug, h^2/(2pi*m0*e), see e.g. Kirkland eqn. C.5
  RScattFacToVolts = (RPlanckConstant**2)*(RAngstromConversion**2)/&
  (TWOPI*RElectronMass*RElectronCharge*RVolume)

  !--------------------------------------------------------------------
  ! allocations for the cRED frame series, INFrames & INhkl
  !--------------------------------------------------------------------
  ! List of g-vectors in the beam pool for each frame
  ALLOCATE(IgPoolList(INhkl,INFrames),STAT=IErr)
  IF(l_alert(IErr,"felixrefine","allocate IgPoolList")) CALL abort
  ! List of Sg for each g in the beam pool for each frame
  ALLOCATE(RgPoolSg(INhkl,INFrames),STAT=IErr)
  IF(l_alert(IErr,"felixrefine","allocate IgPoolList")) CALL abort
  ! Indices of g-vectors in IgPoolList to be output in each frame,
  ! decided by RGOutLimit
  ALLOCATE(IgOutList(INhkl,INFrames),STAT=IErr)
  IF(l_alert(IErr,"felixrefine","allocate IgOutList")) CALL abort

  !--------------------------------------------------------------------
  ! fill unit cell from basis and symmetry, then remove duplicates at special positions
  ! Mean inner potential & wavevector inside the crystal RBigK are also calculated here
  CALL UniqueAtomPositions(IErr)  ! in crystallography.f90
  IF(l_alert(IErr,"felixrefine","UniqueAtomPositions")) CALL abort

  !--------------------------------------------------------------------
  ! From the unit cell we produce RaVecO, RbVecO, RcVecO in an orthogonal reference frame O
  ! with xO // a and zO perpendicular to the ab plane, in Angstrom units
  ! and reciprocal lattice vectors RarVecO, RbrVecO, RcrVecO in the same reference frame
  ! Outer limit of g pool  ***This parameter will probably end up in a modified .inp file***
  RgPoolLimit = TWO*TWOPI  ! reciprocal Angstroms, multiplied by 2pi
  ! Deviation parameter limit, a reflection closer to Ewald than this is in the beam pool
  RDevLimit = 0.01*TWOPI  ! reciprocal Angstroms, multiplied by 2pi
  ! Output limit
  RGOutLimit = ONE*TWOPI  ! reciprocal Angstroms, multiplied by 2pi
  ! Make the reciprocal lattice
  WRITE(SPrintString, FMT='(A33,F5.2,A5)') "Reciprocal lattice defined up to ",&
          RgPoolLimit/TWOPI," A^-1"
  CALL message(LS,SPrintString)
  ! reciprocal vectors first - gives the size of the reciprocal lattice to be calculated
  CALL ReciprocalVectors(RgPoolLimit, IErr)  ! in crystallography.f90
  ! IhklLattice is the list of Miller indices for the full 3D lattice
  ! RgLatticeO is the corresponding list of coordinates in reciprocal space
  ! maximum a*,b*,c* limit is determined by the G magnitude limit
  ALLOCATE(IhklLattice(InLattice, ITHREE), STAT=IErr)! Miller indices
  ALLOCATE(RgLatticeO(InLattice, ITHREE), STAT=IErr)! g-vector
  ALLOCATE(RgMagLattice(InLattice), STAT=IErr)! magnitude
  ALLOCATE(CFgLattice(InLattice), STAT=IErr)! Structure factors
  ALLOCATE(Isort(InLattice), STAT=IErr)! Sorted index

  CALL ReciprocalLattice(RgPoolLimit, IErr)  ! in crystallography.f90

  IF(l_alert(IErr,"felixrefine","ReciprocalLattice")) CALL abort
  WRITE(SPrintString, FMT='(A24,F5.2,A5)') "Experimental resolution ",&
          RgOutLimit/TWOPI," A^-1"
  CALL message(LS,SPrintString)
  ! List the hkl's in each frame
  CALL HKLMake(RDevLimit, RGOutLimit, IErr)  ! in setup_reflections.f90
  IF(l_alert(IErr,"felixrefine","HKLMake")) CALL abort
  ! List the unique g's and make reduced arrays before deleting the reciprocal lattice to save memory
  CALL HKLList(IErr)
  IF(l_alert(IErr,"felixrefine","HKLList")) CALL abort
  ! Delete the reciprocal lattice
  DEALLOCATE(Isort,RgLatticeO,RgMagLattice,CFgLattice,IhklLattice)  
  !--------------------------------------------------------------------
    
    CALL PrintEndTime( LS, IStartTime, "Frame" )
    !CALL message(LS,dbg7,"Rhkl matrix: ",NINT(IgPoolList(ind,1:INhkl,:)))

    !--------------------------------------------------------------------
    ! sort hkl in descending order of magnitude (not sure this is needed, really)
!    CALL HKLSort(Rhkl,INhkl,IErr) 
!    IF(l_alert(IErr,"felixrefine","SortHKL")) CALL abort
    ! Assign numbers to different reflections -> IhklsFrame, IhklsAll, INoOfHKLsFrame
!    CALL HKLList(ind, IErr)
!    IF(l_alert(IErr,"felixrefine","SpecificReflectionDetermination")) CALL abort

  !--------------------------------------------------------------------
  ! Allocations for the Bloch wave calculation
  ! RgPool is a list of g-vectors in the microscope ref frame,
  ! units of 1/A (NB exp(-i*q.r),  physics negative convention)
!  ALLOCATE(RgPool(INhkl,ITHREE),STAT=IErr)
!  IF(l_alert(IErr,"felixrefine","allocate RgPool")) CALL abort
  ! g-vector magnitudes
  ! in reciprocal Angstrom units, in the Microscope reference frame
!  ALLOCATE(RgPoolMag(INhkl),STAT=IErr)
!  IF(l_alert(IErr,"felixrefine","allocate RgPoolMag")) CALL abort
  ! g-vector components parallel to the surface unit normal
!  ALLOCATE(RgDotNorm(INhkl),STAT=IErr)
!  IF(l_alert(IErr,"felixrefine","allocate RgDotNorm")) CALL abort
  ! Matrix of 2pi*g-vectors that corresponds to the Ug matrix
!  ALLOCATE(RgMatrix(INhkl,INhkl,ITHREE),STAT=IErr)
!  IF(l_alert(IErr,"felixrefine","allocate RgMatrix")) CALL abort
  ! NB Rhkl are in INTEGER form [h,k,l] but are REAL to allow dot products etc.
!  ALLOCATE(Rhkl(INhkl,ITHREE),STAT=IErr)
!  IF(l_alert(IErr,"felixrefine","allocate Rhkl")) CALL abort
  ! Deviation parameter for each hkl
!  ALLOCATE(RDevPara(INhkl),STAT=IErr)
  ! what's this deviation parameter for?
!  ALLOCATE(RDevC(INhkl),STAT=IErr)
!  IF(l_alert(IErr,"felixrefine","allocate RDevC")) CALL abort
  ! allocate Ug arrays
!  ALLOCATE(CUgMatNoAbs(INhkl,INhkl),STAT=IErr)! Ug Matrix without absorption
!  IF(l_alert(IErr,"felixrefine","allocate CUgMatNoAbs")) CALL abort
!  ALLOCATE(CUgMatPrime(INhkl,INhkl),STAT=IErr)! U'g Matrix of just absorption
!  IF(l_alert(IErr,"felixrefine","allocate CUgMatPrime")) CALL abort
!  ALLOCATE(CUgMat(INhkl,INhkl),STAT=IErr)! Ug+U'g Matrix, including absorption
!  IF(l_alert(IErr,"felixrefine","allocate CUgMat")) CALL abort
  ! Matrix with numbers marking equivalent Ug's
!  ALLOCATE(ISymmetryRelations(INhkl,INhkl),STAT=IErr)
!  IF(l_alert(IErr,"felixrefine","allocate ISymmetryRelations")) CALL abort
  !--------------------------------------------------------------------
  ! ImageInitialisation
  !--------------------------------------------------------------------
!  IPixelTotal = ISizeX*ISizeY
!  ALLOCATE(IPixelLocation(IPixelTotal,2),STAT=IErr)
!  IF(l_alert(IErr,"felixrefine","allocate IPixelLocation")) CALL abort
  ! we keep track of where a calculation goes in the image using the
  ! IPixelLocation array.  Remember fortran indexing is [row,col]=[y,x]
!  lnd = 0
!  DO ind = 1,ISizeY
!    DO jnd = 1,ISizeX
!      lnd = lnd + 1
!      IPixelLocation(lnd,1) = ind
!      IPixelLocation(lnd,2) = jnd
!    END DO
!  END DO

  !--------------------------------------------------------------------
  ! finish off: deallocations for variables used in all frames
  !--------------------------------------------------------------------
  DEALLOCATE(IgPoolList,STAT=IErr)
  DEALLOCATE(RgPoolSg,STAT=IErr)
  DEALLOCATE(IgOutList,STAT=IErr)
  DEALLOCATE(RgPoolMag,STAT=IErr)
  DEALLOCATE(RgPool,STAT=IErr)
  DEALLOCATE(RgMatrix,STAT=IErr)
  DEALLOCATE(RgDotNorm,STAT=IErr)
  DEALLOCATE(Rhkl,STAT=IErr)
  DEALLOCATE(CUgMat,STAT=IErr)
  DEALLOCATE(CUgMatNoAbs,STAT=IErr)
  DEALLOCATE(CUgMatPrime,STAT=IErr)
  DEALLOCATE(ISymmetryRelations,STAT=IErr)
  DEALLOCATE(RAtomXYZ,STAT=IErr)
  DEALLOCATE(SAtomName,STAT=IErr)
  DEALLOCATE(SAtomLabel,STAT=IErr)
  DEALLOCATE(RIsoDW,STAT=IErr)
  DEALLOCATE(ROccupancy,STAT=IErr)
  DEALLOCATE(IAtomicNumber,STAT=IErr)
  DEALLOCATE(IAnisoDW,STAT=IErr)
  DEALLOCATE(RAtomCoordinate,STAT=IErr)
  DEALLOCATE(IPixelLocation,STAT=IErr)
  CLOSE(IChOutRC,IOSTAT=IErr)
  CLOSE(IChOutIhkl,IOSTAT=IErr)

  CALL message( LS, "--------------------------------" )
  CALL PrintEndTime( LS, IStartTime, "Calculation" )
  CALL message( LS, "--------------------------------")
  CALL message( LS, "||||||||||||||||||||||||||||||||")
  
  ! clean shutdown
  CALL MPI_Finalize(IErr)
  STOP
  
!%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
!%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
!%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  CONTAINS

  SUBROUTINE abort
    IErr=1
    IF(l_alert(IErr,"felixrefine","ABORTING")) CONTINUE
    CALL MPI_Abort(MPI_COMM_WORLD,1,IErr)
    STOP
  END SUBROUTINE abort


  SUBROUTINE BlurG(RImageToBlur,IPixX,IPixY,RBlurringRadius,IErr)

    USE MyNumbers
    USE MPI
    USE message_mod

    IMPLICIT NONE

    REAL(RKIND),DIMENSION(IPixX,IPixY),INTENT(INOUT) :: RImageToBlur
    INTEGER(IKIND),INTENT(IN) :: IPixX,IPixY
    REAL(RKIND),INTENT(IN) :: RBlurringRadius
    INTEGER(IKIND),INTENT(OUT) :: IErr

    REAL(RKIND),DIMENSION(IPixX,IPixY) :: RTempImage,RShiftImage
    INTEGER(IKIND) :: ind,jnd,IKernelRadius,IKernelSize
    REAL(RKIND),DIMENSION(:), ALLOCATABLE :: RGauss1D
    REAL(RKIND) :: Rind,Rsum,Rmin,Rmax

    ! get min and max of input image
    Rmin=MINVAL(RImageToBlur)
    Rmax=MAXVAL(RImageToBlur)

    ! set up a 1D kernel of appropriate size  
    IKernelRadius=NINT(3*RBlurringRadius)
    ALLOCATE(RGauss1D(2*IKernelRadius+1),STAT=IErr)!ffs
    Rsum=0
    DO ind=-IKernelRadius,IKernelRadius
      Rind=REAL(ind)
      RGauss1D(ind+IKernelRadius+1)=EXP(-(Rind**2)/(2*(RBlurringRadius**2)))
      Rsum=Rsum+RGauss1D(ind+IKernelRadius+1)
      IF(ind==0) IErr=78 
    END DO
    RGauss1D=RGauss1D/Rsum!normalise
    RTempImage=RImageToBlur*0_RKIND !reset the temp image 

    ! apply the kernel in direction 1
    DO ind = -IKernelRadius,IKernelRadius
       IF (ind.LT.0) THEN
          RShiftImage(1:IPixX+ind,:)=RImageToBlur(1-ind:IPixX,:)
          DO jnd = 1,1-ind!edge fill on right
             RShiftImage(IPixX-jnd+1,:)=RImageToBlur(IPixX,:)
          END DO
       ELSE
          RShiftImage(1+ind:IPixX,:)=RImageToBlur(1:IPixX-ind,:)
          DO jnd = 1,1+ind!edge fill on left
             RShiftImage(jnd,:)=RImageToBlur(1,:)
          END DO
       END IF
       RTempImage=RTempImage+RShiftImage*RGauss1D(ind+IKernelRadius+1)
    END DO

    ! make the 1D blurred image the input for the next direction
    RImageToBlur=RTempImage
    RTempImage=RImageToBlur*0_RKIND ! reset the temp image

    ! apply the kernel in direction 2  
    DO ind = -IKernelRadius,IKernelRadius
       IF (ind.LT.0) THEN
          RShiftImage(:,1:IPixY+ind)=RImageToBlur(:,1-ind:IPixY)
          DO jnd = 1,1-ind!edge fill on bottom
             RShiftImage(:,IPixY-jnd+1)=RImageToBlur(:,IPixY)
          END DO
       ELSE
          RShiftImage(:,1+ind:IPixY)=RImageToBlur(:,1:IPixY-ind)
          DO jnd = 1,1+ind!edge fill on top
             RShiftImage(:,jnd)=RImageToBlur(:,1)
          END DO
       END IF
       RTempImage=RTempImage+RShiftImage*RGauss1D(ind+IKernelRadius+1)
    END DO
    DEALLOCATE(RGauss1D,STAT=IErr)

    ! set intensity range of output image to match that of the input image
    RTempImage=RTempImage-MINVAL(RTempImage)
    RTempImage=RTempImage*(Rmax-Rmin)/MAXVAL(RTempImage)+Rmin
    ! return the blurred image
    RImageToBlur=RTempImage;

  END SUBROUTINE BlurG    

END PROGRAM Felixrefine

