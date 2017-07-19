!%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
!
! Felix
!
! Richard Beanland, Keith Evans & Rudolf A Roemer
!
! (C) 2013-17, all rights reserved
!
! Version: :VERSION:
! Date:    :DATE:
! Time:    :TIME:
! Status:  :RLSTATUS:
! Build:   :BUILD:
! Author:  :AUTHOR:
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

! Conatained in this file below:
! ReciprocalLattice()
! UniqueAtomPositions()


!>
!! Procedure-description: Creates reciprocal lattice vectors in Microscope
!! reference frame. This involves transforms between the orthogonal, crystal
!! and microscopic frame. 
!!
!! Major-Authors: Keith Evans (2014), Richard Beanland (2016)
!!
SUBROUTINE ReciprocalLattice(IErr)
   
  USE MyNumbers
  USE WriteToScreen
  
  USE RPara; USE IPara; USE SPara
  
  USE MPI
  USE MyMPI
  
  IMPLICIT NONE

  INTEGER(IKIND) :: IErr,ind
  REAL(RKIND) :: RTTest
  REAL(RKIND), DIMENSION(ITHREE) :: RXDirO, RYDirO, RZDirO, RYDirC
  REAL(RKIND), DIMENSION(ITHREE,ITHREE) :: RTMatC2O,RTMatO2M
  CHARACTER*50 indString
  CHARACTER*400  RTMatString

  !Crystal Lattice Vectors: orthogonal reference frame in Angstrom units
  RaVecO(1)= RLengthX
  RaVecO(2)= ZERO
  RaVecO(3)= ZERO

  RbVecO(1)= RLengthY*COS(RGamma)
  RbVecO(2)= RLengthY*SIN(RGamma)
  RbVecO(3)= ZERO

  RcVecO(1)= RLengthZ*COS(RBeta)
  RcVecO(2)= RLengthZ*(COS(RAlpha)-COS(RBeta)*COS(RGamma))/SIN(RGamma)
  RcVecO(3)= RLengthZ*(SQRT(1.D0-COS(RAlpha)*COS(RAlpha)-COS(RBeta)*COS(RBeta)&
    -COS(RGamma)*COS(RGamma)+TWO*COS(RAlpha)*COS(RBeta)*COS(RGamma)) / SIN(RGamma))

  IF(IVolumeFLAG .EQ. 0) THEN
     RVolume= RLengthX*RLengthY*RLengthZ* &
          SQRT(1.0D0 - &
          COS(RAlpha)*COS(RAlpha)-COS(RBeta)*COS(RBeta)-COS(RGamma)*COS(RGamma) + &
          TWO*COS(RAlpha)*COS(RBeta)*COS(RGamma))
  END IF

  IF(IDiffractionFLAG.EQ.0) THEN  
     RTTest = DOT_PRODUCT(RaVecO/DOT_PRODUCT(RaVecO,RaVecO),RbVecO/DOT_PRODUCT(RbVecO,RbVecO))*&
          DOT_PRODUCT(RbVecO/DOT_PRODUCT(RbVecO,RbVecO),RcVecO/DOT_PRODUCT(RcVecO,RcVecO))*&
          DOT_PRODUCT(RcVecO/DOT_PRODUCT(RcVecO,RcVecO),RaVecO/DOT_PRODUCT(RaVecO,RaVecO))
     
     IF(SCAN(SSpaceGroupName,'rR').NE.0) THEN
        IF(ABS(RTTest).LT.TINY) THEN
           SSpaceGroupName = TRIM(ADJUSTL("V"))
           !Crystal is either Obverse or Reverse
           !Selection Rules are not in place to determine the difference, assume the crystal is Obverse")
        ELSE
           SSpaceGroupName=TRIM(ADJUSTL('P'))
           !Primitive setting (Rhombohedral axes)
        END IF
     END IF
  END IF
  ! Set up Reciprocal Lattice Vectors: orthogonal reference frame in 1/Angstrom units
  ! RarDirO,RbrDirO,RcrDirO vectors are reciprocal lattice vectors 2pi/a, 2pi/b, 2pi/c in an orthogonal frame
  ! Note that reciprocal lattice vectors have two pi included, we are using the physics convention exp(i*g.r)
  RarVecO= TWOPI*CROSS(RbVecO,RcVecO)/DOT_PRODUCT(RbVecO,CROSS(RcVecO,RaVecO))
  RbrVecO= TWOPI*CROSS(RcVecO,RaVecO)/DOT_PRODUCT(RcVecO,CROSS(RaVecO,RbVecO))
  RcrVecO= TWOPI*CROSS(RaVecO,RbVecO)/DOT_PRODUCT(RaVecO,CROSS(RbVecO,RcVecO))

  DO ind=1,ITHREE
     IF (abs(RarVecO(ind)).lt.TINY) THEN
        RarVecO(ind) = ZERO
     END IF
     IF (abs(RbrVecO(ind)).lt.TINY) THEN
        RbrVecO(ind) = ZERO
     END IF
     IF (abs(RcrVecO(ind)).lt.TINY) THEN
        RcrVecO(ind) = ZERO
     END IF
  ENDDO

  ! RTmat transforms from crystal (implicit units)to orthogonal reference frame (Angstrom units)
  RTMatC2O(:,1)= RaVecO(:)
  RTMatC2O(:,2)= RbVecO(:)
  RTMatC2O(:,3)= RcVecO(:)
  
  ! RXDirC,RYDirC,RZDirC vectors are the reciprocal lattice vectors that define the x-axis of the
  ! diffraction pattern and the beam direction, they are given in felix.inp
  ! RXDirO,RYDirO,RZDirO vectors are UNIT reciprocal lattice vectors parallel to the above in an orthogonal frame
  RXDirO= RXDirC(1)*RarVecO + RXDirC(2)*RbrVecO + RXDirC(3)*RcrVecO
  RXDirO= RXDirO/SQRT(DOT_PRODUCT(RXDirO,RXDirO))
  RZDirO= RZDirC(1)*RaVecO + RZDirC(2)*RbVecO + RZDirC(3)*RcVecO
  RZDirO= RZDirO/SQRT(DOT_PRODUCT(RZDirO,RZDirO))
  RYDirO= CROSS(RZDirO,RXDirO)

  ! RTmatO2M transforms from orthogonal to microscope reference frame
  RTMatO2M(1,:)= RXDirO(:)
  RTMatO2M(2,:)= RYDirO(:)
  RTMatO2M(3,:)= RZDirO(:)
  
  !Unit normal to the specimen in real space
  !This is used in diffraction pattern calculation subroutine
  RNormDirM = MATMUL(RTMatO2M,MatMUL(RTMatC2O,RNormDirC))
  RNormDirM = RNormDirM/SQRT(DOT_PRODUCT(RNormDirM,RNormDirM)) 

  ! now transform from crystal reference frame to orthogonal and then to microscope frame

  ! RaVecM, RbVecM, RbVecM unit cell vectors in Angstrom units in the microscope frame
  RaVecM= MATMUL(RTMatO2M,RaVecO)
  RbVecM= MATMUL(RTMatO2M,RbVecO)
  RcVecM= MATMUL(RTMatO2M,RcVecO)
  
  ! create new set of reciprocal lattice vectors in Microscope reference frame
  ! Note that reciprocal lattice vectors dot have two pi included, we are using the optical convention exp(i*g.r)
  RarVecM= TWOPI*CROSS(RbVecM,RcVecM)/DOT_PRODUCT(RbVecM,CROSS(RcVecM,RaVecM))
  RbrVecM= TWOPI*CROSS(RcVecM,RaVecM)/DOT_PRODUCT(RcVecM,CROSS(RaVecM,RbVecM))
  RcrVecM= TWOPI*CROSS(RaVecM,RbVecM)/DOT_PRODUCT(RaVecM,CROSS(RbVecM,RcVecM))
  
