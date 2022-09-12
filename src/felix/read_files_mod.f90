!%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
!
! Felix
!
! Richard Beanland, Keith Evans & Rudolf A Roemer
!
! (C) 2013-19, all rights reserved
!
! Version: 2.0
! Date: 31-08-2022
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

MODULE read_files_mod

  IMPLICIT NONE
  PRIVATE
  PUBLIC :: ReadInpFile, ReadHklFile

  CONTAINS

  !>
  !! Procedure-description:
  !!
  !! Major-Authors: Keith Evans (2014), Richard Beanland (2016)
  !!
  SUBROUTINE ReadInpFile ( IErr )

    !?? this should contain clear input information and be well documented
    !?? github and other places should referance here

    USE MyNumbers
    USE message_mod

    ! global outputs, read from .inp
    USE IPARA, ONLY : IWriteFLAG, IScatterFactorMethodFLAG, IHolzFLAG, &
          IAbsorbFLAG, IByteSize, INhkl, INFrames, &
          IMinStrongBeams, IMinWeakBeams, IImageProcessingFLAG, &
          INoofUgs, IPrint, ISizeX, ISizeY
    USE RPARA, ONLY : RDebyeWallerConstant, RAbsorptionPercentage, RConvergenceAngle, &
          RZDirC_0, RXDirC_0, RNormDirC, RAcceleratingVoltage, RFrameAngle, &
          RInitialThickness, RFinalThickness, RDeltaThickness, RBlurRadius
    USE SPARA, ONLY : SPrintString
    ! global inputs
    USE IChannels, ONLY : IChInp
    USE SConst, ONLY : SAlphabet

    IMPLICIT NONE


    INTEGER(IKIND),INTENT(OUT) :: IErr
    INTEGER(IKIND) :: ILine, ind, IPos
    REAL(RKIND) :: ROfIter
    CHARACTER(200) :: SImageMode, SElements, SRefineMode, SStringFromNumber, SRefineYESNO, &
          SAtomicSites, SFormatString, SLengthofNumberString, &
          SDirectionX, SIncidentBeamDirection, SNormalDirectionX

    OPEN(UNIT= IChInp, IOSTAT=IErr, FILE= "felix.inp",STATUS= 'OLD')
    IF(l_alert(IErr,"ReadInpFile","OPEN() felix.inp")) RETURN
    ILine= 1

    ! There are six introductory comment lines which are ignored
    ILine= ILine+1; READ(IChInp,ERR=20,END=30,FMT='(A)')
    ILine= ILine+1; READ(IChInp,ERR=20,END=30,FMT='(A)')
    ILine= ILine+1; READ(IChInp,ERR=20,END=30,FMT='(A)')
    ILine= ILine+1; READ(IChInp,ERR=20,END=30,FMT='(A)') 
    ILine= ILine+1; READ(IChInp,ERR=20,END=30,FMT='(A)')
    ILine= ILine+1; READ(IChInp,ERR=20,END=30,FMT='(A)')

    !--------------------------------------------------------------------
    ! control flags
    !--------------------------------------------------------------------

    ! IWriteFLAG
    ILine= ILine+1; READ(IChInp,'(27X,I15.1)',ERR=20,END=30) IWriteFLAG
    ! IScatterFactorMethodFLAG
    ILine= ILine+1; READ(IChInp,'(27X,I15.1)',ERR=20,END=30) IScatterFactorMethodFLAG
    CALL message ( LXL, dbg7, "IScatterFactorMethodFLAG=",IScatterFactorMethodFLAG )
    ! IHolzFLAG
    ILine= ILine+1; READ(IChInp,'(27X,I15.1)',ERR=20,END=30) IHolzFLAG
    CALL message ( LXL, dbg3, "IHolzFLAG=",IHolzFLAG)
    ! IAbsorbFLAG
    ILine= ILine+1; READ(IChInp,'(27X,I15.1)',ERR=20,END=30) IAbsorbFLAG
    CALL message ( LXL, dbg3, "IAbsorbFLAG=",IAbsorbFLAG)
    ! IByteSize
    ILine= ILine+1; READ(IChInp,'(27X,I15.1)',ERR=20,END=30) IByteSize
    CALL message ( LXL, dbg3, "IByteSize=",IByteSize) ! depends on system, 8 for csc, 2 tinis

    !--------------------------------------------------------------------
    ! experimental settings
    !--------------------------------------------------------------------

    ! Two comment lines
    ILine= ILine+1; READ(IChInp,ERR=20,END=30,FMT='(A)')
    ILine= ILine+1; READ(IChInp,ERR=20,END=30,FMT='(A)')

    ! SNormalDirectionX -> INormalDirection
    ILine= ILine+1; READ(IChInp,FMT='(27X,A)',ERR=20,END=30) SNormalDirectionX
    CALL ThreeDimVectorReadIn(SNormalDirectionX,'[',']',RNormDirC)
    ! SIncidentBeamDirection -> IIncidentBeamDirection
    ILine= ILine+1; READ(IChInp,FMT='(27X,A)',END=30) SIncidentBeamDirection
    CALL ThreeDimVectorReadIn(SIncidentBeamDirection,'[',']',RZDirC_0)
    ! SDirectionX -> IXDirection
    ILine= ILine+1; READ(IChInp,FMT='(27X,A)',END=30) SDirectionX
    CALL ThreeDimVectorReadIn(SDirectionX,'[',']',RXDirC_0)
    ! RFrameAngle - the angular range of each frame, in degrees
    ILine= ILine+1; READ(IChInp,'(27X,F18.9)',ERR=20,END=30) RFrameAngle
    ! INFrames - the total number of frames
    ILine= ILine+1; READ(IChInp,'(27X,I15.1)',ERR=20,END=30) INFrames
    CALL message ( LXL, dbg3, "No. of frames =",INFrames)
    ! RConvergenceAngle - the half-convergence angle, in reciprocal Angstroms
    ILine= ILine+1; READ(IChInp,'(27X,F18.9)',ERR=20,END=30) RConvergenceAngle

    ! RAcceleratingVoltage
    ILine= ILine+1; READ(IChInp,'(27X,F18.9)',ERR=20,END=30) RAcceleratingVoltage

    !--------------------------------------------------------------------
    ! x and y dimensions of the simulation in pixels
    !--------------------------------------------------------------------

    ! Two comment lines
    ILine= ILine+1; READ(IChInp,ERR=20,END=30,FMT='(A)')
    ILine= ILine+1; READ(IChInp,ERR=20,END=30,FMT='(A)')
    ! ISizeX
    ILine= ILine+1; READ(IChInp,'(27X,I15.1)',ERR=20,END=30) ISizeX
    CALL message ( LXL, dbg3, "ISizeX=",ISizeX)

    !--------------------------------------------------------------------
    ! beam selection criteria
    !--------------------------------------------------------------------

    ! Two comment lines 
    ILine= ILine+1; READ(IChInp,ERR=20,END=30,FMT='(A)')
    ILine= ILine+1; READ(IChInp,ERR=20,END=30,FMT='(A)')
    ! INhkl
    ILine= ILine+1; READ(IChInp,'(27X,I15.1)',ERR=20,END=30) INhkl
    CALL message ( LXL, dbg3, "INhkl=",INhkl)
    ! IMinStrongBeams
    ILine= ILine+1; READ(IChInp,'(27X,I15.1)',ERR=20,END=30) IMinStrongBeams
    CALL message ( LXL, dbg3, "IMinStrongBeams=",IMinStrongBeams)
    ! IMinWeakBeams
    ILine= ILine+1
    READ(IChInp,'(27X,I15.1)',ERR=20,END=30) IMinWeakBeams
    CALL message ( LXL, dbg3, "IMinWeakBeams=",IMinWeakBeams)
    WRITE(SPrintString,FMT='(A19,I4,A19,I4,A13)') "Reflection pool of ",INhkl," with a minimum of ",IMinStrongBeams," strong beams"
    CALL message ( LS, SPrintString)

    !--------------------------------------------------------------------
    ! crystal settings
    !--------------------------------------------------------------------

    ! Two comment lines          
    ILine= ILine+1; READ(IChInp,ERR=20,END=30,FMT='(A)')
    ILine= ILine+1; READ(IChInp,ERR=20,END=30,FMT='(A)')
    ! RDebyeWallerConstant          ! default, if not specified in .cif
    ILine= ILine+1; READ(IChInp,'(27X,F18.9)',ERR=20,END=30) RDebyeWallerConstant
    ! RAbsorptionPercentage         ! for proportional model of absorption
    ILine= ILine+1; READ(IChInp,'(27X,F18.9)',ERR=20,END=30) RAbsorptionPercentage

    !--------------------------------------------------------------------
    ! Image Output Options
    !--------------------------------------------------------------------
    ! Two comment lines
    ILine= ILine+1; READ(IChInp,ERR=20,END=30,FMT='(A)')
    ILine= ILine+1; READ(IChInp,ERR=20,END=30,FMT='(A)')
    ! RInitialThickness
    ILine= ILine+1; READ(IChInp,'(27X,F18.9)',ERR=20,END=30) RInitialThickness
    ! RFinalThickness
    ILine= ILine+1; READ(IChInp,'(27X,F18.9)',ERR=20,END=30) RFinalThickness
    ! RDeltaThickness
    ILine= ILine+1; READ(IChInp,'(27X,F18.9)',ERR=20,END=30) RDeltaThickness
    ! RBlurRadius
    ILine= ILine+1; READ(IChInp,'(27X,F18.9)',ERR=20,END=30) RBlurRadius

    !--------------------------------------------------------------------
    ! finish reading, close felix.inp
    !--------------------------------------------------------------------
    
    CLOSE(IChInp, IOSTAT=IErr)
    IF(l_alert(IErr,"ReadInpFile","CLOSE() felix.inp")) RETURN
    RETURN

    !--------------------------------------------------------------------
    ! GOTO error handling from READ()
    !--------------------------------------------------------------------

    !	error in READ() detected  
 20 CONTINUE
    IErr=1
    WRITE(SPrintString,*) ILine
    IF(l_alert(IErr,"ReadInpFile",&
          "READ() felix.inp line number ="//TRIM(SPrintString))) RETURN
    
    !	EOF in READ() occured prematurely
 30 CONTINUE
    IErr=1
    WRITE(SPrintString,*) ILine
    IF(l_alert( IErr,"ReadInpFile",&
          "READ() felix.inp, premature end of file, line number =" // &
          TRIM(SPrintString) )) RETURN

  END SUBROUTINE ReadInpFile

  !!$%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  !>
  !! Procedure-description:
  !!
  !! Major-Authors: Keith Evans (2014), Richard Beanland (2016)
  !!
  SUBROUTINE ReadHklFile(IErr)

    USE MyNumbers
    USE message_mod

    ! global outputs
    USE RPARA, ONLY : RInputHKLs
    USE IPARA, ONLY : INoOfLacbedPatterns,IOutputReflections ! allocated here
    ! global inputs
    USE IChannels, ONLY : IChInp

    IMPLICIT NONE

    INTEGER(IKIND),INTENT(OUT) :: IErr
    INTEGER(IKIND) :: ILine, h, k, l, ind, IPos1, IPos2
    CHARACTER(200) :: dummy1, dummy2

    OPEN(Unit = IChInp,FILE="felix.hkl",STATUS='OLD',ERR=10)
    ILine = 0

    ! count the number of lines in felix.hkl:
    ! this is the number of reflections to output, INoOfLacbedPatterns
    DO
      READ(UNIT= IChInp, END=5, FMT='(a)') dummy1
      ILine = ILine+1
    ENDDO
5   INoOfLacbedPatterns = ILine
    CALL message ( LXL, dbg7, "Number of experimental images to load = ", INoOfLacbedPatterns)

    ALLOCATE(RInputHKLs(INoOfLacbedPatterns,ITHREE),STAT=IErr)
    IF(l_alert(IErr,"ReadHklFile","allocate RInputHKLs")) RETURN
    ALLOCATE(IOutputReflections(INoOfLacbedPatterns),STAT=IErr) !?? should we allocate here JR
    IF(l_alert(IErr,"ReadHklFile","allocate IOutputReflections")) RETURN

    ! read in the hkls
    REWIND(UNIT=IChInp) ! goes to beginning of felix.hkl file
    ILine = 0 
    DO ind = 1,INoOfLacbedPatterns
      ! READ HKL in as String
      READ(UNIT= IChInp,FMT='(A)' ) dummy1
      ! Scan String for h
      IPos1 = SCAN(dummy1,'[')
      IPos2 = SCAN(dummy1,',')
      dummy2 = dummy1((IPos1+1):(IPos2-1))
      READ(dummy2,'(I20)') h
      ! Scan String for k   
      IPos1 = SCAN(dummy1((IPos2+1):),',') + IPos2
      dummy2 = dummy1((IPos2+1):(IPos1-1))
      READ(dummy2,'(I20)') k
      ! Scan String for l     
      IPos2 = SCAN(dummy1((IPos1+1):),']') + IPos1
      dummy2 = dummy1((IPos1+1):(IPos2-1))
      READ(dummy2,'(I20)') l
      ! Convert to REALs
      ILine=ILine+1
      RInputHKLs(ILine,1) = REAL(h,RKIND)
      RInputHKLs(ILine,2) = REAL(k,RKIND)
      RInputHKLs(ILine,3) = REAL(l,RKIND)   
      CALL message ( LXL, dbg7, "RInputHKLs", NINT(RInputHKLs(ILine,:)) )
    END DO

    RETURN

 10 CONTINUE
    IErr=1
    CALL message( LL, "felix.hkl not found")
    RETURN

  END SUBROUTINE ReadHklFile


  !%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  !>
  !! Procedure-description: Function that reads in a 3D vector from a file,
  !! which has to have the form [I1,I2,I3] where I1,I2,I3 are Integers of any length.
  !! Used to read-in integer string vectors from felix.inp into real vectors 
  !!
  !! Major-Authors: Alexander Hubert (2015)
  !!
  SUBROUTINE ThreeDimVectorReadIn(SUnformattedVector,SOpenBracketDummy, &
        SCloseBracketDummy,RFormattedVector)

    ! e.g. CALL ThreeDimVectorReadIn(SIncidentBeamDirection,'[',']',RZDirC)

    USE MyNumbers
   
    IMPLICIT NONE

    CHARACTER(*), INTENT(IN) :: SUnformattedVector,SOpenBracketDummy,SCloseBracketDummy
    REAL(RKIND),INTENT(OUT),DIMENSION(3) :: RFormattedVector
    CHARACTER(1) :: SComma=',',SOpenBracket,SCloseBracket
    CHARACTER(100) :: SFormattedVectorX,SFormattedVectorY,SFormattedVectorZ   
    LOGICAL :: LBACK=.TRUE.   
    INTEGER(IKIND) :: &
          IOpenBracketPosition, ICloseBracketPosition, IFirstCommaPosition, &
          ILastCommaPosition
    
    ! Trim and adjustL bracket to ensure one character string
    SOpenBracket=TRIM(ADJUSTL(SOpenBracketDummy))
    SCloseBracket=TRIM(ADJUSTL(SCloseBracketDummy))
    
    ! Read in string to for the incident beam direction, convert these
    ! to x,y,z coordinate integers with string manipulation
    
    IOpenBracketPosition=INDEX(SUnformattedVector,SOpenBracket)
    ICloseBracketPosition=INDEX(SUnformattedVector,SCloseBracket)
    IFirstCommaPosition=INDEX(SUnformattedVector,SComma)
    ILastCommaPosition=INDEX(SUnformattedVector,SComma,LBACK)

    ! Separate the Unformatted Vector String into its three X,Y,Z components
    SFormattedVectorX = & 
          TRIM(ADJUSTL(SUnformattedVector(IOpenBracketPosition+1:IFirstCommaPosition-1)))
    SFormattedVectorY = &
          TRIM(ADJUSTL(SUnformattedVector(IFirstCommaPosition+1:ILastCommaPosition-1)))
    SFormattedVectorZ = &
          TRIM(ADJUSTL(SUnformattedVector(ILastCommaPosition+1:ICloseBracketPosition-1)))

    ! Read each string component into its associated position in real variable RFormattedVector
    READ(SFormattedVectorX,*) RFormattedVector(1)
    READ(SFormattedVectorY,*) RFormattedVector(2)
    READ(SFormattedVectorZ,*) RFormattedVector(3)

  END SUBROUTINE ThreeDimVectorReadIn

END MODULE read_files_mod