END SUBROUTINE ReciprocalLattice

!%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%



!>
!! Procedure-description: Calculates the FULL set of possible fractional atomic positions
!! and then gets rid of duplicates
!!
!! Major-Authors: Keith Evans (2014), Richard Beanland (2016, 2017)
!!
SUBROUTINE UniqueAtomPositions(IErr)
  
  USE WriteToScreen
  USE MyNumbers
  
  USE CConst; USE IConst
  USE IPara; USE RPara; USE SPara
  USE IChannels
  
  USE MyMPI
  
  IMPLICIT NONE
  
  INTEGER(IKIND) :: IErr,ind,jnd,knd
  INTEGER(IKIND), DIMENSION(:), ALLOCATABLE :: IAllAtomicNumber, RAllAnisoDW
  REAL(RKIND), DIMENSION(:,:), ALLOCATABLE :: RAllAtomPosition
  REAL(RKIND), DIMENSION(:), ALLOCATABLE :: RAllOccupancy, RAllIsoDW
  LOGICAL :: Lunique
  CHARACTER*2, DIMENSION(:), ALLOCATABLE :: SAllAtomName 
  CHARACTER*5, DIMENSION(:), ALLOCATABLE :: SAllAtomLabel 
  CHARACTER*100 SPrintString
  
  !All atom positions generated by symmetry, including duplicates
  ALLOCATE(RAllAtomPosition(SIZE(RSymVec,1)*SIZE(RBasisAtomPosition,1),ITHREE),STAT=IErr)  
  ALLOCATE(SAllAtomName(SIZE(RSymVec,1)*SIZE(RBasisAtomPosition,1)),STAT=IErr)  
  ALLOCATE(SAllAtomLabel(SIZE(RSymVec,1)*SIZE(RBasisAtomPosition,1)),STAT=IErr)  
  ALLOCATE(RAllOccupancy(SIZE(RSymVec,1)*SIZE(RBasisAtomPosition,1)),STAT=IErr)  
  ALLOCATE(RAllIsoDW(SIZE(RSymVec,1)*SIZE(RBasisAtomPosition,1)),STAT=IErr)  
  ALLOCATE(IAllAtomicNumber(SIZE(RSymVec,1)*SIZE(RBasisAtomPosition,1)),STAT=IErr)  
  ALLOCATE(RAllAnisoDW(SIZE(RSymVec,1)*SIZE(RBasisAtomPosition,1)),STAT=IErr)  
  IF( IErr.NE.0 ) THEN
     PRINT*,"UniqueAtomPositions(",my_rank,")error in allocations"
     RETURN
  END IF
 
  !Apply symmetry elements to generate all equivalent positions 
  knd=1
  DO ind=1, SIZE(RSymVec,1)  
    DO jnd=1, SIZE(RBasisAtomPosition,1)
      RAllAtomPosition(knd,:)= MATMUL(RSymMat(ind,:,:),RBasisAtomPosition(jnd,:)) &
             + RSymVec(ind,:)
      SAllAtomLabel(knd) = SBasisAtomLabel(jnd)
      SAllAtomName(knd) = SBasisAtomName(jnd)
      RAllOccupancy(knd) = RBasisOccupancy(jnd)
      RAllIsoDW(knd) = RBasisIsoDW(jnd)
      IAllAtomicNumber(knd) = IBasisAtomicNumber(jnd)
      RAllAnisoDW(knd) = IBasisAnisoDW(jnd)
	  knd=knd+1
    END DO
  END DO
  RAllAtomPosition=MODULO(RAllAtomPosition,ONE)
  WHERE(ABS(RAllAtomPosition).LT.TINY) RAllAtomPosition = ZERO 

  !--------------------------------------------------------------------  
  ! Now reduce to the set of unique fractional atomic positions, used to be 
  ! subroutine CrystalUniqueFractionalAtomicPostitionsCalculation
  
  !first atom has to be in this set
  RAtomPosition(1,:)= RAllAtomPosition(1,:)
  SAtomLabel(1)= SAllAtomLabel(1)
  SAtomName(1)= SAllAtomName(1)
  RIsoDW(1) = RAllIsoDW(1)
  ROccupancy(1) = RAllOccupancy(1)
  IAtomicNumber(1) = IAllAtomicNumber(1)
  RAnisoDW(1) = RAllAnisoDW(1)
  jnd=2
  !work through all possible atom coords and check for duplicates
  DO ind=2,IMaxPossibleNAtomsUnitCell
    Lunique=.TRUE.
    DO knd=1,jnd-1!check against the unique ones found so far
      IF (SUM(ABS(RAllAtomPosition(ind,:)-RAtomPosition(knd,:))).LE.TINY) THEN  !position is the same
        IF (SAllAtomLabel(ind).EQ.SAtomLabel(knd)) THEN !Label is the same too, so not unique
		  Lunique=.FALSE.
		  EXIT
		END IF
	  END IF
    END DO
	IF (Lunique .EQV. .TRUE.) THEN
      RAtomPosition(jnd,:)= RAllAtomPosition(ind,:)
      SAtomLabel(jnd)= SAllAtomLabel(ind)
      SAtomName(jnd)= SAllAtomName(ind)!never used
      RIsoDW(jnd) = RAllIsoDW(ind)
      ROccupancy(jnd) = RAllOccupancy(ind)
      IAtomicNumber(jnd) = IAllAtomicNumber(ind)!
      RAnisoDW(jnd) = RAllAnisoDW(ind)
      jnd=jnd+1
    ENDIF
  ENDDO
  INAtomsUnitCell= jnd-1!this is how many unique atoms there are in the unit cell

  IF(IWriteFLAG.EQ.7.AND.my_rank.EQ.0) THEN!optional output
    DO ind=1,INAtomsUnitCell
      WRITE(SPrintString,FMT='(A4,I3,A2,A2,A3,3F7.4,A7,F5.3,A12,F7.4)')&
      "Atom",ind,": ",SAtomName(ind),", [",RAtomPosition(ind,:),&
      "], DWF=",RIsoDW(ind),", occupancy=",ROccupancy(ind)
      PRINT*,TRIM(ADJUSTL(SPrintString))
    END DO
  END IF
  
  !Finished with these variables now
  DEALLOCATE(RAllAtomPosition,SAllAtomName,RAllOccupancy,RAllIsoDW,IAllAtomicNumber,RAllAnisoDW)
  IF( IErr.NE.0 ) THEN
     PRINT*,"UniqueAtomPositions(",my_rank,")error deallocating RAllAtomPositions etc"
     RETURN
  END IF
    
  ! Calculate atomic position vectors RAtomCoordinate from Fractional Coordinates and Lattice Vectors
  ! In microscope reference frame, in Angstrom units
  DO ind=1,INAtomsUnitCell
    DO jnd=1,ITHREE
       RAtomCoordinate(ind,jnd)= RAtomPosition(ind,1)*RaVecM(jnd)+RAtomPosition(ind,2)*RbVecM(jnd)+RAtomPosition(ind,3)*RcVecM(jnd)
    END DO
  END DO

END SUBROUTINE UniqueAtomPositions
