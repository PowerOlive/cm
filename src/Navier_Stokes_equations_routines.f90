!> \file  
!> \author Sebastian Krittian
!> \brief This module handles all Navier-Stokes fluid routines.
!>
!> \section LICENSE
!>
!> Version: MPL 1.1/GPL 2.0/LGPL 2.1
!>
!> The contents of this file are subject to the Mozilla Public License
!> Version 1.1 (the "License"); you may not use this file except in
!> compliance with the License. You may obtain a copy of the License at
!> http://www.mozilla.org/MPL/
!>
!> Software distributed under the License is distributed on an "AS IS"
!> basis, WITHOUT WARRANTY OF ANY KIND, either express or implied. See the
!> License for the specific language governing rights and limitations
!> under the License.
!>
!> The Original Code is OpenCMISS
!>
!> The Initial Developer of the Original Code is University of Auckland,
!> Auckland, New Zealand, the University of Oxford, Oxford, United
!> Kingdom and King's College, London, United Kingdom. Portions created
!> by the University of Auckland, the University of Oxford and King's
!> College, London are Copyright (C) 2007-2010 by the University of
!> Auckland, the University of Oxford and King's College, London.
!> All Rights Reserved.
!>
!> Contributor(s): David Ladd, Soroush Safaei
!>
!> Alternatively, the contents of this file may be used under the terms of
!> either the GNU General Public License Version 2 or later (the "GPL"), or
!> the GNU Lesser General Public License Version 2.1 or later (the "LGPL"),
!> in which case the provisions of the GPL or the LGPL are applicable instead
!> of those above. If you wish to allow use of your version of this file only
!> under the terms of either the GPL or the LGPL, and not to allow others to
!> use your version of this file under the terms of the MPL, indicate your
!> decision by deleting the provisions above and replace them with the notice
!> and other provisions required by the GPL or the LGPL. If you do not delete
!> the provisions above, a recipient may use your version of this file under
!> the terms of any one of the MPL, the GPL or the LGPL.
!>

!>This module handles all Navier-Stokes fluid routines.
MODULE NAVIER_STOKES_EQUATIONS_ROUTINES

  USE ADVECTION_EQUATION_ROUTINES
  USE ANALYTIC_ANALYSIS_ROUTINES
  USE BASE_ROUTINES
  USE BASIS_ROUTINES
  USE BOUNDARY_CONDITIONS_ROUTINES
  USE CHARACTERISTIC_EQUATION_ROUTINES
  USE CMISS_MPI  
  USE COMP_ENVIRONMENT
  USE CONSTANTS
  USE CONTROL_LOOP_ROUTINES
  USE COORDINATE_ROUTINES
  USE DISTRIBUTED_MATRIX_VECTOR
  USE DOMAIN_MAPPINGS
  USE EQUATIONS_ROUTINES
  USE EQUATIONS_MAPPING_ROUTINES
  USE EQUATIONS_MATRICES_ROUTINES
  USE EQUATIONS_SET_CONSTANTS
  USE FIELD_ROUTINES
  USE FIELD_IO_ROUTINES
  USE FLUID_MECHANICS_IO_ROUTINES
  USE INPUT_OUTPUT
  USE ISO_VARYING_STRING
  USE KINDS
  USE LAPACK
  USE MATHS
  USE MATRIX_VECTOR
  USE MESH_ROUTINES
  USE MPI
  USE NODE_ROUTINES
  USE PROBLEM_CONSTANTS
  USE STREE_EQUATION_ROUTINES
  USE STRINGS
  USE SOLVER_ROUTINES
  USE TIMER
  USE TYPES

#include "macros.h"  

  IMPLICIT NONE

  PRIVATE

  PUBLIC NAVIER_STOKES_ANALYTIC_FUNCTIONS_EVALUATE
  
  PUBLIC NavierStokes_EquationsSetSpecificationSet
  
  PUBLIC NavierStokes_EquationsSetSolutionMethodSet
  
  PUBLIC NAVIER_STOKES_EQUATIONS_SET_SETUP
  
  PUBLIC NavierStokes_PreSolveALEUpdateParameters,NavierStokes_PreSolveUpdateBoundaryConditions, &
    & NAVIER_STOKES_PRE_SOLVE_ALE_UPDATE_MESH
  
  PUBLIC NAVIER_STOKES_PRE_SOLVE, NAVIER_STOKES_POST_SOLVE
    
  PUBLIC NavierStokes_ProblemSpecificationSet
  
  PUBLIC NAVIER_STOKES_PROBLEM_SETUP
  
  PUBLIC NavierStokes_FiniteElementResidualEvaluate,NavierStokes_FiniteElementJacobianEvaluate
  
  PUBLIC NavierStokes_BoundaryConditionsAnalyticCalculate
  
  PUBLIC NavierStokes_ResidualBasedStabilisation
  
  PUBLIC NavierStokes_Couple1D0D
  
  PUBLIC NavierStokes_CoupleCharacteristics
  
  PUBLIC NavierStokes_FiniteElementPreResidualEvaluate
  
  PUBLIC NavierStokes_ControlLoopPostLoop
  
  PUBLIC NavierStokes_UpdateMultiscaleBoundary

CONTAINS 

!
!================================================================================================================================
!

  !>Sets/changes the solution method for a Navier-Stokes flow equation type of an fluid mechanics equations set class.
  SUBROUTINE NavierStokes_EquationsSetSolutionMethodSet(EQUATIONS_SET,SOLUTION_METHOD,ERR,ERROR,*)

    !Argument variables
    TYPE(EQUATIONS_SET_TYPE), POINTER :: EQUATIONS_SET !<A pointer to the equations set to set the solution method for
    INTEGER(INTG), INTENT(IN) :: SOLUTION_METHOD !<The solution method to set
    INTEGER(INTG), INTENT(OUT) :: ERR !<The error code
    TYPE(VARYING_STRING), INTENT(OUT) :: ERROR !<The error string
    !Local Variables
    TYPE(VARYING_STRING) :: LOCAL_ERROR

    ENTERS("NavierStokes_EquationsSetSolutionMethodSet",ERR,ERROR,*999)

    IF(ASSOCIATED(EQUATIONS_SET)) THEN
      IF(.NOT.ALLOCATED(EQUATIONS_SET%SPECIFICATION)) THEN
        CALL FlagError("Equations set specification is not allocated.",err,error,*999)
      ELSE IF(SIZE(EQUATIONS_SET%SPECIFICATION,1)/=3) THEN
        CALL FlagError("Equations set specification must have three entries for a Navier-Stokes type equations set.", &
          & err,error,*999)
      END IF
      SELECT CASE(EQUATIONS_SET%SPECIFICATION(3))
      CASE(EQUATIONS_SET_STATIC_NAVIER_STOKES_SUBTYPE, &
        & EQUATIONS_SET_STATIC_RBS_NAVIER_STOKES_SUBTYPE, &
        & EQUATIONS_SET_LAPLACE_NAVIER_STOKES_SUBTYPE, &
        & EQUATIONS_SET_TRANSIENT_NAVIER_STOKES_SUBTYPE, &
        & EQUATIONS_SET_TRANSIENT_RBS_NAVIER_STOKES_SUBTYPE, &
        & EQUATIONS_SET_MULTISCALE3D_NAVIER_STOKES_SUBTYPE, &
        & EQUATIONS_SET_CONSTITUTIVE_MU_NAVIER_STOKES_SUBTYPE, &
        & EQUATIONS_SET_TRANSIENT1D_ADV_NAVIER_STOKES_SUBTYPE, &
        & EQUATIONS_SET_COUPLED1D0D_ADV_NAVIER_STOKES_SUBTYPE, &
        & EQUATIONS_SET_TRANSIENT1D_NAVIER_STOKES_SUBTYPE, &
        & EQUATIONS_SET_COUPLED1D0D_NAVIER_STOKES_SUBTYPE, &
        & EQUATIONS_SET_QUASISTATIC_NAVIER_STOKES_SUBTYPE, &
        & EQUATIONS_SET_ALE_NAVIER_STOKES_SUBTYPE, &
        & EQUATIONS_SET_PGM_NAVIER_STOKES_SUBTYPE)                                
        SELECT CASE(SOLUTION_METHOD)
        CASE(EQUATIONS_SET_FEM_SOLUTION_METHOD)
          EQUATIONS_SET%SOLUTION_METHOD=EQUATIONS_SET_FEM_SOLUTION_METHOD
        CASE(EQUATIONS_SET_NODAL_SOLUTION_METHOD)
          EQUATIONS_SET%SOLUTION_METHOD=EQUATIONS_SET_NODAL_SOLUTION_METHOD
        CASE(EQUATIONS_SET_BEM_SOLUTION_METHOD)
          CALL FlagError("Not implemented.",ERR,ERROR,*999)
        CASE(EQUATIONS_SET_FD_SOLUTION_METHOD)
          CALL FlagError("Not implemented.",ERR,ERROR,*999)
        CASE(EQUATIONS_SET_FV_SOLUTION_METHOD)
          CALL FlagError("Not implemented.",ERR,ERROR,*999)
        CASE(EQUATIONS_SET_GFEM_SOLUTION_METHOD)
          CALL FlagError("Not implemented.",ERR,ERROR,*999)
        CASE(EQUATIONS_SET_GFV_SOLUTION_METHOD)
          CALL FlagError("Not implemented.",ERR,ERROR,*999)
        CASE DEFAULT
          LOCAL_ERROR="The specified solution method of "//TRIM(NUMBER_TO_VSTRING(SOLUTION_METHOD,"*",ERR,ERROR))// &
            & " is invalid."
          CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
        END SELECT
      CASE DEFAULT
        LOCAL_ERROR="Equations set subtype of "//TRIM(NUMBER_TO_VSTRING(EQUATIONS_SET%SPECIFICATION(3),"*",ERR,ERROR))// &
          & " is not valid for a Navier-Stokes flow equation type of a fluid mechanics equations set class."
        CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
      END SELECT
    ELSE
      CALL FlagError("Equations set is not associated.",ERR,ERROR,*999)
    ENDIF

    EXITS("NavierStokes_EquationsSetSolutionMethodSet")
    RETURN
999 ERRORSEXITS("NavierStokes_EquationsSetSolutionMethodSet",ERR,ERROR)
    RETURN 1
    
  END SUBROUTINE NavierStokes_EquationsSetSolutionMethodSet

!
!================================================================================================================================
!

  !>Sets the equation specification for a Navier-Stokes fluid type of a fluid mechanics equations set class.
  SUBROUTINE NavierStokes_EquationsSetSpecificationSet(equationsSet,specification,err,error,*)

    !Argument variables
    TYPE(EQUATIONS_SET_TYPE), POINTER :: equationsSet !<A pointer to the equations set to set the specification for
    INTEGER(INTG), INTENT(IN) :: specification(:) !<The equations set specification to set
    INTEGER(INTG), INTENT(OUT) :: err !<The error code
    TYPE(VARYING_STRING), INTENT(OUT) :: error !<The error string
    !Local Variables
    TYPE(VARYING_STRING) :: localError
    INTEGER(INTG) :: subtype

    ENTERS("NavierStokes_EquationsSetSpecificationSet",err,error,*999)

    IF(ASSOCIATED(equationsSet)) THEN
      IF(SIZE(specification,1)/=3) THEN
        CALL FlagError("Equations set specification must have three entries for a Navier-Stokes type equations set.", &
          & err,error,*999)
      ENDIF
      subtype=specification(3)
      SELECT CASE(subtype)
      CASE(EQUATIONS_SET_STATIC_NAVIER_STOKES_SUBTYPE, &
        & EQUATIONS_SET_STATIC_RBS_NAVIER_STOKES_SUBTYPE, &
        & EQUATIONS_SET_LAPLACE_NAVIER_STOKES_SUBTYPE, &
        & EQUATIONS_SET_TRANSIENT_NAVIER_STOKES_SUBTYPE, &
        & EQUATIONS_SET_TRANSIENT1D_ADV_NAVIER_STOKES_SUBTYPE, &
        & EQUATIONS_SET_TRANSIENT1D_NAVIER_STOKES_SUBTYPE, &
        & EQUATIONS_SET_TRANSIENT_RBS_NAVIER_STOKES_SUBTYPE, &
        & EQUATIONS_SET_MULTISCALE3D_NAVIER_STOKES_SUBTYPE, &
        & EQUATIONS_SET_CONSTITUTIVE_MU_NAVIER_STOKES_SUBTYPE, &
        & EQUATIONS_SET_COUPLED1D0D_ADV_NAVIER_STOKES_SUBTYPE, &
        & EQUATIONS_SET_Coupled1D0D_NAVIER_STOKES_SUBTYPE, &
        & EQUATIONS_SET_QUASISTATIC_NAVIER_STOKES_SUBTYPE, &
        & EQUATIONS_SET_ALE_NAVIER_STOKES_SUBTYPE, &
        & EQUATIONS_SET_PGM_NAVIER_STOKES_SUBTYPE)
        !ok
      CASE(EQUATIONS_SET_OPTIMISED_NAVIER_STOKES_SUBTYPE)
        CALL FlagError("Not implemented yet.",err,error,*999)
      CASE DEFAULT
        localError="The third equations set specification of "//TRIM(NumberToVstring(specification(3),"*",err,error))// &
          & " is not valid for a Navier-Stokes fluid mechanics equations set."
        CALL FlagError(localError,err,error,*999)
      END SELECT
      !Set full specification
      IF(ALLOCATED(equationsSet%specification)) THEN
        CALL FlagError("Equations set specification is already allocated.",err,error,*999)
      ELSE
        ALLOCATE(equationsSet%specification(3),stat=err)
        IF(err/=0) CALL FlagError("Could not allocate equations set specification.",err,error,*999)
      ENDIF
      equationsSet%specification(1:3)=[EQUATIONS_SET_FLUID_MECHANICS_CLASS,EQUATIONS_SET_NAVIER_STOKES_EQUATION_TYPE,subtype]
    ELSE
      CALL FlagError("Equations set is not associated.",err,error,*999)
    ENDIF

    EXITS("NavierStokes_EquationsSetSpecificationSet")
    RETURN
999 ERRORS("NavierStokes_EquationsSetSpecificationSet",err,error)
    EXITS("NavierStokes_EquationsSetSpecificationSet")
    RETURN 1
    
  END SUBROUTINE NavierStokes_EquationsSetSpecificationSet

!
!================================================================================================================================
!

  !>Sets up the Navier-Stokes fluid setup.
  SUBROUTINE NAVIER_STOKES_EQUATIONS_SET_SETUP(EQUATIONS_SET,EQUATIONS_SET_SETUP,ERR,ERROR,*)

    !Argument variables
    TYPE(EQUATIONS_SET_TYPE), POINTER :: EQUATIONS_SET !<A pointer to the equations set to setup
    TYPE(EQUATIONS_SET_SETUP_TYPE), INTENT(INOUT) :: EQUATIONS_SET_SETUP !<The equations set setup information
    INTEGER(INTG), INTENT(OUT) :: ERR !<The error code
    TYPE(VARYING_STRING), INTENT(OUT) :: ERROR !<The error string
    !Local Variables
    TYPE(DECOMPOSITION_TYPE), POINTER :: GEOMETRIC_DECOMPOSITION
    TYPE(EQUATIONS_TYPE), POINTER :: EQUATIONS
    TYPE(EQUATIONS_MAPPING_TYPE), POINTER :: EQUATIONS_MAPPING
    TYPE(EQUATIONS_MATRICES_TYPE), POINTER :: EQUATIONS_MATRICES
    TYPE(EQUATIONS_SET_ANALYTIC_TYPE), POINTER :: EQUATIONS_ANALYTIC
    TYPE(EQUATIONS_SET_MATERIALS_TYPE), POINTER :: EQUATIONS_MATERIALS
    TYPE(EQUATIONS_SET_EQUATIONS_SET_FIELD_TYPE), POINTER :: EQUATIONS_EQUATIONS_SET_FIELD
    TYPE(FIELD_TYPE), POINTER :: EQUATIONS_SET_FIELD_FIELD,ANALYTIC_FIELD,DEPENDENT_FIELD,GEOMETRIC_FIELD
    TYPE(VARYING_STRING) :: LOCAL_ERROR
    INTEGER(INTG) :: GEOMETRIC_SCALING_TYPE,GEOMETRIC_MESH_COMPONENT,INDEPENDENT_FIELD_NUMBER_OF_COMPONENTS
    INTEGER(INTG) :: NUMBER_OF_ANALYTIC_COMPONENTS,DEPENDENT_FIELD_NUMBER_OF_VARIABLES,DEPENDENT_FIELD_NUMBER_OF_COMPONENTS
    INTEGER(INTG) :: NUMBER_OF_DIMENSIONS,GEOMETRIC_COMPONENT_NUMBER,I,componentIdx,INDEPENDENT_FIELD_NUMBER_OF_VARIABLES
    INTEGER(INTG) :: MATERIAL_FIELD_NUMBER_OF_VARIABLES,MATERIAL_FIELD_NUMBER_OF_COMPONENTS1,MATERIAL_FIELD_NUMBER_OF_COMPONENTS2
    INTEGER(INTG) :: elementBasedComponents,nodeBasedComponents,constantBasedComponents
    INTEGER(INTG) :: EQUATIONS_SET_FIELD_NUMBER_OF_VARIABLES,EQUATIONS_SET_FIELD_NUMBER_OF_COMPONENTS

    ENTERS("NAVIER_STOKES_EQUATIONS_SET_SETUP",ERR,ERROR,*999)

    NULLIFY(EQUATIONS)
    NULLIFY(EQUATIONS_MAPPING)
    NULLIFY(EQUATIONS_MATRICES)
    NULLIFY(GEOMETRIC_DECOMPOSITION)
    NULLIFY(EQUATIONS_EQUATIONS_SET_FIELD)
    NULLIFY(EQUATIONS_SET_FIELD_FIELD)

    IF(ASSOCIATED(EQUATIONS_SET)) THEN
      IF(.NOT.ALLOCATED(EQUATIONS_SET%SPECIFICATION)) THEN
        CALL FlagError("Equations set specification is not allocated.",err,error,*999)
      ELSE IF(SIZE(EQUATIONS_SET%SPECIFICATION,1)/=3) THEN
        CALL FlagError("Equations set specification must have three entries for a Navier-Stokes type equations set.", &
          & err,error,*999)
      END IF
      SELECT CASE(EQUATIONS_SET%SPECIFICATION(3))
      CASE(EQUATIONS_SET_STATIC_NAVIER_STOKES_SUBTYPE, &
        & EQUATIONS_SET_STATIC_RBS_NAVIER_STOKES_SUBTYPE, &
        & EQUATIONS_SET_TRANSIENT_NAVIER_STOKES_SUBTYPE, &
        & EQUATIONS_SET_TRANSIENT1D_NAVIER_STOKES_SUBTYPE, &
        & EQUATIONS_SET_COUPLED1D0D_NAVIER_STOKES_SUBTYPE, &
        & EQUATIONS_SET_TRANSIENT1D_ADV_NAVIER_STOKES_SUBTYPE, &
        & EQUATIONS_SET_COUPLED1D0D_ADV_NAVIER_STOKES_SUBTYPE, &
        & EQUATIONS_SET_TRANSIENT_RBS_NAVIER_STOKES_SUBTYPE, &
        & EQUATIONS_SET_MULTISCALE3D_NAVIER_STOKES_SUBTYPE, &
        & EQUATIONS_SET_CONSTITUTIVE_MU_NAVIER_STOKES_SUBTYPE, &
        & EQUATIONS_SET_QUASISTATIC_NAVIER_STOKES_SUBTYPE, &
        & EQUATIONS_SET_LAPLACE_NAVIER_STOKES_SUBTYPE, &
        & EQUATIONS_SET_ALE_NAVIER_STOKES_SUBTYPE, &
        & EQUATIONS_SET_PGM_NAVIER_STOKES_SUBTYPE)
        SELECT CASE(EQUATIONS_SET_SETUP%SETUP_TYPE)
        !-----------------------------------------------------------------
        ! I n i t i a l   s e t u p
        !-----------------------------------------------------------------
        CASE(EQUATIONS_SET_SETUP_INITIAL_TYPE)
          SELECT CASE(EQUATIONS_SET%SPECIFICATION(3))
          CASE(EQUATIONS_SET_STATIC_NAVIER_STOKES_SUBTYPE,EQUATIONS_SET_LAPLACE_NAVIER_STOKES_SUBTYPE, &
            & EQUATIONS_SET_TRANSIENT_NAVIER_STOKES_SUBTYPE,EQUATIONS_SET_ALE_NAVIER_STOKES_SUBTYPE, &
            & EQUATIONS_SET_PGM_NAVIER_STOKES_SUBTYPE,EQUATIONS_SET_QUASISTATIC_NAVIER_STOKES_SUBTYPE)
            SELECT CASE(EQUATIONS_SET_SETUP%ACTION_TYPE)
            CASE(EQUATIONS_SET_SETUP_START_ACTION)
              CALL NavierStokes_EquationsSetSolutionMethodSet(EQUATIONS_SET, &
                & EQUATIONS_SET_FEM_SOLUTION_METHOD,ERR,ERROR,*999)
              EQUATIONS_SET%SOLUTION_METHOD=EQUATIONS_SET_FEM_SOLUTION_METHOD
            CASE(EQUATIONS_SET_SETUP_FINISH_ACTION)
              !Do nothing
            CASE DEFAULT
              LOCAL_ERROR="The action type of "//TRIM(NUMBER_TO_VSTRING(EQUATIONS_SET_SETUP%ACTION_TYPE, &
                & "*",ERR,ERROR))// " for a setup type of "//TRIM(NUMBER_TO_VSTRING(EQUATIONS_SET_SETUP% &
                & SETUP_TYPE,"*",ERR,ERROR))// " is not implemented for a Navier-Stokes fluid."
              CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
            END SELECT
          CASE(EQUATIONS_SET_TRANSIENT1D_NAVIER_STOKES_SUBTYPE, &
             & EQUATIONS_SET_COUPLED1D0D_NAVIER_STOKES_SUBTYPE, &
             & EQUATIONS_SET_TRANSIENT1D_ADV_NAVIER_STOKES_SUBTYPE, &
             & EQUATIONS_SET_COUPLED1D0D_ADV_NAVIER_STOKES_SUBTYPE)
            SELECT CASE(EQUATIONS_SET_SETUP%ACTION_TYPE)
            CASE(EQUATIONS_SET_SETUP_START_ACTION)
              CALL NavierStokes_EquationsSetSolutionMethodSet(EQUATIONS_SET, &
                & EQUATIONS_SET_FEM_SOLUTION_METHOD,ERR,ERROR,*999)
              EQUATIONS_SET%SOLUTION_METHOD=EQUATIONS_SET_FEM_SOLUTION_METHOD
              EQUATIONS_SET_FIELD_NUMBER_OF_VARIABLES = 1 
              EQUATIONS_SET_FIELD_NUMBER_OF_COMPONENTS = 1
              EQUATIONS_EQUATIONS_SET_FIELD=>EQUATIONS_SET%EQUATIONS_SET_FIELD
              IF(EQUATIONS_EQUATIONS_SET_FIELD%EQUATIONS_SET_FIELD_AUTO_CREATED) THEN
                !Create the auto created equations set field field for SUPG element metrics
                CALL FIELD_CREATE_START(EQUATIONS_SET_SETUP%FIELD_USER_NUMBER,EQUATIONS_SET%REGION, &
                  & EQUATIONS_EQUATIONS_SET_FIELD%EQUATIONS_SET_FIELD_FIELD,ERR,ERROR,*999)
                EQUATIONS_SET_FIELD_FIELD=>EQUATIONS_EQUATIONS_SET_FIELD%EQUATIONS_SET_FIELD_FIELD
                CALL FIELD_LABEL_SET(EQUATIONS_SET_FIELD_FIELD,"Equations Set Field",ERR,ERROR,*999)
                CALL FIELD_TYPE_SET_AND_LOCK(EQUATIONS_SET_FIELD_FIELD,FIELD_GENERAL_TYPE,&
                  & ERR,ERROR,*999)
                CALL FIELD_NUMBER_OF_VARIABLES_SET(EQUATIONS_SET_FIELD_FIELD, &
                  & EQUATIONS_SET_FIELD_NUMBER_OF_VARIABLES,ERR,ERROR,*999)
                CALL FIELD_VARIABLE_TYPES_SET_AND_LOCK(EQUATIONS_SET_FIELD_FIELD,&
                  & [FIELD_U_VARIABLE_TYPE],ERR,ERROR,*999)
                CALL FIELD_VARIABLE_LABEL_SET(EQUATIONS_SET_FIELD_FIELD,FIELD_U_VARIABLE_TYPE, &
                  & "Penalty Coefficient",ERR,ERROR,*999)
                CALL FIELD_DATA_TYPE_SET_AND_LOCK(EQUATIONS_SET_FIELD_FIELD,FIELD_U_VARIABLE_TYPE, &
                  & FIELD_DP_TYPE,ERR,ERROR,*999)
                CALL FIELD_NUMBER_OF_COMPONENTS_SET_AND_LOCK(EQUATIONS_SET_FIELD_FIELD,&
                  & FIELD_U_VARIABLE_TYPE,EQUATIONS_SET_FIELD_NUMBER_OF_COMPONENTS,ERR,ERROR,*999)
              END IF
            CASE(EQUATIONS_SET_SETUP_FINISH_ACTION)
              IF(EQUATIONS_SET%EQUATIONS_SET_FIELD%EQUATIONS_SET_FIELD_AUTO_CREATED) THEN
                CALL FIELD_CREATE_FINISH(EQUATIONS_SET%EQUATIONS_SET_FIELD%EQUATIONS_SET_FIELD_FIELD,ERR,ERROR,*999)
                !Default the penalty coefficient value to 1E4
                CALL FIELD_COMPONENT_VALUES_INITIALISE(EQUATIONS_SET%EQUATIONS_SET_FIELD%EQUATIONS_SET_FIELD_FIELD, &
                 & FIELD_U_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE,1,1.0E4_DP,ERR,ERROR,*999)
              END IF
            CASE DEFAULT
              LOCAL_ERROR="The action type of "//TRIM(NUMBER_TO_VSTRING(EQUATIONS_SET_SETUP%ACTION_TYPE, &
                & "*",ERR,ERROR))// " for a setup type of "//TRIM(NUMBER_TO_VSTRING(EQUATIONS_SET_SETUP% &
                & SETUP_TYPE,"*",ERR,ERROR))// " is not implemented for a Navier-Stokes fluid."
              CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
            END SELECT
          CASE (EQUATIONS_SET_STATIC_RBS_NAVIER_STOKES_SUBTYPE, &
             &  EQUATIONS_SET_TRANSIENT_RBS_NAVIER_STOKES_SUBTYPE, &
             &  EQUATIONS_SET_MULTISCALE3D_NAVIER_STOKES_SUBTYPE, &
             &  EQUATIONS_SET_CONSTITUTIVE_MU_NAVIER_STOKES_SUBTYPE)
            SELECT CASE(EQUATIONS_SET_SETUP%ACTION_TYPE)
            CASE(EQUATIONS_SET_SETUP_START_ACTION)
              CALL NavierStokes_EquationsSetSolutionMethodSet(EQUATIONS_SET, &
                & EQUATIONS_SET_FEM_SOLUTION_METHOD,ERR,ERROR,*999)
              EQUATIONS_SET%SOLUTION_METHOD=EQUATIONS_SET_FEM_SOLUTION_METHOD
              EQUATIONS_SET_FIELD_NUMBER_OF_VARIABLES = 3
              nodeBasedComponents = 1  ! boundary flux
              elementBasedComponents = 10  ! 4 element metrics, 3 boundary normal components, boundaryID, boundaryType, C1
              constantBasedComponents = 4  ! maxCFL, boundaryStabilisationBeta, timeIncrement, stabilisationType
              EQUATIONS_EQUATIONS_SET_FIELD=>EQUATIONS_SET%EQUATIONS_SET_FIELD
              IF(EQUATIONS_EQUATIONS_SET_FIELD%EQUATIONS_SET_FIELD_AUTO_CREATED) THEN
                !Create the auto created equations set field field for SUPG element metrics
                CALL FIELD_CREATE_START(EQUATIONS_SET_SETUP%FIELD_USER_NUMBER,EQUATIONS_SET%REGION, &
                  & EQUATIONS_EQUATIONS_SET_FIELD%EQUATIONS_SET_FIELD_FIELD,ERR,ERROR,*999)
                EQUATIONS_SET_FIELD_FIELD=>EQUATIONS_EQUATIONS_SET_FIELD%EQUATIONS_SET_FIELD_FIELD
                CALL FIELD_LABEL_SET(EQUATIONS_SET_FIELD_FIELD,"Equations Set Field",ERR,ERROR,*999)
                CALL FIELD_TYPE_SET_AND_LOCK(EQUATIONS_SET_FIELD_FIELD,FIELD_GENERAL_TYPE,&
                  & ERR,ERROR,*999)
                 CALL FIELD_NUMBER_OF_VARIABLES_SET(EQUATIONS_SET_FIELD_FIELD, &
                   & EQUATIONS_SET_FIELD_NUMBER_OF_VARIABLES,ERR,ERROR,*999)
                 CALL FIELD_VARIABLE_TYPES_SET_AND_LOCK(EQUATIONS_SET_FIELD_FIELD,&
                   & [FIELD_U_VARIABLE_TYPE,FIELD_V_VARIABLE_TYPE,FIELD_U1_VARIABLE_TYPE],ERR,ERROR,*999)
                 CALL FIELD_VARIABLE_LABEL_SET(EQUATIONS_SET_FIELD_FIELD,FIELD_U_VARIABLE_TYPE, &
                   & "BoundaryFlow",ERR,ERROR,*999)
                 CALL FIELD_VARIABLE_LABEL_SET(EQUATIONS_SET_FIELD_FIELD,FIELD_V_VARIABLE_TYPE, &
                   & "ElementMetrics",ERR,ERROR,*999)
                 CALL FIELD_VARIABLE_LABEL_SET(EQUATIONS_SET_FIELD_FIELD,FIELD_U1_VARIABLE_TYPE, &
                   & "EquationsConstants",ERR,ERROR,*999)
                 CALL FIELD_DATA_TYPE_SET_AND_LOCK(EQUATIONS_SET_FIELD_FIELD,FIELD_U_VARIABLE_TYPE, &
                   & FIELD_DP_TYPE,ERR,ERROR,*999)
                 CALL FIELD_DATA_TYPE_SET_AND_LOCK(EQUATIONS_SET_FIELD_FIELD,FIELD_V_VARIABLE_TYPE, &
                   & FIELD_DP_TYPE,ERR,ERROR,*999)
                 CALL FIELD_DATA_TYPE_SET_AND_LOCK(EQUATIONS_SET_FIELD_FIELD,FIELD_U1_VARIABLE_TYPE, &
                   & FIELD_DP_TYPE,ERR,ERROR,*999)
                 CALL FIELD_NUMBER_OF_COMPONENTS_SET_AND_LOCK(EQUATIONS_SET_FIELD_FIELD,&
                   & FIELD_U_VARIABLE_TYPE,nodeBasedComponents,ERR,ERROR,*999)
                 CALL FIELD_NUMBER_OF_COMPONENTS_SET_AND_LOCK(EQUATIONS_SET_FIELD_FIELD,&
                   & FIELD_V_VARIABLE_TYPE,elementBasedComponents,ERR,ERROR,*999)
                 CALL FIELD_NUMBER_OF_COMPONENTS_SET_AND_LOCK(EQUATIONS_SET_FIELD_FIELD,&
                   & FIELD_U1_VARIABLE_TYPE,constantBasedComponents,ERR,ERROR,*999)
              ELSE
                LOCAL_ERROR="User-specified fields are not yet implemented for an equations set field field &
                  & setup type of "//TRIM(NUMBER_TO_VSTRING(EQUATIONS_SET_SETUP% &
                  & SETUP_TYPE,"*",ERR,ERROR))// " for a Navier-Stokes fluid."
              END IF
            CASE(EQUATIONS_SET_SETUP_FINISH_ACTION)
              IF(EQUATIONS_SET%EQUATIONS_SET_FIELD%EQUATIONS_SET_FIELD_AUTO_CREATED) THEN
                CALL FIELD_CREATE_FINISH(EQUATIONS_SET%EQUATIONS_SET_FIELD%EQUATIONS_SET_FIELD_FIELD,ERR,ERROR,*999)
                !Default the Element Metrics parameter values 0.0
                nodeBasedComponents = 1  ! boundary flux
                elementBasedComponents = 10  ! 4 element metrics, 3 boundary normal components, boundaryID, boundaryType, C1
                constantBasedComponents = 4  ! maxCFL, boundaryStabilisationBeta, timeIncrement, stabilisationType
                ! Init boundary flux to 0
                CALL FIELD_COMPONENT_VALUES_INITIALISE(EQUATIONS_SET%EQUATIONS_SET_FIELD%EQUATIONS_SET_FIELD_FIELD, &
                  & FIELD_U_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE,1,0.0_DP,ERR,ERROR,*999)
                ! Init Element Metrics to 0 (except C1)
                DO componentIdx=1,elementBasedComponents-1
                  CALL FIELD_COMPONENT_VALUES_INITIALISE(EQUATIONS_SET%EQUATIONS_SET_FIELD%EQUATIONS_SET_FIELD_FIELD, &
                    & FIELD_V_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE,componentIdx,0.0_DP,ERR,ERROR,*999)
                END DO
                ! Default C1 to -1 for now, will be calculated in ResidualBasedStabilisation if not specified by user
                CALL FIELD_COMPONENT_VALUES_INITIALISE(EQUATIONS_SET%EQUATIONS_SET_FIELD%EQUATIONS_SET_FIELD_FIELD, &
                  & FIELD_V_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE,elementBasedComponents,-1.0_DP,ERR,ERROR,*999)
                ! Boundary stabilisation scale factor (beta): default to 0
                CALL FIELD_COMPONENT_VALUES_INITIALISE(EQUATIONS_SET%EQUATIONS_SET_FIELD%EQUATIONS_SET_FIELD_FIELD, &
                  & FIELD_U1_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE,1,0.0_DP,ERR,ERROR,*999)
                ! Max Courant (CFL) number: default to 1.0
                CALL FIELD_COMPONENT_VALUES_INITIALISE(EQUATIONS_SET%EQUATIONS_SET_FIELD%EQUATIONS_SET_FIELD_FIELD, &
                  & FIELD_U1_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE,2,1.0_DP,ERR,ERROR,*999)
                ! Init Time increment to 0
                CALL FIELD_COMPONENT_VALUES_INITIALISE(EQUATIONS_SET%EQUATIONS_SET_FIELD%EQUATIONS_SET_FIELD_FIELD, &
                  & FIELD_U1_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE,3,0.0_DP,ERR,ERROR,*999)
                ! Stabilisation type: default to 1 for RBS (0=none, 2=RBVM)
                CALL FIELD_COMPONENT_VALUES_INITIALISE(EQUATIONS_SET%EQUATIONS_SET_FIELD%EQUATIONS_SET_FIELD_FIELD, &
                  & FIELD_U1_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE,4,1.0_DP,ERR,ERROR,*999)
              ELSE
                LOCAL_ERROR="User-specified fields are not yet implemented for an equations set field field &
                  & setup type of "//TRIM(NUMBER_TO_VSTRING(EQUATIONS_SET_SETUP% &
                  & SETUP_TYPE,"*",ERR,ERROR))// " for a Navier-Stokes fluid."
              END IF
            CASE DEFAULT
              LOCAL_ERROR="The action type of "//TRIM(NUMBER_TO_VSTRING(EQUATIONS_SET_SETUP%ACTION_TYPE, &
                & "*",ERR,ERROR))// " for a setup type of "//TRIM(NUMBER_TO_VSTRING(EQUATIONS_SET_SETUP% &
                & SETUP_TYPE,"*",ERR,ERROR))// " is not implemented for a Navier-Stokes fluid."
              CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
            END SELECT
          CASE DEFAULT
            LOCAL_ERROR="The equation set subtype of "//TRIM(NUMBER_TO_VSTRING(EQUATIONS_SET%SPECIFICATION(3),"*",ERR,ERROR))// &
              & " for a setup type of "//TRIM(NUMBER_TO_VSTRING(EQUATIONS_SET_SETUP%SETUP_TYPE,"*",ERR,ERROR))// &
              & " is invalid for a Navier-Stokes equation."
            CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
          END SELECT
        !-----------------------------------------------------------------
        ! G e o m e t r i c   f i e l d
        !-----------------------------------------------------------------
        CASE(EQUATIONS_SET_SETUP_GEOMETRY_TYPE)
          SELECT CASE(EQUATIONS_SET%SPECIFICATION(3))
          CASE(EQUATIONS_SET_STATIC_NAVIER_STOKES_SUBTYPE,EQUATIONS_SET_LAPLACE_NAVIER_STOKES_SUBTYPE, &
            & EQUATIONS_SET_TRANSIENT_NAVIER_STOKES_SUBTYPE,EQUATIONS_SET_ALE_NAVIER_STOKES_SUBTYPE, &
            & EQUATIONS_SET_PGM_NAVIER_STOKES_SUBTYPE,EQUATIONS_SET_QUASISTATIC_NAVIER_STOKES_SUBTYPE)
            !Do nothing???
          CASE(EQUATIONS_SET_TRANSIENT1D_NAVIER_STOKES_SUBTYPE, &
             & EQUATIONS_SET_COUPLED1D0D_NAVIER_STOKES_SUBTYPE, &
             & EQUATIONS_SET_TRANSIENT1D_ADV_NAVIER_STOKES_SUBTYPE, &
             & EQUATIONS_SET_COUPLED1D0D_ADV_NAVIER_STOKES_SUBTYPE)
            SELECT CASE(EQUATIONS_SET_SETUP%ACTION_TYPE)
            CASE(EQUATIONS_SET_SETUP_START_ACTION)
              EQUATIONS_SET_FIELD_NUMBER_OF_COMPONENTS = 1 
              EQUATIONS_EQUATIONS_SET_FIELD=>EQUATIONS_SET%EQUATIONS_SET_FIELD
              EQUATIONS_SET_FIELD_FIELD=>EQUATIONS_EQUATIONS_SET_FIELD%EQUATIONS_SET_FIELD_FIELD
              IF(EQUATIONS_EQUATIONS_SET_FIELD%EQUATIONS_SET_FIELD_AUTO_CREATED) THEN
                CALL FIELD_MESH_DECOMPOSITION_GET(EQUATIONS_SET%GEOMETRY%GEOMETRIC_FIELD,GEOMETRIC_DECOMPOSITION,ERR,ERROR,*999)
                CALL FIELD_MESH_DECOMPOSITION_SET_AND_LOCK(EQUATIONS_SET_FIELD_FIELD,&
                  & GEOMETRIC_DECOMPOSITION,ERR,ERROR,*999)
                CALL FIELD_GEOMETRIC_FIELD_SET_AND_LOCK(EQUATIONS_SET_FIELD_FIELD,& 
                  & EQUATIONS_SET%GEOMETRY%GEOMETRIC_FIELD,ERR,ERROR,*999)
                CALL FIELD_COMPONENT_MESH_COMPONENT_GET(EQUATIONS_SET%GEOMETRY%GEOMETRIC_FIELD,FIELD_U_VARIABLE_TYPE, &
                  & 1,GEOMETRIC_COMPONENT_NUMBER,ERR,ERROR,*999)                
                DO componentIdx = 1, EQUATIONS_SET_FIELD_NUMBER_OF_COMPONENTS
                  CALL FIELD_COMPONENT_MESH_COMPONENT_SET_AND_LOCK(EQUATIONS_SET%EQUATIONS_SET_FIELD%EQUATIONS_SET_FIELD_FIELD, &
                    & FIELD_U_VARIABLE_TYPE,componentIdx,GEOMETRIC_COMPONENT_NUMBER,ERR,ERROR,*999)
                  CALL FIELD_COMPONENT_INTERPOLATION_SET_AND_LOCK(EQUATIONS_SET%EQUATIONS_SET_FIELD%EQUATIONS_SET_FIELD_FIELD, &
                    & FIELD_U_VARIABLE_TYPE,componentIdx,FIELD_CONSTANT_INTERPOLATION,ERR,ERROR,*999)
                END DO
                !Default the field scaling to that of the geometric field
                CALL FIELD_SCALING_TYPE_GET(EQUATIONS_SET%GEOMETRY%GEOMETRIC_FIELD,GEOMETRIC_SCALING_TYPE,ERR,ERROR,*999)
                CALL FIELD_SCALING_TYPE_SET(EQUATIONS_SET%EQUATIONS_SET_FIELD%EQUATIONS_SET_FIELD_FIELD,GEOMETRIC_SCALING_TYPE, &
                  & ERR,ERROR,*999)
              ENDIF
            CASE(EQUATIONS_SET_SETUP_FINISH_ACTION)
              ! do nothing
            CASE DEFAULT
              LOCAL_ERROR="The action type of "//TRIM(NUMBER_TO_VSTRING(EQUATIONS_SET_SETUP%ACTION_TYPE,"*",ERR,ERROR))// &
                & " for a setup type of "//TRIM(NUMBER_TO_VSTRING(EQUATIONS_SET_SETUP%SETUP_TYPE,"*",ERR,ERROR))// &
                & " is invalid for a linear diffusion equation."
              CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
            END SELECT
          CASE (EQUATIONS_SET_STATIC_RBS_NAVIER_STOKES_SUBTYPE, &
             &  EQUATIONS_SET_TRANSIENT_RBS_NAVIER_STOKES_SUBTYPE, &
             &  EQUATIONS_SET_MULTISCALE3D_NAVIER_STOKES_SUBTYPE, &
             &  EQUATIONS_SET_CONSTITUTIVE_MU_NAVIER_STOKES_SUBTYPE)
            SELECT CASE(EQUATIONS_SET_SETUP%ACTION_TYPE)
            CASE(EQUATIONS_SET_SETUP_START_ACTION)
              nodeBasedComponents = 1  ! boundary flux
              elementBasedComponents = 10  ! 4 element metrics, 3 boundary normal components, boundaryID, boundaryType, C1
              constantBasedComponents = 4  ! maxCFL, boundaryStabilisationBeta, timeIncrement, stabilisationType
              EQUATIONS_EQUATIONS_SET_FIELD=>EQUATIONS_SET%EQUATIONS_SET_FIELD
              EQUATIONS_SET_FIELD_FIELD=>EQUATIONS_EQUATIONS_SET_FIELD%EQUATIONS_SET_FIELD_FIELD
              IF(EQUATIONS_EQUATIONS_SET_FIELD%EQUATIONS_SET_FIELD_AUTO_CREATED) THEN
                CALL FIELD_MESH_DECOMPOSITION_GET(EQUATIONS_SET%GEOMETRY%GEOMETRIC_FIELD,GEOMETRIC_DECOMPOSITION,ERR,ERROR,*999)
                CALL FIELD_MESH_DECOMPOSITION_SET_AND_LOCK(EQUATIONS_SET_FIELD_FIELD,&
                  & GEOMETRIC_DECOMPOSITION,ERR,ERROR,*999)
                CALL FIELD_GEOMETRIC_FIELD_SET_AND_LOCK(EQUATIONS_SET_FIELD_FIELD,& 
                  & EQUATIONS_SET%GEOMETRY%GEOMETRIC_FIELD,ERR,ERROR,*999)
                CALL FIELD_COMPONENT_MESH_COMPONENT_GET(EQUATIONS_SET%GEOMETRY%GEOMETRIC_FIELD,FIELD_U_VARIABLE_TYPE, &
                  & 1,GEOMETRIC_COMPONENT_NUMBER,ERR,ERROR,*999)                
                CALL FIELD_COMPONENT_MESH_COMPONENT_SET_AND_LOCK(EQUATIONS_SET%EQUATIONS_SET_FIELD%EQUATIONS_SET_FIELD_FIELD, &
                  & FIELD_U_VARIABLE_TYPE,1,GEOMETRIC_COMPONENT_NUMBER,ERR,ERROR,*999)
                CALL FIELD_COMPONENT_INTERPOLATION_SET_AND_LOCK(EQUATIONS_SET%EQUATIONS_SET_FIELD%EQUATIONS_SET_FIELD_FIELD, &
                  & FIELD_U_VARIABLE_TYPE,1,FIELD_NODE_BASED_INTERPOLATION,ERR,ERROR,*999)
                ! Element-based fields
                DO componentIdx = 1, elementBasedComponents
                  CALL FIELD_COMPONENT_MESH_COMPONENT_SET_AND_LOCK(EQUATIONS_SET%EQUATIONS_SET_FIELD%EQUATIONS_SET_FIELD_FIELD, &
                    & FIELD_V_VARIABLE_TYPE,componentIdx,GEOMETRIC_COMPONENT_NUMBER,ERR,ERROR,*999)
                  CALL FIELD_COMPONENT_INTERPOLATION_SET_AND_LOCK(EQUATIONS_SET%EQUATIONS_SET_FIELD%EQUATIONS_SET_FIELD_FIELD, &
                    & FIELD_V_VARIABLE_TYPE,componentIdx,FIELD_ELEMENT_BASED_INTERPOLATION,ERR,ERROR,*999)
                END DO
                ! Constant fields: boundary stabilisation scale factor and max courant #
                DO componentIdx = 1, constantBasedComponents
                  CALL FIELD_COMPONENT_MESH_COMPONENT_SET_AND_LOCK(EQUATIONS_SET%EQUATIONS_SET_FIELD%EQUATIONS_SET_FIELD_FIELD, &
                    & FIELD_U1_VARIABLE_TYPE,componentIdx,GEOMETRIC_COMPONENT_NUMBER,ERR,ERROR,*999)
                  CALL FIELD_COMPONENT_INTERPOLATION_SET_AND_LOCK(EQUATIONS_SET%EQUATIONS_SET_FIELD%EQUATIONS_SET_FIELD_FIELD, &
                    & FIELD_U1_VARIABLE_TYPE,componentIdx,FIELD_CONSTANT_INTERPOLATION,ERR,ERROR,*999)
                END DO
                !Default the field scaling to that of the geometric field
                CALL FIELD_SCALING_TYPE_GET(EQUATIONS_SET%GEOMETRY%GEOMETRIC_FIELD,GEOMETRIC_SCALING_TYPE,ERR,ERROR,*999)
                CALL FIELD_SCALING_TYPE_SET(EQUATIONS_SET%EQUATIONS_SET_FIELD%EQUATIONS_SET_FIELD_FIELD,GEOMETRIC_SCALING_TYPE, &
                  & ERR,ERROR,*999)
              ELSE
                !Do nothing
              END IF
            CASE(EQUATIONS_SET_SETUP_FINISH_ACTION)
              ! do nothing
            CASE DEFAULT
              LOCAL_ERROR="The action type of "//TRIM(NUMBER_TO_VSTRING(EQUATIONS_SET_SETUP%ACTION_TYPE,"*",ERR,ERROR))// &
                & " for a setup type of "//TRIM(NUMBER_TO_VSTRING(EQUATIONS_SET_SETUP%SETUP_TYPE,"*",ERR,ERROR))// &
                & " is invalid for a linear diffusion equation."
              CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
            END SELECT
          CASE DEFAULT
            LOCAL_ERROR="The equation set subtype of "//TRIM(NUMBER_TO_VSTRING(EQUATIONS_SET%SPECIFICATION(3),"*",ERR,ERROR))// &
              & " is invalid for a Navier-Stokes equation."
            CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
          END SELECT
        !-----------------------------------------------------------------
        ! D e p e n d e n t   f i e l d
        !-----------------------------------------------------------------
        CASE(EQUATIONS_SET_SETUP_DEPENDENT_TYPE)
          SELECT CASE(EQUATIONS_SET%SPECIFICATION(3))
          CASE(EQUATIONS_SET_STATIC_NAVIER_STOKES_SUBTYPE,EQUATIONS_SET_LAPLACE_NAVIER_STOKES_SUBTYPE, &
            & EQUATIONS_SET_TRANSIENT_NAVIER_STOKES_SUBTYPE,EQUATIONS_SET_ALE_NAVIER_STOKES_SUBTYPE, &
            & EQUATIONS_SET_PGM_NAVIER_STOKES_SUBTYPE,EQUATIONS_SET_QUASISTATIC_NAVIER_STOKES_SUBTYPE, &
            & EQUATIONS_SET_STATIC_RBS_NAVIER_STOKES_SUBTYPE, &
            & EQUATIONS_SET_TRANSIENT_RBS_NAVIER_STOKES_SUBTYPE, &
            & EQUATIONS_SET_MULTISCALE3D_NAVIER_STOKES_SUBTYPE, &
            & EQUATIONS_SET_CONSTITUTIVE_MU_NAVIER_STOKES_SUBTYPE)
            SELECT CASE(EQUATIONS_SET_SETUP%ACTION_TYPE)
            !Set start action
            CASE(EQUATIONS_SET_SETUP_START_ACTION)
              IF(EQUATIONS_SET%DEPENDENT%DEPENDENT_FIELD_AUTO_CREATED) THEN
                !Create the auto created dependent field
                CALL FIELD_CREATE_START(EQUATIONS_SET_SETUP%FIELD_USER_NUMBER,EQUATIONS_SET%REGION, &
                  & EQUATIONS_SET%DEPENDENT%DEPENDENT_FIELD,ERR,ERROR,*999)
                CALL FIELD_LABEL_SET(EQUATIONS_SET%DEPENDENT%DEPENDENT_FIELD,"Dependent Field",ERR,ERROR,*999)
                CALL FIELD_TYPE_SET_AND_LOCK(EQUATIONS_SET%DEPENDENT%DEPENDENT_FIELD,FIELD_GENERAL_TYPE,ERR,ERROR,*999)
                CALL FIELD_DEPENDENT_TYPE_SET_AND_LOCK(EQUATIONS_SET%DEPENDENT%DEPENDENT_FIELD,FIELD_DEPENDENT_TYPE,ERR,ERROR,*999)
                CALL FIELD_MESH_DECOMPOSITION_GET(EQUATIONS_SET%GEOMETRY%GEOMETRIC_FIELD,GEOMETRIC_DECOMPOSITION,ERR,ERROR,*999)
                CALL FIELD_MESH_DECOMPOSITION_SET_AND_LOCK(EQUATIONS_SET%DEPENDENT%DEPENDENT_FIELD, &
                  & GEOMETRIC_DECOMPOSITION,ERR,ERROR,*999)
                CALL FIELD_GEOMETRIC_FIELD_SET_AND_LOCK(EQUATIONS_SET%DEPENDENT%DEPENDENT_FIELD,EQUATIONS_SET%GEOMETRY% &
                  & GEOMETRIC_FIELD,ERR,ERROR,*999)
                DEPENDENT_FIELD_NUMBER_OF_VARIABLES=2
                CALL FIELD_NUMBER_OF_VARIABLES_SET_AND_LOCK(EQUATIONS_SET%DEPENDENT%DEPENDENT_FIELD, &
                  & DEPENDENT_FIELD_NUMBER_OF_VARIABLES,ERR,ERROR,*999)
                CALL FIELD_VARIABLE_TYPES_SET_AND_LOCK(EQUATIONS_SET%DEPENDENT%DEPENDENT_FIELD,[FIELD_U_VARIABLE_TYPE, &
                  & FIELD_DELUDELN_VARIABLE_TYPE],ERR,ERROR,*999)
                CALL FIELD_VARIABLE_LABEL_SET(EQUATIONS_SET%DEPENDENT%DEPENDENT_FIELD,FIELD_U_VARIABLE_TYPE, &
                  & "U",ERR,ERROR,*999)
                CALL FIELD_VARIABLE_LABEL_SET(EQUATIONS_SET%DEPENDENT%DEPENDENT_FIELD,FIELD_DELUDELN_VARIABLE_TYPE, &
                  & "del U/del n",ERR,ERROR,*999)
                CALL FIELD_DIMENSION_SET_AND_LOCK(EQUATIONS_SET%DEPENDENT%DEPENDENT_FIELD,FIELD_U_VARIABLE_TYPE, &
                  & FIELD_VECTOR_DIMENSION_TYPE,ERR,ERROR,*999)
                CALL FIELD_DIMENSION_SET_AND_LOCK(EQUATIONS_SET%DEPENDENT%DEPENDENT_FIELD,FIELD_DELUDELN_VARIABLE_TYPE, &
                  & FIELD_VECTOR_DIMENSION_TYPE,ERR,ERROR,*999)
                CALL FIELD_DATA_TYPE_SET_AND_LOCK(EQUATIONS_SET%DEPENDENT%DEPENDENT_FIELD,FIELD_U_VARIABLE_TYPE, &
                  & FIELD_DP_TYPE,ERR,ERROR,*999)
                CALL FIELD_DATA_TYPE_SET_AND_LOCK(EQUATIONS_SET%DEPENDENT%DEPENDENT_FIELD,FIELD_DELUDELN_VARIABLE_TYPE, &
                  & FIELD_DP_TYPE,ERR,ERROR,*999)
                CALL FIELD_NUMBER_OF_COMPONENTS_GET(EQUATIONS_SET%GEOMETRY%GEOMETRIC_FIELD,FIELD_U_VARIABLE_TYPE, &
                  & NUMBER_OF_DIMENSIONS,ERR,ERROR,*999)
                !calculate number of components with one component for each dimension and one for pressure
                DEPENDENT_FIELD_NUMBER_OF_COMPONENTS=NUMBER_OF_DIMENSIONS+1
                CALL FIELD_NUMBER_OF_COMPONENTS_SET_AND_LOCK(EQUATIONS_SET%DEPENDENT%DEPENDENT_FIELD, &
                  & FIELD_U_VARIABLE_TYPE,DEPENDENT_FIELD_NUMBER_OF_COMPONENTS,ERR,ERROR,*999)
                CALL FIELD_NUMBER_OF_COMPONENTS_SET_AND_LOCK(EQUATIONS_SET%DEPENDENT%DEPENDENT_FIELD, &
                  & FIELD_DELUDELN_VARIABLE_TYPE,DEPENDENT_FIELD_NUMBER_OF_COMPONENTS,ERR,ERROR,*999)
                !Default to the geometric interpolation setup
                CALL FIELD_COMPONENT_MESH_COMPONENT_GET(EQUATIONS_SET%GEOMETRY%GEOMETRIC_FIELD,FIELD_U_VARIABLE_TYPE, & 
                  & 1,GEOMETRIC_MESH_COMPONENT,ERR,ERROR,*999)
                DO componentIdx=1,DEPENDENT_FIELD_NUMBER_OF_COMPONENTS
                  CALL FIELD_COMPONENT_MESH_COMPONENT_SET(EQUATIONS_SET%DEPENDENT%DEPENDENT_FIELD, & 
                    & FIELD_U_VARIABLE_TYPE,componentIdx,GEOMETRIC_MESH_COMPONENT,ERR,ERROR,*999)
                  CALL FIELD_COMPONENT_MESH_COMPONENT_SET(EQUATIONS_SET%DEPENDENT%DEPENDENT_FIELD, &
                    & FIELD_DELUDELN_VARIABLE_TYPE,componentIdx,GEOMETRIC_MESH_COMPONENT,ERR,ERROR,*999)
                END DO !componentIdx
                SELECT CASE(EQUATIONS_SET%SOLUTION_METHOD)
                CASE(EQUATIONS_SET_FEM_SOLUTION_METHOD)
                  DO componentIdx=1,DEPENDENT_FIELD_NUMBER_OF_COMPONENTS
                    CALL FIELD_COMPONENT_INTERPOLATION_SET_AND_LOCK(EQUATIONS_SET%DEPENDENT%DEPENDENT_FIELD, &
                      & FIELD_U_VARIABLE_TYPE,componentIdx,FIELD_NODE_BASED_INTERPOLATION,ERR,ERROR,*999)
                    CALL FIELD_COMPONENT_INTERPOLATION_SET_AND_LOCK(EQUATIONS_SET%DEPENDENT%DEPENDENT_FIELD, &
                      & FIELD_DELUDELN_VARIABLE_TYPE,componentIdx,FIELD_NODE_BASED_INTERPOLATION,ERR,ERROR,*999)
                  END DO !componentIdx
                  !Default geometric field scaling
                  CALL FIELD_SCALING_TYPE_GET(EQUATIONS_SET%GEOMETRY%GEOMETRIC_FIELD,GEOMETRIC_SCALING_TYPE,ERR,ERROR,*999)
                  CALL FIELD_SCALING_TYPE_SET(EQUATIONS_SET%DEPENDENT%DEPENDENT_FIELD,GEOMETRIC_SCALING_TYPE,ERR,ERROR,*999)
                !Other solutions not defined yet
                CASE(EQUATIONS_SET_BEM_SOLUTION_METHOD)
                  CALL FlagError("Not implemented.",ERR,ERROR,*999)
                CASE(EQUATIONS_SET_FD_SOLUTION_METHOD)
                  CALL FlagError("Not implemented.",ERR,ERROR,*999)
                CASE(EQUATIONS_SET_FV_SOLUTION_METHOD)
                  CALL FlagError("Not implemented.",ERR,ERROR,*999)
                CASE(EQUATIONS_SET_GFEM_SOLUTION_METHOD)
                  CALL FlagError("Not implemented.",ERR,ERROR,*999)
                CASE(EQUATIONS_SET_GFV_SOLUTION_METHOD)
                  CALL FlagError("Not implemented.",ERR,ERROR,*999)
                CASE DEFAULT
                  LOCAL_ERROR="The solution method of " &
                    & //TRIM(NUMBER_TO_VSTRING(EQUATIONS_SET%SOLUTION_METHOD,"*",ERR,ERROR))// " is invalid."
                  CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
                END SELECT
              ELSE 
                !Check the user specified field
                CALL FIELD_TYPE_CHECK(EQUATIONS_SET_SETUP%FIELD,FIELD_GENERAL_TYPE,ERR,ERROR,*999)
                CALL FIELD_DEPENDENT_TYPE_CHECK(EQUATIONS_SET_SETUP%FIELD,FIELD_DEPENDENT_TYPE,ERR,ERROR,*999)
                DEPENDENT_FIELD_NUMBER_OF_VARIABLES=2
                CALL FIELD_NUMBER_OF_VARIABLES_CHECK(EQUATIONS_SET_SETUP%FIELD,DEPENDENT_FIELD_NUMBER_OF_VARIABLES,ERR,ERROR,*999)
                CALL FIELD_VARIABLE_TYPES_CHECK(EQUATIONS_SET_SETUP%FIELD,[FIELD_U_VARIABLE_TYPE, &
                  & FIELD_DELUDELN_VARIABLE_TYPE],ERR,ERROR,*999)
                CALL FIELD_DATA_TYPE_CHECK(EQUATIONS_SET_SETUP%FIELD,FIELD_U_VARIABLE_TYPE,FIELD_DP_TYPE,ERR,ERROR,*999)
                CALL FIELD_DATA_TYPE_CHECK(EQUATIONS_SET_SETUP%FIELD,FIELD_DELUDELN_VARIABLE_TYPE,FIELD_DP_TYPE, &
                  & ERR,ERROR,*999)
                CALL FIELD_DIMENSION_CHECK(EQUATIONS_SET_SETUP%FIELD,FIELD_U_VARIABLE_TYPE,FIELD_VECTOR_DIMENSION_TYPE, &
                  & ERR,ERROR,*999)
                CALL FIELD_DIMENSION_CHECK(EQUATIONS_SET_SETUP%FIELD,FIELD_DELUDELN_VARIABLE_TYPE, &
                  & FIELD_VECTOR_DIMENSION_TYPE,ERR,ERROR,*999)
                CALL FIELD_NUMBER_OF_COMPONENTS_GET(EQUATIONS_SET%GEOMETRY%GEOMETRIC_FIELD,FIELD_U_VARIABLE_TYPE, &
                  & NUMBER_OF_DIMENSIONS,ERR,ERROR,*999)
                !calculate number of components with one component for each dimension and one for pressure
                DEPENDENT_FIELD_NUMBER_OF_COMPONENTS=NUMBER_OF_DIMENSIONS+1
                CALL FIELD_NUMBER_OF_COMPONENTS_CHECK(EQUATIONS_SET_SETUP%FIELD,FIELD_U_VARIABLE_TYPE, &
                  & DEPENDENT_FIELD_NUMBER_OF_COMPONENTS,ERR,ERROR,*999)
                CALL FIELD_NUMBER_OF_COMPONENTS_CHECK(EQUATIONS_SET_SETUP%FIELD,FIELD_DELUDELN_VARIABLE_TYPE, &
                  & DEPENDENT_FIELD_NUMBER_OF_COMPONENTS,ERR,ERROR,*999)
                SELECT CASE(EQUATIONS_SET%SOLUTION_METHOD)
                CASE(EQUATIONS_SET_FEM_SOLUTION_METHOD)
                  DO componentIdx=1,DEPENDENT_FIELD_NUMBER_OF_COMPONENTS
                    CALL FIELD_COMPONENT_INTERPOLATION_CHECK(EQUATIONS_SET_SETUP%FIELD,FIELD_U_VARIABLE_TYPE, &
                      & componentIdx,FIELD_NODE_BASED_INTERPOLATION,ERR,ERROR,*999)
                    CALL FIELD_COMPONENT_INTERPOLATION_CHECK(EQUATIONS_SET_SETUP%FIELD,FIELD_DELUDELN_VARIABLE_TYPE, & 
                      & componentIdx,FIELD_NODE_BASED_INTERPOLATION,ERR,ERROR,*999)
                  END DO !componentIdx
                CASE(EQUATIONS_SET_BEM_SOLUTION_METHOD)
                  CALL FlagError("Not implemented.",ERR,ERROR,*999)
                CASE(EQUATIONS_SET_FD_SOLUTION_METHOD)
                  CALL FlagError("Not implemented.",ERR,ERROR,*999)
                CASE(EQUATIONS_SET_FV_SOLUTION_METHOD)
                  CALL FlagError("Not implemented.",ERR,ERROR,*999)
                CASE(EQUATIONS_SET_GFEM_SOLUTION_METHOD)
                  CALL FlagError("Not implemented.",ERR,ERROR,*999)
                CASE(EQUATIONS_SET_GFV_SOLUTION_METHOD)
                  CALL FlagError("Not implemented.",ERR,ERROR,*999)
                CASE DEFAULT
                  LOCAL_ERROR="The solution method of "//TRIM(NUMBER_TO_VSTRING(EQUATIONS_SET%SOLUTION_METHOD, &
                    & "*",ERR,ERROR))//" is invalid."
                  CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
                END SELECT
              END IF
            !Specify finish action
            CASE(EQUATIONS_SET_SETUP_FINISH_ACTION)
              IF(EQUATIONS_SET%DEPENDENT%DEPENDENT_FIELD_AUTO_CREATED) THEN
                CALL FIELD_CREATE_FINISH(EQUATIONS_SET%DEPENDENT%DEPENDENT_FIELD,ERR,ERROR,*999)
                CALL FIELD_NUMBER_OF_COMPONENTS_GET(EQUATIONS_SET%DEPENDENT%DEPENDENT_FIELD,FIELD_U_VARIABLE_TYPE, &
                  & DEPENDENT_FIELD_NUMBER_OF_COMPONENTS,ERR,ERROR,*999)
                IF(EQUATIONS_SET%specification(3)==EQUATIONS_SET_STATIC_RBS_NAVIER_STOKES_SUBTYPE .OR. &
                 & EQUATIONS_SET%specification(3)==EQUATIONS_SET_TRANSIENT_RBS_NAVIER_STOKES_SUBTYPE .OR. &
                 & EQUATIONS_SET%specification(3)==EQUATIONS_SET_MULTISCALE3D_NAVIER_STOKES_SUBTYPE) THEN
                  CALL FIELD_PARAMETER_SET_CREATE(EQUATIONS_SET%DEPENDENT%DEPENDENT_FIELD,FIELD_U_VARIABLE_TYPE, &
                    & FIELD_PRESSURE_VALUES_SET_TYPE,ERR,ERROR,*999)
                  DO componentIdx=1,DEPENDENT_FIELD_NUMBER_OF_COMPONENTS
                    CALL FIELD_COMPONENT_VALUES_INITIALISE(EQUATIONS_SET%DEPENDENT%DEPENDENT_FIELD,FIELD_U_VARIABLE_TYPE, &
                      & FIELD_PRESSURE_VALUES_SET_TYPE,componentIdx,0.0_DP,ERR,ERROR,*999)
                  END DO
                END IF
              END IF
            CASE DEFAULT
              LOCAL_ERROR="The action type of "//TRIM(NUMBER_TO_VSTRING(EQUATIONS_SET_SETUP%ACTION_TYPE,"*", & 
                & ERR,ERROR))//" for a setup type of "//TRIM(NUMBER_TO_VSTRING(EQUATIONS_SET_SETUP%SETUP_TYPE, & 
                & "*",ERR,ERROR))//" is invalid for a Navier-Stokes fluid."
              CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
            END SELECT
          CASE(EQUATIONS_SET_TRANSIENT1D_NAVIER_STOKES_SUBTYPE, &
               EQUATIONS_SET_TRANSIENT1D_ADV_NAVIER_STOKES_SUBTYPE)
            SELECT CASE(EQUATIONS_SET_SETUP%ACTION_TYPE)
            !Set start action
            CASE(EQUATIONS_SET_SETUP_START_ACTION)
              !set number of variables to 5 (U,DELUDELN,V,U1,U2)
              DEPENDENT_FIELD_NUMBER_OF_VARIABLES=5
              !calculate number of components (Q,A) for U and dUdN
              DEPENDENT_FIELD_NUMBER_OF_COMPONENTS=2
              IF(EQUATIONS_SET%DEPENDENT%DEPENDENT_FIELD_AUTO_CREATED) THEN
                !Create the auto created dependent field
                !start field creation with name 'DEPENDENT_FIELD'
                CALL FIELD_CREATE_START(EQUATIONS_SET_SETUP%FIELD_USER_NUMBER,EQUATIONS_SET%REGION, &
                  & EQUATIONS_SET%DEPENDENT%DEPENDENT_FIELD,ERR,ERROR,*999)
                !start creation of a new field
                CALL FIELD_TYPE_SET_AND_LOCK(EQUATIONS_SET%DEPENDENT%DEPENDENT_FIELD,FIELD_GENERAL_TYPE,ERR,ERROR,*999)
                !label the field
                CALL FIELD_LABEL_SET(EQUATIONS_SET%DEPENDENT%DEPENDENT_FIELD,"Dependent Field",ERR,ERROR,*999)
                !define new created field to be dependent
                CALL FIELD_DEPENDENT_TYPE_SET_AND_LOCK(EQUATIONS_SET%DEPENDENT%DEPENDENT_FIELD, &
                  & FIELD_DEPENDENT_TYPE,ERR,ERROR,*999)
                !look for decomposition rule already defined
                CALL FIELD_MESH_DECOMPOSITION_GET(EQUATIONS_SET%GEOMETRY%GEOMETRIC_FIELD,GEOMETRIC_DECOMPOSITION, &
                  & ERR,ERROR,*999)
                !apply decomposition rule found on new created field
                CALL FIELD_MESH_DECOMPOSITION_SET_AND_LOCK(EQUATIONS_SET%DEPENDENT%DEPENDENT_FIELD, &
                  & GEOMETRIC_DECOMPOSITION,ERR,ERROR,*999)
                !point new field to geometric field
                CALL FIELD_GEOMETRIC_FIELD_SET_AND_LOCK(EQUATIONS_SET%DEPENDENT%DEPENDENT_FIELD,EQUATIONS_SET%GEOMETRY% &
                  & GEOMETRIC_FIELD,ERR,ERROR,*999)                  
                !set number of variables to 6 (U,DELUDELN,V,U1,U2)
                CALL FIELD_NUMBER_OF_VARIABLES_SET_AND_LOCK(EQUATIONS_SET%DEPENDENT%DEPENDENT_FIELD, &
                  & DEPENDENT_FIELD_NUMBER_OF_VARIABLES,ERR,ERROR,*999)
                CALL FIELD_VARIABLE_TYPES_SET_AND_LOCK(EQUATIONS_SET%DEPENDENT%DEPENDENT_FIELD,[FIELD_U_VARIABLE_TYPE, &
                  & FIELD_DELUDELN_VARIABLE_TYPE,FIELD_V_VARIABLE_TYPE,FIELD_U1_VARIABLE_TYPE,FIELD_U2_VARIABLE_TYPE], &
                  & ERR,ERROR,*999)
                CALL FIELD_DIMENSION_SET_AND_LOCK(EQUATIONS_SET%DEPENDENT%DEPENDENT_FIELD,FIELD_U_VARIABLE_TYPE, &
                  & FIELD_VECTOR_DIMENSION_TYPE,ERR,ERROR,*999)
                CALL FIELD_DIMENSION_SET_AND_LOCK(EQUATIONS_SET%DEPENDENT%DEPENDENT_FIELD,FIELD_DELUDELN_VARIABLE_TYPE, &
                  & FIELD_VECTOR_DIMENSION_TYPE,ERR,ERROR,*999)
                CALL FIELD_DIMENSION_SET_AND_LOCK(EQUATIONS_SET%DEPENDENT%DEPENDENT_FIELD,FIELD_V_VARIABLE_TYPE, &
                  & FIELD_VECTOR_DIMENSION_TYPE,ERR,ERROR,*999)
                CALL FIELD_DIMENSION_SET_AND_LOCK(EQUATIONS_SET%DEPENDENT%DEPENDENT_FIELD,FIELD_U1_VARIABLE_TYPE, &
                  & FIELD_VECTOR_DIMENSION_TYPE,ERR,ERROR,*999)
                CALL FIELD_DIMENSION_SET_AND_LOCK(EQUATIONS_SET%DEPENDENT%DEPENDENT_FIELD,FIELD_U2_VARIABLE_TYPE, &
                  & FIELD_VECTOR_DIMENSION_TYPE,ERR,ERROR,*999)
                !set data type
                CALL FIELD_DATA_TYPE_SET_AND_LOCK(EQUATIONS_SET%DEPENDENT%DEPENDENT_FIELD,FIELD_U_VARIABLE_TYPE, &
                  & FIELD_DP_TYPE,ERR,ERROR,*999)
                CALL FIELD_DATA_TYPE_SET_AND_LOCK(EQUATIONS_SET%DEPENDENT%DEPENDENT_FIELD,FIELD_DELUDELN_VARIABLE_TYPE, &
                  & FIELD_DP_TYPE,ERR,ERROR,*999)
                CALL FIELD_DATA_TYPE_SET_AND_LOCK(EQUATIONS_SET%DEPENDENT%DEPENDENT_FIELD,FIELD_V_VARIABLE_TYPE, &
                  & FIELD_DP_TYPE,ERR,ERROR,*999)
                CALL FIELD_DATA_TYPE_SET_AND_LOCK(EQUATIONS_SET%DEPENDENT%DEPENDENT_FIELD,FIELD_U1_VARIABLE_TYPE, &
                  & FIELD_DP_TYPE,ERR,ERROR,*999)
                CALL FIELD_DATA_TYPE_SET_AND_LOCK(EQUATIONS_SET%DEPENDENT%DEPENDENT_FIELD,FIELD_U2_VARIABLE_TYPE, &
                  & FIELD_DP_TYPE,ERR,ERROR,*999)
                  
                CALL FIELD_NUMBER_OF_COMPONENTS_GET(EQUATIONS_SET%GEOMETRY%GEOMETRIC_FIELD,FIELD_U_VARIABLE_TYPE, &
                  & NUMBER_OF_DIMENSIONS,ERR,ERROR,*999)
               !calculate number of components
                CALL FIELD_NUMBER_OF_COMPONENTS_SET_AND_LOCK(EQUATIONS_SET%DEPENDENT%DEPENDENT_FIELD, &
                  & FIELD_U_VARIABLE_TYPE,DEPENDENT_FIELD_NUMBER_OF_COMPONENTS,ERR,ERROR,*999)
                CALL FIELD_NUMBER_OF_COMPONENTS_SET_AND_LOCK(EQUATIONS_SET%DEPENDENT%DEPENDENT_FIELD, &
                  & FIELD_DELUDELN_VARIABLE_TYPE,DEPENDENT_FIELD_NUMBER_OF_COMPONENTS,ERR,ERROR,*999)
                ! 2 component (W1,W2) for V
                CALL FIELD_NUMBER_OF_COMPONENTS_SET_AND_LOCK(EQUATIONS_SET%DEPENDENT%DEPENDENT_FIELD, &
                  & FIELD_V_VARIABLE_TYPE,DEPENDENT_FIELD_NUMBER_OF_COMPONENTS,ERR,ERROR,*999)
                CALL FIELD_NUMBER_OF_COMPONENTS_SET_AND_LOCK(EQUATIONS_SET%DEPENDENT%DEPENDENT_FIELD, &
                  & FIELD_U1_VARIABLE_TYPE,DEPENDENT_FIELD_NUMBER_OF_COMPONENTS,ERR,ERROR,*999)
                CALL FIELD_NUMBER_OF_COMPONENTS_SET_AND_LOCK(EQUATIONS_SET%DEPENDENT%DEPENDENT_FIELD, &
                  & FIELD_U2_VARIABLE_TYPE,DEPENDENT_FIELD_NUMBER_OF_COMPONENTS,ERR,ERROR,*999)
                CALL FIELD_COMPONENT_MESH_COMPONENT_GET(EQUATIONS_SET%GEOMETRY%GEOMETRIC_FIELD,FIELD_U_VARIABLE_TYPE, & 
                  & NUMBER_OF_DIMENSIONS,GEOMETRIC_MESH_COMPONENT,ERR,ERROR,*999)
                !Default to the geometric interpolation setup
                DO I=1,DEPENDENT_FIELD_NUMBER_OF_COMPONENTS
                  CALL FIELD_COMPONENT_MESH_COMPONENT_SET(EQUATIONS_SET%DEPENDENT%DEPENDENT_FIELD, & 
                    & FIELD_U_VARIABLE_TYPE,I,GEOMETRIC_MESH_COMPONENT,ERR,ERROR,*999)
                  CALL FIELD_COMPONENT_MESH_COMPONENT_SET(EQUATIONS_SET%DEPENDENT%DEPENDENT_FIELD, &
                    & FIELD_DELUDELN_VARIABLE_TYPE,I,GEOMETRIC_MESH_COMPONENT,ERR,ERROR,*999)
                  CALL FIELD_COMPONENT_MESH_COMPONENT_SET(EQUATIONS_SET%DEPENDENT%DEPENDENT_FIELD, & 
                    & FIELD_V_VARIABLE_TYPE,I,GEOMETRIC_MESH_COMPONENT,ERR,ERROR,*999)
                  CALL FIELD_COMPONENT_MESH_COMPONENT_SET(EQUATIONS_SET%DEPENDENT%DEPENDENT_FIELD, &
                    & FIELD_U1_VARIABLE_TYPE,I,GEOMETRIC_MESH_COMPONENT,ERR,ERROR,*999)
                  CALL FIELD_COMPONENT_MESH_COMPONENT_SET(EQUATIONS_SET%DEPENDENT%DEPENDENT_FIELD, &
                    & FIELD_U2_VARIABLE_TYPE,I,GEOMETRIC_MESH_COMPONENT,ERR,ERROR,*999)
                END DO
                SELECT CASE(EQUATIONS_SET%SOLUTION_METHOD)
                !Specify fem solution method
                CASE(EQUATIONS_SET_FEM_SOLUTION_METHOD)
                  DO I=1,DEPENDENT_FIELD_NUMBER_OF_COMPONENTS
                    CALL FIELD_COMPONENT_INTERPOLATION_SET_AND_LOCK(EQUATIONS_SET%DEPENDENT%DEPENDENT_FIELD, &
                      & FIELD_U_VARIABLE_TYPE,I,FIELD_NODE_BASED_INTERPOLATION,ERR,ERROR,*999)
                    CALL FIELD_COMPONENT_INTERPOLATION_SET_AND_LOCK(EQUATIONS_SET%DEPENDENT%DEPENDENT_FIELD, &
                      & FIELD_DELUDELN_VARIABLE_TYPE,I,FIELD_NODE_BASED_INTERPOLATION,ERR,ERROR,*999)
                    CALL FIELD_COMPONENT_INTERPOLATION_SET_AND_LOCK(EQUATIONS_SET%DEPENDENT%DEPENDENT_FIELD, &
                        & FIELD_U1_VARIABLE_TYPE,1,FIELD_NODE_BASED_INTERPOLATION,ERR,ERROR,*999)
                    CALL FIELD_COMPONENT_INTERPOLATION_SET_AND_LOCK(EQUATIONS_SET%DEPENDENT%DEPENDENT_FIELD, &
                        & FIELD_U2_VARIABLE_TYPE,1,FIELD_NODE_BASED_INTERPOLATION,ERR,ERROR,*999)
                  END DO
                  CALL FIELD_SCALING_TYPE_GET(EQUATIONS_SET%GEOMETRY%GEOMETRIC_FIELD,GEOMETRIC_SCALING_TYPE, &
                    & ERR,ERROR,*999)
                  CALL FIELD_SCALING_TYPE_SET(EQUATIONS_SET%DEPENDENT%DEPENDENT_FIELD,GEOMETRIC_SCALING_TYPE, &
                    & ERR,ERROR,*999)
                CASE(EQUATIONS_SET_BEM_SOLUTION_METHOD)
                  CALL FlagError("Not implemented.",ERR,ERROR,*999)
                CASE(EQUATIONS_SET_FD_SOLUTION_METHOD)
                  CALL FlagError("Not implemented.",ERR,ERROR,*999)
                CASE(EQUATIONS_SET_FV_SOLUTION_METHOD)
                  CALL FlagError("Not implemented.",ERR,ERROR,*999)
                CASE(EQUATIONS_SET_GFEM_SOLUTION_METHOD)
                  CALL FlagError("Not implemented.",ERR,ERROR,*999)
                CASE(EQUATIONS_SET_GFV_SOLUTION_METHOD)
                  CALL FlagError("Not implemented.",ERR,ERROR,*999)
                CASE DEFAULT
                  LOCAL_ERROR="The solution method of " &
                    & //TRIM(NUMBER_TO_VSTRING(EQUATIONS_SET%SOLUTION_METHOD,"*",ERR,ERROR))// " is invalid."
                  CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
                END SELECT
              ELSE 
                !Check the user specified field- Characteristic equations
                CALL FIELD_TYPE_CHECK(EQUATIONS_SET_SETUP%FIELD,FIELD_GENERAL_TYPE,ERR,ERROR,*999)
                CALL FIELD_DEPENDENT_TYPE_CHECK(EQUATIONS_SET_SETUP%FIELD,FIELD_DEPENDENT_TYPE,ERR,ERROR,*999)
                CALL FIELD_NUMBER_OF_VARIABLES_CHECK(EQUATIONS_SET_SETUP%FIELD,DEPENDENT_FIELD_NUMBER_OF_VARIABLES, &
                  & ERR,ERROR,*999)
                CALL FIELD_VARIABLE_TYPES_CHECK(EQUATIONS_SET_SETUP%FIELD,[FIELD_U_VARIABLE_TYPE, &
                  & FIELD_DELUDELN_VARIABLE_TYPE,FIELD_V_VARIABLE_TYPE,FIELD_U1_VARIABLE_TYPE,FIELD_U2_VARIABLE_TYPE], &
                  & ERR,ERROR,*999)
                CALL FIELD_DIMENSION_CHECK(EQUATIONS_SET_SETUP%FIELD,FIELD_U_VARIABLE_TYPE, & 
                  & FIELD_VECTOR_DIMENSION_TYPE,ERR,ERROR,*999)
                CALL FIELD_DIMENSION_CHECK(EQUATIONS_SET_SETUP%FIELD,FIELD_DELUDELN_VARIABLE_TYPE, &
                  & FIELD_VECTOR_DIMENSION_TYPE,ERR,ERROR,*999)
                CALL FIELD_DIMENSION_CHECK(EQUATIONS_SET_SETUP%FIELD,FIELD_V_VARIABLE_TYPE, &
                  & FIELD_VECTOR_DIMENSION_TYPE,ERR,ERROR,*999)
                CALL FIELD_DIMENSION_CHECK(EQUATIONS_SET_SETUP%FIELD,FIELD_U1_VARIABLE_TYPE, &
                  & FIELD_VECTOR_DIMENSION_TYPE,ERR,ERROR,*999)
                CALL FIELD_DIMENSION_CHECK(EQUATIONS_SET_SETUP%FIELD,FIELD_U2_VARIABLE_TYPE, &
                  & FIELD_VECTOR_DIMENSION_TYPE,ERR,ERROR,*999)

                CALL FIELD_DATA_TYPE_CHECK(EQUATIONS_SET_SETUP%FIELD,FIELD_U_VARIABLE_TYPE,FIELD_DP_TYPE,ERR,ERROR,*999)
                CALL FIELD_DATA_TYPE_CHECK(EQUATIONS_SET_SETUP%FIELD,FIELD_DELUDELN_VARIABLE_TYPE,FIELD_DP_TYPE, &
                  & ERR,ERROR,*999)
                CALL FIELD_DATA_TYPE_CHECK(EQUATIONS_SET_SETUP%FIELD,FIELD_V_VARIABLE_TYPE,FIELD_DP_TYPE,ERR,ERROR,*999)
                CALL FIELD_DATA_TYPE_CHECK(EQUATIONS_SET_SETUP%FIELD,FIELD_U1_VARIABLE_TYPE,FIELD_DP_TYPE,ERR,ERROR,*999)
                CALL FIELD_DATA_TYPE_CHECK(EQUATIONS_SET_SETUP%FIELD,FIELD_U2_VARIABLE_TYPE,FIELD_DP_TYPE,ERR,ERROR,*999)
                CALL FIELD_NUMBER_OF_COMPONENTS_GET(EQUATIONS_SET%GEOMETRY%GEOMETRIC_FIELD,FIELD_U_VARIABLE_TYPE, &
                  & NUMBER_OF_DIMENSIONS,ERR,ERROR,*999)
                !calculate number of components (Q,A) for U and dUdN
                CALL FIELD_NUMBER_OF_COMPONENTS_CHECK(EQUATIONS_SET_SETUP%FIELD,FIELD_U_VARIABLE_TYPE, &
                  & DEPENDENT_FIELD_NUMBER_OF_COMPONENTS,ERR,ERROR,*999)
                CALL FIELD_NUMBER_OF_COMPONENTS_CHECK(EQUATIONS_SET_SETUP%FIELD,FIELD_DELUDELN_VARIABLE_TYPE, &
                  & DEPENDENT_FIELD_NUMBER_OF_COMPONENTS,ERR,ERROR,*999)
                ! 2 component (W1,W2) for V
                CALL FIELD_NUMBER_OF_COMPONENTS_CHECK(EQUATIONS_SET_SETUP%FIELD,FIELD_V_VARIABLE_TYPE, &
                  & DEPENDENT_FIELD_NUMBER_OF_COMPONENTS,ERR,ERROR,*999)
                CALL FIELD_NUMBER_OF_COMPONENTS_CHECK(EQUATIONS_SET_SETUP%FIELD,FIELD_U1_VARIABLE_TYPE, &
                  & DEPENDENT_FIELD_NUMBER_OF_COMPONENTS,ERR,ERROR,*999)
                CALL FIELD_NUMBER_OF_COMPONENTS_CHECK(EQUATIONS_SET_SETUP%FIELD,FIELD_U2_VARIABLE_TYPE, &
                  & DEPENDENT_FIELD_NUMBER_OF_COMPONENTS,ERR,ERROR,*999)
                SELECT CASE(EQUATIONS_SET%SOLUTION_METHOD)
                CASE(EQUATIONS_SET_FEM_SOLUTION_METHOD)
                  CALL FIELD_COMPONENT_INTERPOLATION_CHECK(EQUATIONS_SET_SETUP%FIELD,FIELD_U_VARIABLE_TYPE,1, &
                    & FIELD_NODE_BASED_INTERPOLATION,ERR,ERROR,*999)
                  CALL FIELD_COMPONENT_INTERPOLATION_CHECK(EQUATIONS_SET_SETUP%FIELD,FIELD_DELUDELN_VARIABLE_TYPE,1, &
                    & FIELD_NODE_BASED_INTERPOLATION,ERR,ERROR,*999)
                  CALL FIELD_COMPONENT_INTERPOLATION_CHECK(EQUATIONS_SET_SETUP%FIELD,FIELD_V_VARIABLE_TYPE,1, &
                    & FIELD_NODE_BASED_INTERPOLATION,ERR,ERROR,*999)
                  CALL FIELD_COMPONENT_INTERPOLATION_CHECK(EQUATIONS_SET_SETUP%FIELD,FIELD_U1_VARIABLE_TYPE,1, &
                    & FIELD_NODE_BASED_INTERPOLATION,ERR,ERROR,*999)
                  CALL FIELD_COMPONENT_INTERPOLATION_CHECK(EQUATIONS_SET_SETUP%FIELD,FIELD_U2_VARIABLE_TYPE,1, &
                    & FIELD_NODE_BASED_INTERPOLATION,ERR,ERROR,*999)
                CASE(EQUATIONS_SET_BEM_SOLUTION_METHOD)
                  CALL FlagError("Not implemented.",ERR,ERROR,*999)
                CASE(EQUATIONS_SET_FD_SOLUTION_METHOD)
                  CALL FlagError("Not implemented.",ERR,ERROR,*999)
                CASE(EQUATIONS_SET_FV_SOLUTION_METHOD)
                  CALL FlagError("Not implemented.",ERR,ERROR,*999)
                CASE(EQUATIONS_SET_GFEM_SOLUTION_METHOD)
                  CALL FlagError("Not implemented.",ERR,ERROR,*999)
                CASE(EQUATIONS_SET_GFV_SOLUTION_METHOD)
                  CALL FlagError("Not implemented.",ERR,ERROR,*999)
                CASE DEFAULT
                  LOCAL_ERROR="The solution method of "//TRIM(NUMBER_TO_VSTRING(EQUATIONS_SET%SOLUTION_METHOD, &
                    & "*",ERR,ERROR))//" is invalid."
                  CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
                END SELECT
              END IF
            !Specify finish action
            CASE(EQUATIONS_SET_SETUP_FINISH_ACTION)
              IF(EQUATIONS_SET%DEPENDENT%DEPENDENT_FIELD_AUTO_CREATED) THEN
                CALL FIELD_CREATE_FINISH(EQUATIONS_SET%DEPENDENT%DEPENDENT_FIELD,ERR,ERROR,*999)
              END IF
            CASE DEFAULT
              LOCAL_ERROR="The action type of "//TRIM(NUMBER_TO_VSTRING(EQUATIONS_SET_SETUP%ACTION_TYPE,"*", & 
                & ERR,ERROR))//" for a setup type of "//TRIM(NUMBER_TO_VSTRING(EQUATIONS_SET_SETUP%SETUP_TYPE, & 
                & "*",ERR,ERROR))//" is invalid for a Navier-Stokes fluid."
              CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
            END SELECT
          CASE(EQUATIONS_SET_COUPLED1D0D_NAVIER_STOKES_SUBTYPE, &
             & EQUATIONS_SET_COUPLED1D0D_ADV_NAVIER_STOKES_SUBTYPE)
            SELECT CASE(EQUATIONS_SET_SETUP%ACTION_TYPE)
            !Set start action
            CASE(EQUATIONS_SET_SETUP_START_ACTION)
              IF(EQUATIONS_SET%DEPENDENT%DEPENDENT_FIELD_AUTO_CREATED) THEN
                !Create the auto created dependent field
                !start field creation with name 'DEPENDENT_FIELD'
                CALL FIELD_CREATE_START(EQUATIONS_SET_SETUP%FIELD_USER_NUMBER,EQUATIONS_SET%REGION, &
                  & EQUATIONS_SET%DEPENDENT%DEPENDENT_FIELD,ERR,ERROR,*999)
                !start creation of a new field
                CALL FIELD_TYPE_SET_AND_LOCK(EQUATIONS_SET%DEPENDENT%DEPENDENT_FIELD,FIELD_GENERAL_TYPE,ERR,ERROR,*999)
                !label the field
                CALL FIELD_LABEL_SET(EQUATIONS_SET%DEPENDENT%DEPENDENT_FIELD,"Dependent Field",ERR,ERROR,*999)
                !define new created field to be dependent
                CALL FIELD_DEPENDENT_TYPE_SET_AND_LOCK(EQUATIONS_SET%DEPENDENT%DEPENDENT_FIELD, &
                  & FIELD_DEPENDENT_TYPE,ERR,ERROR,*999)
                !look for decomposition rule already defined
                CALL FIELD_MESH_DECOMPOSITION_GET(EQUATIONS_SET%GEOMETRY%GEOMETRIC_FIELD,GEOMETRIC_DECOMPOSITION, &
                  & ERR,ERROR,*999)
                !apply decomposition rule found on new created field
                CALL FIELD_MESH_DECOMPOSITION_SET_AND_LOCK(EQUATIONS_SET%DEPENDENT%DEPENDENT_FIELD, &
                  & GEOMETRIC_DECOMPOSITION,ERR,ERROR,*999)
                !point new field to geometric field
                CALL FIELD_GEOMETRIC_FIELD_SET_AND_LOCK(EQUATIONS_SET%DEPENDENT%DEPENDENT_FIELD,EQUATIONS_SET%GEOMETRY% &
                  & GEOMETRIC_FIELD,ERR,ERROR,*999)
                !set number of variables to 5 (U,DELUDELN,V,U1,U2)
                DEPENDENT_FIELD_NUMBER_OF_VARIABLES=5
                CALL FIELD_NUMBER_OF_VARIABLES_SET_AND_LOCK(EQUATIONS_SET%DEPENDENT%DEPENDENT_FIELD, &
                  & DEPENDENT_FIELD_NUMBER_OF_VARIABLES,ERR,ERROR,*999)
                IF(EQUATIONS_SET%specification(3)==EQUATIONS_SET_COUPLED1D0D_ADV_NAVIER_STOKES_SUBTYPE) THEN
                  CALL FIELD_VARIABLE_TYPES_SET_AND_LOCK(EQUATIONS_SET%DEPENDENT%DEPENDENT_FIELD,[FIELD_U_VARIABLE_TYPE, &
                    & FIELD_DELUDELN_VARIABLE_TYPE,FIELD_V_VARIABLE_TYPE,FIELD_U1_VARIABLE_TYPE,FIELD_U2_VARIABLE_TYPE, &
                    & FIELD_U3_VARIABLE_TYPE],ERR,ERROR,*999)
                ELSE
                  CALL FIELD_VARIABLE_TYPES_SET_AND_LOCK(EQUATIONS_SET%DEPENDENT%DEPENDENT_FIELD,[FIELD_U_VARIABLE_TYPE, &
                    & FIELD_DELUDELN_VARIABLE_TYPE,FIELD_V_VARIABLE_TYPE,FIELD_U1_VARIABLE_TYPE,FIELD_U2_VARIABLE_TYPE], &
                    & ERR,ERROR,*999)
                END IF
                CALL FIELD_DIMENSION_SET_AND_LOCK(EQUATIONS_SET%DEPENDENT%DEPENDENT_FIELD,FIELD_U_VARIABLE_TYPE, &
                  & FIELD_VECTOR_DIMENSION_TYPE,ERR,ERROR,*999)
                CALL FIELD_DIMENSION_SET_AND_LOCK(EQUATIONS_SET%DEPENDENT%DEPENDENT_FIELD,FIELD_DELUDELN_VARIABLE_TYPE, &
                  & FIELD_VECTOR_DIMENSION_TYPE,ERR,ERROR,*999)
                CALL FIELD_DIMENSION_SET_AND_LOCK(EQUATIONS_SET%DEPENDENT%DEPENDENT_FIELD,FIELD_V_VARIABLE_TYPE, &
                  & FIELD_VECTOR_DIMENSION_TYPE,ERR,ERROR,*999)
                CALL FIELD_DIMENSION_SET_AND_LOCK(EQUATIONS_SET%DEPENDENT%DEPENDENT_FIELD,FIELD_U1_VARIABLE_TYPE, &
                  & FIELD_VECTOR_DIMENSION_TYPE,ERR,ERROR,*999)
                CALL FIELD_DIMENSION_SET_AND_LOCK(EQUATIONS_SET%DEPENDENT%DEPENDENT_FIELD,FIELD_U2_VARIABLE_TYPE, &
                  & FIELD_VECTOR_DIMENSION_TYPE,ERR,ERROR,*999)
                CALL FIELD_DATA_TYPE_SET_AND_LOCK(EQUATIONS_SET%DEPENDENT%DEPENDENT_FIELD,FIELD_U_VARIABLE_TYPE, &
                  & FIELD_DP_TYPE,ERR,ERROR,*999)
                CALL FIELD_DATA_TYPE_SET_AND_LOCK(EQUATIONS_SET%DEPENDENT%DEPENDENT_FIELD,FIELD_DELUDELN_VARIABLE_TYPE, &
                  & FIELD_DP_TYPE,ERR,ERROR,*999)
                CALL FIELD_DATA_TYPE_SET_AND_LOCK(EQUATIONS_SET%DEPENDENT%DEPENDENT_FIELD,FIELD_V_VARIABLE_TYPE, &
                  & FIELD_DP_TYPE,ERR,ERROR,*999)
                CALL FIELD_DATA_TYPE_SET_AND_LOCK(EQUATIONS_SET%DEPENDENT%DEPENDENT_FIELD,FIELD_U1_VARIABLE_TYPE, &
                  & FIELD_DP_TYPE,ERR,ERROR,*999)
                CALL FIELD_DATA_TYPE_SET_AND_LOCK(EQUATIONS_SET%DEPENDENT%DEPENDENT_FIELD,FIELD_U2_VARIABLE_TYPE, &
                  & FIELD_DP_TYPE,ERR,ERROR,*999)
                CALL FIELD_NUMBER_OF_COMPONENTS_GET(EQUATIONS_SET%GEOMETRY%GEOMETRIC_FIELD,FIELD_U_VARIABLE_TYPE, &
                  & NUMBER_OF_DIMENSIONS,ERR,ERROR,*999)
                !calculate number of components (Q,A)
                DEPENDENT_FIELD_NUMBER_OF_COMPONENTS=2
                CALL FIELD_NUMBER_OF_COMPONENTS_SET_AND_LOCK(EQUATIONS_SET%DEPENDENT%DEPENDENT_FIELD, &
                  & FIELD_U_VARIABLE_TYPE,DEPENDENT_FIELD_NUMBER_OF_COMPONENTS,ERR,ERROR,*999)
                CALL FIELD_NUMBER_OF_COMPONENTS_SET_AND_LOCK(EQUATIONS_SET%DEPENDENT%DEPENDENT_FIELD, &
                  & FIELD_DELUDELN_VARIABLE_TYPE,DEPENDENT_FIELD_NUMBER_OF_COMPONENTS,ERR,ERROR,*999)
                CALL FIELD_NUMBER_OF_COMPONENTS_SET_AND_LOCK(EQUATIONS_SET%DEPENDENT%DEPENDENT_FIELD, &
                  & FIELD_V_VARIABLE_TYPE,DEPENDENT_FIELD_NUMBER_OF_COMPONENTS,ERR,ERROR,*999)
                CALL FIELD_NUMBER_OF_COMPONENTS_SET_AND_LOCK(EQUATIONS_SET%DEPENDENT%DEPENDENT_FIELD, &
                  & FIELD_U1_VARIABLE_TYPE,1,ERR,ERROR,*999)
                CALL FIELD_NUMBER_OF_COMPONENTS_SET_AND_LOCK(EQUATIONS_SET%DEPENDENT%DEPENDENT_FIELD, &
                  & FIELD_U2_VARIABLE_TYPE,1,ERR,ERROR,*999)
                CALL FIELD_COMPONENT_MESH_COMPONENT_GET(EQUATIONS_SET%GEOMETRY%GEOMETRIC_FIELD,FIELD_U_VARIABLE_TYPE, & 
                  & NUMBER_OF_DIMENSIONS,GEOMETRIC_MESH_COMPONENT,ERR,ERROR,*999)
                !Default to the geometric interpolation setup
                DO I=1,DEPENDENT_FIELD_NUMBER_OF_COMPONENTS
                  CALL FIELD_COMPONENT_MESH_COMPONENT_SET(EQUATIONS_SET%DEPENDENT%DEPENDENT_FIELD, & 
                    & FIELD_U_VARIABLE_TYPE,I,GEOMETRIC_MESH_COMPONENT,ERR,ERROR,*999)
                  CALL FIELD_COMPONENT_MESH_COMPONENT_SET(EQUATIONS_SET%DEPENDENT%DEPENDENT_FIELD, &
                    & FIELD_DELUDELN_VARIABLE_TYPE,I,GEOMETRIC_MESH_COMPONENT,ERR,ERROR,*999)
                  CALL FIELD_COMPONENT_MESH_COMPONENT_SET(EQUATIONS_SET%DEPENDENT%DEPENDENT_FIELD, & 
                    & FIELD_V_VARIABLE_TYPE,I,GEOMETRIC_MESH_COMPONENT,ERR,ERROR,*999)
                  CALL FIELD_COMPONENT_MESH_COMPONENT_SET(EQUATIONS_SET%DEPENDENT%DEPENDENT_FIELD, &
                    & FIELD_U1_VARIABLE_TYPE,I,GEOMETRIC_MESH_COMPONENT,ERR,ERROR,*999)
                  CALL FIELD_COMPONENT_MESH_COMPONENT_SET(EQUATIONS_SET%DEPENDENT%DEPENDENT_FIELD, &
                    & FIELD_U2_VARIABLE_TYPE,I,GEOMETRIC_MESH_COMPONENT,ERR,ERROR,*999)
                END DO
                SELECT CASE(EQUATIONS_SET%SOLUTION_METHOD)
                !Specify fem solution method
                CASE(EQUATIONS_SET_FEM_SOLUTION_METHOD)
                  DO I=1,DEPENDENT_FIELD_NUMBER_OF_COMPONENTS
                    CALL FIELD_COMPONENT_INTERPOLATION_SET_AND_LOCK(EQUATIONS_SET%DEPENDENT%DEPENDENT_FIELD, &
                      & FIELD_U_VARIABLE_TYPE,I,FIELD_NODE_BASED_INTERPOLATION,ERR,ERROR,*999)
                    CALL FIELD_COMPONENT_INTERPOLATION_SET_AND_LOCK(EQUATIONS_SET%DEPENDENT%DEPENDENT_FIELD, &
                      & FIELD_DELUDELN_VARIABLE_TYPE,I,FIELD_NODE_BASED_INTERPOLATION,ERR,ERROR,*999)
                    CALL FIELD_COMPONENT_INTERPOLATION_SET_AND_LOCK(EQUATIONS_SET%DEPENDENT%DEPENDENT_FIELD, &
                      & FIELD_V_VARIABLE_TYPE,I,FIELD_NODE_BASED_INTERPOLATION,ERR,ERROR,*999)
                    CALL FIELD_COMPONENT_INTERPOLATION_SET_AND_LOCK(EQUATIONS_SET%DEPENDENT%DEPENDENT_FIELD, &
                      & FIELD_U1_VARIABLE_TYPE,I,FIELD_NODE_BASED_INTERPOLATION,ERR,ERROR,*999)
                    CALL FIELD_COMPONENT_INTERPOLATION_SET_AND_LOCK(EQUATIONS_SET%DEPENDENT%DEPENDENT_FIELD, &
                      & FIELD_U2_VARIABLE_TYPE,I,FIELD_NODE_BASED_INTERPOLATION,ERR,ERROR,*999)
                  END DO
                  CALL FIELD_SCALING_TYPE_GET(EQUATIONS_SET%GEOMETRY%GEOMETRIC_FIELD,GEOMETRIC_SCALING_TYPE, &
                    & ERR,ERROR,*999)
                  CALL FIELD_SCALING_TYPE_SET(EQUATIONS_SET%DEPENDENT%DEPENDENT_FIELD,GEOMETRIC_SCALING_TYPE, &
                    & ERR,ERROR,*999)
                CASE(EQUATIONS_SET_BEM_SOLUTION_METHOD)
                  CALL FlagError("Not implemented.",ERR,ERROR,*999)
                CASE(EQUATIONS_SET_FD_SOLUTION_METHOD)
                  CALL FlagError("Not implemented.",ERR,ERROR,*999)
                CASE(EQUATIONS_SET_FV_SOLUTION_METHOD)
                  CALL FlagError("Not implemented.",ERR,ERROR,*999)
                CASE(EQUATIONS_SET_GFEM_SOLUTION_METHOD)
                  CALL FlagError("Not implemented.",ERR,ERROR,*999)
                CASE(EQUATIONS_SET_GFV_SOLUTION_METHOD)
                  CALL FlagError("Not implemented.",ERR,ERROR,*999)
                CASE DEFAULT
                  LOCAL_ERROR="The solution method of " &
                    & //TRIM(NUMBER_TO_VSTRING(EQUATIONS_SET%SOLUTION_METHOD,"*",ERR,ERROR))// " is invalid."
                  CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
                END SELECT
              ELSE 
                !set number of variables to 5 (U,DELUDELN,V,U1,U2)
                DEPENDENT_FIELD_NUMBER_OF_VARIABLES=5
                !Check the user specified field- Characteristic equations
                CALL FIELD_TYPE_CHECK(EQUATIONS_SET_SETUP%FIELD,FIELD_GENERAL_TYPE,ERR,ERROR,*999)
                CALL FIELD_DEPENDENT_TYPE_CHECK(EQUATIONS_SET_SETUP%FIELD,FIELD_DEPENDENT_TYPE,ERR,ERROR,*999)
                CALL FIELD_NUMBER_OF_VARIABLES_CHECK(EQUATIONS_SET_SETUP%FIELD,DEPENDENT_FIELD_NUMBER_OF_VARIABLES,ERR,ERROR,*999)
                CALL FIELD_VARIABLE_TYPES_CHECK(EQUATIONS_SET_SETUP%FIELD,[FIELD_U_VARIABLE_TYPE, &
                  & FIELD_DELUDELN_VARIABLE_TYPE,FIELD_V_VARIABLE_TYPE,FIELD_U1_VARIABLE_TYPE,FIELD_U2_VARIABLE_TYPE], &
                  & ERR,ERROR,*999)
                CALL FIELD_DIMENSION_CHECK(EQUATIONS_SET_SETUP%FIELD,FIELD_U_VARIABLE_TYPE, & 
                  & FIELD_VECTOR_DIMENSION_TYPE,ERR,ERROR,*999)
                CALL FIELD_DIMENSION_CHECK(EQUATIONS_SET_SETUP%FIELD,FIELD_DELUDELN_VARIABLE_TYPE, &
                  & FIELD_VECTOR_DIMENSION_TYPE,ERR,ERROR,*999)
                CALL FIELD_DIMENSION_CHECK(EQUATIONS_SET_SETUP%FIELD,FIELD_V_VARIABLE_TYPE, &
                  & FIELD_VECTOR_DIMENSION_TYPE,ERR,ERROR,*999)
                CALL FIELD_DIMENSION_CHECK(EQUATIONS_SET_SETUP%FIELD,FIELD_U1_VARIABLE_TYPE, &
                  & FIELD_VECTOR_DIMENSION_TYPE,ERR,ERROR,*999)
                CALL FIELD_DIMENSION_CHECK(EQUATIONS_SET_SETUP%FIELD,FIELD_U2_VARIABLE_TYPE, &
                  & FIELD_VECTOR_DIMENSION_TYPE,ERR,ERROR,*999)
                CALL FIELD_DATA_TYPE_CHECK(EQUATIONS_SET_SETUP%FIELD,FIELD_U_VARIABLE_TYPE,FIELD_DP_TYPE,ERR,ERROR,*999)
                CALL FIELD_DATA_TYPE_CHECK(EQUATIONS_SET_SETUP%FIELD,FIELD_DELUDELN_VARIABLE_TYPE,FIELD_DP_TYPE, &
                  & ERR,ERROR,*999)
                CALL FIELD_DATA_TYPE_CHECK(EQUATIONS_SET_SETUP%FIELD,FIELD_V_VARIABLE_TYPE,FIELD_DP_TYPE,ERR,ERROR,*999)
                CALL FIELD_DATA_TYPE_CHECK(EQUATIONS_SET_SETUP%FIELD,FIELD_U1_VARIABLE_TYPE,FIELD_DP_TYPE,ERR,ERROR,*999)
                CALL FIELD_DATA_TYPE_CHECK(EQUATIONS_SET_SETUP%FIELD,FIELD_U2_VARIABLE_TYPE,FIELD_DP_TYPE,ERR,ERROR,*999)
                CALL FIELD_NUMBER_OF_COMPONENTS_GET(EQUATIONS_SET%GEOMETRY%GEOMETRIC_FIELD,FIELD_U_VARIABLE_TYPE, &
                  & NUMBER_OF_DIMENSIONS,ERR,ERROR,*999)
                !calculate number of components (Q,A) for U and dUdN
                DEPENDENT_FIELD_NUMBER_OF_COMPONENTS=2
                CALL FIELD_NUMBER_OF_COMPONENTS_CHECK(EQUATIONS_SET_SETUP%FIELD,FIELD_U_VARIABLE_TYPE, &
                  & DEPENDENT_FIELD_NUMBER_OF_COMPONENTS,ERR,ERROR,*999)
                CALL FIELD_NUMBER_OF_COMPONENTS_CHECK(EQUATIONS_SET_SETUP%FIELD,FIELD_DELUDELN_VARIABLE_TYPE, &
                  & DEPENDENT_FIELD_NUMBER_OF_COMPONENTS,ERR,ERROR,*999)
                CALL FIELD_NUMBER_OF_COMPONENTS_CHECK(EQUATIONS_SET_SETUP%FIELD,FIELD_V_VARIABLE_TYPE, &
                  & DEPENDENT_FIELD_NUMBER_OF_COMPONENTS,ERR,ERROR,*999)
                CALL FIELD_NUMBER_OF_COMPONENTS_CHECK(EQUATIONS_SET_SETUP%FIELD,FIELD_U1_VARIABLE_TYPE, &
                  & DEPENDENT_FIELD_NUMBER_OF_COMPONENTS,ERR,ERROR,*999)
                CALL FIELD_NUMBER_OF_COMPONENTS_CHECK(EQUATIONS_SET_SETUP%FIELD,FIELD_U2_VARIABLE_TYPE, &
                  & DEPENDENT_FIELD_NUMBER_OF_COMPONENTS,ERR,ERROR,*999)
                SELECT CASE(EQUATIONS_SET%SOLUTION_METHOD)
                CASE(EQUATIONS_SET_FEM_SOLUTION_METHOD)
                  CALL FIELD_COMPONENT_INTERPOLATION_CHECK(EQUATIONS_SET_SETUP%FIELD,FIELD_U_VARIABLE_TYPE,1, &
                    & FIELD_NODE_BASED_INTERPOLATION,ERR,ERROR,*999)
                  CALL FIELD_COMPONENT_INTERPOLATION_CHECK(EQUATIONS_SET_SETUP%FIELD,FIELD_DELUDELN_VARIABLE_TYPE,1, &
                    & FIELD_NODE_BASED_INTERPOLATION,ERR,ERROR,*999)
                  CALL FIELD_COMPONENT_INTERPOLATION_CHECK(EQUATIONS_SET_SETUP%FIELD,FIELD_V_VARIABLE_TYPE,1, &
                    & FIELD_NODE_BASED_INTERPOLATION,ERR,ERROR,*999)
                  CALL FIELD_COMPONENT_INTERPOLATION_CHECK(EQUATIONS_SET_SETUP%FIELD,FIELD_U1_VARIABLE_TYPE,1, &
                    & FIELD_NODE_BASED_INTERPOLATION,ERR,ERROR,*999)
                  CALL FIELD_COMPONENT_INTERPOLATION_CHECK(EQUATIONS_SET_SETUP%FIELD,FIELD_U2_VARIABLE_TYPE,1, &
                    & FIELD_NODE_BASED_INTERPOLATION,ERR,ERROR,*999)
                CASE(EQUATIONS_SET_BEM_SOLUTION_METHOD)
                  CALL FlagError("Not implemented.",ERR,ERROR,*999)
                CASE(EQUATIONS_SET_FD_SOLUTION_METHOD)
                  CALL FlagError("Not implemented.",ERR,ERROR,*999)
                CASE(EQUATIONS_SET_FV_SOLUTION_METHOD)
                  CALL FlagError("Not implemented.",ERR,ERROR,*999)
                CASE(EQUATIONS_SET_GFEM_SOLUTION_METHOD)
                  CALL FlagError("Not implemented.",ERR,ERROR,*999)
                CASE(EQUATIONS_SET_GFV_SOLUTION_METHOD)
                  CALL FlagError("Not implemented.",ERR,ERROR,*999)
                CASE DEFAULT
                  LOCAL_ERROR="The solution method of "//TRIM(NUMBER_TO_VSTRING(EQUATIONS_SET%SOLUTION_METHOD, &
                    & "*",ERR,ERROR))//" is invalid."
                  CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
                END SELECT
              END IF
            !Specify finish action
            CASE(EQUATIONS_SET_SETUP_FINISH_ACTION)
              IF(EQUATIONS_SET%DEPENDENT%DEPENDENT_FIELD_AUTO_CREATED) THEN
                CALL FIELD_CREATE_FINISH(EQUATIONS_SET%DEPENDENT%DEPENDENT_FIELD,ERR,ERROR,*999)
              END IF
            CASE DEFAULT
              LOCAL_ERROR="The action type of "//TRIM(NUMBER_TO_VSTRING(EQUATIONS_SET_SETUP%ACTION_TYPE,"*", & 
                & ERR,ERROR))//" for a setup type of "//TRIM(NUMBER_TO_VSTRING(EQUATIONS_SET_SETUP%SETUP_TYPE, & 
                & "*",ERR,ERROR))//" is invalid for a Navier-Stokes fluid."
              CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
            END SELECT
          CASE DEFAULT
            LOCAL_ERROR="The equation set subtype of "//TRIM(NUMBER_TO_VSTRING(EQUATIONS_SET%SPECIFICATION(3),"*",ERR,ERROR))// &
              & " for a setup type of "//TRIM(NUMBER_TO_VSTRING(EQUATIONS_SET_SETUP%SETUP_TYPE,"*",ERR,ERROR))// &
              & " is invalid for a Navier-Stokes equation."
            CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
          END SELECT
        !-----------------------------------------------------------------
        ! I n d e p e n d e n t   f i e l d
        !-----------------------------------------------------------------
        CASE(EQUATIONS_SET_SETUP_INDEPENDENT_TYPE)
          SELECT CASE(EQUATIONS_SET%SPECIFICATION(3))
          CASE(EQUATIONS_SET_ALE_NAVIER_STOKES_SUBTYPE,EQUATIONS_SET_PGM_NAVIER_STOKES_SUBTYPE)
            SELECT CASE(EQUATIONS_SET_SETUP%ACTION_TYPE)
            !Set start action
            CASE(EQUATIONS_SET_SETUP_START_ACTION)
              IF(EQUATIONS_SET%INDEPENDENT%INDEPENDENT_FIELD_AUTO_CREATED) THEN
                !Create the auto created independent field
                CALL FIELD_CREATE_START(EQUATIONS_SET_SETUP%FIELD_USER_NUMBER,EQUATIONS_SET%REGION, &
                  & EQUATIONS_SET%INDEPENDENT%INDEPENDENT_FIELD,ERR,ERROR,*999)
                CALL FIELD_LABEL_SET(EQUATIONS_SET%INDEPENDENT%INDEPENDENT_FIELD,"Independent Field",ERR,ERROR,*999)
                CALL FIELD_TYPE_SET_AND_LOCK(EQUATIONS_SET%INDEPENDENT%INDEPENDENT_FIELD,FIELD_GENERAL_TYPE,ERR,ERROR,*999)
                CALL FIELD_DEPENDENT_TYPE_SET_AND_LOCK(EQUATIONS_SET%INDEPENDENT%INDEPENDENT_FIELD, &
                  & FIELD_INDEPENDENT_TYPE,ERR,ERROR,*999)
                CALL FIELD_MESH_DECOMPOSITION_GET(EQUATIONS_SET%GEOMETRY%GEOMETRIC_FIELD,GEOMETRIC_DECOMPOSITION, &
                  & ERR,ERROR,*999)
                CALL FIELD_MESH_DECOMPOSITION_SET_AND_LOCK(EQUATIONS_SET%INDEPENDENT%INDEPENDENT_FIELD, &
                  & GEOMETRIC_DECOMPOSITION,ERR,ERROR,*999)
                CALL FIELD_GEOMETRIC_FIELD_SET_AND_LOCK(EQUATIONS_SET%INDEPENDENT%INDEPENDENT_FIELD,EQUATIONS_SET% & 
                  & GEOMETRY%GEOMETRIC_FIELD,ERR,ERROR,*999)
                INDEPENDENT_FIELD_NUMBER_OF_VARIABLES=1
                CALL FIELD_NUMBER_OF_VARIABLES_SET_AND_LOCK(EQUATIONS_SET%INDEPENDENT%INDEPENDENT_FIELD, &
                  & INDEPENDENT_FIELD_NUMBER_OF_VARIABLES,ERR,ERROR,*999)
                CALL FIELD_VARIABLE_TYPES_SET_AND_LOCK(EQUATIONS_SET%INDEPENDENT%INDEPENDENT_FIELD, & 
                  & [FIELD_U_VARIABLE_TYPE],ERR,ERROR,*999)
                CALL FIELD_VARIABLE_LABEL_SET(EQUATIONS_SET%INDEPENDENT%INDEPENDENT_FIELD,FIELD_U_VARIABLE_TYPE, &
                  & "U",ERR,ERROR,*999)
                CALL FIELD_DIMENSION_SET_AND_LOCK(EQUATIONS_SET%INDEPENDENT%INDEPENDENT_FIELD,FIELD_U_VARIABLE_TYPE, &
                  & FIELD_VECTOR_DIMENSION_TYPE,ERR,ERROR,*999)
                CALL FIELD_DATA_TYPE_SET_AND_LOCK(EQUATIONS_SET%INDEPENDENT%INDEPENDENT_FIELD,FIELD_U_VARIABLE_TYPE, &
                  & FIELD_DP_TYPE,ERR,ERROR,*999)
                CALL FIELD_NUMBER_OF_COMPONENTS_GET(EQUATIONS_SET%GEOMETRY%GEOMETRIC_FIELD,FIELD_U_VARIABLE_TYPE, &
                  & NUMBER_OF_DIMENSIONS,ERR,ERROR,*999)
                !calculate number of components with one component for each dimension
                INDEPENDENT_FIELD_NUMBER_OF_COMPONENTS=NUMBER_OF_DIMENSIONS
                CALL FIELD_NUMBER_OF_COMPONENTS_SET_AND_LOCK(EQUATIONS_SET%INDEPENDENT%INDEPENDENT_FIELD, & 
                  & FIELD_U_VARIABLE_TYPE,INDEPENDENT_FIELD_NUMBER_OF_COMPONENTS,ERR,ERROR,*999)
                !Default to the geometric interpolation setup
                DO componentIdx=1,INDEPENDENT_FIELD_NUMBER_OF_COMPONENTS
                  CALL FIELD_COMPONENT_MESH_COMPONENT_GET(EQUATIONS_SET%GEOMETRY%GEOMETRIC_FIELD,FIELD_U_VARIABLE_TYPE, & 
                    & componentIdx,GEOMETRIC_MESH_COMPONENT,ERR,ERROR,*999)
                  CALL FIELD_COMPONENT_MESH_COMPONENT_SET(EQUATIONS_SET%INDEPENDENT%INDEPENDENT_FIELD, & 
                    & FIELD_U_VARIABLE_TYPE,componentIdx,GEOMETRIC_MESH_COMPONENT,ERR,ERROR,*999)
                END DO !componentIdx
                SELECT CASE(EQUATIONS_SET%SOLUTION_METHOD)
                !Specify fem solution method
                CASE(EQUATIONS_SET_FEM_SOLUTION_METHOD)
                  DO componentIdx=1,INDEPENDENT_FIELD_NUMBER_OF_COMPONENTS
                    CALL FIELD_COMPONENT_INTERPOLATION_SET_AND_LOCK(EQUATIONS_SET%INDEPENDENT%INDEPENDENT_FIELD, &
                      & FIELD_U_VARIABLE_TYPE,componentIdx,FIELD_NODE_BASED_INTERPOLATION,ERR,ERROR,*999)
                  END DO !componentIdx
                  !Default geometric field scaling
                  CALL FIELD_SCALING_TYPE_GET(EQUATIONS_SET%GEOMETRY%GEOMETRIC_FIELD,GEOMETRIC_SCALING_TYPE,ERR,ERROR,*999)
                  CALL FIELD_SCALING_TYPE_SET(EQUATIONS_SET%INDEPENDENT%INDEPENDENT_FIELD,GEOMETRIC_SCALING_TYPE,ERR,ERROR,*999)
                !Other solutions not defined yet
                CASE DEFAULT
                  LOCAL_ERROR="The solution method of " &
                    & //TRIM(NUMBER_TO_VSTRING(EQUATIONS_SET%SOLUTION_METHOD,"*",ERR,ERROR))// " is invalid."
                  CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
                END SELECT 
              ELSE
                !Check the user specified field
                CALL FIELD_TYPE_CHECK(EQUATIONS_SET_SETUP%FIELD,FIELD_GENERAL_TYPE,ERR,ERROR,*999)
                CALL FIELD_DEPENDENT_TYPE_CHECK(EQUATIONS_SET_SETUP%FIELD,FIELD_INDEPENDENT_TYPE,ERR,ERROR,*999)
                CALL FIELD_NUMBER_OF_VARIABLES_CHECK(EQUATIONS_SET_SETUP%FIELD,1,ERR,ERROR,*999)
                CALL FIELD_VARIABLE_TYPES_CHECK(EQUATIONS_SET_SETUP%FIELD,[FIELD_U_VARIABLE_TYPE],ERR,ERROR,*999)
                CALL FIELD_DATA_TYPE_CHECK(EQUATIONS_SET_SETUP%FIELD,FIELD_U_VARIABLE_TYPE,FIELD_DP_TYPE,ERR,ERROR,*999)
                CALL FIELD_DIMENSION_CHECK(EQUATIONS_SET_SETUP%FIELD,FIELD_U_VARIABLE_TYPE,FIELD_VECTOR_DIMENSION_TYPE, &
                  & ERR,ERROR,*999)
                CALL FIELD_NUMBER_OF_COMPONENTS_GET(EQUATIONS_SET%GEOMETRY%GEOMETRIC_FIELD,FIELD_U_VARIABLE_TYPE, &
                  & NUMBER_OF_DIMENSIONS,ERR,ERROR,*999)
                !calculate number of components with one component for each dimension
                INDEPENDENT_FIELD_NUMBER_OF_COMPONENTS=NUMBER_OF_DIMENSIONS
                CALL FIELD_NUMBER_OF_COMPONENTS_CHECK(EQUATIONS_SET_SETUP%FIELD,FIELD_U_VARIABLE_TYPE, &
                  & INDEPENDENT_FIELD_NUMBER_OF_COMPONENTS,ERR,ERROR,*999)
                SELECT CASE(EQUATIONS_SET%SOLUTION_METHOD)
                CASE(EQUATIONS_SET_FEM_SOLUTION_METHOD)
                   DO componentIdx=1,INDEPENDENT_FIELD_NUMBER_OF_COMPONENTS                  
                    CALL FIELD_COMPONENT_INTERPOLATION_CHECK(EQUATIONS_SET_SETUP%FIELD,FIELD_U_VARIABLE_TYPE,1, &
                      & FIELD_NODE_BASED_INTERPOLATION,ERR,ERROR,*999)
                  END DO !componentIdx
                CASE DEFAULT
                  LOCAL_ERROR="The solution method of "//TRIM(NUMBER_TO_VSTRING(EQUATIONS_SET%SOLUTION_METHOD, &
                    &"*",ERR,ERROR))//" is invalid."
                  CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
                END SELECT
              END IF    
              !Specify finish action
            CASE(EQUATIONS_SET_SETUP_FINISH_ACTION)
              IF(EQUATIONS_SET%INDEPENDENT%INDEPENDENT_FIELD_AUTO_CREATED) THEN
                CALL FIELD_CREATE_FINISH(EQUATIONS_SET%INDEPENDENT%INDEPENDENT_FIELD,ERR,ERROR,*999)
                CALL FIELD_PARAMETER_SET_CREATE(EQUATIONS_SET%INDEPENDENT%INDEPENDENT_FIELD,FIELD_U_VARIABLE_TYPE, &
                  & FIELD_MESH_DISPLACEMENT_SET_TYPE,ERR,ERROR,*999)
                CALL FIELD_PARAMETER_SET_CREATE(EQUATIONS_SET%INDEPENDENT%INDEPENDENT_FIELD,FIELD_U_VARIABLE_TYPE, &
                  & FIELD_MESH_VELOCITY_SET_TYPE,ERR,ERROR,*999)
                CALL FIELD_PARAMETER_SET_CREATE(EQUATIONS_SET%INDEPENDENT%INDEPENDENT_FIELD,FIELD_U_VARIABLE_TYPE, &
                  & FIELD_BOUNDARY_SET_TYPE,ERR,ERROR,*999)
              END IF
            CASE DEFAULT
              LOCAL_ERROR="The action type of "//TRIM(NUMBER_TO_VSTRING(EQUATIONS_SET_SETUP%ACTION_TYPE,"*",ERR,ERROR))// &
                & " for a setup type of "//TRIM(NUMBER_TO_VSTRING(EQUATIONS_SET_SETUP%SETUP_TYPE,"*",ERR,ERROR))// &
                & " is invalid for a standard Navier-Stokes fluid"
              CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
            END SELECT
          CASE(EQUATIONS_SET_TRANSIENT1D_NAVIER_STOKES_SUBTYPE, &
             & EQUATIONS_SET_TRANSIENT1D_ADV_NAVIER_STOKES_SUBTYPE)
            SELECT CASE(EQUATIONS_SET_SETUP%ACTION_TYPE)
            !Set start action
            CASE(EQUATIONS_SET_SETUP_START_ACTION)
              !set number of variables to 1
              INDEPENDENT_FIELD_NUMBER_OF_VARIABLES=1
              !normalDirection for wave relative to node for W1,W2
              INDEPENDENT_FIELD_NUMBER_OF_COMPONENTS=2
              !Create the auto created independent field
              IF(EQUATIONS_SET%INDEPENDENT%INDEPENDENT_FIELD_AUTO_CREATED) THEN
                !start field creation with name 'INDEPENDENT_FIELD'
                CALL FIELD_CREATE_START(EQUATIONS_SET_SETUP%FIELD_USER_NUMBER,EQUATIONS_SET%REGION, &
                  & EQUATIONS_SET%INDEPENDENT%INDEPENDENT_FIELD,ERR,ERROR,*999)
                !start creation of a new field
                CALL FIELD_TYPE_SET_AND_LOCK(EQUATIONS_SET%INDEPENDENT%INDEPENDENT_FIELD,FIELD_GENERAL_TYPE,ERR,ERROR,*999)
                !label the field
                CALL FIELD_LABEL_SET(EQUATIONS_SET%INDEPENDENT%INDEPENDENT_FIELD,"Independent Field",ERR,ERROR, & 
                  & *999)
                !define new created field to be independent
                CALL FIELD_DEPENDENT_TYPE_SET_AND_LOCK(EQUATIONS_SET%INDEPENDENT%INDEPENDENT_FIELD, &
                  & FIELD_INDEPENDENT_TYPE,ERR,ERROR,*999)
                !look for decomposition rule already defined
                CALL FIELD_MESH_DECOMPOSITION_GET(EQUATIONS_SET%GEOMETRY%GEOMETRIC_FIELD,GEOMETRIC_DECOMPOSITION, &
                  & ERR,ERROR,*999)
                !apply decomposition rule found on new created field
                CALL FIELD_MESH_DECOMPOSITION_SET_AND_LOCK(EQUATIONS_SET%INDEPENDENT%INDEPENDENT_FIELD, &
                  & GEOMETRIC_DECOMPOSITION,ERR,ERROR,*999)
                !point new field to geometric field
                CALL FIELD_GEOMETRIC_FIELD_SET_AND_LOCK(EQUATIONS_SET%INDEPENDENT%INDEPENDENT_FIELD,EQUATIONS_SET% & 
                  & GEOMETRY%GEOMETRIC_FIELD,ERR,ERROR,*999)
                !set number of variables to 1
                CALL FIELD_NUMBER_OF_VARIABLES_SET_AND_LOCK(EQUATIONS_SET%INDEPENDENT%INDEPENDENT_FIELD, &
                  & INDEPENDENT_FIELD_NUMBER_OF_VARIABLES,ERR,ERROR,*999)
                CALL FIELD_VARIABLE_TYPES_SET_AND_LOCK(EQUATIONS_SET%INDEPENDENT%INDEPENDENT_FIELD, & 
                  & [FIELD_U_VARIABLE_TYPE],ERR,ERROR,*999)
                CALL FIELD_DIMENSION_SET_AND_LOCK(EQUATIONS_SET%INDEPENDENT%INDEPENDENT_FIELD,FIELD_U_VARIABLE_TYPE, &
                  & FIELD_VECTOR_DIMENSION_TYPE,ERR,ERROR,*999)
                CALL FIELD_DATA_TYPE_SET_AND_LOCK(EQUATIONS_SET%INDEPENDENT%INDEPENDENT_FIELD,FIELD_U_VARIABLE_TYPE, &
                  & FIELD_DP_TYPE,ERR,ERROR,*999)
                !calculate number of components with one component for each dimension
                CALL FIELD_NUMBER_OF_COMPONENTS_SET_AND_LOCK(EQUATIONS_SET%INDEPENDENT%INDEPENDENT_FIELD, & 
                  & FIELD_U_VARIABLE_TYPE,INDEPENDENT_FIELD_NUMBER_OF_COMPONENTS,ERR,ERROR,*999)
                CALL FIELD_COMPONENT_MESH_COMPONENT_GET(EQUATIONS_SET%GEOMETRY%GEOMETRIC_FIELD,FIELD_U_VARIABLE_TYPE, & 
                  & 1,GEOMETRIC_MESH_COMPONENT,ERR,ERROR,*999)
                !Default to the geometric interpolation setup
                DO I=1,INDEPENDENT_FIELD_NUMBER_OF_COMPONENTS
                  CALL FIELD_COMPONENT_MESH_COMPONENT_SET(EQUATIONS_SET%INDEPENDENT%INDEPENDENT_FIELD, & 
                    & FIELD_U_VARIABLE_TYPE,I,GEOMETRIC_MESH_COMPONENT,ERR,ERROR,*999)
                END DO
                SELECT CASE(EQUATIONS_SET%SOLUTION_METHOD)
                !Specify fem solution method
                CASE(EQUATIONS_SET_FEM_SOLUTION_METHOD)
                  DO componentIdx=1,INDEPENDENT_FIELD_NUMBER_OF_COMPONENTS
                    CALL FIELD_COMPONENT_INTERPOLATION_SET_AND_LOCK(EQUATIONS_SET%INDEPENDENT%INDEPENDENT_FIELD, &
                      & FIELD_U_VARIABLE_TYPE,componentIdx,FIELD_NODE_BASED_INTERPOLATION,ERR,ERROR,*999)
                  END DO !componentIdx
                  CALL FIELD_SCALING_TYPE_GET(EQUATIONS_SET%GEOMETRY%GEOMETRIC_FIELD,GEOMETRIC_SCALING_TYPE, &
                    & ERR,ERROR,*999)
                  CALL FIELD_SCALING_TYPE_SET(EQUATIONS_SET%INDEPENDENT%INDEPENDENT_FIELD,GEOMETRIC_SCALING_TYPE, &
                    & ERR,ERROR,*999)
                CASE(EQUATIONS_SET_NODAL_SOLUTION_METHOD)
                  DO componentIdx=1,INDEPENDENT_FIELD_NUMBER_OF_COMPONENTS
                    CALL FIELD_COMPONENT_INTERPOLATION_SET_AND_LOCK(EQUATIONS_SET%INDEPENDENT%INDEPENDENT_FIELD, &
                      & FIELD_U_VARIABLE_TYPE,componentIdx,FIELD_NODE_BASED_INTERPOLATION,ERR,ERROR,*999)
                  END DO !componentIdx
                  CALL FIELD_SCALING_TYPE_GET(EQUATIONS_SET%GEOMETRY%GEOMETRIC_FIELD,GEOMETRIC_SCALING_TYPE, &
                    & ERR,ERROR,*999)
                  CALL FIELD_SCALING_TYPE_SET(EQUATIONS_SET%INDEPENDENT%INDEPENDENT_FIELD,GEOMETRIC_SCALING_TYPE, &
                    & ERR,ERROR,*999)
                CASE DEFAULT
                  LOCAL_ERROR="The solution method of " &
                    & //TRIM(NUMBER_TO_VSTRING(EQUATIONS_SET%SOLUTION_METHOD,"*",ERR,ERROR))// " is invalid."
                  CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
                END SELECT 
              ELSE
                !Check the user specified field- Characteristic equation
                CALL FIELD_TYPE_CHECK(EQUATIONS_SET_SETUP%FIELD,FIELD_GENERAL_TYPE,ERR,ERROR,*999)
                CALL FIELD_DEPENDENT_TYPE_CHECK(EQUATIONS_SET_SETUP%FIELD,FIELD_INDEPENDENT_TYPE,ERR,ERROR,*999)
                CALL FIELD_NUMBER_OF_VARIABLES_CHECK(EQUATIONS_SET_SETUP%FIELD,INDEPENDENT_FIELD_NUMBER_OF_VARIABLES, &
                  & ERR,ERROR,*999)
                CALL FIELD_VARIABLE_TYPES_CHECK(EQUATIONS_SET_SETUP%FIELD,[FIELD_U_VARIABLE_TYPE],ERR,ERROR,*999)
                CALL FIELD_DIMENSION_CHECK(EQUATIONS_SET_SETUP%FIELD,FIELD_U_VARIABLE_TYPE,FIELD_VECTOR_DIMENSION_TYPE, &
                  & ERR,ERROR,*999)
                CALL FIELD_DATA_TYPE_CHECK(EQUATIONS_SET_SETUP%FIELD,FIELD_U_VARIABLE_TYPE,FIELD_DP_TYPE,ERR,ERROR,*999)
                CALL FIELD_NUMBER_OF_COMPONENTS_CHECK(EQUATIONS_SET_SETUP%FIELD,FIELD_U_VARIABLE_TYPE, &
                  & INDEPENDENT_FIELD_NUMBER_OF_COMPONENTS,ERR,ERROR,*999)
              END IF    
            !Specify finish action
            CASE(EQUATIONS_SET_SETUP_FINISH_ACTION)
              IF(EQUATIONS_SET%INDEPENDENT%INDEPENDENT_FIELD_AUTO_CREATED) THEN
                CALL FIELD_CREATE_FINISH(EQUATIONS_SET%INDEPENDENT%INDEPENDENT_FIELD,ERR,ERROR,*999)
              END IF
            CASE DEFAULT
              LOCAL_ERROR="The action type of "//TRIM(NUMBER_TO_VSTRING(EQUATIONS_SET_SETUP%ACTION_TYPE,"*",ERR,ERROR))// &
                & " for a setup type of "//TRIM(NUMBER_TO_VSTRING(EQUATIONS_SET_SETUP%SETUP_TYPE,"*",ERR,ERROR))// &
                & " is invalid for a standard Navier-Stokes fluid"
              CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
            END SELECT
         CASE(EQUATIONS_SET_COUPLED1D0D_NAVIER_STOKES_SUBTYPE, &
             & EQUATIONS_SET_COUPLED1D0D_ADV_NAVIER_STOKES_SUBTYPE)
            SELECT CASE(EQUATIONS_SET_SETUP%ACTION_TYPE)
            !Set start action
            CASE(EQUATIONS_SET_SETUP_START_ACTION)
             !set number of variables to 1
              INDEPENDENT_FIELD_NUMBER_OF_VARIABLES=1
              !normalDirection for wave relative to node for W1,W2
              INDEPENDENT_FIELD_NUMBER_OF_COMPONENTS=2
              !Create the auto created independent field
              IF(EQUATIONS_SET%INDEPENDENT%INDEPENDENT_FIELD_AUTO_CREATED) THEN
                ! Do nothing? independent field should be set up by characteristic equation routines
              ELSE
                !Check the user specified field- Characteristic equation
                CALL FIELD_TYPE_CHECK(EQUATIONS_SET_SETUP%FIELD,FIELD_GENERAL_TYPE,ERR,ERROR,*999)
                CALL FIELD_DEPENDENT_TYPE_CHECK(EQUATIONS_SET_SETUP%FIELD,FIELD_INDEPENDENT_TYPE,ERR,ERROR,*999)
                CALL FIELD_NUMBER_OF_VARIABLES_CHECK(EQUATIONS_SET_SETUP%FIELD,INDEPENDENT_FIELD_NUMBER_OF_VARIABLES, &
                 & ERR,ERROR,*999)
                CALL FIELD_VARIABLE_TYPES_CHECK(EQUATIONS_SET_SETUP%FIELD,[FIELD_U_VARIABLE_TYPE],ERR,ERROR,*999)
                CALL FIELD_DIMENSION_CHECK(EQUATIONS_SET_SETUP%FIELD,FIELD_U_VARIABLE_TYPE,FIELD_VECTOR_DIMENSION_TYPE, &
                  & ERR,ERROR,*999)
                CALL FIELD_DATA_TYPE_CHECK(EQUATIONS_SET_SETUP%FIELD,FIELD_U_VARIABLE_TYPE,FIELD_DP_TYPE,ERR,ERROR,*999)
                CALL FIELD_NUMBER_OF_COMPONENTS_CHECK(EQUATIONS_SET_SETUP%FIELD,FIELD_U_VARIABLE_TYPE, &
                  & INDEPENDENT_FIELD_NUMBER_OF_COMPONENTS,ERR,ERROR,*999)
              END IF    
            !Specify finish action
            CASE(EQUATIONS_SET_SETUP_FINISH_ACTION)
              IF(EQUATIONS_SET%INDEPENDENT%INDEPENDENT_FIELD_AUTO_CREATED) THEN
                CALL FIELD_CREATE_FINISH(EQUATIONS_SET%INDEPENDENT%INDEPENDENT_FIELD,ERR,ERROR,*999)
              END IF
            CASE DEFAULT
              LOCAL_ERROR="The action type of "//TRIM(NUMBER_TO_VSTRING(EQUATIONS_SET_SETUP%ACTION_TYPE,"*",ERR,ERROR))// &
                & " for a setup type of "//TRIM(NUMBER_TO_VSTRING(EQUATIONS_SET_SETUP%SETUP_TYPE,"*",ERR,ERROR))// &
                & " is invalid for a standard Navier-Stokes fluid"
              CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
            END SELECT
          CASE(EQUATIONS_SET_STATIC_RBS_NAVIER_STOKES_SUBTYPE, &
             & EQUATIONS_SET_TRANSIENT_RBS_NAVIER_STOKES_SUBTYPE, &
             & EQUATIONS_SET_MULTISCALE3D_NAVIER_STOKES_SUBTYPE)
            SELECT CASE(EQUATIONS_SET_SETUP%ACTION_TYPE)
            !Set start action
            CASE(EQUATIONS_SET_SETUP_START_ACTION)
              IF(EQUATIONS_SET%INDEPENDENT%INDEPENDENT_FIELD_AUTO_CREATED) THEN
                !Create the auto created independent field
                CALL FIELD_CREATE_START(EQUATIONS_SET_SETUP%FIELD_USER_NUMBER,EQUATIONS_SET%REGION, &
                  & EQUATIONS_SET%INDEPENDENT%INDEPENDENT_FIELD,ERR,ERROR,*999)
                CALL FIELD_LABEL_SET(EQUATIONS_SET%INDEPENDENT%INDEPENDENT_FIELD,"Independent Field",ERR,ERROR,*999)
                CALL FIELD_TYPE_SET_AND_LOCK(EQUATIONS_SET%INDEPENDENT%INDEPENDENT_FIELD,FIELD_GENERAL_TYPE,ERR,ERROR,*999)
                CALL FIELD_DEPENDENT_TYPE_SET_AND_LOCK(EQUATIONS_SET%INDEPENDENT%INDEPENDENT_FIELD, &
                  & FIELD_INDEPENDENT_TYPE,ERR,ERROR,*999)
                CALL FIELD_MESH_DECOMPOSITION_GET(EQUATIONS_SET%GEOMETRY%GEOMETRIC_FIELD,GEOMETRIC_DECOMPOSITION, &
                  & ERR,ERROR,*999)
                CALL FIELD_MESH_DECOMPOSITION_SET_AND_LOCK(EQUATIONS_SET%INDEPENDENT%INDEPENDENT_FIELD, &
                  & GEOMETRIC_DECOMPOSITION,ERR,ERROR,*999)
                CALL FIELD_GEOMETRIC_FIELD_SET_AND_LOCK(EQUATIONS_SET%INDEPENDENT%INDEPENDENT_FIELD,EQUATIONS_SET% & 
                  & GEOMETRY%GEOMETRIC_FIELD,ERR,ERROR,*999)
                INDEPENDENT_FIELD_NUMBER_OF_VARIABLES=1
                CALL FIELD_NUMBER_OF_VARIABLES_SET_AND_LOCK(EQUATIONS_SET%INDEPENDENT%INDEPENDENT_FIELD, &
                  & INDEPENDENT_FIELD_NUMBER_OF_VARIABLES,ERR,ERROR,*999)
                CALL FIELD_VARIABLE_TYPES_SET_AND_LOCK(EQUATIONS_SET%INDEPENDENT%INDEPENDENT_FIELD, & 
                  & [FIELD_U_VARIABLE_TYPE],ERR,ERROR,*999)
                CALL FIELD_VARIABLE_LABEL_SET(EQUATIONS_SET%INDEPENDENT%INDEPENDENT_FIELD,FIELD_U_VARIABLE_TYPE, &
                  & "U",ERR,ERROR,*999)
                CALL FIELD_DIMENSION_SET_AND_LOCK(EQUATIONS_SET%INDEPENDENT%INDEPENDENT_FIELD,FIELD_U_VARIABLE_TYPE, &
                  & FIELD_VECTOR_DIMENSION_TYPE,ERR,ERROR,*999)
                CALL FIELD_DATA_TYPE_SET_AND_LOCK(EQUATIONS_SET%INDEPENDENT%INDEPENDENT_FIELD,FIELD_U_VARIABLE_TYPE, &
                  & FIELD_DP_TYPE,ERR,ERROR,*999)
                CALL FIELD_NUMBER_OF_COMPONENTS_GET(EQUATIONS_SET%GEOMETRY%GEOMETRIC_FIELD,FIELD_U_VARIABLE_TYPE, &
                  & NUMBER_OF_DIMENSIONS,ERR,ERROR,*999)
                !calculate number of components with one component for each dimension
                INDEPENDENT_FIELD_NUMBER_OF_COMPONENTS=NUMBER_OF_DIMENSIONS
                CALL FIELD_NUMBER_OF_COMPONENTS_SET_AND_LOCK(EQUATIONS_SET%INDEPENDENT%INDEPENDENT_FIELD, & 
                  & FIELD_U_VARIABLE_TYPE,INDEPENDENT_FIELD_NUMBER_OF_COMPONENTS,ERR,ERROR,*999)
                !Default to the geometric interpolation setup
                DO componentIdx=1,INDEPENDENT_FIELD_NUMBER_OF_COMPONENTS
                  CALL FIELD_COMPONENT_MESH_COMPONENT_GET(EQUATIONS_SET%GEOMETRY%GEOMETRIC_FIELD,FIELD_U_VARIABLE_TYPE, & 
                    & componentIdx,GEOMETRIC_MESH_COMPONENT,ERR,ERROR,*999)
                  CALL FIELD_COMPONENT_MESH_COMPONENT_SET(EQUATIONS_SET%INDEPENDENT%INDEPENDENT_FIELD, & 
                    & FIELD_U_VARIABLE_TYPE,componentIdx,GEOMETRIC_MESH_COMPONENT,ERR,ERROR,*999)
                END DO !componentIdx
                SELECT CASE(EQUATIONS_SET%SOLUTION_METHOD)
                !Specify fem solution method
                CASE(EQUATIONS_SET_FEM_SOLUTION_METHOD)
                  DO componentIdx=1,INDEPENDENT_FIELD_NUMBER_OF_COMPONENTS
                    CALL FIELD_COMPONENT_INTERPOLATION_SET_AND_LOCK(EQUATIONS_SET%INDEPENDENT%INDEPENDENT_FIELD, &
                      & FIELD_U_VARIABLE_TYPE,componentIdx,FIELD_NODE_BASED_INTERPOLATION,ERR,ERROR,*999)
                  END DO !componentIdx
                  !Default geometric field scaling
                  CALL FIELD_SCALING_TYPE_GET(EQUATIONS_SET%GEOMETRY%GEOMETRIC_FIELD,GEOMETRIC_SCALING_TYPE,ERR,ERROR,*999)
                  CALL FIELD_SCALING_TYPE_SET(EQUATIONS_SET%INDEPENDENT%INDEPENDENT_FIELD,GEOMETRIC_SCALING_TYPE,ERR,ERROR,*999)
                !Other solutions not defined yet
                CASE DEFAULT
                  LOCAL_ERROR="The solution method of " &
                    & //TRIM(NUMBER_TO_VSTRING(EQUATIONS_SET%SOLUTION_METHOD,"*",ERR,ERROR))// " is invalid."
                  CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
                END SELECT 
              ELSE
                !Check the user specified field
                CALL FIELD_TYPE_CHECK(EQUATIONS_SET_SETUP%FIELD,FIELD_GENERAL_TYPE,ERR,ERROR,*999)
                CALL FIELD_DEPENDENT_TYPE_CHECK(EQUATIONS_SET_SETUP%FIELD,FIELD_INDEPENDENT_TYPE,ERR,ERROR,*999)
                CALL FIELD_NUMBER_OF_VARIABLES_CHECK(EQUATIONS_SET_SETUP%FIELD,1,ERR,ERROR,*999)
                CALL FIELD_VARIABLE_TYPES_CHECK(EQUATIONS_SET_SETUP%FIELD,[FIELD_U_VARIABLE_TYPE],ERR,ERROR,*999)
                CALL FIELD_DATA_TYPE_CHECK(EQUATIONS_SET_SETUP%FIELD,FIELD_U_VARIABLE_TYPE,FIELD_DP_TYPE,ERR,ERROR,*999)
                CALL FIELD_DIMENSION_CHECK(EQUATIONS_SET_SETUP%FIELD,FIELD_U_VARIABLE_TYPE,FIELD_VECTOR_DIMENSION_TYPE, &
                  & ERR,ERROR,*999)
                CALL FIELD_NUMBER_OF_COMPONENTS_GET(EQUATIONS_SET%GEOMETRY%GEOMETRIC_FIELD,FIELD_U_VARIABLE_TYPE, &
                  & NUMBER_OF_DIMENSIONS,ERR,ERROR,*999)
                !calculate number of components with one component for each dimension
                INDEPENDENT_FIELD_NUMBER_OF_COMPONENTS=NUMBER_OF_DIMENSIONS
                CALL FIELD_NUMBER_OF_COMPONENTS_CHECK(EQUATIONS_SET_SETUP%FIELD,FIELD_U_VARIABLE_TYPE, &
                  & INDEPENDENT_FIELD_NUMBER_OF_COMPONENTS,ERR,ERROR,*999)
                SELECT CASE(EQUATIONS_SET%SOLUTION_METHOD)
                CASE(EQUATIONS_SET_FEM_SOLUTION_METHOD)
                   DO componentIdx=1,INDEPENDENT_FIELD_NUMBER_OF_COMPONENTS                  
                    CALL FIELD_COMPONENT_INTERPOLATION_CHECK(EQUATIONS_SET_SETUP%FIELD,FIELD_U_VARIABLE_TYPE,1, &
                      & FIELD_NODE_BASED_INTERPOLATION,ERR,ERROR,*999)
                  END DO !componentIdx
                CASE DEFAULT
                  LOCAL_ERROR="The solution method of "//TRIM(NUMBER_TO_VSTRING(EQUATIONS_SET%SOLUTION_METHOD, &
                    &"*",ERR,ERROR))//" is invalid."
                  CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
                END SELECT
              END IF    
              !Specify finish action
            CASE(EQUATIONS_SET_SETUP_FINISH_ACTION)
              IF(EQUATIONS_SET%INDEPENDENT%INDEPENDENT_FIELD_AUTO_CREATED) THEN
                CALL FIELD_CREATE_FINISH(EQUATIONS_SET%INDEPENDENT%INDEPENDENT_FIELD,ERR,ERROR,*999)
                CALL FIELD_PARAMETER_SET_CREATE(EQUATIONS_SET%INDEPENDENT%INDEPENDENT_FIELD,FIELD_U_VARIABLE_TYPE, &
                  & FIELD_MESH_DISPLACEMENT_SET_TYPE,ERR,ERROR,*999)
                CALL FIELD_PARAMETER_SET_CREATE(EQUATIONS_SET%INDEPENDENT%INDEPENDENT_FIELD,FIELD_U_VARIABLE_TYPE, &
                  & FIELD_MESH_VELOCITY_SET_TYPE,ERR,ERROR,*999)
                CALL FIELD_PARAMETER_SET_CREATE(EQUATIONS_SET%INDEPENDENT%INDEPENDENT_FIELD,FIELD_U_VARIABLE_TYPE, &
                  & FIELD_BOUNDARY_SET_TYPE,ERR,ERROR,*999)
              END IF
            CASE DEFAULT
              LOCAL_ERROR="The action type of "//TRIM(NUMBER_TO_VSTRING(EQUATIONS_SET_SETUP%ACTION_TYPE,"*",ERR,ERROR))// &
                & " for a setup type of "//TRIM(NUMBER_TO_VSTRING(EQUATIONS_SET_SETUP%SETUP_TYPE,"*",ERR,ERROR))// &
                & " is invalid for a standard Navier-Stokes fluid"
              CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
            END SELECT
          CASE DEFAULT
            LOCAL_ERROR="The equation set subtype of "//TRIM(NUMBER_TO_VSTRING(EQUATIONS_SET%SPECIFICATION(3),"*",ERR,ERROR))// &
              & " for a setup type of "//TRIM(NUMBER_TO_VSTRING(EQUATIONS_SET_SETUP%SETUP_TYPE,"*",ERR,ERROR))// &
              & " is invalid for a Navier-Stokes equation."
            CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
          END SELECT
        !-----------------------------------------------------------------
        ! A n a l y t i c   t y p e
        !-----------------------------------------------------------------
        CASE(EQUATIONS_SET_SETUP_ANALYTIC_TYPE)
          SELECT CASE(EQUATIONS_SET%SPECIFICATION(3))
          CASE(EQUATIONS_SET_STATIC_NAVIER_STOKES_SUBTYPE, &
            & EQUATIONS_SET_LAPLACE_NAVIER_STOKES_SUBTYPE, &
            & EQUATIONS_SET_TRANSIENT_NAVIER_STOKES_SUBTYPE, &
            & EQUATIONS_SET_QUASISTATIC_NAVIER_STOKES_SUBTYPE, &
            & EQUATIONS_SET_STATIC_RBS_NAVIER_STOKES_SUBTYPE, &
            & EQUATIONS_SET_TRANSIENT_RBS_NAVIER_STOKES_SUBTYPE, &
            & EQUATIONS_SET_MULTISCALE3D_NAVIER_STOKES_SUBTYPE, &
            & EQUATIONS_SET_CONSTITUTIVE_MU_NAVIER_STOKES_SUBTYPE, &
            & EQUATIONS_SET_TRANSIENT1D_NAVIER_STOKES_SUBTYPE, &
            & EQUATIONS_SET_COUPLED1D0D_NAVIER_STOKES_SUBTYPE, &
            & EQUATIONS_SET_TRANSIENT1D_ADV_NAVIER_STOKES_SUBTYPE, &
            & EQUATIONS_SET_COUPLED1D0D_ADV_NAVIER_STOKES_SUBTYPE)
            SELECT CASE(EQUATIONS_SET_SETUP%ACTION_TYPE)
              !Set start action
            CASE(EQUATIONS_SET_SETUP_START_ACTION)
              EQUATIONS_ANALYTIC=>EQUATIONS_SET%ANALYTIC
              IF(ASSOCIATED(EQUATIONS_ANALYTIC)) THEN
                IF(EQUATIONS_SET%DEPENDENT%DEPENDENT_FINISHED) THEN
                  DEPENDENT_FIELD=>EQUATIONS_SET%DEPENDENT%DEPENDENT_FIELD
                  IF(ASSOCIATED(DEPENDENT_FIELD)) THEN
                    EQUATIONS_MATERIALS=>EQUATIONS_SET%MATERIALS
                    IF(ASSOCIATED(EQUATIONS_MATERIALS)) THEN
                      IF(EQUATIONS_MATERIALS%MATERIALS_FINISHED) THEN
                        GEOMETRIC_FIELD=>EQUATIONS_SET%GEOMETRY%GEOMETRIC_FIELD
                        IF(ASSOCIATED(GEOMETRIC_FIELD)) THEN
                          CALL FIELD_NUMBER_OF_COMPONENTS_GET(EQUATIONS_SET%GEOMETRY%GEOMETRIC_FIELD,FIELD_U_VARIABLE_TYPE, & 
                            & NUMBER_OF_DIMENSIONS,ERR,ERROR,*999)
                          SELECT CASE(EQUATIONS_SET_SETUP%ANALYTIC_FUNCTION_TYPE)
                          CASE(EQUATIONS_SET_NAVIER_STOKES_EQUATION_TWO_DIM_POISEUILLE)
                            !Set analtyic function type
                            EQUATIONS_SET%ANALYTIC%ANALYTIC_FUNCTION_TYPE=EQUATIONS_SET_NAVIER_STOKES_EQUATION_TWO_DIM_POISEUILLE
                            !Check that domain is 2D
                            IF(NUMBER_OF_DIMENSIONS/=2) THEN
                              LOCAL_ERROR="The number of geometric dimensions of "// &
                                & TRIM(NUMBER_TO_VSTRING(NUMBER_OF_DIMENSIONS,"*",ERR,ERROR))// &
                                & " is invalid. The analytic function type of "// &
                                & TRIM(NUMBER_TO_VSTRING(EQUATIONS_SET_SETUP%ANALYTIC_FUNCTION_TYPE,"*",ERR,ERROR))// &
                                & " requires that there be 2 geometric dimensions."
                              CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
                            END IF
                            !Check the materials values are constant
                            CALL FIELD_COMPONENT_INTERPOLATION_CHECK(EQUATIONS_MATERIALS%MATERIALS_FIELD,FIELD_U_VARIABLE_TYPE, &
                              & 1,FIELD_CONSTANT_INTERPOLATION,ERR,ERROR,*999)
                            CALL FIELD_COMPONENT_INTERPOLATION_CHECK(EQUATIONS_MATERIALS%MATERIALS_FIELD,FIELD_U_VARIABLE_TYPE, &
                              & 2,FIELD_CONSTANT_INTERPOLATION,ERR,ERROR,*999)
                            !Set analytic function type
                            EQUATIONS_SET%ANALYTIC%ANALYTIC_FUNCTION_TYPE=EQUATIONS_SET_SETUP%ANALYTIC_FUNCTION_TYPE
                            NUMBER_OF_ANALYTIC_COMPONENTS=4
                          CASE(EQUATIONS_SET_NAVIER_STOKES_EQUATION_FLOWRATE_AORTA, &
                             & EQUATIONS_SET_NAVIER_STOKES_EQUATION_FLOWRATE_OLUFSEN, &
                             & EQUATIONS_SET_NAVIER_STOKES_EQUATION_FLOWRATE_HEART, &
                             & EQUATIONS_SET_NAVIER_STOKES_EQUATION_SPLINT_FROM_FILE)
                            !Check that this is a 1D equations set
                            IF(EQUATIONS_SET%SPECIFICATION(3)==EQUATIONS_SET_TRANSIENT1D_NAVIER_STOKES_SUBTYPE .OR. &
                              & EQUATIONS_SET%SPECIFICATION(3)==EQUATIONS_SET_COUPLED1D0D_NAVIER_STOKES_SUBTYPE .OR. &
                              & EQUATIONS_SET%SPECIFICATION(3)==EQUATIONS_SET_TRANSIENT1D_ADV_NAVIER_STOKES_SUBTYPE .OR. &
                              & EQUATIONS_SET%SPECIFICATION(3)==EQUATIONS_SET_COUPLED1D0D_ADV_NAVIER_STOKES_SUBTYPE) THEN
                              !Set analytic function type
                              EQUATIONS_SET%ANALYTIC%ANALYTIC_FUNCTION_TYPE=EQUATIONS_SET_SETUP%ANALYTIC_FUNCTION_TYPE
                              !Set numbrer of components- Q,A (same as N-S depenedent field)
                              NUMBER_OF_ANALYTIC_COMPONENTS=2
                            ELSE
                              LOCAL_ERROR="The third equations set specification must by a TRANSIENT1D or COUPLED1D0D "// &
                                & "to use an analytic function of type "// &
                                & TRIM(NUMBER_TO_VSTRING(EQUATIONS_SET_SETUP%ANALYTIC_FUNCTION_TYPE,"*",ERR,ERROR))//"."
                              CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
                            END IF
                          CASE(EQUATIONS_SET_NAVIER_STOKES_EQUATION_SINUSOID)
                            !Check that domain is 2D/3D
                            IF(NUMBER_OF_DIMENSIONS<2 .OR. NUMBER_OF_DIMENSIONS>3) THEN
                              LOCAL_ERROR="The number of geometric dimensions of "// &
                                & TRIM(NUMBER_TO_VSTRING(NUMBER_OF_DIMENSIONS,"*",ERR,ERROR))// &
                                & " is invalid. The analytic function type of "// &
                                & TRIM(NUMBER_TO_VSTRING(EQUATIONS_SET_SETUP%ANALYTIC_FUNCTION_TYPE,"*",ERR,ERROR))// &
                                & " requires that there be 2 or 3 geometric dimensions."
                              CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
                            END IF
                            !Set analytic function type
                            EQUATIONS_SET%ANALYTIC%ANALYTIC_FUNCTION_TYPE=EQUATIONS_SET_SETUP%ANALYTIC_FUNCTION_TYPE
                            !Set numbrer of components
                            NUMBER_OF_ANALYTIC_COMPONENTS=10
                          CASE(EQUATIONS_SET_NAVIER_STOKES_EQUATION_TWO_DIM_TAYLOR_GREEN)
                            !Set analtyic function type
                            EQUATIONS_SET%ANALYTIC%ANALYTIC_FUNCTION_TYPE=EQUATIONS_SET_NAVIER_STOKES_EQUATION_TWO_DIM_TAYLOR_GREEN
                            !Check that domain is 2D
                            IF(NUMBER_OF_DIMENSIONS/=2) THEN
                              LOCAL_ERROR="The number of geometric dimensions of "// &
                                & TRIM(NUMBER_TO_VSTRING(NUMBER_OF_DIMENSIONS,"*",ERR,ERROR))// &
                                & " is invalid. The analytic function type of "// &
                                & TRIM(NUMBER_TO_VSTRING(EQUATIONS_SET_SETUP%ANALYTIC_FUNCTION_TYPE,"*",ERR,ERROR))// &
                                & " requires that there be 2 geometric dimensions."
                              CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
                            END IF
                            !Check the materials values are constant
                            CALL FIELD_COMPONENT_INTERPOLATION_CHECK(EQUATIONS_MATERIALS%MATERIALS_FIELD,FIELD_U_VARIABLE_TYPE, &
                              & 1,FIELD_CONSTANT_INTERPOLATION,ERR,ERROR,*999)
                            CALL FIELD_COMPONENT_INTERPOLATION_CHECK(EQUATIONS_MATERIALS%MATERIALS_FIELD,FIELD_U_VARIABLE_TYPE, &
                              & 2,FIELD_CONSTANT_INTERPOLATION,ERR,ERROR,*999)
                            !Set analytic function type
                            EQUATIONS_SET%ANALYTIC%ANALYTIC_FUNCTION_TYPE=EQUATIONS_SET_SETUP%ANALYTIC_FUNCTION_TYPE
                            NUMBER_OF_ANALYTIC_COMPONENTS=2
                          CASE(EQUATIONS_SET_NAVIER_STOKES_EQUATION_TWO_DIM_1)
                            !Set analtyic function type
                            EQUATIONS_SET%ANALYTIC%ANALYTIC_FUNCTION_TYPE=EQUATIONS_SET_NAVIER_STOKES_EQUATION_TWO_DIM_1
                          CASE(EQUATIONS_SET_NAVIER_STOKES_EQUATION_TWO_DIM_2)
                            !Set analtyic function type
                            EQUATIONS_SET%ANALYTIC%ANALYTIC_FUNCTION_TYPE=EQUATIONS_SET_NAVIER_STOKES_EQUATION_TWO_DIM_2
                          CASE(EQUATIONS_SET_NAVIER_STOKES_EQUATION_TWO_DIM_3)
                            !Set analtyic function type
                            EQUATIONS_SET%ANALYTIC%ANALYTIC_FUNCTION_TYPE=EQUATIONS_SET_NAVIER_STOKES_EQUATION_TWO_DIM_3
                          CASE(EQUATIONS_SET_NAVIER_STOKES_EQUATION_TWO_DIM_4)
                            !Set analtyic function type
                            EQUATIONS_SET%ANALYTIC%ANALYTIC_FUNCTION_TYPE=EQUATIONS_SET_NAVIER_STOKES_EQUATION_TWO_DIM_4
                          CASE(EQUATIONS_SET_NAVIER_STOKES_EQUATION_TWO_DIM_5)
                            !Set analtyic function type
                            EQUATIONS_SET%ANALYTIC%ANALYTIC_FUNCTION_TYPE=EQUATIONS_SET_NAVIER_STOKES_EQUATION_TWO_DIM_5
                          CASE(EQUATIONS_SET_NAVIER_STOKES_EQUATION_THREE_DIM_1)
                            !Set analtyic function type
                            EQUATIONS_SET%ANALYTIC%ANALYTIC_FUNCTION_TYPE=EQUATIONS_SET_NAVIER_STOKES_EQUATION_THREE_DIM_1
                          CASE(EQUATIONS_SET_NAVIER_STOKES_EQUATION_THREE_DIM_2)
                            !Set analtyic function type
                            EQUATIONS_SET%ANALYTIC%ANALYTIC_FUNCTION_TYPE=EQUATIONS_SET_NAVIER_STOKES_EQUATION_THREE_DIM_2
                          CASE(EQUATIONS_SET_NAVIER_STOKES_EQUATION_THREE_DIM_3)
                            !Set analtyic function type
                            EQUATIONS_SET%ANALYTIC%ANALYTIC_FUNCTION_TYPE=EQUATIONS_SET_NAVIER_STOKES_EQUATION_THREE_DIM_3
                          CASE(EQUATIONS_SET_NAVIER_STOKES_EQUATION_THREE_DIM_4)
                            !Set analtyic function type
                            EQUATIONS_SET%ANALYTIC%ANALYTIC_FUNCTION_TYPE=EQUATIONS_SET_NAVIER_STOKES_EQUATION_THREE_DIM_4
                          CASE(EQUATIONS_SET_NAVIER_STOKES_EQUATION_THREE_DIM_5)
                            !Set analtyic function type
                            EQUATIONS_SET%ANALYTIC%ANALYTIC_FUNCTION_TYPE=EQUATIONS_SET_NAVIER_STOKES_EQUATION_THREE_DIM_5
                          CASE(EQUATIONS_SET_NAVIER_STOKES_EQUATION_ONE_DIM_1)
                            !Set analtyic function type
                            EQUATIONS_SET%ANALYTIC%ANALYTIC_FUNCTION_TYPE=EQUATIONS_SET_NAVIER_STOKES_EQUATION_ONE_DIM_1
                          CASE DEFAULT
                            LOCAL_ERROR="The specified analytic function type of "// &
                              & TRIM(NUMBER_TO_VSTRING(EQUATIONS_SET_SETUP%ANALYTIC_FUNCTION_TYPE,"*",ERR,ERROR))// &
                              & " is invalid for an analytic Navier-Stokes problem."
                            CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
                          END SELECT
                          !Create analytic field if required
                          IF(NUMBER_OF_ANALYTIC_COMPONENTS>=1) THEN
                            IF(EQUATIONS_ANALYTIC%ANALYTIC_FIELD_AUTO_CREATED) THEN
                              !Create the auto created analytic field
                              CALL FIELD_CREATE_START(EQUATIONS_SET_SETUP%FIELD_USER_NUMBER,EQUATIONS_SET%REGION, &
                                & EQUATIONS_ANALYTIC%ANALYTIC_FIELD,ERR,ERROR,*999)
                              CALL FIELD_LABEL_SET(EQUATIONS_ANALYTIC%ANALYTIC_FIELD,"Analytic Field",ERR,ERROR,*999)
                              CALL FIELD_TYPE_SET_AND_LOCK(EQUATIONS_ANALYTIC%ANALYTIC_FIELD,FIELD_GENERAL_TYPE,ERR,ERROR,*999)
                              CALL FIELD_DEPENDENT_TYPE_SET_AND_LOCK(EQUATIONS_ANALYTIC%ANALYTIC_FIELD,FIELD_INDEPENDENT_TYPE, &
                                & ERR,ERROR,*999)
                              CALL FIELD_MESH_DECOMPOSITION_GET(EQUATIONS_SET%GEOMETRY%GEOMETRIC_FIELD,GEOMETRIC_DECOMPOSITION, &
                                & ERR,ERROR,*999)
                              CALL FIELD_MESH_DECOMPOSITION_SET_AND_LOCK(EQUATIONS_ANALYTIC%ANALYTIC_FIELD, &
                                & GEOMETRIC_DECOMPOSITION,ERR,ERROR,*999)
                              CALL FIELD_GEOMETRIC_FIELD_SET_AND_LOCK(EQUATIONS_ANALYTIC%ANALYTIC_FIELD,EQUATIONS_SET%GEOMETRY% &
                                & GEOMETRIC_FIELD,ERR,ERROR,*999)
                              CALL FIELD_NUMBER_OF_VARIABLES_SET_AND_LOCK(EQUATIONS_ANALYTIC%ANALYTIC_FIELD,1,ERR,ERROR,*999)
                              CALL FIELD_VARIABLE_TYPES_SET_AND_LOCK(EQUATIONS_ANALYTIC%ANALYTIC_FIELD,[FIELD_U_VARIABLE_TYPE], &
                                & ERR,ERROR,*999)
                              CALL FIELD_VARIABLE_LABEL_SET(EQUATIONS_ANALYTIC%ANALYTIC_FIELD,FIELD_U_VARIABLE_TYPE, &
                                & "Analytic",ERR,ERROR,*999)
                              CALL FIELD_DIMENSION_SET_AND_LOCK(EQUATIONS_ANALYTIC%ANALYTIC_FIELD,FIELD_U_VARIABLE_TYPE, &
                                & FIELD_VECTOR_DIMENSION_TYPE,ERR,ERROR,*999)
                              CALL FIELD_DATA_TYPE_SET_AND_LOCK(EQUATIONS_ANALYTIC%ANALYTIC_FIELD,FIELD_U_VARIABLE_TYPE, &
                                & FIELD_DP_TYPE,ERR,ERROR,*999)
                              !Set the number of analytic components
                              CALL FIELD_NUMBER_OF_COMPONENTS_SET_AND_LOCK(EQUATIONS_ANALYTIC%ANALYTIC_FIELD, &
                                & FIELD_U_VARIABLE_TYPE,NUMBER_OF_ANALYTIC_COMPONENTS,ERR,ERROR,*999)
                              !Default the analytic components to the 1st geometric interpolation setup with constant interpolation
                              CALL FIELD_COMPONENT_MESH_COMPONENT_GET(EQUATIONS_SET%GEOMETRY%GEOMETRIC_FIELD, &
                                & FIELD_U_VARIABLE_TYPE,1,GEOMETRIC_MESH_COMPONENT,ERR,ERROR,*999)
                              DO componentIdx=1,NUMBER_OF_ANALYTIC_COMPONENTS
                                CALL FIELD_COMPONENT_MESH_COMPONENT_SET(EQUATIONS_ANALYTIC%ANALYTIC_FIELD,FIELD_U_VARIABLE_TYPE, &
                                  & componentIdx,GEOMETRIC_MESH_COMPONENT,ERR,ERROR,*999)
                                IF(EQUATIONS_SET_SETUP%ANALYTIC_FUNCTION_TYPE == &
                                 & EQUATIONS_SET_NAVIER_STOKES_EQUATION_SINUSOID) THEN
                                  CALL FIELD_COMPONENT_INTERPOLATION_SET(EQUATIONS_ANALYTIC%ANALYTIC_FIELD,FIELD_U_VARIABLE_TYPE, &
                                    & componentIdx,FIELD_NODE_BASED_INTERPOLATION,ERR,ERROR,*999)
                                ELSE
                                  CALL FIELD_COMPONENT_INTERPOLATION_SET(EQUATIONS_ANALYTIC%ANALYTIC_FIELD,FIELD_U_VARIABLE_TYPE, &
                                    & componentIdx,FIELD_CONSTANT_INTERPOLATION,ERR,ERROR,*999)
                                END IF
                              END DO !componentIdx
                              !Default the field scaling to that of the geometric field
                              CALL FIELD_SCALING_TYPE_GET(EQUATIONS_SET%GEOMETRY%GEOMETRIC_FIELD,GEOMETRIC_SCALING_TYPE, &
                                & ERR,ERROR,*999)
                              CALL FIELD_SCALING_TYPE_SET(EQUATIONS_ANALYTIC%ANALYTIC_FIELD,GEOMETRIC_SCALING_TYPE,ERR,ERROR,*999)
                            ELSE
                              !Check the user specified field
                              CALL FIELD_TYPE_CHECK(EQUATIONS_SET_SETUP%FIELD,FIELD_GENERAL_TYPE,ERR,ERROR,*999)
                              CALL FIELD_DEPENDENT_TYPE_CHECK(EQUATIONS_SET_SETUP%FIELD,FIELD_INDEPENDENT_TYPE,ERR,ERROR,*999)
                              CALL FIELD_NUMBER_OF_VARIABLES_CHECK(EQUATIONS_SET_SETUP%FIELD,1,ERR,ERROR,*999)
                              CALL FIELD_VARIABLE_TYPES_CHECK(EQUATIONS_SET_SETUP%FIELD,[FIELD_U_VARIABLE_TYPE],ERR,ERROR,*999)
                              IF(NUMBER_OF_ANALYTIC_COMPONENTS==1) THEN
                                CALL FIELD_DIMENSION_CHECK(EQUATIONS_SET_SETUP%FIELD,FIELD_U_VARIABLE_TYPE, &
                                  & FIELD_SCALAR_DIMENSION_TYPE,ERR,ERROR,*999)
                              ELSE
                                CALL FIELD_DIMENSION_CHECK(EQUATIONS_SET_SETUP%FIELD,FIELD_U_VARIABLE_TYPE, &
                                  & FIELD_VECTOR_DIMENSION_TYPE,ERR,ERROR,*999)
                              END IF
                              CALL FIELD_DATA_TYPE_CHECK(EQUATIONS_SET_SETUP%FIELD,FIELD_U_VARIABLE_TYPE,FIELD_DP_TYPE, &
                                & ERR,ERROR,*999)
                              CALL FIELD_NUMBER_OF_COMPONENTS_CHECK(EQUATIONS_SET_SETUP%FIELD,FIELD_U_VARIABLE_TYPE, &
                                & NUMBER_OF_ANALYTIC_COMPONENTS,ERR,ERROR,*999)
                            END IF
                          END IF
                        ELSE
                          CALL FlagError("Equations set materials is not finished.",ERR,ERROR,*999)
                        END IF
                      ELSE
                        CALL FlagError("Equations set materials is not associated.",ERR,ERROR,*999)
                      END IF
                    ELSE
                      CALL FlagError("Equations set geometric field is not associated.",ERR,ERROR,*999)
                    END IF
                  ELSE
                    CALL FlagError("Equations set dependent field is not associated.",ERR,ERROR,*999)
                  END IF
                ELSE
                  CALL FlagError("Equations set dependent field has not been finished.",ERR,ERROR,*999)
                END IF
              ELSE
                CALL FlagError("Equations analytic is not associated.",ERR,ERROR,*999)
              END IF
            CASE(EQUATIONS_SET_SETUP_FINISH_ACTION)
              EQUATIONS_ANALYTIC=>EQUATIONS_SET%ANALYTIC
              IF(ASSOCIATED(EQUATIONS_ANALYTIC)) THEN
                ANALYTIC_FIELD=>EQUATIONS_ANALYTIC%ANALYTIC_FIELD
                IF(ASSOCIATED(ANALYTIC_FIELD)) THEN
                  IF(EQUATIONS_ANALYTIC%ANALYTIC_FIELD_AUTO_CREATED) THEN
                    !Finish creating the analytic field
                    CALL FIELD_CREATE_FINISH(EQUATIONS_ANALYTIC%ANALYTIC_FIELD,ERR,ERROR,*999)
                    !Set the default values for the analytic field
                    SELECT CASE(EQUATIONS_SET%SPECIFICATION(3))
                    CASE(EQUATIONS_SET_STATIC_NAVIER_STOKES_SUBTYPE, &
                       & EQUATIONS_SET_STATIC_RBS_NAVIER_STOKES_SUBTYPE)
                      SELECT CASE(EQUATIONS_ANALYTIC%ANALYTIC_FUNCTION_TYPE)
                      CASE(EQUATIONS_SET_NAVIER_STOKES_EQUATION_TWO_DIM_POISEUILLE)
                        !Default the analytic parameter values (L, H, U_mean, Pout) to 0.0
                        CALL FIELD_COMPONENT_VALUES_INITIALISE(EQUATIONS_ANALYTIC%ANALYTIC_FIELD,FIELD_U_VARIABLE_TYPE, &
                          & FIELD_VALUES_SET_TYPE,1,0.0_DP,ERR,ERROR,*999)
                        CALL FIELD_COMPONENT_VALUES_INITIALISE(EQUATIONS_ANALYTIC%ANALYTIC_FIELD,FIELD_U_VARIABLE_TYPE, &
                          & FIELD_VALUES_SET_TYPE,2,0.0_DP,ERR,ERROR,*999)
                        CALL FIELD_COMPONENT_VALUES_INITIALISE(EQUATIONS_ANALYTIC%ANALYTIC_FIELD,FIELD_U_VARIABLE_TYPE, &
                          & FIELD_VALUES_SET_TYPE,3,0.0_DP,ERR,ERROR,*999)
                        CALL FIELD_COMPONENT_VALUES_INITIALISE(EQUATIONS_ANALYTIC%ANALYTIC_FIELD,FIELD_U_VARIABLE_TYPE, &
                          & FIELD_VALUES_SET_TYPE,4,0.0_DP,ERR,ERROR,*999)
                      CASE DEFAULT
                        LOCAL_ERROR="The analytic function type of "// &
                          & TRIM(NUMBER_TO_VSTRING(EQUATIONS_ANALYTIC%ANALYTIC_FUNCTION_TYPE,"*",ERR,ERROR))// &
                          & " is invalid for an analytical static Navier-Stokes equation."
                        CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
                      END SELECT
                    CASE(EQUATIONS_SET_TRANSIENT_NAVIER_STOKES_SUBTYPE, &
                       & EQUATIONS_SET_TRANSIENT_RBS_NAVIER_STOKES_SUBTYPE, &
                       & EQUATIONS_SET_MULTISCALE3D_NAVIER_STOKES_SUBTYPE, &
                       & EQUATIONS_SET_CONSTITUTIVE_MU_NAVIER_STOKES_SUBTYPE)
                      SELECT CASE(EQUATIONS_ANALYTIC%ANALYTIC_FUNCTION_TYPE)
                      CASE(EQUATIONS_SET_NAVIER_STOKES_EQUATION_TWO_DIM_TAYLOR_GREEN)
                        !Default the analytic parameter values (U_characteristic, L) to 0.0
                        CALL FIELD_COMPONENT_VALUES_INITIALISE(EQUATIONS_ANALYTIC%ANALYTIC_FIELD,FIELD_U_VARIABLE_TYPE, &
                          & FIELD_VALUES_SET_TYPE,1,0.0_DP,ERR,ERROR,*999)
                        CALL FIELD_COMPONENT_VALUES_INITIALISE(EQUATIONS_ANALYTIC%ANALYTIC_FIELD,FIELD_U_VARIABLE_TYPE, &
                          & FIELD_VALUES_SET_TYPE,2,0.0_DP,ERR,ERROR,*999)
                      CASE(EQUATIONS_SET_NAVIER_STOKES_EQUATION_SINUSOID)
                        !Default the analytic parameter values to 0
                        NUMBER_OF_ANALYTIC_COMPONENTS = 10
                        DO componentIdx = 1,NUMBER_OF_ANALYTIC_COMPONENTS
                          CALL FIELD_COMPONENT_VALUES_INITIALISE(EQUATIONS_ANALYTIC%ANALYTIC_FIELD,FIELD_U_VARIABLE_TYPE, &
                            & FIELD_VALUES_SET_TYPE,componentIdx,0.0_DP,ERR,ERROR,*999)
                        END DO
                      CASE DEFAULT
                        LOCAL_ERROR="The analytic function type of "// &
                          & TRIM(NUMBER_TO_VSTRING(EQUATIONS_ANALYTIC%ANALYTIC_FUNCTION_TYPE,"*",ERR,ERROR))// &
                          & " is invalid for an analytical transient Navier-Stokes equation."
                        CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
                      END SELECT
                    CASE(EQUATIONS_SET_TRANSIENT1D_NAVIER_STOKES_SUBTYPE, &
                       & EQUATIONS_SET_COUPLED1D0D_NAVIER_STOKES_SUBTYPE, &
                       & EQUATIONS_SET_TRANSIENT1D_ADV_NAVIER_STOKES_SUBTYPE, &
                       & EQUATIONS_SET_COUPLED1D0D_ADV_NAVIER_STOKES_SUBTYPE)
                      SELECT CASE(EQUATIONS_ANALYTIC%ANALYTIC_FUNCTION_TYPE)
                      CASE(EQUATIONS_SET_NAVIER_STOKES_EQUATION_FLOWRATE_AORTA, &
                         & EQUATIONS_SET_NAVIER_STOKES_EQUATION_FLOWRATE_OLUFSEN, &
                         & EQUATIONS_SET_NAVIER_STOKES_EQUATION_FLOWRATE_HEART, &
                         & EQUATIONS_SET_NAVIER_STOKES_EQUATION_SPLINT_FROM_FILE)
                        !Default the analytic parameter period values to 0
                        CALL FIELD_COMPONENT_VALUES_INITIALISE(EQUATIONS_ANALYTIC%ANALYTIC_FIELD,FIELD_U_VARIABLE_TYPE, &
                          & FIELD_VALUES_SET_TYPE,1,0.0_DP,ERR,ERROR,*999)
                      CASE DEFAULT
                        LOCAL_ERROR="The analytic function type of "// &
                          & TRIM(NUMBER_TO_VSTRING(EQUATIONS_ANALYTIC%ANALYTIC_FUNCTION_TYPE,"*",ERR,ERROR))// &
                          & " is invalid for a 1D Navier-Stokes equation."
                        CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
                      END SELECT
                    CASE DEFAULT
                      LOCAL_ERROR="The third equations set specification of "// &
                        & TRIM(NUMBER_TO_VSTRING(EQUATIONS_SET%SPECIFICATION(3),"*",ERR,ERROR))// &
                        & " is invalid for an analytical Navier-Stokes equation set."
                      CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
                    END SELECT
                  END IF
                END IF
              ELSE
                CALL FlagError("Equations set analytic is not associated.",ERR,ERROR,*999)
              END IF
            CASE DEFAULT
              LOCAL_ERROR="The action type of "//TRIM(NUMBER_TO_VSTRING(EQUATIONS_SET_SETUP%ACTION_TYPE,"*",ERR,ERROR))// &
                & " for a setup type of "//TRIM(NUMBER_TO_VSTRING(EQUATIONS_SET_SETUP%SETUP_TYPE,"*",ERR,ERROR))// &
                & " is invalid for an analytic Navier-Stokes problem."
              CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
            END SELECT
          CASE DEFAULT
            LOCAL_ERROR="The third equations set specification of "// &
              & TRIM(NUMBER_TO_VSTRING(EQUATIONS_SET%SPECIFICATION(3),"*",ERR,ERROR))// &
              & " for a setup type of "//TRIM(NUMBER_TO_VSTRING(EQUATIONS_SET_SETUP%SETUP_TYPE,"*",ERR,ERROR))// &
              & " is invalid for a Navier-Stokes equation set."
            CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
          END SELECT
        !-----------------------------------------------------------------
        ! M a t e r i a l s   f i e l d 
        !-----------------------------------------------------------------
        CASE(EQUATIONS_SET_SETUP_MATERIALS_TYPE)
          SELECT CASE(EQUATIONS_SET%SPECIFICATION(3))
          CASE(EQUATIONS_SET_STATIC_NAVIER_STOKES_SUBTYPE,EQUATIONS_SET_LAPLACE_NAVIER_STOKES_SUBTYPE, &
            & EQUATIONS_SET_STATIC_RBS_NAVIER_STOKES_SUBTYPE, &
            & EQUATIONS_SET_TRANSIENT_NAVIER_STOKES_SUBTYPE,EQUATIONS_SET_ALE_NAVIER_STOKES_SUBTYPE, &
            & EQUATIONS_SET_PGM_NAVIER_STOKES_SUBTYPE,EQUATIONS_SET_QUASISTATIC_NAVIER_STOKES_SUBTYPE, &
            & EQUATIONS_SET_TRANSIENT_RBS_NAVIER_STOKES_SUBTYPE, &
            & EQUATIONS_SET_MULTISCALE3D_NAVIER_STOKES_SUBTYPE)
            MATERIAL_FIELD_NUMBER_OF_VARIABLES=1
            MATERIAL_FIELD_NUMBER_OF_COMPONENTS1=2! viscosity, density
            SELECT CASE(EQUATIONS_SET_SETUP%ACTION_TYPE)
            !Specify start action
            CASE(EQUATIONS_SET_SETUP_START_ACTION)
              EQUATIONS_MATERIALS=>EQUATIONS_SET%MATERIALS
              IF(ASSOCIATED(EQUATIONS_MATERIALS)) THEN
                IF(EQUATIONS_MATERIALS%MATERIALS_FIELD_AUTO_CREATED) THEN
                  !Create the auto created materials field
                  !start field creation with name 'MATERIAL_FIELD'
                  CALL FIELD_CREATE_START(EQUATIONS_SET_SETUP%FIELD_USER_NUMBER,EQUATIONS_SET%REGION, & 
                    & EQUATIONS_SET%MATERIALS%MATERIALS_FIELD,ERR,ERROR,*999)
                  CALL FIELD_TYPE_SET_AND_LOCK(EQUATIONS_MATERIALS%MATERIALS_FIELD,FIELD_MATERIAL_TYPE,ERR,ERROR,*999)
                  !label the field
                  CALL FIELD_LABEL_SET(EQUATIONS_MATERIALS%MATERIALS_FIELD,"Materials Field",ERR,ERROR,*999)
                  CALL FIELD_DEPENDENT_TYPE_SET_AND_LOCK(EQUATIONS_MATERIALS%MATERIALS_FIELD,FIELD_INDEPENDENT_TYPE, &
                    & ERR,ERROR,*999)
                  CALL FIELD_MESH_DECOMPOSITION_GET(EQUATIONS_SET%GEOMETRY%GEOMETRIC_FIELD,GEOMETRIC_DECOMPOSITION, & 
                    & ERR,ERROR,*999)
                  !apply decomposition rule found on new created field
                  CALL FIELD_MESH_DECOMPOSITION_SET_AND_LOCK(EQUATIONS_SET%MATERIALS%MATERIALS_FIELD, & 
                    & GEOMETRIC_DECOMPOSITION,ERR,ERROR,*999)
                  !point new field to geometric field
                  CALL FIELD_GEOMETRIC_FIELD_SET_AND_LOCK(EQUATIONS_MATERIALS%MATERIALS_FIELD,EQUATIONS_SET%GEOMETRY% &
                    & GEOMETRIC_FIELD,ERR,ERROR,*999)
                  CALL FIELD_NUMBER_OF_VARIABLES_SET(EQUATIONS_MATERIALS%MATERIALS_FIELD, & 
                    & MATERIAL_FIELD_NUMBER_OF_VARIABLES,ERR,ERROR,*999)
                  CALL FIELD_VARIABLE_TYPES_SET_AND_LOCK(EQUATIONS_MATERIALS%MATERIALS_FIELD, & 
                    &[FIELD_U_VARIABLE_TYPE],ERR,ERROR,*999)
                  CALL FIELD_VARIABLE_LABEL_SET(EQUATIONS_MATERIALS%MATERIALS_FIELD,FIELD_U_VARIABLE_TYPE, &
                     & "Materials",ERR,ERROR,*999)
                  CALL FIELD_DIMENSION_SET_AND_LOCK(EQUATIONS_MATERIALS%MATERIALS_FIELD,FIELD_U_VARIABLE_TYPE, &
                    & FIELD_VECTOR_DIMENSION_TYPE,ERR,ERROR,*999)
                  CALL FIELD_DATA_TYPE_SET_AND_LOCK(EQUATIONS_MATERIALS%MATERIALS_FIELD,FIELD_U_VARIABLE_TYPE, &
                    & FIELD_DP_TYPE,ERR,ERROR,*999)
                  CALL FIELD_NUMBER_OF_COMPONENTS_SET_AND_LOCK(EQUATIONS_MATERIALS%MATERIALS_FIELD, & 
                    & FIELD_U_VARIABLE_TYPE,MATERIAL_FIELD_NUMBER_OF_COMPONENTS1,ERR,ERROR,*999)
                  CALL FIELD_COMPONENT_MESH_COMPONENT_GET(EQUATIONS_SET%GEOMETRY%GEOMETRIC_FIELD, & 
                    & FIELD_U_VARIABLE_TYPE,1,GEOMETRIC_COMPONENT_NUMBER,ERR,ERROR,*999)
                  CALL FIELD_COMPONENT_MESH_COMPONENT_SET(EQUATIONS_MATERIALS%MATERIALS_FIELD,FIELD_U_VARIABLE_TYPE, &
                    & 1,GEOMETRIC_COMPONENT_NUMBER,ERR,ERROR,*999)
                  CALL FIELD_COMPONENT_INTERPOLATION_SET(EQUATIONS_MATERIALS%MATERIALS_FIELD,FIELD_U_VARIABLE_TYPE, &
                    & 1,FIELD_CONSTANT_INTERPOLATION,ERR,ERROR,*999)
                  CALL FIELD_COMPONENT_INTERPOLATION_SET(EQUATIONS_MATERIALS%MATERIALS_FIELD,FIELD_U_VARIABLE_TYPE, &
                    & 2,FIELD_CONSTANT_INTERPOLATION,ERR,ERROR,*999)
                  !Default the field scaling to that of the geometric field
                  CALL FIELD_SCALING_TYPE_GET(EQUATIONS_SET%GEOMETRY%GEOMETRIC_FIELD,GEOMETRIC_SCALING_TYPE, & 
                    & ERR,ERROR,*999)
                  CALL FIELD_SCALING_TYPE_SET(EQUATIONS_MATERIALS%MATERIALS_FIELD,GEOMETRIC_SCALING_TYPE,ERR,ERROR,*999)
                ELSE
                  !Check the user specified field
                  CALL FIELD_TYPE_CHECK(EQUATIONS_SET_SETUP%FIELD,FIELD_MATERIAL_TYPE,ERR,ERROR,*999)
                  CALL FIELD_DEPENDENT_TYPE_CHECK(EQUATIONS_SET_SETUP%FIELD,FIELD_INDEPENDENT_TYPE,ERR,ERROR,*999)
                  CALL FIELD_NUMBER_OF_VARIABLES_CHECK(EQUATIONS_SET_SETUP%FIELD,1,ERR,ERROR,*999)
                  CALL FIELD_VARIABLE_TYPES_CHECK(EQUATIONS_SET_SETUP%FIELD,[FIELD_U_VARIABLE_TYPE],ERR,ERROR,*999)
                  CALL FIELD_DIMENSION_CHECK(EQUATIONS_SET_SETUP%FIELD,FIELD_U_VARIABLE_TYPE, & 
                    & FIELD_VECTOR_DIMENSION_TYPE,ERR,ERROR,*999)
                  CALL FIELD_DATA_TYPE_CHECK(EQUATIONS_SET_SETUP%FIELD,FIELD_U_VARIABLE_TYPE,FIELD_DP_TYPE, & 
                    & ERR,ERROR,*999)
                  CALL FIELD_NUMBER_OF_COMPONENTS_GET(EQUATIONS_SET%GEOMETRY%GEOMETRIC_FIELD,FIELD_U_VARIABLE_TYPE, &
                    & NUMBER_OF_DIMENSIONS,ERR,ERROR,*999)
                  CALL FIELD_NUMBER_OF_COMPONENTS_CHECK(EQUATIONS_SET_SETUP%FIELD,FIELD_U_VARIABLE_TYPE,1,ERR,ERROR,*999)
                END IF
              ELSE
                CALL FlagError("Equations set materials is not associated.",ERR,ERROR,*999)
              END IF
            !Specify start action
            CASE(EQUATIONS_SET_SETUP_FINISH_ACTION)
              EQUATIONS_MATERIALS=>EQUATIONS_SET%MATERIALS
              IF(ASSOCIATED(EQUATIONS_MATERIALS)) THEN
                IF(EQUATIONS_MATERIALS%MATERIALS_FIELD_AUTO_CREATED) THEN
                  !Finish creating the materials field
                  CALL FIELD_CREATE_FINISH(EQUATIONS_MATERIALS%MATERIALS_FIELD,ERR,ERROR,*999)
                  !Set the default values for the materials field
                  ! viscosity,density=1
                  CALL FIELD_COMPONENT_VALUES_INITIALISE(EQUATIONS_MATERIALS%MATERIALS_FIELD,FIELD_U_VARIABLE_TYPE, &
                    & FIELD_VALUES_SET_TYPE,1,1.0_DP,ERR,ERROR,*999)
                  CALL FIELD_COMPONENT_VALUES_INITIALISE(EQUATIONS_MATERIALS%MATERIALS_FIELD,FIELD_U_VARIABLE_TYPE, &
                    & FIELD_VALUES_SET_TYPE,2,1.0_DP,ERR,ERROR,*999)
                END IF
              ELSE
                CALL FlagError("Equations set materials is not associated.",ERR,ERROR,*999)
              END IF
            CASE DEFAULT
              LOCAL_ERROR="The action type of "//TRIM(NUMBER_TO_VSTRING(EQUATIONS_SET_SETUP%ACTION_TYPE,"*", & 
                & ERR,ERROR))//" for a setup type of "//TRIM(NUMBER_TO_VSTRING(EQUATIONS_SET_SETUP%SETUP_TYPE,"*", & 
                & ERR,ERROR))//" is invalid for Navier-Stokes equation."
              CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
            END SELECT
          CASE(EQUATIONS_SET_CONSTITUTIVE_MU_NAVIER_STOKES_SUBTYPE)
            MATERIAL_FIELD_NUMBER_OF_VARIABLES=2
            MATERIAL_FIELD_NUMBER_OF_COMPONENTS1=2! U_var (constant)  : viscosity scale, density
            MATERIAL_FIELD_NUMBER_OF_COMPONENTS2=2! V_var (gaussBased): viscosity, shear rate
            SELECT CASE(EQUATIONS_SET_SETUP%ACTION_TYPE)
            !Specify start action
            CASE(EQUATIONS_SET_SETUP_START_ACTION)
              EQUATIONS_MATERIALS=>EQUATIONS_SET%MATERIALS
              IF(ASSOCIATED(EQUATIONS_MATERIALS)) THEN
                IF(EQUATIONS_MATERIALS%MATERIALS_FIELD_AUTO_CREATED) THEN
                  !Create the auto created materials field
                  !start field creation with name 'MATERIAL_FIELD'
                  CALL FIELD_CREATE_START(EQUATIONS_SET_SETUP%FIELD_USER_NUMBER,EQUATIONS_SET%REGION, & 
                    & EQUATIONS_SET%MATERIALS%MATERIALS_FIELD,ERR,ERROR,*999)
                  CALL FIELD_TYPE_SET_AND_LOCK(EQUATIONS_MATERIALS%MATERIALS_FIELD,FIELD_MATERIAL_TYPE,ERR,ERROR,*999)
                  !label the field
                  CALL FIELD_LABEL_SET(EQUATIONS_MATERIALS%MATERIALS_FIELD,"MaterialsField",ERR,ERROR,*999)
                  CALL FIELD_DEPENDENT_TYPE_SET_AND_LOCK(EQUATIONS_MATERIALS%MATERIALS_FIELD,FIELD_INDEPENDENT_TYPE, &
                    & ERR,ERROR,*999)
                  CALL FIELD_MESH_DECOMPOSITION_GET(EQUATIONS_SET%GEOMETRY%GEOMETRIC_FIELD,GEOMETRIC_DECOMPOSITION, & 
                    & ERR,ERROR,*999)
                  !apply decomposition rule found on new created field
                  CALL FIELD_MESH_DECOMPOSITION_SET_AND_LOCK(EQUATIONS_SET%MATERIALS%MATERIALS_FIELD, & 
                    & GEOMETRIC_DECOMPOSITION,ERR,ERROR,*999)
                  !point new field to geometric field
                  CALL FIELD_GEOMETRIC_FIELD_SET_AND_LOCK(EQUATIONS_MATERIALS%MATERIALS_FIELD,EQUATIONS_SET%GEOMETRY% &
                    & GEOMETRIC_FIELD,ERR,ERROR,*999)
                  CALL FIELD_NUMBER_OF_VARIABLES_SET(EQUATIONS_MATERIALS%MATERIALS_FIELD, & 
                    & MATERIAL_FIELD_NUMBER_OF_VARIABLES,ERR,ERROR,*999)
                  CALL FIELD_VARIABLE_TYPES_SET_AND_LOCK(EQUATIONS_MATERIALS%MATERIALS_FIELD, & 
                    &[FIELD_U_VARIABLE_TYPE,FIELD_V_VARIABLE_TYPE],ERR,ERROR,*999)
                  ! Set up U_VARIABLE (constants)
                  CALL FIELD_VARIABLE_LABEL_SET(EQUATIONS_MATERIALS%MATERIALS_FIELD,FIELD_U_VARIABLE_TYPE, &
                     & "MaterialsConstants",ERR,ERROR,*999)
                  CALL FIELD_DIMENSION_SET_AND_LOCK(EQUATIONS_MATERIALS%MATERIALS_FIELD,FIELD_U_VARIABLE_TYPE, &
                    & FIELD_VECTOR_DIMENSION_TYPE,ERR,ERROR,*999)
                  CALL FIELD_DATA_TYPE_SET_AND_LOCK(EQUATIONS_MATERIALS%MATERIALS_FIELD,FIELD_U_VARIABLE_TYPE, &
                    & FIELD_DP_TYPE,ERR,ERROR,*999)
                  CALL FIELD_NUMBER_OF_COMPONENTS_SET_AND_LOCK(EQUATIONS_MATERIALS%MATERIALS_FIELD, & 
                    & FIELD_U_VARIABLE_TYPE,MATERIAL_FIELD_NUMBER_OF_COMPONENTS1,ERR,ERROR,*999)
                  CALL FIELD_COMPONENT_MESH_COMPONENT_GET(EQUATIONS_SET%GEOMETRY%GEOMETRIC_FIELD, & 
                    & FIELD_U_VARIABLE_TYPE,1,GEOMETRIC_COMPONENT_NUMBER,ERR,ERROR,*999)
                  CALL FIELD_COMPONENT_MESH_COMPONENT_SET(EQUATIONS_MATERIALS%MATERIALS_FIELD,FIELD_U_VARIABLE_TYPE, &
                    & 1,GEOMETRIC_COMPONENT_NUMBER,ERR,ERROR,*999)
                  DO componentIdx=1,MATERIAL_FIELD_NUMBER_OF_COMPONENTS2
                    CALL FIELD_COMPONENT_INTERPOLATION_SET(EQUATIONS_MATERIALS%MATERIALS_FIELD,FIELD_U_VARIABLE_TYPE, &
                      & componentIdx,FIELD_CONSTANT_INTERPOLATION,ERR,ERROR,*999)
                  END DO
                  ! Set up V_VARIABLE (gauss-point based, CellML in/out parameters)
                  CALL FIELD_VARIABLE_LABEL_SET(EQUATIONS_MATERIALS%MATERIALS_FIELD,FIELD_V_VARIABLE_TYPE, &
                     & "ConstitutiveValues",ERR,ERROR,*999)
                  CALL FIELD_DIMENSION_SET_AND_LOCK(EQUATIONS_MATERIALS%MATERIALS_FIELD,FIELD_V_VARIABLE_TYPE, &
                    & FIELD_VECTOR_DIMENSION_TYPE,ERR,ERROR,*999)
                  CALL FIELD_DATA_TYPE_SET_AND_LOCK(EQUATIONS_MATERIALS%MATERIALS_FIELD,FIELD_V_VARIABLE_TYPE, &
                    & FIELD_DP_TYPE,ERR,ERROR,*999)
                  CALL FIELD_NUMBER_OF_COMPONENTS_SET_AND_LOCK(EQUATIONS_MATERIALS%MATERIALS_FIELD, & 
                    & FIELD_V_VARIABLE_TYPE,MATERIAL_FIELD_NUMBER_OF_COMPONENTS2,ERR,ERROR,*999)
                  CALL FIELD_COMPONENT_MESH_COMPONENT_GET(EQUATIONS_SET%GEOMETRY%GEOMETRIC_FIELD, & 
                    & FIELD_U_VARIABLE_TYPE,1,GEOMETRIC_COMPONENT_NUMBER,ERR,ERROR,*999)
                  CALL FIELD_COMPONENT_MESH_COMPONENT_SET(EQUATIONS_MATERIALS%MATERIALS_FIELD,FIELD_V_VARIABLE_TYPE, &
                    & 1,GEOMETRIC_COMPONENT_NUMBER,ERR,ERROR,*999)
                  DO componentIdx=1,MATERIAL_FIELD_NUMBER_OF_COMPONENTS2
                    CALL FIELD_COMPONENT_INTERPOLATION_SET(EQUATIONS_MATERIALS%MATERIALS_FIELD,FIELD_V_VARIABLE_TYPE, &
                      & componentIdx,FIELD_GAUSS_POINT_BASED_INTERPOLATION,ERR,ERROR,*999)
                  END DO
                  !Default the field scaling to that of the geometric field
                  CALL FIELD_SCALING_TYPE_GET(EQUATIONS_SET%GEOMETRY%GEOMETRIC_FIELD,GEOMETRIC_SCALING_TYPE, & 
                    & ERR,ERROR,*999)
                  CALL FIELD_SCALING_TYPE_SET(EQUATIONS_MATERIALS%MATERIALS_FIELD,GEOMETRIC_SCALING_TYPE,ERR,ERROR,*999)
                ELSE
                  !Check the user specified field
                  CALL FIELD_TYPE_CHECK(EQUATIONS_SET_SETUP%FIELD,FIELD_MATERIAL_TYPE,ERR,ERROR,*999)
                  CALL FIELD_DEPENDENT_TYPE_CHECK(EQUATIONS_SET_SETUP%FIELD,FIELD_INDEPENDENT_TYPE,ERR,ERROR,*999)
                  CALL FIELD_NUMBER_OF_VARIABLES_CHECK(EQUATIONS_SET_SETUP%FIELD,MATERIAL_FIELD_NUMBER_OF_VARIABLES,ERR,ERROR,*999)
                  CALL FIELD_VARIABLE_TYPES_CHECK(EQUATIONS_SET_SETUP%FIELD, &
                    & [FIELD_U_VARIABLE_TYPE,FIELD_V_VARIABLE_TYPE],ERR,ERROR,*999)
                  ! Check the U_VARIABLE
                  CALL FIELD_DIMENSION_CHECK(EQUATIONS_SET_SETUP%FIELD,FIELD_U_VARIABLE_TYPE, & 
                    & FIELD_VECTOR_DIMENSION_TYPE,ERR,ERROR,*999)
                  CALL FIELD_DATA_TYPE_CHECK(EQUATIONS_SET_SETUP%FIELD,FIELD_U_VARIABLE_TYPE,FIELD_DP_TYPE, & 
                    & ERR,ERROR,*999)
                  CALL FIELD_NUMBER_OF_COMPONENTS_GET(EQUATIONS_SET%GEOMETRY%GEOMETRIC_FIELD,FIELD_U_VARIABLE_TYPE, &
                    & NUMBER_OF_DIMENSIONS,ERR,ERROR,*999)
                  CALL FIELD_NUMBER_OF_COMPONENTS_CHECK(EQUATIONS_SET_SETUP%FIELD,FIELD_U_VARIABLE_TYPE, &
                    & MATERIAL_FIELD_NUMBER_OF_COMPONENTS1,ERR,ERROR,*999)
                  ! Check the U_VARIABLE
                  CALL FIELD_DIMENSION_CHECK(EQUATIONS_SET_SETUP%FIELD,FIELD_V_VARIABLE_TYPE, & 
                    & FIELD_VECTOR_DIMENSION_TYPE,ERR,ERROR,*999)
                  CALL FIELD_DATA_TYPE_CHECK(EQUATIONS_SET_SETUP%FIELD,FIELD_V_VARIABLE_TYPE,FIELD_DP_TYPE, & 
                    & ERR,ERROR,*999)
                  CALL FIELD_NUMBER_OF_COMPONENTS_CHECK(EQUATIONS_SET_SETUP%FIELD,FIELD_V_VARIABLE_TYPE, &
                    & MATERIAL_FIELD_NUMBER_OF_COMPONENTS2,ERR,ERROR,*999)
                END IF
              ELSE
                CALL FlagError("Equations set materials is not associated.",ERR,ERROR,*999)
              END IF
            !Specify start action
            CASE(EQUATIONS_SET_SETUP_FINISH_ACTION)
              EQUATIONS_MATERIALS=>EQUATIONS_SET%MATERIALS
              IF(ASSOCIATED(EQUATIONS_MATERIALS)) THEN
                IF(EQUATIONS_MATERIALS%MATERIALS_FIELD_AUTO_CREATED) THEN
                  !Finish creating the materials field
                  CALL FIELD_CREATE_FINISH(EQUATIONS_MATERIALS%MATERIALS_FIELD,ERR,ERROR,*999)
                  !Set the default values for the materials constants (viscosity scale, density)
                  DO componentIdx=1,MATERIAL_FIELD_NUMBER_OF_COMPONENTS2
                    CALL FIELD_COMPONENT_VALUES_INITIALISE(EQUATIONS_MATERIALS%MATERIALS_FIELD,FIELD_U_VARIABLE_TYPE, &
                      & FIELD_VALUES_SET_TYPE,componentIdx,1.0_DP,ERR,ERROR,*999)
                  END DO
                  !Set the default values for the materials consitutive parameters (viscosity scale, density)
                  DO componentIdx=1,MATERIAL_FIELD_NUMBER_OF_COMPONENTS2
                    CALL FIELD_COMPONENT_VALUES_INITIALISE(EQUATIONS_MATERIALS%MATERIALS_FIELD,FIELD_V_VARIABLE_TYPE, &
                      & FIELD_VALUES_SET_TYPE,componentIdx,1.0_DP,ERR,ERROR,*999)
                  END DO
                END IF
              ELSE
                CALL FlagError("Equations set materials is not associated.",ERR,ERROR,*999)
              END IF
            CASE DEFAULT
              LOCAL_ERROR="The action type of "//TRIM(NUMBER_TO_VSTRING(EQUATIONS_SET_SETUP%ACTION_TYPE,"*", & 
                & ERR,ERROR))//" for a setup type of "//TRIM(NUMBER_TO_VSTRING(EQUATIONS_SET_SETUP%SETUP_TYPE,"*", & 
                & ERR,ERROR))//" is invalid for Navier-Stokes equation."
              CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
            END SELECT
          CASE(EQUATIONS_SET_TRANSIENT1D_NAVIER_STOKES_SUBTYPE, &
            & EQUATIONS_SET_TRANSIENT1D_ADV_NAVIER_STOKES_SUBTYPE, &
            & EQUATIONS_SET_COUPLED1D0D_NAVIER_STOKES_SUBTYPE, &
            & EQUATIONS_SET_COUPLED1D0D_ADV_NAVIER_STOKES_SUBTYPE)
            ! 1 variables for the 1D Navier-Stokes materials
            MATERIAL_FIELD_NUMBER_OF_VARIABLES=2
            MATERIAL_FIELD_NUMBER_OF_COMPONENTS1=8
            MATERIAL_FIELD_NUMBER_OF_COMPONENTS2=3
            SELECT CASE(EQUATIONS_SET_SETUP%ACTION_TYPE)
            !Specify start action
            CASE(EQUATIONS_SET_SETUP_START_ACTION)
              EQUATIONS_MATERIALS=>EQUATIONS_SET%MATERIALS
              IF(ASSOCIATED(EQUATIONS_MATERIALS)) THEN
                IF(EQUATIONS_MATERIALS%MATERIALS_FIELD_AUTO_CREATED) THEN
                  !Create the auto created materials field
                  !start field creation with name 'MATERIAL_FIELD'
                  CALL FIELD_CREATE_START(EQUATIONS_SET_SETUP%FIELD_USER_NUMBER,EQUATIONS_SET%REGION, & 
                    & EQUATIONS_SET%MATERIALS%MATERIALS_FIELD,ERR,ERROR,*999)
                  CALL FIELD_TYPE_SET_AND_LOCK(EQUATIONS_MATERIALS%MATERIALS_FIELD,FIELD_MATERIAL_TYPE,ERR,ERROR,*999)
                  !label the field
                  CALL FIELD_LABEL_SET(EQUATIONS_MATERIALS%MATERIALS_FIELD,"Materials Field",ERR,ERROR,*999)
                  CALL FIELD_DEPENDENT_TYPE_SET_AND_LOCK(EQUATIONS_MATERIALS%MATERIALS_FIELD,FIELD_INDEPENDENT_TYPE, &
                    & ERR,ERROR,*999)
                  CALL FIELD_MESH_DECOMPOSITION_GET(EQUATIONS_SET%GEOMETRY%GEOMETRIC_FIELD,GEOMETRIC_DECOMPOSITION, & 
                    & ERR,ERROR,*999)
                  !apply decomposition rule found on new created field
                  CALL FIELD_MESH_DECOMPOSITION_SET_AND_LOCK(EQUATIONS_SET%MATERIALS%MATERIALS_FIELD, & 
                    & GEOMETRIC_DECOMPOSITION,ERR,ERROR,*999)
                  !point new field to geometric field
                  CALL FIELD_GEOMETRIC_FIELD_SET_AND_LOCK(EQUATIONS_MATERIALS%MATERIALS_FIELD,EQUATIONS_SET%GEOMETRY% &
                    & GEOMETRIC_FIELD,ERR,ERROR,*999)
                  CALL FIELD_NUMBER_OF_VARIABLES_SET(EQUATIONS_MATERIALS%MATERIALS_FIELD, & 
                    & MATERIAL_FIELD_NUMBER_OF_VARIABLES,ERR,ERROR,*999)
                  ! 2 U,V materials field
                  CALL FIELD_VARIABLE_TYPES_SET_AND_LOCK(EQUATIONS_MATERIALS%MATERIALS_FIELD, & 
                    &[FIELD_U_VARIABLE_TYPE,FIELD_V_VARIABLE_TYPE,FIELD_U1_VARIABLE_TYPE],ERR,ERROR,*999)
                  CALL FIELD_DIMENSION_SET_AND_LOCK(EQUATIONS_MATERIALS%MATERIALS_FIELD,FIELD_U_VARIABLE_TYPE, &
                    & FIELD_VECTOR_DIMENSION_TYPE,ERR,ERROR,*999)
                  CALL FIELD_DIMENSION_SET_AND_LOCK(EQUATIONS_MATERIALS%MATERIALS_FIELD,FIELD_V_VARIABLE_TYPE, &
                    & FIELD_VECTOR_DIMENSION_TYPE,ERR,ERROR,*999)
                  ! Set up Navier-Stokes materials parameters
                  CALL FIELD_DATA_TYPE_SET_AND_LOCK(EQUATIONS_MATERIALS%MATERIALS_FIELD,FIELD_U_VARIABLE_TYPE, &
                    & FIELD_DP_TYPE,ERR,ERROR,*999)
                  CALL FIELD_DATA_TYPE_SET_AND_LOCK(EQUATIONS_MATERIALS%MATERIALS_FIELD,FIELD_V_VARIABLE_TYPE, &
                    & FIELD_DP_TYPE,ERR,ERROR,*999)
                  CALL FIELD_NUMBER_OF_COMPONENTS_SET_AND_LOCK(EQUATIONS_MATERIALS%MATERIALS_FIELD, & 
                    & FIELD_U_VARIABLE_TYPE,MATERIAL_FIELD_NUMBER_OF_COMPONENTS1,ERR,ERROR,*999)
                  CALL FIELD_NUMBER_OF_COMPONENTS_SET_AND_LOCK(EQUATIONS_MATERIALS%MATERIALS_FIELD, & 
                    & FIELD_V_VARIABLE_TYPE,MATERIAL_FIELD_NUMBER_OF_COMPONENTS2,ERR,ERROR,*999)
                  CALL FIELD_COMPONENT_MESH_COMPONENT_GET(EQUATIONS_SET%GEOMETRY%GEOMETRIC_FIELD, & 
                    & FIELD_U_VARIABLE_TYPE,1,GEOMETRIC_COMPONENT_NUMBER,ERR,ERROR,*999)
                  CALL FIELD_COMPONENT_MESH_COMPONENT_SET(EQUATIONS_MATERIALS%MATERIALS_FIELD,FIELD_U_VARIABLE_TYPE, &
                    & 1,GEOMETRIC_COMPONENT_NUMBER,ERR,ERROR,*999)
                  CALL FIELD_COMPONENT_MESH_COMPONENT_SET(EQUATIONS_MATERIALS%MATERIALS_FIELD,FIELD_V_VARIABLE_TYPE, &
                    & 1,GEOMETRIC_COMPONENT_NUMBER,ERR,ERROR,*999)
                  DO I=1,MATERIAL_FIELD_NUMBER_OF_COMPONENTS1 !(MU,RHO,alpha,pressureExternal,LengthScale,TimeScale,MassScale)
                    CALL FIELD_COMPONENT_INTERPOLATION_SET(EQUATIONS_MATERIALS%MATERIALS_FIELD,FIELD_U_VARIABLE_TYPE, &
                      & I,FIELD_CONSTANT_INTERPOLATION,ERR,ERROR,*999)
                  END DO  
                  DO I=1,MATERIAL_FIELD_NUMBER_OF_COMPONENTS2 !(A0,E,H0)
                    CALL FIELD_COMPONENT_INTERPOLATION_SET(EQUATIONS_MATERIALS%MATERIALS_FIELD,FIELD_V_VARIABLE_TYPE, &
                      & I,FIELD_NODE_BASED_INTERPOLATION,ERR,ERROR,*999)
                  END DO
                  ! Set up coupling materials parameters
                  CALL FIELD_COMPONENT_MESH_COMPONENT_GET(EQUATIONS_SET%GEOMETRY%GEOMETRIC_FIELD, & 
                    & FIELD_U_VARIABLE_TYPE,1,GEOMETRIC_COMPONENT_NUMBER,ERR,ERROR,*999)
                  !Default the field scaling to that of the geometric field
                  CALL FIELD_SCALING_TYPE_GET(EQUATIONS_SET%GEOMETRY%GEOMETRIC_FIELD,GEOMETRIC_SCALING_TYPE, & 
                    & ERR,ERROR,*999)
                  CALL FIELD_SCALING_TYPE_SET(EQUATIONS_MATERIALS%MATERIALS_FIELD,GEOMETRIC_SCALING_TYPE,ERR,ERROR,*999)
                ELSE
                  !Check the user specified field
                  CALL FIELD_TYPE_CHECK(EQUATIONS_SET_SETUP%FIELD,FIELD_MATERIAL_TYPE,ERR,ERROR,*999)
                  CALL FIELD_DEPENDENT_TYPE_CHECK(EQUATIONS_SET_SETUP%FIELD,FIELD_INDEPENDENT_TYPE,ERR,ERROR,*999)
                  CALL FIELD_NUMBER_OF_VARIABLES_CHECK(EQUATIONS_SET_SETUP%FIELD,MATERIAL_FIELD_NUMBER_OF_VARIABLES,ERR,ERROR,*999)
                  CALL FIELD_VARIABLE_TYPES_CHECK(EQUATIONS_SET_SETUP%FIELD,[FIELD_U_VARIABLE_TYPE,FIELD_V_VARIABLE_TYPE], &
                    & ERR,ERROR,*999)
                  ! Check N-S field variable
                  CALL FIELD_DIMENSION_CHECK(EQUATIONS_SET_SETUP%FIELD,FIELD_U_VARIABLE_TYPE, & 
                    & FIELD_VECTOR_DIMENSION_TYPE,ERR,ERROR,*999)
                  CALL FIELD_DIMENSION_CHECK(EQUATIONS_SET_SETUP%FIELD,FIELD_V_VARIABLE_TYPE, & 
                    & FIELD_VECTOR_DIMENSION_TYPE,ERR,ERROR,*999)
                  CALL FIELD_DATA_TYPE_CHECK(EQUATIONS_SET_SETUP%FIELD,FIELD_U_VARIABLE_TYPE,FIELD_DP_TYPE, & 
                    & ERR,ERROR,*999)
                  CALL FIELD_DATA_TYPE_CHECK(EQUATIONS_SET_SETUP%FIELD,FIELD_V_VARIABLE_TYPE,FIELD_DP_TYPE, & 
                    & ERR,ERROR,*999)
                  CALL FIELD_NUMBER_OF_COMPONENTS_CHECK(EQUATIONS_SET_SETUP%FIELD,FIELD_U_VARIABLE_TYPE, &
                    & MATERIAL_FIELD_NUMBER_OF_COMPONENTS1,ERR,ERROR,*999)
                  CALL FIELD_NUMBER_OF_COMPONENTS_CHECK(EQUATIONS_SET_SETUP%FIELD,FIELD_V_VARIABLE_TYPE, &
                    & MATERIAL_FIELD_NUMBER_OF_COMPONENTS2,ERR,ERROR,*999)
                END IF
              ELSE
                CALL FlagError("Equations set materials is not associated.",ERR,ERROR,*999)
              END IF
              !Specify start action
            CASE(EQUATIONS_SET_SETUP_FINISH_ACTION)
              EQUATIONS_MATERIALS=>EQUATIONS_SET%MATERIALS
              IF(ASSOCIATED(EQUATIONS_MATERIALS)) THEN
                IF(EQUATIONS_MATERIALS%MATERIALS_FIELD_AUTO_CREATED) THEN
                  !Finish creating the materials field
                  CALL FIELD_CREATE_FINISH(EQUATIONS_MATERIALS%MATERIALS_FIELD,ERR,ERROR,*999)
                END IF
              ELSE
                CALL FlagError("Equations set materials is not associated.",ERR,ERROR,*999)
              END IF
            CASE DEFAULT
              LOCAL_ERROR="The action type of "//TRIM(NUMBER_TO_VSTRING(EQUATIONS_SET_SETUP%ACTION_TYPE,"*", & 
                & ERR,ERROR))//" for a setup type of "//TRIM(NUMBER_TO_VSTRING(EQUATIONS_SET_SETUP%SETUP_TYPE,"*", & 
                & ERR,ERROR))//" is invalid for Navier-Stokes equation."
              CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
            END SELECT
          CASE DEFAULT
            LOCAL_ERROR="The equation set subtype of "//TRIM(NUMBER_TO_VSTRING(EQUATIONS_SET%SPECIFICATION(3),"*",ERR,ERROR))// &
              & " for a setup type of "//TRIM(NUMBER_TO_VSTRING(EQUATIONS_SET_SETUP%SETUP_TYPE,"*",ERR,ERROR))// &
              & " is invalid for a Navier-Stokes equation."
            CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
          END SELECT
        !-----------------------------------------------------------------
        ! S o u r c e   f i e l d
        !-----------------------------------------------------------------
        CASE(EQUATIONS_SET_SETUP_SOURCE_TYPE)
          SELECT CASE(EQUATIONS_SET%SPECIFICATION(3))
          CASE(EQUATIONS_SET_STATIC_NAVIER_STOKES_SUBTYPE,EQUATIONS_SET_LAPLACE_NAVIER_STOKES_SUBTYPE, &
            & EQUATIONS_SET_STATIC_RBS_NAVIER_STOKES_SUBTYPE, &
            & EQUATIONS_SET_TRANSIENT_NAVIER_STOKES_SUBTYPE,EQUATIONS_SET_ALE_NAVIER_STOKES_SUBTYPE, & 
            & EQUATIONS_SET_PGM_NAVIER_STOKES_SUBTYPE,EQUATIONS_SET_QUASISTATIC_NAVIER_STOKES_SUBTYPE, &
            & EQUATIONS_SET_TRANSIENT1D_NAVIER_STOKES_SUBTYPE,EQUATIONS_SET_COUPLED1D0D_NAVIER_STOKES_SUBTYPE, &
            & EQUATIONS_SET_TRANSIENT1D_ADV_NAVIER_STOKES_SUBTYPE,EQUATIONS_SET_TRANSIENT_RBS_NAVIER_STOKES_SUBTYPE, &
            & EQUATIONS_SET_COUPLED1D0D_ADV_NAVIER_STOKES_SUBTYPE)
            !\todo: Think about gravity
            SELECT CASE(EQUATIONS_SET_SETUP%ACTION_TYPE)
            CASE(EQUATIONS_SET_SETUP_START_ACTION)
              !Do nothing
            CASE(EQUATIONS_SET_SETUP_FINISH_ACTION)
              !Do nothing
              !? Maybe set finished flag????
            CASE DEFAULT
              LOCAL_ERROR="The action type of "//TRIM(NUMBER_TO_VSTRING(EQUATIONS_SET_SETUP%ACTION_TYPE,"*", &
                & ERR,ERROR))//" for a setup type of "//TRIM(NUMBER_TO_VSTRING(EQUATIONS_SET_SETUP%SETUP_TYPE,"*", & 
                & ERR,ERROR))//" is invalid for a Navier-Stokes fluid."
              CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
            END SELECT
          CASE DEFAULT
            LOCAL_ERROR="The equation set subtype of "//TRIM(NUMBER_TO_VSTRING(EQUATIONS_SET%SPECIFICATION(3),"*",ERR,ERROR))// &
              &  " for a setup type of "//TRIM(NUMBER_TO_VSTRING(EQUATIONS_SET_SETUP%SETUP_TYPE,"*",ERR,ERROR))// &
              &  " is invalid for a Navier-Stokes equation."
            CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
          END SELECT
        !-----------------------------------------------------------------
        ! E q u a t i o n s    t y p e
        !-----------------------------------------------------------------
        CASE(EQUATIONS_SET_SETUP_EQUATIONS_TYPE)
          SELECT CASE(EQUATIONS_SET%SPECIFICATION(3))
          CASE(EQUATIONS_SET_STATIC_NAVIER_STOKES_SUBTYPE, &
            &  EQUATIONS_SET_STATIC_RBS_NAVIER_STOKES_SUBTYPE, &
            &  EQUATIONS_SET_LAPLACE_NAVIER_STOKES_SUBTYPE)
            SELECT CASE(EQUATIONS_SET_SETUP%ACTION_TYPE)
            CASE(EQUATIONS_SET_SETUP_START_ACTION)
              EQUATIONS_MATERIALS=>EQUATIONS_SET%MATERIALS
              IF(ASSOCIATED(EQUATIONS_MATERIALS)) THEN              
                IF(EQUATIONS_MATERIALS%MATERIALS_FINISHED) THEN
                  CALL EQUATIONS_CREATE_START(EQUATIONS_SET,EQUATIONS,ERR,ERROR,*999)
                  CALL EQUATIONS_LINEARITY_TYPE_SET(EQUATIONS,EQUATIONS_NONLINEAR,ERR,ERROR,*999)
                  CALL EQUATIONS_TIME_DEPENDENCE_TYPE_SET(EQUATIONS,EQUATIONS_STATIC,ERR,ERROR,*999)
                ELSE
                  CALL FlagError("Equations set materials has not been finished.",ERR,ERROR,*999)
                END IF
              ELSE
                CALL FlagError("Equations materials is not associated.",ERR,ERROR,*999)
              END IF
            CASE(EQUATIONS_SET_SETUP_FINISH_ACTION)
              SELECT CASE(EQUATIONS_SET%SOLUTION_METHOD)
              CASE(EQUATIONS_SET_FEM_SOLUTION_METHOD)
              !Finish the creation of the equations
                CALL EQUATIONS_SET_EQUATIONS_GET(EQUATIONS_SET,EQUATIONS,ERR,ERROR,*999)
                CALL EQUATIONS_CREATE_FINISH(EQUATIONS,ERR,ERROR,*999)
                !Create the equations mapping.
                CALL EQUATIONS_MAPPING_CREATE_START(EQUATIONS,EQUATIONS_MAPPING,ERR,ERROR,*999)
                CALL EquationsMapping_LinearMatricesNumberSet(EQUATIONS_MAPPING,1,ERR,ERROR,*999)
                CALL EquationsMapping_LinearMatricesVariableTypesSet(EQUATIONS_MAPPING,[FIELD_U_VARIABLE_TYPE], &
                  & ERR,ERROR,*999)
                CALL EQUATIONS_MAPPING_RHS_VARIABLE_TYPE_SET(EQUATIONS_MAPPING,FIELD_DELUDELN_VARIABLE_TYPE, & 
                  & ERR,ERROR,*999)
                CALL EQUATIONS_MAPPING_CREATE_FINISH(EQUATIONS_MAPPING,ERR,ERROR,*999)
                !Create the equations matrices
                CALL EQUATIONS_MATRICES_CREATE_START(EQUATIONS,EQUATIONS_MATRICES,ERR,ERROR,*999)
                ! Use the analytic Jacobian calculation
                CALL EquationsMatrices_JacobianTypesSet(EQUATIONS_MATRICES,[EQUATIONS_JACOBIAN_ANALYTIC_CALCULATED], &
                  & ERR,ERROR,*999)
                SELECT CASE(EQUATIONS%SPARSITY_TYPE)
                CASE(EQUATIONS_MATRICES_FULL_MATRICES)
                  CALL EQUATIONS_MATRICES_LINEAR_STORAGE_TYPE_SET(EQUATIONS_MATRICES,[MATRIX_BLOCK_STORAGE_TYPE], &
                    & ERR,ERROR,*999)
                  CALL EquationsMatrices_NonlinearStorageTypeSet(EQUATIONS_MATRICES,MATRIX_BLOCK_STORAGE_TYPE, &
                    & ERR,ERROR,*999)
                CASE(EQUATIONS_MATRICES_SPARSE_MATRICES)
                  CALL EQUATIONS_MATRICES_LINEAR_STORAGE_TYPE_SET(EQUATIONS_MATRICES, & 
                    & [MATRIX_COMPRESSED_ROW_STORAGE_TYPE],ERR,ERROR,*999)
                  CALL EquationsMatrices_NonlinearStorageTypeSet(EQUATIONS_MATRICES, & 
                    & MATRIX_COMPRESSED_ROW_STORAGE_TYPE,ERR,ERROR,*999)
                  CALL EquationsMatrices_LinearStructureTypeSet(EQUATIONS_MATRICES, & 
                    & [EQUATIONS_MATRIX_FEM_STRUCTURE],ERR,ERROR,*999)
                  CALL EquationsMatrices_NonlinearStructureTypeSet(EQUATIONS_MATRICES, & 
                    & EQUATIONS_MATRIX_FEM_STRUCTURE,ERR,ERROR,*999)
                CASE DEFAULT
                  LOCAL_ERROR="The equations matrices sparsity type of "// &
                    & TRIM(NUMBER_TO_VSTRING(EQUATIONS%SPARSITY_TYPE,"*",ERR,ERROR))//" is invalid."
                  CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
                END SELECT
                CALL EQUATIONS_MATRICES_CREATE_FINISH(EQUATIONS_MATRICES,ERR,ERROR,*999)
              CASE(EQUATIONS_SET_NODAL_SOLUTION_METHOD)
                !Finish the creation of the equations
                CALL EQUATIONS_SET_EQUATIONS_GET(EQUATIONS_SET,EQUATIONS,ERR,ERROR,*999)
                CALL EQUATIONS_CREATE_FINISH(EQUATIONS,ERR,ERROR,*999)
                !Create the equations mapping.
                CALL EQUATIONS_MAPPING_CREATE_START(EQUATIONS,EQUATIONS_MAPPING,ERR,ERROR,*999)
                CALL EquationsMapping_LinearMatricesNumberSet(EQUATIONS_MAPPING,1,ERR,ERROR,*999)
                CALL EquationsMapping_LinearMatricesVariableTypesSet(EQUATIONS_MAPPING,[FIELD_U_VARIABLE_TYPE], &
                  & ERR,ERROR,*999)
                CALL EQUATIONS_MAPPING_RHS_VARIABLE_TYPE_SET(EQUATIONS_MAPPING,FIELD_DELUDELN_VARIABLE_TYPE, & 
                  & ERR,ERROR,*999)
                CALL EQUATIONS_MAPPING_CREATE_FINISH(EQUATIONS_MAPPING,ERR,ERROR,*999)
                !Create the equations matrices
                CALL EQUATIONS_MATRICES_CREATE_START(EQUATIONS,EQUATIONS_MATRICES,ERR,ERROR,*999)
                ! Use the analytic Jacobian calculation
                CALL EquationsMatrices_JacobianTypesSet(EQUATIONS_MATRICES,[EQUATIONS_JACOBIAN_ANALYTIC_CALCULATED], &
                  & ERR,ERROR,*999)
                SELECT CASE(EQUATIONS%SPARSITY_TYPE)
                CASE(EQUATIONS_MATRICES_FULL_MATRICES)
                  CALL EQUATIONS_MATRICES_LINEAR_STORAGE_TYPE_SET(EQUATIONS_MATRICES,[MATRIX_BLOCK_STORAGE_TYPE], &
                    & ERR,ERROR,*999)
                  CALL EquationsMatrices_NonlinearStorageTypeSet(EQUATIONS_MATRICES,MATRIX_BLOCK_STORAGE_TYPE, &
                    & ERR,ERROR,*999)
                CASE(EQUATIONS_MATRICES_SPARSE_MATRICES)
                  CALL EQUATIONS_MATRICES_LINEAR_STORAGE_TYPE_SET(EQUATIONS_MATRICES, & 
                    & [MATRIX_COMPRESSED_ROW_STORAGE_TYPE],ERR,ERROR,*999)
                  CALL EquationsMatrices_NonlinearStorageTypeSet(EQUATIONS_MATRICES, & 
                    & MATRIX_COMPRESSED_ROW_STORAGE_TYPE,ERR,ERROR,*999)
                  CALL EquationsMatrices_LinearStructureTypeSet(EQUATIONS_MATRICES, & 
                    & [EQUATIONS_MATRIX_FEM_STRUCTURE],ERR,ERROR,*999)
                  CALL EquationsMatrices_NonlinearStructureTypeSet(EQUATIONS_MATRICES, & 
                    & EQUATIONS_MATRIX_FEM_STRUCTURE,ERR,ERROR,*999)
                CASE DEFAULT
                  LOCAL_ERROR="The equations matrices sparsity type of "// &
                    & TRIM(NUMBER_TO_VSTRING(EQUATIONS%SPARSITY_TYPE,"*",ERR,ERROR))//" is invalid."
                  CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
                END SELECT
                CALL EQUATIONS_MATRICES_CREATE_FINISH(EQUATIONS_MATRICES,ERR,ERROR,*999)
              CASE(EQUATIONS_SET_BEM_SOLUTION_METHOD)
                CALL FlagError("Not implemented.",ERR,ERROR,*999)
              CASE(EQUATIONS_SET_FD_SOLUTION_METHOD)
                CALL FlagError("Not implemented.",ERR,ERROR,*999)
              CASE(EQUATIONS_SET_FV_SOLUTION_METHOD)
                CALL FlagError("Not implemented.",ERR,ERROR,*999)
              CASE(EQUATIONS_SET_GFEM_SOLUTION_METHOD)
                CALL FlagError("Not implemented.",ERR,ERROR,*999)
              CASE(EQUATIONS_SET_GFV_SOLUTION_METHOD)
                CALL FlagError("Not implemented.",ERR,ERROR,*999)
              CASE DEFAULT
                LOCAL_ERROR="The solution method of "//TRIM(NUMBER_TO_VSTRING(EQUATIONS_SET%SOLUTION_METHOD, &
                  & "*",ERR,ERROR))//" is invalid."
                CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
              END SELECT
            CASE DEFAULT
              LOCAL_ERROR="The action type of "//TRIM(NUMBER_TO_VSTRING(EQUATIONS_SET_SETUP%ACTION_TYPE,"*",ERR,ERROR))// &
                & " for a setup type of "//TRIM(NUMBER_TO_VSTRING(EQUATIONS_SET_SETUP%SETUP_TYPE,"*",ERR,ERROR))// &
                & " is invalid for a Navier-stokes equation."
              CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
            END SELECT
          CASE(EQUATIONS_SET_TRANSIENT_NAVIER_STOKES_SUBTYPE, &
             & EQUATIONS_SET_ALE_NAVIER_STOKES_SUBTYPE, & 
             & EQUATIONS_SET_PGM_NAVIER_STOKES_SUBTYPE, &
             & EQUATIONS_SET_TRANSIENT_RBS_NAVIER_STOKES_SUBTYPE, &
             & EQUATIONS_SET_MULTISCALE3D_NAVIER_STOKES_SUBTYPE, &
             & EQUATIONS_SET_CONSTITUTIVE_MU_NAVIER_STOKES_SUBTYPE, &
             & EQUATIONS_SET_TRANSIENT1D_NAVIER_STOKES_SUBTYPE, &
             & EQUATIONS_SET_COUPLED1D0D_NAVIER_STOKES_SUBTYPE, &
             & EQUATIONS_SET_TRANSIENT1D_ADV_NAVIER_STOKES_SUBTYPE, &
             & EQUATIONS_SET_COUPLED1D0D_ADV_NAVIER_STOKES_SUBTYPE)

            SELECT CASE(EQUATIONS_SET_SETUP%ACTION_TYPE)
            CASE(EQUATIONS_SET_SETUP_START_ACTION)
              EQUATIONS_MATERIALS=>EQUATIONS_SET%MATERIALS
              IF(ASSOCIATED(EQUATIONS_MATERIALS)) THEN              
                IF(EQUATIONS_MATERIALS%MATERIALS_FINISHED) THEN
                  CALL EQUATIONS_CREATE_START(EQUATIONS_SET,EQUATIONS,ERR,ERROR,*999)
                  CALL EQUATIONS_LINEARITY_TYPE_SET(EQUATIONS,EQUATIONS_NONLINEAR,ERR,ERROR,*999)
                  CALL EQUATIONS_TIME_DEPENDENCE_TYPE_SET(EQUATIONS,EQUATIONS_FIRST_ORDER_DYNAMIC,ERR,ERROR,*999)
                ELSE
                  CALL FlagError("Equations set materials has not been finished.",ERR,ERROR,*999)
                END IF
              ELSE
                CALL FlagError("Equations materials is not associated.",ERR,ERROR,*999)
              END IF
            CASE(EQUATIONS_SET_SETUP_FINISH_ACTION)
              SELECT CASE(EQUATIONS_SET%SOLUTION_METHOD)
              CASE(EQUATIONS_SET_FEM_SOLUTION_METHOD)
                !Finish the creation of the equations
                CALL EQUATIONS_SET_EQUATIONS_GET(EQUATIONS_SET,EQUATIONS,ERR,ERROR,*999)
                CALL EQUATIONS_CREATE_FINISH(EQUATIONS,ERR,ERROR,*999)
                !Create the equations mapping.
                CALL EQUATIONS_MAPPING_CREATE_START(EQUATIONS,EQUATIONS_MAPPING,ERR,ERROR,*999)
                CALL EquationsMapping_ResidualVariableTypesSet(EQUATIONS_MAPPING,[FIELD_U_VARIABLE_TYPE], &
                  & ERR,ERROR,*999)
                CALL EQUATIONS_MAPPING_DYNAMIC_MATRICES_SET(EQUATIONS_MAPPING,.TRUE.,.TRUE.,ERR,ERROR,*999)
                CALL EQUATIONS_MAPPING_DYNAMIC_VARIABLE_TYPE_SET(EQUATIONS_MAPPING,FIELD_U_VARIABLE_TYPE,ERR,ERROR,*999)
                CALL EQUATIONS_MAPPING_RHS_VARIABLE_TYPE_SET(EQUATIONS_MAPPING,FIELD_DELUDELN_VARIABLE_TYPE,ERR, & 
                  & ERROR,*999)
                CALL EQUATIONS_MAPPING_CREATE_FINISH(EQUATIONS_MAPPING,ERR,ERROR,*999)
                !Create the equations matrices
                CALL EQUATIONS_MATRICES_CREATE_START(EQUATIONS,EQUATIONS_MATRICES,ERR,ERROR,*999)
                ! Use the analytic Jacobian calculation
                CALL EquationsMatrices_JacobianTypesSet(EQUATIONS_MATRICES,[EQUATIONS_JACOBIAN_ANALYTIC_CALCULATED], &
                  & ERR,ERROR,*999)
                SELECT CASE(EQUATIONS%SPARSITY_TYPE)
                CASE(EQUATIONS_MATRICES_FULL_MATRICES)
                  CALL EQUATIONS_MATRICES_DYNAMIC_STORAGE_TYPE_SET(EQUATIONS_MATRICES,[MATRIX_BLOCK_STORAGE_TYPE, &
                    & MATRIX_BLOCK_STORAGE_TYPE],ERR,ERROR,*999)
                  CALL EquationsMatrices_NonlinearStorageTypeSet(EQUATIONS_MATRICES,MATRIX_BLOCK_STORAGE_TYPE, &
                    & ERR,ERROR,*999)
                CASE(EQUATIONS_MATRICES_SPARSE_MATRICES)
                  CALL EQUATIONS_MATRICES_DYNAMIC_STORAGE_TYPE_SET(EQUATIONS_MATRICES, &
                    & [DISTRIBUTED_MATRIX_COMPRESSED_ROW_STORAGE_TYPE, & 
                    & DISTRIBUTED_MATRIX_COMPRESSED_ROW_STORAGE_TYPE],ERR,ERROR,*999)
                  CALL EquationsMatrices_DynamicStructureTypeSet(EQUATIONS_MATRICES, &
                    & [EQUATIONS_MATRIX_FEM_STRUCTURE,EQUATIONS_MATRIX_FEM_STRUCTURE],ERR,ERROR,*999)
                  CALL EquationsMatrices_NonlinearStorageTypeSet(EQUATIONS_MATRICES, & 
                    & MATRIX_COMPRESSED_ROW_STORAGE_TYPE,ERR,ERROR,*999)
                  CALL EquationsMatrices_NonlinearStructureTypeSet(EQUATIONS_MATRICES, & 
                    & EQUATIONS_MATRIX_FEM_STRUCTURE,ERR,ERROR,*999)
                CASE DEFAULT
                  LOCAL_ERROR="The equations matrices sparsity type of "// &
                    & TRIM(NUMBER_TO_VSTRING(EQUATIONS%SPARSITY_TYPE,"*",ERR,ERROR))//" is invalid."
                  CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
                END SELECT
                CALL EQUATIONS_MATRICES_CREATE_FINISH(EQUATIONS_MATRICES,ERR,ERROR,*999)
              CASE(EQUATIONS_SET_BEM_SOLUTION_METHOD)
                CALL FlagError("Not implemented.",ERR,ERROR,*999)
              CASE(EQUATIONS_SET_FD_SOLUTION_METHOD)
               CALL FlagError("Not implemented.",ERR,ERROR,*999)
              CASE(EQUATIONS_SET_FV_SOLUTION_METHOD)
                CALL FlagError("Not implemented.",ERR,ERROR,*999)
              CASE(EQUATIONS_SET_GFEM_SOLUTION_METHOD)
                CALL FlagError("Not implemented.",ERR,ERROR,*999)
              CASE(EQUATIONS_SET_GFV_SOLUTION_METHOD)
                CALL FlagError("Not implemented.",ERR,ERROR,*999)
              CASE DEFAULT
                LOCAL_ERROR="The solution method of "//TRIM(NUMBER_TO_VSTRING(EQUATIONS_SET%SOLUTION_METHOD, &
                  & "*",ERR,ERROR))//" is invalid."
                CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
              END SELECT
            CASE DEFAULT
              LOCAL_ERROR="The action type of "//TRIM(NUMBER_TO_VSTRING(EQUATIONS_SET_SETUP%ACTION_TYPE,"*",ERR,ERROR))// &
                & " for a setup type of "//TRIM(NUMBER_TO_VSTRING(EQUATIONS_SET_SETUP%SETUP_TYPE,"*",ERR,ERROR))// &
                & " is invalid for a Navier-Stokes equation."
              CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
            END SELECT
          CASE(EQUATIONS_SET_QUASISTATIC_NAVIER_STOKES_SUBTYPE)
            SELECT CASE(EQUATIONS_SET_SETUP%ACTION_TYPE)
            CASE(EQUATIONS_SET_SETUP_START_ACTION)
              EQUATIONS_MATERIALS=>EQUATIONS_SET%MATERIALS
              IF(ASSOCIATED(EQUATIONS_MATERIALS)) THEN              
                IF(EQUATIONS_MATERIALS%MATERIALS_FINISHED) THEN
                  CALL EQUATIONS_CREATE_START(EQUATIONS_SET,EQUATIONS,ERR,ERROR,*999)
                  CALL EQUATIONS_LINEARITY_TYPE_SET(EQUATIONS,EQUATIONS_NONLINEAR,ERR,ERROR,*999)
                  CALL EQUATIONS_TIME_DEPENDENCE_TYPE_SET(EQUATIONS,EQUATIONS_QUASISTATIC,ERR,ERROR,*999)
                ELSE
                  CALL FlagError("Equations set materials has not been finished.",ERR,ERROR,*999)
                END IF
              ELSE
                CALL FlagError("Equations materials is not associated.",ERR,ERROR,*999)
              END IF
            CASE(EQUATIONS_SET_SETUP_FINISH_ACTION)
              SELECT CASE(EQUATIONS_SET%SOLUTION_METHOD)
              CASE(EQUATIONS_SET_FEM_SOLUTION_METHOD)
                !Finish the creation of the equations
                CALL EQUATIONS_SET_EQUATIONS_GET(EQUATIONS_SET,EQUATIONS,ERR,ERROR,*999)
                CALL EQUATIONS_CREATE_FINISH(EQUATIONS,ERR,ERROR,*999)
                !Create the equations mapping.
                CALL EQUATIONS_MAPPING_CREATE_START(EQUATIONS,EQUATIONS_MAPPING,ERR,ERROR,*999)
                CALL EquationsMapping_LinearMatricesNumberSet(EQUATIONS_MAPPING,1,ERR,ERROR,*999)
                CALL EquationsMapping_LinearMatricesVariableTypesSet(EQUATIONS_MAPPING,[FIELD_U_VARIABLE_TYPE], &
                  & ERR,ERROR,*999)
                CALL EQUATIONS_MAPPING_RHS_VARIABLE_TYPE_SET(EQUATIONS_MAPPING,FIELD_DELUDELN_VARIABLE_TYPE, & 
                  & ERR,ERROR,*999)
                CALL EQUATIONS_MAPPING_CREATE_FINISH(EQUATIONS_MAPPING,ERR,ERROR,*999)
                !Create the equations matrices
                CALL EQUATIONS_MATRICES_CREATE_START(EQUATIONS,EQUATIONS_MATRICES,ERR,ERROR,*999)
                ! Use the analytic Jacobian calculation
                CALL EquationsMatrices_JacobianTypesSet(EQUATIONS_MATRICES,[EQUATIONS_JACOBIAN_ANALYTIC_CALCULATED], &
                  & ERR,ERROR,*999)
                SELECT CASE(EQUATIONS%SPARSITY_TYPE)
                CASE(EQUATIONS_MATRICES_FULL_MATRICES)
                  CALL EQUATIONS_MATRICES_LINEAR_STORAGE_TYPE_SET(EQUATIONS_MATRICES,[MATRIX_BLOCK_STORAGE_TYPE], &
                    & ERR,ERROR,*999)
                  CALL EquationsMatrices_NonlinearStorageTypeSet(EQUATIONS_MATRICES,MATRIX_BLOCK_STORAGE_TYPE, &
                    & ERR,ERROR,*999)
                CASE(EQUATIONS_MATRICES_SPARSE_MATRICES)
                  CALL EQUATIONS_MATRICES_LINEAR_STORAGE_TYPE_SET(EQUATIONS_MATRICES, & 
                    & [MATRIX_COMPRESSED_ROW_STORAGE_TYPE],ERR,ERROR,*999)
                  CALL EquationsMatrices_NonlinearStorageTypeSet(EQUATIONS_MATRICES, & 
                    & MATRIX_COMPRESSED_ROW_STORAGE_TYPE,ERR,ERROR,*999)
                  CALL EquationsMatrices_LinearStructureTypeSet(EQUATIONS_MATRICES, & 
                    & [EQUATIONS_MATRIX_FEM_STRUCTURE],ERR,ERROR,*999)
                  CALL EquationsMatrices_NonlinearStructureTypeSet(EQUATIONS_MATRICES, & 
                    & EQUATIONS_MATRIX_FEM_STRUCTURE,ERR,ERROR,*999)
                CASE DEFAULT
                  LOCAL_ERROR="The equations matrices sparsity type of "// &
                    & TRIM(NUMBER_TO_VSTRING(EQUATIONS%SPARSITY_TYPE,"*",ERR,ERROR))//" is invalid."
                  CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
                END SELECT
                CALL EQUATIONS_MATRICES_CREATE_FINISH(EQUATIONS_MATRICES,ERR,ERROR,*999)
              CASE(EQUATIONS_SET_BEM_SOLUTION_METHOD)
                CALL FlagError("Not implemented.",ERR,ERROR,*999)
              CASE(EQUATIONS_SET_FD_SOLUTION_METHOD)
                CALL FlagError("Not implemented.",ERR,ERROR,*999)
              CASE(EQUATIONS_SET_FV_SOLUTION_METHOD)
                CALL FlagError("Not implemented.",ERR,ERROR,*999)
              CASE(EQUATIONS_SET_GFEM_SOLUTION_METHOD)
                CALL FlagError("Not implemented.",ERR,ERROR,*999)
              CASE(EQUATIONS_SET_GFV_SOLUTION_METHOD)
                CALL FlagError("Not implemented.",ERR,ERROR,*999)
              CASE DEFAULT
                LOCAL_ERROR="The solution method of "//TRIM(NUMBER_TO_VSTRING(EQUATIONS_SET%SOLUTION_METHOD, &
                  & "*",ERR,ERROR))//" is invalid."
                CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
              END SELECT
            CASE DEFAULT
              LOCAL_ERROR="The action type of "//TRIM(NUMBER_TO_VSTRING(EQUATIONS_SET_SETUP%ACTION_TYPE,"*",ERR,ERROR))// &
                & " for a setup type of "//TRIM(NUMBER_TO_VSTRING(EQUATIONS_SET_SETUP%SETUP_TYPE,"*",ERR,ERROR))// &
                & " is invalid for a Navier-Stokes equation."
              CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
            END SELECT
          CASE DEFAULT
            LOCAL_ERROR="The equation set subtype of "//TRIM(NUMBER_TO_VSTRING(EQUATIONS_SET%SPECIFICATION(3),"*",ERR,ERROR))// &
              & " for a setup type of "//TRIM(NUMBER_TO_VSTRING(EQUATIONS_SET_SETUP%SETUP_TYPE,"*",ERR,ERROR))// &
              & " is invalid for a Navier-Stokes equation."
            CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
          END SELECT
        CASE DEFAULT
          LOCAL_ERROR="The setup type of "//TRIM(NUMBER_TO_VSTRING(EQUATIONS_SET_SETUP%SETUP_TYPE,"*",ERR,ERROR))// &
            & " is invalid for a Navier-Stokes fluid."
          CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
        END SELECT
      CASE DEFAULT
        LOCAL_ERROR="The equations set subtype of "//TRIM(NUMBER_TO_VSTRING(EQUATIONS_SET%SPECIFICATION(3),"*",ERR,ERROR))// &
          & " does not equal a Navier-Stokes fluid subtype."
        CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
      END SELECT
    ELSE
      CALL FlagError("Equations set is not associated.",ERR,ERROR,*999)
    END IF

    EXITS("NAVIER_STOKES_EQUATIONS_SET_SETUP")
    RETURN
999 ERRORSEXITS("NAVIER_STOKES_EQUATIONS_SET_SETUP",ERR,ERROR)
    RETURN 1
    
  END SUBROUTINE NAVIER_STOKES_EQUATIONS_SET_SETUP

  !
  !================================================================================================================================
  !

  !>Sets up the Navier-Stokes problem pre solve.
  SUBROUTINE NAVIER_STOKES_PRE_SOLVE(SOLVER,ERR,ERROR,*)

    !Argument variables
    TYPE(SOLVER_TYPE), POINTER :: SOLVER
    INTEGER(INTG), INTENT(OUT) :: ERR
    TYPE(VARYING_STRING), INTENT(OUT) :: ERROR
    !Local Variables
    TYPE(CONTROL_LOOP_TYPE), POINTER :: CONTROL_LOOP
    TYPE(EQUATIONS_SET_TYPE), POINTER :: EQUATIONS_SET
    TYPE(EQUATIONS_SET_ANALYTIC_TYPE), POINTER :: EQUATIONS_ANALYTIC
    TYPE(NONLINEAR_SOLVER_TYPE), POINTER :: nonlinearSolver
    TYPE(FIELD_TYPE), POINTER :: dependentField
    TYPE(FIELD_VARIABLE_TYPE), POINTER :: fieldVariable
    TYPE(SOLVER_EQUATIONS_TYPE), POINTER :: SOLVER_EQUATIONS
    TYPE(SOLVER_MAPPING_TYPE), POINTER :: SOLVER_MAPPING
    TYPE(SOLVER_MATRICES_TYPE), POINTER :: SOLVER_MATRICES
    TYPE(SOLVER_MATRIX_TYPE), POINTER :: SOLVER_MATRIX
    TYPE(SOLVER_TYPE), POINTER :: SOLVER2,cellmlSolver
    TYPE(SOLVERS_TYPE), POINTER :: SOLVERS
    TYPE(VARYING_STRING) :: LOCAL_ERROR
    INTEGER(INTG) :: solver_matrix_idx,iteration
    REAL(DP) :: timeIncrement,currentTime

    NULLIFY(SOLVER2)
    
    ENTERS("NAVIER_STOKES_PRE_SOLVE",ERR,ERROR,*999)

    IF(ASSOCIATED(SOLVER)) THEN
      SOLVERS=>SOLVER%SOLVERS
      IF(ASSOCIATED(SOLVERS)) THEN
        CONTROL_LOOP=>SOLVERS%CONTROL_LOOP
        IF(ASSOCIATED(CONTROL_LOOP%PROBLEM)) THEN
          IF(.NOT.ALLOCATED(CONTROL_LOOP%problem%specification)) THEN
            CALL FlagError("Problem specification is not allocated.",err,error,*999)
          ELSE IF(SIZE(CONTROL_LOOP%problem%specification,1)<3) THEN
            CALL FlagError("Problem specification must have three entries for a Navier-Stokes problem.",err,error,*999)
          END IF
          !Since we can have a fluid mechanics navier stokes equations set in a coupled problem setup we do not necessarily
          !have PROBLEM%SPECIFICATION(1)==FLUID_MECHANICS_CLASS
          SELECT CASE(CONTROL_LOOP%PROBLEM%SPECIFICATION(1))
          CASE(PROBLEM_FLUID_MECHANICS_CLASS)
            SELECT CASE(CONTROL_LOOP%PROBLEM%SPECIFICATION(3))
            CASE(PROBLEM_STATIC_NAVIER_STOKES_SUBTYPE,PROBLEM_LAPLACE_NAVIER_STOKES_SUBTYPE)
              SOLVER_EQUATIONS=>SOLVER%SOLVER_EQUATIONS
              IF(ASSOCIATED(SOLVER_EQUATIONS)) THEN
                SOLVER_MAPPING=>SOLVER_EQUATIONS%SOLVER_MAPPING
                IF(ASSOCIATED(SOLVER_MAPPING)) THEN
                  ! TODO: Set up for multiple equations sets
                  EQUATIONS_SET=>SOLVER_MAPPING%EQUATIONS_SETS(1)%PTR
                  IF(ASSOCIATED(EQUATIONS_SET)) THEN
                    EQUATIONS_ANALYTIC=>EQUATIONS_SET%ANALYTIC
                    IF(ASSOCIATED(EQUATIONS_ANALYTIC)) THEN
                      !Update boundary conditions and any analytic values
                      CALL NavierStokes_PreSolveUpdateBoundaryConditions(SOLVER,ERR,ERROR,*999)
                    END IF
                  ELSE
                    CALL FlagError("Equations set is not associated.",ERR,ERROR,*999)
                  END IF
                ELSE
                  CALL FlagError("Solver mapping is not associated.",ERR,ERROR,*999)
                END IF
              ELSE
                CALL FlagError("Solver equations is not associated.",ERR,ERROR,*999)
              END IF
            CASE(PROBLEM_TRANSIENT_NAVIER_STOKES_SUBTYPE)
              !Update transient boundary conditions and any analytic values
              CALL NavierStokes_PreSolveUpdateBoundaryConditions(SOLVER,ERR,ERROR,*999)
            CASE(PROBLEM_TRANSIENT_RBS_NAVIER_STOKES_SUBTYPE)
              !Update transient boundary conditions
              CALL NavierStokes_PreSolveUpdateBoundaryConditions(SOLVER,ERR,ERROR,*999)
            CASE(PROBLEM_MULTISCALE_NAVIER_STOKES_SUBTYPE)
              !Update transient boundary conditions
              CALL NavierStokes_PreSolveUpdateBoundaryConditions(SOLVER,ERR,ERROR,*999)
              !CALL NavierStokes_CalculateBoundaryFlux(CONTROL_LOOP,SOLVER,ERR,ERROR,*999)
              nonlinearSolver=>SOLVER%DYNAMIC_SOLVER%NONLINEAR_SOLVER%NONLINEAR_SOLVER
              IF(ASSOCIATED(nonlinearSolver)) THEN
                !check for a linked CellML solver 
                cellmlSolver=>nonlinearSolver%NEWTON_SOLVER%CELLML_EVALUATOR_SOLVER
                IF(ASSOCIATED(cellmlSolver)) THEN
                  ! Calculate the CellML equations
                  CALL SOLVER_SOLVE(cellmlSolver,ERR,ERROR,*999)
                END IF
              ELSE
                CALL FlagError("Nonlinear solver is not associated.",ERR,ERROR,*999)
              END IF

            CASE(PROBLEM_TRANSIENT1D_NAVIER_STOKES_SUBTYPE, &
              &  PROBLEM_COUPLED1D0D_NAVIER_STOKES_SUBTYPE, &
              &  PROBLEM_STREE1D0D_NAVIER_STOKES_SUBTYPE, &
              &  PROBLEM_TRANSIENT1D_ADV_NAVIER_STOKES_SUBTYPE, &
              &  PROBLEM_COUPLED1D0D_ADV_NAVIER_STOKES_SUBTYPE, &
              &  PROBLEM_STREE1D0D_ADV_NAVIER_STOKES_SUBTYPE)

              SELECT CASE(SOLVER%SOLVE_TYPE)
              ! This switch takes advantage of the uniqueness of the solver types to do pre-solve operations
              ! for each of solvers in the various possible 1D subloops

              ! --- C h a r a c t e r i s t i c   S o l v e r ---
              CASE(SOLVER_NONLINEAR_TYPE)
                CALL CONTROL_LOOP_CURRENT_TIMES_GET(CONTROL_LOOP,currentTime,timeIncrement,ERR,ERROR,*999)
                iteration = CONTROL_LOOP%WHILE_LOOP%ITERATION_NUMBER
                EQUATIONS_SET=>SOLVER%SOLVER_EQUATIONS%SOLVER_MAPPING%EQUATIONS_SETS(1)%PTR
                dependentField=>EQUATIONS_SET%DEPENDENT%DEPENDENT_FIELD
                ! Characteristic solver effectively solves for the mass/momentum conserving fluxes at the
                ! *NEXT* timestep by extrapolating current field values and then solving a system of nonlinear
                ! equations: cons mass, continuity of pressure, and the characteristics.
                NULLIFY(fieldVariable)
                CALL FIELD_VARIABLE_GET(dependentField,FIELD_U_VARIABLE_TYPE,fieldVariable,ERR,ERROR,*999)
                IF(.NOT.ASSOCIATED(fieldVariable%PARAMETER_SETS%SET_TYPE(FIELD_INPUT_DATA1_SET_TYPE)%PTR)) THEN
                  CALL FIELD_PARAMETER_SET_CREATE(dependentField,FIELD_U_VARIABLE_TYPE, &
                   & FIELD_INPUT_DATA1_SET_TYPE,ERR,ERROR,*999)
                  CALL FIELD_PARAMETER_SET_CREATE(dependentField,FIELD_U_VARIABLE_TYPE, &
                   & FIELD_INPUT_DATA2_SET_TYPE,ERR,ERROR,*999)
                END IF
                CALL FIELD_PARAMETER_SETS_COPY(dependentField,FIELD_U_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE, &
                 & FIELD_INPUT_DATA1_SET_TYPE,1.0_DP,ERR,ERROR,*999)
                CALL FIELD_PARAMETER_SETS_COPY(dependentField,FIELD_U_VARIABLE_TYPE,FIELD_RESIDUAL_SET_TYPE, &
                 & FIELD_INPUT_DATA2_SET_TYPE,1.0_DP,ERR,ERROR,*999)

                IF(iteration == 1) THEN
                  NULLIFY(fieldVariable)
                  CALL FIELD_VARIABLE_GET(dependentField,FIELD_U_VARIABLE_TYPE,fieldVariable,ERR,ERROR,*999)
                  IF(.NOT.ASSOCIATED(fieldVariable%PARAMETER_SETS%SET_TYPE(FIELD_UPWIND_VALUES_SET_TYPE)%PTR)) THEN
                    CALL FIELD_PARAMETER_SET_CREATE(dependentField,FIELD_U_VARIABLE_TYPE, &
                     & FIELD_UPWIND_VALUES_SET_TYPE,ERR,ERROR,*999)
                  END IF
                  ! Extrapolate new W from Q,A if this is the first timestep (otherwise will be calculated based on Navier-Stokes
                  ! values)
                  CALL Characteristic_Extrapolate(SOLVER,currentTime,timeIncrement,ERR,ERROR,*999)
                END IF

              ! --- 1 D   N a v i e r - S t o k e s   S o l v e r ---
              CASE(SOLVER_DYNAMIC_TYPE)
                IF(SOLVER%global_number==2) THEN
                  ! update solver matrix
                  SOLVER_EQUATIONS=>SOLVER%SOLVER_EQUATIONS
                  IF(ASSOCIATED(SOLVER_EQUATIONS)) THEN
                    SOLVER_MAPPING=>SOLVER_EQUATIONS%SOLVER_MAPPING
                    IF(ASSOCIATED(SOLVER_MAPPING)) THEN
                      SOLVER_MATRICES=>SOLVER_EQUATIONS%SOLVER_MATRICES
                      IF(ASSOCIATED(SOLVER_MATRICES)) THEN
                        DO solver_matrix_idx=1,SOLVER_MAPPING%NUMBER_OF_SOLVER_MATRICES
                          SOLVER_MATRIX=>SOLVER_MATRICES%MATRICES(solver_matrix_idx)%PTR
                          IF(ASSOCIATED(SOLVER_MATRIX)) THEN
                            SOLVER_MATRIX%UPDATE_MATRIX=.TRUE.
                          ELSE
                            CALL FlagError("Solver Matrix is not associated.",ERR,ERROR,*999)
                          END IF
                        END DO
                      ELSE
                        CALL FlagError("Solver Matrices is not associated.",ERR,ERROR,*999)
                      END IF
                      EQUATIONS_SET=>SOLVER_MAPPING%EQUATIONS_SETS(1)%PTR
                      IF(ASSOCIATED(EQUATIONS_SET)) THEN
                        dependentField=>EQUATIONS_SET%DEPENDENT%DEPENDENT_FIELD
                        IF(ASSOCIATED(dependentField)) THEN
                          CALL FIELD_PARAMETER_SETS_COPY(dependentField,FIELD_U_VARIABLE_TYPE,FIELD_INPUT_DATA1_SET_TYPE, &
                           & FIELD_VALUES_SET_TYPE,1.0_DP,ERR,ERROR,*999)
                          CALL FIELD_PARAMETER_SETS_COPY(dependentField,FIELD_U_VARIABLE_TYPE,FIELD_INPUT_DATA2_SET_TYPE, &
                           & FIELD_RESIDUAL_SET_TYPE,1.0_DP,ERR,ERROR,*999)
                        ELSE
                          CALL FlagError("Dependent field is not associated.",err,error,*999)
                        END IF
                      ELSE
                        CALL FlagError("Equations set is not associated.",err,error,*999)
                      END IF
                    ELSE
                      CALL FlagError("Solver mapping is not associated.",ERR,ERROR,*999)
                    END IF
                  ELSE
                    CALL FlagError("Solver equations is not associated.",ERR,ERROR,*999)
                  END IF
                ELSE
                  ! --- A d v e c t i o n   S o l v e r ---
                  CALL ADVECTION_PRE_SOLVE(SOLVER,ERR,ERROR,*999)
                END IF
                ! Update boundary conditions
                CALL NavierStokes_PreSolveUpdateBoundaryConditions(SOLVER,ERR,ERROR,*999)

              ! --- C e l l M L    S o l v e r ---
              CASE(SOLVER_DAE_TYPE)
                ! DAE solver-set time
                CALL CONTROL_LOOP_CURRENT_TIMES_GET(CONTROL_LOOP,currentTime,timeIncrement,ERR,ERROR,*999)
                CALL SOLVER_DAE_TIMES_SET(SOLVER,currentTime,currentTime + timeIncrement,ERR,ERROR,*999)
                CALL SOLVER_DAE_TIME_STEP_SET(SOLVER,timeIncrement/1000.0_DP,ERR,ERROR,*999)

              ! --- S T R E E    S o l v e r ---
              CASE(SOLVER_LINEAR_TYPE)
                CALL Stree_PRE_SOLVE(SOLVER,ERR,ERROR,*999)

              CASE DEFAULT
                LOCAL_ERROR="The solve type of "//TRIM(NUMBER_TO_VSTRING(SOLVER%SOLVE_TYPE,"*",ERR,ERROR))// &
                  & " is invalid for a 1D Navier-Stokes problem."
                CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
              END SELECT   

            CASE(PROBLEM_QUASISTATIC_NAVIER_STOKES_SUBTYPE)
              ! do nothing ???
              CALL NavierStokes_PreSolveUpdateBoundaryConditions(SOLVER,ERR,ERROR,*999)
            CASE(PROBLEM_PGM_NAVIER_STOKES_SUBTYPE)
              ! do nothing ???
              !First update mesh and calculates boundary velocity values
              CALL NAVIER_STOKES_PRE_SOLVE_ALE_UPDATE_MESH(SOLVER,ERR,ERROR,*999)
              !Then apply both normal and moving mesh boundary conditions
              CALL NavierStokes_PreSolveUpdateBoundaryConditions(SOLVER,ERR,ERROR,*999)
            CASE(PROBLEM_ALE_NAVIER_STOKES_SUBTYPE)
              !Pre solve for the linear solver
              IF(SOLVER%SOLVE_TYPE==SOLVER_LINEAR_TYPE) THEN
                CALL WRITE_STRING(GENERAL_OUTPUT_TYPE,"Mesh movement pre solve... ",ERR,ERROR,*999)
                !Update boundary conditions for mesh-movement
                CALL NavierStokes_PreSolveUpdateBoundaryConditions(SOLVER,ERR,ERROR,*999)
                CALL SOLVERS_SOLVER_GET(SOLVER%SOLVERS,2,SOLVER2,ERR,ERROR,*999)
                IF(ASSOCIATED(SOLVER2%DYNAMIC_SOLVER)) THEN
                  SOLVER2%DYNAMIC_SOLVER%ALE=.FALSE.
                ELSE  
                  CALL FlagError("Dynamic solver is not associated for ALE problem.",ERR,ERROR,*999)
                END IF
                !Update material properties for Laplace mesh movement
                CALL NavierStokes_PreSolveALEUpdateParameters(SOLVER,ERR,ERROR,*999)
                !Pre solve for the linear solver
              ELSE IF(SOLVER%SOLVE_TYPE==SOLVER_DYNAMIC_TYPE) THEN
                CALL WRITE_STRING(GENERAL_OUTPUT_TYPE,"ALE Navier-Stokes pre solve... ",ERR,ERROR,*999)
                IF(SOLVER%DYNAMIC_SOLVER%ALE) THEN
                  !First update mesh and calculates boundary velocity values
                  CALL NAVIER_STOKES_PRE_SOLVE_ALE_UPDATE_MESH(SOLVER,ERR,ERROR,*999)
                  !Then apply both normal and moving mesh boundary conditions
                  CALL NavierStokes_PreSolveUpdateBoundaryConditions(SOLVER,ERR,ERROR,*999)
                ELSE  
                  CALL FlagError("Mesh motion calculation not successful for ALE problem.",ERR,ERROR,*999)
                END IF
              ELSE  
                CALL FlagError("Solver type is not associated for ALE problem.",ERR,ERROR,*999)
              END IF
            CASE DEFAULT
              LOCAL_ERROR="Problem subtype "//TRIM(NUMBER_TO_VSTRING(CONTROL_LOOP%PROBLEM%SPECIFICATION(3),"*",ERR,ERROR))// &
                & " is not valid for a Navier-Stokes fluid type of a fluid mechanics problem class."
              CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
            END SELECT
          CASE(PROBLEM_MULTI_PHYSICS_CLASS)
            SELECT CASE(CONTROL_LOOP%PROBLEM%SPECIFICATION(2))
            CASE(PROBLEM_FINITE_ELASTICITY_NAVIER_STOKES_TYPE)
              SELECT CASE(CONTROL_LOOP%PROBLEM%SPECIFICATION(3))
              CASE(PROBLEM_FINITE_ELASTICITY_NAVIER_STOKES_ALE_SUBTYPE)
                !Pre solve for the linear solver
                IF(SOLVER%SOLVE_TYPE==SOLVER_LINEAR_TYPE) THEN
                  CALL WRITE_STRING(GENERAL_OUTPUT_TYPE,"Mesh movement pre solve... ",ERR,ERROR,*999)
                  !TODO if first time step smooth imported mesh with respect to absolute nodal position?

                  !Update boundary conditions for mesh-movement
                  CALL NavierStokes_PreSolveUpdateBoundaryConditions(SOLVER,ERR,ERROR,*999)
                  CALL SOLVERS_SOLVER_GET(SOLVER%SOLVERS,1,SOLVER2,ERR,ERROR,*999)
                  IF(ASSOCIATED(SOLVER2%DYNAMIC_SOLVER)) THEN
                    SOLVER2%DYNAMIC_SOLVER%ALE=.FALSE.
                  ELSE  
                    CALL FlagError("Dynamic solver is not associated for ALE problem.",ERR,ERROR,*999)
                  END IF
                  !Update material properties for Laplace mesh movement
                  CALL NavierStokes_PreSolveALEUpdateParameters(SOLVER,ERR,ERROR,*999)
                  !Pre solve for the dynamic solver which deals with the coupled FiniteElasticity-NavierStokes problem
                ELSE IF(SOLVER%SOLVE_TYPE==SOLVER_DYNAMIC_TYPE) THEN
                  CALL WRITE_STRING(GENERAL_OUTPUT_TYPE,"ALE Navier-Stokes pre solve... ",ERR,ERROR,*999)
                  IF(SOLVER%DYNAMIC_SOLVER%ALE) THEN
                    !Apply both normal and moving mesh boundary conditions
                    CALL NavierStokes_PreSolveUpdateBoundaryConditions(SOLVER,ERR,ERROR,*999)
                  ELSE  
                    CALL FlagError("Mesh motion calculation not successful for ALE problem.",ERR,ERROR,*999)
                  END IF
                ELSE  
                  CALL FlagError("Solver type is not associated for ALE problem.",ERR,ERROR,*999)
                END IF
              CASE DEFAULT
                LOCAL_ERROR="Problem subtype "//TRIM(NUMBER_TO_VSTRING(CONTROL_LOOP%PROBLEM%SPECIFICATION(3),"*",ERR,ERROR))// &
                  & " is not valid for a FiniteElasticity-NavierStokes type of a multi physics problem class."
                CALL FlagError(LOCAL_ERROR,Err,Error,*999)
              END SELECT
            CASE DEFAULT
              LOCAL_ERROR="Problem type "//TRIM(NUMBER_TO_VSTRING(CONTROL_LOOP%PROBLEM%SPECIFICATION(2),"*",ERR,ERROR))// &
                & " is not valid for NAVIER_STOKES_PRE_SOLVE of a multi physics problem class."
              CALL FlagError(LOCAL_ERROR,Err,Error,*999)
            END SELECT
          CASE DEFAULT
            LOCAL_ERROR="Problem class "//TRIM(NUMBER_TO_VSTRING(CONTROL_LOOP%PROBLEM%SPECIFICATION(1),"*",ERR,ERROR))// &
              & " is not valid for Navier-Stokes fluid types."
            CALL FlagError(LOCAL_ERROR,Err,Error,*999)
          END SELECT
        ELSE
          CALL FlagError("Problem is not associated.",ERR,ERROR,*999)
        END IF
      ELSE
        CALL FlagError("Solvers are not associated.",ERR,ERROR,*999)
      END IF
    ELSE
      CALL FlagError("Solver is not associated.",ERR,ERROR,*999)
    END IF

    EXITS("NAVIER_STOKES_PRE_SOLVE")
    RETURN
999 ERRORSEXITS("NAVIER_STOKES_PRE_SOLVE",ERR,ERROR)
    RETURN 1
    
  END SUBROUTINE NAVIER_STOKES_PRE_SOLVE

! 
!================================================================================================================================
!

  !>Sets/changes the problem subtype for a Navier-Stokes fluid type.
  SUBROUTINE NavierStokes_ProblemSpecificationSet(problem,problemSpecification,err,error,*)

    !Argument variables
    TYPE(PROBLEM_TYPE), POINTER :: problem !<A pointer to the problem to set the problem specification for
    INTEGER(INTG), INTENT(IN) :: problemSpecification(:) !<The problem specification to set
    INTEGER(INTG), INTENT(OUT) :: err !<The error code
    TYPE(VARYING_STRING), INTENT(OUT) :: error !<The error string
    !Local Variables
    TYPE(VARYING_STRING) :: localError
    INTEGER(INTG) :: problemSubtype

    ENTERS("NavierStokes_ProblemSpecificationSet",err,error,*999)

    IF(ASSOCIATED(PROBLEM)) THEN
      IF(SIZE(problemSpecification,1)==3) THEN
        problemSubtype=problemSpecification(3)
        SELECT CASE(problemSubtype)
        CASE(PROBLEM_STATIC_NAVIER_STOKES_SUBTYPE, &
            & PROBLEM_LAPLACE_NAVIER_STOKES_SUBTYPE, &
            & PROBLEM_TRANSIENT_NAVIER_STOKES_SUBTYPE, &
            & PROBLEM_TRANSIENT1D_NAVIER_STOKES_SUBTYPE, &
            & PROBLEM_TRANSIENT1D_ADV_NAVIER_STOKES_SUBTYPE, &
            & PROBLEM_COUPLED1D0D_NAVIER_STOKES_SUBTYPE, &
            & PROBLEM_COUPLED1D0D_ADV_NAVIER_STOKES_SUBTYPE, &
            & PROBLEM_STREE1D0D_NAVIER_STOKES_SUBTYPE, &
            & PROBLEM_STREE1D0D_ADV_NAVIER_STOKES_SUBTYPE, &
            & PROBLEM_TRANSIENT_RBS_NAVIER_STOKES_SUBTYPE, &
            & PROBLEM_MULTISCALE_NAVIER_STOKES_SUBTYPE, &
            & PROBLEM_QUASISTATIC_NAVIER_STOKES_SUBTYPE, &
            & PROBLEM_ALE_NAVIER_STOKES_SUBTYPE, &
            & PROBLEM_PGM_NAVIER_STOKES_SUBTYPE)
          !All ok
        CASE(PROBLEM_OPTIMISED_NAVIER_STOKES_SUBTYPE)
          CALL FlagError("Not implemented yet.",err,error,*999)
        CASE DEFAULT
          localError="The third problem specification of "//TRIM(NumberToVstring(problemSubtype,"*",err,error))// &
            & " is not valid for a Navier-Stokes fluid mechanics problem."
          CALL FlagError(localError,err,error,*999)
        END SELECT
        IF(ALLOCATED(problem%specification)) THEN
          CALL FlagError("Problem specification is already allocated.",err,error,*999)
        ELSE
          ALLOCATE(problem%specification(3),stat=err)
          IF(err/=0) CALL FlagError("Could not allocate problem specification.",err,error,*999)
        END IF
        problem%specification(1:3)=[PROBLEM_FLUID_MECHANICS_CLASS,PROBLEM_NAVIER_STOKES_EQUATION_TYPE,problemSubtype]
      ELSE
        CALL FlagError("Navier-Stokes problem specification must have three entries.",err,error,*999)
      END IF
    ELSE
      CALL FlagError("Problem is not associated.",err,error,*999)
    END IF

    EXITS("NavierStokes_ProblemSpecificationSet")
    RETURN
999 ERRORS("NavierStokes_ProblemSpecificationSet",err,error)
    EXITS("NavierStokes_ProblemSpecificationSet")
    RETURN 1
    
  END SUBROUTINE NavierStokes_ProblemSpecificationSet

! 
!================================================================================================================================
!
  
  !>Sets up the Navier-Stokes problem.
  SUBROUTINE NAVIER_STOKES_PROBLEM_SETUP(PROBLEM,PROBLEM_SETUP,ERR,ERROR,*)

    !Argument variables
    TYPE(PROBLEM_TYPE), POINTER :: PROBLEM !<A pointer to the problem set to setup a Navier-Stokes fluid on.
    TYPE(PROBLEM_SETUP_TYPE), INTENT(INOUT) :: PROBLEM_SETUP !<The problem setup information
    INTEGER(INTG), INTENT(OUT) :: ERR !<The error code
    TYPE(VARYING_STRING), INTENT(OUT) :: ERROR !<The error string
    !Local Variables
    TYPE(CELLML_EQUATIONS_TYPE), POINTER :: CELLML_EQUATIONS
    TYPE(CONTROL_LOOP_TYPE), POINTER :: CONTROL_LOOP,CONTROL_LOOP_ROOT
    TYPE(CONTROL_LOOP_TYPE), POINTER :: iterativeWhileLoop,iterativeWhileLoop2,simpleLoop
    TYPE(SOLVER_EQUATIONS_TYPE), POINTER :: SOLVER_EQUATIONS,MESH_SOLVER_EQUATIONS,BIF_SOLVER_EQUATIONS
    TYPE(SOLVERS_TYPE), POINTER :: SOLVERS
    TYPE(SOLVER_TYPE), POINTER :: SOLVER, MESH_SOLVER,BIF_SOLVER,cellmlSolver
    TYPE(VARYING_STRING) :: LOCAL_ERROR

    ENTERS("NAVIER_STOKES_PROBLEM_SETUP",ERR,ERROR,*999)

    NULLIFY(BIF_SOLVER)
    NULLIFY(BIF_SOLVER_EQUATIONS)
    NULLIFY(cellmlSolver)
    NULLIFY(CELLML_EQUATIONS)
    NULLIFY(CONTROL_LOOP)
    NULLIFY(CONTROL_LOOP_ROOT)
    NULLIFY(MESH_SOLVER)
    NULLIFY(MESH_SOLVER_EQUATIONS)
    NULLIFY(SOLVER)
    NULLIFY(SOLVER_EQUATIONS)
    NULLIFY(SOLVERS)

    IF(ASSOCIATED(PROBLEM)) THEN
      IF(.NOT.ALLOCATED(problem%specification)) THEN
        CALL FlagError("Problem specification is not allocated.",err,error,*999)
      ELSE IF(SIZE(problem%specification,1)<3) THEN
        CALL FlagError("Problem specification must have three entries for a Navier-Stokes problem.",err,error,*999)
      END IF
      SELECT CASE(PROBLEM%SPECIFICATION(3))
        !All steady state cases of Navier-Stokes
        CASE(PROBLEM_STATIC_NAVIER_STOKES_SUBTYPE, &
           & PROBLEM_LAPLACE_NAVIER_STOKES_SUBTYPE)
          SELECT CASE(PROBLEM_SETUP%SETUP_TYPE)
            CASE(PROBLEM_SETUP_INITIAL_TYPE)
              SELECT CASE(PROBLEM_SETUP%ACTION_TYPE)
                CASE(PROBLEM_SETUP_START_ACTION)
                  !Do nothing????
                CASE(PROBLEM_SETUP_FINISH_ACTION)
                  !Do nothing???
                CASE DEFAULT
                  LOCAL_ERROR="The action type of "//TRIM(NUMBER_TO_VSTRING(PROBLEM_SETUP%ACTION_TYPE,"*",ERR,ERROR))// &
                    & " for a setup type of "//TRIM(NUMBER_TO_VSTRING(PROBLEM_SETUP%SETUP_TYPE,"*",ERR,ERROR))// &
                    & " is invalid for a Navier-Stokes fluid."
                  CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
              END SELECT
            CASE(PROBLEM_SETUP_CONTROL_TYPE)
              SELECT CASE(PROBLEM_SETUP%ACTION_TYPE)
                CASE(PROBLEM_SETUP_START_ACTION)
                  !Set up a simple control loop
                  CALL CONTROL_LOOP_CREATE_START(PROBLEM,CONTROL_LOOP,ERR,ERROR,*999)
                CASE(PROBLEM_SETUP_FINISH_ACTION)
                  !Finish the control loops
                  CONTROL_LOOP_ROOT=>PROBLEM%CONTROL_LOOP
                  CALL CONTROL_LOOP_GET(CONTROL_LOOP_ROOT,CONTROL_LOOP_NODE,CONTROL_LOOP,ERR,ERROR,*999)
                  CALL CONTROL_LOOP_CREATE_FINISH(CONTROL_LOOP,ERR,ERROR,*999)
                CASE DEFAULT
                  LOCAL_ERROR="The action type of "//TRIM(NUMBER_TO_VSTRING(PROBLEM_SETUP%ACTION_TYPE,"*",ERR,ERROR))// &
                    & " for a setup type of "//TRIM(NUMBER_TO_VSTRING(PROBLEM_SETUP%SETUP_TYPE,"*",ERR,ERROR))// &
                    & " is invalid for a Navier-Stokes fluid."
                  CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
              END SELECT
            CASE(PROBLEM_SETUP_SOLVERS_TYPE)
              !Get the control loop
              CONTROL_LOOP_ROOT=>PROBLEM%CONTROL_LOOP
              CALL CONTROL_LOOP_GET(CONTROL_LOOP_ROOT,CONTROL_LOOP_NODE,CONTROL_LOOP,ERR,ERROR,*999)
              SELECT CASE(PROBLEM_SETUP%ACTION_TYPE)
                CASE(PROBLEM_SETUP_START_ACTION)
                  !Start the solvers creation
                  CALL SOLVERS_CREATE_START(CONTROL_LOOP,SOLVERS,ERR,ERROR,*999)
                  CALL SOLVERS_NUMBER_SET(SOLVERS,1,ERR,ERROR,*999)
                  !Set the solver to be a nonlinear solver
                  CALL SOLVERS_SOLVER_GET(SOLVERS,1,SOLVER,ERR,ERROR,*999)
                  CALL SOLVER_TYPE_SET(SOLVER,SOLVER_NONLINEAR_TYPE,ERR,ERROR,*999)
                  !Set solver defaults
                  CALL SOLVER_LIBRARY_TYPE_SET(SOLVER,SOLVER_PETSC_LIBRARY,ERR,ERROR,*999)
                CASE(PROBLEM_SETUP_FINISH_ACTION)
                  !Get the solvers
                  CALL CONTROL_LOOP_SOLVERS_GET(CONTROL_LOOP,SOLVERS,ERR,ERROR,*999)
                  !Finish the solvers creation
                  CALL SOLVERS_CREATE_FINISH(SOLVERS,ERR,ERROR,*999)
                CASE DEFAULT
                  LOCAL_ERROR="The action type of "//TRIM(NUMBER_TO_VSTRING(PROBLEM_SETUP%ACTION_TYPE,"*",ERR,ERROR))// &
                    & " for a setup type of "//TRIM(NUMBER_TO_VSTRING(PROBLEM_SETUP%SETUP_TYPE,"*",ERR,ERROR))// &
                    & " is invalid for a Navier-Stokes fluid."
                  CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
              END SELECT
            CASE(PROBLEM_SETUP_SOLVER_EQUATIONS_TYPE)
              SELECT CASE(PROBLEM_SETUP%ACTION_TYPE)
                CASE(PROBLEM_SETUP_START_ACTION)
                  !Get the control loop
                  CONTROL_LOOP_ROOT=>PROBLEM%CONTROL_LOOP
                  CALL CONTROL_LOOP_GET(CONTROL_LOOP_ROOT,CONTROL_LOOP_NODE,CONTROL_LOOP,ERR,ERROR,*999)
                  !Get the solver
                  CALL CONTROL_LOOP_SOLVERS_GET(CONTROL_LOOP,SOLVERS,ERR,ERROR,*999)
                  CALL SOLVERS_SOLVER_GET(SOLVERS,1,SOLVER,ERR,ERROR,*999)
                  !Create the solver equations
                  CALL SOLVER_EQUATIONS_CREATE_START(SOLVER,SOLVER_EQUATIONS,ERR,ERROR,*999)
                  CALL SOLVER_EQUATIONS_LINEARITY_TYPE_SET(SOLVER_EQUATIONS,SOLVER_EQUATIONS_NONLINEAR,ERR,ERROR,*999)
                  CALL SOLVER_EQUATIONS_TIME_DEPENDENCE_TYPE_SET(SOLVER_EQUATIONS,SOLVER_EQUATIONS_STATIC,ERR,ERROR,*999)
                  CALL SOLVER_EQUATIONS_SPARSITY_TYPE_SET(SOLVER_EQUATIONS,SOLVER_SPARSE_MATRICES,ERR,ERROR,*999)
                CASE(PROBLEM_SETUP_FINISH_ACTION)
                  !Get the control loop
                  CONTROL_LOOP_ROOT=>PROBLEM%CONTROL_LOOP
                  CALL CONTROL_LOOP_GET(CONTROL_LOOP_ROOT,CONTROL_LOOP_NODE,CONTROL_LOOP,ERR,ERROR,*999)
                  !Get the solver equations
                  CALL CONTROL_LOOP_SOLVERS_GET(CONTROL_LOOP,SOLVERS,ERR,ERROR,*999)
                  CALL SOLVERS_SOLVER_GET(SOLVERS,1,SOLVER,ERR,ERROR,*999)
                  CALL SOLVER_SOLVER_EQUATIONS_GET(SOLVER,SOLVER_EQUATIONS,ERR,ERROR,*999)
                  !Finish the solver equations creation
                  CALL SOLVER_EQUATIONS_CREATE_FINISH(SOLVER_EQUATIONS,ERR,ERROR,*999)
                CASE DEFAULT
                  LOCAL_ERROR="The action type of "//TRIM(NUMBER_TO_VSTRING(PROBLEM_SETUP%ACTION_TYPE,"*",ERR,ERROR))// &
                    & " for a setup type of "//TRIM(NUMBER_TO_VSTRING(PROBLEM_SETUP%SETUP_TYPE,"*",ERR,ERROR))// &
                    & " is invalid for a Navier-Stokes fluid."
                  CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
              END SELECT
            CASE DEFAULT
              LOCAL_ERROR="The setup type of "//TRIM(NUMBER_TO_VSTRING(PROBLEM_SETUP%SETUP_TYPE,"*",ERR,ERROR))// &
                & " is invalid for a Navier-Stokes fluid."
              CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
          END SELECT
        !Transient cases and moving mesh
        CASE(PROBLEM_TRANSIENT_NAVIER_STOKES_SUBTYPE, &
           & PROBLEM_PGM_NAVIER_STOKES_SUBTYPE, &
           & PROBLEM_TRANSIENT_RBS_NAVIER_STOKES_SUBTYPE, &
           & PROBLEM_MULTISCALE_NAVIER_STOKES_SUBTYPE)
          SELECT CASE(PROBLEM_SETUP%SETUP_TYPE)
            CASE(PROBLEM_SETUP_INITIAL_TYPE)
              SELECT CASE(PROBLEM_SETUP%ACTION_TYPE)
                CASE(PROBLEM_SETUP_START_ACTION)
                  !Do nothing????
                CASE(PROBLEM_SETUP_FINISH_ACTION)
                  !Do nothing???
                CASE DEFAULT
                  LOCAL_ERROR="The action type of "//TRIM(NUMBER_TO_VSTRING(PROBLEM_SETUP%ACTION_TYPE,"*",ERR,ERROR))// &
                    & " for a setup type of "//TRIM(NUMBER_TO_VSTRING(PROBLEM_SETUP%SETUP_TYPE,"*",ERR,ERROR))// &
                    & " is invalid for a transient Navier-Stokes fluid."
                  CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
              END SELECT
            CASE(PROBLEM_SETUP_CONTROL_TYPE)
              SELECT CASE(PROBLEM_SETUP%ACTION_TYPE)
                CASE(PROBLEM_SETUP_START_ACTION)
                  !Set up a time control loop
                  CALL CONTROL_LOOP_CREATE_START(PROBLEM,CONTROL_LOOP,ERR,ERROR,*999)
                  CALL CONTROL_LOOP_TYPE_SET(CONTROL_LOOP,PROBLEM_CONTROL_TIME_LOOP_TYPE,ERR,ERROR,*999)
                CASE(PROBLEM_SETUP_FINISH_ACTION)
                  !Finish the control loops
                  CONTROL_LOOP_ROOT=>PROBLEM%CONTROL_LOOP
                  CALL CONTROL_LOOP_GET(CONTROL_LOOP_ROOT,CONTROL_LOOP_NODE,CONTROL_LOOP,ERR,ERROR,*999)
                  CALL CONTROL_LOOP_CREATE_FINISH(CONTROL_LOOP,ERR,ERROR,*999)
                CASE DEFAULT
                  LOCAL_ERROR="The action type of "//TRIM(NUMBER_TO_VSTRING(PROBLEM_SETUP%ACTION_TYPE,"*",ERR,ERROR))// &
                    & " for a setup type of "//TRIM(NUMBER_TO_VSTRING(PROBLEM_SETUP%SETUP_TYPE,"*",ERR,ERROR))// &
                    & " is invalid for a transient Navier-Stokes fluid."
                  CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
              END SELECT
            CASE(PROBLEM_SETUP_SOLVERS_TYPE)
              !Get the control loop
              CONTROL_LOOP_ROOT=>PROBLEM%CONTROL_LOOP
              CALL CONTROL_LOOP_GET(CONTROL_LOOP_ROOT,CONTROL_LOOP_NODE,CONTROL_LOOP,ERR,ERROR,*999)
              SELECT CASE(PROBLEM_SETUP%ACTION_TYPE)
                CASE(PROBLEM_SETUP_START_ACTION)
                  !Start the solvers creation
                  CALL SOLVERS_CREATE_START(CONTROL_LOOP,SOLVERS,ERR,ERROR,*999)
                  CALL SOLVERS_NUMBER_SET(SOLVERS,1,ERR,ERROR,*999)
                  !Set the solver to be a first order dynamic solver 
                  CALL SOLVERS_SOLVER_GET(SOLVERS,1,SOLVER,ERR,ERROR,*999)
                  CALL SOLVER_TYPE_SET(SOLVER,SOLVER_DYNAMIC_TYPE,ERR,ERROR,*999)
                  CALL SOLVER_DYNAMIC_LINEARITY_TYPE_SET(SOLVER,SOLVER_DYNAMIC_NONLINEAR,ERR,ERROR,*999)
                  CALL SOLVER_DYNAMIC_ORDER_SET(SOLVER,SOLVER_DYNAMIC_FIRST_ORDER,ERR,ERROR,*999)
                  !Set solver defaults
                  CALL SOLVER_DYNAMIC_DEGREE_SET(SOLVER,SOLVER_DYNAMIC_FIRST_DEGREE,ERR,ERROR,*999)
                  CALL SOLVER_DYNAMIC_SCHEME_SET(SOLVER,SOLVER_DYNAMIC_CRANK_NICOLSON_SCHEME,ERR,ERROR,*999)
                  CALL SOLVER_LIBRARY_TYPE_SET(SOLVER,SOLVER_CMISS_LIBRARY,ERR,ERROR,*999)
                  !setup CellML evaluator
                  IF(PROBLEM%specification(3)==PROBLEM_MULTISCALE_NAVIER_STOKES_SUBTYPE) THEN
                    !Create the CellML evaluator solver
                    CALL SOLVER_NEWTON_CELLML_EVALUATOR_CREATE(SOLVER,cellmlSolver,ERR,ERROR,*999)
                    !Link the CellML evaluator solver to the solver
                    CALL SOLVER_LINKED_SOLVER_ADD(SOLVER,cellmlSolver,SOLVER_CELLML_EVALUATOR_TYPE,ERR,ERROR,*999)
                  END IF
                CASE(PROBLEM_SETUP_FINISH_ACTION)
                  !Get the solvers
                  CALL CONTROL_LOOP_SOLVERS_GET(CONTROL_LOOP,SOLVERS,ERR,ERROR,*999)
                  !Finish the solvers creation
                  CALL SOLVERS_CREATE_FINISH(SOLVERS,ERR,ERROR,*999)
                CASE DEFAULT
                  LOCAL_ERROR="The action type of "//TRIM(NUMBER_TO_VSTRING(PROBLEM_SETUP%ACTION_TYPE,"*",ERR,ERROR))// &
                    & " for a setup type of "//TRIM(NUMBER_TO_VSTRING(PROBLEM_SETUP%SETUP_TYPE,"*",ERR,ERROR))// &
                    & " is invalid for a transient Navier-Stokes fluid."
                  CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
              END SELECT
            CASE(PROBLEM_SETUP_SOLVER_EQUATIONS_TYPE)
              SELECT CASE(PROBLEM_SETUP%ACTION_TYPE)
                CASE(PROBLEM_SETUP_START_ACTION)
                  !Get the control loop
                  CONTROL_LOOP_ROOT=>PROBLEM%CONTROL_LOOP
                  CALL CONTROL_LOOP_GET(CONTROL_LOOP_ROOT,CONTROL_LOOP_NODE,CONTROL_LOOP,ERR,ERROR,*999)
                  !Get the solver
                  CALL CONTROL_LOOP_SOLVERS_GET(CONTROL_LOOP,SOLVERS,ERR,ERROR,*999)
                  CALL SOLVERS_SOLVER_GET(SOLVERS,1,SOLVER,ERR,ERROR,*999)
                  !Create the solver equations
                  CALL SOLVER_EQUATIONS_CREATE_START(SOLVER,SOLVER_EQUATIONS,ERR,ERROR,*999)
                  CALL SOLVER_EQUATIONS_LINEARITY_TYPE_SET(SOLVER_EQUATIONS,SOLVER_EQUATIONS_NONLINEAR,ERR,ERROR,*999)
                  CALL SOLVER_EQUATIONS_TIME_DEPENDENCE_TYPE_SET(SOLVER_EQUATIONS,SOLVER_EQUATIONS_FIRST_ORDER_DYNAMIC,&
                  & ERR,ERROR,*999)
                  CALL SOLVER_EQUATIONS_SPARSITY_TYPE_SET(SOLVER_EQUATIONS,SOLVER_SPARSE_MATRICES,ERR,ERROR,*999)
                CASE(PROBLEM_SETUP_FINISH_ACTION)
                  !Get the control loop
                  CONTROL_LOOP_ROOT=>PROBLEM%CONTROL_LOOP
                  CALL CONTROL_LOOP_GET(CONTROL_LOOP_ROOT,CONTROL_LOOP_NODE,CONTROL_LOOP,ERR,ERROR,*999)
                  !Get the solver equations
                  CALL CONTROL_LOOP_SOLVERS_GET(CONTROL_LOOP,SOLVERS,ERR,ERROR,*999)
                  CALL SOLVERS_SOLVER_GET(SOLVERS,1,SOLVER,ERR,ERROR,*999)
                  CALL SOLVER_SOLVER_EQUATIONS_GET(SOLVER,SOLVER_EQUATIONS,ERR,ERROR,*999)
                  !Finish the solver equations creation
                  CALL SOLVER_EQUATIONS_CREATE_FINISH(SOLVER_EQUATIONS,ERR,ERROR,*999)
                CASE DEFAULT
                  LOCAL_ERROR="The action type of "//TRIM(NUMBER_TO_VSTRING(PROBLEM_SETUP%ACTION_TYPE,"*",ERR,ERROR))// &
                    & " for a setup type of "//TRIM(NUMBER_TO_VSTRING(PROBLEM_SETUP%SETUP_TYPE,"*",ERR,ERROR))// &
                    & " is invalid for a Navier-Stokes fluid."
                  CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
              END SELECT
            CASE(PROBLEM_SETUP_CELLML_EQUATIONS_TYPE)
              SELECT CASE(PROBLEM_SETUP%ACTION_TYPE)
              CASE(PROBLEM_SETUP_START_ACTION)
                !Get the control loop
                CONTROL_LOOP_ROOT=>PROBLEM%CONTROL_LOOP
                CALL CONTROL_LOOP_GET(CONTROL_LOOP_ROOT,CONTROL_LOOP_NODE,CONTROL_LOOP,ERR,ERROR,*999)
                !Get the solver
                CALL CONTROL_LOOP_SOLVERS_GET(CONTROL_LOOP,SOLVERS,ERR,ERROR,*999)
                CALL SOLVERS_SOLVER_GET(SOLVERS,1,SOLVER,ERR,ERROR,*999)
                !Get the CellML evaluator solver
                CALL SOLVER_NEWTON_CELLML_SOLVER_GET(SOLVER,cellmlSolver,ERR,ERROR,*999)
                !Create the CellML equations
                CALL CELLML_EQUATIONS_CREATE_START(cellmlSolver,CELLML_EQUATIONS, &
                  & ERR,ERROR,*999)
              CASE(PROBLEM_SETUP_FINISH_ACTION)
                !Get the control loop
                CONTROL_LOOP_ROOT=>PROBLEM%CONTROL_LOOP
                CALL CONTROL_LOOP_GET(CONTROL_LOOP_ROOT,CONTROL_LOOP_NODE,CONTROL_LOOP,ERR,ERROR,*999)
                !Get the solver
                CALL CONTROL_LOOP_SOLVERS_GET(CONTROL_LOOP,SOLVERS,ERR,ERROR,*999)
                CALL SOLVERS_SOLVER_GET(SOLVERS,1,SOLVER,ERR,ERROR,*999)
                !Get the CellML evaluator solver
                CALL SOLVER_NEWTON_CELLML_SOLVER_GET(SOLVER,cellmlSolver,ERR,ERROR,*999)
                !Get the CellML equations for the CellML evaluator solver
                CALL SOLVER_CELLML_EQUATIONS_GET(cellmlSolver,CELLML_EQUATIONS,ERR,ERROR,*999)
                !Finish the CellML equations creation
                CALL CELLML_EQUATIONS_CREATE_FINISH(CELLML_EQUATIONS,ERR,ERROR,*999)
              CASE DEFAULT
                LOCAL_ERROR="The action type of "//TRIM(NUMBER_TO_VSTRING(PROBLEM_SETUP%ACTION_TYPE,"*",ERR,ERROR))// &
                  & " for a setup type of "//TRIM(NUMBER_TO_VSTRING(PROBLEM_SETUP%SETUP_TYPE,"*",ERR,ERROR))// &
                  & " is invalid for a CellML setup for a  transient Navier-Stokes equation."
                CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
              END SELECT
            CASE DEFAULT
              LOCAL_ERROR="The setup type of "//TRIM(NUMBER_TO_VSTRING(PROBLEM_SETUP%SETUP_TYPE,"*",ERR,ERROR))// &
                & " is invalid for a transient Navier-Stokes fluid."
              CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
          END SELECT
        CASE(PROBLEM_TRANSIENT1D_NAVIER_STOKES_SUBTYPE, &    !1D Navier-Stokes
           & PROBLEM_COUPLED1D0D_NAVIER_STOKES_SUBTYPE, &    !  with coupled 0D boundaries
           & PROBLEM_TRANSIENT1D_ADV_NAVIER_STOKES_SUBTYPE, & !  with coupled advection
           & PROBLEM_COUPLED1D0D_ADV_NAVIER_STOKES_SUBTYPE, & !  with coupled 0D boundaries and advection
           & PROBLEM_STREE1D0D_NAVIER_STOKES_SUBTYPE, &      !  with stree
           & PROBLEM_STREE1D0D_ADV_NAVIER_STOKES_SUBTYPE)     !  with stree and advection

          SELECT CASE(PROBLEM_SETUP%SETUP_TYPE)
          CASE(PROBLEM_SETUP_INITIAL_TYPE)
            SELECT CASE(PROBLEM_SETUP%ACTION_TYPE)
            CASE(PROBLEM_SETUP_START_ACTION)
              !Do nothing
            CASE(PROBLEM_SETUP_FINISH_ACTION)
              !Do nothing
            CASE DEFAULT
              LOCAL_ERROR="The action type of "//TRIM(NUMBER_TO_VSTRING(PROBLEM_SETUP%ACTION_TYPE,"*",ERR,ERROR))// &
                & " for a setup type of "//TRIM(NUMBER_TO_VSTRING(PROBLEM_SETUP%SETUP_TYPE,"*",ERR,ERROR))// &
                & " is invalid for Coupled1dDaeNavierStokes equation."
              CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
            END SELECT
          CASE(PROBLEM_SETUP_CONTROL_TYPE)
            SELECT CASE(PROBLEM_SETUP%ACTION_TYPE)
            CASE(PROBLEM_SETUP_START_ACTION)
              NULLIFY(CONTROL_LOOP_ROOT)
              !Time Loop
              CALL CONTROL_LOOP_CREATE_START(PROBLEM,CONTROL_LOOP,ERR,ERROR,*999)
              CALL CONTROL_LOOP_TYPE_SET(CONTROL_LOOP,PROBLEM_CONTROL_TIME_LOOP_TYPE,ERR,ERROR,*999)
              NULLIFY(iterativeWhileLoop)
              IF(PROBLEM%specification(3) == PROBLEM_COUPLED1D0D_NAVIER_STOKES_SUBTYPE) THEN
                NULLIFY(iterativeWhileLoop)
                ! The 1D-0D boundary value iterative coupling loop
                CALL CONTROL_LOOP_NUMBER_OF_SUB_LOOPS_SET(CONTROL_LOOP,1,ERR,ERROR,*999)
                CALL CONTROL_LOOP_SUB_LOOP_GET(CONTROL_LOOP,1,iterativeWhileLoop,ERR,ERROR,*999)                
                CALL CONTROL_LOOP_TYPE_SET(iterativeWhileLoop,PROBLEM_CONTROL_WHILE_LOOP_TYPE,ERR,ERROR,*999)
                CALL CONTROL_LOOP_MAXIMUM_ITERATIONS_SET(iterativeWhileLoop,1000,ERR,ERROR,*999)
                CALL ControlLoop_AbsoluteToleranceSet(iterativeWhileLoop,0.1_DP,err,error,*999)
                CALL CONTROL_LOOP_LABEL_SET(iterativeWhileLoop,"1D-0D Iterative Coupling Convergence Loop",ERR,ERROR,*999)
                CALL CONTROL_LOOP_NUMBER_OF_SUB_LOOPS_SET(iterativeWhileLoop,2,ERR,ERROR,*999)
                NULLIFY(simpleLoop)
                ! The simple CellML solver loop
                CALL CONTROL_LOOP_SUB_LOOP_GET(iterativeWhileLoop,1,simpleLoop,ERR,ERROR,*999)                
                CALL CONTROL_LOOP_TYPE_SET(simpleLoop,PROBLEM_CONTROL_SIMPLE_TYPE,ERR,ERROR,*999)
                CALL CONTROL_LOOP_LABEL_SET(simpleLoop,"0D CellML solver Loop",ERR,ERROR,*999)
                NULLIFY(iterativeWhileLoop2)
                ! The Characteristics branch solver/ Navier-Stokes iterative coupling loop
                CALL CONTROL_LOOP_SUB_LOOP_GET(iterativeWhileLoop,2,iterativeWhileLoop2,ERR,ERROR,*999)                
                CALL CONTROL_LOOP_TYPE_SET(iterativeWhileLoop2,PROBLEM_CONTROL_WHILE_LOOP_TYPE,ERR,ERROR,*999)
                CALL CONTROL_LOOP_MAXIMUM_ITERATIONS_SET(iterativeWhileLoop2,1000,ERR,ERROR,*999)
                CALL ControlLoop_AbsoluteToleranceSet(iterativeWhileLoop2,1.0E6_DP,err,error,*999)
                CALL CONTROL_LOOP_LABEL_SET(iterativeWhileLoop2,"1D Characteristic/NSE branch value convergence Loop", &
                 & ERR,ERROR,*999)
              ELSE IF(PROBLEM%specification(3) == PROBLEM_COUPLED1D0D_ADV_NAVIER_STOKES_SUBTYPE) THEN
                NULLIFY(iterativeWhileLoop)
                ! The 1D-0D boundary value iterative coupling loop
                CALL CONTROL_LOOP_NUMBER_OF_SUB_LOOPS_SET(CONTROL_LOOP,2,ERR,ERROR,*999)
                CALL CONTROL_LOOP_SUB_LOOP_GET(CONTROL_LOOP,1,iterativeWhileLoop,ERR,ERROR,*999)                
                CALL CONTROL_LOOP_TYPE_SET(iterativeWhileLoop,PROBLEM_CONTROL_WHILE_LOOP_TYPE,ERR,ERROR,*999)
                CALL CONTROL_LOOP_MAXIMUM_ITERATIONS_SET(iterativeWhileLoop,1000,ERR,ERROR,*999)
                CALL ControlLoop_AbsoluteToleranceSet(iterativeWhileLoop,0.1_DP,err,error,*999)
                CALL CONTROL_LOOP_LABEL_SET(iterativeWhileLoop,"1D-0D Iterative Coupling Convergence Loop",ERR,ERROR,*999)
                CALL CONTROL_LOOP_NUMBER_OF_SUB_LOOPS_SET(iterativeWhileLoop,2,ERR,ERROR,*999)
                NULLIFY(simpleLoop)
                ! The simple CellML solver loop
                CALL CONTROL_LOOP_SUB_LOOP_GET(iterativeWhileLoop,1,simpleLoop,ERR,ERROR,*999)                
                CALL CONTROL_LOOP_TYPE_SET(simpleLoop,PROBLEM_CONTROL_SIMPLE_TYPE,ERR,ERROR,*999)
                CALL CONTROL_LOOP_LABEL_SET(simpleLoop,"0D CellML solver Loop",ERR,ERROR,*999)
                NULLIFY(iterativeWhileLoop2)
                ! The Characteristics branch solver/ Navier-Stokes iterative coupling loop
                CALL CONTROL_LOOP_SUB_LOOP_GET(iterativeWhileLoop,2,iterativeWhileLoop2,ERR,ERROR,*999)                
                CALL CONTROL_LOOP_TYPE_SET(iterativeWhileLoop2,PROBLEM_CONTROL_WHILE_LOOP_TYPE,ERR,ERROR,*999)
                CALL CONTROL_LOOP_MAXIMUM_ITERATIONS_SET(iterativeWhileLoop2,1000,ERR,ERROR,*999)
                CALL ControlLoop_AbsoluteToleranceSet(iterativeWhileLoop2,1.0E6_DP,err,error,*999)
                CALL CONTROL_LOOP_LABEL_SET(iterativeWhileLoop2,"1D Characteristic/NSE branch value convergence Loop", &
                 & ERR,ERROR,*999)
                NULLIFY(simpleLoop)
                ! The simple Advection solver loop
                CALL CONTROL_LOOP_SUB_LOOP_GET(CONTROL_LOOP,2,simpleLoop,ERR,ERROR,*999)                
                CALL CONTROL_LOOP_TYPE_SET(simpleLoop,PROBLEM_CONTROL_SIMPLE_TYPE,ERR,ERROR,*999)
                CALL CONTROL_LOOP_LABEL_SET(simpleLoop,"Advection",ERR,ERROR,*999)
              ELSE IF(PROBLEM%specification(3) == PROBLEM_TRANSIENT1D_NAVIER_STOKES_SUBTYPE) THEN
                NULLIFY(iterativeWhileLoop)
                ! The Characteristics branch solver/ Navier-Stokes iterative coupling loop
                CALL CONTROL_LOOP_NUMBER_OF_SUB_LOOPS_SET(CONTROL_LOOP,1,ERR,ERROR,*999)
                CALL CONTROL_LOOP_SUB_LOOP_GET(CONTROL_LOOP,1,iterativeWhileLoop,ERR,ERROR,*999)                
                CALL CONTROL_LOOP_TYPE_SET(iterativeWhileLoop,PROBLEM_CONTROL_WHILE_LOOP_TYPE,ERR,ERROR,*999)
                CALL CONTROL_LOOP_MAXIMUM_ITERATIONS_SET(iterativeWhileLoop,1000,ERR,ERROR,*999)
                CALL ControlLoop_AbsoluteToleranceSet(iterativeWhileLoop,1.0E3_DP,err,error,*999)
                CALL CONTROL_LOOP_LABEL_SET(iterativeWhileLoop,"1D Characteristic/NSE branch value convergence Loop",ERR,ERROR,*999)
              ELSE IF(PROBLEM%specification(3) == PROBLEM_TRANSIENT1D_ADV_NAVIER_STOKES_SUBTYPE) THEN
                NULLIFY(iterativeWhileLoop)
                ! The Characteristics branch solver/ Navier-Stokes iterative coupling loop
                CALL CONTROL_LOOP_NUMBER_OF_SUB_LOOPS_SET(CONTROL_LOOP,2,ERR,ERROR,*999)
                CALL CONTROL_LOOP_SUB_LOOP_GET(CONTROL_LOOP,1,iterativeWhileLoop,ERR,ERROR,*999)                
                CALL CONTROL_LOOP_TYPE_SET(iterativeWhileLoop,PROBLEM_CONTROL_WHILE_LOOP_TYPE,ERR,ERROR,*999)
                CALL CONTROL_LOOP_MAXIMUM_ITERATIONS_SET(iterativeWhileLoop,1000,ERR,ERROR,*999)
                CALL ControlLoop_AbsoluteToleranceSet(iterativeWhileLoop,1.0E6_DP,err,error,*999)
                CALL CONTROL_LOOP_LABEL_SET(iterativeWhileLoop,"1D Characteristic/NSE branch value convergence Loop",ERR,ERROR,*999)
                NULLIFY(simpleLoop)
                ! The simple Advection solver loop
                CALL CONTROL_LOOP_SUB_LOOP_GET(CONTROL_LOOP,2,simpleLoop,ERR,ERROR,*999)                
                CALL CONTROL_LOOP_TYPE_SET(simpleLoop,PROBLEM_CONTROL_SIMPLE_TYPE,ERR,ERROR,*999)
                CALL CONTROL_LOOP_LABEL_SET(simpleLoop,"Advection",ERR,ERROR,*999)
              ELSE IF(PROBLEM%specification(3) == PROBLEM_STREE1D0D_NAVIER_STOKES_SUBTYPE) THEN
                NULLIFY(iterativeWhileLoop)
                ! The 1D-0D boundary value iterative coupling loop
                CALL CONTROL_LOOP_NUMBER_OF_SUB_LOOPS_SET(CONTROL_LOOP,1,ERR,ERROR,*999)
                CALL CONTROL_LOOP_SUB_LOOP_GET(CONTROL_LOOP,1,iterativeWhileLoop,ERR,ERROR,*999)                
                CALL CONTROL_LOOP_TYPE_SET(iterativeWhileLoop,PROBLEM_CONTROL_WHILE_LOOP_TYPE,ERR,ERROR,*999)
                CALL CONTROL_LOOP_MAXIMUM_ITERATIONS_SET(iterativeWhileLoop,1000,ERR,ERROR,*999)
                CALL ControlLoop_AbsoluteToleranceSet(iterativeWhileLoop,0.1_DP,err,error,*999)
                CALL CONTROL_LOOP_LABEL_SET(iterativeWhileLoop,"1D-0D Iterative Coupling Convergence Loop",ERR,ERROR,*999)
                CALL CONTROL_LOOP_NUMBER_OF_SUB_LOOPS_SET(iterativeWhileLoop,2,ERR,ERROR,*999)
                NULLIFY(simpleLoop)
                ! The simple CellML solver loop
                CALL CONTROL_LOOP_SUB_LOOP_GET(iterativeWhileLoop,1,simpleLoop,ERR,ERROR,*999)                
                CALL CONTROL_LOOP_TYPE_SET(simpleLoop,PROBLEM_CONTROL_SIMPLE_TYPE,ERR,ERROR,*999)
                CALL CONTROL_LOOP_LABEL_SET(simpleLoop,"0D CellML solver Loop",ERR,ERROR,*999)
                NULLIFY(iterativeWhileLoop2)
                ! The Characteristics branch solver/ Navier-Stokes iterative coupling loop
                CALL CONTROL_LOOP_SUB_LOOP_GET(iterativeWhileLoop,2,iterativeWhileLoop2,ERR,ERROR,*999)                
                CALL CONTROL_LOOP_TYPE_SET(iterativeWhileLoop2,PROBLEM_CONTROL_WHILE_LOOP_TYPE,ERR,ERROR,*999)
                CALL CONTROL_LOOP_MAXIMUM_ITERATIONS_SET(iterativeWhileLoop2,1000,ERR,ERROR,*999)
                CALL ControlLoop_AbsoluteToleranceSet(iterativeWhileLoop2,1.0E6_DP,err,error,*999)
                CALL CONTROL_LOOP_LABEL_SET(iterativeWhileLoop2,"1D Characteristic/NSE branch value convergence Loop", &
                 & ERR,ERROR,*999)
              ELSE IF(PROBLEM%specification(3) == PROBLEM_STREE1D0D_ADV_NAVIER_STOKES_SUBTYPE) THEN
                NULLIFY(iterativeWhileLoop)
                ! The 1D-0D boundary value iterative coupling loop
                CALL CONTROL_LOOP_NUMBER_OF_SUB_LOOPS_SET(CONTROL_LOOP,2,ERR,ERROR,*999)
                CALL CONTROL_LOOP_SUB_LOOP_GET(CONTROL_LOOP,1,iterativeWhileLoop,ERR,ERROR,*999)                
                CALL CONTROL_LOOP_TYPE_SET(iterativeWhileLoop,PROBLEM_CONTROL_WHILE_LOOP_TYPE,ERR,ERROR,*999)
                CALL CONTROL_LOOP_MAXIMUM_ITERATIONS_SET(iterativeWhileLoop,1000,ERR,ERROR,*999)
                CALL ControlLoop_AbsoluteToleranceSet(iterativeWhileLoop,0.1_DP,err,error,*999)
                CALL CONTROL_LOOP_LABEL_SET(iterativeWhileLoop,"1D-0D Iterative Coupling Convergence Loop",ERR,ERROR,*999)
                CALL CONTROL_LOOP_NUMBER_OF_SUB_LOOPS_SET(iterativeWhileLoop,2,ERR,ERROR,*999)
                NULLIFY(simpleLoop)
                ! The simple CellML solver loop
                CALL CONTROL_LOOP_SUB_LOOP_GET(iterativeWhileLoop,1,simpleLoop,ERR,ERROR,*999)                
                CALL CONTROL_LOOP_TYPE_SET(simpleLoop,PROBLEM_CONTROL_SIMPLE_TYPE,ERR,ERROR,*999)
                CALL CONTROL_LOOP_LABEL_SET(simpleLoop,"0D CellML solver Loop",ERR,ERROR,*999)
                NULLIFY(iterativeWhileLoop2)
                ! The Characteristics branch solver/ Navier-Stokes iterative coupling loop
                CALL CONTROL_LOOP_SUB_LOOP_GET(iterativeWhileLoop,2,iterativeWhileLoop2,ERR,ERROR,*999)                
                CALL CONTROL_LOOP_TYPE_SET(iterativeWhileLoop2,PROBLEM_CONTROL_WHILE_LOOP_TYPE,ERR,ERROR,*999)
                CALL CONTROL_LOOP_MAXIMUM_ITERATIONS_SET(iterativeWhileLoop2,1000,ERR,ERROR,*999)
                CALL ControlLoop_AbsoluteToleranceSet(iterativeWhileLoop2,1.0E6_DP,err,error,*999)
                CALL CONTROL_LOOP_LABEL_SET(iterativeWhileLoop2,"1D Characteristic/NSE branch value convergence Loop", &
                 & ERR,ERROR,*999)
                NULLIFY(simpleLoop)
                ! The simple Advection solver loop
                CALL CONTROL_LOOP_SUB_LOOP_GET(CONTROL_LOOP,2,simpleLoop,ERR,ERROR,*999)                
                CALL CONTROL_LOOP_TYPE_SET(simpleLoop,PROBLEM_CONTROL_SIMPLE_TYPE,ERR,ERROR,*999)
                CALL CONTROL_LOOP_LABEL_SET(simpleLoop,"Advection",ERR,ERROR,*999)
              END IF
            CASE(PROBLEM_SETUP_FINISH_ACTION)
              CONTROL_LOOP_ROOT=>PROBLEM%CONTROL_LOOP
              CALL CONTROL_LOOP_GET(CONTROL_LOOP_ROOT,CONTROL_LOOP_NODE,CONTROL_LOOP,ERR,ERROR,*999)
              CALL CONTROL_LOOP_CREATE_FINISH(CONTROL_LOOP,ERR,ERROR,*999)
            CASE DEFAULT
              LOCAL_ERROR="The action type of "//TRIM(NUMBER_TO_VSTRING(PROBLEM_SETUP%ACTION_TYPE,"*",ERR,ERROR))// &
                & " for a setup type of "//TRIM(NUMBER_TO_VSTRING(PROBLEM_SETUP%SETUP_TYPE,"*",ERR,ERROR))// &
                & " is invalid for a 1d transient Navier-Stokes fluid."
              CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
            END SELECT
          !Create the solvers
          CASE(PROBLEM_SETUP_SOLVERS_TYPE)
            !Get the control loop
            CONTROL_LOOP_ROOT=>PROBLEM%CONTROL_LOOP
            NULLIFY(CONTROL_LOOP)
            CALL CONTROL_LOOP_GET(CONTROL_LOOP_ROOT,CONTROL_LOOP_NODE,CONTROL_LOOP,ERR,ERROR,*999)
            SELECT CASE(PROBLEM_SETUP%ACTION_TYPE)
            CASE(PROBLEM_SETUP_START_ACTION)
              SELECT CASE(PROBLEM%specification(3))
              CASE(PROBLEM_TRANSIENT1D_NAVIER_STOKES_SUBTYPE)
                ! Iterative loop couples N-S and characteristics, checking convergence of branch values
                ! (this subloop holds 2 solvers)
                NULLIFY(iterativeWhileLoop)
                CALL CONTROL_LOOP_SUB_LOOP_GET(CONTROL_LOOP,1,iterativeWhileLoop,ERR,ERROR,*999)
                CALL SOLVERS_CREATE_START(iterativeWhileLoop,solvers,ERR,ERROR,*999)
                CALL SOLVERS_NUMBER_SET(solvers,2,ERR,ERROR,*999)
                !!!-- C H A R A C T E R I S T I C --!!!
                NULLIFY(SOLVER)
                CALL SOLVERS_SOLVER_GET(SOLVERS,1,SOLVER,ERR,ERROR,*999)
                CALL SOLVER_TYPE_SET(SOLVER,SOLVER_NONLINEAR_TYPE,ERR,ERROR,*999)
                CALL SOLVER_LABEL_SET(solver,"Characteristic Solver",ERR,ERROR,*999)
                CALL SOLVER_LIBRARY_TYPE_SET(SOLVER,SOLVER_PETSC_LIBRARY,ERR,ERROR,*999)
                !!!-- N A V I E R   S T O K E S --!!!
                NULLIFY(SOLVER)
                CALL SOLVERS_SOLVER_GET(SOLVERS,2,SOLVER,ERR,ERROR,*999)
                CALL SOLVER_TYPE_SET(SOLVER,SOLVER_DYNAMIC_TYPE,ERR,ERROR,*999)
                CALL SOLVER_LABEL_SET(solver,"Navier-Stokes Solver",ERR,ERROR,*999)
                CALL SOLVER_DYNAMIC_LINEARITY_TYPE_SET(SOLVER,SOLVER_DYNAMIC_NONLINEAR,ERR,ERROR,*999)
                CALL SOLVER_DYNAMIC_ORDER_SET(SOLVER,SOLVER_DYNAMIC_FIRST_ORDER,ERR,ERROR,*999)
                CALL SOLVER_DYNAMIC_DEGREE_SET(SOLVER,SOLVER_DYNAMIC_FIRST_DEGREE,ERR,ERROR,*999)
                CALL SOLVER_LIBRARY_TYPE_SET(SOLVER,SOLVER_CMISS_LIBRARY,ERR,ERROR,*999)
              CASE(PROBLEM_TRANSIENT1D_ADV_NAVIER_STOKES_SUBTYPE)
                ! Iterative loop couples N-S and characteristics, checking convergence of branch values
                ! (this subloop holds 2 solvers)
                NULLIFY(iterativeWhileLoop)
                NULLIFY(solvers)
                CALL CONTROL_LOOP_SUB_LOOP_GET(CONTROL_LOOP,1,iterativeWhileLoop,ERR,ERROR,*999)
                CALL SOLVERS_CREATE_START(iterativeWhileLoop,solvers,ERR,ERROR,*999)
                CALL SOLVERS_NUMBER_SET(solvers,2,ERR,ERROR,*999)
                !!!-- C H A R A C T E R I S T I C --!!!
                NULLIFY(SOLVER)
                CALL SOLVERS_SOLVER_GET(SOLVERS,1,SOLVER,ERR,ERROR,*999)
                CALL SOLVER_TYPE_SET(SOLVER,SOLVER_NONLINEAR_TYPE,ERR,ERROR,*999)
                CALL SOLVER_LABEL_SET(solver,"Characteristic Solver",ERR,ERROR,*999)
                CALL SOLVER_LIBRARY_TYPE_SET(SOLVER,SOLVER_PETSC_LIBRARY,ERR,ERROR,*999)
                !!!-- N A V I E R   S T O K E S --!!!
                NULLIFY(SOLVER)
                CALL SOLVERS_SOLVER_GET(SOLVERS,2,SOLVER,ERR,ERROR,*999)
                CALL SOLVER_TYPE_SET(SOLVER,SOLVER_DYNAMIC_TYPE,ERR,ERROR,*999)
                CALL SOLVER_LABEL_SET(solver,"Navier-Stokes Solver",ERR,ERROR,*999)
                CALL SOLVER_DYNAMIC_LINEARITY_TYPE_SET(SOLVER,SOLVER_DYNAMIC_NONLINEAR,ERR,ERROR,*999)
                CALL SOLVER_DYNAMIC_ORDER_SET(SOLVER,SOLVER_DYNAMIC_FIRST_ORDER,ERR,ERROR,*999)
                CALL SOLVER_DYNAMIC_DEGREE_SET(SOLVER,SOLVER_DYNAMIC_FIRST_DEGREE,ERR,ERROR,*999)
                CALL SOLVER_LIBRARY_TYPE_SET(SOLVER,SOLVER_CMISS_LIBRARY,ERR,ERROR,*999)
                ! Simple loop 1 contains the Advection solver
                ! (this subloop holds 1 solver)
                NULLIFY(simpleLoop)
                NULLIFY(solvers)
                CALL CONTROL_LOOP_SUB_LOOP_GET(CONTROL_LOOP,2,simpleLoop,ERR,ERROR,*999)
                CALL SOLVERS_CREATE_START(simpleLoop,solvers,ERR,ERROR,*999)
                CALL SOLVERS_NUMBER_SET(solvers,1,ERR,ERROR,*999)
                !!!-- A D V E C T I O N --!!!
                NULLIFY(SOLVER)
                CALL SOLVERS_SOLVER_GET(SOLVERS,1,SOLVER,ERR,ERROR,*999)
                CALL SOLVER_TYPE_SET(SOLVER,SOLVER_DYNAMIC_TYPE,ERR,ERROR,*999)
                CALL SOLVER_LABEL_SET(solver,"Advection Solver",ERR,ERROR,*999)
                CALL SOLVER_DYNAMIC_LINEARITY_TYPE_SET(SOLVER,SOLVER_DYNAMIC_LINEAR,ERR,ERROR,*999)
                CALL SOLVER_DYNAMIC_ORDER_SET(SOLVER,SOLVER_DYNAMIC_FIRST_ORDER,ERR,ERROR,*999)
                CALL SOLVER_DYNAMIC_DEGREE_SET(SOLVER,SOLVER_DYNAMIC_FIRST_DEGREE,ERR,ERROR,*999)
                CALL SOLVER_LIBRARY_TYPE_SET(SOLVER,SOLVER_CMISS_LIBRARY,ERR,ERROR,*999)
              CASE(PROBLEM_COUPLED1D0D_ADV_NAVIER_STOKES_SUBTYPE)
                ! Iterative loop 1 couples 1D and 0D problems, checking convergence of boundary values
                ! (this subloop holds 2 subloops)
                NULLIFY(iterativeWhileLoop)
                CALL CONTROL_LOOP_SUB_LOOP_GET(CONTROL_LOOP,1,iterativeWhileLoop,ERR,ERROR,*999)

                ! Simple loop 1 contains the 0D/CellML DAE solver
                ! (this subloop holds 1 solver)
                NULLIFY(simpleLoop)
                NULLIFY(solvers)
                CALL CONTROL_LOOP_SUB_LOOP_GET(iterativeWhileLoop,1,simpleLoop,ERR,ERROR,*999)
                CALL SOLVERS_CREATE_START(simpleLoop,solvers,ERR,ERROR,*999)
                CALL SOLVERS_NUMBER_SET(solvers,1,ERR,ERROR,*999)
                !!!-- D A E --!!!
                NULLIFY(SOLVER)
                CALL SOLVERS_SOLVER_GET(solvers,1,solver,ERR,ERROR,*999)
                CALL SOLVER_TYPE_SET(solver,SOLVER_DAE_TYPE,ERR,ERROR,*999)
                CALL SOLVER_LABEL_SET(solver,"DAE Solver",ERR,ERROR,*999)

                ! Iterative loop 2 couples N-S and characteristics, checking convergence of branch values
                ! (this subloop holds 2 solvers)
                NULLIFY(iterativeWhileLoop2)
                NULLIFY(solvers)
                CALL CONTROL_LOOP_SUB_LOOP_GET(iterativeWhileLoop,2,iterativeWhileLoop2,ERR,ERROR,*999)
                CALL SOLVERS_CREATE_START(iterativeWhileLoop2,solvers,ERR,ERROR,*999)
                CALL SOLVERS_NUMBER_SET(solvers,2,ERR,ERROR,*999)
                !!!-- C H A R A C T E R I S T I C --!!!
                NULLIFY(SOLVER)
                CALL SOLVERS_SOLVER_GET(SOLVERS,1,SOLVER,ERR,ERROR,*999)
                CALL SOLVER_TYPE_SET(SOLVER,SOLVER_NONLINEAR_TYPE,ERR,ERROR,*999)
                CALL SOLVER_LABEL_SET(solver,"Characteristic Solver",ERR,ERROR,*999)
                CALL SOLVER_LIBRARY_TYPE_SET(SOLVER,SOLVER_PETSC_LIBRARY,ERR,ERROR,*999)
                !!!-- N A V I E R   S T O K E S --!!!
                NULLIFY(SOLVER)
                CALL SOLVERS_SOLVER_GET(SOLVERS,2,SOLVER,ERR,ERROR,*999)
                CALL SOLVER_TYPE_SET(SOLVER,SOLVER_DYNAMIC_TYPE,ERR,ERROR,*999)
                CALL SOLVER_LABEL_SET(solver,"Navier-Stokes Solver",ERR,ERROR,*999)
                CALL SOLVER_DYNAMIC_LINEARITY_TYPE_SET(SOLVER,SOLVER_DYNAMIC_NONLINEAR,ERR,ERROR,*999)
                CALL SOLVER_DYNAMIC_ORDER_SET(SOLVER,SOLVER_DYNAMIC_FIRST_ORDER,ERR,ERROR,*999)
                CALL SOLVER_DYNAMIC_DEGREE_SET(SOLVER,SOLVER_DYNAMIC_FIRST_DEGREE,ERR,ERROR,*999)
                CALL SOLVER_LIBRARY_TYPE_SET(SOLVER,SOLVER_CMISS_LIBRARY,ERR,ERROR,*999)

                ! Iterative loop 2 couples N-S and characteristics, checking convergence of branch values
                ! (this subloop holds 2 solvers)
                NULLIFY(simpleLoop)
                NULLIFY(solvers)
                CALL CONTROL_LOOP_SUB_LOOP_GET(CONTROL_LOOP,2,simpleLoop,ERR,ERROR,*999)
                CALL SOLVERS_CREATE_START(simpleLoop,solvers,ERR,ERROR,*999)
                CALL SOLVERS_NUMBER_SET(solvers,1,ERR,ERROR,*999)
                !!!-- A D V E C T I O N --!!!
                NULLIFY(SOLVER)
                CALL SOLVERS_SOLVER_GET(SOLVERS,1,SOLVER,ERR,ERROR,*999)
                CALL SOLVER_TYPE_SET(SOLVER,SOLVER_DYNAMIC_TYPE,ERR,ERROR,*999)
                CALL SOLVER_LABEL_SET(solver,"Advection Solver",ERR,ERROR,*999)
                CALL SOLVER_DYNAMIC_LINEARITY_TYPE_SET(SOLVER,SOLVER_DYNAMIC_LINEAR,ERR,ERROR,*999)
                CALL SOLVER_DYNAMIC_ORDER_SET(SOLVER,SOLVER_DYNAMIC_FIRST_ORDER,ERR,ERROR,*999)
                CALL SOLVER_DYNAMIC_DEGREE_SET(SOLVER,SOLVER_DYNAMIC_FIRST_DEGREE,ERR,ERROR,*999)
                CALL SOLVER_LIBRARY_TYPE_SET(SOLVER,SOLVER_CMISS_LIBRARY,ERR,ERROR,*999)
              CASE(PROBLEM_STREE1D0D_ADV_NAVIER_STOKES_SUBTYPE)
                ! Iterative loop 1 couples 1D and 0D problems, checking convergence of boundary values
                ! (this subloop holds 2 subloops)
                NULLIFY(iterativeWhileLoop)
                CALL CONTROL_LOOP_SUB_LOOP_GET(CONTROL_LOOP,1,iterativeWhileLoop,ERR,ERROR,*999)
                ! Simple loop 1 contains the 0D/CellML DAE solver
                ! (this subloop holds 1 solver)
                NULLIFY(simpleLoop)
                NULLIFY(solvers)
                CALL CONTROL_LOOP_SUB_LOOP_GET(iterativeWhileLoop,1,simpleLoop,ERR,ERROR,*999)
                CALL SOLVERS_CREATE_START(simpleLoop,solvers,ERR,ERROR,*999)
                CALL SOLVERS_NUMBER_SET(solvers,1,ERR,ERROR,*999)
                !!!-- D A E --!!!
                NULLIFY(SOLVER)
                CALL SOLVERS_SOLVER_GET(solvers,1,solver,ERR,ERROR,*999)
                CALL SOLVER_TYPE_SET(solver,SOLVER_NONLINEAR_TYPE,ERR,ERROR,*999)
                CALL SOLVER_LABEL_SET(solver,"Linear Solver",ERR,ERROR,*999)
                CALL SOLVER_LIBRARY_TYPE_SET(SOLVER,SOLVER_PETSC_LIBRARY,ERR,ERROR,*999)
                ! Iterative loop 2 couples N-S and characteristics, checking convergence of branch values
                ! (this subloop holds 2 solvers)
                NULLIFY(iterativeWhileLoop2)
                NULLIFY(solvers)
                CALL CONTROL_LOOP_SUB_LOOP_GET(iterativeWhileLoop,2,iterativeWhileLoop2,ERR,ERROR,*999)
                CALL SOLVERS_CREATE_START(iterativeWhileLoop2,solvers,ERR,ERROR,*999)
                CALL SOLVERS_NUMBER_SET(solvers,2,ERR,ERROR,*999)
                !!!-- C H A R A C T E R I S T I C --!!!
                NULLIFY(SOLVER)
                CALL SOLVERS_SOLVER_GET(SOLVERS,1,SOLVER,ERR,ERROR,*999)
                CALL SOLVER_TYPE_SET(SOLVER,SOLVER_NONLINEAR_TYPE,ERR,ERROR,*999)
                CALL SOLVER_LABEL_SET(solver,"Characteristic Solver",ERR,ERROR,*999)
                CALL SOLVER_LIBRARY_TYPE_SET(SOLVER,SOLVER_PETSC_LIBRARY,ERR,ERROR,*999)
                !!!-- N A V I E R   S T O K E S --!!!
                NULLIFY(SOLVER)
                CALL SOLVERS_SOLVER_GET(SOLVERS,2,SOLVER,ERR,ERROR,*999)
                CALL SOLVER_TYPE_SET(SOLVER,SOLVER_DYNAMIC_TYPE,ERR,ERROR,*999)
                CALL SOLVER_LABEL_SET(solver,"Navier-Stokes Solver",ERR,ERROR,*999)
                CALL SOLVER_DYNAMIC_LINEARITY_TYPE_SET(SOLVER,SOLVER_DYNAMIC_NONLINEAR,ERR,ERROR,*999)
                CALL SOLVER_DYNAMIC_ORDER_SET(SOLVER,SOLVER_DYNAMIC_FIRST_ORDER,ERR,ERROR,*999)
                CALL SOLVER_DYNAMIC_DEGREE_SET(SOLVER,SOLVER_DYNAMIC_FIRST_DEGREE,ERR,ERROR,*999)
                CALL SOLVER_LIBRARY_TYPE_SET(SOLVER,SOLVER_CMISS_LIBRARY,ERR,ERROR,*999)
                ! Iterative loop 2 couples N-S and characteristics, checking convergence of branch values
                ! (this subloop holds 2 solvers)
                NULLIFY(simpleLoop)
                NULLIFY(solvers)
                CALL CONTROL_LOOP_SUB_LOOP_GET(CONTROL_LOOP,2,simpleLoop,ERR,ERROR,*999)
                CALL SOLVERS_CREATE_START(simpleLoop,solvers,ERR,ERROR,*999)
                CALL SOLVERS_NUMBER_SET(solvers,1,ERR,ERROR,*999)
                !!!-- A D V E C T I O N --!!!
                NULLIFY(SOLVER)
                CALL SOLVERS_SOLVER_GET(SOLVERS,1,SOLVER,ERR,ERROR,*999)
                CALL SOLVER_TYPE_SET(SOLVER,SOLVER_DYNAMIC_TYPE,ERR,ERROR,*999)
                CALL SOLVER_LABEL_SET(solver,"Advection Solver",ERR,ERROR,*999)
                CALL SOLVER_DYNAMIC_LINEARITY_TYPE_SET(SOLVER,SOLVER_DYNAMIC_LINEAR,ERR,ERROR,*999)
                CALL SOLVER_DYNAMIC_ORDER_SET(SOLVER,SOLVER_DYNAMIC_FIRST_ORDER,ERR,ERROR,*999)
                CALL SOLVER_DYNAMIC_DEGREE_SET(SOLVER,SOLVER_DYNAMIC_FIRST_DEGREE,ERR,ERROR,*999)
                CALL SOLVER_LIBRARY_TYPE_SET(SOLVER,SOLVER_CMISS_LIBRARY,ERR,ERROR,*999)
              CASE(PROBLEM_COUPLED1D0D_NAVIER_STOKES_SUBTYPE)
                ! Iterative loop 1 couples 1D and 0D problems, checking convergence of boundary values
                ! (this subloop holds 2 subloops)
                NULLIFY(iterativeWhileLoop)
                CALL CONTROL_LOOP_SUB_LOOP_GET(CONTROL_LOOP,1,iterativeWhileLoop,ERR,ERROR,*999)

                ! Simple loop 1 contains the 0D/CellML DAE solver
                ! (this subloop holds 1 solver)
                NULLIFY(simpleLoop)
                NULLIFY(solvers)
                CALL CONTROL_LOOP_SUB_LOOP_GET(iterativeWhileLoop,1,simpleLoop,ERR,ERROR,*999)
                CALL SOLVERS_CREATE_START(simpleLoop,solvers,ERR,ERROR,*999)
                CALL SOLVERS_NUMBER_SET(solvers,1,ERR,ERROR,*999)
                !!!-- D A E --!!!
                NULLIFY(SOLVER)
                CALL SOLVERS_SOLVER_GET(solvers,1,solver,ERR,ERROR,*999)
                CALL SOLVER_TYPE_SET(solver,SOLVER_DAE_TYPE,ERR,ERROR,*999)
                CALL SOLVER_LABEL_SET(solver,"DAE Solver",ERR,ERROR,*999)

                ! Iterative loop 2 couples N-S and characteristics, checking convergence of branch values
                ! (this subloop holds 2 solvers)
                NULLIFY(iterativeWhileLoop2)
                NULLIFY(solvers)
                CALL CONTROL_LOOP_SUB_LOOP_GET(iterativeWhileLoop,2,iterativeWhileLoop2,ERR,ERROR,*999)
                CALL SOLVERS_CREATE_START(iterativeWhileLoop2,solvers,ERR,ERROR,*999)
                CALL SOLVERS_NUMBER_SET(solvers,2,ERR,ERROR,*999)
                !!!-- C H A R A C T E R I S T I C --!!!
                NULLIFY(SOLVER)
                CALL SOLVERS_SOLVER_GET(SOLVERS,1,SOLVER,ERR,ERROR,*999)
                CALL SOLVER_TYPE_SET(SOLVER,SOLVER_NONLINEAR_TYPE,ERR,ERROR,*999)
                CALL SOLVER_LABEL_SET(solver,"Characteristic Solver",ERR,ERROR,*999)
                CALL SOLVER_LIBRARY_TYPE_SET(SOLVER,SOLVER_PETSC_LIBRARY,ERR,ERROR,*999)
                !!!-- N A V I E R   S T O K E S --!!!
                NULLIFY(SOLVER)
                CALL SOLVERS_SOLVER_GET(SOLVERS,2,SOLVER,ERR,ERROR,*999)
                CALL SOLVER_TYPE_SET(SOLVER,SOLVER_DYNAMIC_TYPE,ERR,ERROR,*999)
                CALL SOLVER_LABEL_SET(solver,"Navier-Stokes Solver",ERR,ERROR,*999)
                CALL SOLVER_DYNAMIC_LINEARITY_TYPE_SET(SOLVER,SOLVER_DYNAMIC_NONLINEAR,ERR,ERROR,*999)
                CALL SOLVER_DYNAMIC_ORDER_SET(SOLVER,SOLVER_DYNAMIC_FIRST_ORDER,ERR,ERROR,*999)
                CALL SOLVER_DYNAMIC_DEGREE_SET(SOLVER,SOLVER_DYNAMIC_FIRST_DEGREE,ERR,ERROR,*999)
                CALL SOLVER_LIBRARY_TYPE_SET(SOLVER,SOLVER_CMISS_LIBRARY,ERR,ERROR,*999)
              CASE(PROBLEM_STREE1D0D_NAVIER_STOKES_SUBTYPE)
                ! Iterative loop 1 couples 1D and 0D problems, checking convergence of boundary values
                ! (this subloop holds 2 subloops)
                NULLIFY(iterativeWhileLoop)
                CALL CONTROL_LOOP_SUB_LOOP_GET(CONTROL_LOOP,1,iterativeWhileLoop,ERR,ERROR,*999)

                ! Simple loop 1 contains the 0D/CellML DAE solver
                ! (this subloop holds 1 solver)
                NULLIFY(simpleLoop)
                NULLIFY(solvers)
                CALL CONTROL_LOOP_SUB_LOOP_GET(iterativeWhileLoop,1,simpleLoop,ERR,ERROR,*999)
                CALL SOLVERS_CREATE_START(simpleLoop,solvers,ERR,ERROR,*999)
                CALL SOLVERS_NUMBER_SET(solvers,1,ERR,ERROR,*999)
                !!!-- D A E --!!!
                NULLIFY(SOLVER)
                CALL SOLVERS_SOLVER_GET(solvers,1,solver,ERR,ERROR,*999)
                CALL SOLVER_TYPE_SET(solver,SOLVER_LINEAR_TYPE,ERR,ERROR,*999)
                CALL SOLVER_LABEL_SET(solver,"Linear Solver",ERR,ERROR,*999)
                CALL SOLVER_LIBRARY_TYPE_SET(SOLVER,SOLVER_PETSC_LIBRARY,ERR,ERROR,*999)

                ! Iterative loop 2 couples N-S and characteristics, checking convergence of branch values
                ! (this subloop holds 2 solvers)
                NULLIFY(iterativeWhileLoop2)
                NULLIFY(solvers)
                CALL CONTROL_LOOP_SUB_LOOP_GET(iterativeWhileLoop,2,iterativeWhileLoop2,ERR,ERROR,*999)
                CALL SOLVERS_CREATE_START(iterativeWhileLoop2,solvers,ERR,ERROR,*999)
                CALL SOLVERS_NUMBER_SET(solvers,2,ERR,ERROR,*999)
                !!!-- C H A R A C T E R I S T I C --!!!
                NULLIFY(SOLVER)
                CALL SOLVERS_SOLVER_GET(SOLVERS,1,SOLVER,ERR,ERROR,*999)
                CALL SOLVER_TYPE_SET(SOLVER,SOLVER_NONLINEAR_TYPE,ERR,ERROR,*999)
                CALL SOLVER_LABEL_SET(solver,"Characteristic Solver",ERR,ERROR,*999)
                CALL SOLVER_LIBRARY_TYPE_SET(SOLVER,SOLVER_PETSC_LIBRARY,ERR,ERROR,*999)
                !!!-- N A V I E R   S T O K E S --!!!
                NULLIFY(SOLVER)
                CALL SOLVERS_SOLVER_GET(SOLVERS,2,SOLVER,ERR,ERROR,*999)
                CALL SOLVER_TYPE_SET(SOLVER,SOLVER_DYNAMIC_TYPE,ERR,ERROR,*999)
                CALL SOLVER_LABEL_SET(solver,"Navier-Stokes Solver",ERR,ERROR,*999)
                CALL SOLVER_DYNAMIC_LINEARITY_TYPE_SET(SOLVER,SOLVER_DYNAMIC_NONLINEAR,ERR,ERROR,*999)
                CALL SOLVER_DYNAMIC_ORDER_SET(SOLVER,SOLVER_DYNAMIC_FIRST_ORDER,ERR,ERROR,*999)
                CALL SOLVER_DYNAMIC_DEGREE_SET(SOLVER,SOLVER_DYNAMIC_FIRST_DEGREE,ERR,ERROR,*999)
                CALL SOLVER_LIBRARY_TYPE_SET(SOLVER,SOLVER_CMISS_LIBRARY,ERR,ERROR,*999)
              CASE DEFAULT
                LOCAL_ERROR="Problem subtype "//TRIM(NUMBER_TO_VSTRING(PROBLEM%specification(3),"*",ERR,ERROR))// &
                  & " is not valid for a Navier-Stokes equation type of a fluid mechanics problem class."
                CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
              END SELECT
            CASE(PROBLEM_SETUP_FINISH_ACTION)
              IF(PROBLEM%specification(3)==PROBLEM_COUPLED1D0D_NAVIER_STOKES_SUBTYPE) THEN
                NULLIFY(iterativeWhileLoop)
                CALL CONTROL_LOOP_SUB_LOOP_GET(CONTROL_LOOP,1,iterativeWhileLoop,ERR,ERROR,*999)
                NULLIFY(simpleLoop)
                NULLIFY(SOLVERS)
                CALL CONTROL_LOOP_SUB_LOOP_GET(iterativeWhileLoop,1,simpleLoop,ERR,ERROR,*999)
                CALL CONTROL_LOOP_SOLVERS_GET(simpleLoop,SOLVERS,ERR,ERROR,*999)
                CALL SOLVERS_CREATE_FINISH(SOLVERS,ERR,ERROR,*999)
                NULLIFY(iterativeWhileLoop2)
                NULLIFY(SOLVERS)
                CALL CONTROL_LOOP_SUB_LOOP_GET(iterativeWhileLoop,2,iterativeWhileLoop2,ERR,ERROR,*999)
                CALL CONTROL_LOOP_SOLVERS_GET(iterativeWhileLoop2,SOLVERS,ERR,ERROR,*999)
                CALL SOLVERS_CREATE_FINISH(SOLVERS,ERR,ERROR,*999)
              ELSE IF(PROBLEM%specification(3)==PROBLEM_STREE1D0D_NAVIER_STOKES_SUBTYPE) THEN
                NULLIFY(iterativeWhileLoop)
                CALL CONTROL_LOOP_SUB_LOOP_GET(CONTROL_LOOP,1,iterativeWhileLoop,ERR,ERROR,*999)
                NULLIFY(simpleLoop)
                NULLIFY(SOLVERS)
                CALL CONTROL_LOOP_SUB_LOOP_GET(iterativeWhileLoop,1,simpleLoop,ERR,ERROR,*999)
                CALL CONTROL_LOOP_SOLVERS_GET(simpleLoop,SOLVERS,ERR,ERROR,*999)
                CALL SOLVERS_CREATE_FINISH(SOLVERS,ERR,ERROR,*999)
                NULLIFY(iterativeWhileLoop2)
                NULLIFY(SOLVERS)
                CALL CONTROL_LOOP_SUB_LOOP_GET(iterativeWhileLoop,2,iterativeWhileLoop2,ERR,ERROR,*999)
                CALL CONTROL_LOOP_SOLVERS_GET(iterativeWhileLoop2,SOLVERS,ERR,ERROR,*999)
                CALL SOLVERS_CREATE_FINISH(SOLVERS,ERR,ERROR,*999)
              ELSE IF(PROBLEM%specification(3)==PROBLEM_TRANSIENT1D_NAVIER_STOKES_SUBTYPE) THEN
                NULLIFY(iterativeWhileLoop)
                NULLIFY(SOLVERS)
                CALL CONTROL_LOOP_SUB_LOOP_GET(CONTROL_LOOP,1,iterativeWhileLoop,ERR,ERROR,*999)
                CALL CONTROL_LOOP_SOLVERS_GET(iterativeWhileLoop,SOLVERS,ERR,ERROR,*999)
                CALL SOLVERS_CREATE_FINISH(SOLVERS,ERR,ERROR,*999)
              ELSE IF(PROBLEM%specification(3)==PROBLEM_TRANSIENT1D_ADV_NAVIER_STOKES_SUBTYPE) THEN
                NULLIFY(iterativeWhileLoop)
                NULLIFY(SOLVERS)
                CALL CONTROL_LOOP_SUB_LOOP_GET(CONTROL_LOOP,1,iterativeWhileLoop,ERR,ERROR,*999)
                CALL CONTROL_LOOP_SOLVERS_GET(iterativeWhileLoop,SOLVERS,ERR,ERROR,*999)
                CALL SOLVERS_CREATE_FINISH(SOLVERS,ERR,ERROR,*999)
                NULLIFY(simpleLoop)
                NULLIFY(SOLVERS)
                CALL CONTROL_LOOP_SUB_LOOP_GET(CONTROL_LOOP,2,simpleLoop,ERR,ERROR,*999)
                CALL CONTROL_LOOP_SOLVERS_GET(simpleLoop,SOLVERS,ERR,ERROR,*999)
                CALL SOLVERS_CREATE_FINISH(SOLVERS,ERR,ERROR,*999)
              ELSE IF(PROBLEM%specification(3)==PROBLEM_COUPLED1D0D_ADV_NAVIER_STOKES_SUBTYPE) THEN
                NULLIFY(iterativeWhileLoop)
                CALL CONTROL_LOOP_SUB_LOOP_GET(CONTROL_LOOP,1,iterativeWhileLoop,ERR,ERROR,*999)
                NULLIFY(simpleLoop)
                NULLIFY(SOLVERS)
                CALL CONTROL_LOOP_SUB_LOOP_GET(iterativeWhileLoop,1,simpleLoop,ERR,ERROR,*999)
                CALL CONTROL_LOOP_SOLVERS_GET(simpleLoop,SOLVERS,ERR,ERROR,*999)
                CALL SOLVERS_CREATE_FINISH(SOLVERS,ERR,ERROR,*999)
                NULLIFY(iterativeWhileLoop2)
                NULLIFY(SOLVERS)
                CALL CONTROL_LOOP_SUB_LOOP_GET(iterativeWhileLoop,2,iterativeWhileLoop2,ERR,ERROR,*999)
                CALL CONTROL_LOOP_SOLVERS_GET(iterativeWhileLoop2,SOLVERS,ERR,ERROR,*999)
                CALL SOLVERS_CREATE_FINISH(SOLVERS,ERR,ERROR,*999)
                NULLIFY(simpleLoop)
                NULLIFY(SOLVERS)
                CALL CONTROL_LOOP_SUB_LOOP_GET(CONTROL_LOOP,2,simpleLoop,ERR,ERROR,*999)
                CALL CONTROL_LOOP_SOLVERS_GET(simpleLoop,SOLVERS,ERR,ERROR,*999)
                CALL SOLVERS_CREATE_FINISH(SOLVERS,ERR,ERROR,*999)
              ELSE IF(PROBLEM%specification(3)==PROBLEM_STREE1D0D_ADV_NAVIER_STOKES_SUBTYPE) THEN
                NULLIFY(iterativeWhileLoop)
                CALL CONTROL_LOOP_SUB_LOOP_GET(CONTROL_LOOP,1,iterativeWhileLoop,ERR,ERROR,*999)
                NULLIFY(simpleLoop)
                NULLIFY(SOLVERS)
                CALL CONTROL_LOOP_SUB_LOOP_GET(iterativeWhileLoop,1,simpleLoop,ERR,ERROR,*999)
                CALL CONTROL_LOOP_SOLVERS_GET(simpleLoop,SOLVERS,ERR,ERROR,*999)
                CALL SOLVERS_CREATE_FINISH(SOLVERS,ERR,ERROR,*999)
                NULLIFY(iterativeWhileLoop2)
                NULLIFY(SOLVERS)
                CALL CONTROL_LOOP_SUB_LOOP_GET(iterativeWhileLoop,2,iterativeWhileLoop2,ERR,ERROR,*999)
                CALL CONTROL_LOOP_SOLVERS_GET(iterativeWhileLoop2,SOLVERS,ERR,ERROR,*999)
                CALL SOLVERS_CREATE_FINISH(SOLVERS,ERR,ERROR,*999)
                NULLIFY(simpleLoop)
                NULLIFY(SOLVERS)
                CALL CONTROL_LOOP_SUB_LOOP_GET(CONTROL_LOOP,2,simpleLoop,ERR,ERROR,*999)
                CALL CONTROL_LOOP_SOLVERS_GET(simpleLoop,SOLVERS,ERR,ERROR,*999)
                CALL SOLVERS_CREATE_FINISH(SOLVERS,ERR,ERROR,*999)
              END IF
            CASE DEFAULT
              LOCAL_ERROR="The action type of "//TRIM(NUMBER_TO_VSTRING(PROBLEM_SETUP%ACTION_TYPE,"*",ERR,ERROR))// &
                & " for a setup type of "//TRIM(NUMBER_TO_VSTRING(PROBLEM_SETUP%SETUP_TYPE,"*",ERR,ERROR))// &
                & " is invalid for a 1d transient Navier-Stokes fluid."
              CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
            END SELECT
          !Create the solver equations
          CASE(PROBLEM_SETUP_SOLVER_EQUATIONS_TYPE)
            SELECT CASE(PROBLEM_SETUP%ACTION_TYPE)
            CASE(PROBLEM_SETUP_START_ACTION)
              !Get the control loop
              CONTROL_LOOP_ROOT=>PROBLEM%CONTROL_LOOP
              NULLIFY(CONTROL_LOOP)
              CALL CONTROL_LOOP_GET(CONTROL_LOOP_ROOT,CONTROL_LOOP_NODE,CONTROL_LOOP,ERR,ERROR,*999)
              NULLIFY(SOLVER)
              NULLIFY(SOLVER_EQUATIONS)
              SELECT CASE(PROBLEM%specification(3))
              CASE(PROBLEM_TRANSIENT1D_NAVIER_STOKES_SUBTYPE)
                NULLIFY(iterativeWhileLoop)
                ! Iterative loop couples N-S and characteristics, checking convergence of branch values
                ! (this subloop holds 2 solvers)
                CALL CONTROL_LOOP_SUB_LOOP_GET(CONTROL_LOOP,1,iterativeWhileLoop,ERR,ERROR,*999)
                CALL CONTROL_LOOP_SOLVERS_GET(iterativeWhileLoop,SOLVERS,ERR,ERROR,*999)
                !!!-- C H A R A C T E R I S T I C --!!!
                CALL SOLVERS_SOLVER_GET(SOLVERS,1,SOLVER,ERR,ERROR,*999)
                CALL SOLVER_EQUATIONS_CREATE_START(SOLVER,SOLVER_EQUATIONS,ERR,ERROR,*999)
                CALL SOLVER_EQUATIONS_LINEARITY_TYPE_SET(SOLVER_EQUATIONS,SOLVER_EQUATIONS_NONLINEAR,ERR,ERROR,*999)
                CALL SOLVER_EQUATIONS_TIME_DEPENDENCE_TYPE_SET(SOLVER_EQUATIONS,SOLVER_EQUATIONS_STATIC,ERR,ERROR,*999)
                CALL SOLVER_EQUATIONS_SPARSITY_TYPE_SET(SOLVER_EQUATIONS,SOLVER_SPARSE_MATRICES,ERR,ERROR,*999)
                NULLIFY(SOLVER)
                NULLIFY(SOLVER_EQUATIONS)
                !!!-- N A V I E R   S T O K E S --!!!
                CALL SOLVERS_SOLVER_GET(SOLVERS,2,SOLVER,ERR,ERROR,*999)
                CALL SOLVER_EQUATIONS_CREATE_START(SOLVER,SOLVER_EQUATIONS,ERR,ERROR,*999)
                CALL SOLVER_EQUATIONS_LINEARITY_TYPE_SET(SOLVER_EQUATIONS,SOLVER_EQUATIONS_NONLINEAR,ERR,ERROR,*999)
                CALL SOLVER_EQUATIONS_TIME_DEPENDENCE_TYPE_SET(SOLVER_EQUATIONS,SOLVER_EQUATIONS_FIRST_ORDER_DYNAMIC,ERR,ERROR,*999)
                CALL SOLVER_EQUATIONS_SPARSITY_TYPE_SET(SOLVER_EQUATIONS,SOLVER_SPARSE_MATRICES,ERR,ERROR,*999)
              CASE(PROBLEM_TRANSIENT1D_ADV_NAVIER_STOKES_SUBTYPE)
                NULLIFY(iterativeWhileLoop)
                ! Iterative loop couples N-S and characteristics, checking convergence of branch values
                ! (this subloop holds 2 solvers)
                CALL CONTROL_LOOP_SUB_LOOP_GET(CONTROL_LOOP,1,iterativeWhileLoop,ERR,ERROR,*999)
                CALL CONTROL_LOOP_SOLVERS_GET(iterativeWhileLoop,SOLVERS,ERR,ERROR,*999)
                !!!-- C H A R A C T E R I S T I C --!!!
                CALL CONTROL_LOOP_SOLVERS_GET(CONTROL_LOOP,SOLVERS,ERR,ERROR,*999)
                CALL SOLVERS_SOLVER_GET(SOLVERS,1,SOLVER,ERR,ERROR,*999)
                CALL SOLVER_EQUATIONS_CREATE_START(SOLVER,SOLVER_EQUATIONS,ERR,ERROR,*999)
                CALL SOLVER_EQUATIONS_LINEARITY_TYPE_SET(SOLVER_EQUATIONS,SOLVER_EQUATIONS_NONLINEAR,ERR,ERROR,*999)
                CALL SOLVER_EQUATIONS_TIME_DEPENDENCE_TYPE_SET(SOLVER_EQUATIONS,SOLVER_EQUATIONS_STATIC,ERR,ERROR,*999)
                CALL SOLVER_EQUATIONS_SPARSITY_TYPE_SET(SOLVER_EQUATIONS,SOLVER_SPARSE_MATRICES,ERR,ERROR,*999)
                NULLIFY(SOLVER)
                NULLIFY(SOLVER_EQUATIONS)
                !!!-- N A V I E R   S T O K E S --!!!
                CALL SOLVERS_SOLVER_GET(SOLVERS,2,SOLVER,ERR,ERROR,*999)
                CALL SOLVER_EQUATIONS_CREATE_START(SOLVER,SOLVER_EQUATIONS,ERR,ERROR,*999)
                CALL SOLVER_EQUATIONS_LINEARITY_TYPE_SET(SOLVER_EQUATIONS,SOLVER_EQUATIONS_NONLINEAR,ERR,ERROR,*999)
                CALL SOLVER_EQUATIONS_TIME_DEPENDENCE_TYPE_SET(SOLVER_EQUATIONS,SOLVER_EQUATIONS_FIRST_ORDER_DYNAMIC,ERR,ERROR,*999)
                CALL SOLVER_EQUATIONS_SPARSITY_TYPE_SET(SOLVER_EQUATIONS,SOLVER_SPARSE_MATRICES,ERR,ERROR,*999)
                NULLIFY(SOLVER)
                NULLIFY(SOLVERS)
                NULLIFY(SOLVER_EQUATIONS)
                NULLIFY(simpleLoop)
                ! Iterative loop couples N-S and characteristics, checking convergence of branch values
                ! (this subloop holds 2 solvers)
                CALL CONTROL_LOOP_SUB_LOOP_GET(CONTROL_LOOP,2,simpleLoop,ERR,ERROR,*999)
                CALL CONTROL_LOOP_SOLVERS_GET(simpleLoop,SOLVERS,ERR,ERROR,*999)
                !!!-- A D V E C T I O N --!!!
                CALL SOLVERS_SOLVER_GET(SOLVERS,1,SOLVER,ERR,ERROR,*999)
                CALL SOLVER_EQUATIONS_CREATE_START(SOLVER,SOLVER_EQUATIONS,ERR,ERROR,*999)
                CALL SOLVER_EQUATIONS_LINEARITY_TYPE_SET(SOLVER_EQUATIONS,SOLVER_EQUATIONS_LINEAR,ERR,ERROR,*999)
                CALL SOLVER_EQUATIONS_TIME_DEPENDENCE_TYPE_SET(SOLVER_EQUATIONS,SOLVER_EQUATIONS_FIRST_ORDER_DYNAMIC,ERR,ERROR,*999)
                CALL SOLVER_EQUATIONS_SPARSITY_TYPE_SET(SOLVER_EQUATIONS,SOLVER_SPARSE_MATRICES,ERR,ERROR,*999)
              CASE(PROBLEM_COUPLED1D0D_ADV_NAVIER_STOKES_SUBTYPE)
                NULLIFY(iterativeWhileLoop)
                ! Iterative loop 1 couples 1D and 0D problems, checking convergence of boundary values
                ! (this subloop holds 2 subloops)
                CALL CONTROL_LOOP_SUB_LOOP_GET(CONTROL_LOOP,1,iterativeWhileLoop,ERR,ERROR,*999)
                NULLIFY(iterativeWhileLoop2)
                ! Iterative loop 2 couples N-S and characteristics, checking convergence of branch values
                ! (this subloop holds 2 solvers)
                CALL CONTROL_LOOP_SUB_LOOP_GET(iterativeWhileLoop,2,iterativeWhileLoop2,ERR,ERROR,*999)
                CALL CONTROL_LOOP_SOLVERS_GET(iterativeWhileLoop2,SOLVERS,ERR,ERROR,*999)
                !!!-- C H A R A C T E R I S T I C --!!!
                CALL SOLVERS_SOLVER_GET(SOLVERS,1,SOLVER,ERR,ERROR,*999)
                CALL SOLVER_EQUATIONS_CREATE_START(SOLVER,SOLVER_EQUATIONS,ERR,ERROR,*999)
                CALL SOLVER_EQUATIONS_LINEARITY_TYPE_SET(SOLVER_EQUATIONS,SOLVER_EQUATIONS_NONLINEAR,ERR,ERROR,*999)
                CALL SOLVER_EQUATIONS_TIME_DEPENDENCE_TYPE_SET(SOLVER_EQUATIONS,SOLVER_EQUATIONS_STATIC,ERR,ERROR,*999)
                CALL SOLVER_EQUATIONS_SPARSITY_TYPE_SET(SOLVER_EQUATIONS,SOLVER_SPARSE_MATRICES,ERR,ERROR,*999)
                NULLIFY(SOLVER)
                NULLIFY(SOLVER_EQUATIONS)
                !!!-- N A V I E R   S T O K E S --!!!
                CALL SOLVERS_SOLVER_GET(SOLVERS,2,SOLVER,ERR,ERROR,*999)
                CALL SOLVER_EQUATIONS_CREATE_START(SOLVER,SOLVER_EQUATIONS,ERR,ERROR,*999)
                CALL SOLVER_EQUATIONS_LINEARITY_TYPE_SET(SOLVER_EQUATIONS,SOLVER_EQUATIONS_NONLINEAR,ERR,ERROR,*999)
                CALL SOLVER_EQUATIONS_TIME_DEPENDENCE_TYPE_SET(SOLVER_EQUATIONS,SOLVER_EQUATIONS_FIRST_ORDER_DYNAMIC,ERR,ERROR,*999)
                CALL SOLVER_EQUATIONS_SPARSITY_TYPE_SET(SOLVER_EQUATIONS,SOLVER_SPARSE_MATRICES,ERR,ERROR,*999)
                NULLIFY(SOLVER)
                NULLIFY(SOLVERS)
                NULLIFY(SOLVER_EQUATIONS)
                NULLIFY(simpleLoop)
                ! Iterative loop couples N-S and characteristics, checking convergence of branch values
                ! (this subloop holds 2 solvers)
                CALL CONTROL_LOOP_SUB_LOOP_GET(CONTROL_LOOP,2,simpleLoop,ERR,ERROR,*999)
                CALL CONTROL_LOOP_SOLVERS_GET(simpleLoop,SOLVERS,ERR,ERROR,*999)
                !!!-- A D V E C T I O N --!!!
                CALL SOLVERS_SOLVER_GET(SOLVERS,1,SOLVER,ERR,ERROR,*999)
                CALL SOLVER_EQUATIONS_CREATE_START(SOLVER,SOLVER_EQUATIONS,ERR,ERROR,*999)
                CALL SOLVER_EQUATIONS_LINEARITY_TYPE_SET(SOLVER_EQUATIONS,SOLVER_EQUATIONS_LINEAR,ERR,ERROR,*999)
                CALL SOLVER_EQUATIONS_TIME_DEPENDENCE_TYPE_SET(SOLVER_EQUATIONS,SOLVER_EQUATIONS_FIRST_ORDER_DYNAMIC,ERR,ERROR,*999)
                CALL SOLVER_EQUATIONS_SPARSITY_TYPE_SET(SOLVER_EQUATIONS,SOLVER_SPARSE_MATRICES,ERR,ERROR,*999)
              CASE(PROBLEM_COUPLED1D0D_NAVIER_STOKES_SUBTYPE)
                NULLIFY(iterativeWhileLoop)
                ! Iterative loop 1 couples 1D and 0D problems, checking convergence of boundary values
                ! (this subloop holds 2 subloops)
                CALL CONTROL_LOOP_SUB_LOOP_GET(CONTROL_LOOP,1,iterativeWhileLoop,ERR,ERROR,*999)
                NULLIFY(iterativeWhileLoop2)
                ! Iterative loop 2 couples N-S and characteristics, checking convergence of branch values
                ! (this subloop holds 2 solvers)
                CALL CONTROL_LOOP_SUB_LOOP_GET(iterativeWhileLoop,2,iterativeWhileLoop2,ERR,ERROR,*999)
                CALL CONTROL_LOOP_SOLVERS_GET(iterativeWhileLoop2,SOLVERS,ERR,ERROR,*999)
                !!!-- C H A R A C T E R I S T I C --!!!
                CALL SOLVERS_SOLVER_GET(SOLVERS,1,SOLVER,ERR,ERROR,*999)
                CALL SOLVER_EQUATIONS_CREATE_START(SOLVER,SOLVER_EQUATIONS,ERR,ERROR,*999)
                CALL SOLVER_EQUATIONS_LINEARITY_TYPE_SET(SOLVER_EQUATIONS,SOLVER_EQUATIONS_NONLINEAR,ERR,ERROR,*999)
                CALL SOLVER_EQUATIONS_TIME_DEPENDENCE_TYPE_SET(SOLVER_EQUATIONS,SOLVER_EQUATIONS_STATIC,ERR,ERROR,*999)
                CALL SOLVER_EQUATIONS_SPARSITY_TYPE_SET(SOLVER_EQUATIONS,SOLVER_SPARSE_MATRICES,ERR,ERROR,*999)
                NULLIFY(SOLVER)
                NULLIFY(SOLVER_EQUATIONS)
                !!!-- N A V I E R   S T O K E S --!!!
                CALL SOLVERS_SOLVER_GET(SOLVERS,2,SOLVER,ERR,ERROR,*999)
                CALL SOLVER_EQUATIONS_CREATE_START(SOLVER,SOLVER_EQUATIONS,ERR,ERROR,*999)
                CALL SOLVER_EQUATIONS_LINEARITY_TYPE_SET(SOLVER_EQUATIONS,SOLVER_EQUATIONS_NONLINEAR,ERR,ERROR,*999)
                CALL SOLVER_EQUATIONS_TIME_DEPENDENCE_TYPE_SET(SOLVER_EQUATIONS,SOLVER_EQUATIONS_FIRST_ORDER_DYNAMIC,ERR,ERROR,*999)
                CALL SOLVER_EQUATIONS_SPARSITY_TYPE_SET(SOLVER_EQUATIONS,SOLVER_SPARSE_MATRICES,ERR,ERROR,*999)
              CASE(PROBLEM_STREE1D0D_ADV_NAVIER_STOKES_SUBTYPE)
                NULLIFY(iterativeWhileLoop)
                ! Iterative loop 1 couples 1D and 0D problems, checking convergence of boundary values
                ! (this subloop holds 2 subloops)
                CALL CONTROL_LOOP_SUB_LOOP_GET(CONTROL_LOOP,1,iterativeWhileLoop,ERR,ERROR,*999)
                NULLIFY(simpleLoop)
                CALL CONTROL_LOOP_SUB_LOOP_GET(iterativeWhileLoop,1,simpleLoop,ERR,ERROR,*999)
                CALL CONTROL_LOOP_SOLVERS_GET(simpleLoop,SOLVERS,ERR,ERROR,*999)
                NULLIFY(SOLVER)
                NULLIFY(SOLVER_EQUATIONS)
                !!!-- D A E --!!!
                CALL SOLVERS_SOLVER_GET(SOLVERS,1,SOLVER,ERR,ERROR,*999)
                CALL SOLVER_EQUATIONS_CREATE_START(SOLVER,SOLVER_EQUATIONS,ERR,ERROR,*999)
                CALL SOLVER_EQUATIONS_LINEARITY_TYPE_SET(SOLVER_EQUATIONS,SOLVER_EQUATIONS_LINEAR,ERR,ERROR,*999)
                CALL SOLVER_EQUATIONS_TIME_DEPENDENCE_TYPE_SET(SOLVER_EQUATIONS,SOLVER_EQUATIONS_STATIC,ERR,ERROR,*999)
                CALL SOLVER_EQUATIONS_SPARSITY_TYPE_SET(SOLVER_EQUATIONS,SOLVER_SPARSE_MATRICES,ERR,ERROR,*999)
                NULLIFY(SOLVER)
                NULLIFY(SOLVER_EQUATIONS)
                NULLIFY(iterativeWhileLoop2)
                ! Iterative loop 2 couples N-S and characteristics, checking convergence of branch values
                ! (this subloop holds 2 solvers)
                CALL CONTROL_LOOP_SUB_LOOP_GET(iterativeWhileLoop,2,iterativeWhileLoop2,ERR,ERROR,*999)
                CALL CONTROL_LOOP_SOLVERS_GET(iterativeWhileLoop2,SOLVERS,ERR,ERROR,*999)
                !!!-- C H A R A C T E R I S T I C --!!!
                CALL SOLVERS_SOLVER_GET(SOLVERS,1,SOLVER,ERR,ERROR,*999)
                CALL SOLVER_EQUATIONS_CREATE_START(SOLVER,SOLVER_EQUATIONS,ERR,ERROR,*999)
                CALL SOLVER_EQUATIONS_LINEARITY_TYPE_SET(SOLVER_EQUATIONS,SOLVER_EQUATIONS_NONLINEAR,ERR,ERROR,*999)
                CALL SOLVER_EQUATIONS_TIME_DEPENDENCE_TYPE_SET(SOLVER_EQUATIONS,SOLVER_EQUATIONS_STATIC,ERR,ERROR,*999)
                CALL SOLVER_EQUATIONS_SPARSITY_TYPE_SET(SOLVER_EQUATIONS,SOLVER_SPARSE_MATRICES,ERR,ERROR,*999)
                NULLIFY(SOLVER)
                NULLIFY(SOLVER_EQUATIONS)
                !!!-- N A V I E R   S T O K E S --!!!
                CALL SOLVERS_SOLVER_GET(SOLVERS,2,SOLVER,ERR,ERROR,*999)
                CALL SOLVER_EQUATIONS_CREATE_START(SOLVER,SOLVER_EQUATIONS,ERR,ERROR,*999)
                CALL SOLVER_EQUATIONS_LINEARITY_TYPE_SET(SOLVER_EQUATIONS,SOLVER_EQUATIONS_NONLINEAR,ERR,ERROR,*999)
                CALL SOLVER_EQUATIONS_TIME_DEPENDENCE_TYPE_SET(SOLVER_EQUATIONS,SOLVER_EQUATIONS_FIRST_ORDER_DYNAMIC,ERR,ERROR,*999)
                CALL SOLVER_EQUATIONS_SPARSITY_TYPE_SET(SOLVER_EQUATIONS,SOLVER_SPARSE_MATRICES,ERR,ERROR,*999)
                NULLIFY(SOLVER)
                NULLIFY(SOLVERS)
                NULLIFY(SOLVER_EQUATIONS)
                NULLIFY(simpleLoop)
                ! Iterative loop couples N-S and characteristics, checking convergence of branch values
                ! (this subloop holds 2 solvers)
                CALL CONTROL_LOOP_SUB_LOOP_GET(CONTROL_LOOP,2,simpleLoop,ERR,ERROR,*999)
                CALL CONTROL_LOOP_SOLVERS_GET(simpleLoop,SOLVERS,ERR,ERROR,*999)
                !!!-- A D V E C T I O N --!!!
                CALL SOLVERS_SOLVER_GET(SOLVERS,1,SOLVER,ERR,ERROR,*999)
                CALL SOLVER_EQUATIONS_CREATE_START(SOLVER,SOLVER_EQUATIONS,ERR,ERROR,*999)
                CALL SOLVER_EQUATIONS_LINEARITY_TYPE_SET(SOLVER_EQUATIONS,SOLVER_EQUATIONS_LINEAR,ERR,ERROR,*999)
                CALL SOLVER_EQUATIONS_TIME_DEPENDENCE_TYPE_SET(SOLVER_EQUATIONS,SOLVER_EQUATIONS_FIRST_ORDER_DYNAMIC,ERR,ERROR,*999)
                CALL SOLVER_EQUATIONS_SPARSITY_TYPE_SET(SOLVER_EQUATIONS,SOLVER_SPARSE_MATRICES,ERR,ERROR,*999)
              CASE(PROBLEM_STREE1D0D_NAVIER_STOKES_SUBTYPE)
                NULLIFY(iterativeWhileLoop)
                ! Iterative loop 1 couples 1D and 0D problems, checking convergence of boundary values
                ! (this subloop holds 2 subloops)
                CALL CONTROL_LOOP_SUB_LOOP_GET(CONTROL_LOOP,1,iterativeWhileLoop,ERR,ERROR,*999)
                NULLIFY(simpleLoop)
                CALL CONTROL_LOOP_SUB_LOOP_GET(iterativeWhileLoop,1,simpleLoop,ERR,ERROR,*999)
                CALL CONTROL_LOOP_SOLVERS_GET(simpleLoop,SOLVERS,ERR,ERROR,*999)
                NULLIFY(SOLVER)
                NULLIFY(SOLVER_EQUATIONS)
                !!!-- D A E --!!!
                CALL SOLVERS_SOLVER_GET(SOLVERS,1,SOLVER,ERR,ERROR,*999)
                CALL SOLVER_EQUATIONS_CREATE_START(SOLVER,SOLVER_EQUATIONS,ERR,ERROR,*999)
                CALL SOLVER_EQUATIONS_LINEARITY_TYPE_SET(SOLVER_EQUATIONS,SOLVER_EQUATIONS_LINEAR,ERR,ERROR,*999)
                CALL SOLVER_EQUATIONS_TIME_DEPENDENCE_TYPE_SET(SOLVER_EQUATIONS,SOLVER_EQUATIONS_STATIC,ERR,ERROR,*999)
                CALL SOLVER_EQUATIONS_SPARSITY_TYPE_SET(SOLVER_EQUATIONS,SOLVER_SPARSE_MATRICES,ERR,ERROR,*999)
                NULLIFY(SOLVER)
                NULLIFY(SOLVERS)
                NULLIFY(SOLVER_EQUATIONS)
                NULLIFY(iterativeWhileLoop2)
                ! Iterative loop 2 couples N-S and characteristics, checking convergence of branch values
                ! (this subloop holds 2 solvers)
                CALL CONTROL_LOOP_SUB_LOOP_GET(iterativeWhileLoop,2,iterativeWhileLoop2,ERR,ERROR,*999)
                CALL CONTROL_LOOP_SOLVERS_GET(iterativeWhileLoop2,SOLVERS,ERR,ERROR,*999)
                !!!-- C H A R A C T E R I S T I C --!!!
                CALL SOLVERS_SOLVER_GET(SOLVERS,1,SOLVER,ERR,ERROR,*999)
                CALL SOLVER_EQUATIONS_CREATE_START(SOLVER,SOLVER_EQUATIONS,ERR,ERROR,*999)
                CALL SOLVER_EQUATIONS_LINEARITY_TYPE_SET(SOLVER_EQUATIONS,SOLVER_EQUATIONS_NONLINEAR,ERR,ERROR,*999)
                CALL SOLVER_EQUATIONS_TIME_DEPENDENCE_TYPE_SET(SOLVER_EQUATIONS,SOLVER_EQUATIONS_STATIC,ERR,ERROR,*999)
                CALL SOLVER_EQUATIONS_SPARSITY_TYPE_SET(SOLVER_EQUATIONS,SOLVER_SPARSE_MATRICES,ERR,ERROR,*999)
                NULLIFY(SOLVER)
                NULLIFY(SOLVER_EQUATIONS)
                !!!-- N A V I E R   S T O K E S --!!!
                CALL SOLVERS_SOLVER_GET(SOLVERS,2,SOLVER,ERR,ERROR,*999)
                CALL SOLVER_EQUATIONS_CREATE_START(SOLVER,SOLVER_EQUATIONS,ERR,ERROR,*999)
                CALL SOLVER_EQUATIONS_LINEARITY_TYPE_SET(SOLVER_EQUATIONS,SOLVER_EQUATIONS_NONLINEAR,ERR,ERROR,*999)
                CALL SOLVER_EQUATIONS_TIME_DEPENDENCE_TYPE_SET(SOLVER_EQUATIONS,SOLVER_EQUATIONS_FIRST_ORDER_DYNAMIC,ERR,ERROR,*999)
                CALL SOLVER_EQUATIONS_SPARSITY_TYPE_SET(SOLVER_EQUATIONS,SOLVER_SPARSE_MATRICES,ERR,ERROR,*999)
              CASE DEFAULT
                LOCAL_ERROR="Problem subtype "//TRIM(NUMBER_TO_VSTRING(PROBLEM%specification(3),"*",ERR,ERROR))// &
                  & " is not valid for a Navier-Stokes equation type of a fluid mechanics problem class."
                CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
              END SELECT
            CASE(PROBLEM_SETUP_FINISH_ACTION)
              !Get the control loop
              CONTROL_LOOP_ROOT=>PROBLEM%CONTROL_LOOP
              NULLIFY(CONTROL_LOOP)
              CALL CONTROL_LOOP_GET(CONTROL_LOOP_ROOT,CONTROL_LOOP_NODE,CONTROL_LOOP,ERR,ERROR,*999)
              NULLIFY(SOLVER)
              NULLIFY(SOLVER_EQUATIONS)
              SELECT CASE(PROBLEM%specification(3))
              CASE(PROBLEM_TRANSIENT1D_NAVIER_STOKES_SUBTYPE)
                NULLIFY(iterativeWhileLoop)
                ! Iterative loop couples N-S and characteristics, checking convergence of branch values
                ! (this subloop holds 2 solvers)
                CALL CONTROL_LOOP_SUB_LOOP_GET(CONTROL_LOOP,1,iterativeWhileLoop,ERR,ERROR,*999)
                CALL CONTROL_LOOP_SOLVERS_GET(iterativeWhileLoop,SOLVERS,ERR,ERROR,*999)
                !!!-- C H A R A C T E R I S T I C --!!!
                CALL SOLVERS_SOLVER_GET(SOLVERS,1,SOLVER,ERR,ERROR,*999)
                CALL SOLVER_SOLVER_EQUATIONS_GET(SOLVER,SOLVER_EQUATIONS,ERR,ERROR,*999)
                CALL SOLVER_EQUATIONS_CREATE_FINISH(SOLVER_EQUATIONS,ERR,ERROR,*999)
                NULLIFY(SOLVER)
                NULLIFY(SOLVER_EQUATIONS)
                !!!-- N A V I E R   S T O K E S --!!!
                CALL SOLVERS_SOLVER_GET(SOLVERS,2,SOLVER,ERR,ERROR,*999)
                CALL SOLVER_SOLVER_EQUATIONS_GET(SOLVER,SOLVER_EQUATIONS,ERR,ERROR,*999)
                CALL SOLVER_EQUATIONS_CREATE_FINISH(SOLVER_EQUATIONS,ERR,ERROR,*999)
              CASE(PROBLEM_TRANSIENT1D_ADV_NAVIER_STOKES_SUBTYPE)
                NULLIFY(iterativeWhileLoop)
                ! Iterative loop couples N-S and characteristics, checking convergence of branch values
                ! (this subloop holds 2 solvers)
                CALL CONTROL_LOOP_SUB_LOOP_GET(CONTROL_LOOP,1,iterativeWhileLoop,ERR,ERROR,*999)
                CALL CONTROL_LOOP_SOLVERS_GET(iterativeWhileLoop,SOLVERS,ERR,ERROR,*999)
                !!!-- C H A R A C T E R I S T I C --!!!
                CALL SOLVERS_SOLVER_GET(SOLVERS,1,SOLVER,ERR,ERROR,*999)
                CALL SOLVER_SOLVER_EQUATIONS_GET(SOLVER,SOLVER_EQUATIONS,ERR,ERROR,*999)
                CALL SOLVER_EQUATIONS_CREATE_FINISH(SOLVER_EQUATIONS,ERR,ERROR,*999)
                NULLIFY(SOLVER)
                NULLIFY(SOLVER_EQUATIONS)
                !!!-- N A V I E R   S T O K E S --!!!
                CALL SOLVERS_SOLVER_GET(SOLVERS,2,SOLVER,ERR,ERROR,*999)
                CALL SOLVER_SOLVER_EQUATIONS_GET(SOLVER,SOLVER_EQUATIONS,ERR,ERROR,*999)
                CALL SOLVER_EQUATIONS_CREATE_FINISH(SOLVER_EQUATIONS,ERR,ERROR,*999)
                NULLIFY(SOLVERS)
                NULLIFY(SOLVER)
                NULLIFY(SOLVER_EQUATIONS)
                NULLIFY(simpleLoop)
                ! Iterative loop couples N-S and characteristics, checking convergence of branch values
                ! (this subloop holds 2 solvers)
                CALL CONTROL_LOOP_SUB_LOOP_GET(CONTROL_LOOP,2,simpleLoop,ERR,ERROR,*999)
                CALL CONTROL_LOOP_SOLVERS_GET(simpleLoop,SOLVERS,ERR,ERROR,*999)
                !!!-- A D V E C T I O N --!!!
                CALL SOLVERS_SOLVER_GET(SOLVERS,1,SOLVER,ERR,ERROR,*999)
                CALL SOLVER_SOLVER_EQUATIONS_GET(SOLVER,SOLVER_EQUATIONS,ERR,ERROR,*999)
                CALL SOLVER_EQUATIONS_CREATE_FINISH(SOLVER_EQUATIONS,ERR,ERROR,*999)
              CASE(PROBLEM_COUPLED1D0D_ADV_NAVIER_STOKES_SUBTYPE)
                NULLIFY(iterativeWhileLoop)
                ! Iterative loop 1 couples 1D and 0D problems, checking convergence of boundary values
                ! (this subloop holds 2 subloops)
                CALL CONTROL_LOOP_SUB_LOOP_GET(CONTROL_LOOP,1,iterativeWhileLoop,ERR,ERROR,*999)
                NULLIFY(iterativeWhileLoop2)
                ! Iterative loop 2 couples N-S and characteristics, checking convergence of branch values
                ! (this subloop holds 2 solvers)
                CALL CONTROL_LOOP_SUB_LOOP_GET(iterativeWhileLoop,2,iterativeWhileLoop2,ERR,ERROR,*999)
                CALL CONTROL_LOOP_SOLVERS_GET(iterativeWhileLoop2,SOLVERS,ERR,ERROR,*999)
                !!!-- C H A R A C T E R I S T I C --!!!
                CALL SOLVERS_SOLVER_GET(SOLVERS,1,SOLVER,ERR,ERROR,*999)
                CALL SOLVER_SOLVER_EQUATIONS_GET(SOLVER,SOLVER_EQUATIONS,ERR,ERROR,*999)
                CALL SOLVER_EQUATIONS_CREATE_FINISH(SOLVER_EQUATIONS,ERR,ERROR,*999)
                NULLIFY(SOLVER)
                NULLIFY(SOLVER_EQUATIONS)
                !!!-- N A V I E R   S T O K E S --!!!
                CALL SOLVERS_SOLVER_GET(SOLVERS,2,SOLVER,ERR,ERROR,*999)
                CALL SOLVER_SOLVER_EQUATIONS_GET(SOLVER,SOLVER_EQUATIONS,ERR,ERROR,*999)
                CALL SOLVER_EQUATIONS_CREATE_FINISH(SOLVER_EQUATIONS,ERR,ERROR,*999)
                NULLIFY(SOLVERS)
                NULLIFY(SOLVER)
                NULLIFY(SOLVER_EQUATIONS)
                NULLIFY(simpleLoop)
                ! Iterative loop couples N-S and characteristics, checking convergence of branch values
                ! (this subloop holds 2 solvers)
                CALL CONTROL_LOOP_SUB_LOOP_GET(CONTROL_LOOP,2,simpleLoop,ERR,ERROR,*999)
                CALL CONTROL_LOOP_SOLVERS_GET(simpleLoop,SOLVERS,ERR,ERROR,*999)
                !!!-- A D V E C T I O N --!!!
                CALL SOLVERS_SOLVER_GET(SOLVERS,1,SOLVER,ERR,ERROR,*999)
                CALL SOLVER_SOLVER_EQUATIONS_GET(SOLVER,SOLVER_EQUATIONS,ERR,ERROR,*999)
                CALL SOLVER_EQUATIONS_CREATE_FINISH(SOLVER_EQUATIONS,ERR,ERROR,*999)
              CASE(PROBLEM_COUPLED1D0D_NAVIER_STOKES_SUBTYPE)
                NULLIFY(iterativeWhileLoop)
                ! Iterative loop 1 couples 1D and 0D problems, checking convergence of boundary values
                ! (this subloop holds 2 subloops)
                CALL CONTROL_LOOP_SUB_LOOP_GET(CONTROL_LOOP,1,iterativeWhileLoop,ERR,ERROR,*999)
                NULLIFY(iterativeWhileLoop2)
                ! Iterative loop 2 couples N-S and characteristics, checking convergence of branch values
                ! (this subloop holds 2 solvers)
                CALL CONTROL_LOOP_SUB_LOOP_GET(iterativeWhileLoop,2,iterativeWhileLoop2,ERR,ERROR,*999)
                CALL CONTROL_LOOP_SOLVERS_GET(iterativeWhileLoop2,SOLVERS,ERR,ERROR,*999)
                !!!-- C H A R A C T E R I S T I C --!!!
                CALL SOLVERS_SOLVER_GET(SOLVERS,1,SOLVER,ERR,ERROR,*999)
                CALL SOLVER_SOLVER_EQUATIONS_GET(SOLVER,SOLVER_EQUATIONS,ERR,ERROR,*999)
                CALL SOLVER_EQUATIONS_CREATE_FINISH(SOLVER_EQUATIONS,ERR,ERROR,*999)
                NULLIFY(SOLVER)
                NULLIFY(SOLVER_EQUATIONS)
                !!!-- N A V I E R   S T O K E S --!!!
                CALL SOLVERS_SOLVER_GET(SOLVERS,2,SOLVER,ERR,ERROR,*999)
                CALL SOLVER_SOLVER_EQUATIONS_GET(SOLVER,SOLVER_EQUATIONS,ERR,ERROR,*999)
                CALL SOLVER_EQUATIONS_CREATE_FINISH(SOLVER_EQUATIONS,ERR,ERROR,*999)
              CASE(PROBLEM_STREE1D0D_ADV_NAVIER_STOKES_SUBTYPE)
                NULLIFY(iterativeWhileLoop)
                ! Iterative loop 1 couples 1D and 0D problems, checking convergence of boundary values
                ! (this subloop holds 2 subloops)
                CALL CONTROL_LOOP_SUB_LOOP_GET(CONTROL_LOOP,1,iterativeWhileLoop,ERR,ERROR,*999)
                NULLIFY(simpleLoop)
                CALL CONTROL_LOOP_SUB_LOOP_GET(iterativeWhileLoop,1,simpleLoop,ERR,ERROR,*999)
                CALL CONTROL_LOOP_SOLVERS_GET(simpleLoop,SOLVERS,ERR,ERROR,*999)
                NULLIFY(SOLVER)
                NULLIFY(SOLVER_EQUATIONS)
                !!!-- D A E --!!!
                CALL SOLVERS_SOLVER_GET(SOLVERS,1,SOLVER,ERR,ERROR,*999)
                CALL SOLVER_SOLVER_EQUATIONS_GET(SOLVER,SOLVER_EQUATIONS,ERR,ERROR,*999)
                CALL SOLVER_EQUATIONS_CREATE_FINISH(SOLVER_EQUATIONS,ERR,ERROR,*999)
                NULLIFY(SOLVER)
                NULLIFY(SOLVER_EQUATIONS)
                NULLIFY(iterativeWhileLoop2)
                ! Iterative loop 2 couples N-S and characteristics, checking convergence of branch values
                ! (this subloop holds 2 solvers)
                CALL CONTROL_LOOP_SUB_LOOP_GET(iterativeWhileLoop,2,iterativeWhileLoop2,ERR,ERROR,*999)
                CALL CONTROL_LOOP_SOLVERS_GET(iterativeWhileLoop2,SOLVERS,ERR,ERROR,*999)
                !!!-- C H A R A C T E R I S T I C --!!!
                CALL SOLVERS_SOLVER_GET(SOLVERS,1,SOLVER,ERR,ERROR,*999)
                CALL SOLVER_SOLVER_EQUATIONS_GET(SOLVER,SOLVER_EQUATIONS,ERR,ERROR,*999)
                CALL SOLVER_EQUATIONS_CREATE_FINISH(SOLVER_EQUATIONS,ERR,ERROR,*999)
                NULLIFY(SOLVER)
                NULLIFY(SOLVER_EQUATIONS)
                !!!-- N A V I E R   S T O K E S --!!!
                CALL SOLVERS_SOLVER_GET(SOLVERS,2,SOLVER,ERR,ERROR,*999)
                CALL SOLVER_SOLVER_EQUATIONS_GET(SOLVER,SOLVER_EQUATIONS,ERR,ERROR,*999)
                CALL SOLVER_EQUATIONS_CREATE_FINISH(SOLVER_EQUATIONS,ERR,ERROR,*999)
                NULLIFY(SOLVERS)
                NULLIFY(SOLVER)
                NULLIFY(SOLVER_EQUATIONS)
                NULLIFY(simpleLoop)
                ! Iterative loop couples N-S and characteristics, checking convergence of branch values
                ! (this subloop holds 2 solvers)
                CALL CONTROL_LOOP_SUB_LOOP_GET(CONTROL_LOOP,2,simpleLoop,ERR,ERROR,*999)
                CALL CONTROL_LOOP_SOLVERS_GET(simpleLoop,SOLVERS,ERR,ERROR,*999)
                !!!-- A D V E C T I O N --!!!
                CALL SOLVERS_SOLVER_GET(SOLVERS,1,SOLVER,ERR,ERROR,*999)
                CALL SOLVER_SOLVER_EQUATIONS_GET(SOLVER,SOLVER_EQUATIONS,ERR,ERROR,*999)
                CALL SOLVER_EQUATIONS_CREATE_FINISH(SOLVER_EQUATIONS,ERR,ERROR,*999)
              CASE(PROBLEM_STREE1D0D_NAVIER_STOKES_SUBTYPE)
                NULLIFY(iterativeWhileLoop)
                ! Iterative loop 1 couples 1D and 0D problems, checking convergence of boundary values
                ! (this subloop holds 2 subloops)
                CALL CONTROL_LOOP_SUB_LOOP_GET(CONTROL_LOOP,1,iterativeWhileLoop,ERR,ERROR,*999)
                NULLIFY(simpleLoop)
                CALL CONTROL_LOOP_SUB_LOOP_GET(iterativeWhileLoop,1,simpleLoop,ERR,ERROR,*999)
                CALL CONTROL_LOOP_SOLVERS_GET(simpleLoop,SOLVERS,ERR,ERROR,*999)
                NULLIFY(SOLVER)
                NULLIFY(SOLVER_EQUATIONS)
                !!!-- D A E --!!!
                CALL SOLVERS_SOLVER_GET(SOLVERS,1,SOLVER,ERR,ERROR,*999)
                CALL SOLVER_SOLVER_EQUATIONS_GET(SOLVER,SOLVER_EQUATIONS,ERR,ERROR,*999)
                CALL SOLVER_EQUATIONS_CREATE_FINISH(SOLVER_EQUATIONS,ERR,ERROR,*999)
                NULLIFY(SOLVER)
                NULLIFY(SOLVERS)
                NULLIFY(SOLVER_EQUATIONS)
                NULLIFY(iterativeWhileLoop2)
                ! Iterative loop 2 couples N-S and characteristics, checking convergence of branch values
                ! (this subloop holds 2 solvers)
                CALL CONTROL_LOOP_SUB_LOOP_GET(iterativeWhileLoop,2,iterativeWhileLoop2,ERR,ERROR,*999)
                CALL CONTROL_LOOP_SOLVERS_GET(iterativeWhileLoop2,SOLVERS,ERR,ERROR,*999)
                !!!-- C H A R A C T E R I S T I C --!!!
                CALL SOLVERS_SOLVER_GET(SOLVERS,1,SOLVER,ERR,ERROR,*999)
                CALL SOLVER_SOLVER_EQUATIONS_GET(SOLVER,SOLVER_EQUATIONS,ERR,ERROR,*999)
                CALL SOLVER_EQUATIONS_CREATE_FINISH(SOLVER_EQUATIONS,ERR,ERROR,*999)
                NULLIFY(SOLVER)
                NULLIFY(SOLVER_EQUATIONS)
                !!!-- N A V I E R   S T O K E S --!!!
                CALL SOLVERS_SOLVER_GET(SOLVERS,2,SOLVER,ERR,ERROR,*999)
                CALL SOLVER_SOLVER_EQUATIONS_GET(SOLVER,SOLVER_EQUATIONS,ERR,ERROR,*999)
                CALL SOLVER_EQUATIONS_CREATE_FINISH(SOLVER_EQUATIONS,ERR,ERROR,*999)
              CASE DEFAULT
                LOCAL_ERROR="Problem subtype "//TRIM(NUMBER_TO_VSTRING(PROBLEM%specification(3),"*",ERR,ERROR))// &
                  & " is not valid for a Navier-Stokes equation type of a fluid mechanics problem class."
                CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
              END SELECT
            CASE DEFAULT
              LOCAL_ERROR="The action type of "//TRIM(NUMBER_TO_VSTRING(PROBLEM_SETUP%ACTION_TYPE,"*",ERR,ERROR))// &
                & " for a setup type of "//TRIM(NUMBER_TO_VSTRING(PROBLEM_SETUP%SETUP_TYPE,"*",ERR,ERROR))// &
                & " is invalid for a Navier-Stokes fluid."
              CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
            END SELECT
          !Create the CELLML solver equations
          CASE(PROBLEM_SETUP_CELLML_EQUATIONS_TYPE)
            SELECT CASE(PROBLEM_SETUP%ACTION_TYPE)
            CASE(PROBLEM_SETUP_START_ACTION)
              !Get the control loop
              CONTROL_LOOP_ROOT=>PROBLEM%CONTROL_LOOP              
              CALL CONTROL_LOOP_GET(CONTROL_LOOP_ROOT,CONTROL_LOOP_NODE,CONTROL_LOOP,ERR,ERROR,*999)
              IF(PROBLEM%specification(3) == PROBLEM_COUPLED1D0D_NAVIER_STOKES_SUBTYPE .OR. &
                & PROBLEM%specification(3) == PROBLEM_COUPLED1D0D_ADV_NAVIER_STOKES_SUBTYPE) THEN
                NULLIFY(iterativeWhileLoop)
                CALL CONTROL_LOOP_SUB_LOOP_GET(CONTROL_LOOP,1,iterativeWhileLoop,ERR,ERROR,*999)
                NULLIFY(simpleLoop)
                CALL CONTROL_LOOP_SUB_LOOP_GET(iterativeWhileLoop,1,simpleLoop,ERR,ERROR,*999)
                CALL CONTROL_LOOP_SOLVERS_GET(simpleLoop,SOLVERS,ERR,ERROR,*999)
              ELSE
                CALL CONTROL_LOOP_SOLVERS_GET(CONTROL_LOOP,SOLVERS,ERR,ERROR,*999)
              END IF
              NULLIFY(SOLVER)
              NULLIFY(cellMLSolver)
              NULLIFY(CELLML_EQUATIONS)
              SELECT CASE(PROBLEM%specification(3))
              CASE(PROBLEM_COUPLED1D0D_NAVIER_STOKES_SUBTYPE, &
                 & PROBLEM_COUPLED1D0D_ADV_NAVIER_STOKES_SUBTYPE)
                CALL SOLVERS_SOLVER_GET(SOLVERS,1,SOLVER,ERR,ERROR,*999)
                CALL CELLML_EQUATIONS_CREATE_START(solver,CELLML_EQUATIONS,ERR,ERROR,*999)
              CASE DEFAULT
                LOCAL_ERROR="Problem subtype "//TRIM(NUMBER_TO_VSTRING(PROBLEM%specification(3),"*",ERR,ERROR))// &
                  & " is not valid for cellML equations setup Navier-Stokes equation type of a fluid mechanics problem class."
                CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
              END SELECT
            CASE(PROBLEM_SETUP_FINISH_ACTION)
              !Get the control loop
              CONTROL_LOOP_ROOT=>PROBLEM%CONTROL_LOOP
              CALL CONTROL_LOOP_GET(CONTROL_LOOP_ROOT,CONTROL_LOOP_NODE,CONTROL_LOOP,ERR,ERROR,*999)
              IF(PROBLEM%specification(3) == PROBLEM_COUPLED1D0D_NAVIER_STOKES_SUBTYPE .OR. &
                & PROBLEM%specification(3) == PROBLEM_COUPLED1D0D_ADV_NAVIER_STOKES_SUBTYPE) THEN
                NULLIFY(iterativeWhileLoop)
                CALL CONTROL_LOOP_SUB_LOOP_GET(CONTROL_LOOP,1,iterativeWhileLoop,ERR,ERROR,*999)
                NULLIFY(simpleLoop)
                CALL CONTROL_LOOP_SUB_LOOP_GET(iterativeWhileLoop,1,simpleLoop,ERR,ERROR,*999)
                CALL CONTROL_LOOP_SOLVERS_GET(simpleLoop,SOLVERS,ERR,ERROR,*999)
              ELSE
                CALL CONTROL_LOOP_SOLVERS_GET(CONTROL_LOOP,SOLVERS,ERR,ERROR,*999)
              END IF
              NULLIFY(SOLVER)
              SELECT CASE(PROBLEM%specification(3))
              CASE(PROBLEM_COUPLED1D0D_NAVIER_STOKES_SUBTYPE, &
                 & PROBLEM_COUPLED1D0D_ADV_NAVIER_STOKES_SUBTYPE)
                CALL SOLVERS_SOLVER_GET(SOLVERS,1,SOLVER,ERR,ERROR,*999)
                CALL SOLVER_CELLML_EQUATIONS_GET(solver,CELLML_EQUATIONS,ERR,ERROR,*999)
                CALL CELLML_EQUATIONS_CREATE_FINISH(CELLML_EQUATIONS,ERR,ERROR,*999)
              CASE DEFAULT
                LOCAL_ERROR="The third problem specification of "// &
                  & TRIM(NUMBER_TO_VSTRING(PROBLEM%specification(3),"*",ERR,ERROR))// &
                  & " is not valid for cellML equations setup Navier-Stokes fluid mechanics problem."
                CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
              END SELECT
            CASE DEFAULT
              LOCAL_ERROR="The action type of "//TRIM(NUMBER_TO_VSTRING(PROBLEM_SETUP%ACTION_TYPE,"*",ERR,ERROR))// &
                & " for a setup type of "//TRIM(NUMBER_TO_VSTRING(PROBLEM_SETUP%SETUP_TYPE,"*",ERR,ERROR))// &
                & " is invalid for a CellML setup for a 1D Navier-Stokes equation."
              CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
            END SELECT
          CASE DEFAULT
            LOCAL_ERROR="The setup type of "//TRIM(NUMBER_TO_VSTRING(PROBLEM_SETUP%SETUP_TYPE,"*",ERR,ERROR))// &
              & " is invalid for a 1d transient Navier-Stokes fluid."
            CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
          END SELECT
        CASE(PROBLEM_QUASISTATIC_NAVIER_STOKES_SUBTYPE)
          !Quasi-static Navier-Stokes
          SELECT CASE(PROBLEM_SETUP%SETUP_TYPE)
            CASE(PROBLEM_SETUP_INITIAL_TYPE)
              SELECT CASE(PROBLEM_SETUP%ACTION_TYPE)
                CASE(PROBLEM_SETUP_START_ACTION)
                  !Do nothing????
                CASE(PROBLEM_SETUP_FINISH_ACTION)
                  !Do nothing???
                CASE DEFAULT
                  LOCAL_ERROR="The action type of "//TRIM(NUMBER_TO_VSTRING(PROBLEM_SETUP%ACTION_TYPE,"*",ERR,ERROR))// &
                    & " for a setup type of "//TRIM(NUMBER_TO_VSTRING(PROBLEM_SETUP%SETUP_TYPE,"*",ERR,ERROR))// &
                    & " is invalid for a quasistatic Navier-Stokes fluid."
                  CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
              END SELECT
            CASE(PROBLEM_SETUP_CONTROL_TYPE)
              SELECT CASE(PROBLEM_SETUP%ACTION_TYPE)
                CASE(PROBLEM_SETUP_START_ACTION)
                  !Set up a time control loop
                  CALL CONTROL_LOOP_CREATE_START(PROBLEM,CONTROL_LOOP,ERR,ERROR,*999)
                  CALL CONTROL_LOOP_TYPE_SET(CONTROL_LOOP,PROBLEM_CONTROL_TIME_LOOP_TYPE,ERR,ERROR,*999)
                CASE(PROBLEM_SETUP_FINISH_ACTION)
                  !Finish the control loops
                  CONTROL_LOOP_ROOT=>PROBLEM%CONTROL_LOOP
                  CALL CONTROL_LOOP_GET(CONTROL_LOOP_ROOT,CONTROL_LOOP_NODE,CONTROL_LOOP,ERR,ERROR,*999)
                  CALL CONTROL_LOOP_CREATE_FINISH(CONTROL_LOOP,ERR,ERROR,*999)
                CASE DEFAULT
                  LOCAL_ERROR="The action type of "//TRIM(NUMBER_TO_VSTRING(PROBLEM_SETUP%ACTION_TYPE,"*",ERR,ERROR))// &
                    & " for a setup type of "//TRIM(NUMBER_TO_VSTRING(PROBLEM_SETUP%SETUP_TYPE,"*",ERR,ERROR))// &
                    & " is invalid for a quasistatic Navier-Stokes fluid."
                  CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
              END SELECT
            CASE(PROBLEM_SETUP_SOLVERS_TYPE)
              !Get the control loop
              CONTROL_LOOP_ROOT=>PROBLEM%CONTROL_LOOP
              CALL CONTROL_LOOP_GET(CONTROL_LOOP_ROOT,CONTROL_LOOP_NODE,CONTROL_LOOP,ERR,ERROR,*999)
              SELECT CASE(PROBLEM_SETUP%ACTION_TYPE)
              CASE(PROBLEM_SETUP_START_ACTION)
                !Start the solvers creation
                CALL SOLVERS_CREATE_START(CONTROL_LOOP,SOLVERS,ERR,ERROR,*999)
                CALL SOLVERS_NUMBER_SET(SOLVERS,1,ERR,ERROR,*999)
                !Set the solver to be a nonlinear solver
                CALL SOLVERS_SOLVER_GET(SOLVERS,1,SOLVER,ERR,ERROR,*999)
                CALL SOLVER_TYPE_SET(SOLVER,SOLVER_NONLINEAR_TYPE,ERR,ERROR,*999)
                !Set solver defaults
                CALL SOLVER_LIBRARY_TYPE_SET(SOLVER,SOLVER_PETSC_LIBRARY,ERR,ERROR,*999)
              CASE(PROBLEM_SETUP_FINISH_ACTION)
                !Get the solvers
                CALL CONTROL_LOOP_SOLVERS_GET(CONTROL_LOOP,SOLVERS,ERR,ERROR,*999)
                !Finish the solvers creation
                CALL SOLVERS_CREATE_FINISH(SOLVERS,ERR,ERROR,*999)
              CASE DEFAULT
                LOCAL_ERROR="The action type of "//TRIM(NUMBER_TO_VSTRING(PROBLEM_SETUP%ACTION_TYPE,"*",ERR,ERROR))// &
                  & " for a setup type of "//TRIM(NUMBER_TO_VSTRING(PROBLEM_SETUP%SETUP_TYPE,"*",ERR,ERROR))// &
                  & " is invalid for a quasistatic Navier-Stokes equation."
                CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
              END SELECT
            CASE(PROBLEM_SETUP_SOLVER_EQUATIONS_TYPE)
              SELECT CASE(PROBLEM_SETUP%ACTION_TYPE)
                CASE(PROBLEM_SETUP_START_ACTION)
                  !Get the control loop
                  CONTROL_LOOP_ROOT=>PROBLEM%CONTROL_LOOP
                  CALL CONTROL_LOOP_GET(CONTROL_LOOP_ROOT,CONTROL_LOOP_NODE,CONTROL_LOOP,ERR,ERROR,*999)
                  !Get the solver
                  CALL CONTROL_LOOP_SOLVERS_GET(CONTROL_LOOP,SOLVERS,ERR,ERROR,*999)
                  CALL SOLVERS_SOLVER_GET(SOLVERS,1,SOLVER,ERR,ERROR,*999)
                  !Create the solver equations
                  CALL SOLVER_EQUATIONS_CREATE_START(SOLVER,SOLVER_EQUATIONS,ERR,ERROR,*999)
                  CALL SOLVER_EQUATIONS_LINEARITY_TYPE_SET(SOLVER_EQUATIONS,SOLVER_EQUATIONS_NONLINEAR,ERR,ERROR,*999)
                  CALL SOLVER_EQUATIONS_TIME_DEPENDENCE_TYPE_SET(SOLVER_EQUATIONS,SOLVER_EQUATIONS_QUASISTATIC,ERR,ERROR,*999)
                  CALL SOLVER_EQUATIONS_SPARSITY_TYPE_SET(SOLVER_EQUATIONS,SOLVER_SPARSE_MATRICES,ERR,ERROR,*999)
                CASE(PROBLEM_SETUP_FINISH_ACTION)
                  !Get the control loop
                  CONTROL_LOOP_ROOT=>PROBLEM%CONTROL_LOOP
                  CALL CONTROL_LOOP_GET(CONTROL_LOOP_ROOT,CONTROL_LOOP_NODE,CONTROL_LOOP,ERR,ERROR,*999)
                  !Get the solver equations
                  CALL CONTROL_LOOP_SOLVERS_GET(CONTROL_LOOP,SOLVERS,ERR,ERROR,*999)
                  CALL SOLVERS_SOLVER_GET(SOLVERS,1,SOLVER,ERR,ERROR,*999)
                  CALL SOLVER_SOLVER_EQUATIONS_GET(SOLVER,SOLVER_EQUATIONS,ERR,ERROR,*999)
                  !Finish the solver equations creation
                  CALL SOLVER_EQUATIONS_CREATE_FINISH(SOLVER_EQUATIONS,ERR,ERROR,*999)             
                CASE DEFAULT
                  LOCAL_ERROR="The action type of "//TRIM(NUMBER_TO_VSTRING(PROBLEM_SETUP%ACTION_TYPE,"*",ERR,ERROR))// &
                    & " for a setup type of "//TRIM(NUMBER_TO_VSTRING(PROBLEM_SETUP%SETUP_TYPE,"*",ERR,ERROR))// &
                    & " is invalid for a quasistatic Navier-Stokes equation."
                  CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
                END SELECT
            CASE DEFAULT
              LOCAL_ERROR="The setup type of "//TRIM(NUMBER_TO_VSTRING(PROBLEM_SETUP%SETUP_TYPE,"*",ERR,ERROR))// &
                & " is invalid for a quasistatic Navier-Stokes fluid."
              CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
          END SELECT
        !Navier-Stokes ALE cases
        CASE(PROBLEM_ALE_NAVIER_STOKES_SUBTYPE)
          SELECT CASE(PROBLEM_SETUP%SETUP_TYPE)
            CASE(PROBLEM_SETUP_INITIAL_TYPE)
              SELECT CASE(PROBLEM_SETUP%ACTION_TYPE)
                CASE(PROBLEM_SETUP_START_ACTION)
                  !Do nothing????
                CASE(PROBLEM_SETUP_FINISH_ACTION)
                  !Do nothing????
                CASE DEFAULT
                  LOCAL_ERROR="The action type of "//TRIM(NUMBER_TO_VSTRING(PROBLEM_SETUP%ACTION_TYPE,"*",ERR,ERROR))// &
                    & " for a setup type of "//TRIM(NUMBER_TO_VSTRING(PROBLEM_SETUP%SETUP_TYPE,"*",ERR,ERROR))// &
                    & " is invalid for a ALE Navier-Stokes fluid."
                  CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
              END SELECT
            CASE(PROBLEM_SETUP_CONTROL_TYPE)
              SELECT CASE(PROBLEM_SETUP%ACTION_TYPE)
                CASE(PROBLEM_SETUP_START_ACTION)
                  !Set up a time control loop
                  CALL CONTROL_LOOP_CREATE_START(PROBLEM,CONTROL_LOOP,ERR,ERROR,*999)
                  CALL CONTROL_LOOP_TYPE_SET(CONTROL_LOOP,PROBLEM_CONTROL_TIME_LOOP_TYPE,ERR,ERROR,*999)
                CASE(PROBLEM_SETUP_FINISH_ACTION)
                  !Finish the control loops
                  CONTROL_LOOP_ROOT=>PROBLEM%CONTROL_LOOP
                  CALL CONTROL_LOOP_GET(CONTROL_LOOP_ROOT,CONTROL_LOOP_NODE,CONTROL_LOOP,ERR,ERROR,*999)
                  CALL CONTROL_LOOP_CREATE_FINISH(CONTROL_LOOP,ERR,ERROR,*999)            
                CASE DEFAULT
                  LOCAL_ERROR="The action type of "//TRIM(NUMBER_TO_VSTRING(PROBLEM_SETUP%ACTION_TYPE,"*",ERR,ERROR))// &
                    & " for a setup type of "//TRIM(NUMBER_TO_VSTRING(PROBLEM_SETUP%SETUP_TYPE,"*",ERR,ERROR))// &
                    & " is invalid for a ALE Navier-Stokes fluid."
                  CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
              END SELECT
            CASE(PROBLEM_SETUP_SOLVERS_TYPE)
              !Get the control loop
              CONTROL_LOOP_ROOT=>PROBLEM%CONTROL_LOOP
              CALL CONTROL_LOOP_GET(CONTROL_LOOP_ROOT,CONTROL_LOOP_NODE,CONTROL_LOOP,ERR,ERROR,*999)
              SELECT CASE(PROBLEM_SETUP%ACTION_TYPE)
                CASE(PROBLEM_SETUP_START_ACTION)
                  !Start the solvers creation
                  CALL SOLVERS_CREATE_START(CONTROL_LOOP,SOLVERS,ERR,ERROR,*999)
                  CALL SOLVERS_NUMBER_SET(SOLVERS,2,ERR,ERROR,*999)
                  !Set the first solver to be a linear solver for the Laplace mesh movement problem
                  CALL SOLVERS_SOLVER_GET(SOLVERS,1,MESH_SOLVER,ERR,ERROR,*999)
                  CALL SOLVER_TYPE_SET(MESH_SOLVER,SOLVER_LINEAR_TYPE,ERR,ERROR,*999)
                  !Set solver defaults
                  CALL SOLVER_LIBRARY_TYPE_SET(MESH_SOLVER,SOLVER_PETSC_LIBRARY,ERR,ERROR,*999)
                  !Set the solver to be a first order dynamic solver 
                  CALL SOLVERS_SOLVER_GET(SOLVERS,2,SOLVER,ERR,ERROR,*999)
                  CALL SOLVER_TYPE_SET(SOLVER,SOLVER_DYNAMIC_TYPE,ERR,ERROR,*999)
                  CALL SOLVER_DYNAMIC_LINEARITY_TYPE_SET(SOLVER,SOLVER_DYNAMIC_NONLINEAR,ERR,ERROR,*999)
                  CALL SOLVER_DYNAMIC_ORDER_SET(SOLVER,SOLVER_DYNAMIC_FIRST_ORDER,ERR,ERROR,*999)
                  !Set solver defaults
                  CALL SOLVER_DYNAMIC_DEGREE_SET(SOLVER,SOLVER_DYNAMIC_FIRST_DEGREE,ERR,ERROR,*999)
                  CALL SOLVER_DYNAMIC_SCHEME_SET(SOLVER,SOLVER_DYNAMIC_CRANK_NICOLSON_SCHEME,ERR,ERROR,*999)
                  CALL SOLVER_LIBRARY_TYPE_SET(SOLVER,SOLVER_CMISS_LIBRARY,ERR,ERROR,*999)
                CASE(PROBLEM_SETUP_FINISH_ACTION)
                  !Get the solvers
                  CALL CONTROL_LOOP_SOLVERS_GET(CONTROL_LOOP,SOLVERS,ERR,ERROR,*999)
                  !Finish the solvers creation
                  CALL SOLVERS_CREATE_FINISH(SOLVERS,ERR,ERROR,*999)
                CASE DEFAULT
                  LOCAL_ERROR="The action type of "//TRIM(NUMBER_TO_VSTRING(PROBLEM_SETUP%ACTION_TYPE,"*",ERR,ERROR))// &
                    & " for a setup type of "//TRIM(NUMBER_TO_VSTRING(PROBLEM_SETUP%SETUP_TYPE,"*",ERR,ERROR))// &
                    & " is invalid for a ALE Navier-Stokes fluid."
                  CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
              END SELECT
            CASE(PROBLEM_SETUP_SOLVER_EQUATIONS_TYPE)
              SELECT CASE(PROBLEM_SETUP%ACTION_TYPE)
                CASE(PROBLEM_SETUP_START_ACTION)
                  !Get the control loop
                  CONTROL_LOOP_ROOT=>PROBLEM%CONTROL_LOOP
                  CALL CONTROL_LOOP_GET(CONTROL_LOOP_ROOT,CONTROL_LOOP_NODE,CONTROL_LOOP,ERR,ERROR,*999)
                  !Get the solver
                  CALL CONTROL_LOOP_SOLVERS_GET(CONTROL_LOOP,SOLVERS,ERR,ERROR,*999)
                  CALL SOLVERS_SOLVER_GET(SOLVERS,1,MESH_SOLVER,ERR,ERROR,*999)
                  !Create the solver equations
                  CALL SOLVER_EQUATIONS_CREATE_START(MESH_SOLVER,MESH_SOLVER_EQUATIONS,ERR,ERROR,*999)
                  CALL SOLVER_EQUATIONS_LINEARITY_TYPE_SET(MESH_SOLVER_EQUATIONS,SOLVER_EQUATIONS_LINEAR,ERR,ERROR,*999)
                  CALL SOLVER_EQUATIONS_TIME_DEPENDENCE_TYPE_SET(MESH_SOLVER_EQUATIONS,SOLVER_EQUATIONS_STATIC,ERR,ERROR,*999)
                  CALL SOLVER_EQUATIONS_SPARSITY_TYPE_SET(MESH_SOLVER_EQUATIONS,SOLVER_SPARSE_MATRICES,ERR,ERROR,*999)
                  CALL SOLVERS_SOLVER_GET(SOLVERS,2,SOLVER,ERR,ERROR,*999)
                  !Create the solver equations
                  CALL SOLVER_EQUATIONS_CREATE_START(SOLVER,SOLVER_EQUATIONS,ERR,ERROR,*999)
                  CALL SOLVER_EQUATIONS_LINEARITY_TYPE_SET(SOLVER_EQUATIONS,SOLVER_EQUATIONS_NONLINEAR,ERR,ERROR,*999)
                  CALL SOLVER_EQUATIONS_TIME_DEPENDENCE_TYPE_SET(SOLVER_EQUATIONS,SOLVER_EQUATIONS_FIRST_ORDER_DYNAMIC,&
                  & ERR,ERROR,*999)
                  CALL SOLVER_EQUATIONS_SPARSITY_TYPE_SET(SOLVER_EQUATIONS,SOLVER_SPARSE_MATRICES,ERR,ERROR,*999)
                CASE(PROBLEM_SETUP_FINISH_ACTION)
                  !Get the control loop
                  CONTROL_LOOP_ROOT=>PROBLEM%CONTROL_LOOP
                  CALL CONTROL_LOOP_GET(CONTROL_LOOP_ROOT,CONTROL_LOOP_NODE,CONTROL_LOOP,ERR,ERROR,*999)
                  !Get the solver equations
                  CALL CONTROL_LOOP_SOLVERS_GET(CONTROL_LOOP,SOLVERS,ERR,ERROR,*999)
                  CALL SOLVERS_SOLVER_GET(SOLVERS,1,MESH_SOLVER,ERR,ERROR,*999)
                  CALL SOLVER_SOLVER_EQUATIONS_GET(MESH_SOLVER,MESH_SOLVER_EQUATIONS,ERR,ERROR,*999)
                  !Finish the solver equations creation
                  CALL SOLVER_EQUATIONS_CREATE_FINISH(MESH_SOLVER_EQUATIONS,ERR,ERROR,*999)             
                  !Get the solver equations
                  CALL SOLVERS_SOLVER_GET(SOLVERS,2,SOLVER,ERR,ERROR,*999)
                  CALL SOLVER_SOLVER_EQUATIONS_GET(SOLVER,SOLVER_EQUATIONS,ERR,ERROR,*999)
                  !Finish the solver equations creation
                  CALL SOLVER_EQUATIONS_CREATE_FINISH(SOLVER_EQUATIONS,ERR,ERROR,*999)             
                CASE DEFAULT
                  LOCAL_ERROR="The action type of "//TRIM(NUMBER_TO_VSTRING(PROBLEM_SETUP%ACTION_TYPE,"*",ERR,ERROR))// &
                    & " for a setup type of "//TRIM(NUMBER_TO_VSTRING(PROBLEM_SETUP%SETUP_TYPE,"*",ERR,ERROR))// &
                    & " is invalid for a Navier-Stokes fluid."
                  CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
              END SELECT
            CASE DEFAULT
              LOCAL_ERROR="The setup type of "//TRIM(NUMBER_TO_VSTRING(PROBLEM_SETUP%SETUP_TYPE,"*",ERR,ERROR))// &
                & " is invalid for a ALE Navier-Stokes fluid."
              CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
          END SELECT
        CASE DEFAULT
          LOCAL_ERROR="The third problem specification of "//TRIM(NUMBER_TO_VSTRING(PROBLEM%specification(3),"*",ERR,ERROR))// &
            & " is not valid for a Navier-Stokes fluid mechanics problem."
          CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
        END SELECT
    ELSE
      CALL FlagError("Problem is not associated.",ERR,ERROR,*999)
    END IF

    EXITS("NAVIER_STOKES_PROBLEM_SETUP")
    RETURN
999 ERRORSEXITS("NAVIER_STOKES_PROBLEM_SETUP",ERR,ERROR)
    RETURN 1
    
  END SUBROUTINE NAVIER_STOKES_PROBLEM_SETUP

  !
  !================================================================================================================================
  !

  !>Evaluates the residual element stiffness matrices and RHS for a Navier-Stokes equation finite element equations set.
  SUBROUTINE NavierStokes_FiniteElementResidualEvaluate(EQUATIONS_SET,ELEMENT_NUMBER,ERR,ERROR,*)

    !Argument variables
    TYPE(EQUATIONS_SET_TYPE), POINTER :: EQUATIONS_SET !<A pointer to the equations set to perform the finite element calculations on
    INTEGER(INTG), INTENT(IN) :: ELEMENT_NUMBER !<The element number to calculate
    INTEGER(INTG), INTENT(OUT) :: ERR !<The error code
    TYPE(VARYING_STRING), INTENT(OUT) :: ERROR !<The error string
    !Local Variables
    TYPE(BASIS_TYPE), POINTER :: DEPENDENT_BASIS,DEPENDENT_BASIS1,DEPENDENT_BASIS2,GEOMETRIC_BASIS,INDEPENDENT_BASIS
    TYPE(DECOMPOSITION_TYPE), POINTER :: DECOMPOSITION
    TYPE(DOMAIN_ELEMENTS_TYPE), POINTER :: ELEMENTS_TOPOLOGY
    TYPE(EQUATIONS_TYPE), POINTER :: EQUATIONS
    TYPE(EQUATIONS_MAPPING_TYPE), POINTER :: EQUATIONS_MAPPING
    TYPE(EQUATIONS_MAPPING_LINEAR_TYPE), POINTER :: LINEAR_MAPPING
    TYPE(EQUATIONS_MAPPING_DYNAMIC_TYPE), POINTER :: DYNAMIC_MAPPING
    TYPE(EQUATIONS_MAPPING_NONLINEAR_TYPE), POINTER :: NONLINEAR_MAPPING
    TYPE(EQUATIONS_MATRICES_TYPE), POINTER :: EQUATIONS_MATRICES
    TYPE(EQUATIONS_MATRICES_LINEAR_TYPE), POINTER :: LINEAR_MATRICES
    TYPE(EQUATIONS_MATRICES_DYNAMIC_TYPE), POINTER :: DYNAMIC_MATRICES
    TYPE(EQUATIONS_MATRICES_NONLINEAR_TYPE), POINTER :: NONLINEAR_MATRICES
    TYPE(EQUATIONS_MATRICES_RHS_TYPE), POINTER :: RHS_VECTOR
    TYPE(EQUATIONS_MATRIX_TYPE), POINTER :: STIFFNESS_MATRIX,DAMPING_MATRIX
    TYPE(FIELD_TYPE), POINTER :: DEPENDENT_FIELD,GEOMETRIC_FIELD,MATERIALS_FIELD,INDEPENDENT_FIELD
    TYPE(FIELD_VARIABLE_TYPE), POINTER :: FIELD_VARIABLE
    TYPE(QUADRATURE_SCHEME_TYPE), POINTER :: QUADRATURE_SCHEME,QUADRATURE_SCHEME1,QUADRATURE_SCHEME2
    INTEGER(INTG) :: ng,mh,mhs,mi,ms,nh,nhs,ni,ns,nhs_max,mhs_max,nhs_min,mhs_min,xv,out
    INTEGER(INTG) :: FIELD_VAR_TYPE,MESH_COMPONENT1,MESH_COMPONENT2,MESH_COMPONENT_NUMBER
    INTEGER(INTG) :: nodeIdx,xiIdx,coordIdx,derivativeIdx,versionIdx,elementVersionNumber,componentIdx
    INTEGER(INTG) :: numberOfVersions,nodeNumber,numberOfElementNodes,numberOfParameters,firstNode,lastNode
    REAL(DP) :: JGW,SUM,X(3),DXI_DX(3,3),DPHIMS_DXI(3),DPHINS_DXI(3),PHIMS,PHINS,momentum,mass,QUpwind,AUpwind,pExternal
    REAL(DP) :: U_VALUE(3),W_VALUE(3),U_DERIV(3,3),Q_VALUE,A_VALUE,Q_DERIV,A_DERIV,area,pressure,normalWave,normal,Lref,Tref,Mref
    REAL(DP) :: MU_PARAM,RHO_PARAM,A0_PARAM,E_PARAM,H_PARAM,A0_DERIV,E_DERIV,H_DERIV,alpha,beta,G0_PARAM,muScale
    REAL(DP), POINTER :: dependentParameters(:),materialsParameters(:),materialsParameters1(:)
    LOGICAL :: UPDATE_STIFFNESS_MATRIX,UPDATE_DAMPING_MATRIX,UPDATE_RHS_VECTOR,UPDATE_NONLINEAR_RESIDUAL
    TYPE(VARYING_STRING) :: LOCAL_ERROR

    ENTERS("NavierStokes_FiniteElementResidualEvaluate",ERR,ERROR,*999)

    UPDATE_STIFFNESS_MATRIX=.FALSE.
    UPDATE_DAMPING_MATRIX=.FALSE.
    UPDATE_RHS_VECTOR=.FALSE.
    UPDATE_NONLINEAR_RESIDUAL=.FALSE.
    X=0.0_DP
    out=0

    NULLIFY(DEPENDENT_BASIS,GEOMETRIC_BASIS)
    NULLIFY(EQUATIONS)
    NULLIFY(EQUATIONS_MAPPING)
    NULLIFY(LINEAR_MAPPING)
    NULLIFY(NONLINEAR_MAPPING)
    NULLIFY(DYNAMIC_MAPPING)
    NULLIFY(EQUATIONS_MATRICES)
    NULLIFY(LINEAR_MATRICES)
    NULLIFY(NONLINEAR_MATRICES)
    NULLIFY(DYNAMIC_MATRICES)
    NULLIFY(RHS_VECTOR)
    NULLIFY(STIFFNESS_MATRIX, DAMPING_MATRIX)
    NULLIFY(DEPENDENT_FIELD,INDEPENDENT_FIELD,GEOMETRIC_FIELD,MATERIALS_FIELD)
    NULLIFY(dependentParameters,materialsParameters,materialsParameters1)
    NULLIFY(FIELD_VARIABLE)
    NULLIFY(QUADRATURE_SCHEME)
    NULLIFY(QUADRATURE_SCHEME1, QUADRATURE_SCHEME2)
    NULLIFY(DECOMPOSITION)
   
    IF(ASSOCIATED(EQUATIONS_SET)) THEN
      IF(.NOT.ALLOCATED(EQUATIONS_SET%SPECIFICATION)) THEN
        CALL FlagError("Equations set specification is not allocated.",err,error,*999)
      ELSE IF(SIZE(EQUATIONS_SET%SPECIFICATION,1)/=3) THEN
        CALL FlagError("Equations set specification must have three entries for a Navier-Stokes type equations set.", &
          & err,error,*999)
      END IF
      EQUATIONS=>EQUATIONS_SET%EQUATIONS
      IF(ASSOCIATED(EQUATIONS)) THEN
        SELECT CASE(EQUATIONS_SET%SPECIFICATION(3))
        CASE(EQUATIONS_SET_STATIC_NAVIER_STOKES_SUBTYPE,EQUATIONS_SET_LAPLACE_NAVIER_STOKES_SUBTYPE, &
          & EQUATIONS_SET_STATIC_RBS_NAVIER_STOKES_SUBTYPE, &
          & EQUATIONS_SET_TRANSIENT_NAVIER_STOKES_SUBTYPE,EQUATIONS_SET_ALE_NAVIER_STOKES_SUBTYPE, &
          & EQUATIONS_SET_PGM_NAVIER_STOKES_SUBTYPE,EQUATIONS_SET_QUASISTATIC_NAVIER_STOKES_SUBTYPE, &
          & EQUATIONS_SET_TRANSIENT1D_NAVIER_STOKES_SUBTYPE,EQUATIONS_SET_COUPLED1D0D_NAVIER_STOKES_SUBTYPE, &
          & EQUATIONS_SET_TRANSIENT1D_ADV_NAVIER_STOKES_SUBTYPE,EQUATIONS_SET_TRANSIENT_RBS_NAVIER_STOKES_SUBTYPE, &
          & EQUATIONS_SET_MULTISCALE3D_NAVIER_STOKES_SUBTYPE,EQUATIONS_SET_COUPLED1D0D_ADV_NAVIER_STOKES_SUBTYPE, &
          & EQUATIONS_SET_CONSTITUTIVE_MU_NAVIER_STOKES_SUBTYPE)
          !Set general and specific pointers
          DEPENDENT_FIELD=>EQUATIONS%INTERPOLATION%DEPENDENT_FIELD
          INDEPENDENT_FIELD=>EQUATIONS%INTERPOLATION%INDEPENDENT_FIELD
          GEOMETRIC_FIELD=>EQUATIONS%INTERPOLATION%GEOMETRIC_FIELD
          MATERIALS_FIELD=>EQUATIONS%INTERPOLATION%MATERIALS_FIELD
          EQUATIONS_MATRICES=>EQUATIONS%EQUATIONS_MATRICES
          GEOMETRIC_BASIS=>GEOMETRIC_FIELD%DECOMPOSITION%DOMAIN(GEOMETRIC_FIELD%DECOMPOSITION%MESH_COMPONENT_NUMBER)%PTR% &
            & TOPOLOGY%ELEMENTS%ELEMENTS(ELEMENT_NUMBER)%BASIS
          DEPENDENT_BASIS=>DEPENDENT_FIELD%DECOMPOSITION%DOMAIN(DEPENDENT_FIELD%DECOMPOSITION%MESH_COMPONENT_NUMBER)%PTR% &
            & TOPOLOGY%ELEMENTS%ELEMENTS(ELEMENT_NUMBER)%BASIS
          QUADRATURE_SCHEME=>DEPENDENT_BASIS%QUADRATURE%QUADRATURE_SCHEME_MAP(BASIS_DEFAULT_QUADRATURE_SCHEME)%PTR
          RHS_VECTOR=>EQUATIONS_MATRICES%RHS_VECTOR
          EQUATIONS_MAPPING=>EQUATIONS%EQUATIONS_MAPPING
          SELECT CASE(EQUATIONS_SET%SPECIFICATION(3))
          CASE(EQUATIONS_SET_STATIC_NAVIER_STOKES_SUBTYPE,EQUATIONS_SET_LAPLACE_NAVIER_STOKES_SUBTYPE, &
            & EQUATIONS_SET_QUASISTATIC_NAVIER_STOKES_SUBTYPE)
            LINEAR_MATRICES=>EQUATIONS_MATRICES%LINEAR_MATRICES
            NONLINEAR_MATRICES=>EQUATIONS_MATRICES%NONLINEAR_MATRICES
            STIFFNESS_MATRIX=>LINEAR_MATRICES%MATRICES(1)%PTR
            LINEAR_MAPPING=>EQUATIONS_MAPPING%LINEAR_MAPPING
            NONLINEAR_MAPPING=>EQUATIONS_MAPPING%NONLINEAR_MAPPING
            FIELD_VARIABLE=>NONLINEAR_MAPPING%RESIDUAL_VARIABLES(1)%PTR
            FIELD_VAR_TYPE=FIELD_VARIABLE%VARIABLE_TYPE
            STIFFNESS_MATRIX%ELEMENT_MATRIX%MATRIX=0.0_DP
            NONLINEAR_MATRICES%ELEMENT_RESIDUAL%VECTOR=0.0_DP
            IF(ASSOCIATED(STIFFNESS_MATRIX)) UPDATE_STIFFNESS_MATRIX=STIFFNESS_MATRIX%UPDATE_MATRIX
            IF(ASSOCIATED(RHS_VECTOR)) UPDATE_RHS_VECTOR=RHS_VECTOR%UPDATE_VECTOR
            IF(ASSOCIATED(NONLINEAR_MATRICES)) UPDATE_NONLINEAR_RESIDUAL=NONLINEAR_MATRICES%UPDATE_RESIDUAL
          CASE(EQUATIONS_SET_STATIC_RBS_NAVIER_STOKES_SUBTYPE)
            LINEAR_MATRICES=>EQUATIONS_MATRICES%LINEAR_MATRICES
            NONLINEAR_MATRICES=>EQUATIONS_MATRICES%NONLINEAR_MATRICES
            STIFFNESS_MATRIX=>LINEAR_MATRICES%MATRICES(1)%PTR
            LINEAR_MAPPING=>EQUATIONS_MAPPING%LINEAR_MAPPING
            NONLINEAR_MAPPING=>EQUATIONS_MAPPING%NONLINEAR_MAPPING
            FIELD_VARIABLE=>NONLINEAR_MAPPING%RESIDUAL_VARIABLES(1)%PTR
            FIELD_VAR_TYPE=FIELD_VARIABLE%VARIABLE_TYPE
            STIFFNESS_MATRIX%ELEMENT_MATRIX%MATRIX=0.0_DP
            NONLINEAR_MATRICES%ELEMENT_RESIDUAL%VECTOR=0.0_DP
            IF(ASSOCIATED(STIFFNESS_MATRIX)) UPDATE_STIFFNESS_MATRIX=STIFFNESS_MATRIX%UPDATE_MATRIX
            IF(ASSOCIATED(RHS_VECTOR)) UPDATE_RHS_VECTOR=RHS_VECTOR%UPDATE_VECTOR
            IF(ASSOCIATED(NONLINEAR_MATRICES)) UPDATE_NONLINEAR_RESIDUAL=NONLINEAR_MATRICES%UPDATE_RESIDUAL
          CASE(EQUATIONS_SET_TRANSIENT_NAVIER_STOKES_SUBTYPE)
            DYNAMIC_MATRICES=>EQUATIONS_MATRICES%DYNAMIC_MATRICES
            STIFFNESS_MATRIX=>DYNAMIC_MATRICES%MATRICES(1)%PTR
            DAMPING_MATRIX=>DYNAMIC_MATRICES%MATRICES(2)%PTR
            NONLINEAR_MATRICES=>EQUATIONS_MATRICES%NONLINEAR_MATRICES
            DYNAMIC_MAPPING=>EQUATIONS_MAPPING%DYNAMIC_MAPPING
            NONLINEAR_MAPPING=>EQUATIONS_MAPPING%NONLINEAR_MAPPING
            FIELD_VARIABLE=>NONLINEAR_MAPPING%RESIDUAL_VARIABLES(1)%PTR
            FIELD_VAR_TYPE=FIELD_VARIABLE%VARIABLE_TYPE
            STIFFNESS_MATRIX%ELEMENT_MATRIX%MATRIX=0.0_DP
            DAMPING_MATRIX%ELEMENT_MATRIX%MATRIX=0.0_DP
            NONLINEAR_MATRICES%ELEMENT_RESIDUAL%VECTOR=0.0_DP
            IF(ASSOCIATED(STIFFNESS_MATRIX)) UPDATE_STIFFNESS_MATRIX=STIFFNESS_MATRIX%UPDATE_MATRIX
            IF(ASSOCIATED(DAMPING_MATRIX)) UPDATE_DAMPING_MATRIX=DAMPING_MATRIX%UPDATE_MATRIX
            IF(ASSOCIATED(RHS_VECTOR)) UPDATE_RHS_VECTOR=RHS_VECTOR%UPDATE_VECTOR
            IF(ASSOCIATED(NONLINEAR_MATRICES)) UPDATE_NONLINEAR_RESIDUAL=NONLINEAR_MATRICES%UPDATE_RESIDUAL
          CASE(EQUATIONS_SET_TRANSIENT1D_NAVIER_STOKES_SUBTYPE,EQUATIONS_SET_COUPLED1D0D_NAVIER_STOKES_SUBTYPE, & 
             & EQUATIONS_SET_TRANSIENT1D_ADV_NAVIER_STOKES_SUBTYPE,EQUATIONS_SET_COUPLED1D0D_ADV_NAVIER_STOKES_SUBTYPE)
            DYNAMIC_MATRICES=>EQUATIONS_MATRICES%DYNAMIC_MATRICES
            STIFFNESS_MATRIX=>DYNAMIC_MATRICES%MATRICES(1)%PTR
            DAMPING_MATRIX=>DYNAMIC_MATRICES%MATRICES(2)%PTR
            NONLINEAR_MATRICES=>EQUATIONS_MATRICES%NONLINEAR_MATRICES
            DYNAMIC_MAPPING=>EQUATIONS_MAPPING%DYNAMIC_MAPPING
            NONLINEAR_MAPPING=>EQUATIONS_MAPPING%NONLINEAR_MAPPING
            FIELD_VARIABLE=>NONLINEAR_MAPPING%RESIDUAL_VARIABLES(1)%PTR
            FIELD_VAR_TYPE=FIELD_VARIABLE%VARIABLE_TYPE
            STIFFNESS_MATRIX%ELEMENT_MATRIX%MATRIX=0.0_DP
            DAMPING_MATRIX%ELEMENT_MATRIX%MATRIX=0.0_DP
            NONLINEAR_MATRICES%ELEMENT_RESIDUAL%VECTOR=0.0_DP
            IF(ASSOCIATED(STIFFNESS_MATRIX)) UPDATE_STIFFNESS_MATRIX=STIFFNESS_MATRIX%UPDATE_MATRIX
            IF(ASSOCIATED(DAMPING_MATRIX)) UPDATE_DAMPING_MATRIX=DAMPING_MATRIX%UPDATE_MATRIX
            IF(ASSOCIATED(RHS_VECTOR)) UPDATE_RHS_VECTOR=RHS_VECTOR%UPDATE_VECTOR
            IF(ASSOCIATED(NONLINEAR_MATRICES)) UPDATE_NONLINEAR_RESIDUAL=NONLINEAR_MATRICES%UPDATE_RESIDUAL
            CALL FIELD_INTERPOLATION_PARAMETERS_ELEMENT_GET(FIELD_VALUES_SET_TYPE,ELEMENT_NUMBER,EQUATIONS%INTERPOLATION% &
             & MATERIALS_INTERP_PARAMETERS(FIELD_V_VARIABLE_TYPE)%PTR,ERR,ERROR,*999)
          CASE(EQUATIONS_SET_TRANSIENT_RBS_NAVIER_STOKES_SUBTYPE)
            DYNAMIC_MATRICES=>EQUATIONS_MATRICES%DYNAMIC_MATRICES
            STIFFNESS_MATRIX=>DYNAMIC_MATRICES%MATRICES(1)%PTR
            DAMPING_MATRIX=>DYNAMIC_MATRICES%MATRICES(2)%PTR
            NONLINEAR_MATRICES=>EQUATIONS_MATRICES%NONLINEAR_MATRICES
            DYNAMIC_MAPPING=>EQUATIONS_MAPPING%DYNAMIC_MAPPING
            NONLINEAR_MAPPING=>EQUATIONS_MAPPING%NONLINEAR_MAPPING
            FIELD_VARIABLE=>NONLINEAR_MAPPING%RESIDUAL_VARIABLES(1)%PTR
            FIELD_VAR_TYPE=FIELD_VARIABLE%VARIABLE_TYPE
            STIFFNESS_MATRIX%ELEMENT_MATRIX%MATRIX=0.0_DP
            DAMPING_MATRIX%ELEMENT_MATRIX%MATRIX=0.0_DP
            NONLINEAR_MATRICES%ELEMENT_RESIDUAL%VECTOR=0.0_DP
            IF(ASSOCIATED(STIFFNESS_MATRIX)) UPDATE_STIFFNESS_MATRIX=STIFFNESS_MATRIX%UPDATE_MATRIX
            IF(ASSOCIATED(DAMPING_MATRIX)) UPDATE_DAMPING_MATRIX=DAMPING_MATRIX%UPDATE_MATRIX
            IF(ASSOCIATED(RHS_VECTOR)) UPDATE_RHS_VECTOR=RHS_VECTOR%UPDATE_VECTOR
            IF(ASSOCIATED(NONLINEAR_MATRICES)) UPDATE_NONLINEAR_RESIDUAL=NONLINEAR_MATRICES%UPDATE_RESIDUAL
          CASE(EQUATIONS_SET_MULTISCALE3D_NAVIER_STOKES_SUBTYPE, &
            &  EQUATIONS_SET_CONSTITUTIVE_MU_NAVIER_STOKES_SUBTYPE)
            DECOMPOSITION => DEPENDENT_FIELD%DECOMPOSITION
            MESH_COMPONENT_NUMBER = DECOMPOSITION%MESH_COMPONENT_NUMBER
            DYNAMIC_MATRICES=>EQUATIONS_MATRICES%DYNAMIC_MATRICES
            STIFFNESS_MATRIX=>DYNAMIC_MATRICES%MATRICES(1)%PTR
            DAMPING_MATRIX=>DYNAMIC_MATRICES%MATRICES(2)%PTR
            NONLINEAR_MATRICES=>EQUATIONS_MATRICES%NONLINEAR_MATRICES
            DYNAMIC_MAPPING=>EQUATIONS_MAPPING%DYNAMIC_MAPPING
            NONLINEAR_MAPPING=>EQUATIONS_MAPPING%NONLINEAR_MAPPING
            FIELD_VARIABLE=>NONLINEAR_MAPPING%RESIDUAL_VARIABLES(1)%PTR
            FIELD_VAR_TYPE=FIELD_VARIABLE%VARIABLE_TYPE
            STIFFNESS_MATRIX%ELEMENT_MATRIX%MATRIX=0.0_DP
            DAMPING_MATRIX%ELEMENT_MATRIX%MATRIX=0.0_DP
            NONLINEAR_MATRICES%ELEMENT_RESIDUAL%VECTOR=0.0_DP
            IF(ASSOCIATED(STIFFNESS_MATRIX)) UPDATE_STIFFNESS_MATRIX=STIFFNESS_MATRIX%UPDATE_MATRIX
            IF(ASSOCIATED(DAMPING_MATRIX)) UPDATE_DAMPING_MATRIX=DAMPING_MATRIX%UPDATE_MATRIX
            IF(ASSOCIATED(RHS_VECTOR)) UPDATE_RHS_VECTOR=RHS_VECTOR%UPDATE_VECTOR
            IF(ASSOCIATED(NONLINEAR_MATRICES)) UPDATE_NONLINEAR_RESIDUAL=NONLINEAR_MATRICES%UPDATE_RESIDUAL
          CASE(EQUATIONS_SET_ALE_NAVIER_STOKES_SUBTYPE,EQUATIONS_SET_PGM_NAVIER_STOKES_SUBTYPE)
            INDEPENDENT_FIELD=>EQUATIONS%INTERPOLATION%INDEPENDENT_FIELD
            INDEPENDENT_BASIS=>INDEPENDENT_FIELD%DECOMPOSITION%DOMAIN(INDEPENDENT_FIELD%DECOMPOSITION%MESH_COMPONENT_NUMBER)% & 
              & PTR%TOPOLOGY%ELEMENTS%ELEMENTS(ELEMENT_NUMBER)%BASIS
            DYNAMIC_MATRICES=>EQUATIONS_MATRICES%DYNAMIC_MATRICES
            STIFFNESS_MATRIX=>DYNAMIC_MATRICES%MATRICES(1)%PTR
            DAMPING_MATRIX=>DYNAMIC_MATRICES%MATRICES(2)%PTR
            NONLINEAR_MATRICES=>EQUATIONS_MATRICES%NONLINEAR_MATRICES
            DYNAMIC_MAPPING=>EQUATIONS_MAPPING%DYNAMIC_MAPPING
            NONLINEAR_MAPPING=>EQUATIONS_MAPPING%NONLINEAR_MAPPING
            FIELD_VARIABLE=>NONLINEAR_MAPPING%RESIDUAL_VARIABLES(1)%PTR
            FIELD_VAR_TYPE=FIELD_VARIABLE%VARIABLE_TYPE
            STIFFNESS_MATRIX%ELEMENT_MATRIX%MATRIX=0.0_DP
            DAMPING_MATRIX%ELEMENT_MATRIX%MATRIX=0.0_DP
            NONLINEAR_MATRICES%ELEMENT_RESIDUAL%VECTOR=0.0_DP
            IF(ASSOCIATED(STIFFNESS_MATRIX)) UPDATE_STIFFNESS_MATRIX=STIFFNESS_MATRIX%UPDATE_MATRIX
            IF(ASSOCIATED(DAMPING_MATRIX)) UPDATE_DAMPING_MATRIX=DAMPING_MATRIX%UPDATE_MATRIX
            IF(ASSOCIATED(RHS_VECTOR)) UPDATE_RHS_VECTOR=RHS_VECTOR%UPDATE_VECTOR
            IF(ASSOCIATED(NONLINEAR_MATRICES)) UPDATE_NONLINEAR_RESIDUAL=NONLINEAR_MATRICES%UPDATE_RESIDUAL
            CALL FIELD_INTERPOLATION_PARAMETERS_ELEMENT_GET(FIELD_MESH_VELOCITY_SET_TYPE,ELEMENT_NUMBER,EQUATIONS%INTERPOLATION% &
              & INDEPENDENT_INTERP_PARAMETERS(FIELD_U_VARIABLE_TYPE)%PTR,ERR,ERROR,*999)
          CASE DEFAULT
            LOCAL_ERROR="Equations set subtype "//TRIM(NUMBER_TO_VSTRING(EQUATIONS_SET%SPECIFICATION(3),"*",ERR,ERROR))// &
              & " is not valid for a Navier-Stokes fluid type of a fluid mechanics equations set class."
            CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
          END SELECT
          CALL FIELD_INTERPOLATION_PARAMETERS_ELEMENT_GET(FIELD_VALUES_SET_TYPE,ELEMENT_NUMBER,EQUATIONS%INTERPOLATION% &
            & DEPENDENT_INTERP_PARAMETERS(FIELD_U_VARIABLE_TYPE)%PTR,ERR,ERROR,*999)
          CALL FIELD_INTERPOLATION_PARAMETERS_ELEMENT_GET(FIELD_VALUES_SET_TYPE,ELEMENT_NUMBER,EQUATIONS%INTERPOLATION% &
            & GEOMETRIC_INTERP_PARAMETERS(FIELD_U_VARIABLE_TYPE)%PTR,ERR,ERROR,*999)
          CALL FIELD_PARAMETER_SET_GET_CONSTANT(MATERIALS_FIELD,FIELD_U_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE,1, &
            & MU_PARAM,err,error,*999)
          CALL FIELD_PARAMETER_SET_GET_CONSTANT(MATERIALS_FIELD,FIELD_U_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE,2, &
            & RHO_PARAM,err,error,*999)
          !Loop over Gauss points
          DO ng=1,QUADRATURE_SCHEME%NUMBER_OF_GAUSS
            CALL FIELD_INTERPOLATE_GAUSS(FIRST_PART_DERIV,BASIS_DEFAULT_QUADRATURE_SCHEME,ng,EQUATIONS%INTERPOLATION% &
              & DEPENDENT_INTERP_POINT(FIELD_U_VARIABLE_TYPE)%PTR,ERR,ERROR,*999)
            CALL FIELD_INTERPOLATE_GAUSS(FIRST_PART_DERIV,BASIS_DEFAULT_QUADRATURE_SCHEME,ng,EQUATIONS%INTERPOLATION% &
              & GEOMETRIC_INTERP_POINT(FIELD_U_VARIABLE_TYPE)%PTR,ERR,ERROR,*999)
            CALL FIELD_INTERPOLATED_POINT_METRICS_CALCULATE(GEOMETRIC_BASIS%NUMBER_OF_XI,EQUATIONS%INTERPOLATION% &
              & GEOMETRIC_INTERP_POINT_METRICS(FIELD_U_VARIABLE_TYPE)%PTR,ERR,ERROR,*999)
            IF(EQUATIONS_SET%specification(3)==EQUATIONS_SET_ALE_NAVIER_STOKES_SUBTYPE.OR. &
              & EQUATIONS_SET%specification(3)==EQUATIONS_SET_PGM_NAVIER_STOKES_SUBTYPE) THEN
              CALL FIELD_INTERPOLATE_GAUSS(FIRST_PART_DERIV,BASIS_DEFAULT_QUADRATURE_SCHEME,ng,EQUATIONS%INTERPOLATION% &
                & INDEPENDENT_INTERP_POINT(FIELD_U_VARIABLE_TYPE)%PTR,ERR,ERROR,*999)
              W_VALUE(1)=EQUATIONS%INTERPOLATION%INDEPENDENT_INTERP_POINT(FIELD_U_VARIABLE_TYPE)%PTR%VALUES(1,NO_PART_DERIV)
              W_VALUE(2)=EQUATIONS%INTERPOLATION%INDEPENDENT_INTERP_POINT(FIELD_U_VARIABLE_TYPE)%PTR%VALUES(2,NO_PART_DERIV)
              IF(FIELD_VARIABLE%NUMBER_OF_COMPONENTS==4) THEN
                W_VALUE(3)=EQUATIONS%INTERPOLATION%INDEPENDENT_INTERP_POINT(FIELD_U_VARIABLE_TYPE)%PTR%VALUES(3,NO_PART_DERIV)
              END IF 
            ELSE
              W_VALUE=0.0_DP
            END IF

            ! Get the constitutive law (non-Newtonian) viscosity based on shear rate
            IF(EQUATIONS_SET%specification(3)==EQUATIONS_SET_CONSTITUTIVE_MU_NAVIER_STOKES_SUBTYPE) THEN
              ! Note the constant from the U_VARIABLE is a scale factor
              muScale = MU_PARAM
              ! Get the gauss point based value returned from the CellML solver
              CALL Field_ParameterSetGetLocalGaussPoint(MATERIALS_FIELD,FIELD_V_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE, &
                & ng,ELEMENT_NUMBER,1,MU_PARAM,ERR,ERROR,*999)
              MU_PARAM=MU_PARAM*muScale
            END IF

            !Start with matrix calculations
            IF(EQUATIONS_SET%specification(3)==EQUATIONS_SET_STATIC_NAVIER_STOKES_SUBTYPE.OR. &
              & EQUATIONS_SET%specification(3)==EQUATIONS_SET_LAPLACE_NAVIER_STOKES_SUBTYPE.OR. &
              & EQUATIONS_SET%specification(3)==EQUATIONS_SET_STATIC_RBS_NAVIER_STOKES_SUBTYPE.OR. &
              & EQUATIONS_SET%specification(3)==EQUATIONS_SET_TRANSIENT_NAVIER_STOKES_SUBTYPE.OR. &
              & EQUATIONS_SET%specification(3)==EQUATIONS_SET_TRANSIENT_RBS_NAVIER_STOKES_SUBTYPE.OR. &
              & EQUATIONS_SET%specification(3)==EQUATIONS_SET_MULTISCALE3D_NAVIER_STOKES_SUBTYPE.OR. &
              & EQUATIONS_SET%specification(3)==EQUATIONS_SET_CONSTITUTIVE_MU_NAVIER_STOKES_SUBTYPE.OR. &
              & EQUATIONS_SET%specification(3)==EQUATIONS_SET_QUASISTATIC_NAVIER_STOKES_SUBTYPE.OR. &
              & EQUATIONS_SET%specification(3)==EQUATIONS_SET_ALE_NAVIER_STOKES_SUBTYPE.OR. &
              & EQUATIONS_SET%specification(3)==EQUATIONS_SET_PGM_NAVIER_STOKES_SUBTYPE) THEN
              !Loop over field components
              mhs=0
              DO mh=1,FIELD_VARIABLE%NUMBER_OF_COMPONENTS-1
                MESH_COMPONENT1=FIELD_VARIABLE%COMPONENTS(mh)%MESH_COMPONENT_NUMBER
                DEPENDENT_BASIS1=>DEPENDENT_FIELD%DECOMPOSITION%DOMAIN(MESH_COMPONENT1)%PTR% &
                  & TOPOLOGY%ELEMENTS%ELEMENTS(ELEMENT_NUMBER)%BASIS
                QUADRATURE_SCHEME1=>DEPENDENT_BASIS1%QUADRATURE%QUADRATURE_SCHEME_MAP(BASIS_DEFAULT_QUADRATURE_SCHEME)%PTR
                JGW=EQUATIONS%INTERPOLATION%GEOMETRIC_INTERP_POINT_METRICS(FIELD_U_VARIABLE_TYPE)%PTR%JACOBIAN* &
                  & QUADRATURE_SCHEME1%GAUSS_WEIGHTS(ng)

                DO ms=1,DEPENDENT_BASIS1%NUMBER_OF_ELEMENT_PARAMETERS
                  mhs=mhs+1
                  nhs=0
                  IF(UPDATE_STIFFNESS_MATRIX.OR.UPDATE_DAMPING_MATRIX) THEN
                    !Loop over element columns
                    DO nh=1,FIELD_VARIABLE%NUMBER_OF_COMPONENTS
                      MESH_COMPONENT2=FIELD_VARIABLE%COMPONENTS(nh)%MESH_COMPONENT_NUMBER
                      DEPENDENT_BASIS2=>DEPENDENT_FIELD%DECOMPOSITION%DOMAIN(MESH_COMPONENT2)%PTR% &
                        & TOPOLOGY%ELEMENTS%ELEMENTS(ELEMENT_NUMBER)%BASIS
                      QUADRATURE_SCHEME2=>DEPENDENT_BASIS2%QUADRATURE%QUADRATURE_SCHEME_MAP&
                        &(BASIS_DEFAULT_QUADRATURE_SCHEME)%PTR
                      ! JGW=EQUATIONS%INTERPOLATION%GEOMETRIC_INTERP_POINT_METRICS%JACOBIAN*QUADRATURE_SCHEME2%&
                      ! &GAUSS_WEIGHTS(ng)                        
                      DO ns=1,DEPENDENT_BASIS2%NUMBER_OF_ELEMENT_PARAMETERS
                        nhs=nhs+1
                        !Calculate some general values
                        DO ni=1,DEPENDENT_BASIS2%NUMBER_OF_XI
                          DO mi=1,DEPENDENT_BASIS1%NUMBER_OF_XI
                            DXI_DX(mi,ni)=EQUATIONS%INTERPOLATION%GEOMETRIC_INTERP_POINT_METRICS(FIELD_U_VARIABLE_TYPE)%PTR% &
                              & DXI_DX(mi,ni)
                          END DO
                          DPHIMS_DXI(ni)=QUADRATURE_SCHEME1%GAUSS_BASIS_FNS(ms,PARTIAL_DERIVATIVE_FIRST_DERIVATIVE_MAP(ni),ng)
                          DPHINS_DXI(ni)=QUADRATURE_SCHEME2%GAUSS_BASIS_FNS(ns,PARTIAL_DERIVATIVE_FIRST_DERIVATIVE_MAP(ni),ng)
                        END DO !ni
                        PHIMS=QUADRATURE_SCHEME1%GAUSS_BASIS_FNS(ms,NO_PART_DERIV,ng)
                        PHINS=QUADRATURE_SCHEME2%GAUSS_BASIS_FNS(ns,NO_PART_DERIV,ng)
                        !Laplace only matrix
                        IF(UPDATE_STIFFNESS_MATRIX) THEN
                          !LAPLACE TYPE 
                          IF(nh==mh) THEN 
                            SUM=0.0_DP
                            !Calculate SUM 
                            DO xv=1,DEPENDENT_BASIS1%NUMBER_OF_XI
                              DO mi=1,DEPENDENT_BASIS1%NUMBER_OF_XI
                                DO ni=1,DEPENDENT_BASIS2%NUMBER_OF_XI
                                  SUM=SUM+MU_PARAM*DPHINS_DXI(ni)*DXI_DX(ni,xv)*DPHIMS_DXI(mi)*DXI_DX(mi,xv)
                                END DO !ni
                              END DO !mi
                            END DO !x 
                            !Calculate MATRIX  
                            STIFFNESS_MATRIX%ELEMENT_MATRIX%MATRIX(mhs,nhs)=STIFFNESS_MATRIX%ELEMENT_MATRIX%MATRIX(mhs,nhs)+SUM*JGW
                          END IF
                        END IF
                        !General matrix
                        IF(UPDATE_STIFFNESS_MATRIX) THEN
                          !GRADIENT TRANSPOSE TYPE
                          IF(EQUATIONS_SET%SPECIFICATION(3)/=EQUATIONS_SET_LAPLACE_NAVIER_STOKES_SUBTYPE) THEN 
                            IF(nh<FIELD_VARIABLE%NUMBER_OF_COMPONENTS) THEN 
                              SUM=0.0_DP
                              !Calculate SUM 
                              DO mi=1,DEPENDENT_BASIS1%NUMBER_OF_XI
                                DO ni=1,DEPENDENT_BASIS2%NUMBER_OF_XI
                                  !note mh/nh derivative in DXI_DX 
                                  SUM=SUM+MU_PARAM*DPHINS_DXI(mi)*DXI_DX(mi,mh)*DPHIMS_DXI(ni)*DXI_DX(ni,nh)
                                END DO !ni
                              END DO !mi
                              !Calculate MATRIX
                              STIFFNESS_MATRIX%ELEMENT_MATRIX%MATRIX(mhs,nhs)=STIFFNESS_MATRIX%ELEMENT_MATRIX%MATRIX(mhs,nhs) &
                               & +SUM*JGW
                           END IF
                          END IF
                        END IF
                        !Contribution through ALE
                        IF(UPDATE_STIFFNESS_MATRIX) THEN
                          !GRADIENT TRANSPOSE TYPE
                          IF(EQUATIONS_SET%SPECIFICATION(3)==EQUATIONS_SET_ALE_NAVIER_STOKES_SUBTYPE.OR. & 
                            & EQUATIONS_SET%SPECIFICATION(3)==EQUATIONS_SET_PGM_NAVIER_STOKES_SUBTYPE) THEN 
                            IF(nh==mh) THEN 
                              SUM=0.0_DP
                              !Calculate SUM 
                              DO mi=1,DEPENDENT_BASIS1%NUMBER_OF_XI
                                DO ni=1,DEPENDENT_BASIS1%NUMBER_OF_XI
                                  SUM=SUM-RHO_PARAM*W_VALUE(mi)*DPHINS_DXI(ni)*DXI_DX(ni,mi)*PHIMS
                                END DO !ni
                              END DO !mi
                              !Calculate MATRIX
                              STIFFNESS_MATRIX%ELEMENT_MATRIX%MATRIX(mhs,nhs)=STIFFNESS_MATRIX%ELEMENT_MATRIX%MATRIX(mhs,nhs)+ &
                               & SUM*JGW
                            END IF
                          END IF
                        END IF
                        !Pressure contribution (B transpose)
                        IF(UPDATE_STIFFNESS_MATRIX) THEN
                          !LAPLACE TYPE 
                          IF(nh==FIELD_VARIABLE%NUMBER_OF_COMPONENTS) THEN 
                            SUM=0.0_DP
                            !Calculate SUM 
                            DO ni=1,DEPENDENT_BASIS1%NUMBER_OF_XI
                              SUM=SUM-PHINS*DPHIMS_DXI(ni)*DXI_DX(ni,mh)
                            END DO !ni
                            !Calculate MATRIX
                            STIFFNESS_MATRIX%ELEMENT_MATRIX%MATRIX(mhs,nhs)=STIFFNESS_MATRIX%ELEMENT_MATRIX%MATRIX(mhs,nhs)+SUM*JGW
                          END IF
                        END IF
                        !Damping matrix
                        IF(EQUATIONS_SET%specification(3)==EQUATIONS_SET_TRANSIENT_NAVIER_STOKES_SUBTYPE.OR. &
                          & EQUATIONS_SET%specification(3)==EQUATIONS_SET_ALE_NAVIER_STOKES_SUBTYPE.OR. &
                          & EQUATIONS_SET%specification(3)==EQUATIONS_SET_PGM_NAVIER_STOKES_SUBTYPE.OR. &
                          & EQUATIONS_SET%specification(3)==EQUATIONS_SET_TRANSIENT_RBS_NAVIER_STOKES_SUBTYPE.OR. &
                          & EQUATIONS_SET%specification(3)==EQUATIONS_SET_MULTISCALE3D_NAVIER_STOKES_SUBTYPE .OR. &
                          & EQUATIONS_SET%specification(3)==EQUATIONS_SET_CONSTITUTIVE_MU_NAVIER_STOKES_SUBTYPE) THEN
                          IF(UPDATE_DAMPING_MATRIX) THEN
                            IF(nh==mh) THEN 
                              SUM=0.0_DP 
                              !Calculate SUM 
                              SUM=PHIMS*PHINS*RHO_PARAM
                              !Calculate MATRIX
                              DAMPING_MATRIX%ELEMENT_MATRIX%MATRIX(mhs,nhs)=DAMPING_MATRIX%ELEMENT_MATRIX%MATRIX(mhs,nhs)+SUM*JGW
                            END IF
                          END IF
                        END IF
                      END DO !ns    
                    END DO !nh
                  END IF
                END DO !ms
              END DO !mh
              !Analytic RHS vector
              IF(RHS_VECTOR%FIRST_ASSEMBLY) THEN
                IF(UPDATE_RHS_VECTOR) THEN
                  IF(ASSOCIATED(EQUATIONS_SET%ANALYTIC)) THEN
                    IF(EQUATIONS_SET%ANALYTIC%ANALYTIC_FUNCTION_TYPE==EQUATIONS_SET_NAVIER_STOKES_EQUATION_TWO_DIM_1.OR. &
                      & EQUATIONS_SET%ANALYTIC%ANALYTIC_FUNCTION_TYPE==EQUATIONS_SET_NAVIER_STOKES_EQUATION_TWO_DIM_2.OR. &
                      & EQUATIONS_SET%ANALYTIC%ANALYTIC_FUNCTION_TYPE==EQUATIONS_SET_NAVIER_STOKES_EQUATION_TWO_DIM_3.OR. &
                      & EQUATIONS_SET%ANALYTIC%ANALYTIC_FUNCTION_TYPE==EQUATIONS_SET_NAVIER_STOKES_EQUATION_TWO_DIM_4.OR. &
                      & EQUATIONS_SET%ANALYTIC%ANALYTIC_FUNCTION_TYPE==EQUATIONS_SET_NAVIER_STOKES_EQUATION_TWO_DIM_5.OR. &
                      & EQUATIONS_SET%ANALYTIC%ANALYTIC_FUNCTION_TYPE==EQUATIONS_SET_NAVIER_STOKES_EQUATION_ONE_DIM_1.OR. &
                      & EQUATIONS_SET%ANALYTIC%ANALYTIC_FUNCTION_TYPE==EQUATIONS_SET_NAVIER_STOKES_EQUATION_THREE_DIM_1.OR. &
                      & EQUATIONS_SET%ANALYTIC%ANALYTIC_FUNCTION_TYPE==EQUATIONS_SET_NAVIER_STOKES_EQUATION_THREE_DIM_2.OR. &
                      & EQUATIONS_SET%ANALYTIC%ANALYTIC_FUNCTION_TYPE==EQUATIONS_SET_NAVIER_STOKES_EQUATION_THREE_DIM_3.OR. &
                      & EQUATIONS_SET%ANALYTIC%ANALYTIC_FUNCTION_TYPE==EQUATIONS_SET_NAVIER_STOKES_EQUATION_THREE_DIM_4.OR. &
                      & EQUATIONS_SET%ANALYTIC%ANALYTIC_FUNCTION_TYPE==EQUATIONS_SET_NAVIER_STOKES_EQUATION_THREE_DIM_5) THEN
                      mhs=0
                      DO mh=1,FIELD_VARIABLE%NUMBER_OF_COMPONENTS-1
                        MESH_COMPONENT1=FIELD_VARIABLE%COMPONENTS(mh)%MESH_COMPONENT_NUMBER
                        DEPENDENT_BASIS1=>DEPENDENT_FIELD%DECOMPOSITION%DOMAIN(MESH_COMPONENT1)%PTR% &
                          & TOPOLOGY%ELEMENTS%ELEMENTS(ELEMENT_NUMBER)%BASIS
                        QUADRATURE_SCHEME1=>DEPENDENT_BASIS1%QUADRATURE%QUADRATURE_SCHEME_MAP(BASIS_DEFAULT_QUADRATURE_SCHEME)%PTR
                        JGW=EQUATIONS%INTERPOLATION%GEOMETRIC_INTERP_POINT_METRICS(FIELD_U_VARIABLE_TYPE)%PTR%JACOBIAN* &
                          & QUADRATURE_SCHEME1%GAUSS_WEIGHTS(ng)

                        DO ms=1,DEPENDENT_BASIS1%NUMBER_OF_ELEMENT_PARAMETERS
                          mhs=mhs+1
                          PHIMS=QUADRATURE_SCHEME1%GAUSS_BASIS_FNS(ms,NO_PART_DERIV,ng)
                          !note mh value derivative 
                          SUM=0.0_DP 
                          X(1) = EQUATIONS%INTERPOLATION%GEOMETRIC_INTERP_POINT(FIELD_U_VARIABLE_TYPE)%PTR%VALUES(1,1)
                          X(2) = EQUATIONS%INTERPOLATION%GEOMETRIC_INTERP_POINT(FIELD_U_VARIABLE_TYPE)%PTR%VALUES(2,1)
                          IF(DEPENDENT_BASIS1%NUMBER_OF_XI==3) THEN
                            X(3) = EQUATIONS%INTERPOLATION%GEOMETRIC_INTERP_POINT(FIELD_U_VARIABLE_TYPE)%PTR%VALUES(3,1)
                          END IF
                          IF(EQUATIONS_SET%ANALYTIC%ANALYTIC_FUNCTION_TYPE==EQUATIONS_SET_NAVIER_STOKES_EQUATION_TWO_DIM_1) THEN
                            IF(mh==1) THEN 
                              !Calculate SUM 
                              SUM=0.0_DP                         
                            ELSE IF(mh==2) THEN
                              !Calculate SUM 
                              SUM=PHIMS*(-2.0_DP/3.0_DP*(X(1)**3*RHO_PARAM+3.0_DP*MU_PARAM*10.0_DP**2- &
                                & 3.0_DP*RHO_PARAM*X(2)**2*X(1))/(10.0_DP**4))
                            END IF
                          ELSE IF(EQUATIONS_SET%ANALYTIC%ANALYTIC_FUNCTION_TYPE==EQUATIONS_SET_NAVIER_STOKES_EQUATION_TWO_DIM_2) &
                            & THEN
                            IF(mh==1) THEN 
                              !Calculate SUM 
                              SUM=0.0_DP                               
                            ELSE IF(mh==2) THEN
                              !Calculate SUM 
                              SUM=PHIMS*(-4.0_DP*MU_PARAM/10.0_DP/10.0_DP*EXP((X(1)-X(2))/10.0_DP))
                            END IF
                          ELSE IF(EQUATIONS_SET%ANALYTIC%ANALYTIC_FUNCTION_TYPE==EQUATIONS_SET_NAVIER_STOKES_EQUATION_TWO_DIM_3) & 
                           & THEN
                            IF(mh==1) THEN 
                              !Calculate SUM 
                              SUM=0.0_DP         
                            ELSE IF(mh==2) THEN
                              !Calculate SUM 
                              SUM=PHIMS*(16.0_DP*MU_PARAM*PI**2/10.0_DP**2*COS(2.0_DP*PI*X(2)/10.0_DP)* &
                                & COS(2.0_DP*PI*X(1)/10.0_DP)- &
                                & 2.0_DP*COS(2.0_DP*PI*X(2)/10.0_DP)*SIN(2.0_DP*PI*X(2)/10.0_DP)*RHO_PARAM*PI/10.0_DP)
                            END IF
                          ELSE IF(EQUATIONS_SET%ANALYTIC%ANALYTIC_FUNCTION_TYPE==EQUATIONS_SET_NAVIER_STOKES_EQUATION_TWO_DIM_4) & 
                           & THEN
                            IF(mh==1) THEN 
                              !Calculate SUM 
                              SUM=PHIMS*(2.0_DP*SIN(X(1))*COS(X(2)))*MU_PARAM
                            ELSE IF(mh==2) THEN
                              !Calculate SUM 
                              SUM=PHIMS*(-2.0_DP*COS(X(1))*SIN(X(2)))*MU_PARAM
                            END IF
                          ELSE IF(EQUATIONS_SET%ANALYTIC%ANALYTIC_FUNCTION_TYPE==EQUATIONS_SET_NAVIER_STOKES_EQUATION_TWO_DIM_5) & 
                           & THEN
                            !do nothing
                          ELSE IF(EQUATIONS_SET%ANALYTIC%ANALYTIC_FUNCTION_TYPE== & 
                            & EQUATIONS_SET_NAVIER_STOKES_EQUATION_THREE_DIM_1) THEN
                            IF(mh==1) THEN 
                              !Calculate SUM 
                              SUM=0.0_DP       
                            ELSE IF(mh==2) THEN
                              !Calculate SUM 
                              SUM=PHIMS*(-2.0_DP/3.0_DP*(RHO_PARAM*X(1)**3+6.0_DP*RHO_PARAM*X(1)*X(3)*X(2)+ &
                                & 6.0_DP*MU_PARAM*10.0_DP**2- & 
                                & 3.0_DP*RHO_PARAM*X(2)**2*X(1)-3.0_DP*RHO_PARAM*X(3)*X(1)**2-3.0_DP*RHO_PARAM*X(3)*X(2)**2)/ &
                                  & (10.0_DP**4))
                            ELSE IF(mh==3) THEN
                              !Calculate SUM 
                              SUM=PHIMS*(-2.0_DP/3.0_DP*(6.0_DP*RHO_PARAM*X(1)*X(3)*X(2)+RHO_PARAM*X(1)**3+ &
                                & 6.0_DP*MU_PARAM*10.0_DP**2- & 
                                & 3.0_DP*RHO_PARAM*X(1)*X(3)**2-3.0_DP*RHO_PARAM*X(2)*X(1)**2-3.0_DP*RHO_PARAM*X(2)*X(3)**2)/ & 
                                & (10.0_DP**4))
                            END IF
                          ELSE IF(EQUATIONS_SET%ANALYTIC%ANALYTIC_FUNCTION_TYPE== & 
                            & EQUATIONS_SET_NAVIER_STOKES_EQUATION_THREE_DIM_2) THEN
                            IF(mh==1) THEN 
                              !Calculate SUM 
                              SUM=0.0_DP         
                            ELSE IF(mh==2) THEN
                              !Calculate SUM 
                              SUM=PHIMS*((-4.0_DP*MU_PARAM*EXP((X(1)-X(2))/10.0_DP)-2.0_DP*MU_PARAM*EXP((X(2)-X(3))/10.0_DP)+ & 
                                & RHO_PARAM*EXP((X(3)-X(2))/10.0_DP)*10.0_DP)/10.0_DP**2)
                            ELSE IF(mh==3) THEN
                              !Calculate SUM 
                              SUM=PHIMS*(-(4.0_DP*MU_PARAM*EXP((X(3)-X(1))/10.0_DP)+2.0_DP*MU_PARAM*EXP((X(2)-X(3))/10.0_DP)+ & 
                                & RHO_PARAM*EXP((X(3)-X(2))/10.0_DP)*10.0_DP)/10.0_DP** 2)
                            END IF
                          ELSE IF(EQUATIONS_SET%ANALYTIC%ANALYTIC_FUNCTION_TYPE== & 
                            & EQUATIONS_SET_NAVIER_STOKES_EQUATION_THREE_DIM_3) THEN
                            IF(mh==1) THEN 
                              !Calculate SUM 
                              SUM=0.0_DP         
                            ELSE IF(mh==2) THEN
                              !Calculate SUM 
                              SUM=PHIMS*(2.0_DP*COS(2.0_DP*PI*X(2)/10.0_DP)*(18.0_DP*COS(2.0_DP*PI*X(1)/10.0_DP)* &
                                & MU_PARAM*PI*SIN(2.0_DP*PI*X(3)/10.0_DP)-3.0_DP*RHO_PARAM*COS(2.0_DP*PI*X(1)/10.0_DP)**2* &
                                & SIN(2.0_DP*PI*X(2)/10.0_DP)*10.0_DP-2.0_DP*RHO_PARAM*SIN(2.0_DP*PI*X(2)/10.0_DP)*10.0_DP+ & 
                                & 2.0_DP*RHO_PARAM*SIN(2.0_DP*PI*X(2)/10.0_DP)*10.0_DP*COS(2.0_DP*PI*X(3)/10.0_DP)**2)*PI/ &
                                & 10.0_DP**2)
                            ELSE IF(mh==3) THEN
                              !Calculate SUM 
                              SUM=PHIMS*(-2.0_DP*PI*COS(2.0_DP*PI*X(3)/10.0_DP)*RHO_PARAM*SIN(2.0_DP*PI*X(3)/10.0_DP)* & 
                                & (-1.0_DP+COS(2.0_DP*PI*X(2)/10.0_DP)**2)/10.0_DP)
                            END IF
                          ELSE IF(EQUATIONS_SET%ANALYTIC%ANALYTIC_FUNCTION_TYPE== &
                            & EQUATIONS_SET_NAVIER_STOKES_EQUATION_THREE_DIM_4) THEN
                            IF(mh==1) THEN 
                              !Calculate SUM 
                              !SUM=PHIMS*(2.0_DP*SIN(X(1))*COS(X(2)))*MU_PARAM
                            ELSE IF(mh==2) THEN
                              !Calculate SUM 
                              !SUM=PHIMS*(-2.0_DP*COS(X(1))*SIN(X(2)))*MU_PARAM
                            END IF
                          ELSE IF(EQUATIONS_SET%ANALYTIC%ANALYTIC_FUNCTION_TYPE== &
                            & EQUATIONS_SET_NAVIER_STOKES_EQUATION_THREE_DIM_5) THEN
                            !do nothing
                          END IF
                          !Calculate RH VECTOR
                           RHS_VECTOR%ELEMENT_VECTOR%VECTOR(mhs)=RHS_VECTOR%ELEMENT_VECTOR%VECTOR(mhs)+SUM*JGW
                        END DO !ms
                      END DO !mh
                    ELSE
                      RHS_VECTOR%ELEMENT_VECTOR%VECTOR(mhs)=0.0_DP
                    END IF                 
                  END IF
                END IF                                                                     
              END IF

              !Calculate nonlinear vector
              IF(UPDATE_NONLINEAR_RESIDUAL) THEN
                ! Get interpolated velocity and velocity gradient values for nonlinear term
                U_VALUE(1)=EQUATIONS%INTERPOLATION%DEPENDENT_INTERP_POINT(FIELD_VAR_TYPE)%PTR%VALUES(1,NO_PART_DERIV)
                U_VALUE(2)=EQUATIONS%INTERPOLATION%DEPENDENT_INTERP_POINT(FIELD_VAR_TYPE)%PTR%VALUES(2,NO_PART_DERIV)
                U_DERIV(1,1)=EQUATIONS%INTERPOLATION%DEPENDENT_INTERP_POINT(FIELD_VAR_TYPE)%PTR%VALUES(1,PART_DERIV_S1)
                U_DERIV(1,2)=EQUATIONS%INTERPOLATION%DEPENDENT_INTERP_POINT(FIELD_VAR_TYPE)%PTR%VALUES(1,PART_DERIV_S2)
                U_DERIV(2,1)=EQUATIONS%INTERPOLATION%DEPENDENT_INTERP_POINT(FIELD_VAR_TYPE)%PTR%VALUES(2,PART_DERIV_S1)
                U_DERIV(2,2)=EQUATIONS%INTERPOLATION%DEPENDENT_INTERP_POINT(FIELD_VAR_TYPE)%PTR%VALUES(2,PART_DERIV_S2)
                IF(FIELD_VARIABLE%NUMBER_OF_COMPONENTS==4) THEN
                  U_VALUE(3)=EQUATIONS%INTERPOLATION%DEPENDENT_INTERP_POINT(FIELD_VAR_TYPE)%PTR%VALUES(3,NO_PART_DERIV)
                  U_DERIV(3,1)=EQUATIONS%INTERPOLATION%DEPENDENT_INTERP_POINT(FIELD_VAR_TYPE)%PTR%VALUES(3,PART_DERIV_S1)
                  U_DERIV(3,2)=EQUATIONS%INTERPOLATION%DEPENDENT_INTERP_POINT(FIELD_VAR_TYPE)%PTR%VALUES(3,PART_DERIV_S2)
                  U_DERIV(3,3)=EQUATIONS%INTERPOLATION%DEPENDENT_INTERP_POINT(FIELD_VAR_TYPE)%PTR%VALUES(3,PART_DERIV_S3)
                  U_DERIV(1,3)=EQUATIONS%INTERPOLATION%DEPENDENT_INTERP_POINT(FIELD_VAR_TYPE)%PTR%VALUES(1,PART_DERIV_S3)
                  U_DERIV(2,3)=EQUATIONS%INTERPOLATION%DEPENDENT_INTERP_POINT(FIELD_VAR_TYPE)%PTR%VALUES(2,PART_DERIV_S3) 
                ELSE
                  U_VALUE(3)=0.0_DP
                  U_DERIV(3,1)=0.0_DP
                  U_DERIV(3,2)=0.0_DP
                  U_DERIV(3,3)=0.0_DP
                  U_DERIV(1,3)=0.0_DP
                  U_DERIV(2,3)=0.0_DP
                END IF
                !Here W_VALUES must be ZERO if ALE part of linear matrix
                W_VALUE=0.0_DP
                mhs=0
                DO mh=1,(FIELD_VARIABLE%NUMBER_OF_COMPONENTS-1)
                  MESH_COMPONENT1=FIELD_VARIABLE%COMPONENTS(mh)%MESH_COMPONENT_NUMBER
                  DEPENDENT_BASIS1=>DEPENDENT_FIELD%DECOMPOSITION%DOMAIN(MESH_COMPONENT1)%PTR% &
                    & TOPOLOGY%ELEMENTS%ELEMENTS(ELEMENT_NUMBER)%BASIS
                  QUADRATURE_SCHEME1=>DEPENDENT_BASIS1%QUADRATURE%QUADRATURE_SCHEME_MAP(BASIS_DEFAULT_QUADRATURE_SCHEME)%PTR
                  JGW=EQUATIONS%INTERPOLATION%GEOMETRIC_INTERP_POINT_METRICS(FIELD_U_VARIABLE_TYPE)%PTR%JACOBIAN* &
                    & QUADRATURE_SCHEME1%GAUSS_WEIGHTS(ng)
                  DXI_DX=0.0_DP

                  DO ni=1,DEPENDENT_BASIS1%NUMBER_OF_XI
                    DO mi=1,DEPENDENT_BASIS1%NUMBER_OF_XI
                      DXI_DX(mi,ni)=EQUATIONS%INTERPOLATION%GEOMETRIC_INTERP_POINT_METRICS(FIELD_U_VARIABLE_TYPE)%PTR%DXI_DX(mi,ni)
                    END DO
                  END DO

                  DO ms=1,DEPENDENT_BASIS1%NUMBER_OF_ELEMENT_PARAMETERS
                    mhs=mhs+1
                    PHIMS=QUADRATURE_SCHEME1%GAUSS_BASIS_FNS(ms,NO_PART_DERIV,ng)
                    !note mh value derivative 
                    SUM=0.0_DP
                    ! Convective form
                    DO ni=1,DEPENDENT_BASIS1%NUMBER_OF_XI
                      SUM=SUM+RHO_PARAM*(PHIMS)*( & 
                        & (U_VALUE(1))*(U_DERIV(mh,ni)*DXI_DX(ni,1))+ &
                        & (U_VALUE(2))*(U_DERIV(mh,ni)*DXI_DX(ni,2))+ &
                        & (U_VALUE(3))*(U_DERIV(mh,ni)*DXI_DX(ni,3)))
                    END DO !ni

                    NONLINEAR_MATRICES%ELEMENT_RESIDUAL%VECTOR(mhs)=NONLINEAR_MATRICES%ELEMENT_RESIDUAL%VECTOR(mhs)+SUM*JGW

                  END DO !ms
                END DO !mh
              END IF
            END IF

            !------------------------------------------------------------------
            ! R e s i d u a l - b a s e d    S t a b i l i s a t i o n
            !------------------------------------------------------------------
            IF(EQUATIONS_SET%specification(3)==EQUATIONS_SET_TRANSIENT_RBS_NAVIER_STOKES_SUBTYPE.OR. &
              & EQUATIONS_SET%specification(3)==EQUATIONS_SET_STATIC_RBS_NAVIER_STOKES_SUBTYPE.OR. &
              & EQUATIONS_SET%specification(3)==EQUATIONS_SET_MULTISCALE3D_NAVIER_STOKES_SUBTYPE) THEN
              CALL NavierStokes_ResidualBasedStabilisation(EQUATIONS_SET,ELEMENT_NUMBER,ng, &
               & MU_PARAM,RHO_PARAM,.FALSE.,ERR,ERROR,*999)
            END IF

            !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
            !!!!!                                        !!!!!
            !!!!!         1 D  T R A N S I E N T         !!!!!
            !!!!!                                        !!!!!
            !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

            !Start with matrix calculations
            IF(EQUATIONS_SET%specification(3)==EQUATIONS_SET_TRANSIENT1D_NAVIER_STOKES_SUBTYPE .OR. &
              & EQUATIONS_SET%specification(3)==EQUATIONS_SET_COUPLED1D0D_NAVIER_STOKES_SUBTYPE .OR. &
              & EQUATIONS_SET%specification(3)==EQUATIONS_SET_TRANSIENT1D_ADV_NAVIER_STOKES_SUBTYPE .OR. &
              & EQUATIONS_SET%specification(3)==EQUATIONS_SET_COUPLED1D0D_ADV_NAVIER_STOKES_SUBTYPE) THEN
              Q_VALUE=EQUATIONS%INTERPOLATION%DEPENDENT_INTERP_POINT(FIELD_U_VARIABLE_TYPE)%PTR%VALUES(1,NO_PART_DERIV)
              Q_DERIV=EQUATIONS%INTERPOLATION%DEPENDENT_INTERP_POINT(FIELD_U_VARIABLE_TYPE)%PTR%VALUES(1,FIRST_PART_DERIV)
              A_VALUE=EQUATIONS%INTERPOLATION%DEPENDENT_INTERP_POINT(FIELD_U_VARIABLE_TYPE)%PTR%VALUES(2,NO_PART_DERIV)
              A_DERIV=EQUATIONS%INTERPOLATION%DEPENDENT_INTERP_POINT(FIELD_U_VARIABLE_TYPE)%PTR%VALUES(2,FIRST_PART_DERIV)
              CALL FIELD_PARAMETER_SET_GET_CONSTANT(MATERIALS_FIELD,FIELD_U_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE,3, &
               & alpha,err,error,*999)
              CALL FIELD_PARAMETER_SET_GET_CONSTANT(MATERIALS_FIELD,FIELD_U_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE,8, &
               & G0_PARAM,err,error,*999)
              CALL FIELD_INTERPOLATE_GAUSS(FIRST_PART_DERIV,BASIS_DEFAULT_QUADRATURE_SCHEME,ng,EQUATIONS%INTERPOLATION% &
                & MATERIALS_INTERP_POINT(FIELD_V_VARIABLE_TYPE)%PTR,ERR,ERROR,*999)
              A0_PARAM=EQUATIONS%INTERPOLATION%MATERIALS_INTERP_POINT(FIELD_V_VARIABLE_TYPE)%PTR%VALUES(1,NO_PART_DERIV)
              A0_DERIV=EQUATIONS%INTERPOLATION%MATERIALS_INTERP_POINT(FIELD_V_VARIABLE_TYPE)%PTR%VALUES(1,FIRST_PART_DERIV)
              E_PARAM=EQUATIONS%INTERPOLATION%MATERIALS_INTERP_POINT(FIELD_V_VARIABLE_TYPE)%PTR%VALUES(2,NO_PART_DERIV)
              E_DERIV=EQUATIONS%INTERPOLATION%MATERIALS_INTERP_POINT(FIELD_V_VARIABLE_TYPE)%PTR%VALUES(2,FIRST_PART_DERIV)
              H_PARAM=EQUATIONS%INTERPOLATION%MATERIALS_INTERP_POINT(FIELD_V_VARIABLE_TYPE)%PTR%VALUES(3,NO_PART_DERIV)
              H_DERIV=EQUATIONS%INTERPOLATION%MATERIALS_INTERP_POINT(FIELD_V_VARIABLE_TYPE)%PTR%VALUES(3,FIRST_PART_DERIV)
              beta = (4.0_DP*(SQRT(PI))*E_PARAM*H_PARAM)/(3.0_DP*A0_PARAM)  !(kg/m2/s2)

              ! If A goes negative during nonlinear iteration, give ZERO_TOLERANCE value to avoid segfault
              IF(A_VALUE < A0_PARAM*0.001_DP) THEN
                A_VALUE = A0_PARAM*0.001_DP
              END IF

              mhs=0
              !Loop Over Element Rows
              DO mh=1,FIELD_VARIABLE%NUMBER_OF_COMPONENTS
                MESH_COMPONENT1=FIELD_VARIABLE%COMPONENTS(mh)%MESH_COMPONENT_NUMBER
                DEPENDENT_BASIS1=>DEPENDENT_FIELD%DECOMPOSITION%DOMAIN(MESH_COMPONENT1)%PTR% &
                  & TOPOLOGY%ELEMENTS%ELEMENTS(ELEMENT_NUMBER)%BASIS
                QUADRATURE_SCHEME1=>DEPENDENT_BASIS1%QUADRATURE%QUADRATURE_SCHEME_MAP(BASIS_DEFAULT_QUADRATURE_SCHEME)%PTR
                JGW=EQUATIONS%INTERPOLATION%GEOMETRIC_INTERP_POINT_METRICS(FIELD_U_VARIABLE_TYPE)%PTR%JACOBIAN* &
                  & QUADRATURE_SCHEME1%GAUSS_WEIGHTS(ng)
                ELEMENTS_TOPOLOGY=>FIELD_VARIABLE%COMPONENTS(mh)%DOMAIN%TOPOLOGY%ELEMENTS
                DXI_DX=0.0_DP
                !Calculate dxi_dx in 3D
                DO xiIdx=1,DEPENDENT_BASIS1%NUMBER_OF_XI
                  DO coordIdx=1,EQUATIONS%INTERPOLATION%GEOMETRIC_INTERP_POINT_METRICS(FIELD_U_VARIABLE_TYPE) &
                    & %PTR%NUMBER_OF_X_DIMENSIONS
                    DXI_DX(1,1)=DXI_DX(1,1)+(EQUATIONS%INTERPOLATION%GEOMETRIC_INTERP_POINT_METRICS(FIELD_U_VARIABLE_TYPE)% &
                      & PTR%DXI_DX(xiIdx,coordIdx))**2.0_DP
                  END DO !coordIdx
                END DO !xiIdx
                DXI_DX(1,1)=SQRT(DXI_DX(1,1))
                !Loop Over Element rows
                DO ms=1,DEPENDENT_BASIS1%NUMBER_OF_ELEMENT_PARAMETERS
                  PHIMS=QUADRATURE_SCHEME1%GAUSS_BASIS_FNS(ms,NO_PART_DERIV,ng)
                  DPHIMS_DXI(1)=QUADRATURE_SCHEME1%GAUSS_BASIS_FNS(ms,FIRST_PART_DERIV,ng)
                  mhs=mhs+1
                  nhs=0
                  IF(UPDATE_STIFFNESS_MATRIX .OR. UPDATE_DAMPING_MATRIX) THEN
                    !Loop Over Element Columns
                    DO nh=1,FIELD_VARIABLE%NUMBER_OF_COMPONENTS
                      MESH_COMPONENT2=FIELD_VARIABLE%COMPONENTS(nh)%MESH_COMPONENT_NUMBER
                      DEPENDENT_BASIS2=>DEPENDENT_FIELD%DECOMPOSITION%DOMAIN(MESH_COMPONENT2)%PTR% &
                        & TOPOLOGY%ELEMENTS%ELEMENTS(ELEMENT_NUMBER)%BASIS
                      QUADRATURE_SCHEME2=>DEPENDENT_BASIS2%QUADRATURE%QUADRATURE_SCHEME_MAP(BASIS_DEFAULT_QUADRATURE_SCHEME)%PTR
                      DO ns=1,DEPENDENT_BASIS2%NUMBER_OF_ELEMENT_PARAMETERS
                        PHINS=QUADRATURE_SCHEME2%GAUSS_BASIS_FNS(ns,NO_PART_DERIV,ng)
                        DPHINS_DXI(1)=QUADRATURE_SCHEME2%GAUSS_BASIS_FNS(ns,FIRST_PART_DERIV,ng)
                        nhs=nhs+1

                        !!!-- D A M P I N G  M A T R I X --!!!
                        IF(UPDATE_DAMPING_MATRIX) THEN
                          !Momentum Equation, dQ/dt
                          IF(mh==1 .AND. nh==1) THEN
                            SUM=PHINS*PHIMS
                            DAMPING_MATRIX%ELEMENT_MATRIX%MATRIX(mhs,nhs)= &
                              & DAMPING_MATRIX%ELEMENT_MATRIX%MATRIX(mhs,nhs)+SUM*JGW
                          END IF
                          !Mass Equation, dA/dt
                          IF(mh==2 .AND. nh==2) THEN
                            SUM=PHINS*PHIMS
                            DAMPING_MATRIX%ELEMENT_MATRIX%MATRIX(mhs,nhs)= &
                              & DAMPING_MATRIX%ELEMENT_MATRIX%MATRIX(mhs,nhs)+SUM*JGW
                          END IF
                        END IF

                        !!!-- S T I F F N E S S  M A T R I X --!!!
                        IF(UPDATE_STIFFNESS_MATRIX) THEN
                          IF(mh==1 .AND. nh==2) THEN 
                            !Momentum Equation, linearisable A0 terms
                            SUM=-PHINS*PHIMS*(beta*SQRT(A0_PARAM)/RHO_PARAM)*(H_DERIV/H_PARAM + E_DERIV/E_PARAM)*DXI_DX(1,1)
                            STIFFNESS_MATRIX%ELEMENT_MATRIX%MATRIX(mhs,nhs)= &
                              & STIFFNESS_MATRIX%ELEMENT_MATRIX%MATRIX(mhs,nhs)+SUM*JGW
                            !Momentum Equation, gravitational force
                            SUM=PHINS*PHIMS*G0_PARAM
                            STIFFNESS_MATRIX%ELEMENT_MATRIX%MATRIX(mhs,nhs)= &
                              & STIFFNESS_MATRIX%ELEMENT_MATRIX%MATRIX(mhs,nhs)+SUM*JGW
                          END IF
                          !Mass Equation, dQ/dX, flow derivative
                          IF(mh==2 .AND. nh==1) THEN 
                            SUM=DPHINS_DXI(1)*DXI_DX(1,1)*PHIMS
                            STIFFNESS_MATRIX%ELEMENT_MATRIX%MATRIX(mhs,nhs)= &
                              & STIFFNESS_MATRIX%ELEMENT_MATRIX%MATRIX(mhs,nhs)+SUM*JGW
                          END IF
                        END IF

                      END DO !ns    
                    END DO !nh
                  END IF
                  
                  !!!-- N O N L I N E A R  V E C T O R --!!!
                  IF(UPDATE_NONLINEAR_RESIDUAL) THEN
                    !Momentum Equation
                    IF(mh==1) THEN
                      SUM=((2.0_DP*alpha*(Q_VALUE/A_VALUE)*Q_DERIV - &
                        & (alpha*((Q_VALUE/A_VALUE)**2.0_DP)*A_DERIV)+(beta/RHO_PARAM)* &           !Convective
                        & ((SQRT(A_VALUE)/2.0_DP)*A_DERIV+ &                                        !A  gradient 
                        & (A_VALUE/(2.0_DP*SQRT(A0_PARAM))-(A_VALUE**1.5_DP)/A0_PARAM)*A0_DERIV+ &  !A0 gradient
                        & (A_VALUE*(SQRT(A_VALUE)))*(H_DERIV/H_PARAM) + &                           !H  gradient (nonlinear part)
                        & (A_VALUE*(SQRT(A_VALUE)))*(E_DERIV/E_PARAM)))* &                          !E  gradient (nonlinear part)
                        & DXI_DX(1,1)+(Q_VALUE/A_VALUE))*PHIMS                                      !Viscosity
                      NONLINEAR_MATRICES%ELEMENT_RESIDUAL%VECTOR(mhs)= &
                        & NONLINEAR_MATRICES%ELEMENT_RESIDUAL%VECTOR(mhs)+SUM*JGW
                    END IF
                  END IF

                END DO !ms
              END DO !mh
            END IF
          END DO !ng

          IF(EQUATIONS_SET%specification(3)==EQUATIONS_SET_TRANSIENT1D_NAVIER_STOKES_SUBTYPE .OR. &
              & EQUATIONS_SET%specification(3)==EQUATIONS_SET_COUPLED1D0D_NAVIER_STOKES_SUBTYPE .OR. &
              & EQUATIONS_SET%specification(3)==EQUATIONS_SET_TRANSIENT1D_ADV_NAVIER_STOKES_SUBTYPE .OR. &
              & EQUATIONS_SET%specification(3)==EQUATIONS_SET_COUPLED1D0D_ADV_NAVIER_STOKES_SUBTYPE) THEN
            IF(UPDATE_NONLINEAR_RESIDUAL) THEN
              ELEMENTS_TOPOLOGY=>DEPENDENT_FIELD%VARIABLE_TYPE_MAP(FIELD_U_VARIABLE_TYPE)%PTR%components(1)%domain%topology%elements
              numberOfElementNodes=ELEMENTS_TOPOLOGY%ELEMENTS(ELEMENT_NUMBER)%BASIS%NUMBER_OF_NODES
              numberOfParameters=ELEMENTS_TOPOLOGY%MAXIMUM_NUMBER_OF_ELEMENT_PARAMETERS  
              firstNode=ELEMENTS_TOPOLOGY%ELEMENTS(ELEMENT_NUMBER)%ELEMENT_NODES(1)
              lastNode=ELEMENTS_TOPOLOGY%ELEMENTS(ELEMENT_NUMBER)%ELEMENT_NODES(numberOfElementNodes)
              !Get material constants
              CALL FIELD_PARAMETER_SET_GET_CONSTANT(MATERIALS_FIELD,FIELD_U_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE,2, &
                & RHO_PARAM,err,error,*999)
              CALL FIELD_PARAMETER_SET_GET_CONSTANT(MATERIALS_FIELD,FIELD_U_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE,4, &
                & pExternal,err,error,*999)
              CALL FIELD_PARAMETER_SET_GET_CONSTANT(MATERIALS_FIELD,FIELD_U_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE,5, &
                & Lref,err,error,*999)
              CALL FIELD_PARAMETER_SET_GET_CONSTANT(MATERIALS_FIELD,FIELD_U_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE,6, &
                & Tref,err,error,*999)
              CALL FIELD_PARAMETER_SET_GET_CONSTANT(MATERIALS_FIELD,FIELD_U_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE,7, &
                & Mref,err,error,*999)

              !!!-- P R E S S U R E    C A L C U L A T I O N --!!!
              !Loop over the element nodes and versions
              DO nodeIdx=1,numberOfElementNodes
                nodeNumber=ELEMENTS_TOPOLOGY%ELEMENTS(ELEMENT_NUMBER)%ELEMENT_NODES(nodeIdx)
                derivativeIdx = 1
                versionIdx=ELEMENTS_TOPOLOGY%DOMAIN%TOPOLOGY%ELEMENTS%ELEMENTS(ELEMENT_NUMBER)% &
                 & elementVersions(derivativeIdx,nodeIdx)
                !Get current Area values
                CALL Field_ParameterSetGetLocalNode(DEPENDENT_FIELD,FIELD_U_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE,versionIdx, &
                 & derivativeIdx,nodeNumber,2,area,err,error,*999)
                IF(area < A0_PARAM*0.001_DP) area = A0_PARAM*0.001_DP
                !Get material parameters
                CALL Field_ParameterSetGetLocalNode(MATERIALS_FIELD,FIELD_V_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE,versionIdx, &
                 & derivativeIdx,nodeNumber,1,A0_PARAM,err,error,*999) 
                CALL Field_ParameterSetGetLocalNode(MATERIALS_FIELD,FIELD_V_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE,versionIdx, &
                 & derivativeIdx,nodeNumber,2,E_PARAM,err,error,*999) 
                CALL Field_ParameterSetGetLocalNode(MATERIALS_FIELD,FIELD_V_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE,versionIdx, &
                  & derivativeIdx,nodeNumber,3,H_PARAM,err,error,*999) 
                beta = (4.0_DP*(SQRT(PI))*E_PARAM*H_PARAM)/(3.0_DP*A0_PARAM)  !(kg/m2/s2)
                !Pressure equation in mmHg
                pressure=(pExternal+beta*(SQRT(area)-SQRT(A0_PARAM)))/(Mref/(Lref*Tref**2.0))*0.0075_DP
                !Update the dependent field
                IF(ELEMENT_NUMBER<=DEPENDENT_FIELD%DECOMPOSITION%TOPOLOGY%ELEMENTS%NUMBER_OF_ELEMENTS) THEN
                  CALL FIELD_PARAMETER_SET_UPDATE_LOCAL_NODE(DEPENDENT_FIELD,FIELD_U2_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE, &
                    & versionIdx,1,nodeNumber,1,pressure,err,error,*999)
                END IF
              END DO
                
              !!!-- B R A N C H   F L U X   U P W I N D I N G --!!!
              !----------------------------------------------------
              ! In order to enforce conservation of mass and momentum across discontinuous
              ! branching topologies, flux is upwinded against the conservative branch values 
              ! established by the characteristic solver.
              DO nodeIdx=1,numberOfElementNodes
                nodeNumber=ELEMENTS_TOPOLOGY%ELEMENTS(ELEMENT_NUMBER)%ELEMENT_NODES(nodeIdx)
                numberOfVersions=ELEMENTS_TOPOLOGY%DOMAIN%TOPOLOGY%NODES%NODES(nodeNumber)%DERIVATIVES(1)%numberOfVersions

                ! Find the branch node on this element
                IF(numberOfVersions>1) THEN                  
                  derivativeIdx = 1
                  elementVersionNumber=ELEMENTS_TOPOLOGY%DOMAIN%TOPOLOGY%ELEMENTS%ELEMENTS(ELEMENT_NUMBER)% &
                   & elementVersions(derivativeIdx,nodeIdx)

                  ! Find the wave direction - incoming or outgoing
                  DO componentIdx = 1,2
                    CALL Field_ParameterSetGetLocalNode(INDEPENDENT_FIELD,FIELD_U_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE, & 
                     & elementVersionNumber,derivativeIdx,nodeNumber,componentIdx,normalWave,err,error,*999)
                    IF(ABS(normalWave) > ZERO_TOLERANCE) THEN
                      normal = normalWave
                    END IF
                  END DO

                  ! Get materials parameters for node on this element
                  CALL Field_ParameterSetGetLocalNode(MATERIALS_FIELD,FIELD_V_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE, &
                   & elementVersionNumber,derivativeIdx,nodeNumber,1,A0_PARAM,err,error,*999)
                  CALL Field_ParameterSetGetLocalNode(MATERIALS_FIELD,FIELD_V_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE, &
                   & elementVersionNumber,derivativeIdx,nodeNumber,2,E_PARAM,err,error,*999)
                  CALL Field_ParameterSetGetLocalNode(MATERIALS_FIELD,FIELD_V_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE, &
                    & elementVersionNumber,derivativeIdx,nodeNumber,3,H_PARAM,err,error,*999)
                  beta = (4.0_DP*(SQRT(PI))*E_PARAM*H_PARAM)/(3.0_DP*A0_PARAM)

                  !Get current Q & A values for node on this element
                  CALL Field_ParameterSetGetLocalNode(DEPENDENT_FIELD,FIELD_U_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE, &
                   & elementVersionNumber,derivativeIdx,nodeNumber,1,Q_VALUE,err,error,*999)         
                  CALL Field_ParameterSetGetLocalNode(DEPENDENT_FIELD,FIELD_U_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE, &
                   & elementVersionNumber,derivativeIdx,nodeNumber,2,A_VALUE,err,error,*999)

                  !Get upwind Q & A values based on the branch (characteristics) solver
                  CALL Field_ParameterSetGetLocalNode(DEPENDENT_FIELD,FIELD_U_VARIABLE_TYPE,FIELD_UPWIND_VALUES_SET_TYPE, &
                   & elementVersionNumber,derivativeIdx,nodeNumber,1,QUpwind,err,error,*999)         
                  CALL Field_ParameterSetGetLocalNode(DEPENDENT_FIELD,FIELD_U_VARIABLE_TYPE,FIELD_UPWIND_VALUES_SET_TYPE, &
                   & elementVersionNumber,derivativeIdx,nodeNumber,2,AUpwind,err,error,*999)

                  ! If A goes negative during nonlinear iteration, set to positive value to avoid segfault
                  IF(A_VALUE < A0_PARAM*0.001_DP) THEN
                    A_VALUE = A0_PARAM*0.001_DP
                  END IF

                  !Momentum Equation: F_upwind - F_Current
                  momentum = ((alpha*(QUpwind**2.0_DP)/AUpwind+(AUpwind**1.5_DP-A0_PARAM**1.5_DP)*(beta/(3.0_DP*RHO_PARAM))) &
                         & - (alpha*(Q_VALUE**2.0_DP)/A_VALUE+(A_VALUE**1.5_DP-A0_PARAM**1.5_DP)*(beta/(3.0_DP*RHO_PARAM))))*normal

                  !Continuity Equation 
                  mass = (QUpwind-Q_VALUE)*normal

                  !Add momentum/mass contributions to first/last node accordingly
                  IF(nodeNumber==firstNode) THEN
                    NONLINEAR_MATRICES%ELEMENT_RESIDUAL%VECTOR(1)= &
                      & NONLINEAR_MATRICES%ELEMENT_RESIDUAL%VECTOR(1)+momentum
                    NONLINEAR_MATRICES%ELEMENT_RESIDUAL%VECTOR(numberOfParameters+1)= &
                      & NONLINEAR_MATRICES%ELEMENT_RESIDUAL%VECTOR(numberOfParameters+1)+mass
                  ELSE IF(nodeNumber==lastNode) THEN
                    NONLINEAR_MATRICES%ELEMENT_RESIDUAL%VECTOR(numberOfParameters)= &
                      & NONLINEAR_MATRICES%ELEMENT_RESIDUAL%VECTOR(numberOfParameters)+momentum
                    NONLINEAR_MATRICES%ELEMENT_RESIDUAL%VECTOR(numberOfParameters*2)= &
                      & NONLINEAR_MATRICES%ELEMENT_RESIDUAL%VECTOR(numberOfParameters*2)+mass
                  END IF
                END IF !version>1
              END DO !loop nodes
            END IF
          END IF

          ! F a c e   I n t e g r a t i o n
          IF(RHS_VECTOR%UPDATE_VECTOR) THEN
            !If specified, also perform face integration for neumann boundary conditions
            IF(DEPENDENT_FIELD%DECOMPOSITION%CALCULATE_FACES) THEN
              CALL NavierStokes_FiniteElementFaceIntegrate(EQUATIONS_SET,ELEMENT_NUMBER,FIELD_VARIABLE,ERR,ERROR,*999)
            END IF
          END IF

          !!!--   A S S E M B L E   M A T R I C E S  &  V E C T O R S   --!!!
          mhs_min=mhs
          mhs_max=nhs
          nhs_min=mhs
          nhs_max=nhs
          IF(EQUATIONS_SET%specification(3)==EQUATIONS_SET_STATIC_NAVIER_STOKES_SUBTYPE.OR.  &
            & EQUATIONS_SET%specification(3)==EQUATIONS_SET_STATIC_RBS_NAVIER_STOKES_SUBTYPE.OR. &
            & EQUATIONS_SET%specification(3)==EQUATIONS_SET_LAPLACE_NAVIER_STOKES_SUBTYPE.OR. &
            & EQUATIONS_SET%specification(3)==EQUATIONS_SET_TRANSIENT_NAVIER_STOKES_SUBTYPE.OR. &
            & EQUATIONS_SET%specification(3)==EQUATIONS_SET_TRANSIENT_RBS_NAVIER_STOKES_SUBTYPE.OR. &
            & EQUATIONS_SET%specification(3)==EQUATIONS_SET_MULTISCALE3D_NAVIER_STOKES_SUBTYPE.OR. &
            & EQUATIONS_SET%specification(3)==EQUATIONS_SET_CONSTITUTIVE_MU_NAVIER_STOKES_SUBTYPE.OR. &
            & EQUATIONS_SET%specification(3)==EQUATIONS_SET_QUASISTATIC_NAVIER_STOKES_SUBTYPE.OR. &
            & EQUATIONS_SET%specification(3)==EQUATIONS_SET_ALE_NAVIER_STOKES_SUBTYPE.OR. &
            & EQUATIONS_SET%specification(3)==EQUATIONS_SET_PGM_NAVIER_STOKES_SUBTYPE) THEN
            IF(STIFFNESS_MATRIX%FIRST_ASSEMBLY) THEN
              IF(UPDATE_STIFFNESS_MATRIX) THEN
                DO mhs=mhs_min+1,mhs_max
                  DO nhs=1,nhs_min
                    !Transpose pressure type entries for mass equation  
                    STIFFNESS_MATRIX%ELEMENT_MATRIX%MATRIX(mhs,nhs)=-STIFFNESS_MATRIX%ELEMENT_MATRIX%MATRIX(nhs,mhs)
                  END DO
                END DO
              END IF
            END IF
          END IF

        CASE DEFAULT
          LOCAL_ERROR="Equations set subtype "//TRIM(NUMBER_TO_VSTRING(EQUATIONS_SET%SPECIFICATION(3),"*",ERR,ERROR))// &
            & " is not valid for a Navier-Stokes equation type of a classical field equations set class."
          CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
        END SELECT
      ELSE
        CALL FlagError("Equations set equations is not associated.",ERR,ERROR,*999)
      END IF
    ELSE
      CALL FlagError("Equations set is not associated.",ERR,ERROR,*999)
    ENDIF

    EXITS("NavierStokes_FiniteElementResidualEvaluate")
    RETURN
999 ERRORSEXITS("NavierStokes_FiniteElementResidualEvaluate",ERR,ERROR)
    RETURN 1
    
  END SUBROUTINE NavierStokes_FiniteElementResidualEvaluate

  !
  !================================================================================================================================
  !

  !>Evaluates the Jacobian element stiffness matrices and RHS for a Navier-Stokes equation finite element equations set.
  SUBROUTINE NavierStokes_FiniteElementJacobianEvaluate(EQUATIONS_SET,ELEMENT_NUMBER,ERR,ERROR,*)

    !Argument variables
    TYPE(EQUATIONS_SET_TYPE), POINTER :: EQUATIONS_SET !<A pointer to the equations set to perform the finite element calculations on
    INTEGER(INTG), INTENT(IN) :: ELEMENT_NUMBER !<The element number to calculate
    INTEGER(INTG), INTENT(OUT) :: ERR !<The error code
    TYPE(VARYING_STRING), INTENT(OUT) :: ERROR !<The error string
    !Local Variables
    TYPE(BASIS_TYPE), POINTER :: DEPENDENT_BASIS,DEPENDENT_BASIS1,DEPENDENT_BASIS2,GEOMETRIC_BASIS,INDEPENDENT_BASIS
    TYPE(DECOMPOSITION_TYPE), POINTER :: DECOMPOSITION
    TYPE(DOMAIN_ELEMENTS_TYPE), POINTER :: ELEMENTS_TOPOLOGY
    TYPE(EQUATIONS_TYPE), POINTER :: EQUATIONS
    TYPE(EQUATIONS_MAPPING_TYPE), POINTER :: EQUATIONS_MAPPING
    TYPE(EQUATIONS_MAPPING_LINEAR_TYPE), POINTER :: LINEAR_MAPPING
    TYPE(EQUATIONS_MAPPING_DYNAMIC_TYPE), POINTER :: DYNAMIC_MAPPING
    TYPE(EQUATIONS_MAPPING_NONLINEAR_TYPE), POINTER :: NONLINEAR_MAPPING
    TYPE(EQUATIONS_MATRICES_TYPE), POINTER :: EQUATIONS_MATRICES
    TYPE(EQUATIONS_MATRICES_LINEAR_TYPE), POINTER :: LINEAR_MATRICES
    TYPE(EQUATIONS_MATRICES_DYNAMIC_TYPE), POINTER :: DYNAMIC_MATRICES
    TYPE(EQUATIONS_MATRICES_NONLINEAR_TYPE), POINTER :: NONLINEAR_MATRICES
    TYPE(EQUATIONS_JACOBIAN_TYPE), POINTER :: JACOBIAN_MATRIX
    TYPE(EQUATIONS_MATRIX_TYPE), POINTER :: STIFFNESS_MATRIX 
    TYPE(FIELD_TYPE), POINTER :: DEPENDENT_FIELD,GEOMETRIC_FIELD,MATERIALS_FIELD,INDEPENDENT_FIELD
    TYPE(FIELD_VARIABLE_TYPE), POINTER :: FIELD_VARIABLE
    TYPE(QUADRATURE_SCHEME_TYPE), POINTER :: QUADRATURE_SCHEME,QUADRATURE_SCHEME1,QUADRATURE_SCHEME2
    TYPE(VARYING_STRING) :: LOCAL_ERROR
    INTEGER(INTG) :: ng,mh,mhs,mi,ms,nh,nhs,ni,ns,x,xiIdx,coordIdx
    INTEGER(INTG) :: derivativeIdx,elementVersionNumber,firstNode,lastNode,nodeIdx,nodeNumber
    INTEGER(INTG) :: numberOfElementNodes,numberOfParameters,numberOfVersions,componentIdx
    INTEGER(INTG) :: FIELD_VAR_TYPE,MESH_COMPONENT_NUMBER,MESH_COMPONENT1,MESH_COMPONENT2
    REAL(DP) :: JGW,SUM,DXI_DX(3,3),DPHIMS_DXI(3),DPHINS_DXI(3),PHIMS,PHINS
    REAL(DP) :: U_VALUE(3),W_VALUE(3),U_DERIV(3,3),Q_VALUE,Q_DERIV,A_VALUE,A_DERIV,alpha,beta,normal,normalWave
    REAL(DP) :: MU_PARAM,RHO_PARAM,A0_PARAM,A0_DERIV,E_PARAM,E_DERIV,H_PARAM,H_DERIV,mass,momentum1,momentum2,muScale
    LOGICAL  :: UPDATE_JACOBIAN_MATRIX

    ENTERS("NavierStokes_FiniteElementJacobianEvaluate",ERR,ERROR,*999)

    DXI_DX=0.0_DP
    UPDATE_JACOBIAN_MATRIX=.FALSE.

    IF(ASSOCIATED(EQUATIONS_SET)) THEN
      IF(.NOT.ALLOCATED(EQUATIONS_SET%SPECIFICATION)) THEN
        CALL FlagError("Equations set specification is not allocated.",err,error,*999)
      ELSE IF(SIZE(EQUATIONS_SET%SPECIFICATION,1)/=3) THEN
        CALL FlagError("Equations set specification must have three entries for a Navier-Stokes type equations set.", &
          & err,error,*999)
      END IF
      NULLIFY(EQUATIONS)
      EQUATIONS=>EQUATIONS_SET%EQUATIONS
      IF(ASSOCIATED(EQUATIONS)) THEN
        SELECT CASE(EQUATIONS_SET%specification(3))
        CASE(EQUATIONS_SET_STATIC_NAVIER_STOKES_SUBTYPE, &
          & EQUATIONS_SET_LAPLACE_NAVIER_STOKES_SUBTYPE, &
          & EQUATIONS_SET_STATIC_RBS_NAVIER_STOKES_SUBTYPE, &
          & EQUATIONS_SET_TRANSIENT_NAVIER_STOKES_SUBTYPE, &
          & EQUATIONS_SET_ALE_NAVIER_STOKES_SUBTYPE, &
          & EQUATIONS_SET_PGM_NAVIER_STOKES_SUBTYPE, &
          & EQUATIONS_SET_QUASISTATIC_NAVIER_STOKES_SUBTYPE, &
          & EQUATIONS_SET_TRANSIENT1D_NAVIER_STOKES_SUBTYPE, &
          & EQUATIONS_SET_COUPLED1D0D_NAVIER_STOKES_SUBTYPE, &
          & EQUATIONS_SET_TRANSIENT1D_ADV_NAVIER_STOKES_SUBTYPE, &
          & EQUATIONS_SET_COUPLED1D0D_ADV_NAVIER_STOKES_SUBTYPE, &
          & EQUATIONS_SET_TRANSIENT_RBS_NAVIER_STOKES_SUBTYPE, &
          & EQUATIONS_SET_MULTISCALE3D_NAVIER_STOKES_SUBTYPE, &
          & EQUATIONS_SET_CONSTITUTIVE_MU_NAVIER_STOKES_SUBTYPE)
          !Set some general and case-specific pointers
          DEPENDENT_FIELD=>EQUATIONS%INTERPOLATION%DEPENDENT_FIELD
          INDEPENDENT_FIELD=>EQUATIONS%INTERPOLATION%INDEPENDENT_FIELD
          GEOMETRIC_FIELD=>EQUATIONS%INTERPOLATION%GEOMETRIC_FIELD
          MATERIALS_FIELD=>EQUATIONS%INTERPOLATION%MATERIALS_FIELD
          EQUATIONS_MATRICES=>EQUATIONS%EQUATIONS_MATRICES
          GEOMETRIC_BASIS=>GEOMETRIC_FIELD%DECOMPOSITION%DOMAIN(GEOMETRIC_FIELD%DECOMPOSITION%MESH_COMPONENT_NUMBER)%PTR% &
            & TOPOLOGY%ELEMENTS%ELEMENTS(ELEMENT_NUMBER)%BASIS
          DEPENDENT_BASIS=>DEPENDENT_FIELD%DECOMPOSITION%DOMAIN(DEPENDENT_FIELD%DECOMPOSITION%MESH_COMPONENT_NUMBER)%PTR% &
            & TOPOLOGY%ELEMENTS%ELEMENTS(ELEMENT_NUMBER)%BASIS
          QUADRATURE_SCHEME=>DEPENDENT_BASIS%QUADRATURE%QUADRATURE_SCHEME_MAP(BASIS_DEFAULT_QUADRATURE_SCHEME)%PTR
          EQUATIONS_MAPPING=>EQUATIONS%EQUATIONS_MAPPING
          SELECT CASE(EQUATIONS_SET%specification(3))
          CASE(EQUATIONS_SET_STATIC_NAVIER_STOKES_SUBTYPE,EQUATIONS_SET_LAPLACE_NAVIER_STOKES_SUBTYPE, &
            & EQUATIONS_SET_QUASISTATIC_NAVIER_STOKES_SUBTYPE)
            LINEAR_MATRICES=>EQUATIONS_MATRICES%LINEAR_MATRICES
            NONLINEAR_MATRICES=>EQUATIONS_MATRICES%NONLINEAR_MATRICES
            JACOBIAN_MATRIX=>NONLINEAR_MATRICES%JACOBIANS(1)%PTR
            STIFFNESS_MATRIX=>LINEAR_MATRICES%MATRICES(1)%PTR
            LINEAR_MAPPING=>EQUATIONS_MAPPING%LINEAR_MAPPING
            NONLINEAR_MAPPING=>EQUATIONS_MAPPING%NONLINEAR_MAPPING
            FIELD_VARIABLE=>NONLINEAR_MAPPING%RESIDUAL_VARIABLES(1)%PTR
            FIELD_VAR_TYPE=FIELD_VARIABLE%VARIABLE_TYPE
            STIFFNESS_MATRIX%ELEMENT_MATRIX%MATRIX=0.0_DP
            NONLINEAR_MATRICES%ELEMENT_RESIDUAL%VECTOR=0.0_DP
            IF(ASSOCIATED(JACOBIAN_MATRIX)) UPDATE_JACOBIAN_MATRIX=JACOBIAN_MATRIX%UPDATE_JACOBIAN
          CASE(EQUATIONS_SET_STATIC_RBS_NAVIER_STOKES_SUBTYPE)
            LINEAR_MATRICES=>EQUATIONS_MATRICES%LINEAR_MATRICES
            NONLINEAR_MATRICES=>EQUATIONS_MATRICES%NONLINEAR_MATRICES
            JACOBIAN_MATRIX=>NONLINEAR_MATRICES%JACOBIANS(1)%PTR
            STIFFNESS_MATRIX=>LINEAR_MATRICES%MATRICES(1)%PTR
            LINEAR_MAPPING=>EQUATIONS_MAPPING%LINEAR_MAPPING
            NONLINEAR_MAPPING=>EQUATIONS_MAPPING%NONLINEAR_MAPPING
            FIELD_VARIABLE=>NONLINEAR_MAPPING%RESIDUAL_VARIABLES(1)%PTR
            FIELD_VAR_TYPE=FIELD_VARIABLE%VARIABLE_TYPE
            !               SOURCE_VECTOR=>EQUATIONS_MATRICES%SOURCE_VECTOR
            STIFFNESS_MATRIX%ELEMENT_MATRIX%MATRIX=0.0_DP
            NONLINEAR_MATRICES%ELEMENT_RESIDUAL%VECTOR=0.0_DP
            IF(ASSOCIATED(JACOBIAN_MATRIX)) UPDATE_JACOBIAN_MATRIX=JACOBIAN_MATRIX%UPDATE_JACOBIAN
          CASE(EQUATIONS_SET_TRANSIENT_NAVIER_STOKES_SUBTYPE)
            NONLINEAR_MAPPING=>EQUATIONS_MAPPING%NONLINEAR_MAPPING
            NONLINEAR_MATRICES=>EQUATIONS_MATRICES%NONLINEAR_MATRICES
            JACOBIAN_MATRIX=>NONLINEAR_MATRICES%JACOBIANS(1)%PTR
            JACOBIAN_MATRIX%ELEMENT_JACOBIAN%MATRIX=0.0_DP
            DYNAMIC_MATRICES=>EQUATIONS_MATRICES%DYNAMIC_MATRICES
            DYNAMIC_MAPPING=>EQUATIONS_MAPPING%DYNAMIC_MAPPING
            FIELD_VARIABLE=>NONLINEAR_MAPPING%RESIDUAL_VARIABLES(1)%PTR
            FIELD_VAR_TYPE=FIELD_VARIABLE%VARIABLE_TYPE
            LINEAR_MAPPING=>EQUATIONS_MAPPING%LINEAR_MAPPING
            IF(ASSOCIATED(JACOBIAN_MATRIX)) UPDATE_JACOBIAN_MATRIX=JACOBIAN_MATRIX%UPDATE_JACOBIAN
          CASE(EQUATIONS_SET_TRANSIENT1D_NAVIER_STOKES_SUBTYPE,EQUATIONS_SET_COUPLED1D0D_NAVIER_STOKES_SUBTYPE, &
            & EQUATIONS_SET_TRANSIENT1D_ADV_NAVIER_STOKES_SUBTYPE,EQUATIONS_SET_COUPLED1D0D_ADV_NAVIER_STOKES_SUBTYPE)
            NONLINEAR_MAPPING=>EQUATIONS_MAPPING%NONLINEAR_MAPPING
            NONLINEAR_MATRICES=>EQUATIONS_MATRICES%NONLINEAR_MATRICES
            JACOBIAN_MATRIX=>NONLINEAR_MATRICES%JACOBIANS(1)%PTR
            JACOBIAN_MATRIX%ELEMENT_JACOBIAN%MATRIX=0.0_DP
            DYNAMIC_MATRICES=>EQUATIONS_MATRICES%DYNAMIC_MATRICES
            DYNAMIC_MAPPING=>EQUATIONS_MAPPING%DYNAMIC_MAPPING
            FIELD_VARIABLE=>NONLINEAR_MAPPING%RESIDUAL_VARIABLES(1)%PTR
            FIELD_VAR_TYPE=FIELD_VARIABLE%VARIABLE_TYPE
            LINEAR_MAPPING=>EQUATIONS_MAPPING%LINEAR_MAPPING
            IF(ASSOCIATED(JACOBIAN_MATRIX)) UPDATE_JACOBIAN_MATRIX=JACOBIAN_MATRIX%UPDATE_JACOBIAN
            CALL FIELD_INTERPOLATION_PARAMETERS_ELEMENT_GET(FIELD_VALUES_SET_TYPE,ELEMENT_NUMBER,EQUATIONS%INTERPOLATION% &
              & MATERIALS_INTERP_PARAMETERS(FIELD_V_VARIABLE_TYPE)%PTR,ERR,ERROR,*999)
          CASE(EQUATIONS_SET_TRANSIENT_RBS_NAVIER_STOKES_SUBTYPE)
            NONLINEAR_MAPPING=>EQUATIONS_MAPPING%NONLINEAR_MAPPING
            NONLINEAR_MATRICES=>EQUATIONS_MATRICES%NONLINEAR_MATRICES
            JACOBIAN_MATRIX=>NONLINEAR_MATRICES%JACOBIANS(1)%PTR
            JACOBIAN_MATRIX%ELEMENT_JACOBIAN%MATRIX=0.0_DP
            DYNAMIC_MATRICES=>EQUATIONS_MATRICES%DYNAMIC_MATRICES
            DYNAMIC_MAPPING=>EQUATIONS_MAPPING%DYNAMIC_MAPPING
            FIELD_VARIABLE=>NONLINEAR_MAPPING%RESIDUAL_VARIABLES(1)%PTR
            FIELD_VAR_TYPE=FIELD_VARIABLE%VARIABLE_TYPE
            LINEAR_MAPPING=>EQUATIONS_MAPPING%LINEAR_MAPPING
            IF(ASSOCIATED(JACOBIAN_MATRIX)) UPDATE_JACOBIAN_MATRIX=JACOBIAN_MATRIX%UPDATE_JACOBIAN
          CASE(EQUATIONS_SET_MULTISCALE3D_NAVIER_STOKES_SUBTYPE, &
            &  EQUATIONS_SET_CONSTITUTIVE_MU_NAVIER_STOKES_SUBTYPE)
            DECOMPOSITION => DEPENDENT_FIELD%DECOMPOSITION
            MESH_COMPONENT_NUMBER = DECOMPOSITION%MESH_COMPONENT_NUMBER
            NONLINEAR_MAPPING=>EQUATIONS_MAPPING%NONLINEAR_MAPPING
            NONLINEAR_MATRICES=>EQUATIONS_MATRICES%NONLINEAR_MATRICES
            JACOBIAN_MATRIX=>NONLINEAR_MATRICES%JACOBIANS(1)%PTR
            JACOBIAN_MATRIX%ELEMENT_JACOBIAN%MATRIX=0.0_DP
            DYNAMIC_MATRICES=>EQUATIONS_MATRICES%DYNAMIC_MATRICES
            DYNAMIC_MAPPING=>EQUATIONS_MAPPING%DYNAMIC_MAPPING
            FIELD_VARIABLE=>NONLINEAR_MAPPING%RESIDUAL_VARIABLES(1)%PTR
            FIELD_VAR_TYPE=FIELD_VARIABLE%VARIABLE_TYPE
            LINEAR_MAPPING=>EQUATIONS_MAPPING%LINEAR_MAPPING
            IF(ASSOCIATED(JACOBIAN_MATRIX)) UPDATE_JACOBIAN_MATRIX=JACOBIAN_MATRIX%UPDATE_JACOBIAN
          CASE(EQUATIONS_SET_ALE_NAVIER_STOKES_SUBTYPE,EQUATIONS_SET_PGM_NAVIER_STOKES_SUBTYPE)
            INDEPENDENT_FIELD=>EQUATIONS%INTERPOLATION%INDEPENDENT_FIELD
            INDEPENDENT_BASIS=>INDEPENDENT_FIELD%DECOMPOSITION%DOMAIN(INDEPENDENT_FIELD%DECOMPOSITION%MESH_COMPONENT_NUMBER)% & 
              & PTR%TOPOLOGY%ELEMENTS%ELEMENTS(ELEMENT_NUMBER)%BASIS
            NONLINEAR_MAPPING=>EQUATIONS_MAPPING%NONLINEAR_MAPPING
            NONLINEAR_MATRICES=>EQUATIONS_MATRICES%NONLINEAR_MATRICES
            JACOBIAN_MATRIX=>NONLINEAR_MATRICES%JACOBIANS(1)%PTR
            JACOBIAN_MATRIX%ELEMENT_JACOBIAN%MATRIX=0.0_DP
            DYNAMIC_MATRICES=>EQUATIONS_MATRICES%DYNAMIC_MATRICES
            DYNAMIC_MAPPING=>EQUATIONS_MAPPING%DYNAMIC_MAPPING
            FIELD_VARIABLE=>NONLINEAR_MAPPING%RESIDUAL_VARIABLES(1)%PTR
            FIELD_VAR_TYPE=FIELD_VARIABLE%VARIABLE_TYPE
            LINEAR_MAPPING=>EQUATIONS_MAPPING%LINEAR_MAPPING
            IF(ASSOCIATED(JACOBIAN_MATRIX)) UPDATE_JACOBIAN_MATRIX=JACOBIAN_MATRIX%UPDATE_JACOBIAN
            CALL FIELD_INTERPOLATION_PARAMETERS_ELEMENT_GET(FIELD_MESH_VELOCITY_SET_TYPE,ELEMENT_NUMBER,EQUATIONS% & 
              & INTERPOLATION%INDEPENDENT_INTERP_PARAMETERS(FIELD_U_VARIABLE_TYPE)%PTR,ERR,ERROR,*999)
          CASE DEFAULT
            LOCAL_ERROR="Equations set subtype "//TRIM(NUMBER_TO_VSTRING(EQUATIONS_SET%specification(3),"*",ERR,ERROR))// &
              & " is not valid for a Navier-Stokes fluid type of a fluid mechanics equations set class."
            CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
          END SELECT
          CALL FIELD_INTERPOLATION_PARAMETERS_ELEMENT_GET(FIELD_VALUES_SET_TYPE,ELEMENT_NUMBER,EQUATIONS%INTERPOLATION% &
            & DEPENDENT_INTERP_PARAMETERS(FIELD_VAR_TYPE)%PTR,ERR,ERROR,*999)
          CALL FIELD_INTERPOLATION_PARAMETERS_ELEMENT_GET(FIELD_VALUES_SET_TYPE,ELEMENT_NUMBER,EQUATIONS%INTERPOLATION% &
            & GEOMETRIC_INTERP_PARAMETERS(FIELD_U_VARIABLE_TYPE)%PTR,ERR,ERROR,*999)
          CALL FIELD_PARAMETER_SET_GET_CONSTANT(MATERIALS_FIELD,FIELD_U_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE,1, &
              & MU_PARAM,err,error,*999)
            CALL FIELD_PARAMETER_SET_GET_CONSTANT(MATERIALS_FIELD,FIELD_U_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE,2, &
              & RHO_PARAM,err,error,*999)
            !Loop over all Gauss points 
            DO ng=1,QUADRATURE_SCHEME%NUMBER_OF_GAUSS
              CALL FIELD_INTERPOLATE_GAUSS(FIRST_PART_DERIV,BASIS_DEFAULT_QUADRATURE_SCHEME,ng,EQUATIONS%INTERPOLATION% &
                & DEPENDENT_INTERP_POINT(FIELD_VAR_TYPE)%PTR,ERR,ERROR,*999)
              CALL FIELD_INTERPOLATE_GAUSS(FIRST_PART_DERIV,BASIS_DEFAULT_QUADRATURE_SCHEME,ng,EQUATIONS%INTERPOLATION% &
                & GEOMETRIC_INTERP_POINT(FIELD_U_VARIABLE_TYPE)%PTR,ERR,ERROR,*999)
              CALL FIELD_INTERPOLATED_POINT_METRICS_CALCULATE(GEOMETRIC_BASIS%NUMBER_OF_XI,EQUATIONS%INTERPOLATION% &
                & GEOMETRIC_INTERP_POINT_METRICS(FIELD_U_VARIABLE_TYPE)%PTR,ERR,ERROR,*999)
              IF(EQUATIONS_SET%specification(3)==EQUATIONS_SET_ALE_NAVIER_STOKES_SUBTYPE.OR. &
                & EQUATIONS_SET%specification(3)==EQUATIONS_SET_PGM_NAVIER_STOKES_SUBTYPE) THEN
                CALL FIELD_INTERPOLATE_GAUSS(FIRST_PART_DERIV,BASIS_DEFAULT_QUADRATURE_SCHEME,ng,EQUATIONS%INTERPOLATION% &
                  & INDEPENDENT_INTERP_POINT(FIELD_U_VARIABLE_TYPE)%PTR,ERR,ERROR,*999)
                  W_VALUE(1)=EQUATIONS%INTERPOLATION%INDEPENDENT_INTERP_POINT(FIELD_U_VARIABLE_TYPE)%PTR%VALUES(1,NO_PART_DERIV)
                  W_VALUE(2)=EQUATIONS%INTERPOLATION%INDEPENDENT_INTERP_POINT(FIELD_U_VARIABLE_TYPE)%PTR%VALUES(2,NO_PART_DERIV)
                  IF(FIELD_VARIABLE%NUMBER_OF_COMPONENTS==4) THEN
                    W_VALUE(3)=EQUATIONS%INTERPOLATION%INDEPENDENT_INTERP_POINT(FIELD_U_VARIABLE_TYPE)%PTR%VALUES(3,NO_PART_DERIV)
                  END IF 
              ELSE
                W_VALUE=0.0_DP
              END IF

              ! Get the constitutive law (non-Newtonian) viscosity based on shear rate
              IF(EQUATIONS_SET%specification(3)==EQUATIONS_SET_CONSTITUTIVE_MU_NAVIER_STOKES_SUBTYPE) THEN
                ! Note the constant from the U_VARIABLE is a scale factor
                muScale = MU_PARAM
                ! Get the gauss point based value returned from the CellML solver
                CALL Field_ParameterSetGetLocalGaussPoint(MATERIALS_FIELD,FIELD_V_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE, &
                  & ng,ELEMENT_NUMBER,1,MU_PARAM,ERR,ERROR,*999)
                MU_PARAM=MU_PARAM*muScale
              END IF

              IF(EQUATIONS_SET%specification(3)==EQUATIONS_SET_STATIC_NAVIER_STOKES_SUBTYPE.OR.  &
                & EQUATIONS_SET%specification(3)==EQUATIONS_SET_STATIC_RBS_NAVIER_STOKES_SUBTYPE.OR. &
                & EQUATIONS_SET%specification(3)==EQUATIONS_SET_LAPLACE_NAVIER_STOKES_SUBTYPE.OR. &
                & EQUATIONS_SET%specification(3)==EQUATIONS_SET_TRANSIENT_NAVIER_STOKES_SUBTYPE.OR. &
                & EQUATIONS_SET%specification(3)==EQUATIONS_SET_TRANSIENT_RBS_NAVIER_STOKES_SUBTYPE.OR. &
                & EQUATIONS_SET%specification(3)==EQUATIONS_SET_MULTISCALE3D_NAVIER_STOKES_SUBTYPE.OR. &
                & EQUATIONS_SET%specification(3)==EQUATIONS_SET_CONSTITUTIVE_MU_NAVIER_STOKES_SUBTYPE.OR. &
                & EQUATIONS_SET%specification(3)==EQUATIONS_SET_QUASISTATIC_NAVIER_STOKES_SUBTYPE.OR. &
                & EQUATIONS_SET%specification(3)==EQUATIONS_SET_ALE_NAVIER_STOKES_SUBTYPE.OR. &
                & EQUATIONS_SET%specification(3)==EQUATIONS_SET_PGM_NAVIER_STOKES_SUBTYPE) THEN

                U_VALUE(1)=EQUATIONS%INTERPOLATION%DEPENDENT_INTERP_POINT(FIELD_VAR_TYPE)%PTR%VALUES(1,NO_PART_DERIV)
                U_VALUE(2)=EQUATIONS%INTERPOLATION%DEPENDENT_INTERP_POINT(FIELD_VAR_TYPE)%PTR%VALUES(2,NO_PART_DERIV)
                U_DERIV(1,1)=EQUATIONS%INTERPOLATION%DEPENDENT_INTERP_POINT(FIELD_VAR_TYPE)%PTR%VALUES(1,PART_DERIV_S1)
                U_DERIV(1,2)=EQUATIONS%INTERPOLATION%DEPENDENT_INTERP_POINT(FIELD_VAR_TYPE)%PTR%VALUES(1,PART_DERIV_S2)
                U_DERIV(2,1)=EQUATIONS%INTERPOLATION%DEPENDENT_INTERP_POINT(FIELD_VAR_TYPE)%PTR%VALUES(2,PART_DERIV_S1)
                U_DERIV(2,2)=EQUATIONS%INTERPOLATION%DEPENDENT_INTERP_POINT(FIELD_VAR_TYPE)%PTR%VALUES(2,PART_DERIV_S2)
                IF(FIELD_VARIABLE%NUMBER_OF_COMPONENTS==4) THEN
                  U_VALUE(3)=EQUATIONS%INTERPOLATION%DEPENDENT_INTERP_POINT(FIELD_VAR_TYPE)%PTR%VALUES(3,NO_PART_DERIV)
                  U_DERIV(3,1)=EQUATIONS%INTERPOLATION%DEPENDENT_INTERP_POINT(FIELD_VAR_TYPE)%PTR%VALUES(3,PART_DERIV_S1)
                  U_DERIV(3,2)=EQUATIONS%INTERPOLATION%DEPENDENT_INTERP_POINT(FIELD_VAR_TYPE)%PTR%VALUES(3,PART_DERIV_S2)
                  U_DERIV(3,3)=EQUATIONS%INTERPOLATION%DEPENDENT_INTERP_POINT(FIELD_VAR_TYPE)%PTR%VALUES(3,PART_DERIV_S3)
                  U_DERIV(1,3)=EQUATIONS%INTERPOLATION%DEPENDENT_INTERP_POINT(FIELD_VAR_TYPE)%PTR%VALUES(1,PART_DERIV_S3)
                  U_DERIV(2,3)=EQUATIONS%INTERPOLATION%DEPENDENT_INTERP_POINT(FIELD_VAR_TYPE)%PTR%VALUES(2,PART_DERIV_S3)
                ELSE
                  U_VALUE(3)=0.0_DP
                  U_DERIV(3,1)=0.0_DP
                  U_DERIV(3,2)=0.0_DP
                  U_DERIV(3,3)=0.0_DP
                  U_DERIV(1,3)=0.0_DP
                  U_DERIV(2,3)=0.0_DP
                END IF
                !Start with calculation of partial matrices
                !Here W_VALUES must be ZERO if ALE part of linear matrix
                W_VALUE=0.0_DP
              END IF

              IF(EQUATIONS_SET%specification(3)==EQUATIONS_SET_STATIC_NAVIER_STOKES_SUBTYPE.OR.  &
                & EQUATIONS_SET%specification(3)==EQUATIONS_SET_STATIC_RBS_NAVIER_STOKES_SUBTYPE.OR. &
                & EQUATIONS_SET%specification(3)==EQUATIONS_SET_LAPLACE_NAVIER_STOKES_SUBTYPE.OR. &
                & EQUATIONS_SET%specification(3)==EQUATIONS_SET_TRANSIENT_NAVIER_STOKES_SUBTYPE.OR. &
                & EQUATIONS_SET%specification(3)==EQUATIONS_SET_TRANSIENT_RBS_NAVIER_STOKES_SUBTYPE.OR. &
                & EQUATIONS_SET%specification(3)==EQUATIONS_SET_MULTISCALE3D_NAVIER_STOKES_SUBTYPE.OR. &
                & EQUATIONS_SET%specification(3)==EQUATIONS_SET_CONSTITUTIVE_MU_NAVIER_STOKES_SUBTYPE.OR. &
                & EQUATIONS_SET%specification(3)==EQUATIONS_SET_QUASISTATIC_NAVIER_STOKES_SUBTYPE.OR. &
                & EQUATIONS_SET%specification(3)==EQUATIONS_SET_ALE_NAVIER_STOKES_SUBTYPE.OR. &
                & EQUATIONS_SET%specification(3)==EQUATIONS_SET_PGM_NAVIER_STOKES_SUBTYPE) THEN
                !Loop over field components
                mhs=0

                DO mh=1,FIELD_VARIABLE%NUMBER_OF_COMPONENTS-1
                  MESH_COMPONENT1=FIELD_VARIABLE%COMPONENTS(mh)%MESH_COMPONENT_NUMBER
                  DEPENDENT_BASIS1=>DEPENDENT_FIELD%DECOMPOSITION%DOMAIN(MESH_COMPONENT1)%PTR% &
                    & TOPOLOGY%ELEMENTS%ELEMENTS(ELEMENT_NUMBER)%BASIS
                  QUADRATURE_SCHEME1=>DEPENDENT_BASIS1%QUADRATURE%QUADRATURE_SCHEME_MAP(BASIS_DEFAULT_QUADRATURE_SCHEME)%PTR
                  JGW=EQUATIONS%INTERPOLATION%GEOMETRIC_INTERP_POINT_METRICS(FIELD_U_VARIABLE_TYPE)%PTR%JACOBIAN* &
                    & QUADRATURE_SCHEME1%GAUSS_WEIGHTS(ng)

                  DO ms=1,DEPENDENT_BASIS1%NUMBER_OF_ELEMENT_PARAMETERS
                    mhs=mhs+1
                    nhs=0
                    IF(UPDATE_JACOBIAN_MATRIX) THEN
                      !Loop over element columns
                      DO nh=1,FIELD_VARIABLE%NUMBER_OF_COMPONENTS-1
                        MESH_COMPONENT2=FIELD_VARIABLE%COMPONENTS(nh)%MESH_COMPONENT_NUMBER
                        DEPENDENT_BASIS2=>DEPENDENT_FIELD%DECOMPOSITION%DOMAIN(MESH_COMPONENT2)%PTR% &
                          & TOPOLOGY%ELEMENTS%ELEMENTS(ELEMENT_NUMBER)%BASIS
                        QUADRATURE_SCHEME2=>DEPENDENT_BASIS2%QUADRATURE%QUADRATURE_SCHEME_MAP&
                          &(BASIS_DEFAULT_QUADRATURE_SCHEME)%PTR                       
                        DO ns=1,DEPENDENT_BASIS2%NUMBER_OF_ELEMENT_PARAMETERS
                          nhs=nhs+1
                          !Calculate some general values needed below
                          DO ni=1,DEPENDENT_BASIS2%NUMBER_OF_XI
                            DO mi=1,DEPENDENT_BASIS1%NUMBER_OF_XI
                              DXI_DX(mi,ni)=EQUATIONS%INTERPOLATION%GEOMETRIC_INTERP_POINT_METRICS(FIELD_U_VARIABLE_TYPE)%PTR% &
                                & DXI_DX(mi,ni)
                            END DO
                            DPHIMS_DXI(ni)=QUADRATURE_SCHEME1%GAUSS_BASIS_FNS(ms,PARTIAL_DERIVATIVE_FIRST_DERIVATIVE_MAP(ni),ng)
                            DPHINS_DXI(ni)=QUADRATURE_SCHEME2%GAUSS_BASIS_FNS(ns,PARTIAL_DERIVATIVE_FIRST_DERIVATIVE_MAP(ni),ng)
                          END DO !ni
                          PHIMS=QUADRATURE_SCHEME1%GAUSS_BASIS_FNS(ms,NO_PART_DERIV,ng)
                          PHINS=QUADRATURE_SCHEME2%GAUSS_BASIS_FNS(ns,NO_PART_DERIV,ng)
                          SUM=0.0_DP
                          IF(UPDATE_JACOBIAN_MATRIX) THEN
                            !Calculate J1 only
                            DO ni=1,DEPENDENT_BASIS1%NUMBER_OF_XI
                              SUM=SUM+(PHINS*U_DERIV(mh,ni)*DXI_DX(ni,nh)*PHIMS*RHO_PARAM)
                            END DO 
                            !Calculate MATRIX  
                            JACOBIAN_MATRIX%ELEMENT_JACOBIAN%MATRIX(mhs,nhs)=JACOBIAN_MATRIX%ELEMENT_JACOBIAN%MATRIX(mhs,nhs) &
                             & +SUM*JGW
                            !Calculate J2 only
                            IF(nh==mh) THEN 
                              SUM=0.0_DP
                              !Calculate SUM 
                              DO x=1,DEPENDENT_BASIS1%NUMBER_OF_XI
                                DO mi=1,DEPENDENT_BASIS2%NUMBER_OF_XI
                                  SUM=SUM+RHO_PARAM*(U_VALUE(x)-W_VALUE(x))*DPHINS_DXI(mi)*DXI_DX(mi,x)*PHIMS
                                END DO !mi
                              END DO !x
                              !Calculate MATRIX
                              JACOBIAN_MATRIX%ELEMENT_JACOBIAN%MATRIX(mhs,nhs)=JACOBIAN_MATRIX%ELEMENT_JACOBIAN%MATRIX(mhs,nhs) &
                               & +SUM*JGW
                            END IF
                          END IF
                        END DO !ns    
                      END DO !nh
                    END IF
                  END DO !ms
                END DO !mh
                ! Stabilisation terms
                IF(EQUATIONS_SET%specification(3)==EQUATIONS_SET_TRANSIENT_RBS_NAVIER_STOKES_SUBTYPE.OR. &
                  & EQUATIONS_SET%specification(3)==EQUATIONS_SET_STATIC_RBS_NAVIER_STOKES_SUBTYPE.OR. &
                  & EQUATIONS_SET%specification(3)==EQUATIONS_SET_MULTISCALE3D_NAVIER_STOKES_SUBTYPE) THEN
                  CALL NavierStokes_ResidualBasedStabilisation(EQUATIONS_SET,ELEMENT_NUMBER,ng,MU_PARAM,RHO_PARAM,.TRUE., &
                    & ERR,ERROR,*999)
                END IF
              END IF

              !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
              !!!!!                                        !!!!!
              !!!!!         1 D  T R A N S I E N T         !!!!!
              !!!!!                                        !!!!!
              !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

              !Start with Matrix Calculations
              IF(EQUATIONS_SET%specification(3)==EQUATIONS_SET_TRANSIENT1D_NAVIER_STOKES_SUBTYPE .OR. &
               & EQUATIONS_SET%specification(3)==EQUATIONS_SET_COUPLED1D0D_NAVIER_STOKES_SUBTYPE .OR. &
               & EQUATIONS_SET%specification(3)==EQUATIONS_SET_TRANSIENT1D_ADV_NAVIER_STOKES_SUBTYPE .OR. &
               & EQUATIONS_SET%specification(3)==EQUATIONS_SET_COUPLED1D0D_ADV_NAVIER_STOKES_SUBTYPE) THEN
                Q_VALUE=EQUATIONS%INTERPOLATION%DEPENDENT_INTERP_POINT(FIELD_VAR_TYPE)%PTR%VALUES(1,NO_PART_DERIV)
                Q_DERIV=EQUATIONS%INTERPOLATION%DEPENDENT_INTERP_POINT(FIELD_VAR_TYPE)%PTR%VALUES(1,FIRST_PART_DERIV)
                A_VALUE=EQUATIONS%INTERPOLATION%DEPENDENT_INTERP_POINT(FIELD_VAR_TYPE)%PTR%VALUES(2,NO_PART_DERIV)
                A_DERIV=EQUATIONS%INTERPOLATION%DEPENDENT_INTERP_POINT(FIELD_VAR_TYPE)%PTR%VALUES(2,FIRST_PART_DERIV)
                CALL FIELD_PARAMETER_SET_GET_CONSTANT(MATERIALS_FIELD,FIELD_U_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE,3, &
                 & alpha,err,error,*999)
                CALL FIELD_INTERPOLATE_GAUSS(FIRST_PART_DERIV,BASIS_DEFAULT_QUADRATURE_SCHEME,ng,EQUATIONS%INTERPOLATION% &
                  & MATERIALS_INTERP_POINT(FIELD_V_VARIABLE_TYPE)%PTR,ERR,ERROR,*999)
                A0_PARAM=EQUATIONS%INTERPOLATION%MATERIALS_INTERP_POINT(FIELD_V_VARIABLE_TYPE)%PTR%VALUES(1,NO_PART_DERIV)
                A0_DERIV=EQUATIONS%INTERPOLATION%MATERIALS_INTERP_POINT(FIELD_V_VARIABLE_TYPE)%PTR%VALUES(1,FIRST_PART_DERIV)
                E_PARAM=EQUATIONS%INTERPOLATION%MATERIALS_INTERP_POINT(FIELD_V_VARIABLE_TYPE)%PTR%VALUES(2,NO_PART_DERIV)
                E_DERIV=EQUATIONS%INTERPOLATION%MATERIALS_INTERP_POINT(FIELD_V_VARIABLE_TYPE)%PTR%VALUES(2,FIRST_PART_DERIV)
                H_PARAM=EQUATIONS%INTERPOLATION%MATERIALS_INTERP_POINT(FIELD_V_VARIABLE_TYPE)%PTR%VALUES(3,NO_PART_DERIV)
                H_DERIV=EQUATIONS%INTERPOLATION%MATERIALS_INTERP_POINT(FIELD_V_VARIABLE_TYPE)%PTR%VALUES(3,FIRST_PART_DERIV)
                beta = (4.0_DP*SQRT(PI)*E_PARAM*H_PARAM)/(3.0_DP*A0_PARAM)     !(kg/m2/s2)

                ! If A goes negative during nonlinear iteration, give ZERO_TOLERANCE value to avoid segfault
                IF(A_VALUE < A0_PARAM*0.001_DP) THEN
                  A_VALUE = A0_PARAM*0.001_DP
                END IF

                mhs=0
                !Loop Over Element Rows
                DO mh=1,FIELD_VARIABLE%NUMBER_OF_COMPONENTS
                  MESH_COMPONENT1=FIELD_VARIABLE%COMPONENTS(mh)%MESH_COMPONENT_NUMBER
                  DEPENDENT_BASIS1=>DEPENDENT_FIELD%DECOMPOSITION%DOMAIN(MESH_COMPONENT1)%PTR% &
                    & TOPOLOGY%ELEMENTS%ELEMENTS(ELEMENT_NUMBER)%BASIS
                  QUADRATURE_SCHEME1=>DEPENDENT_BASIS1%QUADRATURE%QUADRATURE_SCHEME_MAP(BASIS_DEFAULT_QUADRATURE_SCHEME)%PTR
                  JGW=EQUATIONS%INTERPOLATION%GEOMETRIC_INTERP_POINT_METRICS(FIELD_U_VARIABLE_TYPE)%PTR%JACOBIAN* &
                    & QUADRATURE_SCHEME1%GAUSS_WEIGHTS(ng)
                  ELEMENTS_TOPOLOGY=>FIELD_VARIABLE%COMPONENTS(mh)%DOMAIN%TOPOLOGY%ELEMENTS
                  DXI_DX(1,1)=0.0_DP
                  !Calculate dxi_dx in 3D
                  DO xiIdx=1,DEPENDENT_BASIS1%NUMBER_OF_XI
                    DO coordIdx=1,EQUATIONS%INTERPOLATION%GEOMETRIC_INTERP_POINT_METRICS(FIELD_U_VARIABLE_TYPE) &
                      & %PTR%NUMBER_OF_X_DIMENSIONS
                      DXI_DX(1,1)=DXI_DX(1,1)+(EQUATIONS%INTERPOLATION%GEOMETRIC_INTERP_POINT_METRICS(FIELD_U_VARIABLE_TYPE)% &
                        & PTR%DXI_DX(xiIdx,coordIdx))**2.0_DP
                    END DO !coordIdx
                  END DO !xiIdx
                  DXI_DX(1,1)=SQRT(DXI_DX(1,1))
                  !Loop Over Element rows
                  DO ms=1,DEPENDENT_BASIS1%NUMBER_OF_ELEMENT_PARAMETERS
                    PHIMS=QUADRATURE_SCHEME1%GAUSS_BASIS_FNS(ms,NO_PART_DERIV,ng)
                    DPHIMS_DXI(1)=QUADRATURE_SCHEME1%GAUSS_BASIS_FNS(ms,FIRST_PART_DERIV,ng)
                    mhs=mhs+1
                    nhs=0
                    !Loop Over Element Columns
                    DO nh=1,FIELD_VARIABLE%NUMBER_OF_COMPONENTS
                      MESH_COMPONENT2=FIELD_VARIABLE%COMPONENTS(nh)%MESH_COMPONENT_NUMBER
                      DEPENDENT_BASIS2=>DEPENDENT_FIELD%DECOMPOSITION%DOMAIN(MESH_COMPONENT2)%PTR% &
                        & TOPOLOGY%ELEMENTS%ELEMENTS(ELEMENT_NUMBER)%BASIS
                      QUADRATURE_SCHEME2=>DEPENDENT_BASIS2%QUADRATURE%QUADRATURE_SCHEME_MAP&
                        &(BASIS_DEFAULT_QUADRATURE_SCHEME)%PTR
                      DO ns=1,DEPENDENT_BASIS2%NUMBER_OF_ELEMENT_PARAMETERS
                        PHINS=QUADRATURE_SCHEME2%GAUSS_BASIS_FNS(ns,NO_PART_DERIV,ng)
                        DPHINS_DXI(1)=QUADRATURE_SCHEME1%GAUSS_BASIS_FNS(ns,FIRST_PART_DERIV,ng)
                        nhs=nhs+1
                        IF(UPDATE_JACOBIAN_MATRIX) THEN

                          !Momentum Equation (dF/dQ)
                          IF(mh==1 .AND. nh==1) THEN
                            SUM=((alpha*2.0_DP*PHINS*Q_DERIV/A_VALUE +  &
                              & alpha*2.0_DP*Q_VALUE*DPHINS_DXI(1)/A_VALUE+ &
                              & (-2.0_DP)*alpha*Q_VALUE*PHINS*A_DERIV/(A_VALUE**2.0_DP))*DXI_DX(1,1)+ &   !Convective
                              & ((PHINS/A_VALUE)))*PHIMS                                                  !Viscosity
                            JACOBIAN_MATRIX%ELEMENT_JACOBIAN%MATRIX(mhs,nhs)= &
                              & JACOBIAN_MATRIX%ELEMENT_JACOBIAN%MATRIX(mhs,nhs)+SUM*JGW
                          END IF

                          !Momentum Equation (dF/dA)
                          IF(mh==1 .AND. nh==2) THEN
                            SUM=((((-2.0_DP*alpha*Q_VALUE*PHINS*Q_DERIV)/(A_VALUE**2.0_DP))+ & 
                              & ((2.0_DP*alpha*PHINS*(Q_VALUE**2.0_DP)*A_DERIV)/(A_VALUE**3.0_DP))+ &             
                              & (-alpha*((Q_VALUE/A_VALUE)**2.0_DP)*DPHINS_DXI(1))+ &                           !Convective
                              & ((0.5_DP*PHINS*(1.0_DP/SQRT(A_VALUE))*A_DERIV+SQRT(A_VALUE)*DPHINS_DXI(1))+ &   !Area Gradient
                              & ((1.0_DP/SQRT(A0_PARAM))-((3.0_DP/(A0_PARAM))*SQRT(A_VALUE)))*(A0_DERIV) + &    !Ref Area Gradient
                              & (2.0_DP*PHINS*1.5_DP*SQRT(A_VALUE))*H_DERIV/H_PARAM+ &                          !Thickness Gradient
                              & (2.0_DP*PHINS*1.5_DP*SQRT(A_VALUE))*E_DERIV/E_PARAM) &                          !Elasticity Gradient
                              & *beta/(2.0_DP*RHO_PARAM))*DXI_DX(1,1)+(-PHINS*Q_VALUE/A_VALUE**2.0_DP))*PHIMS   !Viscosity
                            JACOBIAN_MATRIX%ELEMENT_JACOBIAN%MATRIX(mhs,nhs)= &
                              & JACOBIAN_MATRIX%ELEMENT_JACOBIAN%MATRIX(mhs,nhs)+SUM*JGW
                          END IF

                        END IF
                      END DO !ns
                    END DO !nh
                  END DO !ms
                END DO !mh
              END IF
            END DO !ng

          IF(EQUATIONS_SET%specification(3)==EQUATIONS_SET_TRANSIENT1D_NAVIER_STOKES_SUBTYPE .OR. &
            & EQUATIONS_SET%specification(3)==EQUATIONS_SET_COUPLED1D0D_NAVIER_STOKES_SUBTYPE .OR. &
            & EQUATIONS_SET%specification(3)==EQUATIONS_SET_TRANSIENT1D_ADV_NAVIER_STOKES_SUBTYPE .OR. &
            & EQUATIONS_SET%specification(3)==EQUATIONS_SET_COUPLED1D0D_ADV_NAVIER_STOKES_SUBTYPE) THEN
              ELEMENTS_TOPOLOGY=>DEPENDENT_FIELD%VARIABLE_TYPE_MAP(FIELD_U_VARIABLE_TYPE)%PTR%components(1)%domain%topology%elements
              numberOfElementNodes=ELEMENTS_TOPOLOGY%ELEMENTS(ELEMENT_NUMBER)%BASIS%NUMBER_OF_NODES
              numberOfParameters=ELEMENTS_TOPOLOGY%MAXIMUM_NUMBER_OF_ELEMENT_PARAMETERS  
              firstNode=ELEMENTS_TOPOLOGY%ELEMENTS(ELEMENT_NUMBER)%ELEMENT_NODES(1)
              lastNode=ELEMENTS_TOPOLOGY%ELEMENTS(ELEMENT_NUMBER)%ELEMENT_NODES(numberOfElementNodes)
              !Get material constants
              CALL FIELD_PARAMETER_SET_GET_CONSTANT(MATERIALS_FIELD,FIELD_U_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE,2, &
                & RHO_PARAM,err,error,*999)
                
              !!!-- B R A N C H   F L U X   U P W I N D I N G --!!!
              !----------------------------------------------------
              ! In order to enforce conservation of mass and momentum across discontinuous
              ! branching topologies, flux is upwinded against the conservative branch values 
              ! established by the characteristic solver.
              DO nodeIdx=1,numberOfElementNodes
                nodeNumber=ELEMENTS_TOPOLOGY%ELEMENTS(ELEMENT_NUMBER)%ELEMENT_NODES(nodeIdx)
                numberOfVersions=ELEMENTS_TOPOLOGY%DOMAIN%TOPOLOGY%NODES%NODES(nodeNumber)%DERIVATIVES(1)%numberOfVersions

                ! Find the branch node on this element
                IF(numberOfVersions>1) THEN                  
                  derivativeIdx = 1
                  elementVersionNumber=ELEMENTS_TOPOLOGY%DOMAIN%TOPOLOGY%ELEMENTS%ELEMENTS(ELEMENT_NUMBER)% &
                    & elementVersions(derivativeIdx,nodeIdx)

                  ! Find the wave direction - incoming or outgoing
                  DO componentIdx = 1,2
                    CALL Field_ParameterSetGetLocalNode(INDEPENDENT_FIELD,FIELD_U_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE, & 
                     & elementVersionNumber,derivativeIdx,nodeNumber,componentIdx,normalWave,err,error,*999)
                    IF(ABS(normalWave) > ZERO_TOLERANCE) THEN
                      normal = normalWave
                    END IF
                  END DO

                  ! Get materials parameters for node on this element
                  CALL Field_ParameterSetGetLocalNode(MATERIALS_FIELD,FIELD_V_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE, &
                    & elementVersionNumber,derivativeIdx,nodeNumber,1,A0_PARAM,err,error,*999)
                  CALL Field_ParameterSetGetLocalNode(MATERIALS_FIELD,FIELD_V_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE, &
                    & elementVersionNumber,derivativeIdx,nodeNumber,2,E_PARAM,err,error,*999)
                  CALL Field_ParameterSetGetLocalNode(MATERIALS_FIELD,FIELD_V_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE, &
                    & elementVersionNumber,derivativeIdx,nodeNumber,3,H_PARAM,err,error,*999)
                  beta = (4.0_DP*(SQRT(PI))*E_PARAM*H_PARAM)/(3.0_DP*A0_PARAM)

                  !Get current Q & A values
                  CALL Field_ParameterSetGetLocalNode(DEPENDENT_FIELD,FIELD_U_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE, &
                    & elementVersionNumber,derivativeIdx,nodeNumber,1,Q_VALUE,err,error,*999)         
                  CALL Field_ParameterSetGetLocalNode(DEPENDENT_FIELD,FIELD_U_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE, &
                    & elementVersionNumber,derivativeIdx,nodeNumber,2,A_VALUE,err,error,*999)

                  !Momentum Equation, d/dQ
                  momentum1 = (-alpha*2.0_DP*Q_VALUE/A_VALUE)*normal

                  !Momentum Equation, d/dA
                  momentum2 = (alpha*(Q_VALUE/A_VALUE)**2.0_DP-1.5_DP*(A_VALUE**0.5_DP)*(beta/(3.0_DP*RHO_PARAM)))*normal

                  !Continuity Equation , d/dQ
                  mass = -1.0_DP*normal

                  !Add momentum/mass contributions to first/last node accordingly
                  IF(nodeNumber==firstNode) THEN
                    JACOBIAN_MATRIX%ELEMENT_JACOBIAN%MATRIX(1,1)= &
                      & JACOBIAN_MATRIX%ELEMENT_JACOBIAN%MATRIX(1,1)+momentum1
                    JACOBIAN_MATRIX%ELEMENT_JACOBIAN%MATRIX(1,numberOfParameters+1)= &
                      & JACOBIAN_MATRIX%ELEMENT_JACOBIAN%MATRIX(1,numberOfParameters+1)+momentum2
                    JACOBIAN_MATRIX%ELEMENT_JACOBIAN%MATRIX(numberOfParameters+1,1)= &
                      & JACOBIAN_MATRIX%ELEMENT_JACOBIAN%MATRIX(numberOfParameters+1,1)+mass
                  ELSE IF(nodeNumber==lastNode) THEN
                    JACOBIAN_MATRIX%ELEMENT_JACOBIAN%MATRIX(numberOfParameters,numberOfParameters)= &
                      & JACOBIAN_MATRIX%ELEMENT_JACOBIAN%MATRIX(numberOfParameters,numberOfParameters)+momentum1
                    JACOBIAN_MATRIX%ELEMENT_JACOBIAN%MATRIX(numberOfParameters,2*numberOfParameters)= &
                      & JACOBIAN_MATRIX%ELEMENT_JACOBIAN%MATRIX(numberOfParameters,2*numberOfParameters)+momentum2
                    JACOBIAN_MATRIX%ELEMENT_JACOBIAN%MATRIX(2*numberOfParameters,numberOfParameters)= &
                      & JACOBIAN_MATRIX%ELEMENT_JACOBIAN%MATRIX(2*numberOfParameters,numberOfParameters)+mass
                  END IF
                END IF !version>1
              END DO !loop nodes

          END IF

        CASE DEFAULT
          LOCAL_ERROR="Equations set subtype "//TRIM(NUMBER_TO_VSTRING(EQUATIONS_SET%SPECIFICATION(3),"*",ERR,ERROR))// &
            & " is not valid for a Navier-Stokes equation type of a fluid mechanics equations set class."
          CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
        END SELECT
      ELSE
        CALL FlagError("Equations set equations is not associated.",ERR,ERROR,*999)
      END IF
    ELSE
      CALL FlagError("Equations set is not associated.",ERR,ERROR,*999)
    ENDIF

    EXITS("NavierStokes_FiniteElementJacobianEvaluate")
    RETURN
999 ERRORSEXITS("NavierStokes_FiniteElementJacobianEvaluate",ERR,ERROR)
    RETURN 1
    
  END SUBROUTINE NavierStokes_FiniteElementJacobianEvaluate

  !
  !================================================================================================================================
  !

  !>Sets up the Navier-Stokes problem post solve.
  SUBROUTINE NAVIER_STOKES_POST_SOLVE(SOLVER,ERR,ERROR,*)

    !Argument variables
    TYPE(SOLVER_TYPE), POINTER :: SOLVER
    INTEGER(INTG), INTENT(OUT) :: ERR
    TYPE(VARYING_STRING), INTENT(OUT) :: ERROR
    !Local Variables
    TYPE(CONTROL_LOOP_TYPE), POINTER :: CONTROL_LOOP
    TYPE(FIELD_TYPE), POINTER :: dependentField
    TYPE(FIELD_VARIABLE_TYPE), POINTER :: fieldVariable
    TYPE(SOLVER_TYPE), POINTER :: SOLVER2
    TYPE(SOLVERS_TYPE), POINTER :: SOLVERS
    TYPE(VARYING_STRING) :: LOCAL_ERROR
    INTEGER(INTG) :: iteration,timestep,outputIteration,equationsSetNumber
    REAL(DP) :: startTime,stopTime,currentTime,timeIncrement

    ENTERS("NAVIER_STOKES_POST_SOLVE",ERR,ERROR,*999)
    NULLIFY(SOLVER2)
    NULLIFY(SOLVERS)
    NULLIFY(dependentField)
    NULLIFY(fieldVariable)

    IF(ASSOCIATED(SOLVER)) THEN
      SOLVERS=>SOLVER%SOLVERS
      IF(ASSOCIATED(SOLVERS)) THEN
        CONTROL_LOOP=>SOLVERS%CONTROL_LOOP
        IF(ASSOCIATED(CONTROL_LOOP)) THEN
          IF(ASSOCIATED(CONTROL_LOOP%PROBLEM)) THEN 
            IF(.NOT.ALLOCATED(CONTROL_LOOP%problem%specification)) THEN
              CALL FlagError("Problem specification is not allocated.",err,error,*999)
            ELSE IF(SIZE(CONTROL_LOOP%problem%specification,1)<3) THEN
              CALL FlagError("Problem specification must have three entries for a Navier-Stokes problem.",err,error,*999)
            END IF
            SELECT CASE(CONTROL_LOOP%PROBLEM%specification(3))
            CASE(PROBLEM_STATIC_NAVIER_STOKES_SUBTYPE,PROBLEM_LAPLACE_NAVIER_STOKES_SUBTYPE)
              CALL NAVIER_STOKES_POST_SOLVE_OUTPUT_DATA(SOLVER,err,error,*999)
            CASE(PROBLEM_PGM_NAVIER_STOKES_SUBTYPE)
              CALL NAVIER_STOKES_POST_SOLVE_OUTPUT_DATA(SOLVER,err,error,*999)
            CASE(PROBLEM_QUASISTATIC_NAVIER_STOKES_SUBTYPE)
              CALL NAVIER_STOKES_POST_SOLVE_OUTPUT_DATA(SOLVER,err,error,*999)
            CASE(PROBLEM_TRANSIENT_NAVIER_STOKES_SUBTYPE)
              CALL NAVIER_STOKES_POST_SOLVE_OUTPUT_DATA(SOLVER,err,error,*999)
            CASE(PROBLEM_TRANSIENT1D_NAVIER_STOKES_SUBTYPE)
              SELECT CASE(SOLVER%SOLVE_TYPE)
              CASE(SOLVER_NONLINEAR_TYPE)
                ! Characteristic solver- copy branch Q,A values to new parameter set
                dependentField=>SOLVER%SOLVER_EQUATIONS%SOLVER_MAPPING%EQUATIONS_SETS(1)%PTR%DEPENDENT%DEPENDENT_FIELD
                CALL FIELD_VARIABLE_GET(dependentField,FIELD_U_VARIABLE_TYPE,fieldVariable,ERR,ERROR,*999)
                IF(.NOT.ASSOCIATED(fieldVariable%PARAMETER_SETS%SET_TYPE(FIELD_UPWIND_VALUES_SET_TYPE)%PTR)) THEN
                  CALL FIELD_PARAMETER_SET_CREATE(dependentField,FIELD_U_VARIABLE_TYPE, &
                   & FIELD_UPWIND_VALUES_SET_TYPE,ERR,ERROR,*999)
                END IF
                iteration = CONTROL_LOOP%WHILE_LOOP%ITERATION_NUMBER
                IF(iteration == 1) THEN
                  CALL FIELD_PARAMETER_SETS_COPY(dependentField,FIELD_U_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE, &
                   & FIELD_UPWIND_VALUES_SET_TYPE,1.0_DP,ERR,ERROR,*999)
                END IF
              CASE(SOLVER_DYNAMIC_TYPE)
                ! Navier-Stokes solver: do nothing
              CASE DEFAULT
                LOCAL_ERROR="The solver type of "//TRIM(NUMBER_TO_VSTRING(SOLVER%SOLVE_TYPE,"*",ERR,ERROR))// &
                  & " is invalid for a 1D Navier-Stokes problem."
                CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
              END SELECT
            CASE(PROBLEM_COUPLED1D0D_NAVIER_STOKES_SUBTYPE)
              IF(ASSOCIATED(SOLVER%SOLVERS%CONTROL_LOOP%WHILE_LOOP)) THEN
                SELECT CASE(SOLVER%GLOBAL_NUMBER)
                CASE(1)
                  ! Characteristic solver- copy branch Q,A values to new parameter set
                  dependentField=>SOLVER%SOLVER_EQUATIONS%SOLVER_MAPPING%EQUATIONS_SETS(1)%PTR%DEPENDENT%DEPENDENT_FIELD
                  CALL FIELD_VARIABLE_GET(dependentField,FIELD_U_VARIABLE_TYPE,fieldVariable,ERR,ERROR,*999)
                  IF(.NOT.ASSOCIATED(fieldVariable%PARAMETER_SETS%SET_TYPE(FIELD_UPWIND_VALUES_SET_TYPE)%PTR)) THEN
                    CALL FIELD_PARAMETER_SET_CREATE(dependentField,FIELD_U_VARIABLE_TYPE, &
                     & FIELD_UPWIND_VALUES_SET_TYPE,ERR,ERROR,*999)
                  END IF
                  CALL FIELD_PARAMETER_SETS_COPY(dependentField,FIELD_U_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE, &
                   & FIELD_UPWIND_VALUES_SET_TYPE,1.0_DP,ERR,ERROR,*999)

                CASE(2)
                  ! ! 1D Navier-Stokes solver
                  IF(CONTROL_LOOP%CONTROL_LOOP_LEVEL==3) THEN
                    ! check characteristic/ N-S convergence at branches
  !                    CALL NavierStokes_CoupleCharacteristics(CONTROL_LOOP,SOLVER,ERR,ERROR,*999)
                  END IF
                CASE DEFAULT
                  LOCAL_ERROR="The solver global number of "//TRIM(NUMBER_TO_VSTRING(SOLVER%GLOBAL_NUMBER,"*",ERR,ERROR))// &
                    & " is invalid for the iterative 1D-0D coupled Navier-Stokes problem."
                  CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
                END SELECT
              ELSE IF(ASSOCIATED(SOLVER%SOLVERS%CONTROL_LOOP%SIMPLE_LOOP)) THEN
                IF(SOLVER%GLOBAL_NUMBER == 1) THEN
                  ! DAE solver- do nothing
                ELSE
                  LOCAL_ERROR="The solver global number of "//TRIM(NUMBER_TO_VSTRING(SOLVER%GLOBAL_NUMBER,"*",ERR,ERROR))// &
                    & " is invalid for the CellML DAE simple loop of a 1D0D coupled Navier-Stokes problem."
                  CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
                END IF
              ELSE
                LOCAL_ERROR="The control loop type for solver "//TRIM(NUMBER_TO_VSTRING(SOLVER%GLOBAL_NUMBER,"*",ERR,ERROR))// &
                  & " is invalid for the a 1D0D coupled Navier-Stokes problem."
                CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
              END IF
            CASE(PROBLEM_STREE1D0D_NAVIER_STOKES_SUBTYPE)
              IF(ASSOCIATED(SOLVER%SOLVERS%CONTROL_LOOP%WHILE_LOOP)) THEN
                SELECT CASE(SOLVER%GLOBAL_NUMBER)
                CASE(1)
                  ! Characteristic solver- copy branch Q,A values to new parameter set
                  dependentField=>SOLVER%SOLVER_EQUATIONS%SOLVER_MAPPING%EQUATIONS_SETS(1)%PTR%DEPENDENT%DEPENDENT_FIELD
                  CALL FIELD_VARIABLE_GET(dependentField,FIELD_U_VARIABLE_TYPE,fieldVariable,ERR,ERROR,*999)
                  IF(.NOT.ASSOCIATED(fieldVariable%PARAMETER_SETS%SET_TYPE(FIELD_UPWIND_VALUES_SET_TYPE)%PTR)) THEN
                    CALL FIELD_PARAMETER_SET_CREATE(dependentField,FIELD_U_VARIABLE_TYPE, &
                     & FIELD_UPWIND_VALUES_SET_TYPE,ERR,ERROR,*999)
                  END IF
                  CALL FIELD_PARAMETER_SETS_COPY(dependentField,FIELD_U_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE, &
                   & FIELD_UPWIND_VALUES_SET_TYPE,1.0_DP,ERR,ERROR,*999)

                CASE(2)
                  ! ! 1D Navier-Stokes solver
                  IF(CONTROL_LOOP%CONTROL_LOOP_LEVEL==3) THEN
                    ! check characteristic/ N-S convergence at branches
  !                    CALL NavierStokes_CoupleCharacteristics(CONTROL_LOOP,SOLVER,ERR,ERROR,*999)
                  END IF
                CASE DEFAULT
                  LOCAL_ERROR="The solver global number of "//TRIM(NUMBER_TO_VSTRING(SOLVER%GLOBAL_NUMBER,"*",ERR,ERROR))// &
                    & " is invalid for the iterative 1D-0D coupled Navier-Stokes problem."
                  CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
                END SELECT
              ELSE IF(ASSOCIATED(SOLVER%SOLVERS%CONTROL_LOOP%SIMPLE_LOOP)) THEN
                IF(SOLVER%GLOBAL_NUMBER == 1) THEN
                  ! DAE solver- do nothing
                ELSE
                  LOCAL_ERROR="The solver global number of "//TRIM(NUMBER_TO_VSTRING(SOLVER%GLOBAL_NUMBER,"*",ERR,ERROR))// &
                    & " is invalid for the CellML DAE simple loop of a 1D0D coupled Navier-Stokes problem."
                  CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
                END IF
              ELSE
                LOCAL_ERROR="The control loop type for solver "//TRIM(NUMBER_TO_VSTRING(SOLVER%GLOBAL_NUMBER,"*",ERR,ERROR))// &
                  & " is invalid for the a 1D0D coupled Navier-Stokes problem."
                CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
              END IF
            CASE(PROBLEM_TRANSIENT1D_ADV_NAVIER_STOKES_SUBTYPE)
              SELECT CASE(SOLVER%GLOBAL_NUMBER)
              CASE(1)
                ! Characteristic solver- copy branch Q,A values to new parameter set
                dependentField=>SOLVER%SOLVER_EQUATIONS%SOLVER_MAPPING%EQUATIONS_SETS(1)%PTR%DEPENDENT%DEPENDENT_FIELD
                CALL FIELD_VARIABLE_GET(dependentField,FIELD_U_VARIABLE_TYPE,fieldVariable,ERR,ERROR,*999)
                IF(.NOT.ASSOCIATED(fieldVariable%PARAMETER_SETS%SET_TYPE(FIELD_UPWIND_VALUES_SET_TYPE)%PTR)) THEN
                  CALL FIELD_PARAMETER_SET_CREATE(dependentField,FIELD_U_VARIABLE_TYPE, &
                   & FIELD_UPWIND_VALUES_SET_TYPE,ERR,ERROR,*999)
                END IF
                CALL FIELD_PARAMETER_SETS_COPY(dependentField,FIELD_U_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE, &
                 & FIELD_UPWIND_VALUES_SET_TYPE,1.0_DP,ERR,ERROR,*999)
              CASE(2)
                ! check characteristic/ N-S convergence at branches
  !                CALL NavierStokes_CoupleCharacteristics(CONTROL_LOOP,SOLVER,ERR,ERROR,*999)
              CASE(3)
                ! Advection solver output data if necessary
                IF(CONTROL_LOOP%WHILE_LOOP%CONTINUE_LOOP .EQV. .FALSE.) THEN
                  ! 1D NSE solver output data if N-S/Chars converged
                  CALL NAVIER_STOKES_POST_SOLVE_OUTPUT_DATA(SOLVER,err,error,*999)
                END IF
              CASE DEFAULT
                LOCAL_ERROR="The solver global number of "//TRIM(NUMBER_TO_VSTRING(SOLVER%GLOBAL_NUMBER,"*",ERR,ERROR))// &
                  & " is invalid for a 1D Navier-Stokes and Advection problem."
                CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
              END SELECT
            CASE(PROBLEM_COUPLED1D0D_ADV_NAVIER_STOKES_SUBTYPE)
              IF(ASSOCIATED(SOLVER%SOLVERS%CONTROL_LOOP%WHILE_LOOP)) THEN
                SELECT CASE(SOLVER%GLOBAL_NUMBER)
                CASE(1)
                  ! Characteristic solver- copy branch Q,A values to new parameter set
                  dependentField=>SOLVER%SOLVER_EQUATIONS%SOLVER_MAPPING%EQUATIONS_SETS(1)%PTR%DEPENDENT%DEPENDENT_FIELD
                  CALL FIELD_VARIABLE_GET(dependentField,FIELD_U_VARIABLE_TYPE,fieldVariable,ERR,ERROR,*999)
                  IF(.NOT.ASSOCIATED(fieldVariable%PARAMETER_SETS%SET_TYPE(FIELD_UPWIND_VALUES_SET_TYPE)%PTR)) THEN
                    CALL FIELD_PARAMETER_SET_CREATE(dependentField,FIELD_U_VARIABLE_TYPE, &
                     & FIELD_UPWIND_VALUES_SET_TYPE,ERR,ERROR,*999)
                  END IF
                  CALL FIELD_PARAMETER_SETS_COPY(dependentField,FIELD_U_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE, &
                   & FIELD_UPWIND_VALUES_SET_TYPE,1.0_DP,ERR,ERROR,*999)
                CASE(2)
                  ! ! 1D Navier-Stokes solver
                  IF(CONTROL_LOOP%CONTROL_LOOP_LEVEL==3) THEN
                    ! check characteristic/ N-S convergence at branches
  !                    CALL NavierStokes_CoupleCharacteristics(CONTROL_LOOP,SOLVER,ERR,ERROR,*999)
                  END IF
                CASE DEFAULT
                  LOCAL_ERROR="The solver global number of "//TRIM(NUMBER_TO_VSTRING(SOLVER%GLOBAL_NUMBER,"*",ERR,ERROR))// &
                    & " is invalid for the iterative 1D-0D coupled Navier-Stokes problem."
                  CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
                END SELECT
              ELSE IF(ASSOCIATED(SOLVER%SOLVERS%CONTROL_LOOP%SIMPLE_LOOP)) THEN
                ! DAE and advection solvers - output data if post advection solve
                IF(SOLVER%SOLVERS%CONTROL_LOOP%SUB_LOOP_INDEX == 3) THEN
                  CALL NAVIER_STOKES_POST_SOLVE_OUTPUT_DATA(SOLVER,err,error,*999)
                END IF
              ELSE
                LOCAL_ERROR="The control loop type for solver "//TRIM(NUMBER_TO_VSTRING(SOLVER%GLOBAL_NUMBER,"*",ERR,ERROR))// &
                  & " is invalid for the a 1D0D coupled Navier-Stokes problem."
                CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
              END IF
            CASE(PROBLEM_STREE1D0D_ADV_NAVIER_STOKES_SUBTYPE)
              IF(ASSOCIATED(SOLVER%SOLVERS%CONTROL_LOOP%WHILE_LOOP)) THEN
                SELECT CASE(SOLVER%GLOBAL_NUMBER)
                CASE(1)
                  ! Characteristic solver- copy branch Q,A values to new parameter set
                  dependentField=>SOLVER%SOLVER_EQUATIONS%SOLVER_MAPPING%EQUATIONS_SETS(1)%PTR%DEPENDENT%DEPENDENT_FIELD
                  CALL FIELD_VARIABLE_GET(dependentField,FIELD_U_VARIABLE_TYPE,fieldVariable,ERR,ERROR,*999)
                  IF(.NOT.ASSOCIATED(fieldVariable%PARAMETER_SETS%SET_TYPE(FIELD_UPWIND_VALUES_SET_TYPE)%PTR)) THEN
                    CALL FIELD_PARAMETER_SET_CREATE(dependentField,FIELD_U_VARIABLE_TYPE, &
                     & FIELD_UPWIND_VALUES_SET_TYPE,ERR,ERROR,*999)
                  END IF
                  CALL FIELD_PARAMETER_SETS_COPY(dependentField,FIELD_U_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE, &
                   & FIELD_UPWIND_VALUES_SET_TYPE,1.0_DP,ERR,ERROR,*999)
                CASE(2)
                  ! ! 1D Navier-Stokes solver
                  IF(CONTROL_LOOP%CONTROL_LOOP_LEVEL==3) THEN
                    ! check characteristic/ N-S convergence at branches
  !                    CALL NavierStokes_CoupleCharacteristics(CONTROL_LOOP,SOLVER,ERR,ERROR,*999)
                  END IF
                CASE DEFAULT
                  LOCAL_ERROR="The solver global number of "//TRIM(NUMBER_TO_VSTRING(SOLVER%GLOBAL_NUMBER,"*",ERR,ERROR))// &
                    & " is invalid for the iterative 1D-0D coupled Navier-Stokes problem."
                  CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
                END SELECT
              ELSE IF(ASSOCIATED(SOLVER%SOLVERS%CONTROL_LOOP%SIMPLE_LOOP)) THEN
                ! DAE and advection solvers - output data if post advection solve
                IF(SOLVER%SOLVERS%CONTROL_LOOP%SUB_LOOP_INDEX == 3) THEN
                  CALL NAVIER_STOKES_POST_SOLVE_OUTPUT_DATA(SOLVER,err,error,*999)
                END IF
              ELSE
                LOCAL_ERROR="The control loop type for solver "//TRIM(NUMBER_TO_VSTRING(SOLVER%GLOBAL_NUMBER,"*",ERR,ERROR))// &
                  & " is invalid for the a 1D0D coupled Navier-Stokes problem."
                CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
              END IF
            CASE(PROBLEM_TRANSIENT_RBS_NAVIER_STOKES_SUBTYPE)
              CALL CONTROL_LOOP_TIMES_GET(CONTROL_LOOP,startTime,stopTime,currentTime,timeIncrement, &
               & timestep,outputIteration,ERR,ERROR,*999)
              CALL NavierStokes_CalculateBoundaryFlux(SOLVER,ERR,ERROR,*999)
              CALL NAVIER_STOKES_POST_SOLVE_OUTPUT_DATA(SOLVER,err,error,*999)
            CASE(PROBLEM_MULTISCALE_NAVIER_STOKES_SUBTYPE)
              CALL NavierStokes_CalculateBoundaryFlux(SOLVER,ERR,ERROR,*999)
              CALL NAVIER_STOKES_POST_SOLVE_OUTPUT_DATA(SOLVER,err,error,*999)
              DO equationsSetNumber=1,SOLVER%SOLVER_EQUATIONS%SOLVER_MAPPING%NUMBER_OF_EQUATIONS_SETS
                ! If this is a coupled constitutive (non-Newtonian) viscosity problem, update shear rate values
                !  to be passed to the CellML solver at beginning of next timestep
                IF(SOLVER%SOLVER_EQUATIONS%SOLVER_MAPPING%EQUATIONS_SETS(equationsSetNumber)%PTR% &
                 &  EQUATIONS%EQUATIONS_SET%specification(3)==EQUATIONS_SET_CONSTITUTIVE_MU_NAVIER_STOKES_SUBTYPE) THEN
                 CALL NavierStokes_ShearRateCalculate(SOLVER%SOLVER_EQUATIONS%SOLVER_MAPPING% &
                  & EQUATIONS_SETS(equationsSetNumber)%PTR%EQUATIONS%EQUATIONS_SET,err,error,*999)
                END IF
              END DO
            CASE(PROBLEM_ALE_NAVIER_STOKES_SUBTYPE)
              !Post solve for the linear solver
              IF(SOLVER%SOLVE_TYPE==SOLVER_LINEAR_TYPE) THEN
                CALL WRITE_STRING(GENERAL_OUTPUT_TYPE,"Mesh movement post solve... ",ERR,ERROR,*999)
                CALL SOLVERS_SOLVER_GET(SOLVER%SOLVERS,2,SOLVER2,ERR,ERROR,*999)
                IF(ASSOCIATED(SOLVER2%DYNAMIC_SOLVER)) THEN
                  SOLVER2%DYNAMIC_SOLVER%ALE=.TRUE.
                ELSE  
                  CALL FlagError("Dynamic solver is not associated for ALE problem.",ERR,ERROR,*999)
                END IF
              !Post solve for the dynamic solver
              ELSE IF(SOLVER%SOLVE_TYPE==SOLVER_DYNAMIC_TYPE) THEN
                CALL WRITE_STRING(GENERAL_OUTPUT_TYPE,"ALE Navier-Stokes post solve... ",ERR,ERROR,*999)
                CALL NAVIER_STOKES_POST_SOLVE_OUTPUT_DATA(SOLVER,err,error,*999)
              END IF
            CASE DEFAULT
              LOCAL_ERROR="The third problem specification of  "// &
                & TRIM(NUMBER_TO_VSTRING(CONTROL_LOOP%PROBLEM%specification(3),"*",ERR,ERROR))// &
                & " is not valid for a Navier-Stokes fluid mechanics problem."
              CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
            END SELECT
          ELSE
            CALL FlagError("Problem is not associated.",ERR,ERROR,*999)
          END IF
        ELSE
          CALL FlagError("Control loop is not associated.",ERR,ERROR,*999)
        END IF
      ELSE
        CALL FlagError("Solvers is not associated.",ERR,ERROR,*999)
      END IF
    ELSE
      CALL FlagError("Solver is not associated.",ERR,ERROR,*999)
    END IF

    EXITS("NAVIER_STOKES_POST_SOLVE")
    RETURN
999 ERRORSEXITS("NAVIER_STOKES_POST_SOLVE",ERR,ERROR)
    RETURN 1
  END SUBROUTINE NAVIER_STOKES_POST_SOLVE

  !
  !================================================================================================================================
  !

  !>Update boundary conditions for Navier-Stokes flow pre solve
  SUBROUTINE NavierStokes_PreSolveUpdateBoundaryConditions(SOLVER,ERR,ERROR,*)

    !Argument variables
    TYPE(SOLVER_TYPE), POINTER :: SOLVER
    INTEGER(INTG), INTENT(OUT) :: ERR
    TYPE(VARYING_STRING), INTENT(OUT) :: ERROR
    !Local Variables
    TYPE(CONTROL_LOOP_TYPE), POINTER :: CONTROL_LOOP
    TYPE(BOUNDARY_CONDITIONS_VARIABLE_TYPE), POINTER :: BOUNDARY_CONDITIONS_VARIABLE
    TYPE(BOUNDARY_CONDITIONS_TYPE), POINTER :: BOUNDARY_CONDITIONS
    TYPE(DOMAIN_TYPE), POINTER :: DOMAIN
    TYPE(DOMAIN_NODES_TYPE), POINTER :: DOMAIN_NODES
    TYPE(EQUATIONS_SET_TYPE), POINTER :: EQUATIONS_SET,SOLID_EQUATIONS_SET,FLUID_EQUATIONS_SET
    TYPE(EQUATIONS_SET_DEPENDENT_TYPE), POINTER :: SOLID_DEPENDENT
    TYPE(EQUATIONS_SET_GEOMETRY_TYPE), POINTER :: FLUID_GEOMETRIC
    TYPE(EQUATIONS_TYPE), POINTER :: EQUATIONS,SOLID_EQUATIONS,FLUID_EQUATIONS
    TYPE(FIELD_INTERPOLATED_POINT_PTR_TYPE), POINTER :: INTERPOLATED_POINT(:)
    TYPE(FIELD_INTERPOLATION_PARAMETERS_PTR_TYPE), POINTER :: INTERPOLATION_PARAMETERS(:)
    TYPE(FIELD_TYPE), POINTER :: ANALYTIC_FIELD,DEPENDENT_FIELD,GEOMETRIC_FIELD,MATERIALS_FIELD
    TYPE(FIELD_TYPE), POINTER :: INDEPENDENT_FIELD,SOLID_DEPENDENT_FIELD,FLUID_GEOMETRIC_FIELD
    TYPE(FIELD_VARIABLE_TYPE), POINTER :: ANALYTIC_VARIABLE,FIELD_VARIABLE,GEOMETRIC_VARIABLE,MATERIALS_VARIABLE
    TYPE(FIELD_VARIABLE_TYPE), POINTER :: dependentFieldVariable,independentFieldVariable
    TYPE(SOLVER_EQUATIONS_TYPE), POINTER :: SOLVER_EQUATIONS,SOLID_SOLVER_EQUATIONS,FLUID_SOLVER_EQUATIONS
    TYPE(SOLVER_MAPPING_TYPE), POINTER :: SOLVER_MAPPING,SOLID_SOLVER_MAPPING,FLUID_SOLVER_MAPPING
    TYPE(SOLVER_TYPE), POINTER :: Solver2
    TYPE(SOLVERS_TYPE), POINTER :: SOLVERS
    TYPE(VARYING_STRING) :: LOCAL_ERROR
    INTEGER(INTG) :: nodeIdx,derivativeIdx,versionIdx,variableIdx,numberOfSourceTimesteps,timeIdx,componentIdx
    INTEGER(INTG) :: NUMBER_OF_DIMENSIONS,BOUNDARY_CONDITION_CHECK_VARIABLE,GLOBAL_DERIV_INDEX,node_idx,variable_type
    INTEGER(INTG) :: variable_idx,local_ny,ANALYTIC_FUNCTION_TYPE,component_idx,deriv_idx,dim_idx,version_idx
    INTEGER(INTG) :: element_idx,en_idx,I,J,K,number_of_nodes_xic(3),search_idx,localDof,globalDof,componentBC,previousNodeNumber
    INTEGER(INTG) :: componentNumberVelocity,numberOfDimensions,numberOfNodes,numberOfGlobalNodes,currentLoopIteration
    INTEGER(INTG) :: dependentVariableType,independentVariableType,dependentDof,independentDof,userNodeNumber,localNodeNumber
    INTEGER(INTG) :: EquationsSetIndex,SolidNodeNumber,FluidNodeNumber
    INTEGER(INTG), ALLOCATABLE :: InletNodes(:)
    REAL(DP) :: CURRENT_TIME,TIME_INCREMENT,DISPLACEMENT_VALUE,VALUE,XI_COORDINATES(3),timeData,QP,QPP,componentValues(3)
    REAL(DP) :: T_COORDINATES(20,3),MU_PARAM,RHO_PARAM,X(3),FluidGFValue,SolidDFValue,NewLaplaceBoundaryValue,Lref,Tref,Mref
    REAL(DP), POINTER :: MESH_VELOCITY_VALUES(:), GEOMETRIC_PARAMETERS(:), BOUNDARY_VALUES(:)
    REAL(DP), POINTER :: TANGENTS(:,:),NORMAL(:),TIME,ANALYTIC_PARAMETERS(:),MATERIALS_PARAMETERS(:)
    REAL(DP), POINTER :: independentParameters(:),dependentParameters(:) 
    REAL(DP), ALLOCATABLE :: nodeData(:,:),qSpline(:),qValues(:),tValues(:),BoundaryValues(:)
    LOGICAL :: ghostNode,nodeExists,importDataFromFile,ALENavierStokesEquationsSetFound=.FALSE.
    LOGICAL :: SolidEquationsSetFound=.FALSE.,SolidNodeFound=.FALSE.,FluidEquationsSetFound=.FALSE.
    CHARACTER(70) :: inputFile,tempString

    NULLIFY(SOLVER_EQUATIONS)
    NULLIFY(SOLVER_MAPPING)
    NULLIFY(EQUATIONS_SET)
    NULLIFY(EQUATIONS)
    NULLIFY(BOUNDARY_CONDITIONS_VARIABLE)
    NULLIFY(BOUNDARY_CONDITIONS)
    NULLIFY(ANALYTIC_FIELD)
    NULLIFY(DEPENDENT_FIELD)
    NULLIFY(GEOMETRIC_FIELD)
    NULLIFY(MATERIALS_FIELD)
    NULLIFY(INDEPENDENT_FIELD)
    NULLIFY(ANALYTIC_VARIABLE)
    NULLIFY(FIELD_VARIABLE)
    NULLIFY(GEOMETRIC_VARIABLE)
    NULLIFY(MATERIALS_VARIABLE)
    NULLIFY(DOMAIN)
    NULLIFY(DOMAIN_NODES)
    NULLIFY(INTERPOLATED_POINT)
    NULLIFY(INTERPOLATION_PARAMETERS)
    NULLIFY(MESH_VELOCITY_VALUES)
    NULLIFY(GEOMETRIC_PARAMETERS)
    NULLIFY(BOUNDARY_VALUES)
    NULLIFY(TANGENTS)
    NULLIFY(NORMAL)
    NULLIFY(TIME)
    NULLIFY(ANALYTIC_PARAMETERS)
    NULLIFY(MATERIALS_PARAMETERS)
    NULLIFY(independentParameters)
    NULLIFY(dependentParameters)

    ENTERS("NavierStokes_PreSolveUpdateBoundaryConditions",ERR,ERROR,*999)

    IF(ASSOCIATED(SOLVER)) THEN
      SOLVERS=>SOLVER%SOLVERS
      IF(ASSOCIATED(SOLVERS)) THEN
        CONTROL_LOOP=>SOLVERS%CONTROL_LOOP
        CALL CONTROL_LOOP_CURRENT_TIMES_GET(CONTROL_LOOP,CURRENT_TIME,TIME_INCREMENT,ERR,ERROR,*999)
        IF(ASSOCIATED(CONTROL_LOOP%PROBLEM)) THEN
          IF(.NOT.ALLOCATED(CONTROL_LOOP%problem%specification)) THEN
            CALL FlagError("Problem specification array is not allocated.",err,error,*999)
          ELSE IF(SIZE(CONTROL_LOOP%problem%specification,1)<3) THEN
            CALL FlagError("Problem specification must have three entries for a Navier-Stokes problem.",err,error,*999)
          END IF
          SELECT CASE(CONTROL_LOOP%PROBLEM%SPECIFICATION(1))
          CASE(PROBLEM_FLUID_MECHANICS_CLASS)        
            SELECT CASE(CONTROL_LOOP%PROBLEM%SPECIFICATION(3))
            CASE(PROBLEM_LAPLACE_NAVIER_STOKES_SUBTYPE)
              ! do nothing ???
            CASE(PROBLEM_STATIC_NAVIER_STOKES_SUBTYPE, &
               & PROBLEM_TRANSIENT_NAVIER_STOKES_SUBTYPE, &
               & PROBLEM_TRANSIENT_RBS_NAVIER_STOKES_SUBTYPE, &
               & PROBLEM_MULTISCALE_NAVIER_STOKES_SUBTYPE)
              SOLVER_EQUATIONS=>SOLVER%SOLVER_EQUATIONS
              IF(ASSOCIATED(SOLVER_EQUATIONS)) THEN
                SOLVER_MAPPING=>SOLVER_EQUATIONS%SOLVER_MAPPING
                EQUATIONS=>SOLVER_MAPPING%EQUATIONS_SET_TO_SOLVER_MAP(1)%EQUATIONS
                IF(ASSOCIATED(EQUATIONS)) THEN
                  EQUATIONS_SET=>EQUATIONS%EQUATIONS_SET

                  ! Fitting boundary condition- get values from file
                  ! TODO: this should be generalised with input filenames specified from the example file when IO is improved
                  IF(ASSOCIATED(EQUATIONS_SET%INDEPENDENT)) THEN                
                    !Read in field values to independent field
                    NULLIFY(independentFieldVariable)
                    NULLIFY(dependentFieldVariable)
                    INDEPENDENT_FIELD=>EQUATIONS_SET%INDEPENDENT%INDEPENDENT_FIELD
                    DEPENDENT_FIELD=>EQUATIONS_SET%DEPENDENT%DEPENDENT_FIELD
                    independentVariableType=INDEPENDENT_FIELD%VARIABLES(1)%VARIABLE_TYPE
                    CALL FIELD_VARIABLE_GET(INDEPENDENT_FIELD,FIELD_U_VARIABLE_TYPE,independentFieldVariable,ERR,ERROR,*999)
                    dependentVariableType=DEPENDENT_FIELD%VARIABLES(1)%VARIABLE_TYPE
                    CALL FIELD_VARIABLE_GET(DEPENDENT_FIELD,FIELD_U_VARIABLE_TYPE,dependentFieldVariable,ERR,ERROR,*999)
                    CALL BOUNDARY_CONDITIONS_VARIABLE_GET(SOLVER_EQUATIONS%BOUNDARY_CONDITIONS, &
                      & dependentFieldVariable,BOUNDARY_CONDITIONS_VARIABLE,ERR,ERROR,*999)
                    !Read in field data from file
                    !Loop over nodes and update independent field values - if a fixed fitted boundary, also update dependent
                    IF(ASSOCIATED(INDEPENDENT_FIELD)) THEN
                      componentNumberVelocity = 1
                      numberOfDimensions = dependentFieldVariable%NUMBER_OF_COMPONENTS - 1
                      ! Get the nodes on this computational domain
                      IF(independentFieldVariable%COMPONENTS(componentNumberVelocity)%INTERPOLATION_TYPE== &
                        & FIELD_NODE_BASED_INTERPOLATION) THEN
                        domain=>independentFieldVariable%COMPONENTS(componentNumberVelocity)%DOMAIN
                        IF(ASSOCIATED(domain)) THEN
                          IF(ASSOCIATED(domain%TOPOLOGY)) THEN
                            DOMAIN_NODES=>domain%TOPOLOGY%NODES
                            IF(ASSOCIATED(DOMAIN_NODES)) THEN
                              numberOfNodes = DOMAIN_NODES%NUMBER_OF_NODES
                              numberOfGlobalNodes = DOMAIN_NODES%NUMBER_OF_GLOBAL_NODES
                            ELSE
                              CALL FlagError("Domain topology nodes is not associated.",ERR,ERROR,*999)
                            END IF
                          ELSE
                            CALL FlagError("Domain topology is not associated.",ERR,ERROR,*999)
                          END IF
                        ELSE
                          CALL FlagError("Domain is not associated.",ERR,ERROR,*999)
                        END IF
                      ELSE
                        CALL FlagError("Only node based interpolation is implemented.",ERR,ERROR,*999)
                      END IF

                      ! Construct the filename based on the computational node and time step
                      currentLoopIteration=CONTROL_LOOP%TIME_LOOP%ITERATION_NUMBER
                      WRITE(tempString,"(I4.4)") currentLoopIteration
                      inputFile = './../interpolatedData/fitData' // tempString(1:4) // '.dat'

                      INQUIRE(FILE=inputFile, EXIST=importDataFromFile)
                      IF(importDataFromFile) THEN
                        !Read fitted data from input file (if exists)
                        CALL WRITE_STRING(GENERAL_OUTPUT_TYPE,"Updating independent field and boundary nodes from "//inputFile, &
                          & ERR,ERROR,*999)
                        OPEN(UNIT=10, FILE=inputFile, STATUS='OLD')                  
                        !Loop over local nodes and update independent field and (and dependent field for any FIXED_FITTED nodes)
                        previousNodeNumber=0
                        DO nodeIdx=1,numberOfNodes
                          userNodeNumber=DOMAIN_NODES%NODES(nodeIdx)%USER_NUMBER
                          CALL DOMAIN_TOPOLOGY_NODE_CHECK_EXISTS(domain%Topology,userNodeNumber,nodeExists,localNodeNumber, &
                            & ghostNode,err,error,*999)
                          IF(nodeExists .AND. .NOT. ghostNode) THEN
                            ! Move to line in file for this node (dummy read)
                            ! NOTE: this takes advantage of the user number increasing ordering of domain nodes 
                            DO search_idx=1,userNodeNumber-previousNodeNumber-1
                              READ(10,*)
                            END DO
                            ! Read in the node data for this timestep file
                            READ(10,*) (componentValues(componentIdx), componentIdx=1,numberOfDimensions)
                            DO componentIdx=1,numberOfDimensions
                              dependentDof = dependentFieldVariable%COMPONENTS(componentIdx)%PARAM_TO_DOF_MAP%NODE_PARAM2DOF_MAP% &
                                & NODES(nodeIdx)%DERIVATIVES(1)%VERSIONS(1)
                              independentDof = independentFieldVariable%COMPONENTS(componentIdx)%PARAM_TO_DOF_MAP% &
                                & NODE_PARAM2DOF_MAP%NODES(nodeIdx)%DERIVATIVES(1)%VERSIONS(1)
                              VALUE = componentValues(componentIdx)
                              CALL FIELD_PARAMETER_SET_UPDATE_LOCAL_DOF(INDEPENDENT_FIELD,independentVariableType, &
                                & FIELD_VALUES_SET_TYPE,independentDof,VALUE,ERR,ERROR,*999)
                              CALL FIELD_COMPONENT_DOF_GET_USER_NODE(DEPENDENT_FIELD,dependentVariableType,1,1,userNodeNumber, & 
                                & componentIdx,localDof,globalDof,err,error,*999)
                              BOUNDARY_CONDITION_CHECK_VARIABLE=BOUNDARY_CONDITIONS_VARIABLE%CONDITION_TYPES(globalDof)
                              IF(BOUNDARY_CONDITION_CHECK_VARIABLE==BOUNDARY_CONDITION_FIXED_FITTED) THEN
                                CALL FIELD_PARAMETER_SET_UPDATE_LOCAL_DOF(DEPENDENT_FIELD,dependentVariableType, &
                                  & FIELD_VALUES_SET_TYPE,localDof,VALUE,ERR,ERROR,*999)
                              END IF
                            END DO !componentIdx
                            previousNodeNumber=userNodeNumber
                          END IF ! ghost/exist check
                        END DO !nodeIdx
                        CLOSE(UNIT=10)
                      END IF !check import file exists
                    ELSE
                      CALL FlagError("Equations set independent field is not associated.",ERR,ERROR,*999)
                    END IF
                  END IF !Equations set independent

                  ! Analytic equations
                  IF(ASSOCIATED(EQUATIONS_SET%ANALYTIC)) THEN
                    !Standard analytic functions
                    IF(EQUATIONS_SET%ANALYTIC%ANALYTIC_FUNCTION_TYPE==EQUATIONS_SET_NAVIER_STOKES_EQUATION_SINUSOID) THEN
                      ! Update analytic time value with current time
                      EQUATIONS_SET%ANALYTIC%ANALYTIC_TIME=CURRENT_TIME
                      !Calculate analytic values
                      BOUNDARY_CONDITIONS=>SOLVER_EQUATIONS%BOUNDARY_CONDITIONS
                      IF(ASSOCIATED(BOUNDARY_CONDITIONS)) THEN
                        CALL NavierStokes_BoundaryConditionsAnalyticCalculate(EQUATIONS_SET,BOUNDARY_CONDITIONS,ERR,ERROR,*999)
                      END IF
                    ELSE IF(EQUATIONS_SET%ANALYTIC%ANALYTIC_FUNCTION_TYPE== &
                      & EQUATIONS_SET_NAVIER_STOKES_EQUATION_TWO_DIM_TAYLOR_GREEN.OR. &
                      & EQUATIONS_SET%ANALYTIC%ANALYTIC_FUNCTION_TYPE==EQUATIONS_SET_NAVIER_STOKES_EQUATION_TWO_DIM_POISEUILLE) THEN
                      IF(ASSOCIATED(EQUATIONS_SET)) THEN
                        IF(ASSOCIATED(EQUATIONS_SET%ANALYTIC)) THEN
                          DEPENDENT_FIELD=>EQUATIONS_SET%DEPENDENT%DEPENDENT_FIELD
                          IF(ASSOCIATED(DEPENDENT_FIELD)) THEN
                            GEOMETRIC_FIELD=>EQUATIONS_SET%GEOMETRY%GEOMETRIC_FIELD
                            IF(ASSOCIATED(GEOMETRIC_FIELD)) THEN            
                              ! Geometric parameters
                              CALL FIELD_NUMBER_OF_COMPONENTS_GET(GEOMETRIC_FIELD,FIELD_U_VARIABLE_TYPE,NUMBER_OF_DIMENSIONS,ERR, & 
                                & ERROR,*999)
                              NULLIFY(GEOMETRIC_VARIABLE)
                              NULLIFY(GEOMETRIC_PARAMETERS)
                              CALL FIELD_VARIABLE_GET(GEOMETRIC_FIELD,FIELD_U_VARIABLE_TYPE,GEOMETRIC_VARIABLE,ERR,ERROR,*999)
                              CALL FIELD_PARAMETER_SET_DATA_GET(GEOMETRIC_FIELD,FIELD_U_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE, &
                                & GEOMETRIC_PARAMETERS,ERR,ERROR,*999)
                              ! Analytic parameters
                              ANALYTIC_FIELD=>EQUATIONS_SET%ANALYTIC%ANALYTIC_FIELD
                              NULLIFY(ANALYTIC_VARIABLE)
                              NULLIFY(ANALYTIC_PARAMETERS)
                              IF(ASSOCIATED(ANALYTIC_FIELD)) THEN
                                CALL FIELD_VARIABLE_GET(ANALYTIC_FIELD,FIELD_U_VARIABLE_TYPE,ANALYTIC_VARIABLE,ERR,ERROR,*999)
                                CALL FIELD_PARAMETER_SET_DATA_GET(ANALYTIC_FIELD,FIELD_U_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE, &
                                  & ANALYTIC_PARAMETERS,ERR,ERROR,*999)           
                              END IF
                              ! Materials parameters
                              NULLIFY(MATERIALS_FIELD)
                              NULLIFY(MATERIALS_VARIABLE)
                              NULLIFY(MATERIALS_PARAMETERS)
                              IF(ASSOCIATED(EQUATIONS_SET%MATERIALS)) THEN
                                MATERIALS_FIELD=>EQUATIONS_SET%MATERIALS%MATERIALS_FIELD
                                CALL FIELD_VARIABLE_GET(MATERIALS_FIELD,FIELD_U_VARIABLE_TYPE,MATERIALS_VARIABLE,ERR,ERROR,*999)
                                CALL FIELD_PARAMETER_SET_DATA_GET(MATERIALS_FIELD,FIELD_U_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE, &
                                  & MATERIALS_PARAMETERS,ERR,ERROR,*999)           
                              END IF
                              DO variable_idx=1,DEPENDENT_FIELD%NUMBER_OF_VARIABLES
                                variable_type=DEPENDENT_FIELD%VARIABLES(variable_idx)%VARIABLE_TYPE
                                FIELD_VARIABLE=>DEPENDENT_FIELD%VARIABLE_TYPE_MAP(variable_type)%PTR
                                IF(ASSOCIATED(FIELD_VARIABLE)) THEN
                                  CALL Field_ParameterSetEnsureCreated(DEPENDENT_FIELD,variable_type, &
                                    & FIELD_ANALYTIC_VALUES_SET_TYPE,ERR,ERROR,*999)
                                  DO component_idx=1,FIELD_VARIABLE%NUMBER_OF_COMPONENTS
                                    IF(FIELD_VARIABLE%COMPONENTS(component_idx)%INTERPOLATION_TYPE== & 
                                      & FIELD_NODE_BASED_INTERPOLATION) THEN
                                      DOMAIN=>FIELD_VARIABLE%COMPONENTS(component_idx)%DOMAIN
                                      IF(ASSOCIATED(DOMAIN)) THEN
                                        IF(ASSOCIATED(DOMAIN%TOPOLOGY)) THEN
                                          DOMAIN_NODES=>DOMAIN%TOPOLOGY%NODES
                                          IF(ASSOCIATED(DOMAIN_NODES)) THEN
                                            !Should be replaced by boundary node flag
                                            DO node_idx=1,DOMAIN_NODES%NUMBER_OF_NODES
                                              DO dim_idx=1,NUMBER_OF_DIMENSIONS
                                                !Default to version 1 of each node derivative
                                                local_ny=GEOMETRIC_VARIABLE%COMPONENTS(dim_idx)%PARAM_TO_DOF_MAP% &
                                                  & NODE_PARAM2DOF_MAP%NODES(node_idx)%DERIVATIVES(1)%VERSIONS(1)
                                                X(dim_idx)=GEOMETRIC_PARAMETERS(local_ny)
                                              END DO !dim_idx

                                              !Loop over the derivatives
                                              DO deriv_idx=1,DOMAIN_NODES%NODES(node_idx)%NUMBER_OF_DERIVATIVES
                                                ANALYTIC_FUNCTION_TYPE=EQUATIONS_SET%ANALYTIC%ANALYTIC_FUNCTION_TYPE
                                                GLOBAL_DERIV_INDEX=DOMAIN_NODES%NODES(node_idx)%DERIVATIVES(deriv_idx)% &
                                                  & GLOBAL_DERIVATIVE_INDEX
                                                CALL NAVIER_STOKES_ANALYTIC_FUNCTIONS_EVALUATE(ANALYTIC_FUNCTION_TYPE,X, &
                                                  & CURRENT_TIME,variable_type,GLOBAL_DERIV_INDEX,componentIdx, &
                                                  & NUMBER_OF_DIMENSIONS,FIELD_VARIABLE%NUMBER_OF_COMPONENTS,ANALYTIC_PARAMETERS, &
                                                  & MATERIALS_PARAMETERS,VALUE,ERR,ERROR,*999)
                                                DO version_idx=1, &
                                                  & DOMAIN_NODES%NODES(node_idx)%DERIVATIVES(deriv_idx)%numberOfVersions
                                                  local_ny=FIELD_VARIABLE%COMPONENTS(component_idx)%PARAM_TO_DOF_MAP% &
                                                    & NODE_PARAM2DOF_MAP%NODES(node_idx)%DERIVATIVES(deriv_idx)% &
                                                    & VERSIONS(version_idx)
                                                  ! Set analytic values
                                                  CALL FIELD_PARAMETER_SET_UPDATE_LOCAL_DOF(DEPENDENT_FIELD,variable_type, &
                                                    & FIELD_ANALYTIC_VALUES_SET_TYPE,local_ny,VALUE,ERR,ERROR,*999)
                                                  CALL BOUNDARY_CONDITIONS_VARIABLE_GET(SOLVER_EQUATIONS%BOUNDARY_CONDITIONS, &
                                                    & DEPENDENT_FIELD%VARIABLE_TYPE_MAP(FIELD_U_VARIABLE_TYPE)%PTR, &
                                                    & BOUNDARY_CONDITIONS_VARIABLE,ERR,ERROR,*999)
                                                  IF(EQUATIONS_SET%ANALYTIC%ANALYTIC_FUNCTION_TYPE== &
                                                    & EQUATIONS_SET_NAVIER_STOKES_EQUATION_TWO_DIM_TAYLOR_GREEN) THEN
                                                    !Taylor-Green boundary conditions update
                                                    IF(ASSOCIATED(BOUNDARY_CONDITIONS_VARIABLE)) THEN
                                                      BOUNDARY_CONDITION_CHECK_VARIABLE=BOUNDARY_CONDITIONS_VARIABLE% &
                                                        & CONDITION_TYPES(local_ny)
                                                      IF(BOUNDARY_CONDITION_CHECK_VARIABLE==BOUNDARY_CONDITION_FIXED .AND. &
                                                        & component_idx<FIELD_VARIABLE%NUMBER_OF_COMPONENTS) THEN
                                                        CALL FIELD_PARAMETER_SET_UPDATE_LOCAL_DOF(DEPENDENT_FIELD, &
                                                          & variable_type,FIELD_VALUES_SET_TYPE,local_ny, &
                                                          & VALUE,ERR,ERROR,*999)
                                                      END IF !Boundary condition fixed
                                                    END IF !Boundary condition variable
                                                  END IF ! Taylor-Green
                                                END DO !version_idx
                                              END DO !deriv_idx
                                            END DO !node_idx
                                          ELSE
                                            CALL FlagError("Domain topology nodes is not associated.",ERR,ERROR,*999)
                                          END IF
                                        ELSE
                                          CALL FlagError("Domain topology is not associated.",ERR,ERROR,*999)
                                        END IF
                                      ELSE
                                        CALL FlagError("Domain is not associated.",ERR,ERROR,*999)
                                      END IF
                                    ELSE
                                      CALL FlagError("Only node based interpolation is implemented.",ERR,ERROR,*999)
                                    END IF
                                  END DO !component_idx
                                  CALL FIELD_PARAMETER_SET_UPDATE_START(DEPENDENT_FIELD,variable_type, &
                                    & FIELD_ANALYTIC_VALUES_SET_TYPE,ERR,ERROR,*999)
                                  CALL FIELD_PARAMETER_SET_UPDATE_FINISH(DEPENDENT_FIELD,variable_type, &
                                    & FIELD_ANALYTIC_VALUES_SET_TYPE,ERR,ERROR,*999)
                                  CALL FIELD_PARAMETER_SET_UPDATE_START(DEPENDENT_FIELD,variable_type, &
                                    & FIELD_VALUES_SET_TYPE,ERR,ERROR,*999)
                                  CALL FIELD_PARAMETER_SET_UPDATE_FINISH(DEPENDENT_FIELD,variable_type, &
                                    & FIELD_VALUES_SET_TYPE,ERR,ERROR,*999)
                                ELSE
                                  CALL FlagError("Field variable is not associated.",ERR,ERROR,*999)
                                END IF
                              END DO !variable_idx
                              CALL FIELD_PARAMETER_SET_DATA_RESTORE(GEOMETRIC_FIELD,FIELD_U_VARIABLE_TYPE,&
                                & FIELD_VALUES_SET_TYPE,GEOMETRIC_PARAMETERS,ERR,ERROR,*999)
                            ELSE
                              CALL FlagError("Equations set geometric field is not associated.",ERR,ERROR,*999)
                            END IF
                          ELSE
                            CALL FlagError("Equations set dependent field is not associated.",ERR,ERROR,*999)
                          END IF
                        ELSE
                          CALL FlagError("Equations set analytic is not associated.",ERR,ERROR,*999)
                        END IF
                      ELSE
                        CALL FlagError("Equations set is not associated.",ERR,ERROR,*999)
                      END IF
                      ! Unit shape analytic functions
                    ELSE IF(EQUATIONS_SET%ANALYTIC%ANALYTIC_FUNCTION_TYPE==EQUATIONS_SET_NAVIER_STOKES_EQUATION_TWO_DIM_4 .OR. &
                      & EQUATIONS_SET%ANALYTIC%ANALYTIC_FUNCTION_TYPE==EQUATIONS_SET_NAVIER_STOKES_EQUATION_TWO_DIM_5 .OR. &
                      & EQUATIONS_SET%ANALYTIC%ANALYTIC_FUNCTION_TYPE==EQUATIONS_SET_NAVIER_STOKES_EQUATION_THREE_DIM_4 .OR. &
                      & EQUATIONS_SET%ANALYTIC%ANALYTIC_FUNCTION_TYPE==EQUATIONS_SET_NAVIER_STOKES_EQUATION_THREE_DIM_5 .OR. &
                      & EQUATIONS_SET%ANALYTIC%ANALYTIC_FUNCTION_TYPE==EQUATIONS_SET_NAVIER_STOKES_EQUATION_THREE_DIM_1) THEN
                      IF(ASSOCIATED(EQUATIONS_SET)) THEN
                        DEPENDENT_FIELD=>EQUATIONS_SET%DEPENDENT%DEPENDENT_FIELD
                        IF(ASSOCIATED(DEPENDENT_FIELD)) THEN
                          GEOMETRIC_FIELD=>EQUATIONS_SET%GEOMETRY%GEOMETRIC_FIELD
                          IF(ASSOCIATED(GEOMETRIC_FIELD)) THEN            
                            ! Geometric parameters
                            CALL FIELD_NUMBER_OF_COMPONENTS_GET(GEOMETRIC_FIELD,FIELD_U_VARIABLE_TYPE,NUMBER_OF_DIMENSIONS, &
                             & ERR,ERROR,*999)
                            NULLIFY(GEOMETRIC_VARIABLE)
                            CALL FIELD_VARIABLE_GET(GEOMETRIC_FIELD,FIELD_U_VARIABLE_TYPE,GEOMETRIC_VARIABLE,ERR,ERROR,*999)
                            NULLIFY(GEOMETRIC_PARAMETERS)
                            CALL FIELD_PARAMETER_SET_DATA_GET(GEOMETRIC_FIELD,FIELD_U_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE, & 
                              & GEOMETRIC_PARAMETERS,ERR,ERROR,*999)
                            ! Analytic parameters
                            ANALYTIC_FUNCTION_TYPE=EQUATIONS_SET%ANALYTIC%ANALYTIC_FUNCTION_TYPE
                            ANALYTIC_FIELD=>EQUATIONS_SET%ANALYTIC%ANALYTIC_FIELD
                            NULLIFY(ANALYTIC_VARIABLE)
                            NULLIFY(ANALYTIC_PARAMETERS)
                            IF(ASSOCIATED(ANALYTIC_FIELD)) THEN
                              CALL FIELD_VARIABLE_GET(ANALYTIC_FIELD,FIELD_U_VARIABLE_TYPE,ANALYTIC_VARIABLE,ERR,ERROR,*999)
                              CALL FIELD_PARAMETER_SET_DATA_GET(ANALYTIC_FIELD,FIELD_U_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE, &
                                & ANALYTIC_PARAMETERS,ERR,ERROR,*999)           
                            END IF
                            ! Materials parameters
                            NULLIFY(MATERIALS_FIELD)
                            NULLIFY(MATERIALS_VARIABLE)
                            NULLIFY(MATERIALS_PARAMETERS)
                            IF(ASSOCIATED(EQUATIONS_SET%MATERIALS)) THEN
                              MATERIALS_FIELD=>EQUATIONS_SET%MATERIALS%MATERIALS_FIELD
                              CALL FIELD_VARIABLE_GET(MATERIALS_FIELD,FIELD_U_VARIABLE_TYPE,MATERIALS_VARIABLE,ERR,ERROR,*999)
                              CALL FIELD_PARAMETER_SET_DATA_GET(MATERIALS_FIELD,FIELD_U_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE, &
                                & MATERIALS_PARAMETERS,ERR,ERROR,*999)           
                            END IF
                            TIME=EQUATIONS_SET%ANALYTIC%ANALYTIC_TIME
                            ! Interpolation parameters
                            NULLIFY(INTERPOLATION_PARAMETERS)
                            CALL FIELD_INTERPOLATION_PARAMETERS_INITIALISE(GEOMETRIC_FIELD,INTERPOLATION_PARAMETERS,ERR,ERROR,*999)
                            NULLIFY(INTERPOLATED_POINT) 
                            CALL FIELD_INTERPOLATED_POINTS_INITIALISE(INTERPOLATION_PARAMETERS,INTERPOLATED_POINT,ERR,ERROR,*999)
                            CALL FIELD_NUMBER_OF_COMPONENTS_GET(GEOMETRIC_FIELD,FIELD_U_VARIABLE_TYPE,NUMBER_OF_DIMENSIONS, &
                             & ERR,ERROR,*999)
                            DO variable_idx=1,DEPENDENT_FIELD%NUMBER_OF_VARIABLES
                              variable_type=DEPENDENT_FIELD%VARIABLES(variable_idx)%VARIABLE_TYPE
                              FIELD_VARIABLE=>DEPENDENT_FIELD%VARIABLE_TYPE_MAP(variable_type)%PTR
                              IF(ASSOCIATED(FIELD_VARIABLE)) THEN
                                DO componentIdx=1,FIELD_VARIABLE%NUMBER_OF_COMPONENTS
                                  IF(FIELD_VARIABLE%COMPONENTS(componentIdx)%INTERPOLATION_TYPE== & 
                                    & FIELD_NODE_BASED_INTERPOLATION) THEN
                                    DOMAIN=>FIELD_VARIABLE%COMPONENTS(componentIdx)%DOMAIN
                                    IF(ASSOCIATED(DOMAIN)) THEN
                                      IF(ASSOCIATED(DOMAIN%TOPOLOGY)) THEN
                                        DOMAIN_NODES=>DOMAIN%TOPOLOGY%NODES
                                        IF(ASSOCIATED(DOMAIN_NODES)) THEN
                                          !Should be replaced by boundary node flag
                                          DO node_idx=1,DOMAIN_NODES%NUMBER_OF_NODES
                                            element_idx=DOMAIN%topology%nodes%nodes(node_idx)%surrounding_elements(1)
                                            CALL FIELD_INTERPOLATION_PARAMETERS_ELEMENT_GET(FIELD_VALUES_SET_TYPE,element_idx, &
                                              & INTERPOLATION_PARAMETERS(FIELD_U_VARIABLE_TYPE)%PTR,ERR,ERROR,*999)
                                            en_idx=0
                                            XI_COORDINATES=0.0_DP
                                            number_of_nodes_xic(1)=DOMAIN%topology%elements%elements(element_idx)% &
                                              & basis%number_of_nodes_xic(1)
                                            number_of_nodes_xic(2)=DOMAIN%topology%elements%elements(element_idx)% & 
                                              & basis%number_of_nodes_xic(2)
                                            IF(NUMBER_OF_DIMENSIONS==3) THEN
                                              number_of_nodes_xic(3)=DOMAIN%topology%elements%elements(element_idx)%basis% &
                                                & number_of_nodes_xic(3)
                                            ELSE
                                              number_of_nodes_xic(3)=1
                                            END IF
!\todo: change definitions as soon as adjacent elements / boundary elements calculation works for simplex
                                            IF(DOMAIN%topology%elements%maximum_number_of_element_parameters==4 .OR. &
                                              & DOMAIN%topology%elements%maximum_number_of_element_parameters==9 .OR. &
                                              & DOMAIN%topology%elements%maximum_number_of_element_parameters==16 .OR. &
                                              & DOMAIN%topology%elements%maximum_number_of_element_parameters==8 .OR. &
                                              & DOMAIN%topology%elements%maximum_number_of_element_parameters==27 .OR. &
                                              & DOMAIN%topology%elements%maximum_number_of_element_parameters==64) THEN
                                              DO K=1,number_of_nodes_xic(3)
                                                DO J=1,number_of_nodes_xic(2)
                                                  DO I=1,number_of_nodes_xic(1)
                                                    en_idx=en_idx+1
                                                    IF(DOMAIN%topology%elements%elements(element_idx)% & 
                                                      & element_nodes(en_idx)==node_idx) EXIT
                                                    XI_COORDINATES(1)=XI_COORDINATES(1)+(1.0_DP/(number_of_nodes_xic(1)-1))
                                                  END DO !I
                                                  IF(DOMAIN%topology%elements%elements(element_idx)% &
                                                    & element_nodes(en_idx)==node_idx) EXIT
                                                  XI_COORDINATES(1)=0.0_DP
                                                  XI_COORDINATES(2)=XI_COORDINATES(2)+(1.0_DP/(number_of_nodes_xic(2)-1))
                                                END DO !J
                                                IF(DOMAIN%topology%elements%elements(element_idx)% & 
                                                  & element_nodes(en_idx)==node_idx) EXIT
                                                XI_COORDINATES(1)=0.0_DP
                                                XI_COORDINATES(2)=0.0_DP
                                                IF(number_of_nodes_xic(3)/=1) THEN
                                                  XI_COORDINATES(3)=XI_COORDINATES(3)+(1.0_DP/(number_of_nodes_xic(3)-1))
                                                END IF
                                              END DO !K
                                              CALL FIELD_INTERPOLATE_XI(NO_PART_DERIV,XI_COORDINATES, &
                                                & INTERPOLATED_POINT(FIELD_U_VARIABLE_TYPE)%PTR,ERR,ERROR,*999)
                                            ELSE
                                              !\todo: Use boundary flag
                                              IF(DOMAIN%topology%elements%maximum_number_of_element_parameters==3) THEN
                                                T_COORDINATES(1,1:2)=[0.0_DP,1.0_DP]
                                                T_COORDINATES(2,1:2)=[1.0_DP,0.0_DP]
                                                T_COORDINATES(3,1:2)=[1.0_DP,1.0_DP]
                                              ELSE IF(DOMAIN%topology%elements%maximum_number_of_element_parameters==6) THEN
                                                T_COORDINATES(1,1:2)=[0.0_DP,1.0_DP]
                                                T_COORDINATES(2,1:2)=[1.0_DP,0.0_DP]
                                                T_COORDINATES(3,1:2)=[1.0_DP,1.0_DP]
                                                T_COORDINATES(4,1:2)=[0.5_DP,0.5_DP]
                                                T_COORDINATES(5,1:2)=[1.0_DP,0.5_DP]
                                                T_COORDINATES(6,1:2)=[0.5_DP,1.0_DP]
                                              ELSE IF(DOMAIN%topology%elements%maximum_number_of_element_parameters==10.AND. & 
                                                & NUMBER_OF_DIMENSIONS==2) THEN
                                                T_COORDINATES(1,1:2)=[0.0_DP,1.0_DP]
                                                T_COORDINATES(2,1:2)=[1.0_DP,0.0_DP]
                                                T_COORDINATES(3,1:2)=[1.0_DP,1.0_DP]
                                                T_COORDINATES(4,1:2)=[1.0_DP/3.0_DP,2.0_DP/3.0_DP]
                                                T_COORDINATES(5,1:2)=[2.0_DP/3.0_DP,1.0_DP/3.0_DP]
                                                T_COORDINATES(6,1:2)=[1.0_DP,1.0_DP/3.0_DP]
                                                T_COORDINATES(7,1:2)=[1.0_DP,2.0_DP/3.0_DP]
                                                T_COORDINATES(8,1:2)=[2.0_DP/3.0_DP,1.0_DP]
                                                T_COORDINATES(9,1:2)=[1.0_DP/3.0_DP,1.0_DP]
                                                T_COORDINATES(10,1:2)=[2.0_DP/3.0_DP,2.0_DP/3.0_DP]
                                              ELSE IF(DOMAIN%topology%elements%maximum_number_of_element_parameters==4) THEN
                                                T_COORDINATES(1,1:3)=[0.0_DP,1.0_DP,1.0_DP]
                                                T_COORDINATES(2,1:3)=[1.0_DP,0.0_DP,1.0_DP]
                                                T_COORDINATES(3,1:3)=[1.0_DP,1.0_DP,0.0_DP]
                                                T_COORDINATES(4,1:3)=[1.0_DP,1.0_DP,1.0_DP]
                                              ELSE IF(DOMAIN%topology%elements%maximum_number_of_element_parameters==10.AND. & 
                                                & NUMBER_OF_DIMENSIONS==3) THEN
                                                T_COORDINATES(1,1:3)=[0.0_DP,1.0_DP,1.0_DP]
                                                T_COORDINATES(2,1:3)=[1.0_DP,0.0_DP,1.0_DP]
                                                T_COORDINATES(3,1:3)=[1.0_DP,1.0_DP,0.0_DP]
                                                T_COORDINATES(4,1:3)=[1.0_DP,1.0_DP,1.0_DP]
                                                T_COORDINATES(5,1:3)=[0.5_DP,0.5_DP,1.0_DP]
                                                T_COORDINATES(6,1:3)=[0.5_DP,1.0_DP,0.5_DP]
                                                T_COORDINATES(7,1:3)=[0.5_DP,1.0_DP,1.0_DP]
                                                T_COORDINATES(8,1:3)=[1.0_DP,0.5_DP,0.5_DP]
                                                T_COORDINATES(9,1:3)=[1.0_DP,1.0_DP,0.5_DP]
                                                T_COORDINATES(10,1:3)=[1.0_DP,0.5_DP,1.0_DP]
                                              ELSE IF(DOMAIN%topology%elements%maximum_number_of_element_parameters==20) THEN
                                                T_COORDINATES(1,1:3)=[0.0_DP,1.0_DP,1.0_DP]
                                                T_COORDINATES(2,1:3)=[1.0_DP,0.0_DP,1.0_DP]
                                                T_COORDINATES(3,1:3)=[1.0_DP,1.0_DP,0.0_DP]
                                                T_COORDINATES(4,1:3)=[1.0_DP,1.0_DP,1.0_DP]
                                                T_COORDINATES(5,1:3)=[1.0_DP/3.0_DP,2.0_DP/3.0_DP,1.0_DP]
                                                T_COORDINATES(6,1:3)=[2.0_DP/3.0_DP,1.0_DP/3.0_DP,1.0_DP]
                                                T_COORDINATES(7,1:3)=[1.0_DP/3.0_DP,1.0_DP,2.0_DP/3.0_DP]
                                                T_COORDINATES(8,1:3)=[2.0_DP/3.0_DP,1.0_DP,1.0_DP/3.0_DP]
                                                T_COORDINATES(9,1:3)=[1.0_DP/3.0_DP,1.0_DP,1.0_DP]
                                                T_COORDINATES(10,1:3)=[2.0_DP/3.0_DP,1.0_DP,1.0_DP]
                                                T_COORDINATES(11,1:3)=[1.0_DP,1.0_DP/3.0_DP,2.0_DP/3.0_DP]
                                                T_COORDINATES(12,1:3)=[1.0_DP,2.0_DP/3.0_DP,1.0_DP/3.0_DP]
                                                T_COORDINATES(13,1:3)=[1.0_DP,1.0_DP,1.0_DP/3.0_DP]
                                                T_COORDINATES(14,1:3)=[1.0_DP,1.0_DP,2.0_DP/3.0_DP]
                                                T_COORDINATES(15,1:3)=[1.0_DP,1.0_DP/3.0_DP,1.0_DP]
                                                T_COORDINATES(16,1:3)=[1.0_DP,2.0_DP/3.0_DP,1.0_DP]
                                                T_COORDINATES(17,1:3)=[2.0_DP/3.0_DP,2.0_DP/3.0_DP,2.0_DP/3.0_DP]
                                                T_COORDINATES(18,1:3)=[2.0_DP/3.0_DP,2.0_DP/3.0_DP,1.0_DP]
                                                T_COORDINATES(19,1:3)=[2.0_DP/3.0_DP,1.0_DP,2.0_DP/3.0_DP]
                                                T_COORDINATES(20,1:3)=[1.0_DP,2.0_DP/3.0_DP,2.0_DP/3.0_DP]
                                              END IF
                                              DO K=1,DOMAIN%topology%elements%maximum_number_of_element_parameters
                                                IF(DOMAIN%topology%elements%elements(element_idx)%element_nodes(K)==node_idx) EXIT
                                              END DO !K
                                              IF(NUMBER_OF_DIMENSIONS==2) THEN
                                                CALL FIELD_INTERPOLATE_XI(NO_PART_DERIV,T_COORDINATES(K,1:2), &
                                                  & INTERPOLATED_POINT(FIELD_U_VARIABLE_TYPE)%PTR,ERR,ERROR,*999)
                                              ELSE IF(NUMBER_OF_DIMENSIONS==3) THEN
                                                CALL FIELD_INTERPOLATE_XI(NO_PART_DERIV,T_COORDINATES(K,1:3), &
                                                  & INTERPOLATED_POINT(FIELD_U_VARIABLE_TYPE)%PTR,ERR,ERROR,*999)
                                              END IF
                                            END IF
                                            X=0.0_DP
                                            DO dim_idx=1,NUMBER_OF_DIMENSIONS
                                              X(dim_idx)=INTERPOLATED_POINT(FIELD_U_VARIABLE_TYPE)%PTR%VALUES(dim_idx,1)
                                            END DO !dim_idx
                                            !Loop over the derivatives
                                            DO deriv_idx=1,DOMAIN_NODES%NODES(node_idx)%NUMBER_OF_DERIVATIVES
                                              ANALYTIC_FUNCTION_TYPE=EQUATIONS_SET%ANALYTIC%ANALYTIC_FUNCTION_TYPE
                                              GLOBAL_DERIV_INDEX=DOMAIN_NODES%NODES(node_idx)%DERIVATIVES(deriv_idx)% &
                                                & GLOBAL_DERIVATIVE_INDEX
                                              MATERIALS_FIELD=>EQUATIONS_SET%MATERIALS%MATERIALS_FIELD
                                              !Define MU_PARAM, density=1
                                              MU_PARAM=MATERIALS_FIELD%variables(1)%parameter_sets%parameter_sets(1)%ptr% &
                                                & parameters%cmiss%data_dp(1)
                                              !Define RHO_PARAM, density=2
                                              RHO_PARAM=MATERIALS_FIELD%variables(1)%parameter_sets%parameter_sets(1)%ptr% &
                                                & parameters%cmiss%data_dp(2)
                                              CALL NAVIER_STOKES_ANALYTIC_FUNCTIONS_EVALUATE(ANALYTIC_FUNCTION_TYPE,X, &
                                                & CURRENT_TIME,variable_type,GLOBAL_DERIV_INDEX,componentIdx,NUMBER_OF_DIMENSIONS,& 
                                                & FIELD_VARIABLE%NUMBER_OF_COMPONENTS,ANALYTIC_PARAMETERS, &
                                                & MATERIALS_PARAMETERS,VALUE,ERR,ERROR,*999)
                                              !Default to version 1 of each node derivative
                                              local_ny=FIELD_VARIABLE%COMPONENTS(componentIdx)%PARAM_TO_DOF_MAP% &
                                                & NODE_PARAM2DOF_MAP%NODES(node_idx)%DERIVATIVES(deriv_idx)%VERSIONS(1)
                                              CALL FIELD_PARAMETER_SET_UPDATE_LOCAL_DOF(DEPENDENT_FIELD,variable_type, &
                                                & FIELD_ANALYTIC_VALUES_SET_TYPE,local_ny,VALUE,ERR,ERROR,*999)
                                              CALL BOUNDARY_CONDITIONS_VARIABLE_GET(BOUNDARY_CONDITIONS,DEPENDENT_FIELD% &
                                                & VARIABLE_TYPE_MAP(FIELD_U_VARIABLE_TYPE)%PTR,BOUNDARY_CONDITIONS_VARIABLE, &
                                                & ERR,ERROR,*999)
                                              IF(ASSOCIATED(BOUNDARY_CONDITIONS_VARIABLE)) THEN
                                                BOUNDARY_CONDITION_CHECK_VARIABLE=BOUNDARY_CONDITIONS_VARIABLE% &
                                                  & CONDITION_TYPES(local_ny)
                                                IF(BOUNDARY_CONDITION_CHECK_VARIABLE==BOUNDARY_CONDITION_FIXED) THEN
                                                  CALL FIELD_PARAMETER_SET_UPDATE_LOCAL_DOF(DEPENDENT_FIELD, &
                                                   & variable_type,FIELD_VALUES_SET_TYPE,local_ny, &
                                                   & VALUE,ERR,ERROR,*999)
                                                END IF
                                              ELSE
                                                CALL FlagError("Boundary conditions U variable is not associated.", &
                                                  & ERR,ERROR,*999)
                                              END IF
                                            END DO !deriv_idx
                                          END DO !node_idx
                                        ELSE
                                          CALL FlagError("Domain topology nodes is not associated.",ERR,ERROR,*999)
                                        END IF
                                      ELSE
                                        CALL FlagError("Domain topology is not associated.",ERR,ERROR,*999)
                                      END IF
                                    ELSE
                                      CALL FlagError("Domain is not associated.",ERR,ERROR,*999)
                                    END IF
                                  ELSE
                                    CALL FlagError("Only node based interpolation is implemented.",ERR,ERROR,*999)
                                  END IF
                                END DO !componentIdx
                                CALL FIELD_PARAMETER_SET_UPDATE_START(DEPENDENT_FIELD,variable_type, &
                                 & FIELD_ANALYTIC_VALUES_SET_TYPE,ERR,ERROR,*999)
                                CALL FIELD_PARAMETER_SET_UPDATE_FINISH(DEPENDENT_FIELD,variable_type, &
                                 & FIELD_ANALYTIC_VALUES_SET_TYPE,ERR,ERROR,*999)
                                CALL FIELD_PARAMETER_SET_UPDATE_START(DEPENDENT_FIELD,variable_type, &
                                 & FIELD_VALUES_SET_TYPE,ERR,ERROR,*999)
                                CALL FIELD_PARAMETER_SET_UPDATE_FINISH(DEPENDENT_FIELD,variable_type, &
                                 & FIELD_VALUES_SET_TYPE,ERR,ERROR,*999)
                              ELSE
                                CALL FlagError("Field variable is not associated.",ERR,ERROR,*999)
                              END IF
                            END DO !variable_idx
                            CALL FIELD_PARAMETER_SET_DATA_RESTORE(GEOMETRIC_FIELD,FIELD_U_VARIABLE_TYPE,&
                             & FIELD_VALUES_SET_TYPE,GEOMETRIC_PARAMETERS,ERR,ERROR,*999)
                          ELSE
                            CALL FlagError("Equations set geometric field is not associated.",ERR,ERROR,*999)
                          END IF
                        ELSE
                          CALL FlagError("Equations set dependent field is not associated.",ERR,ERROR,*999)
                        END IF
                      ELSE
                        CALL FlagError("Equations set is not associated.",ERR,ERROR,*999)
                      END IF
                    END IF !Standard/unit analytic subtypes

                  END IF ! Analytic boundary conditions

                  !TODO implement non-analytic time-varying boundary conditions (i.e. from file)
                ELSE
                  CALL FlagError("Equations are not associated.",ERR,ERROR,*999)
                END IF
              ELSE
                CALL FlagError("Solver equations are not associated.",ERR,ERROR,*999)
              END IF
              CALL FIELD_PARAMETER_SET_UPDATE_START(EQUATIONS_SET%DEPENDENT%DEPENDENT_FIELD,FIELD_U_VARIABLE_TYPE, &
                & FIELD_VALUES_SET_TYPE,ERR,ERROR,*999)
              CALL FIELD_PARAMETER_SET_UPDATE_FINISH(EQUATIONS_SET%DEPENDENT%DEPENDENT_FIELD,FIELD_U_VARIABLE_TYPE, &
                & FIELD_VALUES_SET_TYPE,ERR,ERROR,*999)
            CASE(PROBLEM_TRANSIENT1D_NAVIER_STOKES_SUBTYPE, &
               & PROBLEM_COUPLED1D0D_NAVIER_STOKES_SUBTYPE, &
               & PROBLEM_STREE1D0D_NAVIER_STOKES_SUBTYPE, &
               & PROBLEM_TRANSIENT1D_ADV_NAVIER_STOKES_SUBTYPE, &
               & PROBLEM_COUPLED1D0D_ADV_NAVIER_STOKES_SUBTYPE, &
               & PROBLEM_STREE1D0D_ADV_NAVIER_STOKES_SUBTYPE)
              SOLVER_EQUATIONS=>SOLVER%SOLVER_EQUATIONS
              IF(ASSOCIATED(SOLVER_EQUATIONS)) THEN
                !If analytic flow waveform, calculate and update
                SOLVER_MAPPING=>SOLVER_EQUATIONS%SOLVER_MAPPING
                IF(ASSOCIATED(SOLVER_MAPPING)) THEN
                  EQUATIONS=>SOLVER_MAPPING%EQUATIONS_SET_TO_SOLVER_MAP(1)%EQUATIONS
                  IF(ASSOCIATED(EQUATIONS)) THEN
                    EQUATIONS_SET=>EQUATIONS%EQUATIONS_SET
                    IF(ASSOCIATED(EQUATIONS_SET%ANALYTIC)) THEN
                      SELECT CASE(EQUATIONS_SET%ANALYTIC%ANALYTIC_FUNCTION_TYPE)
                      CASE(EQUATIONS_SET_NAVIER_STOKES_EQUATION_FLOWRATE_AORTA, &
                         & EQUATIONS_SET_NAVIER_STOKES_EQUATION_FLOWRATE_OLUFSEN)
                        EQUATIONS_SET%ANALYTIC%ANALYTIC_TIME=CURRENT_TIME
                        BOUNDARY_CONDITIONS=>SOLVER_EQUATIONS%BOUNDARY_CONDITIONS
                        IF(ASSOCIATED(BOUNDARY_CONDITIONS)) THEN
                          ! Calculate analytic values
                          CALL NavierStokes_BoundaryConditionsAnalyticCalculate(EQUATIONS_SET,BOUNDARY_CONDITIONS,ERR,ERROR,*999)
                        ELSE
                          CALL FlagError("Boundary conditions are not associated.",ERR,ERROR,*999)
                        END IF
                      CASE(EQUATIONS_SET_NAVIER_STOKES_EQUATION_SPLINT_FROM_FILE)
                        ! Perform spline interpolation of values from a file
                        EQUATIONS_SET%ANALYTIC%ANALYTIC_TIME=CURRENT_TIME
                        BOUNDARY_CONDITIONS=>SOLVER_EQUATIONS%BOUNDARY_CONDITIONS
                        DEPENDENT_FIELD=>EQUATIONS_SET%DEPENDENT%DEPENDENT_FIELD
                        ANALYTIC_FIELD=>EQUATIONS_SET%ANALYTIC%ANALYTIC_FIELD
                        DO variableIdx=1,DEPENDENT_FIELD%NUMBER_OF_VARIABLES
                          dependentVariableType=DEPENDENT_FIELD%VARIABLES(variableIdx)%VARIABLE_TYPE
                          NULLIFY(dependentFieldVariable)
                          CALL FIELD_VARIABLE_GET(DEPENDENT_FIELD,dependentVariableType,dependentFieldVariable,ERR,ERROR,*999)
                          CALL BOUNDARY_CONDITIONS_VARIABLE_GET(BOUNDARY_CONDITIONS, &
                           & dependentFieldVariable,BOUNDARY_CONDITIONS_VARIABLE,ERR,ERROR,*999)
                          IF(ASSOCIATED(BOUNDARY_CONDITIONS_VARIABLE)) THEN
                            IF(ASSOCIATED(dependentFieldVariable)) THEN
                              DO componentIdx=1,dependentFieldVariable%NUMBER_OF_COMPONENTS
                                IF(dependentFieldVariable%COMPONENTS(componentIdx)%INTERPOLATION_TYPE== &
                                 & FIELD_NODE_BASED_INTERPOLATION) THEN
                                  domain=>dependentFieldVariable%COMPONENTS(componentIdx)%DOMAIN
                                  IF(ASSOCIATED(domain)) THEN
                                    IF(ASSOCIATED(domain%TOPOLOGY)) THEN
                                      DOMAIN_NODES=>domain%TOPOLOGY%NODES
                                      IF(ASSOCIATED(DOMAIN_NODES)) THEN
                                        !Loop over the local nodes excluding the ghosts.
                                        DO nodeIdx=1,DOMAIN_NODES%NUMBER_OF_NODES
                                          userNodeNumber=DOMAIN_NODES%NODES(nodeIdx)%USER_NUMBER
                                          DO derivativeIdx=1,DOMAIN_NODES%NODES(nodeIdx)%NUMBER_OF_DERIVATIVES
                                            DO versionIdx=1,DOMAIN_NODES%NODES(nodeIdx)%DERIVATIVES(derivativeIdx)%numberOfVersions
                                              ! Update analytic field if file exists and dependent field if boundary condition set
                                              inputFile = './input/interpolatedData/1D/' 
                                              IF(dependentVariableType == FIELD_U_VARIABLE_TYPE) THEN
                                                inputFile = TRIM(inputFile) // 'U/component' 
                                              END IF
                                              WRITE(tempString,"(I1.1)") componentIdx 
                                              inputFile = TRIM(inputFile) // tempString(1:1) // '/derivative'
                                              WRITE(tempString,"(I1.1)") derivativeIdx 
                                              inputFile = TRIM(inputFile) // tempString(1:1) // '/version'
                                              WRITE(tempString,"(I1.1)") versionIdx 
                                              inputFile = TRIM(inputFile) // tempString(1:1) // '/'
                                              WRITE(tempString,"(I4.4)") userNodeNumber
                                              inputFile = TRIM(inputFile) // tempString(1:4) // '.dat'
                                              inputFile = TRIM(inputFile)
                                              INQUIRE(FILE=inputFile, EXIST=importDataFromFile)
                                              IF(importDataFromFile) THEN
                                                ! Create the analytic field values type on the dependent field if it does not exist
                                                IF(.NOT.ASSOCIATED(dependentFieldVariable%PARAMETER_SETS% &
                                                  & SET_TYPE(FIELD_ANALYTIC_VALUES_SET_TYPE)%PTR)) &
                                                  & CALL FIELD_PARAMETER_SET_CREATE(DEPENDENT_FIELD,dependentVariableType, &
                                                  & FIELD_ANALYTIC_VALUES_SET_TYPE,ERR,ERROR,*999)
                                                !Read fitted data from input file (if exists)
                                                OPEN(UNIT=10, FILE=inputFile, STATUS='OLD')                  
                                                ! Header timeData = numberOfTimesteps
                                                READ(10,*) timeData
                                                numberOfSourceTimesteps = INT(timeData)
                                                ALLOCATE(nodeData(numberOfSourceTimesteps,2))
                                                ALLOCATE(qValues(numberOfSourceTimesteps))
                                                ALLOCATE(tValues(numberOfSourceTimesteps))
                                                ALLOCATE(qSpline(numberOfSourceTimesteps))
                                                nodeData = 0.0_DP                                            
                                                ! Read in time and dependent value
                                                DO timeIdx=1,numberOfSourceTimesteps
                                                  READ(10,*) (nodeData(timeIdx,component_idx), component_idx=1,2)
                                                END DO
                                                CLOSE(UNIT=10)
                                                tValues = nodeData(:,1)
                                                qValues = nodeData(:,2)
                                                CALL spline_cubic_set(numberOfSourceTimesteps,tValues,qValues,2,0.0_DP,2,0.0_DP, &
                                                  & qSpline,err,error,*999)
                                                CALL spline_cubic_val(numberOfSourceTimesteps,tValues,qValues,qSpline, & 
                                                  & CURRENT_TIME,VALUE,QP,QPP,err,error,*999)

                                                DEALLOCATE(nodeData)
                                                DEALLOCATE(qSpline)
                                                DEALLOCATE(qValues)
                                                DEALLOCATE(tValues)

                                                dependentDof = dependentFieldVariable%COMPONENTS(componentIdx)%PARAM_TO_DOF_MAP% &
                                                 & NODE_PARAM2DOF_MAP%NODES(nodeIdx)%DERIVATIVES(derivativeIdx)%VERSIONS(versionIdx)
                                                CALL FIELD_PARAMETER_SET_UPDATE_LOCAL_DOF(DEPENDENT_FIELD,dependentVariableType, &
                                                  & FIELD_ANALYTIC_VALUES_SET_TYPE,dependentDof,VALUE,ERR,ERROR,*999)
                                                ! Update dependent field value if this is a splint BC
                                                BOUNDARY_CONDITION_CHECK_VARIABLE=BOUNDARY_CONDITIONS_VARIABLE% &
                                                  & CONDITION_TYPES(dependentDof)
                                                IF(BOUNDARY_CONDITION_CHECK_VARIABLE==BOUNDARY_CONDITION_FIXED_FITTED) THEN 
                                                  CALL FIELD_PARAMETER_SET_UPDATE_LOCAL_DOF(DEPENDENT_FIELD,dependentVariableType, &
                                                    & FIELD_VALUES_SET_TYPE,dependentDof,VALUE,ERR,ERROR,*999)
                                                END IF
                                              END IF ! check if import data file exists
                                            END DO !versionIdx
                                          END DO !derivativeIdx
                                        END DO !nodeIdx
                                      ELSE
                                        CALL FlagError("Domain topology nodes is not associated.",ERR,ERROR,*999)
                                      END IF
                                    ELSE
                                      CALL FlagError("Domain topology is not associated.",ERR,ERROR,*999)
                                    END IF
                                  ELSE
                                    CALL FlagError("Domain is not associated.",ERR,ERROR,*999)
                                  END IF
                                ELSE
                                  CALL FlagError("Only node based interpolation is implemented.",ERR,ERROR,*999)
                                END IF
                              END DO !componentIdx
                            ELSE
                              CALL FlagError("Dependent field variable is not associated.",ERR,ERROR,*999)
                            END IF
                          END IF
                        END DO !variableIdx
                      CASE(EQUATIONS_SET_NAVIER_STOKES_EQUATION_FLOWRATE_HEART)
                        ! Using heart lumped parameter model for input
                        EQUATIONS_SET%ANALYTIC%ANALYTIC_TIME=CURRENT_TIME
                        BOUNDARY_CONDITIONS=>SOLVER_EQUATIONS%BOUNDARY_CONDITIONS
                        DEPENDENT_FIELD=>EQUATIONS_SET%DEPENDENT%DEPENDENT_FIELD
                        MATERIALS_FIELD=>EQUATIONS_SET%MATERIALS%MATERIALS_FIELD
                        CALL FIELD_PARAMETER_SET_GET_CONSTANT(MATERIALS_FIELD,FIELD_U_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE,5, &
                          & Lref,err,error,*999)
                        CALL FIELD_PARAMETER_SET_GET_CONSTANT(MATERIALS_FIELD,FIELD_U_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE,6, &
                          & Tref,err,error,*999)
                        CALL FIELD_PARAMETER_SET_GET_CONSTANT(MATERIALS_FIELD,FIELD_U_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE,7, &
                          & Mref,err,error,*999)
                        DO variableIdx=1,DEPENDENT_FIELD%NUMBER_OF_VARIABLES
                          dependentVariableType=DEPENDENT_FIELD%VARIABLES(variableIdx)%VARIABLE_TYPE
                          NULLIFY(dependentFieldVariable)
                          CALL FIELD_VARIABLE_GET(DEPENDENT_FIELD,dependentVariableType,dependentFieldVariable,ERR,ERROR,*999)
                          CALL BOUNDARY_CONDITIONS_VARIABLE_GET(BOUNDARY_CONDITIONS,dependentFieldVariable, &
                            & BOUNDARY_CONDITIONS_VARIABLE,ERR,ERROR,*999)
                          IF(ASSOCIATED(BOUNDARY_CONDITIONS_VARIABLE)) THEN
                            IF(ASSOCIATED(dependentFieldVariable)) THEN
                              DO componentIdx=1,dependentFieldVariable%NUMBER_OF_COMPONENTS
                                IF(dependentFieldVariable%COMPONENTS(componentIdx)%INTERPOLATION_TYPE== &
                                 & FIELD_NODE_BASED_INTERPOLATION) THEN
                                  domain=>dependentFieldVariable%COMPONENTS(componentIdx)%DOMAIN
                                  IF(ASSOCIATED(domain)) THEN
                                    IF(ASSOCIATED(domain%TOPOLOGY)) THEN
                                      DOMAIN_NODES=>domain%TOPOLOGY%NODES
                                      IF(ASSOCIATED(DOMAIN_NODES)) THEN
                                        !Loop over the local nodes excluding the ghosts.
                                        DO nodeIdx=1,DOMAIN_NODES%NUMBER_OF_NODES
                                          userNodeNumber=DOMAIN_NODES%NODES(nodeIdx)%USER_NUMBER
                                          DO derivativeIdx=1,DOMAIN_NODES%NODES(nodeIdx)%NUMBER_OF_DERIVATIVES
                                            DO versionIdx=1,DOMAIN_NODES%NODES(nodeIdx)%DERIVATIVES(derivativeIdx)%numberOfVersions
                                                dependentDof = dependentFieldVariable%COMPONENTS(componentIdx)%PARAM_TO_DOF_MAP% &
                                                 & NODE_PARAM2DOF_MAP%NODES(nodeIdx)%DERIVATIVES(derivativeIdx)%VERSIONS(versionIdx)
                                                BOUNDARY_CONDITION_CHECK_VARIABLE=BOUNDARY_CONDITIONS_VARIABLE% &
                                                  & CONDITION_TYPES(dependentDof)
                                                IF(BOUNDARY_CONDITION_CHECK_VARIABLE==BOUNDARY_CONDITION_FIXED_INLET) THEN
                                                  CALL Field_ParameterSetGetLocalNode(DEPENDENT_FIELD,FIELD_U1_VARIABLE_TYPE, &
                                                    & FIELD_VALUES_SET_TYPE,versionIdx,derivativeIdx,userNodeNumber,1,VALUE, &
                                                    & ERR,ERROR,*999)
                                                  ! Convert Q from ml/s to non-dimensionalised form.
                                                  CALL FIELD_PARAMETER_SET_UPDATE_LOCAL_DOF(DEPENDENT_FIELD,dependentVariableType, &
                                                    & FIELD_VALUES_SET_TYPE,dependentDof,((Lref**3.0)/Tref)*VALUE,ERR,ERROR,*999)
                                                END IF
                                            END DO !versionIdx
                                          END DO !derivativeIdx
                                        END DO !nodeIdx
                                      ELSE
                                        CALL FlagError("Domain topology nodes is not associated.",ERR,ERROR,*999)
                                      END IF
                                    ELSE
                                      CALL FlagError("Domain topology is not associated.",ERR,ERROR,*999)
                                    END IF
                                  ELSE
                                    CALL FlagError("Domain is not associated.",ERR,ERROR,*999)
                                  END IF
                                ELSE
                                  CALL FlagError("Only node based interpolation is implemented.",ERR,ERROR,*999)
                                END IF
                              END DO !componentIdx
                            ELSE
                              CALL FlagError("Dependent field variable is not associated.",ERR,ERROR,*999)
                            END IF
                          END IF
                        END DO !variableIdx
                      CASE DEFAULT
                        ! Do nothing (might have another use for analytic equations)
                      END SELECT
                    END IF ! Check for analytic equations
                  ELSE
                    CALL FlagError("Equations are not associated.",ERR,ERROR,*999)
                  END IF
                ELSE
                  CALL FlagError("Solver mapping is not associated.",ERR,ERROR,*999)
                END IF
              END IF ! solver equations associated
              ! Update any multiscale boundary values (coupled 0D or non-reflecting)
              CALL NavierStokes_UpdateMultiscaleBoundary(solver,err,error,*999)
            CASE(PROBLEM_QUASISTATIC_NAVIER_STOKES_SUBTYPE)
              !Pre solve for the linear solver
              SOLVER_EQUATIONS=>SOLVER%SOLVER_EQUATIONS
              IF(ASSOCIATED(SOLVER_EQUATIONS)) THEN
                SOLVER_MAPPING=>SOLVER_EQUATIONS%SOLVER_MAPPING
                EQUATIONS=>SOLVER_MAPPING%EQUATIONS_SET_TO_SOLVER_MAP(1)%EQUATIONS
                IF(ASSOCIATED(EQUATIONS)) THEN
                  EQUATIONS_SET=>EQUATIONS%EQUATIONS_SET
                  IF(ASSOCIATED(EQUATIONS_SET)) THEN
                    BOUNDARY_CONDITIONS=>SOLVER_EQUATIONS%BOUNDARY_CONDITIONS
                    IF(ASSOCIATED(BOUNDARY_CONDITIONS)) THEN
                      FIELD_VARIABLE=>EQUATIONS_SET%DEPENDENT%DEPENDENT_FIELD%VARIABLE_TYPE_MAP(FIELD_U_VARIABLE_TYPE)%PTR
                      IF(ASSOCIATED(FIELD_VARIABLE)) THEN
                        CALL BOUNDARY_CONDITIONS_VARIABLE_GET(BOUNDARY_CONDITIONS,FIELD_VARIABLE, &
                          & BOUNDARY_CONDITIONS_VARIABLE,ERR,ERROR,*999)
                      ELSE
                        CALL FlagError("Field U variable is not associated",ERR,ERROR,*999)
                      END IF
                      IF(ASSOCIATED(BOUNDARY_CONDITIONS_VARIABLE)) THEN
                       CALL FIELD_NUMBER_OF_COMPONENTS_GET(EQUATIONS_SET%GEOMETRY%GEOMETRIC_FIELD,FIELD_U_VARIABLE_TYPE, &
                        & NUMBER_OF_DIMENSIONS,ERR,ERROR,*999)
                       NULLIFY(BOUNDARY_VALUES)
                       CALL FIELD_PARAMETER_SET_DATA_GET(EQUATIONS_SET%DEPENDENT%DEPENDENT_FIELD,FIELD_U_VARIABLE_TYPE, &
                         & FIELD_BOUNDARY_SET_TYPE,BOUNDARY_VALUES,ERR,ERROR,*999)
                       CALL FLUID_MECHANICS_IO_READ_BOUNDARY_CONDITIONS(SOLVER_NONLINEAR_TYPE,BOUNDARY_VALUES, &
                         & NUMBER_OF_DIMENSIONS,BOUNDARY_CONDITION_FIXED_INLET,CONTROL_LOOP%TIME_LOOP%INPUT_NUMBER, &
                         & CONTROL_LOOP%TIME_LOOP%ITERATION_NUMBER,CURRENT_TIME,1.0_DP)
                       DO variable_idx=1,EQUATIONS_SET%DEPENDENT%DEPENDENT_FIELD%NUMBER_OF_VARIABLES
                         variable_type=EQUATIONS_SET%DEPENDENT%DEPENDENT_FIELD%VARIABLES(variable_idx)%VARIABLE_TYPE
                         FIELD_VARIABLE=>EQUATIONS_SET%DEPENDENT%DEPENDENT_FIELD%VARIABLE_TYPE_MAP(variable_type)%PTR
                         IF(ASSOCIATED(FIELD_VARIABLE)) THEN
                           DO componentIdx=1,FIELD_VARIABLE%NUMBER_OF_COMPONENTS
                             DOMAIN=>FIELD_VARIABLE%COMPONENTS(componentIdx)%DOMAIN
                             IF(ASSOCIATED(DOMAIN)) THEN
                               IF(ASSOCIATED(DOMAIN%TOPOLOGY)) THEN
                                 DOMAIN_NODES=>DOMAIN%TOPOLOGY%NODES
                                 IF(ASSOCIATED(DOMAIN_NODES)) THEN
                                   !Loop over the local nodes excluding the ghosts.
                                   DO node_idx=1,DOMAIN_NODES%NUMBER_OF_NODES
                                     DO deriv_idx=1,DOMAIN_NODES%NODES(node_idx)%NUMBER_OF_DERIVATIVES
                                       !Default to version 1 of each node derivative
                                       local_ny=FIELD_VARIABLE%COMPONENTS(componentIdx)%PARAM_TO_DOF_MAP% &
                                         & NODE_PARAM2DOF_MAP%NODES(node_idx)%DERIVATIVES(deriv_idx)%VERSIONS(1)
                                       BOUNDARY_CONDITION_CHECK_VARIABLE=BOUNDARY_CONDITIONS_VARIABLE% &
                                         & CONDITION_TYPES(local_ny)
                                       IF(BOUNDARY_CONDITION_CHECK_VARIABLE==BOUNDARY_CONDITION_FIXED_INLET) THEN
                                         CALL FIELD_PARAMETER_SET_UPDATE_LOCAL_DOF(EQUATIONS_SET%DEPENDENT%DEPENDENT_FIELD, &
                                           & FIELD_U_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE,local_ny, &
                                           & BOUNDARY_VALUES(local_ny),ERR,ERROR,*999)
                                       END IF
                                     END DO !deriv_idx
                                   END DO !node_idx
                                 END IF
                               END IF
                             END IF
                           END DO !componentIdx
                         END IF
                       END DO !variable_idx

  !\todo: This part should be read in out of a file eventually
                     ELSE
                       CALL FlagError("Boundary condition variable is not associated.",ERR,ERROR,*999)
                     END IF
                   ELSE
                     CALL FlagError("Boundary conditions are not associated.",ERR,ERROR,*999)
                   END IF
                 ELSE
                   CALL FlagError("Equations set is not associated.",ERR,ERROR,*999)
                 END IF
               ELSE
                 CALL FlagError("Equations are not associated.",ERR,ERROR,*999)
               END IF
              ELSE
                CALL FlagError("Solver equations are not associated.",ERR,ERROR,*999)
              END IF
              CALL FIELD_PARAMETER_SET_UPDATE_START(EQUATIONS_SET%DEPENDENT%DEPENDENT_FIELD,FIELD_U_VARIABLE_TYPE, &
                & FIELD_VALUES_SET_TYPE,ERR,ERROR,*999)
              CALL FIELD_PARAMETER_SET_UPDATE_FINISH(EQUATIONS_SET%DEPENDENT%DEPENDENT_FIELD,FIELD_U_VARIABLE_TYPE, &
                & FIELD_VALUES_SET_TYPE,ERR,ERROR,*999)
            CASE(PROBLEM_PGM_NAVIER_STOKES_SUBTYPE)
             !Pre solve for the dynamic solver
             IF(SOLVER%SOLVE_TYPE==SOLVER_DYNAMIC_TYPE) THEN
               CALL WRITE_STRING(GENERAL_OUTPUT_TYPE,"Mesh movement change boundary conditions... ",ERR,ERROR,*999)
                SOLVER_EQUATIONS=>SOLVER%SOLVER_EQUATIONS
                IF(ASSOCIATED(SOLVER_EQUATIONS)) THEN
                  SOLVER_MAPPING=>SOLVER_EQUATIONS%SOLVER_MAPPING
                  EQUATIONS=>SOLVER_MAPPING%EQUATIONS_SET_TO_SOLVER_MAP(1)%EQUATIONS
                  IF(ASSOCIATED(EQUATIONS)) THEN
                    EQUATIONS_SET=>EQUATIONS%EQUATIONS_SET
                    IF(ASSOCIATED(EQUATIONS_SET)) THEN
                      BOUNDARY_CONDITIONS=>SOLVER_EQUATIONS%BOUNDARY_CONDITIONS
                      IF(ASSOCIATED(BOUNDARY_CONDITIONS)) THEN
                        FIELD_VARIABLE=>EQUATIONS_SET%DEPENDENT%DEPENDENT_FIELD%VARIABLE_TYPE_MAP(FIELD_U_VARIABLE_TYPE)%PTR
                        IF(ASSOCIATED(FIELD_VARIABLE)) THEN
                          CALL BOUNDARY_CONDITIONS_VARIABLE_GET(BOUNDARY_CONDITIONS,FIELD_VARIABLE, &
                            & BOUNDARY_CONDITIONS_VARIABLE,ERR,ERROR,*999)
                        ELSE
                          CALL FlagError("Field U variable is not associated",ERR,ERROR,*999)
                        END IF
                        IF(ASSOCIATED(BOUNDARY_CONDITIONS_VARIABLE)) THEN
                          CALL FIELD_NUMBER_OF_COMPONENTS_GET(EQUATIONS_SET%GEOMETRY%GEOMETRIC_FIELD,FIELD_U_VARIABLE_TYPE, &
                            & NUMBER_OF_DIMENSIONS,ERR,ERROR,*999)
                          NULLIFY(MESH_VELOCITY_VALUES)
                          CALL FIELD_PARAMETER_SET_DATA_GET(EQUATIONS_SET%INDEPENDENT%INDEPENDENT_FIELD,FIELD_U_VARIABLE_TYPE, & 
                            & FIELD_MESH_VELOCITY_SET_TYPE,MESH_VELOCITY_VALUES,ERR,ERROR,*999)
                          NULLIFY(BOUNDARY_VALUES)
                          CALL FIELD_PARAMETER_SET_DATA_GET(EQUATIONS_SET%INDEPENDENT%INDEPENDENT_FIELD,FIELD_U_VARIABLE_TYPE, & 
                            & FIELD_BOUNDARY_SET_TYPE,BOUNDARY_VALUES,ERR,ERROR,*999)
                          CALL FLUID_MECHANICS_IO_READ_BOUNDARY_CONDITIONS(SOLVER_LINEAR_TYPE,BOUNDARY_VALUES, & 
                            & NUMBER_OF_DIMENSIONS,BOUNDARY_CONDITION_FIXED_INLET,CONTROL_LOOP%TIME_LOOP%INPUT_NUMBER, &
                            & CONTROL_LOOP%TIME_LOOP%ITERATION_NUMBER,CURRENT_TIME,1.0_DP)
                          DO variable_idx=1,EQUATIONS_SET%DEPENDENT%DEPENDENT_FIELD%NUMBER_OF_VARIABLES
                            variable_type=EQUATIONS_SET%DEPENDENT%DEPENDENT_FIELD%VARIABLES(variable_idx)%VARIABLE_TYPE
                            FIELD_VARIABLE=>EQUATIONS_SET%DEPENDENT%DEPENDENT_FIELD%VARIABLE_TYPE_MAP(variable_type)%PTR
                            IF(ASSOCIATED(FIELD_VARIABLE)) THEN
                              DO componentIdx=1,FIELD_VARIABLE%NUMBER_OF_COMPONENTS
                                DOMAIN=>FIELD_VARIABLE%COMPONENTS(componentIdx)%DOMAIN
                                IF(ASSOCIATED(DOMAIN)) THEN
                                  IF(ASSOCIATED(DOMAIN%TOPOLOGY)) THEN
                                    DOMAIN_NODES=>DOMAIN%TOPOLOGY%NODES
                                    IF(ASSOCIATED(DOMAIN_NODES)) THEN
                                      !Loop over the local nodes excluding the ghosts.
                                      DO node_idx=1,DOMAIN_NODES%NUMBER_OF_NODES
                                        DO deriv_idx=1,DOMAIN_NODES%NODES(node_idx)%NUMBER_OF_DERIVATIVES
                                          !Default to version 1 of each node derivative
                                          local_ny=FIELD_VARIABLE%COMPONENTS(componentIdx)%PARAM_TO_DOF_MAP% &
                                            & NODE_PARAM2DOF_MAP%NODES(node_idx)%DERIVATIVES(deriv_idx)%VERSIONS(1)
                                          DISPLACEMENT_VALUE=0.0_DP
                                          BOUNDARY_CONDITION_CHECK_VARIABLE=BOUNDARY_CONDITIONS_VARIABLE% & 
                                            & CONDITION_TYPES(local_ny)
                                          IF(BOUNDARY_CONDITION_CHECK_VARIABLE==BOUNDARY_CONDITION_MOVED_WALL) THEN
                                            CALL FIELD_PARAMETER_SET_UPDATE_LOCAL_DOF(EQUATIONS_SET%DEPENDENT%DEPENDENT_FIELD, & 
                                              & FIELD_U_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE,local_ny, & 
                                              & MESH_VELOCITY_VALUES(local_ny),ERR,ERROR,*999)
                                          ELSE IF(BOUNDARY_CONDITION_CHECK_VARIABLE==BOUNDARY_CONDITION_FIXED_INLET) THEN
                                            CALL FIELD_PARAMETER_SET_UPDATE_LOCAL_DOF(EQUATIONS_SET%DEPENDENT%DEPENDENT_FIELD, & 
                                              & FIELD_U_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE,local_ny, & 
                                              & BOUNDARY_VALUES(local_ny),ERR,ERROR,*999)
                                          END IF
                                        END DO !deriv_idx
                                      END DO !node_idx
                                    END IF
                                  END IF
                                END IF
                              END DO !componentIdx
                            END IF
                          END DO !variable_idx
                        ELSE
                          CALL FlagError("Boundary condition variable is not associated.",ERR,ERROR,*999)
                        END IF
                      ELSE
                        CALL FlagError("Boundary conditions are not associated.",ERR,ERROR,*999)
                      END IF
                    ELSE
                      CALL FlagError("Equations set is not associated.",ERR,ERROR,*999)
                    END IF
                  ELSE
                    CALL FlagError("Equations are not associated.",ERR,ERROR,*999)
                  END IF                
                ELSE
                  CALL FlagError("Solver equations are not associated.",ERR,ERROR,*999)
                END IF  
                CALL FIELD_PARAMETER_SET_UPDATE_START(EQUATIONS_SET%DEPENDENT%DEPENDENT_FIELD,FIELD_U_VARIABLE_TYPE, & 
                  & FIELD_VALUES_SET_TYPE,ERR,ERROR,*999)
                CALL FIELD_PARAMETER_SET_UPDATE_FINISH(EQUATIONS_SET%DEPENDENT%DEPENDENT_FIELD,FIELD_U_VARIABLE_TYPE, & 
                  & FIELD_VALUES_SET_TYPE,ERR,ERROR,*999)
              END IF
            CASE(PROBLEM_ALE_NAVIER_STOKES_SUBTYPE)
              !Pre solve for the linear solver
              IF(SOLVER%SOLVE_TYPE==SOLVER_LINEAR_TYPE) THEN
                CALL WRITE_STRING(GENERAL_OUTPUT_TYPE,"Mesh movement change boundary conditions... ",ERR,ERROR,*999)
                SOLVER_EQUATIONS=>SOLVER%SOLVER_EQUATIONS
                IF(ASSOCIATED(SOLVER_EQUATIONS)) THEN
                  SOLVER_MAPPING=>SOLVER_EQUATIONS%SOLVER_MAPPING
                  EQUATIONS=>SOLVER_MAPPING%EQUATIONS_SET_TO_SOLVER_MAP(1)%EQUATIONS
                  IF(ASSOCIATED(EQUATIONS)) THEN
                    EQUATIONS_SET=>EQUATIONS%EQUATIONS_SET
                    IF(ASSOCIATED(EQUATIONS_SET)) THEN
                      BOUNDARY_CONDITIONS=>SOLVER_EQUATIONS%BOUNDARY_CONDITIONS
                      IF(ASSOCIATED(BOUNDARY_CONDITIONS)) THEN
                        FIELD_VARIABLE=>EQUATIONS_SET%DEPENDENT%DEPENDENT_FIELD%VARIABLE_TYPE_MAP(FIELD_U_VARIABLE_TYPE)%PTR
                        IF(ASSOCIATED(FIELD_VARIABLE)) THEN
                          CALL BOUNDARY_CONDITIONS_VARIABLE_GET(BOUNDARY_CONDITIONS,FIELD_VARIABLE, &
                            & BOUNDARY_CONDITIONS_VARIABLE,ERR,ERROR,*999)
                        ELSE
                          CALL FlagError("Field U variable is not associated",ERR,ERROR,*999)
                        END IF
                        IF(ASSOCIATED(BOUNDARY_CONDITIONS_VARIABLE)) THEN
                          CALL FIELD_NUMBER_OF_COMPONENTS_GET(EQUATIONS_SET%GEOMETRY%GEOMETRIC_FIELD,FIELD_U_VARIABLE_TYPE, &
                            & NUMBER_OF_DIMENSIONS,ERR,ERROR,*999)
                          NULLIFY(BOUNDARY_VALUES)
                          CALL FIELD_PARAMETER_SET_DATA_GET(EQUATIONS_SET%INDEPENDENT%INDEPENDENT_FIELD,FIELD_U_VARIABLE_TYPE, & 
                            & FIELD_BOUNDARY_SET_TYPE,BOUNDARY_VALUES,ERR,ERROR,*999)
                          CALL FLUID_MECHANICS_IO_READ_BOUNDARY_CONDITIONS(SOLVER_LINEAR_TYPE,BOUNDARY_VALUES, & 
                            & NUMBER_OF_DIMENSIONS,BOUNDARY_CONDITION_MOVED_WALL,CONTROL_LOOP%TIME_LOOP%INPUT_NUMBER, &
                            & CONTROL_LOOP%TIME_LOOP%ITERATION_NUMBER,CURRENT_TIME,1.0_DP)
                          DO variable_idx=1,EQUATIONS_SET%DEPENDENT%DEPENDENT_FIELD%NUMBER_OF_VARIABLES
                            variable_type=EQUATIONS_SET%DEPENDENT%DEPENDENT_FIELD%VARIABLES(variable_idx)%VARIABLE_TYPE
                            FIELD_VARIABLE=>EQUATIONS_SET%DEPENDENT%DEPENDENT_FIELD%VARIABLE_TYPE_MAP(variable_type)%PTR
                            IF(ASSOCIATED(FIELD_VARIABLE)) THEN
                              DO component_idx=1,FIELD_VARIABLE%NUMBER_OF_COMPONENTS
                                DOMAIN=>FIELD_VARIABLE%COMPONENTS(component_idx)%DOMAIN
                                IF(ASSOCIATED(DOMAIN)) THEN
                                  IF(ASSOCIATED(DOMAIN%TOPOLOGY)) THEN
                                    DOMAIN_NODES=>DOMAIN%TOPOLOGY%NODES
                                    IF(ASSOCIATED(DOMAIN_NODES)) THEN
                                      !Loop over the local nodes excluding the ghosts.
                                      DO node_idx=1,DOMAIN_NODES%NUMBER_OF_NODES
                                        DO deriv_idx=1,DOMAIN_NODES%NODES(node_idx)%NUMBER_OF_DERIVATIVES
                                          !Default to version 1 of each node derivative
                                          local_ny=FIELD_VARIABLE%COMPONENTS(component_idx)%PARAM_TO_DOF_MAP% &
                                            & NODE_PARAM2DOF_MAP%NODES(node_idx)%DERIVATIVES(deriv_idx)%VERSIONS(1)
                                          BOUNDARY_CONDITION_CHECK_VARIABLE=BOUNDARY_CONDITIONS_VARIABLE% & 
                                            & CONDITION_TYPES(local_ny)
                                          IF(BOUNDARY_CONDITION_CHECK_VARIABLE==BOUNDARY_CONDITION_MOVED_WALL) THEN
                                            CALL FIELD_PARAMETER_SET_UPDATE_LOCAL_DOF(EQUATIONS_SET%DEPENDENT%DEPENDENT_FIELD, & 
                                              & FIELD_U_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE,local_ny, & 
                                              & BOUNDARY_VALUES(local_ny),ERR,ERROR,*999)
                                          END IF
                                        END DO !deriv_idx
                                      END DO !node_idx
                                    END IF
                                  END IF
                                END IF
                              END DO !component_idx
                            END IF
                          END DO !variable_idx
                          CALL FIELD_PARAMETER_SET_DATA_RESTORE(EQUATIONS_SET%INDEPENDENT%INDEPENDENT_FIELD, &
                            & FIELD_U_VARIABLE_TYPE,FIELD_BOUNDARY_SET_TYPE,BOUNDARY_VALUES,ERR,ERROR,*999)
                          !\todo: This part should be read in out of a file eventually
                        ELSE
                          CALL FlagError("Boundary condition variable is not associated.",ERR,ERROR,*999)
                        END IF
                      ELSE
                        CALL FlagError("Boundary conditions are not associated.",ERR,ERROR,*999)
                      END IF
                    ELSE
                      CALL FlagError("Equations set is not associated.",ERR,ERROR,*999)
                    END IF
                  ELSE
                    CALL FlagError("Equations are not associated.",ERR,ERROR,*999)
                  END IF
                ELSE
                  CALL FlagError("Solver equations are not associated.",ERR,ERROR,*999)
                END IF
                CALL FIELD_PARAMETER_SET_UPDATE_START(EQUATIONS_SET%DEPENDENT%DEPENDENT_FIELD,FIELD_U_VARIABLE_TYPE, & 
                  & FIELD_VALUES_SET_TYPE,ERR,ERROR,*999)
                CALL FIELD_PARAMETER_SET_UPDATE_FINISH(EQUATIONS_SET%DEPENDENT%DEPENDENT_FIELD,FIELD_U_VARIABLE_TYPE, & 
                  & FIELD_VALUES_SET_TYPE,ERR,ERROR,*999)
                !Pre solve for the dynamic solver
              ELSE IF(SOLVER%SOLVE_TYPE==SOLVER_DYNAMIC_TYPE) THEN
                CALL WRITE_STRING(GENERAL_OUTPUT_TYPE,"Mesh movement change boundary conditions... ",ERR,ERROR,*999)
                SOLVER_EQUATIONS=>SOLVER%SOLVER_EQUATIONS
                IF(ASSOCIATED(SOLVER_EQUATIONS)) THEN
                  SOLVER_MAPPING=>SOLVER_EQUATIONS%SOLVER_MAPPING
                  EQUATIONS=>SOLVER_MAPPING%EQUATIONS_SET_TO_SOLVER_MAP(1)%EQUATIONS
                  IF(ASSOCIATED(EQUATIONS)) THEN
                    EQUATIONS_SET=>EQUATIONS%EQUATIONS_SET
                    IF(ASSOCIATED(EQUATIONS_SET)) THEN
                      BOUNDARY_CONDITIONS=>SOLVER_EQUATIONS%BOUNDARY_CONDITIONS
                      IF(ASSOCIATED(BOUNDARY_CONDITIONS)) THEN
                        FIELD_VARIABLE=>EQUATIONS_SET%DEPENDENT%DEPENDENT_FIELD%VARIABLE_TYPE_MAP(FIELD_U_VARIABLE_TYPE)%PTR
                        IF(ASSOCIATED(FIELD_VARIABLE)) THEN
                          CALL BOUNDARY_CONDITIONS_VARIABLE_GET(BOUNDARY_CONDITIONS,FIELD_VARIABLE, &
                            & BOUNDARY_CONDITIONS_VARIABLE,ERR,ERROR,*999)
                        ELSE
                          CALL FlagError("Field U variable is not associated",ERR,ERROR,*999)
                        END IF
                        IF(ASSOCIATED(BOUNDARY_CONDITIONS_VARIABLE)) THEN
                          CALL FIELD_NUMBER_OF_COMPONENTS_GET(EQUATIONS_SET%GEOMETRY%GEOMETRIC_FIELD,FIELD_U_VARIABLE_TYPE, &
                            & NUMBER_OF_DIMENSIONS,ERR,ERROR,*999)
                          NULLIFY(MESH_VELOCITY_VALUES)
                          CALL FIELD_PARAMETER_SET_DATA_GET(EQUATIONS_SET%INDEPENDENT%INDEPENDENT_FIELD,FIELD_U_VARIABLE_TYPE, & 
                            & FIELD_MESH_VELOCITY_SET_TYPE,MESH_VELOCITY_VALUES,ERR,ERROR,*999)
                          NULLIFY(BOUNDARY_VALUES)
                          CALL FIELD_PARAMETER_SET_DATA_GET(EQUATIONS_SET%INDEPENDENT%INDEPENDENT_FIELD,FIELD_U_VARIABLE_TYPE, & 
                            & FIELD_BOUNDARY_SET_TYPE,BOUNDARY_VALUES,ERR,ERROR,*999)
                          CALL FLUID_MECHANICS_IO_READ_BOUNDARY_CONDITIONS(SOLVER_LINEAR_TYPE,BOUNDARY_VALUES, & 
                            & NUMBER_OF_DIMENSIONS,BOUNDARY_CONDITION_FIXED_INLET,CONTROL_LOOP%TIME_LOOP%INPUT_NUMBER, &
                            & CONTROL_LOOP%TIME_LOOP%ITERATION_NUMBER,CURRENT_TIME,1.0_DP)
                          DO variable_idx=1,EQUATIONS_SET%DEPENDENT%DEPENDENT_FIELD%NUMBER_OF_VARIABLES
                            variable_type=EQUATIONS_SET%DEPENDENT%DEPENDENT_FIELD%VARIABLES(variable_idx)%VARIABLE_TYPE
                            FIELD_VARIABLE=>EQUATIONS_SET%DEPENDENT%DEPENDENT_FIELD%VARIABLE_TYPE_MAP(variable_type)%PTR
                            IF(ASSOCIATED(FIELD_VARIABLE)) THEN
                              DO component_idx=1,FIELD_VARIABLE%NUMBER_OF_COMPONENTS
                                DOMAIN=>FIELD_VARIABLE%COMPONENTS(component_idx)%DOMAIN
                                IF(ASSOCIATED(DOMAIN)) THEN
                                  IF(ASSOCIATED(DOMAIN%TOPOLOGY)) THEN
                                    DOMAIN_NODES=>DOMAIN%TOPOLOGY%NODES
                                    IF(ASSOCIATED(DOMAIN_NODES)) THEN
                                      !Loop over the local nodes excluding the ghosts.
                                      DO node_idx=1,DOMAIN_NODES%NUMBER_OF_NODES
                                        DO deriv_idx=1,DOMAIN_NODES%NODES(node_idx)%NUMBER_OF_DERIVATIVES
                                          !Default to version 1 of each node derivative
                                          local_ny=FIELD_VARIABLE%COMPONENTS(component_idx)%PARAM_TO_DOF_MAP% &
                                            & NODE_PARAM2DOF_MAP%NODES(node_idx)%DERIVATIVES(deriv_idx)%VERSIONS(1)
                                          DISPLACEMENT_VALUE=0.0_DP
                                          BOUNDARY_CONDITION_CHECK_VARIABLE=BOUNDARY_CONDITIONS_VARIABLE% & 
                                            & CONDITION_TYPES(local_ny)
                                          IF(BOUNDARY_CONDITION_CHECK_VARIABLE==BOUNDARY_CONDITION_MOVED_WALL) THEN
                                            CALL FIELD_PARAMETER_SET_UPDATE_LOCAL_DOF(EQUATIONS_SET%DEPENDENT%DEPENDENT_FIELD, & 
                                              & FIELD_U_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE,local_ny, & 
                                              & MESH_VELOCITY_VALUES(local_ny),ERR,ERROR,*999)
                                          ELSE IF(BOUNDARY_CONDITION_CHECK_VARIABLE==BOUNDARY_CONDITION_FIXED_INLET) THEN
                                            CALL FIELD_PARAMETER_SET_UPDATE_LOCAL_DOF(EQUATIONS_SET%DEPENDENT%DEPENDENT_FIELD, & 
                                              & FIELD_U_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE,local_ny, & 
                                              & BOUNDARY_VALUES(local_ny),ERR,ERROR,*999)
                                          END IF
                                        END DO !deriv_idx
                                      END DO !node_idx
                                    END IF
                                  END IF
                                END IF
                              END DO !component_idx
                            END IF
                          END DO !variable_idx
                          CALL FIELD_PARAMETER_SET_DATA_RESTORE(EQUATIONS_SET%INDEPENDENT%INDEPENDENT_FIELD, &
                            & FIELD_U_VARIABLE_TYPE,FIELD_MESH_VELOCITY_SET_TYPE,MESH_VELOCITY_VALUES,ERR,ERROR,*999)
                          CALL FIELD_PARAMETER_SET_DATA_RESTORE(EQUATIONS_SET%INDEPENDENT%INDEPENDENT_FIELD, &
                            & FIELD_U_VARIABLE_TYPE,FIELD_BOUNDARY_SET_TYPE,BOUNDARY_VALUES,ERR,ERROR,*999)
                        ELSE
                          CALL FlagError("Boundary condition variable is not associated.",ERR,ERROR,*999)
                        END IF
                      ELSE
                        CALL FlagError("Boundary conditions are not associated.",ERR,ERROR,*999)
                      END IF
                    ELSE
                      CALL FlagError("Equations set is not associated.",ERR,ERROR,*999)
                    END IF
                  ELSE
                    CALL FlagError("Equations are not associated.",ERR,ERROR,*999)
                  END IF
                ELSE
                  CALL FlagError("Solver equations are not associated.",ERR,ERROR,*999)
                END IF
                CALL FIELD_PARAMETER_SET_UPDATE_START(EQUATIONS_SET%DEPENDENT%DEPENDENT_FIELD,FIELD_U_VARIABLE_TYPE, & 
                  & FIELD_VALUES_SET_TYPE,ERR,ERROR,*999)
                CALL FIELD_PARAMETER_SET_UPDATE_FINISH(EQUATIONS_SET%DEPENDENT%DEPENDENT_FIELD,FIELD_U_VARIABLE_TYPE, & 
                  & FIELD_VALUES_SET_TYPE,ERR,ERROR,*999)
              END IF
              ! do nothing ???
            CASE DEFAULT
              LOCAL_ERROR="Problem subtype "//TRIM(NUMBER_TO_VSTRING(CONTROL_LOOP%PROBLEM%SPECIFICATION(3),"*",ERR,ERROR))// &
                & " is not valid for a Navier-Stokes equation fluid type of a fluid mechanics problem class."
              CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
            END SELECT
          CASE(PROBLEM_MULTI_PHYSICS_CLASS)
            SELECT CASE(CONTROL_LOOP%PROBLEM%SPECIFICATION(2))
            CASE(PROBLEM_FINITE_ELASTICITY_NAVIER_STOKES_TYPE)
              SELECT CASE(CONTROL_LOOP%PROBLEM%SPECIFICATION(3))
              CASE(PROBLEM_FINITE_ELASTICITY_NAVIER_STOKES_ALE_SUBTYPE)
                NULLIFY(Solver2)
                !Pre solve for the linear solver
                IF(SOLVER%SOLVE_TYPE==SOLVER_LINEAR_TYPE) THEN
                  CALL WRITE_STRING(GENERAL_OUTPUT_TYPE,"Mesh movement change boundary conditions... ",ERR,ERROR,*999)
                  SOLVER_EQUATIONS=>SOLVER%SOLVER_EQUATIONS
                  IF(ASSOCIATED(SOLVER_EQUATIONS)) THEN
                    SOLVER_MAPPING=>SOLVER_EQUATIONS%SOLVER_MAPPING
                    EQUATIONS=>SOLVER_MAPPING%EQUATIONS_SET_TO_SOLVER_MAP(1)%EQUATIONS
                    IF(ASSOCIATED(EQUATIONS)) THEN
                      EQUATIONS_SET=>EQUATIONS%EQUATIONS_SET
                      IF(ASSOCIATED(EQUATIONS_SET)) THEN
                        BOUNDARY_CONDITIONS=>SOLVER_EQUATIONS%BOUNDARY_CONDITIONS
                        IF(ASSOCIATED(BOUNDARY_CONDITIONS)) THEN
                          FIELD_VARIABLE=>EQUATIONS_SET%DEPENDENT%DEPENDENT_FIELD%VARIABLE_TYPE_MAP(FIELD_U_VARIABLE_TYPE)%PTR
                          IF(ASSOCIATED(FIELD_VARIABLE)) THEN
                            CALL BOUNDARY_CONDITIONS_VARIABLE_GET(BOUNDARY_CONDITIONS,FIELD_VARIABLE, &
                              & BOUNDARY_CONDITIONS_VARIABLE,ERR,ERROR,*999)
                          ELSE
                            CALL FlagError("Field U variable is not associated",ERR,ERROR,*999)
                          END IF
                          IF(ASSOCIATED(BOUNDARY_CONDITIONS_VARIABLE)) THEN
                            CALL FIELD_NUMBER_OF_COMPONENTS_GET(EQUATIONS_SET%GEOMETRY%GEOMETRIC_FIELD,FIELD_U_VARIABLE_TYPE, &
                              & NUMBER_OF_DIMENSIONS,ERR,ERROR,*999)
                            !Update moving wall nodes from solid/fluid gap (as we solve for displacements of the mesh
                            !in Laplacian smoothing step).
                            CALL SOLVERS_SOLVER_GET(SOLVER%SOLVERS,1,Solver2,ERR,ERROR,*999)
                            IF(.NOT.ASSOCIATED(Solver2)) CALL FlagError("Dynamic solver is not associated.",Err,Error,*999)
                            !Find the FiniteElasticity equations set as there is a NavierStokes equations set too
                            SOLID_SOLVER_EQUATIONS=>Solver2%SOLVER_EQUATIONS
                            IF(ASSOCIATED(SOLID_SOLVER_EQUATIONS)) THEN
                              SOLID_SOLVER_MAPPING=>SOLID_SOLVER_EQUATIONS%SOLVER_MAPPING
                              IF(ASSOCIATED(SOLID_SOLVER_MAPPING)) THEN
                                EquationsSetIndex=1
                                SolidEquationsSetFound=.FALSE.
                                DO WHILE (.NOT.SolidEquationsSetFound &
                                  & .AND.EquationsSetIndex<=SOLID_SOLVER_MAPPING%NUMBER_OF_EQUATIONS_SETS)
                                  SOLID_EQUATIONS=>SOLID_SOLVER_MAPPING%EQUATIONS_SET_TO_SOLVER_MAP(EquationsSetIndex)%EQUATIONS
                                  IF(ASSOCIATED(SOLID_EQUATIONS)) THEN
                                    SOLID_EQUATIONS_SET=>SOLID_EQUATIONS%EQUATIONS_SET
                                    IF(ASSOCIATED(SOLID_EQUATIONS_SET)) THEN
                                      IF(SOLID_EQUATIONS_SET%SPECIFICATION(1)==EQUATIONS_SET_ELASTICITY_CLASS &
                                        & .AND.SOLID_EQUATIONS_SET%SPECIFICATION(2)==EQUATIONS_SET_FINITE_ELASTICITY_TYPE &
                                        & .AND.((SOLID_EQUATIONS_SET%SPECIFICATION(3)==EQUATIONS_SET_MOONEY_RIVLIN_SUBTYPE).OR. &
                                        & (SOLID_EQUATIONS_SET%SPECIFICATION(3)== &
                                        & EQUATIONS_SET_COMPRESSIBLE_FINITE_ELASTICITY_SUBTYPE))) THEN
                                        SolidEquationsSetFound=.TRUE.
                                      ELSE
                                        EquationsSetIndex=EquationsSetIndex+1
                                      END IF
                                    ELSE
                                      CALL FlagError("Solid equations set is not associated.",ERR,ERROR,*999)
                                    END IF
                                  ELSE
                                    CALL FlagError("Solid equations not associated.",Err,Error,*999)
                                  END IF
                                END DO
                                IF(SolidEquationsSetFound.EQV..FALSE.) THEN
                                  LOCAL_ERROR="Solid equations set not found when trying to update boundary conditions."
                                  CALL FlagError(LOCAL_ERROR,Err,Error,*999)
                                END IF
                              ELSE
                                CALL FlagError("Solid solver mapping is not associated.",Err,Error,*999)
                              END IF
                            ELSE
                              CALL FlagError("Solver equations for solid equations set not associated.",Err,Error,*999)
                            END IF
                            SOLID_DEPENDENT=>SOLID_EQUATIONS_SET%DEPENDENT
                            IF(.NOT.ASSOCIATED(SOLID_DEPENDENT%DEPENDENT_FIELD)) THEN
                              CALL FlagError("Solid equations set dependent field is not associated.",Err,Error,*999)
                            END IF
                            SOLID_DEPENDENT_FIELD=>SOLID_DEPENDENT%DEPENDENT_FIELD
                            !Find the NavierStokes equations set as there is a FiniteElasticity equations set too
                            FLUID_SOLVER_EQUATIONS=>Solver2%SOLVER_EQUATIONS
                            IF(ASSOCIATED(FLUID_SOLVER_EQUATIONS)) THEN
                              FLUID_SOLVER_MAPPING=>FLUID_SOLVER_EQUATIONS%SOLVER_MAPPING
                              IF(ASSOCIATED(FLUID_SOLVER_MAPPING)) THEN
                                EquationsSetIndex=1
                                FluidEquationsSetFound=.FALSE.
                                DO WHILE (.NOT.FluidEquationsSetFound &
                                  & .AND.EquationsSetIndex<=FLUID_SOLVER_MAPPING%NUMBER_OF_EQUATIONS_SETS)
                                  FLUID_EQUATIONS=>FLUID_SOLVER_MAPPING%EQUATIONS_SET_TO_SOLVER_MAP(EquationsSetIndex)%EQUATIONS
                                  IF(ASSOCIATED(SOLID_EQUATIONS)) THEN
                                    FLUID_EQUATIONS_SET=>FLUID_EQUATIONS%EQUATIONS_SET
                                    IF(ASSOCIATED(FLUID_EQUATIONS_SET)) THEN
                                      IF(FLUID_EQUATIONS_SET%SPECIFICATION(1)==EQUATIONS_SET_FLUID_MECHANICS_CLASS &
                                        & .AND.FLUID_EQUATIONS_SET%SPECIFICATION(2)==EQUATIONS_SET_NAVIER_STOKES_EQUATION_TYPE &
                                        & .AND.FLUID_EQUATIONS_SET%SPECIFICATION(3)==EQUATIONS_SET_ALE_NAVIER_STOKES_SUBTYPE) THEN
                                        FluidEquationsSetFound=.TRUE.
                                      ELSE
                                        EquationsSetIndex=EquationsSetIndex+1
                                      END IF
                                    ELSE
                                      CALL FlagError("Fluid equations set is not associated.",ERR,ERROR,*999)
                                    END IF
                                  ELSE
                                    CALL FlagError("Fluid equations not associated.",Err,Error,*999)
                                  END IF
                                END DO
                                IF(FluidEquationsSetFound.EQV..FALSE.) THEN
                                  LOCAL_ERROR="Fluid equations set not found when trying to update boundary conditions."
                                  CALL FlagError(LOCAL_ERROR,Err,Error,*999)
                                END IF
                              ELSE
                                CALL FlagError("Fluid solver mapping is not associated.",Err,Error,*999)
                              END IF
                            ELSE
                              CALL FlagError("Fluid equations for fluid equations set not associated.",Err,Error,*999)
                            END IF
                            FLUID_GEOMETRIC=>FLUID_EQUATIONS_SET%GEOMETRY
                            IF(.NOT.ASSOCIATED(FLUID_GEOMETRIC%GEOMETRIC_FIELD)) THEN
                              CALL FlagError("Fluid equations set geometric field is not associated",Err,Error,*999)
                            END IF
                            FLUID_GEOMETRIC_FIELD=>FLUID_GEOMETRIC%GEOMETRIC_FIELD
                            !DO variable_idx=1,EQUATIONS_SET%DEPENDENT%DEPENDENT_FIELD%NUMBER_OF_VARIABLES
                            variable_idx=1
                            variable_type=EQUATIONS_SET%DEPENDENT%DEPENDENT_FIELD%VARIABLES(variable_idx)%VARIABLE_TYPE
                            FIELD_VARIABLE=>EQUATIONS_SET%DEPENDENT%DEPENDENT_FIELD%VARIABLE_TYPE_MAP(variable_type)%PTR
                            IF(ASSOCIATED(FIELD_VARIABLE)) THEN
                              DO component_idx=1,FIELD_VARIABLE%NUMBER_OF_COMPONENTS
                                DOMAIN=>FIELD_VARIABLE%COMPONENTS(component_idx)%DOMAIN
                                IF(ASSOCIATED(DOMAIN)) THEN
                                  IF(ASSOCIATED(DOMAIN%TOPOLOGY)) THEN
                                    DOMAIN_NODES=>DOMAIN%TOPOLOGY%NODES
                                    IF(ASSOCIATED(DOMAIN_NODES)) THEN
                                      !Loop over the local nodes excluding the ghosts.
                                      DO node_idx=1,DOMAIN_NODES%NUMBER_OF_NODES
                                        DO deriv_idx=1,DOMAIN_NODES%NODES(node_idx)%NUMBER_OF_DERIVATIVES
                                          !Default to version 1 of each node derivative
                                          local_ny=FIELD_VARIABLE%COMPONENTS(component_idx)%PARAM_TO_DOF_MAP% &
                                            & NODE_PARAM2DOF_MAP%NODES(node_idx)%DERIVATIVES(deriv_idx)%VERSIONS(1)
                                          BOUNDARY_CONDITION_CHECK_VARIABLE=BOUNDARY_CONDITIONS_VARIABLE% & 
                                            & CONDITION_TYPES(local_ny)
                                          !Update moved wall nodes only
                                          IF(BOUNDARY_CONDITION_CHECK_VARIABLE==BOUNDARY_CONDITION_MOVED_WALL) THEN
                                            !NOTE: assuming same mesh and mesh nodes for fluid domain and moving mesh domain
                                            FluidNodeNumber=node_idx
                                            DO search_idx=1,SIZE(Solver2%SOLVER_EQUATIONS%SOLVER_MAPPING% &
                                              & INTERFACE_CONDITIONS(1)%PTR%INTERFACE% &
                                              & NODES%COUPLED_NODES(2,:))
                                              IF(Solver2%SOLVER_EQUATIONS%SOLVER_MAPPING% &
                                                & INTERFACE_CONDITIONS(1)%PTR%INTERFACE% &
                                                & NODES%COUPLED_NODES(2,search_idx)==node_idx) THEN
                                                SolidNodeNumber=Solver2%SOLVER_EQUATIONS%SOLVER_MAPPING% &
                                                  & INTERFACE_CONDITIONS(1)%PTR%INTERFACE% &
                                                  & NODES%COUPLED_NODES(1,search_idx)!might wanna put a break here
                                                SolidNodeFound=.TRUE.
                                              END IF
                                            END DO
                                            IF(.NOT.SolidNodeFound &
                                              & .OR.FluidNodeNumber==0) CALL FlagError("Solid interface node not found.", &
                                              & Err,Error,*999)
                                            !Default to version number 1
                                            IF(variable_idx==1) THEN
                                              CALL FIELD_PARAMETER_SET_GET_NODE(FLUID_GEOMETRIC_FIELD,variable_type, &
                                                & FIELD_VALUES_SET_TYPE,1,deriv_idx, &
                                                & FluidNodeNumber,component_idx,FluidGFValue,Err,Error,*999)
                                            ELSE
                                              FluidGFValue=0.0_DP
                                            END IF
                                            CALL FIELD_PARAMETER_SET_GET_NODE(SOLID_DEPENDENT_FIELD,variable_type, &
                                              & FIELD_VALUES_SET_TYPE,1,deriv_idx, &
                                              & SolidNodeNumber,component_idx,SolidDFValue,Err,Error,*999)
                                            NewLaplaceBoundaryValue=SolidDFValue-FluidGFValue
                                            CALL FIELD_PARAMETER_SET_UPDATE_LOCAL_DOF(EQUATIONS_SET%DEPENDENT%DEPENDENT_FIELD, & 
                                              & FIELD_U_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE,local_ny, & 
                                              & NewLaplaceBoundaryValue,Err,Error,*999)
                                          END IF
                                        END DO !deriv_idx
                                      END DO !node_idx
                                    END IF
                                  END IF
                                END IF
                              END DO !component_idx
                            END IF
                            !END DO !variable_idx
                          ELSE
                            CALL FlagError("Boundary condition variable is not associated.",ERR,ERROR,*999)
                          END IF
                        ELSE
                          CALL FlagError("Boundary conditions are not associated.",ERR,ERROR,*999)
                        END IF
                      ELSE
                        CALL FlagError("Equations set is not associated.",ERR,ERROR,*999)
                      END IF
                    ELSE
                      CALL FlagError("Equations are not associated.",ERR,ERROR,*999)
                    END IF
                  ELSE
                    CALL FlagError("Solver equations are not associated.",ERR,ERROR,*999)
                  END IF
                  CALL FIELD_PARAMETER_SET_UPDATE_START(EQUATIONS_SET%DEPENDENT%DEPENDENT_FIELD,FIELD_U_VARIABLE_TYPE, & 
                    & FIELD_VALUES_SET_TYPE,ERR,ERROR,*999)
                  CALL FIELD_PARAMETER_SET_UPDATE_FINISH(EQUATIONS_SET%DEPENDENT%DEPENDENT_FIELD,FIELD_U_VARIABLE_TYPE, & 
                    & FIELD_VALUES_SET_TYPE,ERR,ERROR,*999)
                  !Pre solve for the dynamic solver
                ELSE IF(SOLVER%SOLVE_TYPE==SOLVER_DYNAMIC_TYPE) THEN
                  CALL WRITE_STRING(GENERAL_OUTPUT_TYPE,"Velocity field change boundary conditions... ",ERR,ERROR,*999)
                  SOLVER_EQUATIONS=>SOLVER%SOLVER_EQUATIONS
                  IF(ASSOCIATED(SOLVER_EQUATIONS)) THEN
                    SOLVER_MAPPING=>SOLVER_EQUATIONS%SOLVER_MAPPING
                    !Find the NavierStokes equations set as there is a finite elasticity equations set too 
                    EquationsSetIndex=1
                    ALENavierStokesEquationsSetFound=.FALSE.
                    DO WHILE (.NOT.ALENavierStokesEquationsSetFound &
                      & .AND.EquationsSetIndex<=SOLVER_MAPPING%NUMBER_OF_EQUATIONS_SETS)
                      EQUATIONS=>SOLVER_MAPPING%EQUATIONS_SET_TO_SOLVER_MAP(EquationsSetIndex)%EQUATIONS
                      IF(ASSOCIATED(EQUATIONS)) THEN
                        EQUATIONS_SET=>EQUATIONS%EQUATIONS_SET
                        IF(ASSOCIATED(EQUATIONS_SET)) THEN
                          IF(EQUATIONS_SET%SPECIFICATION(1)==EQUATIONS_SET_FLUID_MECHANICS_CLASS &
                            & .AND.EQUATIONS_SET%SPECIFICATION(2)==EQUATIONS_SET_NAVIER_STOKES_EQUATION_TYPE &
                            & .AND.EQUATIONS_SET%SPECIFICATION(3)==EQUATIONS_SET_ALE_NAVIER_STOKES_SUBTYPE) THEN
                            ALENavierStokesEquationsSetFound=.TRUE.
                          ELSE
                            EquationsSetIndex=EquationsSetIndex+1
                          END IF
                        ELSE
                          CALL FlagError("ALE Navier-Stokes equations set is not associated.",ERR,ERROR,*999)
                        END IF
                      ELSE
                        CALL FlagError("ALE equations not associated.",Err,Error,*999)
                      END IF
                    END DO
                    IF(ALENavierStokesEquationsSetFound.EQV..FALSE.) THEN
                      LOCAL_ERROR="ALE NavierStokes equations set not found when trying to update boundary conditions."
                      CALL FlagError(LOCAL_ERROR,Err,Error,*999)
                    END IF
                    !Get boundary conditions
                    BOUNDARY_CONDITIONS=>SOLVER_EQUATIONS%BOUNDARY_CONDITIONS
                    IF(ASSOCIATED(BOUNDARY_CONDITIONS)) THEN
                      FIELD_VARIABLE=>EQUATIONS_SET%DEPENDENT%DEPENDENT_FIELD%VARIABLE_TYPE_MAP(FIELD_U_VARIABLE_TYPE)%PTR
                      IF(ASSOCIATED(FIELD_VARIABLE)) THEN
                        CALL BOUNDARY_CONDITIONS_VARIABLE_GET(BOUNDARY_CONDITIONS,FIELD_VARIABLE, &
                          & BOUNDARY_CONDITIONS_VARIABLE,ERR,ERROR,*999)
                      ELSE
                        CALL FlagError("Field U variable is not associated",ERR,ERROR,*999)
                      END IF
                      IF(ASSOCIATED(BOUNDARY_CONDITIONS_VARIABLE)) THEN
                        CALL FIELD_NUMBER_OF_COMPONENTS_GET(EQUATIONS_SET%GEOMETRY%GEOMETRIC_FIELD,FIELD_U_VARIABLE_TYPE, &
                          & NUMBER_OF_DIMENSIONS,ERR,ERROR,*999)
                        NULLIFY(MESH_VELOCITY_VALUES)
                        CALL FIELD_PARAMETER_SET_DATA_GET(EQUATIONS_SET%INDEPENDENT%INDEPENDENT_FIELD,FIELD_U_VARIABLE_TYPE, & 
                          & FIELD_MESH_VELOCITY_SET_TYPE,MESH_VELOCITY_VALUES,ERR,ERROR,*999)
                        NULLIFY(BOUNDARY_VALUES)
                        CALL FIELD_PARAMETER_SET_DATA_GET(EQUATIONS_SET%INDEPENDENT%INDEPENDENT_FIELD,FIELD_U_VARIABLE_TYPE, & 
                          & FIELD_BOUNDARY_SET_TYPE,BOUNDARY_VALUES,ERR,ERROR,*999)
                        !Get update for time-dependent boundary conditions
                        IF(CONTROL_LOOP%TIME_LOOP%INPUT_NUMBER==1) THEN
                          componentBC=1
                          CALL FluidMechanics_IO_UpdateBoundaryConditionUpdateNodes(EQUATIONS_SET%GEOMETRY%GEOMETRIC_FIELD, &
                            & SOLVER%SOLVE_TYPE,InletNodes, &
                            & BoundaryValues,BOUNDARY_CONDITION_FIXED_INLET,CONTROL_LOOP%TIME_LOOP%INPUT_NUMBER, &
                            & CURRENT_TIME,CONTROL_LOOP%TIME_LOOP%STOP_TIME)
                          DO node_idx=1,SIZE(InletNodes)
                            CALL FIELD_PARAMETER_SET_UPDATE_NODE(EQUATIONS_SET%DEPENDENT%DEPENDENT_FIELD, &
                              & FIELD_U_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE,1,1,InletNodes(node_idx),componentBC, &
                              & BoundaryValues(node_idx),ERR,ERROR,*999)
                          END DO
                        ELSE
                          !Figure out which component we're applying BC at
                          IF(CONTROL_LOOP%TIME_LOOP%INPUT_NUMBER==2) THEN
                            componentBC=1
                          ELSE
                            componentBC=2
                          END IF
                          !Get inlet nodes and the corresponding velocities
                          CALL FluidMechanics_IO_UpdateBoundaryConditionUpdateNodes(EQUATIONS_SET%GEOMETRY%GEOMETRIC_FIELD, &
                            & SOLVER%SOLVE_TYPE,InletNodes, &
                            & BoundaryValues,BOUNDARY_CONDITION_FIXED_INLET,CONTROL_LOOP%TIME_LOOP%INPUT_NUMBER, &
                            & CURRENT_TIME,CONTROL_LOOP%TIME_LOOP%STOP_TIME)
                          DO node_idx=1,SIZE(InletNodes)
                            CALL FIELD_PARAMETER_SET_UPDATE_NODE(EQUATIONS_SET%DEPENDENT%DEPENDENT_FIELD, &
                              & FIELD_U_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE,1,1,InletNodes(node_idx),componentBC, &
                              & BoundaryValues(node_idx),ERR,ERROR,*999)
                          END DO
                        END IF
                        CALL FIELD_PARAMETER_SET_DATA_RESTORE(EQUATIONS_SET%INDEPENDENT%INDEPENDENT_FIELD, &
                          & FIELD_U_VARIABLE_TYPE,FIELD_MESH_VELOCITY_SET_TYPE,MESH_VELOCITY_VALUES,ERR,ERROR,*999)
                        CALL FIELD_PARAMETER_SET_DATA_RESTORE(EQUATIONS_SET%INDEPENDENT%INDEPENDENT_FIELD, &
                          & FIELD_U_VARIABLE_TYPE,FIELD_BOUNDARY_SET_TYPE,BOUNDARY_VALUES,ERR,ERROR,*999)
                      ELSE
                        CALL FlagError("Boundary condition variable is not associated.",ERR,ERROR,*999)
                      END IF
                    ELSE
                      CALL FlagError("Boundary conditions are not associated.",ERR,ERROR,*999)
                    END IF
                  ELSE
                    CALL FlagError("Solver equations are not associated.",ERR,ERROR,*999)
                  END IF
                  CALL FIELD_PARAMETER_SET_UPDATE_START(EQUATIONS_SET%DEPENDENT%DEPENDENT_FIELD,FIELD_U_VARIABLE_TYPE, & 
                    & FIELD_VALUES_SET_TYPE,ERR,ERROR,*999)
                  CALL FIELD_PARAMETER_SET_UPDATE_FINISH(EQUATIONS_SET%DEPENDENT%DEPENDENT_FIELD,FIELD_U_VARIABLE_TYPE, & 
                    & FIELD_VALUES_SET_TYPE,ERR,ERROR,*999)
                END IF
                ! do nothing ???
              CASE DEFAULT
                LOCAL_ERROR="Problem subtype "//TRIM(NUMBER_TO_VSTRING(CONTROL_LOOP%PROBLEM%SPECIFICATION(3),"*",ERR,ERROR))// &
                  & " is not valid for a FiniteElasticity-NavierStokes problem type of a multi physics problem class."
                CALL FlagError(LOCAL_ERROR,Err,Error,*999)
              END SELECT
            CASE DEFAULT
              LOCAL_ERROR="Problem type "//TRIM(NUMBER_TO_VSTRING(CONTROL_LOOP%PROBLEM%SPECIFICATION(2),"*",ERR,ERROR))// &
                & " is not valid for NAVIER_STOKES_PRE_SOLVE of a multi physics problem class."
              CALL FlagError(LOCAL_ERROR,Err,Error,*999)
            END SELECT
          CASE DEFAULT
            LOCAL_ERROR="The first problem specification of "// &
              & TRIM(NUMBER_TO_VSTRING(CONTROL_LOOP%PROBLEM%specification(1),"*",ERR,ERROR))// &
              & " is not valid for NavierStokes_PreSolveUpdateBoundaryConditions."
            CALL FlagError(LOCAL_ERROR,Err,Error,*999)
          END SELECT
        ELSE
          CALL FlagError("Problem is not associated.",ERR,ERROR,*999)
        END IF
      ELSE
        CALL FlagError("Solver is not associated.",ERR,ERROR,*999)
      END IF
    ELSE
      CALL FlagError("Control loop is not associated.",ERR,ERROR,*999)
    END IF

    EXITS("NavierStokes_PreSolveUpdateBoundaryConditions")
    RETURN
999 ERRORS("NavierStokes_PreSolveUpdateBoundaryConditions",ERR,ERROR)
    EXITS("NavierStokes_PreSolveUpdateBoundaryConditions")
    RETURN 1
    
  END SUBROUTINE NavierStokes_PreSolveUpdateBoundaryConditions

  !
  !================================================================================================================================
  !

  !>Update mesh velocity and move mesh for ALE Navier-Stokes problem
  SUBROUTINE NAVIER_STOKES_PRE_SOLVE_ALE_UPDATE_MESH(SOLVER,ERR,ERROR,*)

    !Argument variables
    TYPE(SOLVER_TYPE), POINTER :: SOLVER
    INTEGER(INTG), INTENT(OUT) :: ERR
    TYPE(VARYING_STRING), INTENT(OUT) :: ERROR
    !Local Variables
    TYPE(CONTROL_LOOP_TYPE), POINTER :: CONTROL_LOOP
    TYPE(DOMAIN_NODES_TYPE), POINTER :: DOMAIN_NODES
    TYPE(DOMAIN_TYPE), POINTER :: DOMAIN
    TYPE(EQUATIONS_MAPPING_TYPE), POINTER :: EQUATIONS_MAPPING
    TYPE(EQUATIONS_SET_TYPE), POINTER :: EQUATIONS_SET_LAPLACE, EQUATIONS_SET_ALE_NAVIER_STOKES
    TYPE(EQUATIONS_TYPE), POINTER :: EQUATIONS
    TYPE(FIELD_TYPE), POINTER :: DEPENDENT_FIELD_LAPLACE, INDEPENDENT_FIELD_ALE_NAVIER_STOKES
    TYPE(FIELD_VARIABLE_TYPE), POINTER :: FIELD_VARIABLE
    TYPE(SOLVER_EQUATIONS_TYPE), POINTER :: SOLVER_EQUATIONS_LAPLACE, SOLVER_EQUATIONS_ALE_NAVIER_STOKES
    TYPE(SOLVER_MAPPING_TYPE), POINTER :: SOLVER_MAPPING_LAPLACE, SOLVER_MAPPING_ALE_NAVIER_STOKES
    TYPE(SOLVER_TYPE), POINTER :: SOLVER_ALE_NAVIER_STOKES, SOLVER_LAPLACE
    TYPE(SOLVERS_TYPE), POINTER :: SOLVERS
    TYPE(VARYING_STRING) :: LOCAL_ERROR
    INTEGER(INTG) :: I,NUMBER_OF_DIMENSIONS_LAPLACE,NUMBER_OF_DIMENSIONS_ALE_NAVIER_STOKES
    INTEGER(INTG) :: GEOMETRIC_MESH_COMPONENT,INPUT_TYPE,INPUT_OPTION,EquationsSetIndex
    INTEGER(INTG) :: component_idx,deriv_idx,local_ny,node_idx,variable_idx,variable_type
    REAL(DP) :: CURRENT_TIME,TIME_INCREMENT,ALPHA
    REAL(DP), POINTER :: MESH_DISPLACEMENT_VALUES(:)
    LOGICAL :: ALENavierStokesEquationsSetFound=.FALSE.

    ENTERS("NAVIER_STOKES_PRE_SOLVE_ALE_UPDATE_MESH",ERR,ERROR,*999)

    IF(ASSOCIATED(SOLVER)) THEN
      SOLVERS=>SOLVER%SOLVERS
      IF(ASSOCIATED(SOLVERS)) THEN
        CONTROL_LOOP=>SOLVERS%CONTROL_LOOP
        CALL CONTROL_LOOP_CURRENT_TIMES_GET(CONTROL_LOOP,CURRENT_TIME,TIME_INCREMENT,ERR,ERROR,*999)
        NULLIFY(SOLVER_LAPLACE)
        NULLIFY(SOLVER_ALE_NAVIER_STOKES)
        NULLIFY(INDEPENDENT_FIELD_ALE_NAVIER_STOKES)
        IF(ASSOCIATED(CONTROL_LOOP%PROBLEM)) THEN
          IF(.NOT.ALLOCATED(CONTROL_LOOP%problem%specification)) THEN
            CALL FlagError("Problem specification array is not allocated.",err,error,*999)
          ELSE IF(SIZE(CONTROL_LOOP%problem%specification,1)<3) THEN
            CALL FlagError("Problem specification must have three entries for a Navier-Stokes problem.",err,error,*999)
          END IF
          SELECT CASE(CONTROL_LOOP%PROBLEM%SPECIFICATION(1))
          CASE(PROBLEM_FLUID_MECHANICS_CLASS)
            SELECT CASE(CONTROL_LOOP%PROBLEM%SPECIFICATION(3))
            CASE(PROBLEM_STATIC_NAVIER_STOKES_SUBTYPE,PROBLEM_LAPLACE_NAVIER_STOKES_SUBTYPE)
              ! do nothing ???
            CASE(PROBLEM_TRANSIENT_NAVIER_STOKES_SUBTYPE)
              ! do nothing ???
            CASE(PROBLEM_TRANSIENT_RBS_NAVIER_STOKES_SUBTYPE,PROBLEM_MULTISCALE_NAVIER_STOKES_SUBTYPE)
              ! do nothing ???
            CASE(PROBLEM_TRANSIENT1D_NAVIER_STOKES_SUBTYPE,PROBLEM_COUPLED1D0D_NAVIER_STOKES_SUBTYPE, &
             & PROBLEM_TRANSIENT1D_ADV_NAVIER_STOKES_SUBTYPE,PROBLEM_COUPLED1D0D_ADV_NAVIER_STOKES_SUBTYPE)
              ! do nothing ???
            CASE(PROBLEM_PGM_NAVIER_STOKES_SUBTYPE)
              !Update mesh within the dynamic solver
              IF(SOLVER%SOLVE_TYPE==SOLVER_DYNAMIC_TYPE) THEN
                !Get the independent field for the ALE Navier-Stokes problem
                CALL SOLVERS_SOLVER_GET(SOLVER%SOLVERS,1,SOLVER_ALE_NAVIER_STOKES,ERR,ERROR,*999)
                SOLVER_EQUATIONS_ALE_NAVIER_STOKES=>SOLVER_ALE_NAVIER_STOKES%SOLVER_EQUATIONS
                IF(ASSOCIATED(SOLVER_EQUATIONS_ALE_NAVIER_STOKES)) THEN
                  SOLVER_MAPPING_ALE_NAVIER_STOKES=>SOLVER_EQUATIONS_ALE_NAVIER_STOKES%SOLVER_MAPPING
                  IF(ASSOCIATED(SOLVER_MAPPING_ALE_NAVIER_STOKES)) THEN
                    EQUATIONS_SET_ALE_NAVIER_STOKES=>SOLVER_MAPPING_ALE_NAVIER_STOKES%EQUATIONS_SETS(1)%PTR
                    IF(ASSOCIATED(EQUATIONS_SET_ALE_NAVIER_STOKES)) THEN
                      INDEPENDENT_FIELD_ALE_NAVIER_STOKES=>EQUATIONS_SET_ALE_NAVIER_STOKES%INDEPENDENT%INDEPENDENT_FIELD
                    ELSE
                      CALL FlagError("ALE Navier-Stokes equations set is not associated.",ERR,ERROR,*999)
                    END IF
                    !Get the data
                    CALL FIELD_NUMBER_OF_COMPONENTS_GET(EQUATIONS_SET_ALE_NAVIER_STOKES%GEOMETRY%GEOMETRIC_FIELD, & 
                      & FIELD_U_VARIABLE_TYPE,NUMBER_OF_DIMENSIONS_ALE_NAVIER_STOKES,ERR,ERROR,*999)
                    !\todo: Introduce user calls instead of hard-coding 42/1
                    !Copy input to Navier-Stokes' independent field
                    INPUT_TYPE=42
                    INPUT_OPTION=1
                    NULLIFY(MESH_DISPLACEMENT_VALUES)
                    CALL FIELD_PARAMETER_SET_DATA_GET(EQUATIONS_SET_ALE_NAVIER_STOKES%INDEPENDENT%INDEPENDENT_FIELD, &
                      & FIELD_U_VARIABLE_TYPE,FIELD_MESH_DISPLACEMENT_SET_TYPE,MESH_DISPLACEMENT_VALUES,ERR,ERROR,*999)
                    CALL FLUID_MECHANICS_IO_READ_DATA(SOLVER_LINEAR_TYPE,MESH_DISPLACEMENT_VALUES, & 
                      & NUMBER_OF_DIMENSIONS_ALE_NAVIER_STOKES,INPUT_TYPE,INPUT_OPTION, &
                      & CONTROL_LOOP%TIME_LOOP%ITERATION_NUMBER,1.0_DP)
                    CALL FIELD_PARAMETER_SET_UPDATE_START(EQUATIONS_SET_ALE_NAVIER_STOKES%INDEPENDENT%INDEPENDENT_FIELD, & 
                      & FIELD_U_VARIABLE_TYPE,FIELD_MESH_DISPLACEMENT_SET_TYPE,ERR,ERROR,*999)
                    CALL FIELD_PARAMETER_SET_UPDATE_FINISH(EQUATIONS_SET_ALE_NAVIER_STOKES%INDEPENDENT%INDEPENDENT_FIELD, & 
                      & FIELD_U_VARIABLE_TYPE,FIELD_MESH_DISPLACEMENT_SET_TYPE,ERR,ERROR,*999)
                  ELSE
                    CALL FlagError("ALE Navier-Stokes solver mapping is not associated.",ERR,ERROR,*999)
                  END IF
                ELSE
                  CALL FlagError("ALE Navier-Stokes solver equations are not associated.",ERR,ERROR,*999)
                END IF
                !Use calculated values to update mesh
                CALL FIELD_COMPONENT_MESH_COMPONENT_GET(EQUATIONS_SET_ALE_NAVIER_STOKES%GEOMETRY%GEOMETRIC_FIELD, & 
                  & FIELD_U_VARIABLE_TYPE,1,GEOMETRIC_MESH_COMPONENT,ERR,ERROR,*999)
                !                 CALL FIELD_PARAMETER_SET_DATA_GET(INDEPENDENT_FIELD_ALE_NAVIER_STOKES,FIELD_U_VARIABLE_TYPE, & 
                !                   & FIELD_MESH_DISPLACEMENT_SET_TYPE,MESH_DISPLACEMENT_VALUES,ERR,ERROR,*999)
                EQUATIONS=>SOLVER_MAPPING_ALE_NAVIER_STOKES%EQUATIONS_SET_TO_SOLVER_MAP(1)%EQUATIONS
                IF(ASSOCIATED(EQUATIONS)) THEN
                  EQUATIONS_MAPPING=>EQUATIONS%EQUATIONS_MAPPING
                  IF(ASSOCIATED(EQUATIONS_MAPPING)) THEN
                    DO variable_idx=1,EQUATIONS_SET_ALE_NAVIER_STOKES%GEOMETRY%GEOMETRIC_FIELD%NUMBER_OF_VARIABLES
                      variable_type=EQUATIONS_SET_ALE_NAVIER_STOKES%GEOMETRY%GEOMETRIC_FIELD%VARIABLES(variable_idx)%VARIABLE_TYPE
                      FIELD_VARIABLE=>EQUATIONS_SET_ALE_NAVIER_STOKES%GEOMETRY%GEOMETRIC_FIELD%VARIABLE_TYPE_MAP(variable_type)%PTR
                      IF(ASSOCIATED(FIELD_VARIABLE)) THEN
                        DO component_idx=1,FIELD_VARIABLE%NUMBER_OF_COMPONENTS
                          DOMAIN=>FIELD_VARIABLE%COMPONENTS(component_idx)%DOMAIN
                          IF(ASSOCIATED(DOMAIN)) THEN
                            IF(ASSOCIATED(DOMAIN%TOPOLOGY)) THEN
                              DOMAIN_NODES=>DOMAIN%TOPOLOGY%NODES
                              IF(ASSOCIATED(DOMAIN_NODES)) THEN
                                !Loop over the local nodes excluding the ghosts.
                                DO node_idx=1,DOMAIN_NODES%NUMBER_OF_NODES
                                  DO deriv_idx=1,DOMAIN_NODES%NODES(node_idx)%NUMBER_OF_DERIVATIVES
                                    !Default to version 1 of each node derivative
                                    local_ny=FIELD_VARIABLE%COMPONENTS(component_idx)%PARAM_TO_DOF_MAP% &
                                      & NODE_PARAM2DOF_MAP%NODES(node_idx)%DERIVATIVES(deriv_idx)%VERSIONS(1)
                                    CALL FIELD_PARAMETER_SET_ADD_LOCAL_DOF(EQUATIONS_SET_ALE_NAVIER_STOKES%GEOMETRY% &
                                      & GEOMETRIC_FIELD,FIELD_U_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE,local_ny, & 
                                      & MESH_DISPLACEMENT_VALUES(local_ny),ERR,ERROR,*999)
                                  END DO !deriv_idx
                                END DO !node_idx
                              END IF
                            END IF
                          END IF
                        END DO !componentIdx
                      END IF
                    END DO !variable_idx
                  ELSE
                    CALL FlagError("Equations mapping is not associated.",ERR,ERROR,*999)
                  END IF
                ELSE
                  CALL FlagError("Equations are not associated.",ERR,ERROR,*999)
                END IF
                CALL FIELD_PARAMETER_SET_UPDATE_START(EQUATIONS_SET_ALE_NAVIER_STOKES%GEOMETRY%GEOMETRIC_FIELD, & 
                  & FIELD_U_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE,ERR,ERROR,*999)
                CALL FIELD_PARAMETER_SET_UPDATE_FINISH(EQUATIONS_SET_ALE_NAVIER_STOKES%GEOMETRY%GEOMETRIC_FIELD, & 
                  & FIELD_U_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE,ERR,ERROR,*999)
                !Now use displacement values to calculate velocity values
                TIME_INCREMENT=CONTROL_LOOP%TIME_LOOP%TIME_INCREMENT
                ALPHA=1.0_DP/TIME_INCREMENT
                CALL FIELD_PARAMETER_SETS_COPY(INDEPENDENT_FIELD_ALE_NAVIER_STOKES,FIELD_U_VARIABLE_TYPE, & 
                  & FIELD_MESH_DISPLACEMENT_SET_TYPE,FIELD_MESH_VELOCITY_SET_TYPE,ALPHA,ERR,ERROR,*999)
              ELSE  
                CALL FlagError("Mesh motion calculation not successful for ALE problem.",ERR,ERROR,*999)
              END IF
            CASE(PROBLEM_ALE_NAVIER_STOKES_SUBTYPE)
              !Update mesh within the dynamic solver
              IF(SOLVER%SOLVE_TYPE==SOLVER_DYNAMIC_TYPE) THEN
                IF(SOLVER%DYNAMIC_SOLVER%ALE) THEN
                  !Get the dependent field for the three component Laplace problem
                  CALL SOLVERS_SOLVER_GET(SOLVER%SOLVERS,1,SOLVER_LAPLACE,ERR,ERROR,*999)
                  SOLVER_EQUATIONS_LAPLACE=>SOLVER_LAPLACE%SOLVER_EQUATIONS
                  IF(ASSOCIATED(SOLVER_EQUATIONS_LAPLACE)) THEN
                    SOLVER_MAPPING_LAPLACE=>SOLVER_EQUATIONS_LAPLACE%SOLVER_MAPPING
                    IF(ASSOCIATED(SOLVER_MAPPING_LAPLACE)) THEN
                      EQUATIONS_SET_LAPLACE=>SOLVER_MAPPING_LAPLACE%EQUATIONS_SETS(1)%PTR
                      IF(ASSOCIATED(EQUATIONS_SET_LAPLACE)) THEN
                        DEPENDENT_FIELD_LAPLACE=>EQUATIONS_SET_LAPLACE%DEPENDENT%DEPENDENT_FIELD
                      ELSE
                        CALL FlagError("Laplace equations set is not associated.",ERR,ERROR,*999)
                      END IF
                      CALL FIELD_NUMBER_OF_COMPONENTS_GET(EQUATIONS_SET_LAPLACE%GEOMETRY%GEOMETRIC_FIELD,FIELD_U_VARIABLE_TYPE, &
                        & NUMBER_OF_DIMENSIONS_LAPLACE,ERR,ERROR,*999)
                    ELSE
                      CALL FlagError("Laplace solver mapping is not associated.",ERR,ERROR,*999)
                    END IF
                  ELSE
                    CALL FlagError("Laplace solver equations are not associated.",ERR,ERROR,*999)
                  END IF
                  !Get the independent field for the ALE Navier-Stokes problem
                  CALL SOLVERS_SOLVER_GET(SOLVER%SOLVERS,2,SOLVER_ALE_NAVIER_STOKES,ERR,ERROR,*999)
                  SOLVER_EQUATIONS_ALE_NAVIER_STOKES=>SOLVER_ALE_NAVIER_STOKES%SOLVER_EQUATIONS
                  IF(ASSOCIATED(SOLVER_EQUATIONS_ALE_NAVIER_STOKES)) THEN
                    SOLVER_MAPPING_ALE_NAVIER_STOKES=>SOLVER_EQUATIONS_ALE_NAVIER_STOKES%SOLVER_MAPPING
                    IF(ASSOCIATED(SOLVER_MAPPING_ALE_NAVIER_STOKES)) THEN
                      EQUATIONS_SET_ALE_NAVIER_STOKES=>SOLVER_MAPPING_ALE_NAVIER_STOKES%EQUATIONS_SETS(1)%PTR
                      IF(ASSOCIATED(EQUATIONS_SET_ALE_NAVIER_STOKES)) THEN
                        INDEPENDENT_FIELD_ALE_NAVIER_STOKES=>EQUATIONS_SET_ALE_NAVIER_STOKES%INDEPENDENT%INDEPENDENT_FIELD
                      ELSE
                        CALL FlagError("ALE Navier-Stokes equations set is not associated.",ERR,ERROR,*999)
                      END IF
                      CALL FIELD_NUMBER_OF_COMPONENTS_GET(EQUATIONS_SET_ALE_NAVIER_STOKES%GEOMETRY%GEOMETRIC_FIELD, & 
                        & FIELD_U_VARIABLE_TYPE,NUMBER_OF_DIMENSIONS_ALE_NAVIER_STOKES,ERR,ERROR,*999)
                    ELSE
                      CALL FlagError("ALE Navier-Stokes solver mapping is not associated.",ERR,ERROR,*999)
                    END IF
                  ELSE
                    CALL FlagError("ALE Navier-Stokes solver equations are not associated.",ERR,ERROR,*999)
                  END IF
                  !Copy result from Laplace mesh movement to Navier-Stokes' independent field
                  IF(NUMBER_OF_DIMENSIONS_ALE_NAVIER_STOKES==NUMBER_OF_DIMENSIONS_LAPLACE) THEN
                    DO I=1,NUMBER_OF_DIMENSIONS_ALE_NAVIER_STOKES
                      CALL Field_ParametersToFieldParametersCopy(DEPENDENT_FIELD_LAPLACE, & 
                        & FIELD_U_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE,I,INDEPENDENT_FIELD_ALE_NAVIER_STOKES, & 
                        & FIELD_U_VARIABLE_TYPE,FIELD_MESH_DISPLACEMENT_SET_TYPE,I,ERR,ERROR,*999)
                    END DO
                  ELSE
                    CALL FlagError("Dimension of Laplace and ALE Navier-Stokes equations set is not consistent.",ERR,ERROR,*999)
                  END IF
                  !Use calculated values to update mesh
                  CALL FIELD_COMPONENT_MESH_COMPONENT_GET(EQUATIONS_SET_ALE_NAVIER_STOKES%GEOMETRY%GEOMETRIC_FIELD, & 
                    & FIELD_U_VARIABLE_TYPE,1,GEOMETRIC_MESH_COMPONENT,ERR,ERROR,*999)
                  NULLIFY(MESH_DISPLACEMENT_VALUES)
                  CALL FIELD_PARAMETER_SET_DATA_GET(INDEPENDENT_FIELD_ALE_NAVIER_STOKES,FIELD_U_VARIABLE_TYPE, & 
                    & FIELD_MESH_DISPLACEMENT_SET_TYPE,MESH_DISPLACEMENT_VALUES,ERR,ERROR,*999)
                  EQUATIONS=>SOLVER_MAPPING_LAPLACE%EQUATIONS_SET_TO_SOLVER_MAP(1)%EQUATIONS
                  IF(ASSOCIATED(EQUATIONS)) THEN
                    EQUATIONS_MAPPING=>EQUATIONS%EQUATIONS_MAPPING
                    IF(ASSOCIATED(EQUATIONS_MAPPING)) THEN
                      DO variable_idx=1,EQUATIONS_SET_ALE_NAVIER_STOKES%GEOMETRY%GEOMETRIC_FIELD%NUMBER_OF_VARIABLES
                        variable_type=EQUATIONS_SET_ALE_NAVIER_STOKES%GEOMETRY%GEOMETRIC_FIELD%VARIABLES(variable_idx)%VARIABLE_TYPE
                        FIELD_VARIABLE=>EQUATIONS_SET_ALE_NAVIER_STOKES%GEOMETRY%GEOMETRIC_FIELD% &
                          & VARIABLE_TYPE_MAP(variable_type)%PTR
                        IF(ASSOCIATED(FIELD_VARIABLE)) THEN
                          DO component_idx=1,FIELD_VARIABLE%NUMBER_OF_COMPONENTS
                            DOMAIN=>FIELD_VARIABLE%COMPONENTS(component_idx)%DOMAIN
                            IF(ASSOCIATED(DOMAIN)) THEN
                              IF(ASSOCIATED(DOMAIN%TOPOLOGY)) THEN
                                DOMAIN_NODES=>DOMAIN%TOPOLOGY%NODES
                                IF(ASSOCIATED(DOMAIN_NODES)) THEN
                                  !Loop over the local nodes excluding the ghosts.
                                  DO node_idx=1,DOMAIN_NODES%NUMBER_OF_NODES
                                    DO deriv_idx=1,DOMAIN_NODES%NODES(node_idx)%NUMBER_OF_DERIVATIVES
                                      !Default to version 1 of each node derivative
                                      local_ny=FIELD_VARIABLE%COMPONENTS(component_idx)%PARAM_TO_DOF_MAP% &
                                        & NODE_PARAM2DOF_MAP%NODES(node_idx)%DERIVATIVES(deriv_idx)%VERSIONS(1)
                                      CALL FIELD_PARAMETER_SET_ADD_LOCAL_DOF(EQUATIONS_SET_ALE_NAVIER_STOKES%GEOMETRY% &
                                        & GEOMETRIC_FIELD,FIELD_U_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE,local_ny, & 
                                        & MESH_DISPLACEMENT_VALUES(local_ny),ERR,ERROR,*999)
                                    END DO !deriv_idx
                                  END DO !node_idx
                                END IF
                              END IF
                            END IF
                          END DO !componentIdx
                        END IF
                      END DO !variable_idx
                    ELSE
                      CALL FlagError("Equations mapping is not associated.",ERR,ERROR,*999)
                    END IF
                    CALL FIELD_PARAMETER_SET_DATA_RESTORE(INDEPENDENT_FIELD_ALE_NAVIER_STOKES,FIELD_U_VARIABLE_TYPE, & 
                      & FIELD_MESH_DISPLACEMENT_SET_TYPE,MESH_DISPLACEMENT_VALUES,ERR,ERROR,*999)
                  ELSE
                    CALL FlagError("Equations are not associated.",ERR,ERROR,*999)
                  END IF
                  CALL FIELD_PARAMETER_SET_UPDATE_START(EQUATIONS_SET_ALE_NAVIER_STOKES%GEOMETRY%GEOMETRIC_FIELD, & 
                    & FIELD_U_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE,ERR,ERROR,*999)
                  CALL FIELD_PARAMETER_SET_UPDATE_FINISH(EQUATIONS_SET_ALE_NAVIER_STOKES%GEOMETRY%GEOMETRIC_FIELD, & 
                    & FIELD_U_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE,ERR,ERROR,*999)
                  !Now use displacement values to calculate velocity values
                  TIME_INCREMENT=CONTROL_LOOP%TIME_LOOP%TIME_INCREMENT
                  ALPHA=1.0_DP/TIME_INCREMENT
                  CALL FIELD_PARAMETER_SETS_COPY(INDEPENDENT_FIELD_ALE_NAVIER_STOKES,FIELD_U_VARIABLE_TYPE, & 
                    & FIELD_MESH_DISPLACEMENT_SET_TYPE,FIELD_MESH_VELOCITY_SET_TYPE,ALPHA,ERR,ERROR,*999)
                ELSE  
                  CALL FlagError("Mesh motion calculation not successful for ALE problem.",ERR,ERROR,*999)
                END IF
              ELSE  
                CALL FlagError("Mesh update is not defined for non-dynamic problems.",ERR,ERROR,*999)
              END IF
            CASE DEFAULT
              LOCAL_ERROR="Problem subtype "//TRIM(NUMBER_TO_VSTRING(CONTROL_LOOP%PROBLEM%SPECIFICATION(3),"*",ERR,ERROR))// &
                & " is not valid for a Navier-Stokes equation fluid type of a fluid mechanics problem class."
              CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
            END SELECT
          CASE(PROBLEM_MULTI_PHYSICS_CLASS)
            SELECT CASE(CONTROL_LOOP%PROBLEM%SPECIFICATION(2))
            CASE(PROBLEM_FINITE_ELASTICITY_NAVIER_STOKES_TYPE)
              SELECT CASE(CONTROL_LOOP%PROBLEM%SPECIFICATION(3))
              CASE(PROBLEM_FINITE_ELASTICITY_NAVIER_STOKES_ALE_SUBTYPE)
                !Update mesh within the dynamic solver
                IF(SOLVER%SOLVE_TYPE==SOLVER_DYNAMIC_TYPE) THEN
                  IF(SOLVER%DYNAMIC_SOLVER%ALE) THEN
                    !Get the dependent field for the Laplace problem
                    !     CALL SOLVERS_SOLVER_GET(SOLVER%SOLVERS,1,SOLVER_LAPLACE,ERR,ERROR,*999)
                    CALL SOLVERS_SOLVER_GET(SOLVER%SOLVERS,2,SOLVER_LAPLACE,ERR,ERROR,*999)
                    SOLVER_EQUATIONS_LAPLACE=>SOLVER_LAPLACE%SOLVER_EQUATIONS
                    IF(ASSOCIATED(SOLVER_EQUATIONS_LAPLACE)) THEN
                      SOLVER_MAPPING_LAPLACE=>SOLVER_EQUATIONS_LAPLACE%SOLVER_MAPPING
                      IF(ASSOCIATED(SOLVER_MAPPING_LAPLACE)) THEN
                        EQUATIONS_SET_LAPLACE=>SOLVER_MAPPING_LAPLACE%EQUATIONS_SETS(1)%PTR
                        IF(ASSOCIATED(EQUATIONS_SET_LAPLACE)) THEN
                          DEPENDENT_FIELD_LAPLACE=>EQUATIONS_SET_LAPLACE%DEPENDENT%DEPENDENT_FIELD
                        ELSE
                          CALL FlagError("Laplace equations set is not associated.",ERR,ERROR,*999)
                        END IF
                        CALL FIELD_NUMBER_OF_COMPONENTS_GET(EQUATIONS_SET_LAPLACE%GEOMETRY%GEOMETRIC_FIELD,FIELD_U_VARIABLE_TYPE, &
                          & NUMBER_OF_DIMENSIONS_LAPLACE,ERR,ERROR,*999)
                      ELSE
                        CALL FlagError("Laplace solver mapping is not associated.",ERR,ERROR,*999)
                      END IF
                    ELSE
                      CALL FlagError("Laplace solver equations are not associated.",ERR,ERROR,*999)
                    END IF
                    !Get the independent field for the ALE Navier-Stokes problem
                    !    CALL SOLVERS_SOLVER_GET(SOLVER%SOLVERS,2,SOLVER_ALE_NAVIER_STOKES,ERR,ERROR,*999)
                    CALL SOLVERS_SOLVER_GET(SOLVER%SOLVERS,1,SOLVER_ALE_NAVIER_STOKES,ERR,ERROR,*999)
                    SOLVER_EQUATIONS_ALE_NAVIER_STOKES=>SOLVER_ALE_NAVIER_STOKES%SOLVER_EQUATIONS
                    IF(ASSOCIATED(SOLVER_EQUATIONS_ALE_NAVIER_STOKES)) THEN
                      SOLVER_MAPPING_ALE_NAVIER_STOKES=>SOLVER_EQUATIONS_ALE_NAVIER_STOKES%SOLVER_MAPPING
                      IF(ASSOCIATED(SOLVER_MAPPING_ALE_NAVIER_STOKES)) THEN
                        EquationsSetIndex=1
                        ALENavierStokesEquationsSetFound=.FALSE.
                        !Find the NavierStokes equations set as there is a finite elasticity equations set too
                        DO WHILE (.NOT.ALENavierStokesEquationsSetFound &
                          & .AND.EquationsSetIndex<=SOLVER_MAPPING_ALE_NAVIER_STOKES%NUMBER_OF_EQUATIONS_SETS)
                          EQUATIONS_SET_ALE_NAVIER_STOKES=>SOLVER_MAPPING_ALE_NAVIER_STOKES%EQUATIONS_SETS(EquationsSetIndex)%PTR
                          IF(ASSOCIATED(EQUATIONS_SET_ALE_NAVIER_STOKES)) THEN
                            IF(EQUATIONS_SET_ALE_NAVIER_STOKES%SPECIFICATION(1)==EQUATIONS_SET_FLUID_MECHANICS_CLASS &
                              & .AND.EQUATIONS_SET_ALE_NAVIER_STOKES%SPECIFICATION(2)==EQUATIONS_SET_NAVIER_STOKES_EQUATION_TYPE &
                              & .AND.EQUATIONS_SET_ALE_NAVIER_STOKES%SPECIFICATION(3)==EQUATIONS_SET_ALE_NAVIER_STOKES_SUBTYPE) THEN
                              INDEPENDENT_FIELD_ALE_NAVIER_STOKES=>EQUATIONS_SET_ALE_NAVIER_STOKES%INDEPENDENT%INDEPENDENT_FIELD
                              IF(ASSOCIATED(INDEPENDENT_FIELD_ALE_NAVIER_STOKES)) ALENavierStokesEquationsSetFound=.TRUE.
                            ELSE
                              EquationsSetIndex=EquationsSetIndex+1
                            END IF
                          ELSE
                            CALL FlagError("ALE Navier-Stokes equations set is not associated.",ERR,ERROR,*999)
                          END IF
                        END DO
                        IF(ALENavierStokesEquationsSetFound.EQV..FALSE.) THEN
                          CALL FlagError("ALE NavierStokes equations set not found when trying to update ALE mesh.",Err,Error,*999)
                        END IF
                        CALL FIELD_NUMBER_OF_COMPONENTS_GET(EQUATIONS_SET_ALE_NAVIER_STOKES%GEOMETRY%GEOMETRIC_FIELD, & 
                          & FIELD_U_VARIABLE_TYPE,NUMBER_OF_DIMENSIONS_ALE_NAVIER_STOKES,ERR,ERROR,*999)
                      ELSE
                        CALL FlagError("ALE Navier-Stokes solver mapping is not associated.",ERR,ERROR,*999)
                      END IF
                    ELSE
                      CALL FlagError("ALE Navier-Stokes solver equations are not associated.",ERR,ERROR,*999)
                    END IF
                    !Copy result from Laplace mesh movement to Navier-Stokes' independent field
                    IF(NUMBER_OF_DIMENSIONS_ALE_NAVIER_STOKES==NUMBER_OF_DIMENSIONS_LAPLACE) THEN
                      DO I=1,NUMBER_OF_DIMENSIONS_ALE_NAVIER_STOKES
                        CALL Field_ParametersToFieldParametersCopy(DEPENDENT_FIELD_LAPLACE, & 
                          & FIELD_U_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE,I,INDEPENDENT_FIELD_ALE_NAVIER_STOKES, & 
                          & FIELD_U_VARIABLE_TYPE,FIELD_MESH_DISPLACEMENT_SET_TYPE,I,ERR,ERROR,*999)
                      END DO
                    ELSE
                      CALL FlagError("Dimension of Laplace and ALE Navier-Stokes equations set is not consistent.",ERR,ERROR,*999)
                    END IF
                    !Use calculated values to update mesh
                    CALL FIELD_COMPONENT_MESH_COMPONENT_GET(EQUATIONS_SET_ALE_NAVIER_STOKES%GEOMETRY%GEOMETRIC_FIELD, & 
                      & FIELD_U_VARIABLE_TYPE,1,GEOMETRIC_MESH_COMPONENT,ERR,ERROR,*999)
                    NULLIFY(MESH_DISPLACEMENT_VALUES)
                    CALL FIELD_PARAMETER_SET_DATA_GET(INDEPENDENT_FIELD_ALE_NAVIER_STOKES,FIELD_U_VARIABLE_TYPE, & 
                      & FIELD_MESH_DISPLACEMENT_SET_TYPE,MESH_DISPLACEMENT_VALUES,ERR,ERROR,*999)
                    EQUATIONS=>SOLVER_MAPPING_LAPLACE%EQUATIONS_SET_TO_SOLVER_MAP(1)%EQUATIONS
                    IF(ASSOCIATED(EQUATIONS)) THEN
                      EQUATIONS_MAPPING=>EQUATIONS%EQUATIONS_MAPPING
                      IF(ASSOCIATED(EQUATIONS_MAPPING)) THEN
                        DO variable_idx=1,EQUATIONS_SET_ALE_NAVIER_STOKES%GEOMETRY%GEOMETRIC_FIELD%NUMBER_OF_VARIABLES
                          variable_type=EQUATIONS_SET_ALE_NAVIER_STOKES%GEOMETRY%GEOMETRIC_FIELD%VARIABLES(variable_idx)% &
                            & VARIABLE_TYPE
                          FIELD_VARIABLE=>EQUATIONS_SET_ALE_NAVIER_STOKES%GEOMETRY%GEOMETRIC_FIELD% &
                            & VARIABLE_TYPE_MAP(variable_type)%PTR
                          IF(ASSOCIATED(FIELD_VARIABLE)) THEN
                            DO component_idx=1,FIELD_VARIABLE%NUMBER_OF_COMPONENTS
                              DOMAIN=>FIELD_VARIABLE%COMPONENTS(component_idx)%DOMAIN
                              IF(ASSOCIATED(DOMAIN)) THEN
                                IF(ASSOCIATED(DOMAIN%TOPOLOGY)) THEN
                                  DOMAIN_NODES=>DOMAIN%TOPOLOGY%NODES
                                  IF(ASSOCIATED(DOMAIN_NODES)) THEN
                                    !Loop over the local nodes excluding the ghosts.
                                    DO node_idx=1,DOMAIN_NODES%NUMBER_OF_NODES
                                      DO deriv_idx=1,DOMAIN_NODES%NODES(node_idx)%NUMBER_OF_DERIVATIVES
                                        !Default to version 1 of each node derivative
                                        local_ny=FIELD_VARIABLE%COMPONENTS(component_idx)%PARAM_TO_DOF_MAP% &
                                          & NODE_PARAM2DOF_MAP%NODES(node_idx)%DERIVATIVES(deriv_idx)%VERSIONS(1)
                                        CALL FIELD_PARAMETER_SET_ADD_LOCAL_DOF(EQUATIONS_SET_ALE_NAVIER_STOKES%GEOMETRY% &
                                          & GEOMETRIC_FIELD,FIELD_U_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE,local_ny, & 
                                          & MESH_DISPLACEMENT_VALUES(local_ny),ERR,ERROR,*999)
                                      END DO !deriv_idx
                                    END DO !node_idx
                                  END IF
                                END IF
                              END IF
                            END DO !component_idx
                          END IF
                        END DO !variable_idx
                      ELSE
                        CALL FlagError("Equations mapping is not associated.",ERR,ERROR,*999)
                      END IF
                      CALL FIELD_PARAMETER_SET_DATA_RESTORE(INDEPENDENT_FIELD_ALE_NAVIER_STOKES,FIELD_U_VARIABLE_TYPE, & 
                        & FIELD_MESH_DISPLACEMENT_SET_TYPE,MESH_DISPLACEMENT_VALUES,ERR,ERROR,*999)
                    ELSE
                      CALL FlagError("Equations are not associated.",ERR,ERROR,*999)
                    END IF
                    CALL FIELD_PARAMETER_SET_UPDATE_START(EQUATIONS_SET_ALE_NAVIER_STOKES%GEOMETRY%GEOMETRIC_FIELD, & 
                      & FIELD_U_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE,ERR,ERROR,*999)
                    CALL FIELD_PARAMETER_SET_UPDATE_FINISH(EQUATIONS_SET_ALE_NAVIER_STOKES%GEOMETRY%GEOMETRIC_FIELD, & 
                      & FIELD_U_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE,ERR,ERROR,*999)
                    !Now use displacement values to calculate velocity values
                    TIME_INCREMENT=CONTROL_LOOP%TIME_LOOP%TIME_INCREMENT
                    ALPHA=1.0_DP/TIME_INCREMENT
                    CALL FIELD_PARAMETER_SETS_COPY(INDEPENDENT_FIELD_ALE_NAVIER_STOKES,FIELD_U_VARIABLE_TYPE, & 
                      & FIELD_MESH_DISPLACEMENT_SET_TYPE,FIELD_MESH_VELOCITY_SET_TYPE,ALPHA,ERR,ERROR,*999)
                  ELSE  
                    CALL FlagError("Mesh motion calculation not successful for ALE problem.",ERR,ERROR,*999)
                  END IF
                ELSE  
                  CALL FlagError("Mesh update is not defined for non-dynamic problems.",ERR,ERROR,*999)
                END IF
              CASE DEFAULT
                LOCAL_ERROR="Problem subtype "//TRIM(NUMBER_TO_VSTRING(CONTROL_LOOP%PROBLEM%SPECIFICATION(3),"*",ERR,ERROR))// &
                  & " is not valid for a FiniteElasticity-NavierStokes type of a multi physics problem class."
              END SELECT
            CASE DEFAULT
              LOCAL_ERROR="Problem type "//TRIM(NUMBER_TO_VSTRING(CONTROL_LOOP%PROBLEM%SPECIFICATION(2),"*",ERR,ERROR))// &
                & " is not valid for NAVIER_STOKES_PRE_SOLVE_ALE_UPDATE_MESH of a multi physics problem class."
            END SELECT
          CASE DEFAULT
            LOCAL_ERROR="Problem class "//TRIM(NUMBER_TO_VSTRING(CONTROL_LOOP%PROBLEM%SPECIFICATION(1),"*",ERR,ERROR))// &
              & " is not valid for NAVIER_STOKES_PRE_SOLVE_ALE_UPDATE_MESH."
            CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
          END SELECT
        ELSE
          CALL FlagError("Problem is not associated.",ERR,ERROR,*999)
        END IF
      ELSE
        CALL FlagError("Solver is not associated.",ERR,ERROR,*999)
      END IF
    ELSE
      CALL FlagError("Control loop is not associated.",ERR,ERROR,*999)
    ENDIF
    
    EXITS("NAVIER_STOKES_PRE_SOLVE_ALE_UPDATE_MESH")
    RETURN
999 ERRORSEXITS("NAVIER_STOKES_PRE_SOLVE_ALE_UPDATE_MESH",ERR,ERROR)
    RETURN 1
    
  END SUBROUTINE NAVIER_STOKES_PRE_SOLVE_ALE_UPDATE_MESH

  !
  !================================================================================================================================
  !
  !>Update mesh parameters for Laplace problem
  SUBROUTINE NavierStokes_PreSolveALEUpdateParameters(SOLVER,ERR,ERROR,*)

    !Argument variables
    TYPE(SOLVER_TYPE), POINTER :: SOLVER
    INTEGER(INTG), INTENT(OUT) :: ERR
    TYPE(VARYING_STRING), INTENT(OUT) :: ERROR
    !Local Variables
    TYPE(CONTROL_LOOP_TYPE), POINTER :: CONTROL_LOOP
    TYPE(DOMAIN_NODES_TYPE), POINTER :: DOMAIN_NODES
    TYPE(DOMAIN_TYPE), POINTER :: DOMAIN
    TYPE(FIELD_TYPE), POINTER :: INDEPENDENT_FIELD
    TYPE(FIELD_VARIABLE_TYPE), POINTER :: FIELD_VARIABLE
    TYPE(EQUATIONS_SET_TYPE), POINTER :: EQUATIONS_SET
    TYPE(EQUATIONS_TYPE), POINTER :: EQUATIONS
    TYPE(SOLVER_EQUATIONS_TYPE), POINTER :: SOLVER_EQUATIONS
    TYPE(SOLVER_MAPPING_TYPE), POINTER :: SOLVER_MAPPING
    TYPE(SOLVERS_TYPE), POINTER :: SOLVERS
    TYPE(VARYING_STRING) :: LOCAL_ERROR
    INTEGER(INTG) :: component_idx,deriv_idx,local_ny,node_idx,variable_idx,variable_type
    REAL(DP) :: CURRENT_TIME,TIME_INCREMENT
    REAL(DP), POINTER :: MESH_STIFF_VALUES(:)

    ENTERS("NavierStokes_PreSolveALEUpdateParameters",ERR,ERROR,*999)

    IF(ASSOCIATED(SOLVER)) THEN
      SOLVERS=>SOLVER%SOLVERS
      IF(ASSOCIATED(SOLVERS)) THEN
        CONTROL_LOOP=>SOLVERS%CONTROL_LOOP
        CALL CONTROL_LOOP_CURRENT_TIMES_GET(CONTROL_LOOP,CURRENT_TIME,TIME_INCREMENT,ERR,ERROR,*999)
        IF(ASSOCIATED(CONTROL_LOOP%PROBLEM)) THEN
          IF(.NOT.ALLOCATED(CONTROL_LOOP%problem%specification)) THEN
            CALL FlagError("Problem specification array is not allocated.",err,error,*999)
          ELSE IF(SIZE(CONTROL_LOOP%problem%specification,1)<3) THEN
            CALL FlagError("Problem specification must have three entries for a Navier-Stokes problem.",err,error,*999)
          END IF
          SELECT CASE(CONTROL_LOOP%PROBLEM%SPECIFICATION(1))
          CASE(PROBLEM_FLUID_MECHANICS_CLASS)
            SELECT CASE(CONTROL_LOOP%PROBLEM%SPECIFICATION(3))
            CASE(PROBLEM_STATIC_NAVIER_STOKES_SUBTYPE,PROBLEM_LAPLACE_NAVIER_STOKES_SUBTYPE)
              ! do nothing ???
            CASE(PROBLEM_TRANSIENT_NAVIER_STOKES_SUBTYPE)
              ! do nothing ???
            CASE(PROBLEM_TRANSIENT_RBS_NAVIER_STOKES_SUBTYPE,PROBLEM_MULTISCALE_NAVIER_STOKES_SUBTYPE)
              ! do nothing ???
            CASE(PROBLEM_TRANSIENT1D_NAVIER_STOKES_SUBTYPE,PROBLEM_COUPLED1D0D_NAVIER_STOKES_SUBTYPE, &
             & PROBLEM_TRANSIENT1D_ADV_NAVIER_STOKES_SUBTYPE,PROBLEM_COUPLED1D0D_ADV_NAVIER_STOKES_SUBTYPE)
              ! do nothing ???
            CASE(PROBLEM_ALE_NAVIER_STOKES_SUBTYPE)
              IF(SOLVER%SOLVE_TYPE==SOLVER_LINEAR_TYPE) THEN
                !Get the independent field for the ALE Navier-Stokes problem
                SOLVER_EQUATIONS=>SOLVER%SOLVER_EQUATIONS
                IF(ASSOCIATED(SOLVER_EQUATIONS)) THEN
                  SOLVER_MAPPING=>SOLVER_EQUATIONS%SOLVER_MAPPING
                  IF(ASSOCIATED(SOLVER_MAPPING)) THEN
                    EQUATIONS_SET=>SOLVER_MAPPING%EQUATIONS_SETS(1)%PTR
                    NULLIFY(MESH_STIFF_VALUES)
                    CALL FIELD_PARAMETER_SET_DATA_GET(EQUATIONS_SET%INDEPENDENT%INDEPENDENT_FIELD,FIELD_U_VARIABLE_TYPE, & 
                      & FIELD_VALUES_SET_TYPE,MESH_STIFF_VALUES,ERR,ERROR,*999)
                    IF(ASSOCIATED(EQUATIONS_SET)) THEN
                      EQUATIONS=>SOLVER_MAPPING%EQUATIONS_SET_TO_SOLVER_MAP(1)%EQUATIONS
                      IF(ASSOCIATED(EQUATIONS)) THEN
                        INDEPENDENT_FIELD=>EQUATIONS_SET%INDEPENDENT%INDEPENDENT_FIELD
                        IF(ASSOCIATED(INDEPENDENT_FIELD)) THEN
                          DO variable_idx=1,EQUATIONS_SET%DEPENDENT%DEPENDENT_FIELD%NUMBER_OF_VARIABLES
                            variable_type=EQUATIONS_SET%DEPENDENT%DEPENDENT_FIELD%VARIABLES(variable_idx)%VARIABLE_TYPE
                            FIELD_VARIABLE=>EQUATIONS_SET%DEPENDENT%DEPENDENT_FIELD%VARIABLE_TYPE_MAP(variable_type)%PTR
                            IF(ASSOCIATED(FIELD_VARIABLE)) THEN
                              DO component_idx=1,FIELD_VARIABLE%NUMBER_OF_COMPONENTS
                                DOMAIN=>FIELD_VARIABLE%COMPONENTS(component_idx)%DOMAIN
                                IF(ASSOCIATED(DOMAIN)) THEN
                                  IF(ASSOCIATED(DOMAIN%TOPOLOGY)) THEN
                                    DOMAIN_NODES=>DOMAIN%TOPOLOGY%NODES
                                    IF(ASSOCIATED(DOMAIN_NODES)) THEN
                                      !Loop over the local nodes excluding the ghosts.
                                      DO node_idx=1,DOMAIN_NODES%NUMBER_OF_NODES
                                        DO deriv_idx=1,DOMAIN_NODES%NODES(node_idx)%NUMBER_OF_DERIVATIVES
                                          !Default to version 1 of each node derivative
                                          local_ny=FIELD_VARIABLE%COMPONENTS(component_idx)%PARAM_TO_DOF_MAP% &
                                            & NODE_PARAM2DOF_MAP%NODES(node_idx)%DERIVATIVES(deriv_idx)%VERSIONS(1)
                                          !Calculation of K values dependent on current mesh topology
                                          MESH_STIFF_VALUES(local_ny)=1.0_DP
                                          CALL FIELD_PARAMETER_SET_UPDATE_LOCAL_DOF(EQUATIONS_SET%INDEPENDENT%INDEPENDENT_FIELD, & 
                                            & FIELD_U_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE,local_ny, & 
                                            & MESH_STIFF_VALUES(local_ny),ERR,ERROR,*999)
                                        END DO !deriv_idx
                                      END DO !node_idx
                                    END IF
                                  END IF
                                END IF
                              END DO !component_idx
                            END IF
                          END DO !variable_idx
                        ELSE
                          CALL FlagError("Independent field is not associated.",ERR,ERROR,*999)
                        END IF
                      ELSE
                        CALL FlagError("Equations are not associated.",ERR,ERROR,*999)
                      END IF
                    ELSE
                      CALL FlagError("Equations set is not associated.",ERR,ERROR,*999)
                    END IF
                    CALL FIELD_PARAMETER_SET_DATA_RESTORE(EQUATIONS_SET%INDEPENDENT%INDEPENDENT_FIELD,FIELD_U_VARIABLE_TYPE, & 
                      & FIELD_VALUES_SET_TYPE,MESH_STIFF_VALUES,ERR,ERROR,*999)                     
                  ELSE
                    CALL FlagError("Solver mapping is not associated.",ERR,ERROR,*999)
                  END IF
                ELSE
                  CALL FlagError("Solver equations are not associated.",ERR,ERROR,*999)
                END IF
              ELSE IF(SOLVER%SOLVE_TYPE==SOLVER_DYNAMIC_TYPE) THEN
                CALL FlagError("Mesh motion calculation not successful for ALE problem.",ERR,ERROR,*999)
              END IF
            CASE DEFAULT
              LOCAL_ERROR="Problem subtype "//TRIM(NUMBER_TO_VSTRING(CONTROL_LOOP%PROBLEM%SPECIFICATION(3),"*",ERR,ERROR))// &
                & " is not valid for a Navier-Stokes equation fluid type of a fluid mechanics problem class."
              CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
            END SELECT
          CASE(PROBLEM_MULTI_PHYSICS_CLASS)
            SELECT CASE(CONTROL_LOOP%PROBLEM%SPECIFICATION(2))
            CASE(PROBLEM_FINITE_ELASTICITY_NAVIER_STOKES_TYPE)
              SELECT CASE(CONTROL_LOOP%PROBLEM%SPECIFICATION(3))
              CASE(PROBLEM_FINITE_ELASTICITY_NAVIER_STOKES_ALE_SUBTYPE)
                IF(SOLVER%SOLVE_TYPE==SOLVER_LINEAR_TYPE) THEN
                  !Get the independent field for the ALE Navier-Stokes problem
                  SOLVER_EQUATIONS=>SOLVER%SOLVER_EQUATIONS
                  IF(ASSOCIATED(SOLVER_EQUATIONS)) THEN
                    SOLVER_MAPPING=>SOLVER_EQUATIONS%SOLVER_MAPPING
                    IF(ASSOCIATED(SOLVER_MAPPING)) THEN
                      EQUATIONS_SET=>SOLVER_MAPPING%EQUATIONS_SETS(1)%PTR
                      NULLIFY(MESH_STIFF_VALUES)
                      CALL FIELD_PARAMETER_SET_DATA_GET(EQUATIONS_SET%INDEPENDENT%INDEPENDENT_FIELD,FIELD_U_VARIABLE_TYPE, & 
                        & FIELD_VALUES_SET_TYPE,MESH_STIFF_VALUES,ERR,ERROR,*999)
                      IF(ASSOCIATED(EQUATIONS_SET)) THEN
                        EQUATIONS=>SOLVER_MAPPING%EQUATIONS_SET_TO_SOLVER_MAP(1)%EQUATIONS
                        IF(ASSOCIATED(EQUATIONS)) THEN
                          INDEPENDENT_FIELD=>EQUATIONS_SET%INDEPENDENT%INDEPENDENT_FIELD
                          IF(ASSOCIATED(INDEPENDENT_FIELD)) THEN
                            DO variable_idx=1,EQUATIONS_SET%DEPENDENT%DEPENDENT_FIELD%NUMBER_OF_VARIABLES
                              variable_type=EQUATIONS_SET%DEPENDENT%DEPENDENT_FIELD%VARIABLES(variable_idx)%VARIABLE_TYPE
                              FIELD_VARIABLE=>EQUATIONS_SET%DEPENDENT%DEPENDENT_FIELD%VARIABLE_TYPE_MAP(variable_type)%PTR
                              IF(ASSOCIATED(FIELD_VARIABLE)) THEN
                                DO component_idx=1,FIELD_VARIABLE%NUMBER_OF_COMPONENTS
                                  DOMAIN=>FIELD_VARIABLE%COMPONENTS(component_idx)%DOMAIN
                                  IF(ASSOCIATED(DOMAIN)) THEN
                                    IF(ASSOCIATED(DOMAIN%TOPOLOGY)) THEN
                                      DOMAIN_NODES=>DOMAIN%TOPOLOGY%NODES
                                      IF(ASSOCIATED(DOMAIN_NODES)) THEN
                                        !Loop over the local nodes excluding the ghosts.
                                        DO node_idx=1,DOMAIN_NODES%NUMBER_OF_NODES
                                          DO deriv_idx=1,DOMAIN_NODES%NODES(node_idx)%NUMBER_OF_DERIVATIVES
                                            !Default to version 1 of each node derivative
                                            local_ny=FIELD_VARIABLE%COMPONENTS(component_idx)%PARAM_TO_DOF_MAP% &
                                              & NODE_PARAM2DOF_MAP%NODES(node_idx)%DERIVATIVES(deriv_idx)%VERSIONS(1)
                                            !Calculation of K values dependent on current mesh topology
                                            MESH_STIFF_VALUES(local_ny)=1.0_DP
                                            CALL FIELD_PARAMETER_SET_UPDATE_LOCAL_DOF(EQUATIONS_SET%INDEPENDENT% &
                                              & INDEPENDENT_FIELD,FIELD_U_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE,local_ny, & 
                                              & MESH_STIFF_VALUES(local_ny),ERR,ERROR,*999)
                                          END DO !deriv_idx
                                        END DO !node_idx
                                      END IF
                                    END IF
                                  END IF
                                END DO !component_idx
                              END IF
                            END DO !variable_idx
                          ELSE
                            CALL FlagError("Independent field is not associated.",ERR,ERROR,*999)
                          END IF
                        ELSE
                          CALL FlagError("Equations are not associated.",ERR,ERROR,*999)
                        END IF
                      ELSE
                        CALL FlagError("Equations set is not associated.",ERR,ERROR,*999)
                      END IF
                      CALL FIELD_PARAMETER_SET_DATA_RESTORE(EQUATIONS_SET%INDEPENDENT%INDEPENDENT_FIELD,FIELD_U_VARIABLE_TYPE, & 
                        & FIELD_VALUES_SET_TYPE,MESH_STIFF_VALUES,ERR,ERROR,*999)                     
                    ELSE
                      CALL FlagError("Solver mapping is not associated.",ERR,ERROR,*999)
                    END IF
                  ELSE
                    CALL FlagError("Solver equations are not associated.",ERR,ERROR,*999)
                  END IF
                ELSE IF(SOLVER%SOLVE_TYPE==SOLVER_DYNAMIC_TYPE) THEN
                  CALL FlagError("Mesh motion calculation not successful for ALE problem.",ERR,ERROR,*999)
                END IF
              CASE DEFAULT
                LOCAL_ERROR="The third problem specification of "// &
                  & TRIM(NUMBER_TO_VSTRING(CONTROL_LOOP%PROBLEM%SPECIFICATION(3),"*",ERR,ERROR))// &
                  & " is not valid for a FiniteElasticity-NavierStokes type of a multi physics problem."
                CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
              END SELECT
            CASE DEFAULT
              LOCAL_ERROR="The second problem specification of "// &
                & TRIM(NUMBER_TO_VSTRING(CONTROL_LOOP%PROBLEM%specification(2),"*",ERR,ERROR))// &
                & " is not valid for NavierStokes_PreSolveALEUpdateParameters of a multi physics problem."
              CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
            END SELECT
          CASE DEFAULT
            LOCAL_ERROR="The first problem specification of "// &
              & TRIM(NUMBER_TO_VSTRING(CONTROL_LOOP%PROBLEM%specification(1),"*",ERR,ERROR))// &
              & " is not valid for NavierStokes_PreSolveALEUpdateParameters."
            CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
          END SELECT
        ELSE
          CALL FlagError("Problem is not associated.",ERR,ERROR,*999)
        END IF
      ELSE
        CALL FlagError("Solver is not associated.",ERR,ERROR,*999)
      END IF
    ELSE
      CALL FlagError("Control loop is not associated.",ERR,ERROR,*999)
    ENDIF
    
    EXITS("NavierStokes_PreSolveALEUpdateParameters")
    RETURN
999 ERRORSEXITS("NavierStokes_PreSolveALEUpdateParameters",ERR,ERROR)
    RETURN 1
    
  END SUBROUTINE NavierStokes_PreSolveALEUpdateParameters

  !
  !================================================================================================================================
  !

  !>Output data post solve
  SUBROUTINE NAVIER_STOKES_POST_SOLVE_OUTPUT_DATA(SOLVER,ERR,ERROR,*)

    !Argument variables
    TYPE(SOLVER_TYPE), POINTER :: SOLVER
    INTEGER(INTG), INTENT(OUT) :: ERR
    TYPE(VARYING_STRING), INTENT(OUT) :: ERROR
    !Local Variables
    TYPE(CONTROL_LOOP_TYPE), POINTER :: CONTROL_LOOP
    TYPE(EQUATIONS_SET_TYPE), POINTER :: EQUATIONS_SET
    TYPE(FIELDS_TYPE), POINTER :: Fields
    TYPE(REGION_TYPE), POINTER :: DEPENDENT_REGION
    TYPE(SOLVER_EQUATIONS_TYPE), POINTER :: SOLVER_EQUATIONS
    TYPE(SOLVER_MAPPING_TYPE), POINTER :: SOLVER_MAPPING
    TYPE(SOLVERS_TYPE), POINTER :: SOLVERS
    TYPE(VARYING_STRING) :: LOCAL_ERROR,METHOD,VFileName,FILENAME
    INTEGER(INTG) :: EQUATIONS_SET_IDX,CURRENT_LOOP_ITERATION,OUTPUT_ITERATION_NUMBER
    INTEGER(INTG) :: NUMBER_OF_DIMENSIONS,FileNameLength
    REAL(DP) :: CURRENT_TIME,TIME_INCREMENT,START_TIME,STOP_TIME
    LOGICAL :: EXPORT_FIELD
    CHARACTER(14) :: FILE,OUTPUT_FILE

    NULLIFY(Fields) 

    ENTERS("NAVIER_STOKES_POST_SOLVE_OUTPUT_DATA",ERR,ERROR,*999)

    IF(ASSOCIATED(SOLVER)) THEN
      SOLVERS=>SOLVER%SOLVERS
      IF(ASSOCIATED(SOLVERS)) THEN
        CONTROL_LOOP=>SOLVERS%CONTROL_LOOP
        IF(ASSOCIATED(CONTROL_LOOP%PROBLEM)) THEN
          IF(.NOT.ALLOCATED(CONTROL_LOOP%problem%specification)) THEN
            CALL FlagError("Problem specification array is not allocated.",err,error,*999)
          ELSE IF(SIZE(CONTROL_LOOP%problem%specification,1)<3) THEN
            CALL FlagError("Problem specification must have three entries for a Navier-Stokes problem.",err,error,*999)
          END IF
          SELECT CASE(CONTROL_LOOP%PROBLEM%specification(3))
          CASE(PROBLEM_STATIC_NAVIER_STOKES_SUBTYPE, &
             & PROBLEM_LAPLACE_NAVIER_STOKES_SUBTYPE)
            SOLVER_EQUATIONS=>SOLVER%SOLVER_EQUATIONS
              IF(ASSOCIATED(SOLVER_EQUATIONS)) THEN
                SOLVER_MAPPING=>SOLVER_EQUATIONS%SOLVER_MAPPING
                IF(ASSOCIATED(SOLVER_MAPPING)) THEN
                  !Make sure the equations sets are up to date
                  DO equations_set_idx=1,SOLVER_MAPPING%NUMBER_OF_EQUATIONS_SETS
                    EQUATIONS_SET=>SOLVER_MAPPING%EQUATIONS_SETS(equations_set_idx)%PTR
                    METHOD="FORTRAN"
                    EXPORT_FIELD=.TRUE.
                    IF(EXPORT_FIELD) THEN          
                      OUTPUT_FILE = "StaticSolution"
                      FileNameLength = LEN_TRIM(OUTPUT_FILE)
                      VFileName = OUTPUT_FILE(1:FileNameLength)
                      CALL WRITE_STRING(GENERAL_OUTPUT_TYPE,"...",ERR,ERROR,*999)
                      Fields=>EQUATIONS_SET%REGION%FIELDS
                      CALL FIELD_IO_NODES_EXPORT(Fields,VFileName,METHOD,ERR,ERROR,*999)
                      CALL WRITE_STRING(GENERAL_OUTPUT_TYPE,"Now export elements... ",ERR,ERROR,*999)
                      CALL FIELD_IO_ELEMENTS_EXPORT(Fields,VFileName,METHOD,ERR,ERROR,*999)
                      NULLIFY(Fields)
                      CALL WRITE_STRING(GENERAL_OUTPUT_TYPE,OUTPUT_FILE,ERR,ERROR,*999)
                      CALL WRITE_STRING(GENERAL_OUTPUT_TYPE,"...",ERR,ERROR,*999)
                    END IF
                  END DO
                END IF 
              END IF

          CASE(PROBLEM_TRANSIENT_NAVIER_STOKES_SUBTYPE, &
             & PROBLEM_ALE_NAVIER_STOKES_SUBTYPE, &
             & PROBLEM_PGM_NAVIER_STOKES_SUBTYPE, &
             & PROBLEM_QUASISTATIC_NAVIER_STOKES_SUBTYPE, &
             & PROBLEM_TRANSIENT_RBS_NAVIER_STOKES_SUBTYPE, &
             & PROBLEM_MULTISCALE_NAVIER_STOKES_SUBTYPE)

            CALL CONTROL_LOOP_CURRENT_TIMES_GET(CONTROL_LOOP,CURRENT_TIME,TIME_INCREMENT,ERR,ERROR,*999)
            SOLVER_EQUATIONS=>SOLVER%SOLVER_EQUATIONS
            IF(ASSOCIATED(SOLVER_EQUATIONS)) THEN
              SOLVER_MAPPING=>SOLVER_EQUATIONS%SOLVER_MAPPING
              IF(ASSOCIATED(SOLVER_MAPPING)) THEN
                !Make sure the equations sets are up to date
                DO equations_set_idx=1,SOLVER_MAPPING%NUMBER_OF_EQUATIONS_SETS
                  EQUATIONS_SET=>SOLVER_MAPPING%EQUATIONS_SETS(equations_set_idx)%PTR
                  CURRENT_LOOP_ITERATION=CONTROL_LOOP%TIME_LOOP%ITERATION_NUMBER
                  OUTPUT_ITERATION_NUMBER=CONTROL_LOOP%TIME_LOOP%OUTPUT_NUMBER
                  IF(OUTPUT_ITERATION_NUMBER/=0) THEN
                    IF(CONTROL_LOOP%TIME_LOOP%CURRENT_TIME<=CONTROL_LOOP%TIME_LOOP%STOP_TIME) THEN
                      WRITE(OUTPUT_FILE,'("TimeStep_",I0)') CURRENT_LOOP_ITERATION
                      FILE=OUTPUT_FILE
                      METHOD="FORTRAN"
                      EXPORT_FIELD=.TRUE.
                      IF(MOD(CURRENT_LOOP_ITERATION,OUTPUT_ITERATION_NUMBER)==0)  THEN   
                        !Use standard field IO routines (also only export nodes after first step as not a moving mesh case)
                        FileNameLength = LEN_TRIM(OUTPUT_FILE)
                        VFileName = OUTPUT_FILE(1:FileNameLength)
                        CALL WRITE_STRING(GENERAL_OUTPUT_TYPE,"...",ERR,ERROR,*999)
                        Fields=>EQUATIONS_SET%REGION%FIELDS
                        CALL FIELD_IO_NODES_EXPORT(Fields,VFileName,METHOD,ERR,ERROR,*999)
!                            CALL FLUID_MECHANICS_IO_WRITE_CMGUI(EQUATIONS_SET%REGION,EQUATIONS_SET%GLOBAL_NUMBER,FILE, &
!                              & ERR,ERROR,*999)
                        IF(CURRENT_LOOP_ITERATION==0) THEN
                          CALL WRITE_STRING(GENERAL_OUTPUT_TYPE,"Now export elements... ",ERR,ERROR,*999)
                          CALL FIELD_IO_ELEMENTS_EXPORT(Fields,VFileName,METHOD,ERR,ERROR,*999)
                        END IF
                        NULLIFY(Fields)
                        CALL WRITE_STRING(GENERAL_OUTPUT_TYPE,OUTPUT_FILE,ERR,ERROR,*999)
                        CALL WRITE_STRING(GENERAL_OUTPUT_TYPE,"...",ERR,ERROR,*999)
                      END IF                          
!                       ELSE IF(EXPORT_FIELD) THEN          
!                         IF(MOD(CURRENT_LOOP_ITERATION,OUTPUT_ITERATION_NUMBER)==0)  THEN   
!                           CALL WRITE_STRING(GENERAL_OUTPUT_TYPE,"...",ERR,ERROR,*999)
!                           CALL WRITE_STRING(GENERAL_OUTPUT_TYPE,"Now export fields... ",ERR,ERROR,*999)
!                           CALL FLUID_MECHANICS_IO_WRITE_CMGUI(EQUATIONS_SET%REGION,EQUATIONS_SET%GLOBAL_NUMBER,FILE, &
!                             & ERR,ERROR,*999)
!                           CALL WRITE_STRING(GENERAL_OUTPUT_TYPE,OUTPUT_FILE,ERR,ERROR,*999)
!                           CALL WRITE_STRING(GENERAL_OUTPUT_TYPE,"...",ERR,ERROR,*999)
!                           CALL FIELD_NUMBER_OF_COMPONENTS_GET(EQUATIONS_SET%GEOMETRY%GEOMETRIC_FIELD,FIELD_U_VARIABLE_TYPE, &
!                             & NUMBER_OF_DIMENSIONS,ERR,ERROR,*999)
!                           IF(NUMBER_OF_DIMENSIONS==3) THEN
! !\todo: Allow user to choose whether or not ENCAS ouput is activated (default = NO)
!                             EXPORT_FIELD=.FALSE.
!                             IF(EXPORT_FIELD) THEN
!                               CALL FLUID_MECHANICS_IO_WRITE_ENCAS(EQUATIONS_SET%REGION,EQUATIONS_SET%GLOBAL_NUMBER,FILE, &
!                                 & ERR,ERROR,*999)
!                               CALL WRITE_STRING(GENERAL_OUTPUT_TYPE,OUTPUT_FILE,ERR,ERROR,*999)
!                               CALL WRITE_STRING(GENERAL_OUTPUT_TYPE,"...",ERR,ERROR,*999)
!                             END IF
!                           END IF
!                         END IF
!                       END IF 
                      IF(ASSOCIATED(EQUATIONS_SET%ANALYTIC)) THEN
                        IF(EQUATIONS_SET%ANALYTIC%ANALYTIC_FUNCTION_TYPE==EQUATIONS_SET_NAVIER_STOKES_EQUATION_TWO_DIM_4.OR. &
                          & EQUATIONS_SET%ANALYTIC%ANALYTIC_FUNCTION_TYPE==EQUATIONS_SET_NAVIER_STOKES_EQUATION_TWO_DIM_5.OR. &
                          & EQUATIONS_SET%ANALYTIC%ANALYTIC_FUNCTION_TYPE==EQUATIONS_SET_NAVIER_STOKES_EQUATION_THREE_DIM_4.OR. &
                          & EQUATIONS_SET%ANALYTIC%ANALYTIC_FUNCTION_TYPE==EQUATIONS_SET_NAVIER_STOKES_EQUATION_THREE_DIM_5.OR. &
                          & EQUATIONS_SET%ANALYTIC%ANALYTIC_FUNCTION_TYPE==EQUATIONS_SET_NAVIER_STOKES_EQUATION_ONE_DIM_1.OR. &
                          & EQUATIONS_SET%ANALYTIC%ANALYTIC_FUNCTION_TYPE==EQUATIONS_SET_NAVIER_STOKES_EQUATION_THREE_DIM_1) THEN
                          CALL AnalyticAnalysis_Output(EQUATIONS_SET%DEPENDENT%DEPENDENT_FIELD,FILE,ERR,ERROR,*999)
                        END IF
                      END IF
                    END IF 
                  END IF
                END DO
              END IF
            END IF

          CASE(PROBLEM_TRANSIENT1D_NAVIER_STOKES_SUBTYPE, &
             & PROBLEM_COUPLED1D0D_NAVIER_STOKES_SUBTYPE, &
             & PROBLEM_TRANSIENT1D_ADV_NAVIER_STOKES_SUBTYPE, &
             & PROBLEM_COUPLED1D0D_ADV_NAVIER_STOKES_SUBTYPE, &
             & PROBLEM_STREE1D0D_NAVIER_STOKES_SUBTYPE, &
             & PROBLEM_STREE1D0D_ADV_NAVIER_STOKES_SUBTYPE)

            CALL CONTROL_LOOP_TIMES_GET(CONTROL_LOOP,START_TIME,STOP_TIME,CURRENT_TIME,TIME_INCREMENT, &
              & CURRENT_LOOP_ITERATION,OUTPUT_ITERATION_NUMBER,ERR,ERROR,*999)
            SOLVER_EQUATIONS=>SOLVER%SOLVER_EQUATIONS
            IF(ASSOCIATED(SOLVER_EQUATIONS)) THEN
              SOLVER_MAPPING=>SOLVER_EQUATIONS%SOLVER_MAPPING
              IF(ASSOCIATED(SOLVER_MAPPING)) THEN
                !Make sure the equations sets are up to date
                DO equations_set_idx=1,SOLVER_MAPPING%NUMBER_OF_EQUATIONS_SETS
                  EQUATIONS_SET=>SOLVER_MAPPING%EQUATIONS_SETS(equations_set_idx)%PTR
                  IF(OUTPUT_ITERATION_NUMBER/=0) THEN
                    IF(CURRENT_TIME<=STOP_TIME) THEN
                      IF(CURRENT_LOOP_ITERATION<10) THEN
                        WRITE(OUTPUT_FILE,'("TIME_STEP_000",I0)') CURRENT_LOOP_ITERATION
                      ELSE IF(CURRENT_LOOP_ITERATION<100) THEN
                        WRITE(OUTPUT_FILE,'("TIME_STEP_00",I0)') CURRENT_LOOP_ITERATION
                      ELSE IF(CURRENT_LOOP_ITERATION<1000) THEN
                        WRITE(OUTPUT_FILE,'("TIME_STEP_0",I0)') CURRENT_LOOP_ITERATION
                      ELSE IF(CURRENT_LOOP_ITERATION<10000) THEN
                        WRITE(OUTPUT_FILE,'("TIME_STEP_",I0)') CURRENT_LOOP_ITERATION
                      END IF
                      DEPENDENT_REGION=>EQUATIONS_SET%REGION
                      FILE=OUTPUT_FILE
                      FILENAME="./output/"//"MainTime_"//TRIM(NUMBER_TO_VSTRING(CURRENT_LOOP_ITERATION,"*",ERR,ERROR))
                      METHOD="FORTRAN"
                      EXPORT_FIELD=.TRUE.
                      IF(EXPORT_FIELD) THEN          
                        IF(MOD(CURRENT_LOOP_ITERATION,OUTPUT_ITERATION_NUMBER)==0)  THEN   
                          CALL WRITE_STRING(GENERAL_OUTPUT_TYPE,"...",ERR,ERROR,*999)
                          CALL WRITE_STRING(GENERAL_OUTPUT_TYPE,"Now export fields... ",ERR,ERROR,*999)
                          CALL FIELD_IO_NODES_EXPORT(DEPENDENT_REGION%FIELDS,FILENAME,METHOD,ERR,ERROR,*999)
                          CALL FIELD_IO_ELEMENTS_EXPORT(DEPENDENT_REGION%FIELDS,FILENAME,METHOD,ERR,ERROR,*999)
                          CALL WRITE_STRING(GENERAL_OUTPUT_TYPE,FILENAME,ERR,ERROR,*999)
                          CALL WRITE_STRING(GENERAL_OUTPUT_TYPE,"...",ERR,ERROR,*999)
                          CALL FIELD_NUMBER_OF_COMPONENTS_GET(EQUATIONS_SET%GEOMETRY%GEOMETRIC_FIELD,FIELD_U_VARIABLE_TYPE, &
                            & NUMBER_OF_DIMENSIONS,ERR,ERROR,*999)
                          IF(NUMBER_OF_DIMENSIONS==3) THEN
                            EXPORT_FIELD=.FALSE.
                            IF(EXPORT_FIELD) THEN
                              CALL FLUID_MECHANICS_IO_WRITE_ENCAS(EQUATIONS_SET%REGION,EQUATIONS_SET%GLOBAL_NUMBER,FILE, &
                                & ERR,ERROR,*999)
                              CALL WRITE_STRING(GENERAL_OUTPUT_TYPE,OUTPUT_FILE,ERR,ERROR,*999)
                              CALL WRITE_STRING(GENERAL_OUTPUT_TYPE,"...",ERR,ERROR,*999)
                            END IF
                          END IF
                        END IF
                      END IF 
                      IF(ASSOCIATED(EQUATIONS_SET%ANALYTIC)) THEN
                        IF(EQUATIONS_SET%ANALYTIC%ANALYTIC_FUNCTION_TYPE==EQUATIONS_SET_NAVIER_STOKES_EQUATION_TWO_DIM_4.OR. &
                          & EQUATIONS_SET%ANALYTIC%ANALYTIC_FUNCTION_TYPE==EQUATIONS_SET_NAVIER_STOKES_EQUATION_TWO_DIM_5.OR. &
                          & EQUATIONS_SET%ANALYTIC%ANALYTIC_FUNCTION_TYPE==EQUATIONS_SET_NAVIER_STOKES_EQUATION_THREE_DIM_4.OR. &
                          & EQUATIONS_SET%ANALYTIC%ANALYTIC_FUNCTION_TYPE==EQUATIONS_SET_NAVIER_STOKES_EQUATION_THREE_DIM_5.OR. &
                          & EQUATIONS_SET%ANALYTIC%ANALYTIC_FUNCTION_TYPE==EQUATIONS_SET_NAVIER_STOKES_EQUATION_ONE_DIM_1.OR. &
                          & EQUATIONS_SET%ANALYTIC%ANALYTIC_FUNCTION_TYPE==EQUATIONS_SET_NAVIER_STOKES_EQUATION_THREE_DIM_1) THEN
                          CALL AnalyticAnalysis_Output(EQUATIONS_SET%DEPENDENT%DEPENDENT_FIELD,FILE,ERR,ERROR,*999)
                        END IF
                      END IF
                    END IF 
                  END IF
                END DO
              END IF
            END IF
          CASE DEFAULT
            LOCAL_ERROR="Problem subtype "//TRIM(NUMBER_TO_VSTRING(CONTROL_LOOP%PROBLEM%SPECIFICATION(3),"*",ERR,ERROR))// &
              & " is not valid for a Navier-Stokes equation fluid type of a fluid mechanics problem class."
            CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
          END SELECT
        ELSE
          CALL FlagError("Control loop is not associated.",ERR,ERROR,*999)
        END IF
      ELSE
        CALL FlagError("Solvers is not associated.",ERR,ERROR,*999)
      END IF
    ELSE
      CALL FlagError("Solver is not associated.",ERR,ERROR,*999)
    ENDIF
    
    EXITS("NAVIER_STOKES_POST_SOLVE_OUTPUT_DATA")
    RETURN
999 ERRORSEXITS("NAVIER_STOKES_POST_SOLVE_OUTPUT_DATA",ERR,ERROR)
    RETURN 1
    
  END SUBROUTINE NAVIER_STOKES_POST_SOLVE_OUTPUT_DATA

  !
  !================================================================================================================================
  !

  !>Sets up analytic parameters and calls NAVIER_STOKES_ANALYTIC_FUNCTIONS_EVALUATE to evaluate solutions to analytic problems
  SUBROUTINE NavierStokes_BoundaryConditionsAnalyticCalculate(equationsSet,boundaryConditions,err,error,*)

    !Argument variables
    TYPE(EQUATIONS_SET_TYPE), POINTER :: equationsSet
    TYPE(BOUNDARY_CONDITIONS_TYPE), POINTER :: boundaryConditions
    INTEGER(INTG), INTENT(OUT) :: err !<The error code
    TYPE(VARYING_STRING), INTENT(OUT) :: error !<The error string
    !Local Variables
    TYPE(BOUNDARY_CONDITIONS_VARIABLE_TYPE), POINTER :: boundaryConditionsVariable
    TYPE(DOMAIN_NODES_TYPE), POINTER :: domainNodes
    TYPE(DOMAIN_TYPE), POINTER :: domain
    TYPE(FIELD_INTERPOLATED_POINT_PTR_TYPE), POINTER :: interpolatedPoint(:)
    TYPE(FIELD_INTERPOLATION_PARAMETERS_PTR_TYPE), POINTER :: interpolationParameters(:)
    TYPE(FIELD_TYPE), POINTER :: analyticField,dependentField,geometricField,materialsField
    TYPE(FIELD_VARIABLE_TYPE), POINTER :: fieldVariable,geometricVariable,analyticVariable,materialsVariable
    TYPE(VARYING_STRING) :: localError
    INTEGER(INTG) :: componentIdx,derivativeIdx,dimensionIdx,local_ny,nodeIdx,numberOfDimensions,variableIdx,variableType,I,J,K
    INTEGER(INTG) :: numberOfNodesXiCoord(3),elementIdx,en_idx,boundaryCount,analyticFunctionType,globalDerivativeIndex,versionIdx
    INTEGER(INTG) :: boundaryConditionsCheckVariable,numberOfXi,nodeNumber,userNodeNumber,localDof,globalDof
    INTEGER(INTG) :: parameterIdx,numberOfParameters
    REAL(DP) :: TIME,VALUE,X(3),xiCoordinates(3),initialValue,T_COORDINATES(20,3),nodeAnalyticParameters(10)
    REAL(DP), POINTER :: analyticParameters(:),geometricParameters(:),materialsParameters(:)

    ENTERS("NavierStokes_BoundaryConditionsAnalyticCalculate",err,error,*999)

    boundaryCount=0
    xiCoordinates(3)=0.0_DP

    IF(ASSOCIATED(equationsSet)) THEN
      IF(ASSOCIATED(equationsSet%ANALYTIC)) THEN
        dependentField=>equationsSet%DEPENDENT%DEPENDENT_FIELD
        IF(ASSOCIATED(dependentField)) THEN
          geometricField=>equationsSet%GEOMETRY%GEOMETRIC_FIELD
          IF(ASSOCIATED(geometricField)) THEN     
            ! Geometric parameters
            CALL FIELD_NUMBER_OF_COMPONENTS_GET(geometricField,FIELD_U_VARIABLE_TYPE,numberOfDimensions,err,error,*999)
            NULLIFY(geometricVariable)
            CALL FIELD_VARIABLE_GET(geometricField,FIELD_U_VARIABLE_TYPE,geometricVariable,err,error,*999)
            NULLIFY(geometricParameters)
            CALL FIELD_PARAMETER_SET_DATA_GET(geometricField,FIELD_U_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE,geometricParameters, &
              & err,error,*999)
            ! Analytic parameters
            analyticFunctionType=equationsSet%ANALYTIC%ANALYTIC_FUNCTION_TYPE
            analyticField=>equationsSet%ANALYTIC%ANALYTIC_FIELD
            NULLIFY(analyticVariable)
            NULLIFY(analyticParameters)
            IF(ASSOCIATED(analyticField)) THEN
              CALL FIELD_VARIABLE_GET(analyticField,FIELD_U_VARIABLE_TYPE,analyticVariable,err,error,*999)
              CALL FIELD_PARAMETER_SET_DATA_GET(analyticField,FIELD_U_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE, &
                & analyticParameters,err,error,*999)           
            END IF
            ! Materials parameters
            NULLIFY(materialsField)
            NULLIFY(materialsVariable)
            NULLIFY(materialsParameters)
            IF(ASSOCIATED(equationsSet%MATERIALS)) THEN
              materialsField=>equationsSet%MATERIALS%MATERIALS_FIELD
              CALL FIELD_VARIABLE_GET(materialsField,FIELD_U_VARIABLE_TYPE,materialsVariable,err,error,*999)
              CALL FIELD_PARAMETER_SET_DATA_GET(materialsField,FIELD_U_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE, &
                & materialsParameters,err,error,*999)           
            END IF
            TIME=equationsSet%ANALYTIC%ANALYTIC_TIME
            ! Interpolation parameters
            NULLIFY(interpolationParameters)
            CALL FIELD_INTERPOLATION_PARAMETERS_INITIALISE(geometricField,interpolationParameters,err,error,*999)
            NULLIFY(interpolatedPoint) 
            CALL FIELD_INTERPOLATED_POINTS_INITIALISE(interpolationParameters,interpolatedPoint,err,error,*999)
            CALL FIELD_NUMBER_OF_COMPONENTS_GET(geometricField,FIELD_U_VARIABLE_TYPE,numberOfDimensions,err,error,*999)
          ELSE
            CALL FlagError("Equations set geometric field is not associated.",err,error,*999)
          END IF
        ELSE
          CALL FlagError("Equations set dependent field is not associated.",err,error,*999)
        END IF
      ELSE
        CALL FlagError("Equations set analytic is not associated.",err,error,*999)
      END IF
    ELSE
      CALL FlagError("Equations set is not associated.",err,error,*999)
    END IF

    IF(ASSOCIATED(boundaryConditions)) THEN
      DO variableIdx=1,dependentField%NUMBER_OF_VARIABLES
        variableType=dependentField%VARIABLES(variableIdx)%VARIABLE_TYPE
        fieldVariable=>dependentField%VARIABLE_TYPE_MAP(variableType)%PTR
        IF(ASSOCIATED(fieldVariable)) THEN
          IF(.NOT.ASSOCIATED(fieldVariable%PARAMETER_SETS%SET_TYPE(FIELD_ANALYTIC_VALUES_SET_TYPE)%PTR)) &
            & CALL FIELD_PARAMETER_SET_CREATE(dependentField,variableType,FIELD_ANALYTIC_VALUES_SET_TYPE,err,error,*999)
          DO componentIdx=1,fieldVariable%NUMBER_OF_COMPONENTS
            boundaryCount=0
            IF(fieldVariable%COMPONENTS(componentIdx)%INTERPOLATION_TYPE==FIELD_NODE_BASED_INTERPOLATION) THEN
              domain=>fieldVariable%COMPONENTS(componentIdx)%DOMAIN
              IF(ASSOCIATED(domain)) THEN
                IF(ASSOCIATED(domain%TOPOLOGY)) THEN
                  domainNodes=>domain%TOPOLOGY%NODES
                  IF(ASSOCIATED(domainNodes)) THEN
                    !Loop over the local nodes excluding the ghosts.
                    DO nodeIdx=1,domainNodes%NUMBER_OF_NODES
                      nodeNumber = domainNodes%NODES(nodeIdx)%local_number
                      userNodeNumber = domainNodes%NODES(nodeIdx)%user_number
                      elementIdx=domain%topology%nodes%nodes(nodeNumber)%surrounding_elements(1)
                      CALL FIELD_INTERPOLATION_PARAMETERS_ELEMENT_GET(FIELD_VALUES_SET_TYPE,elementIdx, &
                        & interpolationParameters(FIELD_U_VARIABLE_TYPE)%PTR,err,error,*999)
                      en_idx=0
                      xiCoordinates=0.0_DP
                      numberOfXi=domain%topology%elements%elements(elementIdx)%basis%number_of_xi
                      numberOfNodesXiCoord(1)=domain%topology%elements%elements(elementIdx)%basis%number_of_nodes_xic(1)
                      IF(numberOfXi>1) THEN
                        numberOfNodesXiCoord(2)=domain%topology%elements%elements(elementIdx)%basis%number_of_nodes_xic(2)
                      ELSE
                        numberOfNodesXiCoord(2)=1
                      END IF
                      IF(numberOfXi>2) THEN
                        numberOfNodesXiCoord(3)=domain%topology%elements%elements(elementIdx)%basis%number_of_nodes_xic(3)
                      ELSE
                        numberOfNodesXiCoord(3)=1
                      END IF

                      SELECT CASE(analyticFunctionType)
                      ! --- Calculate analytic profile for validation ---
                      CASE(EQUATIONS_SET_NAVIER_STOKES_EQUATION_TWO_DIM_POISEUILLE)
                        IF(variableIdx < 3) THEN
                          ! Get geometric position info for this node
                          DO dimensionIdx=1,numberOfDimensions
                            local_ny=geometricVariable%COMPONENTS(dimensionIdx)%PARAM_TO_DOF_MAP%NODE_PARAM2DOF_MAP% &
                              & NODES(nodeIdx)%DERIVATIVES(1)%VERSIONS(1)
                            X(dimensionIdx)=geometricParameters(local_ny)
                          END DO !dimensionIdx
                          DO derivativeIdx=1,domainNodes%NODES(nodeNumber)%NUMBER_OF_DERIVATIVES
                            globalDerivativeIndex=domainNodes%NODES(nodeNumber)%DERIVATIVES(derivativeIdx)% &
                              & GLOBAL_DERIVATIVE_INDEX
                            DO versionIdx=1,domainNodes%NODES(nodeNumber)%DERIVATIVES(derivativeIdx)%numberOfVersions
                              CALL NAVIER_STOKES_ANALYTIC_FUNCTIONS_EVALUATE(analyticFunctionType,X,TIME,variableType, &
                                & globalDerivativeIndex,componentIdx,numberOfDimensions,fieldVariable%NUMBER_OF_COMPONENTS, &
                                & analyticParameters,materialsParameters,VALUE,err,error,*999)
                              local_ny=fieldVariable%COMPONENTS(componentIdx)%PARAM_TO_DOF_MAP% &
                                & NODE_PARAM2DOF_MAP%NODES(nodeIdx)%DERIVATIVES(derivativeIdx)%VERSIONS(versionIdx)
                              CALL FIELD_PARAMETER_SET_UPDATE_LOCAL_DOF(dependentField,variableType, &
                                & FIELD_ANALYTIC_VALUES_SET_TYPE,local_ny,VALUE,err,error,*999)
                            END DO !versionIdx
                          END DO !derivativeIdx
                        END IF ! variableIdx < 3

                      ! --- Set velocity boundary conditions with analytic value ---
                      CASE(EQUATIONS_SET_NAVIER_STOKES_EQUATION_TWO_DIM_TAYLOR_GREEN, &
                         & EQUATIONS_SET_NAVIER_STOKES_EQUATION_SINUSOID)
                        ! Get geometric position info for this node
                        DO dimensionIdx=1,numberOfDimensions
                          local_ny=geometricVariable%COMPONENTS(dimensionIdx)%PARAM_TO_DOF_MAP%NODE_PARAM2DOF_MAP% &
                            & NODES(nodeNumber)%DERIVATIVES(1)%VERSIONS(1)
                          X(dimensionIdx)=geometricParameters(local_ny)
                        END DO !dimensionIdx
                        !Loop over the derivatives
                        DO derivativeIdx=1,domainNodes%NODES(nodeNumber)%NUMBER_OF_DERIVATIVES
                          globalDerivativeIndex=domainNodes%NODES(nodeNumber)%DERIVATIVES(derivativeIdx)% &
                            & GLOBAL_DERIVATIVE_INDEX
                          IF(componentIdx<=numberOfXi .OR. &
                            &  analyticFunctionType==EQUATIONS_SET_NAVIER_STOKES_EQUATION_SINUSOID) THEN
                            DO versionIdx=1,domainNodes%NODES(nodeNumber)%DERIVATIVES(derivativeIdx)%numberOfVersions
                              ! Get global and local dof indices
                              CALL FIELD_COMPONENT_DOF_GET_USER_NODE(dependentField,variableType,versionIdx,derivativeIdx, &
                               & userNodeNumber,componentIdx,localDof,globalDof,err,error,*999)
                              IF(analyticFunctionType==EQUATIONS_SET_NAVIER_STOKES_EQUATION_SINUSOID) THEN
                                CALL FIELD_NUMBER_OF_COMPONENTS_GET(analyticField,FIELD_U_VARIABLE_TYPE, &
                                 & numberOfParameters,err,error,*999)
                                DO parameterIdx=1,numberOfParameters
                                  ! populate nodeAnalyticParameters
                                  CALL Field_ParameterSetGetLocalNode(analyticField,FIELD_U_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE, & 
                                   & versionIdx,derivativeIdx,nodeIdx,parameterIdx,nodeAnalyticParameters(parameterIdx), &
                                   & err,error,*999)
                                END DO
                                CALL NAVIER_STOKES_ANALYTIC_FUNCTIONS_EVALUATE(analyticFunctionType,X,TIME,variableType, &
                                  & globalDerivativeIndex,componentIdx,numberOfDimensions,fieldVariable%NUMBER_OF_COMPONENTS, &
                                  & nodeAnalyticParameters,materialsParameters,VALUE,err,error,*999)
                              ELSE
                                CALL NAVIER_STOKES_ANALYTIC_FUNCTIONS_EVALUATE(analyticFunctionType,X,TIME,variableType, &
                                  & globalDerivativeIndex,componentIdx,numberOfDimensions,fieldVariable%NUMBER_OF_COMPONENTS, &
                                  & analyticParameters,materialsParameters,VALUE,err,error,*999)
                              END IF
                              ! update analytic field values
                              CALL FIELD_PARAMETER_SET_UPDATE_LOCAL_DOF(dependentField,variableType, &
                                & FIELD_ANALYTIC_VALUES_SET_TYPE,localDof,VALUE,err,error,*999)
                              IF(variableType==FIELD_U_VARIABLE_TYPE) THEN
                                IF(domainNodes%NODES(nodeNumber)%BOUNDARY_NODE) THEN
                                  CALL BOUNDARY_CONDITIONS_VARIABLE_GET(boundaryConditions,fieldVariable, &
                                   & boundaryConditionsVariable,err,error,*999)
                                  IF(ASSOCIATED(boundaryConditionsVariable)) THEN
                                    boundaryConditionsCheckVariable=boundaryConditionsVariable% &
                                     & CONDITION_TYPES(globalDof)
                                    ! update dependent field values if fixed inlet or pressure BC
                                    IF(boundaryConditionsCheckVariable==BOUNDARY_CONDITION_FIXED_INLET) THEN
                                      ! Set velocity/flowrate values
                                      CALL FIELD_PARAMETER_SET_UPDATE_LOCAL_DOF(dependentField,variableType, &
                                       & FIELD_VALUES_SET_TYPE,localDof,VALUE,err,error,*999)
                                    ELSE IF(boundaryConditionsCheckVariable==BOUNDARY_CONDITION_PRESSURE) THEN
                                      ! Set neumann boundary pressure value on pressure nodes
                                      CALL FIELD_PARAMETER_SET_UPDATE_LOCAL_NODE(dependentField,FIELD_U_VARIABLE_TYPE, &
                                       & FIELD_PRESSURE_VALUES_SET_TYPE,1,1,nodeIdx,componentIdx,VALUE,err,error,*999)
                                    END IF
                                  END IF
                                END IF
                              END IF
                            END DO !versionIdx
                          END IF
                        END DO !derivativeIdx

                      ! --- Set Flow rate boundary conditions with analytic value ---
                      CASE(EQUATIONS_SET_NAVIER_STOKES_EQUATION_FLOWRATE_AORTA, &
                         & EQUATIONS_SET_NAVIER_STOKES_EQUATION_FLOWRATE_OLUFSEN)
                        ! Get geometric position info for this node
                        DO dimensionIdx=1,numberOfDimensions
                          local_ny=geometricVariable%COMPONENTS(dimensionIdx)%PARAM_TO_DOF_MAP%NODE_PARAM2DOF_MAP% &
                            & NODES(nodeIdx)%DERIVATIVES(1)%VERSIONS(1)
                          X(dimensionIdx)=geometricParameters(local_ny)
                        END DO !dimensionIdx
                        !Loop over the derivatives
                        DO derivativeIdx=1,domainNodes%NODES(nodeIdx)%NUMBER_OF_DERIVATIVES
                          globalDerivativeIndex=domainNodes%NODES(nodeIdx)%DERIVATIVES(derivativeIdx)% &
                            & GLOBAL_DERIVATIVE_INDEX
                          IF(componentIdx==1 .AND. variableType==FIELD_U_VARIABLE_TYPE) THEN
                            DO versionIdx=1,domainNodes%NODES(nodeIdx)%DERIVATIVES(derivativeIdx)%numberOfVersions
                              local_ny=fieldVariable%COMPONENTS(componentIdx)%PARAM_TO_DOF_MAP% &
                                & NODE_PARAM2DOF_MAP%NODES(nodeIdx)%DERIVATIVES(derivativeIdx)%VERSIONS(versionIdx)
                              IF(domainNodes%NODES(nodeIdx)%BOUNDARY_NODE) THEN
                                CALL BOUNDARY_CONDITIONS_VARIABLE_GET(boundaryConditions,fieldVariable, &
                                 & boundaryConditionsVariable,err,error,*999)
                                IF(ASSOCIATED(boundaryConditionsVariable)) THEN
                                  boundaryConditionsCheckVariable=boundaryConditionsVariable%CONDITION_TYPES(local_ny)
                                  IF(boundaryConditionsCheckVariable==BOUNDARY_CONDITION_FIXED_INLET) THEN
                                    CALL NAVIER_STOKES_ANALYTIC_FUNCTIONS_EVALUATE(analyticFunctionType,X,TIME,variableType, &
                                      & globalDerivativeIndex,componentIdx,numberOfXi,fieldVariable%NUMBER_OF_COMPONENTS, &
                                      & analyticParameters,materialsParameters,VALUE,err,error,*999)
                                    !If we are a boundary node then set the analytic value on the boundary
                                    CALL FIELD_PARAMETER_SET_UPDATE_LOCAL_DOF(dependentField,variableType, &
                                      & FIELD_VALUES_SET_TYPE,local_ny,VALUE,err,error,*999)
                                  ELSE
                                    CALL Field_ParameterSetGetLocalNode(dependentField,variableType,FIELD_VALUES_SET_TYPE, & 
                                      & versionIdx,derivativeIdx,nodeIdx,componentIdx,VALUE,err,error,*999)
                                    CALL FIELD_PARAMETER_SET_UPDATE_LOCAL_DOF(dependentField,variableType, &
                                      & FIELD_ANALYTIC_VALUES_SET_TYPE,local_ny,VALUE,ERR,ERROR,*999)
                                  END IF
                                END IF
                              END IF
                            END DO !versionIdx
                          END IF
                        END DO !derivativeIdx

                      ! --- Legacy unit shape testing types ---
                      CASE(EQUATIONS_SET_NAVIER_STOKES_EQUATION_ONE_DIM_1,  &
                       & EQUATIONS_SET_NAVIER_STOKES_EQUATION_TWO_DIM_1,  &
                       & EQUATIONS_SET_NAVIER_STOKES_EQUATION_TWO_DIM_2,  &
                       & EQUATIONS_SET_NAVIER_STOKES_EQUATION_TWO_DIM_3,  &
                       & EQUATIONS_SET_NAVIER_STOKES_EQUATION_TWO_DIM_4,  &
                       & EQUATIONS_SET_NAVIER_STOKES_EQUATION_TWO_DIM_5,  &
                       & EQUATIONS_SET_NAVIER_STOKES_EQUATION_THREE_DIM_1,  &
                       & EQUATIONS_SET_NAVIER_STOKES_EQUATION_THREE_DIM_2,  &
                       & EQUATIONS_SET_NAVIER_STOKES_EQUATION_THREE_DIM_3,  &
                       & EQUATIONS_SET_NAVIER_STOKES_EQUATION_THREE_DIM_4,  &
                       & EQUATIONS_SET_NAVIER_STOKES_EQUATION_THREE_DIM_5)
                        !Quad/Hex
                        !\todo: Use boundary flag
                        IF(domain%topology%elements%maximum_number_of_element_parameters==4.AND.numberOfDimensions==2.OR. &
                          & domain%topology%elements%maximum_number_of_element_parameters==9.OR. &
                          & domain%topology%elements%maximum_number_of_element_parameters==16.OR. &
                          & domain%topology%elements%maximum_number_of_element_parameters==8.OR. &
                          & domain%topology%elements%maximum_number_of_element_parameters==27.OR. &
                          & domain%topology%elements%maximum_number_of_element_parameters==64) THEN
                          DO K=1,numberOfNodesXiCoord(3)
                            DO J=1,numberOfNodesXiCoord(2)
                              DO I=1,numberOfNodesXiCoord(1)
                                en_idx=en_idx+1
                                IF(domain%topology%elements%elements(elementIdx)%element_nodes(en_idx)==nodeIdx) EXIT
                                xiCoordinates(1)=xiCoordinates(1)+(1.0_DP/(numberOfNodesXiCoord(1)-1))
                              END DO
                                IF(domain%topology%elements%elements(elementIdx)%element_nodes(en_idx)==nodeIdx) EXIT
                                xiCoordinates(1)=0.0_DP
                                xiCoordinates(2)=xiCoordinates(2)+(1.0_DP/(numberOfNodesXiCoord(2)-1))
                            END DO
                            IF(domain%topology%elements%elements(elementIdx)%element_nodes(en_idx)==nodeIdx) EXIT
                            xiCoordinates(1)=0.0_DP
                            xiCoordinates(2)=0.0_DP
                            IF(numberOfNodesXiCoord(3)/=1) THEN
                              xiCoordinates(3)=xiCoordinates(3)+(1.0_DP/(numberOfNodesXiCoord(3)-1))
                            END IF
                          END DO
                          CALL FIELD_INTERPOLATE_XI(NO_PART_DERIV,xiCoordinates, &
                            & interpolatedPoint(FIELD_U_VARIABLE_TYPE)%PTR,err,error,*999)
                        !Tri/Tet
                        !\todo: Use boundary flag
                        ELSE
                          IF(domain%topology%elements%maximum_number_of_element_parameters==3) THEN
                            T_COORDINATES(1,1:2)=[0.0_DP,1.0_DP]
                            T_COORDINATES(2,1:2)=[1.0_DP,0.0_DP]
                            T_COORDINATES(3,1:2)=[1.0_DP,1.0_DP]
                          ELSE IF(domain%topology%elements%maximum_number_of_element_parameters==6) THEN
                            T_COORDINATES(1,1:2)=[0.0_DP,1.0_DP]
                            T_COORDINATES(2,1:2)=[1.0_DP,0.0_DP]
                            T_COORDINATES(3,1:2)=[1.0_DP,1.0_DP]
                            T_COORDINATES(4,1:2)=[0.5_DP,0.5_DP]
                            T_COORDINATES(5,1:2)=[1.0_DP,0.5_DP]
                            T_COORDINATES(6,1:2)=[0.5_DP,1.0_DP]
                          ELSE IF(domain%topology%elements%maximum_number_of_element_parameters==10.AND. &
                            & numberOfDimensions==2) THEN
                            T_COORDINATES(1,1:2)=[0.0_DP,1.0_DP]
                            T_COORDINATES(2,1:2)=[1.0_DP,0.0_DP]
                            T_COORDINATES(3,1:2)=[1.0_DP,1.0_DP]
                            T_COORDINATES(4,1:2)=[1.0_DP/3.0_DP,2.0_DP/3.0_DP]
                            T_COORDINATES(5,1:2)=[2.0_DP/3.0_DP,1.0_DP/3.0_DP]
                            T_COORDINATES(6,1:2)=[1.0_DP,1.0_DP/3.0_DP]
                            T_COORDINATES(7,1:2)=[1.0_DP,2.0_DP/3.0_DP]
                            T_COORDINATES(8,1:2)=[2.0_DP/3.0_DP,1.0_DP]
                            T_COORDINATES(9,1:2)=[1.0_DP/3.0_DP,1.0_DP]
                            T_COORDINATES(10,1:2)=[2.0_DP/3.0_DP,2.0_DP/3.0_DP]
                          ELSE IF(domain%topology%elements%maximum_number_of_element_parameters==4) THEN
                            T_COORDINATES(1,1:3)=[0.0_DP,1.0_DP,1.0_DP]
                            T_COORDINATES(2,1:3)=[1.0_DP,0.0_DP,1.0_DP]
                            T_COORDINATES(3,1:3)=[1.0_DP,1.0_DP,0.0_DP]
                            T_COORDINATES(4,1:3)=[1.0_DP,1.0_DP,1.0_DP]
                          ELSE IF(domain%topology%elements%maximum_number_of_element_parameters==10.AND. &
                            & numberOfDimensions==3) THEN
                            T_COORDINATES(1,1:3)=[0.0_DP,1.0_DP,1.0_DP]
                            T_COORDINATES(2,1:3)=[1.0_DP,0.0_DP,1.0_DP]
                            T_COORDINATES(3,1:3)=[1.0_DP,1.0_DP,0.0_DP]
                            T_COORDINATES(4,1:3)=[1.0_DP,1.0_DP,1.0_DP]
                            T_COORDINATES(5,1:3)=[0.5_DP,0.5_DP,1.0_DP]
                            T_COORDINATES(6,1:3)=[0.5_DP,1.0_DP,0.5_DP]
                            T_COORDINATES(7,1:3)=[0.5_DP,1.0_DP,1.0_DP]
                            T_COORDINATES(8,1:3)=[1.0_DP,0.5_DP,0.5_DP]
                            T_COORDINATES(9,1:3)=[1.0_DP,1.0_DP,0.5_DP]
                            T_COORDINATES(10,1:3)=[1.0_DP,0.5_DP,1.0_DP]
                          ELSE IF(domain%topology%elements%maximum_number_of_element_parameters==20) THEN
                            T_COORDINATES(1,1:3)=[0.0_DP,1.0_DP,1.0_DP]
                            T_COORDINATES(2,1:3)=[1.0_DP,0.0_DP,1.0_DP]
                            T_COORDINATES(3,1:3)=[1.0_DP,1.0_DP,0.0_DP]
                            T_COORDINATES(4,1:3)=[1.0_DP,1.0_DP,1.0_DP]
                            T_COORDINATES(5,1:3)=[1.0_DP/3.0_DP,2.0_DP/3.0_DP,1.0_DP]
                            T_COORDINATES(6,1:3)=[2.0_DP/3.0_DP,1.0_DP/3.0_DP,1.0_DP]
                            T_COORDINATES(7,1:3)=[1.0_DP/3.0_DP,1.0_DP,2.0_DP/3.0_DP]
                            T_COORDINATES(8,1:3)=[2.0_DP/3.0_DP,1.0_DP,1.0_DP/3.0_DP]
                            T_COORDINATES(9,1:3)=[1.0_DP/3.0_DP,1.0_DP,1.0_DP]
                            T_COORDINATES(10,1:3)=[2.0_DP/3.0_DP,1.0_DP,1.0_DP]
                            T_COORDINATES(11,1:3)=[1.0_DP,1.0_DP/3.0_DP,2.0_DP/3.0_DP]
                            T_COORDINATES(12,1:3)=[1.0_DP,2.0_DP/3.0_DP,1.0_DP/3.0_DP]
                            T_COORDINATES(13,1:3)=[1.0_DP,1.0_DP,1.0_DP/3.0_DP]
                            T_COORDINATES(14,1:3)=[1.0_DP,1.0_DP,2.0_DP/3.0_DP]
                            T_COORDINATES(15,1:3)=[1.0_DP,1.0_DP/3.0_DP,1.0_DP]
                            T_COORDINATES(16,1:3)=[1.0_DP,2.0_DP/3.0_DP,1.0_DP]
                            T_COORDINATES(17,1:3)=[2.0_DP/3.0_DP,2.0_DP/3.0_DP,2.0_DP/3.0_DP]
                            T_COORDINATES(18,1:3)=[2.0_DP/3.0_DP,2.0_DP/3.0_DP,1.0_DP]
                            T_COORDINATES(19,1:3)=[2.0_DP/3.0_DP,1.0_DP,2.0_DP/3.0_DP]
                            T_COORDINATES(20,1:3)=[1.0_DP,2.0_DP/3.0_DP,2.0_DP/3.0_DP]
                          END IF
                          DO K=1,domain%topology%elements%maximum_number_of_element_parameters
                            IF(domain%topology%elements%elements(elementIdx)%element_nodes(K)==nodeIdx) EXIT
                          END DO
                          IF(numberOfDimensions==2) THEN
                            CALL FIELD_INTERPOLATE_XI(NO_PART_DERIV,T_COORDINATES(K,1:2), &
                              & interpolatedPoint(FIELD_U_VARIABLE_TYPE)%PTR,err,error,*999)
                          ELSE IF(numberOfDimensions==3) THEN
                            CALL FIELD_INTERPOLATE_XI(NO_PART_DERIV,T_COORDINATES(K,1:3), &
                              & interpolatedPoint(FIELD_U_VARIABLE_TYPE)%PTR,err,error,*999)
                          END IF
                        END IF
                        X=0.0_DP
                        DO dimensionIdx=1,numberOfDimensions
                          X(dimensionIdx)=interpolatedPoint(FIELD_U_VARIABLE_TYPE)%PTR%VALUES(dimensionIdx,1)
                        END DO !dimensionIdx
                        !Loop over the derivatives
                        DO derivativeIdx=1,domainNodes%NODES(nodeIdx)%NUMBER_OF_DERIVATIVES
                          globalDerivativeIndex=domainNodes%NODES(nodeIdx)%DERIVATIVES(derivativeIdx)% &
                            & GLOBAL_DERIVATIVE_INDEX
                          CALL NAVIER_STOKES_ANALYTIC_FUNCTIONS_EVALUATE(analyticFunctionType,X,TIME,variableType, &
                            & globalDerivativeIndex,componentIdx,numberOfDimensions,fieldVariable%NUMBER_OF_COMPONENTS, &
                            & analyticParameters,materialsParameters,VALUE,err,error,*999)
                          DO versionIdx=1,domainNodes%NODES(nodeIdx)%DERIVATIVES(derivativeIdx)%numberOfVersions
                            local_ny=fieldVariable%COMPONENTS(componentIdx)%PARAM_TO_DOF_MAP% &
                              & NODE_PARAM2DOF_MAP%NODES(nodeIdx)%DERIVATIVES(derivativeIdx)%VERSIONS(versionIdx)
                            CALL FIELD_PARAMETER_SET_UPDATE_LOCAL_DOF(dependentField,variableType, &
                              & FIELD_ANALYTIC_VALUES_SET_TYPE,local_ny,VALUE,err,error,*999)
                            IF(variableType==FIELD_U_VARIABLE_TYPE) THEN
                              IF(domainNodes%NODES(nodeIdx)%BOUNDARY_NODE) THEN
                                !If we are a boundary node then set the analytic value on the boundary
                                CALL BOUNDARY_CONDITIONS_SET_LOCAL_DOF(boundaryConditions,dependentField,variableType, &
                                  & local_ny,BOUNDARY_CONDITION_FIXED,VALUE,err,error,*999)
                                ! \todo: This is just a workaround for linear pressure fields in simplex element components
                                IF(componentIdx>numberOfDimensions) THEN
                                  IF(domain%topology%elements%maximum_number_of_element_parameters==3) THEN
                                    IF(analyticFunctionType==EQUATIONS_SET_STOKES_EQUATION_TWO_DIM_1.OR. &
                                      & analyticFunctionType==EQUATIONS_SET_STOKES_EQUATION_TWO_DIM_2.OR. &
                                      & analyticFunctionType==EQUATIONS_SET_STOKES_EQUATION_TWO_DIM_3.OR. &
                                      & analyticFunctionType==EQUATIONS_SET_STOKES_EQUATION_TWO_DIM_4.OR. &
                                      & analyticFunctionType==EQUATIONS_SET_STOKES_EQUATION_TWO_DIM_5) THEN
                                      IF(-0.001_DP<X(1).AND.X(1)<0.001_DP.AND.-0.001_DP<X(2).AND.X(2)<0.001_DP.OR. &
                                        &  10.0_DP-0.001_DP<X(1).AND.X(1)<10.0_DP+0.001_DP.AND.-0.001_DP<X(2).AND. &
                                        & X(2)<0.001_DP.OR. &
                                        &  10.0_DP-0.001_DP<X(1).AND.X(1)<10.0_DP+0.001_DP.AND.10.0_DP-0.001_DP<X(2).AND. &
                                        & X(2)<10.0_DP+0.001_DP.OR. &
                                        &  -0.001_DP<X(1).AND.X(1)<0.001_DP.AND.10.0_DP-0.001_DP<X(2).AND. &
                                        & X(2)<10.0_DP+0.001_DP) THEN
                                          CALL BOUNDARY_CONDITIONS_SET_LOCAL_DOF(boundaryConditions,dependentField, &
                                            & variableType,local_ny,BOUNDARY_CONDITION_FIXED,VALUE,err,error,*999)
                                          boundaryCount=boundaryCount+1
                                      END IF
                                    END IF
                                  ELSE IF(domain%topology%elements%maximum_number_of_element_parameters==4.AND. &
                                    & numberOfDimensions==3) THEN
                                    IF(analyticFunctionType==EQUATIONS_SET_STOKES_EQUATION_THREE_DIM_1.OR. &
                                      & analyticFunctionType==EQUATIONS_SET_STOKES_EQUATION_THREE_DIM_2.OR. &
                                      & analyticFunctionType==EQUATIONS_SET_STOKES_EQUATION_THREE_DIM_3.OR. &
                                      & analyticFunctionType==EQUATIONS_SET_STOKES_EQUATION_THREE_DIM_4.OR. &
                                      & analyticFunctionType==EQUATIONS_SET_STOKES_EQUATION_THREE_DIM_5) THEN
                                      IF(-5.0_DP-0.001_DP<X(1).AND.X(1)<-5.0_DP+0.001_DP.AND.-5.0_DP-0.001_DP<X(2).AND. &
                                        & X(2)<-5.0_DP+0.001_DP.AND.-5.0_DP-0.001_DP<X(3).AND.X(3)<-5.0_DP+0.001_DP.OR. &
                                        & -5.0_DP-0.001_DP<X(1).AND.X(1)<-5.0_DP+0.001_DP.AND.5.0_DP-0.001_DP<X(2).AND. &
                                        & X(2)<5.0_DP+0.001_DP.AND.-5.0_DP-0.001_DP<X(3).AND.X(3)<-5.0_DP+0.001_DP.OR. &
                                        & 5.0_DP-0.001_DP<X(1).AND.X(1)<5.0_DP+0.001_DP.AND.5.0_DP-0.001_DP<X(2).AND. &
                                        & X(2)<5.0_DP+0.001_DP.AND.-5.0_DP-0.001_DP<X(3).AND.X(3)<-5.0_DP+0.001_DP.OR. &
                                        & 5.0_DP-0.001_DP<X(1).AND.X(1)<5.0_DP+0.001_DP.AND.-5.0_DP-0.001_DP<X(2).AND. &
                                        & X(2)<-5.0_DP+0.001_DP.AND.-5.0_DP-0.001_DP<X(3).AND.X(3)<-5.0_DP+0.001_DP.OR. &
                                        & -5.0_DP-0.001_DP<X(1).AND.X(1)<-5.0_DP+0.001_DP.AND.-5.0_DP-0.001_DP<X(2).AND. &
                                        & X(2)<-5.0_DP+0.001_DP.AND.5.0_DP-0.001_DP<X(3).AND.X(3)<5.0_DP+0.001_DP.OR. &
                                        & -5.0_DP-0.001_DP<X(1).AND.X(1)<-5.0_DP+0.001_DP.AND.5.0_DP-0.001_DP<X(2).AND. &
                                        & X(2)<5.0_DP+0.001_DP.AND.5.0_DP-0.001_DP<X(3).AND.X(3)<5.0_DP+0.001_DP.OR. &
                                        & 5.0_DP-0.001_DP<X(1).AND.X(1)<5.0_DP+0.001_DP.AND.5.0_DP-0.001_DP<X(2).AND. &
                                        & X(2)<5.0_DP+0.001_DP.AND.5.0_DP-0.001_DP<X(3).AND.X(3)<5.0_DP+0.001_DP.OR. &
                                        & 5.0_DP-0.001_DP<X(1).AND.X(1)<5.0_DP+0.001_DP.AND.-5.0_DP-0.001_DP<X(2).AND. &
                                        & X(2)<-5.0_DP+ 0.001_DP.AND.5.0_DP-0.001_DP<X(3).AND.X(3)<5.0_DP+0.001_DP) THEN
                                        CALL BOUNDARY_CONDITIONS_SET_LOCAL_DOF(boundaryConditions,dependentField, &
                                          & variableType,local_ny,BOUNDARY_CONDITION_FIXED,VALUE,err,error,*999)
                                        boundaryCount=boundaryCount+1
                                      END IF
                                    END IF
                                    ! \todo: This is how it should be if adjacent elements would be working
                                  ELSE IF(boundaryCount==0) THEN
                                    CALL BOUNDARY_CONDITIONS_SET_LOCAL_DOF(boundaryConditions,dependentField,variableType,&
                                      & local_ny,BOUNDARY_CONDITION_FIXED,VALUE,err,error,*999)
                                    boundaryCount=boundaryCount+1
                                  END IF
                                END IF
                              ELSE
                                !Set the initial condition.
                                CALL FIELD_PARAMETER_SET_UPDATE_LOCAL_DOF(dependentField,variableType, &
                                  & FIELD_VALUES_SET_TYPE,local_ny,initialValue,err,error,*999)
                              END IF
                            END IF
                          END DO !versionIdx
                        END DO !derivativeIdx

                      CASE DEFAULT
                        localError="Analytic Function Type "//TRIM(NUMBER_TO_VSTRING(analyticFunctionType,"*",ERR,ERROR))// &
                          & " is not yet implemented for a Navier-Stokes problem."
                        CALL FlagError(localError,ERR,ERROR,*999)
                      END SELECT

                    END DO !nodeIdx
                  ELSE
                    CALL FlagError("Domain topology nodes is not associated.",err,error,*999)
                  END IF
                ELSE
                  CALL FlagError("Domain topology is not associated.",err,error,*999)
                END IF
              ELSE
                CALL FlagError("Domain is not associated.",err,error,*999)
              END IF
            ELSE
              CALL FlagError("Only node based interpolation is implemented.",err,error,*999)
            END IF
          END DO !componentIdx
          CALL FIELD_PARAMETER_SET_UPDATE_START(dependentField,variableType,FIELD_ANALYTIC_VALUES_SET_TYPE, &
            & err,error,*999)
          CALL FIELD_PARAMETER_SET_UPDATE_FINISH(dependentField,variableType,FIELD_ANALYTIC_VALUES_SET_TYPE, &
            & err,error,*999)
          CALL FIELD_PARAMETER_SET_UPDATE_START(dependentField,variableType,FIELD_VALUES_SET_TYPE, &
            & err,error,*999)
          CALL FIELD_PARAMETER_SET_UPDATE_FINISH(dependentField,variableType,FIELD_VALUES_SET_TYPE, &
            & err,error,*999)
        ELSE
          CALL FlagError("Field variable is not associated.",err,error,*999)
        END IF
      END DO !variableIdx
      CALL FIELD_PARAMETER_SET_DATA_RESTORE(geometricField,FIELD_U_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE, &
        & geometricParameters,err,error,*999)
      CALL FIELD_INTERPOLATED_POINTS_FINALISE(interpolatedPoint,err,error,*999)
      CALL FIELD_INTERPOLATION_PARAMETERS_FINALISE(interpolationParameters,err,error,*999)
    ELSE
      CALL FlagError("Boundary conditions is not associated.",err,error,*999)
    END IF

    EXITS("NavierStokes_BoundaryConditionsAnalyticCalculate")
    RETURN
999 ERRORS("NavierStokes_BoundaryConditionsAnalyticCalculate",err,error)
    EXITS("NavierStokes_BoundaryConditionsAnalyticCalculate")
    RETURN 1
    
  END SUBROUTINE NavierStokes_BoundaryConditionsAnalyticCalculate

  !
  !================================================================================================================================
  !
  !>Calculates the various analytic values for NSE examples with exact solutions
  SUBROUTINE NAVIER_STOKES_ANALYTIC_FUNCTIONS_EVALUATE(ANALYTIC_FUNCTION_TYPE,X,TIME,VARIABLE_TYPE,GLOBAL_DERIV_INDEX, &
    & componentNumber,NUMBER_OF_DIMENSIONS,NUMBER_OF_COMPONENTS,ANALYTIC_PARAMETERS,MATERIALS_PARAMETERS,VALUE,ERR,ERROR,*)

    !Argument variables
    INTEGER(INTG), INTENT(IN) :: ANALYTIC_FUNCTION_TYPE !<The type of analytic function to evaluate
    REAL(DP), INTENT(IN) :: X(:) !<X(dimension_idx). The geometric position to evaluate at (includes Y,Z for higher dim problems)
    REAL(DP), INTENT(IN) :: TIME !<The time to evaluate at
    INTEGER(INTG), INTENT(IN) :: VARIABLE_TYPE !<The field variable type to evaluate at
    INTEGER(INTG), INTENT(IN) :: GLOBAL_DERIV_INDEX !<The global derivative to evaluate at
    INTEGER(INTG), INTENT(IN) :: componentNumber !<The dependent field component number to evaluate
    INTEGER(INTG), INTENT(IN) :: NUMBER_OF_DIMENSIONS !<The number of geometric dimensions
    INTEGER(INTG), INTENT(IN) :: NUMBER_OF_COMPONENTS !<The number of components for the dependent field
    REAL(DP), INTENT(IN) :: ANALYTIC_PARAMETERS(:) !<A pointer to any analytic field parameters
    REAL(DP), INTENT(IN) :: MATERIALS_PARAMETERS(:) !<A pointer to any materials field parameters
    REAL(DP), INTENT(OUT) :: VALUE !<On return, the analytic function value.
    INTEGER(INTG), INTENT(OUT) :: ERR !<The error code
    TYPE(VARYING_STRING), INTENT(OUT) :: ERROR !<The error string
    !Local variables
    INTEGER(INTG) :: i,j,n,m
    REAL(DP) :: L_PARAM,H_PARAM,U_PARAM,P_PARAM,MU_PARAM,NU_PARAM,RHO_PARAM,INTERNAL_TIME,CURRENT_TIME,K_PARAM
    REAL(DP) :: amplitude,yOffset,period,phaseShift,frequency,s,startTime,stopTime,tt,tmax,Qo
    REAL(DP) :: componentCoeff(4),delta(300),t(300),q(300)
    TYPE(VARYING_STRING) :: LOCAL_ERROR

    ENTERS("NAVIER_STOKES_ANALYTIC_FUNCTIONS_EVALUATE",ERR,ERROR,*999)

    !\todo: Introduce user-defined or default values instead for density and viscosity
    INTERNAL_TIME=TIME
    CURRENT_TIME=TIME

    SELECT CASE(ANALYTIC_FUNCTION_TYPE)
      
    CASE(EQUATIONS_SET_NAVIER_STOKES_EQUATION_TWO_DIM_POISEUILLE)
      !For fully developed 2D laminar flow through a channel, NSE should yield a parabolic profile, 
      !U = Umax(1-y^2/H^2), Umax = (-dP/dx)*(H^2/(2*MU)), Umax = (3/2)*Umean
      !Note: assumes a flat inlet profile (U_PARAM = Umean).
      !Nonlinear terms from NSE will effectively be 0 for Poiseuille flow 
      IF(NUMBER_OF_DIMENSIONS==2.AND.NUMBER_OF_COMPONENTS==3) THEN
        MU_PARAM = MATERIALS_PARAMETERS(1)
        RHO_PARAM = MATERIALS_PARAMETERS(2)
        SELECT CASE(VARIABLE_TYPE)
        CASE(FIELD_U_VARIABLE_TYPE)
          L_PARAM = ANALYTIC_PARAMETERS(1) ! channel length in x-direction
          H_PARAM = ANALYTIC_PARAMETERS(2) ! channel height in y-direction
          U_PARAM = ANALYTIC_PARAMETERS(3) ! mean (inlet) velocity
          P_PARAM = ANALYTIC_PARAMETERS(4) ! pressure value at outlet 
          SELECT CASE(GLOBAL_DERIV_INDEX)
          CASE(NO_GLOBAL_DERIV)
            IF(componentNumber==1) THEN
              !calculate u
              VALUE=(3.0_DP/2.0_DP)*U_PARAM*(1.0_DP-((X(2)-H_PARAM)**2)/(H_PARAM**2))
            ELSE IF(componentNumber==2) THEN
              !calculate v
              VALUE=0.0_DP
            ELSE IF(componentNumber==3) THEN
              !calculate p
              VALUE = (3.0_DP*MU_PARAM*U_PARAM*(X(1)-L_PARAM))/(H_PARAM**2)+P_PARAM
            ELSE
              CALL FlagError("Not implemented.",ERR,ERROR,*999)
            END IF
          CASE(GLOBAL_DERIV_S1)
            CALL FlagError("Not implemented.",ERR,ERROR,*999)
          CASE(GLOBAL_DERIV_S2)
            CALL FlagError("Not implemented.",ERR,ERROR,*999)
          CASE(GLOBAL_DERIV_S1_S2)
            CALL FlagError("Not implemented.",ERR,ERROR,*999)
          CASE DEFAULT
            LOCAL_ERROR="The global derivative index of "//TRIM(NUMBER_TO_VSTRING( &
              & GLOBAL_DERIV_INDEX,"*",ERR,ERROR))// &
              & " is invalid."
            CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
          END SELECT
        CASE(FIELD_DELUDELN_VARIABLE_TYPE)
          SELECT CASE(GLOBAL_DERIV_INDEX)
          CASE( NO_GLOBAL_DERIV)
            VALUE= 0.0_DP
          CASE(GLOBAL_DERIV_S1)
            CALL FlagError("Not implemented.",ERR,ERROR,*999)
          CASE(GLOBAL_DERIV_S2)
            CALL FlagError("Not implemented.",ERR,ERROR,*999)                                    
          CASE(GLOBAL_DERIV_S1_S2)
            CALL FlagError("Not implemented.",ERR,ERROR,*999)
          CASE DEFAULT
            LOCAL_ERROR="The global derivative index of "//TRIM(NUMBER_TO_VSTRING( &
              & GLOBAL_DERIV_INDEX,"*",ERR,ERROR))// &
              & " is invalid."
            CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
          END SELECT
        CASE DEFAULT
          LOCAL_ERROR="The variable type of "//TRIM(NUMBER_TO_VSTRING(VARIABLE_TYPE,"*",ERR,ERROR))// &
            & " is invalid."
          CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
        END SELECT
      ELSE 
        LOCAL_ERROR="The number of components does not correspond to the number of dimensions."
        CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
      END IF
      
    CASE(EQUATIONS_SET_NAVIER_STOKES_EQUATION_TWO_DIM_TAYLOR_GREEN)
      !Exact solution to 2D laminar, dynamic, nonlinear Taylor-Green vortex decay  
      IF(NUMBER_OF_DIMENSIONS==2.AND.NUMBER_OF_COMPONENTS==3) THEN
        MU_PARAM = MATERIALS_PARAMETERS(1)
        RHO_PARAM = MATERIALS_PARAMETERS(2)
        NU_PARAM = MU_PARAM/RHO_PARAM ! kinematic viscosity
        SELECT CASE(VARIABLE_TYPE)
        CASE(FIELD_U_VARIABLE_TYPE)
          U_PARAM = ANALYTIC_PARAMETERS(1) ! characteristic velocity (initial amplitude)
          L_PARAM = ANALYTIC_PARAMETERS(2) ! length scale for square
          K_PARAM = 2.0_DP*PI/L_PARAM   ! scale factor for equations
          SELECT CASE(GLOBAL_DERIV_INDEX)
          CASE(NO_GLOBAL_DERIV)
            IF(componentNumber==1) THEN
              !calculate u
              VALUE=-1.0_DP*U_PARAM*COS(K_PARAM*X(1))*SIN(K_PARAM*X(2))*EXP(-2.0_DP*(K_PARAM**2)*NU_PARAM*CURRENT_TIME)
            ELSE IF(componentNumber==2) THEN
              !calculate v
              VALUE=U_PARAM*SIN(K_PARAM*X(1))*COS(K_PARAM*X(2))*EXP(-2.0_DP*(K_PARAM**2)*NU_PARAM*CURRENT_TIME)
            ELSE IF(componentNumber==3) THEN
              !calculate p
              VALUE =-1.0_DP*(U_PARAM**2)*(RHO_PARAM/4.0_DP)*(COS(2.0_DP*K_PARAM*X(1))+ &
                & COS(2.0_DP*K_PARAM*X(2)))*(EXP(-4.0_DP*(K_PARAM**2)*NU_PARAM*CURRENT_TIME))
            ELSE
              CALL FlagError("Not implemented.",ERR,ERROR,*999)
            END IF
          CASE(GLOBAL_DERIV_S1)
            CALL FlagError("Not implemented.",ERR,ERROR,*999)
          CASE(GLOBAL_DERIV_S2)
            CALL FlagError("Not implemented.",ERR,ERROR,*999)
          CASE(GLOBAL_DERIV_S1_S2)
            CALL FlagError("Not implemented.",ERR,ERROR,*999)
          CASE DEFAULT
            LOCAL_ERROR="The global derivative index of "//TRIM(NUMBER_TO_VSTRING( &
              & GLOBAL_DERIV_INDEX,"*",ERR,ERROR))// &
              & " is invalid."
            CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
          END SELECT
        CASE(FIELD_DELUDELN_VARIABLE_TYPE)
          SELECT CASE(GLOBAL_DERIV_INDEX)
          CASE( NO_GLOBAL_DERIV)
            VALUE= 0.0_DP
          CASE(GLOBAL_DERIV_S1)
            CALL FlagError("Not implemented.",ERR,ERROR,*999)
          CASE(GLOBAL_DERIV_S2)
            CALL FlagError("Not implemented.",ERR,ERROR,*999)                                    
          CASE(GLOBAL_DERIV_S1_S2)
            CALL FlagError("Not implemented.",ERR,ERROR,*999)
          CASE DEFAULT
            LOCAL_ERROR="The global derivative index of "//TRIM(NUMBER_TO_VSTRING( &
              & GLOBAL_DERIV_INDEX,"*",ERR,ERROR))// &
              & " is invalid."
            CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
          END SELECT
        CASE DEFAULT
          LOCAL_ERROR="The variable type of "//TRIM(NUMBER_TO_VSTRING(VARIABLE_TYPE,"*",ERR,ERROR))// &
            & " is invalid."
          CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
        END SELECT
      ELSE 
        LOCAL_ERROR="The number of components does not correspond to the number of dimensions."
        CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
      END IF
      
    CASE(EQUATIONS_SET_NAVIER_STOKES_EQUATION_FLOWRATE_AORTA)
      SELECT CASE(NUMBER_OF_DIMENSIONS)
      CASE(1)
        SELECT CASE(VARIABLE_TYPE)
        CASE(FIELD_U_VARIABLE_TYPE)
          SELECT CASE(GLOBAL_DERIV_INDEX)
          CASE(NO_GLOBAL_DERIV)
            IF(componentNumber==1) THEN
              !Input function
              period = 800
              tt=MOD(TIME,period)
              tmax=150.0_DP
              Qo=100000.0_DP
              VALUE=(Qo*tt/(tmax**2.0_DP))*EXP(-(tt**2.0_DP)/(2.0_DP*(tmax**2.0_DP)))
            ELSE
              CALL FlagError("Incorrect component specification for Aorta flow rate waveform ",ERR,ERROR,*999)
            END IF
          CASE DEFAULT
            LOCAL_ERROR="The global derivative index of "//TRIM(NUMBER_TO_VSTRING( &
              & GLOBAL_DERIV_INDEX,"*",ERR,ERROR))// " is invalid."
            CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
          END SELECT
        CASE(FIELD_DELUDELN_VARIABLE_TYPE) 
          SELECT CASE(GLOBAL_DERIV_INDEX)
          CASE(NO_GLOBAL_DERIV)
            VALUE= 0.0_DP
          CASE DEFAULT
            LOCAL_ERROR="The global derivative index of "//TRIM(NUMBER_TO_VSTRING( &
              & GLOBAL_DERIV_INDEX,"*",ERR,ERROR))// " is invalid."
            CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
          END SELECT
        CASE(FIELD_V_VARIABLE_TYPE,FIELD_U1_VARIABLE_TYPE,FIELD_U2_VARIABLE_TYPE)
          ! Do nothing
        CASE DEFAULT
          LOCAL_ERROR="The variable type of "//TRIM(NUMBER_TO_VSTRING(VARIABLE_TYPE,"*",ERR,ERROR))// &
            & " is invalid."
          CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
        END SELECT
      CASE DEFAULT
        LOCAL_ERROR="Aorta flowrate waveform for "//TRIM(NUMBER_TO_VSTRING(NUMBER_OF_DIMENSIONS,"*",ERR,ERROR))// &
          & " dimension problem has not yet been implemented."
        CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
      END SELECT
      
    CASE(EQUATIONS_SET_NAVIER_STOKES_EQUATION_FLOWRATE_OLUFSEN)
      SELECT CASE(NUMBER_OF_DIMENSIONS)
      CASE(1)
        SELECT CASE(VARIABLE_TYPE)
        CASE(FIELD_U_VARIABLE_TYPE)
          SELECT CASE(GLOBAL_DERIV_INDEX)
          CASE(NO_GLOBAL_DERIV)
            IF(componentNumber==1) THEN
              !Olufsen Aorta
              t(1)= 0.0011660 ; q(1)= 17.39051
              t(2)= 0.0215840 ; q(2)= 10.41978
              t(3)= 0.0340860 ; q(3)= 18.75892
              t(4)= 0.0731370 ; q(4)= 266.3842
              t(5)= 0.0857710 ; q(5)= 346.3755
              t(6)= 0.1029220 ; q(6)= 413.8419
              t(7)= 0.1154270 ; q(7)= 424.2680
              t(8)= 0.1483530 ; q(8)= 429.1147
              t(9)= 0.1698860 ; q(9)= 411.0127
              t(10)= 0.220794 ; q(10)= 319.151
              t(11)= 0.264856 ; q(11)= 207.816
              t(12)= 0.295415 ; q(12)= 160.490
              t(13)= 0.325895 ; q(13)= 70.0342
              t(14)= 0.346215 ; q(14)= 10.1939
              t(15)= 0.363213 ; q(15)= -5.1222
              t(16)= 0.383666 ; q(16)= 6.68963
              t(17)= 0.405265 ; q(17)= 24.0659
              t(18)= 0.427988 ; q(18)= 35.8762
              t(19)= 0.455272 ; q(19)= 58.8137
              t(20)= 0.477990 ; q(20)= 67.8414
              t(21)= 0.502943 ; q(21)= 57.3893
              t(22)= 0.535816 ; q(22)= 33.7142
              t(23)= 0.577789 ; q(23)= 20.4676
              t(24)= 0.602753 ; q(24)= 16.2763
              t(25)= 0.639087 ; q(25)= 22.5119
              t(26)= 0.727616 ; q(26)= 18.9721
              t(27)= 0.783235 ; q(27)= 18.9334
              t(28)= 0.800000 ; q(28)= 16.1121
              
              !Initialize variables
              period = 800
              m=1
              n=28
              !Compute derivation
              DO i=1,n-1
                delta(i)=(q(i+1)-q(i))/(t(i+1)-t(i))
              END DO
              delta(n)=delta(n-1)+(delta(n-1)-delta(n-2))/(t(n-1)-t(n-2))*(t(n)-t(n-1))
              !Find subinterval
              DO j=1,n-1
                IF(t(j) <= (TIME/period)) THEN
                  m=j
                END IF
              END DO
              !Evaluate interpolant
              s=(TIME/period)-t(m)
              VALUE=(q(m)+s*delta(m))
            ELSE
              CALL FlagError("Incorrect component specification for Olufsen flow rate waveform ",ERR,ERROR,*999)
            END IF
          CASE DEFAULT
            LOCAL_ERROR="The global derivative index of "//TRIM(NUMBER_TO_VSTRING( &
              & GLOBAL_DERIV_INDEX,"*",ERR,ERROR))// " is invalid."
            CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
          END SELECT
        CASE(FIELD_DELUDELN_VARIABLE_TYPE) 
          SELECT CASE(GLOBAL_DERIV_INDEX)
          CASE(NO_GLOBAL_DERIV)
            VALUE= 0.0_DP
          CASE DEFAULT
            LOCAL_ERROR="The global derivative index of "//TRIM(NUMBER_TO_VSTRING( &
              & GLOBAL_DERIV_INDEX,"*",ERR,ERROR))// " is invalid."
            CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
          END SELECT
        CASE(FIELD_V_VARIABLE_TYPE,FIELD_U1_VARIABLE_TYPE,FIELD_U2_VARIABLE_TYPE)
          ! Do nothing
        CASE DEFAULT
          LOCAL_ERROR="The variable type of "//TRIM(NUMBER_TO_VSTRING(VARIABLE_TYPE,"*",ERR,ERROR))// &
            & " is invalid."
          CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
        END SELECT
      CASE DEFAULT
        LOCAL_ERROR="Olufsen flowrate waveform for "//TRIM(NUMBER_TO_VSTRING(NUMBER_OF_DIMENSIONS,"*",ERR,ERROR))// &
          & " dimension problem has not yet been implemented."
        CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
      END SELECT
      
    CASE(EQUATIONS_SET_NAVIER_STOKES_EQUATION_SINUSOID)
      ! Returns a sinusoidal value for boundary nodes
      SELECT CASE(NUMBER_OF_DIMENSIONS)
      CASE(2,3)
        componentCoeff(1) = ANALYTIC_PARAMETERS(1) 
        componentCoeff(2) = ANALYTIC_PARAMETERS(2) 
        componentCoeff(3) = ANALYTIC_PARAMETERS(3) 
        componentCoeff(4) = ANALYTIC_PARAMETERS(4) 
        amplitude = ANALYTIC_PARAMETERS(5) 
        yOffset = ANALYTIC_PARAMETERS(6) 
        frequency = ANALYTIC_PARAMETERS(7) 
        phaseShift = ANALYTIC_PARAMETERS(8) 
        startTime = ANALYTIC_PARAMETERS(9) 
        stopTime = ANALYTIC_PARAMETERS(10) 
        SELECT CASE(VARIABLE_TYPE)
        CASE(FIELD_U_VARIABLE_TYPE)
          SELECT CASE(GLOBAL_DERIV_INDEX)
          CASE(NO_GLOBAL_DERIV)
            IF(CURRENT_TIME > startTime - ZERO_TOLERANCE .AND. &
              &  CURRENT_TIME < stopTime + ZERO_TOLERANCE) THEN
              VALUE= componentCoeff(componentNumber)*(yOffset + amplitude*SIN(frequency*CURRENT_TIME+phaseShift))
            ELSE
              VALUE= componentCoeff(componentNumber)*(yOffset + amplitude*SIN(frequency*stopTime+phaseShift))
            END IF
          CASE DEFAULT
            LOCAL_ERROR="The global derivative index of "//TRIM(NUMBER_TO_VSTRING( &
              & GLOBAL_DERIV_INDEX,"*",ERR,ERROR))// " is invalid."
            CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
          END SELECT
        CASE(FIELD_DELUDELN_VARIABLE_TYPE) 
          SELECT CASE(GLOBAL_DERIV_INDEX)
          CASE(NO_GLOBAL_DERIV)
            VALUE= 0.0_DP
          CASE DEFAULT
            LOCAL_ERROR="The global derivative index of "//TRIM(NUMBER_TO_VSTRING( &
              & GLOBAL_DERIV_INDEX,"*",ERR,ERROR))// " is invalid."
            CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
          END SELECT
        CASE DEFAULT
          LOCAL_ERROR="The variable type of "//TRIM(NUMBER_TO_VSTRING(VARIABLE_TYPE,"*",ERR,ERROR))// &
            & " is invalid."
          CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
        END SELECT
      CASE DEFAULT
        LOCAL_ERROR="Sinusoidal analytic types for "//TRIM(NUMBER_TO_VSTRING(NUMBER_OF_DIMENSIONS,"*",ERR,ERROR))// &
          & " dimensional problems have not yet been implemented."
        CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
      END SELECT
      
    CASE(EQUATIONS_SET_NAVIER_STOKES_EQUATION_ONE_DIM_1)
      IF(NUMBER_OF_DIMENSIONS==1.AND.NUMBER_OF_COMPONENTS==3) THEN
        !Polynomial function
        SELECT CASE(VARIABLE_TYPE)
        CASE(FIELD_U_VARIABLE_TYPE)
          SELECT CASE(GLOBAL_DERIV_INDEX)
          CASE(NO_GLOBAL_DERIV)
            IF(componentNumber==1) THEN
              !calculate Q
              VALUE=X(1)**2/10.0_DP**2
            ELSE IF(componentNumber==2) THEN
              !calculate A
              VALUE=X(1)**2/10.0_DP**2
            ELSE IF(componentNumber==3) THEN
              !calculate P
              VALUE=X(1)**2/10.0_DP**2
            ELSE
              CALL FlagError("Not implemented.",ERR,ERROR,*999)
            END IF
          CASE(GLOBAL_DERIV_S1)
            CALL FlagError("Not implemented.",ERR,ERROR,*999)
          CASE(GLOBAL_DERIV_S2)
            CALL FlagError("Not implemented.",ERR,ERROR,*999)
          CASE(GLOBAL_DERIV_S1_S2)
            CALL FlagError("Not implemented.",ERR,ERROR,*999)
          CASE DEFAULT
            LOCAL_ERROR="The global derivative index of "//TRIM(NUMBER_TO_VSTRING( &
              & GLOBAL_DERIV_INDEX,"*",ERR,ERROR))// " is invalid."
            CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
          END SELECT
        CASE(FIELD_DELUDELN_VARIABLE_TYPE) 
          SELECT CASE(GLOBAL_DERIV_INDEX)
          CASE(NO_GLOBAL_DERIV)
            VALUE= 0.0_DP
          CASE(GLOBAL_DERIV_S1)
            CALL FlagError("Not implemented.",ERR,ERROR,*999)
          CASE(GLOBAL_DERIV_S2)
            CALL FlagError("Not implemented.",ERR,ERROR,*999)                                    
          CASE(GLOBAL_DERIV_S1_S2)
            CALL FlagError("Not implemented.",ERR,ERROR,*999)
          CASE DEFAULT
            LOCAL_ERROR="The global derivative index of "//TRIM(NUMBER_TO_VSTRING( &
              & GLOBAL_DERIV_INDEX,"*",ERR,ERROR))// &
              & " is invalid."
            CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
          END SELECT
        CASE DEFAULT
          LOCAL_ERROR="The variable type of "//TRIM(NUMBER_TO_VSTRING(VARIABLE_TYPE,"*",ERR,ERROR))// &
            & " is invalid."
          CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
        END SELECT
      ELSE 
        LOCAL_ERROR="The number of components does not correspond to the number of dimensions."
        CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
      END IF
      
    CASE(EQUATIONS_SET_NAVIER_STOKES_EQUATION_TWO_DIM_1)
      IF(NUMBER_OF_DIMENSIONS==2.AND.NUMBER_OF_COMPONENTS==3) THEN
        !Polynomial function
        MU_PARAM = MATERIALS_PARAMETERS(1)
        RHO_PARAM = MATERIALS_PARAMETERS(2)
        SELECT CASE(VARIABLE_TYPE)
        CASE(FIELD_U_VARIABLE_TYPE)
          SELECT CASE(GLOBAL_DERIV_INDEX)
          CASE(NO_GLOBAL_DERIV)
            IF(componentNumber==1) THEN
              !calculate u
              VALUE=X(2)**2/10.0_DP**2
            ELSE IF(componentNumber==2) THEN
              !calculate v
              VALUE=X(1)**2/10.0_DP**2
            ELSE IF(componentNumber==3) THEN
              !calculate p
              VALUE=2.0_DP/3.0_DP*X(1)*(3.0_DP*MU_PARAM*10.0_DP**2-RHO_PARAM*X(1)**2*X(2))/(10.0_DP ** 4)
            ELSE
              CALL FlagError("Not implemented.",ERR,ERROR,*999)
            END IF
          CASE(GLOBAL_DERIV_S1)
            CALL FlagError("Not implemented.",ERR,ERROR,*999)
          CASE(GLOBAL_DERIV_S2)
            CALL FlagError("Not implemented.",ERR,ERROR,*999)
          CASE(GLOBAL_DERIV_S1_S2)
            CALL FlagError("Not implemented.",ERR,ERROR,*999)
          CASE DEFAULT
            LOCAL_ERROR="The global derivative index of "//TRIM(NUMBER_TO_VSTRING( &
              & GLOBAL_DERIV_INDEX,"*",ERR,ERROR))// &
              & " is invalid."
            CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
          END SELECT
        CASE(FIELD_DELUDELN_VARIABLE_TYPE)
          SELECT CASE(GLOBAL_DERIV_INDEX)
          CASE(NO_GLOBAL_DERIV)
            VALUE= 0.0_DP
          CASE(GLOBAL_DERIV_S1)
            CALL FlagError("Not implemented.",ERR,ERROR,*999)
          CASE(GLOBAL_DERIV_S2)
            CALL FlagError("Not implemented.",ERR,ERROR,*999)                                    
          CASE(GLOBAL_DERIV_S1_S2)
            CALL FlagError("Not implemented.",ERR,ERROR,*999)
          CASE DEFAULT
            LOCAL_ERROR="The global derivative index of "//TRIM(NUMBER_TO_VSTRING( &
              & GLOBAL_DERIV_INDEX,"*",ERR,ERROR))// &
              & " is invalid."
            CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
          END SELECT
        CASE DEFAULT
          LOCAL_ERROR="The variable type of "//TRIM(NUMBER_TO_VSTRING(VARIABLE_TYPE,"*",ERR,ERROR))// &
            & " is invalid."
          CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
        END SELECT
      ELSE 
        LOCAL_ERROR="The number of components does not correspond to the number of dimensions."
        CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
      END IF
      
    CASE(EQUATIONS_SET_NAVIER_STOKES_EQUATION_TWO_DIM_2)
      IF(NUMBER_OF_DIMENSIONS==2.AND.NUMBER_OF_COMPONENTS==3) THEN
        !Exponential function
        MU_PARAM = MATERIALS_PARAMETERS(1)
        RHO_PARAM = MATERIALS_PARAMETERS(2)
        SELECT CASE(VARIABLE_TYPE)
        CASE(FIELD_U_VARIABLE_TYPE)
          SELECT CASE(GLOBAL_DERIV_INDEX)
          CASE(NO_GLOBAL_DERIV)
            IF(componentNumber==1) THEN
              !calculate u
              VALUE= EXP((X(1)-X(2))/10.0_DP)
            ELSE IF(componentNumber==2) THEN
              !calculate v
              VALUE= EXP((X(1)-X(2))/10.0_DP)
            ELSE IF(componentNumber==3) THEN
              !calculate p
              VALUE= 2.0_DP*MU_PARAM/10.0_DP*EXP((X(1)-X(2))/10.0_DP)
            ELSE
              CALL FlagError("Not implemented.",ERR,ERROR,*999)
            END IF
          CASE(GLOBAL_DERIV_S1)
            CALL FlagError("Not implemented.",ERR,ERROR,*999)
          CASE(GLOBAL_DERIV_S2)
            CALL FlagError("Not implemented.",ERR,ERROR,*999)
          CASE(GLOBAL_DERIV_S1_S2)
            CALL FlagError("Not implemented.",ERR,ERROR,*999)
          CASE DEFAULT
            LOCAL_ERROR="The global derivative index of "//TRIM(NUMBER_TO_VSTRING( &
              & GLOBAL_DERIV_INDEX,"*",ERR,ERROR))// &
              & " is invalid."
            CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
          END SELECT
        CASE(FIELD_DELUDELN_VARIABLE_TYPE)
          SELECT CASE(GLOBAL_DERIV_INDEX)
          CASE(NO_GLOBAL_DERIV)
            IF(componentNumber==1) THEN
              !calculate u
              VALUE= 0.0_DP
            ELSE IF(componentNumber==2) THEN
              !calculate v
              VALUE= 0.0_DP
            ELSE IF(componentNumber==3) THEN
              !calculate p
              VALUE= 0.0_DP
            ELSE
              CALL FlagError("Not implemented.",ERR,ERROR,*999)
            END IF
          CASE(GLOBAL_DERIV_S1)
            CALL FlagError("Not implemented.",ERR,ERROR,*999)
          CASE(GLOBAL_DERIV_S2)
            CALL FlagError("Not implemented.",ERR,ERROR,*999)                                    
          CASE(GLOBAL_DERIV_S1_S2)
            CALL FlagError("Not implemented.",ERR,ERROR,*999)
          CASE DEFAULT
            LOCAL_ERROR="The global derivative index of "//TRIM(NUMBER_TO_VSTRING( &
              & GLOBAL_DERIV_INDEX,"*",ERR,ERROR))// &
              & " is invalid."
            CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
          END SELECT
        CASE DEFAULT
          LOCAL_ERROR="The variable type of "//TRIM(NUMBER_TO_VSTRING(VARIABLE_TYPE,"*",ERR,ERROR))// &
            & " is invalid."
          CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
        END SELECT
      ELSE 
        LOCAL_ERROR="The number of components does not correspond to the number of dimensions."
        CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
      END IF
      
    CASE(EQUATIONS_SET_NAVIER_STOKES_EQUATION_TWO_DIM_3)
      IF(NUMBER_OF_DIMENSIONS==2.AND.NUMBER_OF_COMPONENTS==3) THEN
        !Sine and cosine function
        MU_PARAM = MATERIALS_PARAMETERS(1)
        RHO_PARAM = MATERIALS_PARAMETERS(2)
        SELECT CASE(VARIABLE_TYPE)
        CASE(FIELD_U_VARIABLE_TYPE)
          SELECT CASE(GLOBAL_DERIV_INDEX)
          CASE(NO_GLOBAL_DERIV)
            IF(componentNumber==1) THEN
              !calculate u
              VALUE=SIN(2.0_DP*PI*X(1)/10.0_DP)*SIN(2.0_DP*PI*X(2)/10.0_DP)
            ELSE IF(componentNumber==2) THEN
              !calculate v
              VALUE=COS(2.0_DP*PI*X(1)/10.0_DP)*COS(2.0_DP*PI*X(2)/10.0_DP)
            ELSE IF(componentNumber==3) THEN
              !calculate p
              VALUE=4.0_DP*MU_PARAM*PI/10.0_DP*SIN(2.0_DP*PI*X(2)/10.0_DP)*COS(2.0_DP*PI*X(1)/10.0_DP)+ &
                & 0.5_DP*RHO_PARAM*COS(2.0_DP*PI*X(1)/10.0_DP)*COS(2.0_DP*PI*X(1)/10.0_DP)
            ELSE
              CALL FlagError("Not implemented.",ERR,ERROR,*999)
            END IF
          CASE(GLOBAL_DERIV_S1)
            CALL FlagError("Not implemented.",ERR,ERROR,*999)
          CASE(GLOBAL_DERIV_S2)
            CALL FlagError("Not implemented.",ERR,ERROR,*999)
          CASE(GLOBAL_DERIV_S1_S2)
            CALL FlagError("Not implemented.",ERR,ERROR,*999)
          CASE DEFAULT
            LOCAL_ERROR="The global derivative index of "//TRIM(NUMBER_TO_VSTRING( &
              & GLOBAL_DERIV_index,"*",ERR,ERROR))// &
              & " is invalid."
            CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
          END SELECT
        CASE(FIELD_DELUDELN_VARIABLE_TYPE)
          SELECT CASE(GLOBAL_DERIV_INDEX)
          CASE(NO_GLOBAL_DERIV)
            IF(componentNumber==1) THEN
              !calculate u
              VALUE=0.0_DP
            ELSE IF(componentNumber==2) THEN
              !calculate v
              VALUE=16.0_DP*MU_PARAM*PI**2/10.0_DP**2*COS(2.0_DP*PI*X(2)/ 10.0_DP)*COS(2.0_DP*PI*X(1)/10.0_DP)
            ELSE IF(componentNumber==3) THEN
              !calculate p
              VALUE=0.0_DP
            ELSE
              CALL FlagError("Not implemented.",ERR,ERROR,*999)
            END IF
          CASE(GLOBAL_DERIV_S1)
            CALL FlagError("Not implemented.",ERR,ERROR,*999)
          CASE(GLOBAL_DERIV_S2)
            CALL FlagError("Not implemented.",ERR,ERROR,*999)                                    
          CASE(GLOBAL_DERIV_S1_S2)
            CALL FlagError("Not implemented.",ERR,ERROR,*999)
          CASE DEFAULT
            LOCAL_ERROR="The global derivative index of "//TRIM(NUMBER_TO_VSTRING( &
              & GLOBAL_DERIV_INDEX,"*",ERR,ERROR))// &
              & " is invalid."
            CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
          END SELECT
        CASE DEFAULT
          LOCAL_ERROR="The variable type of "//TRIM(NUMBER_TO_VSTRING(VARIABLE_TYPE,"*",ERR,ERROR))// &
            & " is invalid."
          CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
        END SELECT
      ELSE 
        LOCAL_ERROR="The number of components does not correspond to the number of dimensions."
        CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
      END IF
      
    CASE(EQUATIONS_SET_NAVIER_STOKES_EQUATION_TWO_DIM_4,EQUATIONS_SET_NAVIER_STOKES_EQUATION_TWO_DIM_5)
      IF(NUMBER_OF_DIMENSIONS==2.AND.NUMBER_OF_COMPONENTS==3) THEN
        !Taylor-Green vortex solution
        MU_PARAM = MATERIALS_PARAMETERS(1)
        RHO_PARAM = MATERIALS_PARAMETERS(2)
        SELECT CASE(VARIABLE_TYPE)
        CASE(FIELD_U_VARIABLE_TYPE)
          SELECT CASE(GLOBAL_DERIV_INDEX)
          CASE(NO_GLOBAL_DERIV)
            IF(componentNumber==1) THEN
              !calculate u
              VALUE=SIN(X(1)/10.0_DP*2.0_DP*PI)*COS(X(2)/10.0_DP*2.0_DP*PI)*EXP(-2.0_DP*MU_PARAM/RHO_PARAM*CURRENT_TIME)
              VALUE=SIN(X(1)/10.0_DP*PI)*COS(X(2)/10.0_DP*PI)*EXP(-2.0_DP*MU_PARAM/RHO_PARAM*CURRENT_TIME)
              !                      VALUE=SIN(X(1))*COS(X(2))
            ELSE IF(componentNumber==2) THEN
              !calculate v
              VALUE=-COS(X(1)/10.0_DP*2.0_DP*PI)*SIN(X(2)/10.0_DP*2.0_DP*PI)*EXP(-2.0_DP*MU_PARAM/RHO_PARAM*CURRENT_TIME)
              VALUE=-COS(X(1)/10.0_DP*PI)*SIN(X(2)/10.0_DP*PI)*EXP(-2.0_DP*MU_PARAM/RHO_PARAM*CURRENT_TIME)
              !                      VALUE=-COS(X(1))*SIN(X(2))
            ELSE IF(componentNumber==3) THEN
              !calculate p
              VALUE=RHO_PARAM/4.0_DP*(COS(2.0_DP*X(1)/10.0_DP*2.0_DP*PI)+COS(2.0_DP*X(2)/10.0_DP*2.0_DP*PI))* &
                & EXP(-4.0_DP*MU_PARAM/RHO_PARAM*CURRENT_TIME)                      
              VALUE=RHO_PARAM/4.0_DP*(COS(2.0_DP*X(1)/10.0_DP*PI)+COS(2.0_DP*X(2)/10.0_DP*PI))* &
                & EXP(-4.0_DP*MU_PARAM/RHO_PARAM*CURRENT_TIME)                      
              !                      VALUE=RHO_PARAM/4.0_DP*(COS(2.0_DP*X(1))+COS(2.0_DP*X(2)))
            ELSE
              CALL FlagError("Not implemented.",ERR,ERROR,*999)
            END IF
          CASE(GLOBAL_DERIV_S1)
            CALL FlagError("Not implemented.",ERR,ERROR,*999)
          CASE(GLOBAL_DERIV_S2)
            CALL FlagError("Not implemented.",ERR,ERROR,*999)
          CASE(GLOBAL_DERIV_S1_S2)
            CALL FlagError("Not implemented.",ERR,ERROR,*999)
          CASE DEFAULT
            LOCAL_ERROR="The global derivative index of "//TRIM(NUMBER_TO_VSTRING( &
              & GLOBAL_DERIV_INDEX,"*",ERR,ERROR))// &
              & " is invalid."
            CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
          END SELECT
        CASE(FIELD_DELUDELN_VARIABLE_TYPE)
          SELECT CASE(GLOBAL_DERIV_INDEX)
          CASE(NO_GLOBAL_DERIV)
            IF(componentNumber==1) THEN
              !calculate u
              VALUE=0.0_DP
            ELSE IF(componentNumber==2) THEN
              !calculate v
              VALUE=0.0_DP         
            ELSE IF(componentNumber==3) THEN
              !calculate p
              VALUE=0.0_DP
            ELSE
              CALL FlagError("Not implemented.",ERR,ERROR,*999)
            END IF
          CASE(GLOBAL_DERIV_S1)
            CALL FlagError("Not implemented.",ERR,ERROR,*999)
          CASE(GLOBAL_DERIV_S2)
            CALL FlagError("Not implemented.",ERR,ERROR,*999)                                    
          CASE(GLOBAL_DERIV_S1_S2)
            CALL FlagError("Not implemented.",ERR,ERROR,*999)
          CASE DEFAULT
            LOCAL_ERROR="The global derivative index of "//TRIM(NUMBER_TO_VSTRING( &
              & GLOBAL_DERIV_INDEX,"*",ERR,ERROR))// &
              & " is invalid."
            CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
          END SELECT
        CASE DEFAULT
          LOCAL_ERROR="The variable type of "//TRIM(NUMBER_TO_VSTRING(VARIABLE_TYPE,"*",ERR,ERROR))// &
            & " is invalid."
          CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
        END SELECT
      ELSE 
        LOCAL_ERROR="The number of components does not correspond to the number of dimensions."
        CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
      END IF
      
    CASE(EQUATIONS_SET_NAVIER_STOKES_EQUATION_THREE_DIM_1)
      IF(NUMBER_OF_DIMENSIONS==3.AND.NUMBER_OF_COMPONENTS==4) THEN
        !Polynomial function
        MU_PARAM = MATERIALS_PARAMETERS(1)
        RHO_PARAM = MATERIALS_PARAMETERS(2)
        SELECT CASE(variable_type)
        CASE(FIELD_U_VARIABLE_TYPE)
          SELECT CASE(GLOBAL_DERIV_INDEX)
          CASE(NO_GLOBAL_DERIV)
            IF(componentNumber==1) THEN
              !calculate u
              VALUE=X(2)**2/10.0_DP**2+X(3)**2/10.0_DP**2
            ELSE IF(componentNumber==2) THEN
              !calculate v
              VALUE=X(1)**2/10.0_DP**2+X(3)**2/10.0_DP** 2
            ELSE IF(componentNumber==3) THEN
              !calculate w
              VALUE=X(1)**2/10.0_DP**2+X(2)**2/10.0_DP** 2
            ELSE IF(componentNumber==4) THEN
              !calculate p
              VALUE=2.0_DP/3.0_DP*X(1)*(6.0_DP*MU_PARAM*10.0_DP**2-RHO_PARAM*X(2)*X(1)**2-3.0_DP* & 
                & RHO_PARAM*X(2)* &
                & X(3)**2-RHO_PARAM*X(3)*X(1)**2-3.0_DP*RHO_PARAM*X(3)*X(2)**2)/(10.0_DP**4)
            ELSE
              CALL FlagError("Not implemented.",ERR,ERROR,*999)
            END IF
          CASE(GLOBAL_DERIV_S1)
            CALL FlagError("Not implemented.",ERR,ERROR,*999)
          CASE(GLOBAL_DERIV_S2)
            CALL FlagError("Not implemented.",ERR,ERROR,*999)
          CASE(GLOBAL_DERIV_S1_S2)
            CALL FlagError("Not implemented.",ERR,ERROR,*999)
          CASE DEFAULT
            LOCAL_ERROR="The global derivative index of "//TRIM(NUMBER_TO_VSTRING( &
              & GLOBAL_DERIV_INDEX,"*",ERR,ERROR))// &
              & " is invalid."
            CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
          END SELECT
        CASE(FIELD_DELUDELN_VARIABLE_TYPE)
          SELECT CASE(GLOBAL_DERIV_INDEX)
          CASE(NO_GLOBAL_DERIV)
            VALUE=0.0_DP
          CASE(GLOBAL_DERIV_S1)
            CALL FlagError("Not implemented.",ERR,ERROR,*999)
          CASE(GLOBAL_DERIV_S2)
            CALL FlagError("Not implemented.",ERR,ERROR,*999)                                    
          CASE(GLOBAL_DERIV_S1_S2)
            CALL FlagError("Not implemented.",ERR,ERROR,*999)
          CASE DEFAULT
            LOCAL_ERROR="The global derivative index of "//TRIM(NUMBER_TO_VSTRING( &
              & GLOBAL_DERIV_INDEX,"*",ERR,ERROR))// &
              & " is invalid."
            CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
          END SELECT
        CASE DEFAULT
          LOCAL_ERROR="The variable type of "//TRIM(NUMBER_TO_VSTRING(variable_type,"*",ERR,ERROR))// &
            & " is invalid."
          CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
        END SELECT
      ELSE 
        LOCAL_ERROR="The number of components does not correspond to the number of dimensions."
        CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
      END IF
      
    CASE(EQUATIONS_SET_NAVIER_STOKES_EQUATION_THREE_DIM_2)
      IF(NUMBER_OF_DIMENSIONS==3.AND.NUMBER_OF_COMPONENTS==4) THEN
        !Exponential function
        MU_PARAM = MATERIALS_PARAMETERS(1)
        RHO_PARAM = MATERIALS_PARAMETERS(2)
        SELECT CASE(variable_type)
        CASE(FIELD_U_VARIABLE_TYPE)
          SELECT CASE(GLOBAL_DERIV_INDEX)
          CASE(NO_GLOBAL_DERIV)
            IF(componentNumber==1) THEN
              !calculate u
              VALUE=EXP((X(1)-X(2))/10.0_DP)+EXP((X(3)-X(1))/10.0_DP)
            ELSE IF(componentNumber==2) THEN
              !calculate v
              VALUE=EXP((X(1)-X(2))/10.0_DP)+EXP((X(2)-X(3))/10.0_DP)
            ELSE IF(componentNumber==3) THEN
              !calculate w
              VALUE=EXP((X(3)-X(1))/10.0_DP)+EXP((X(2)-X(3))/10.0_DP)
            ELSE IF(componentNumber==4) THEN
              !calculate p
              VALUE=1.0_DP/10.0_DP*(2.0_DP*MU_PARAM*EXP((X(1)-X(2))/10.0_DP)- & 
                & 2.0_DP*MU_PARAM*EXP((X(3)-X(1))/10.0_DP)+RHO_PARAM*10.0_DP*EXP((X(1)-X(3))/10.0_DP)+ & 
                & RHO_PARAM*10.0_DP*EXP((X(2)-X(1))/10.0_DP))
            ELSE
              CALL FlagError("Not implemented.",ERR,ERROR,*999)
            END IF
          CASE(GLOBAL_DERIV_S1)
            CALL FlagError("Not implemented.",ERR,ERROR,*999)
          CASE(GLOBAL_DERIV_S2)
            CALL FlagError("Not implemented.",ERR,ERROR,*999)
          CASE(GLOBAL_DERIV_S1_S2)
            CALL FlagError("Not implemented.",ERR,ERROR,*999)
          CASE DEFAULT
            LOCAL_ERROR="The global derivative index of "//TRIM(NUMBER_TO_VSTRING( &
              & GLOBAL_DERIV_INDEX,"*",ERR,ERROR))// &
              & " is invalid."
            CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
          END SELECT
        CASE(FIELD_DELUDELN_VARIABLE_TYPE)
          SELECT CASE(GLOBAL_DERIV_INDEX)
          CASE(NO_GLOBAL_DERIV)
            IF(componentNumber==1) THEN
              !calculate u
              VALUE=0.0_DP
            ELSE IF(componentNumber==2) THEN
              !calculate v
              VALUE=-2.0_DP*MU_PARAM*(2.0_DP*EXP(X(1)-X(2))+EXP(X(2)-X(3)))
            ELSE IF(componentNumber==3) THEN
              !calculate w
              VALUE=-2.0_DP*MU_PARAM*(2.0_DP*EXP(X(3)-X(1))+EXP(X(2)-X(3)))
            ELSE IF(componentNumber==4) THEN
              !calculate p
              VALUE=0.0_DP
            ELSE
              CALL FlagError("Not implemented.",ERR,ERROR,*999)
            END IF
          CASE(GLOBAL_DERIV_S1)
            CALL FlagError("Not implemented.",ERR,ERROR,*999)
          CASE(GLOBAL_DERIV_S2)
            CALL FlagError("Not implemented.",ERR,ERROR,*999)                                    
          CASE(GLOBAL_DERIV_S1_S2)
            CALL FlagError("Not implemented.",ERR,ERROR,*999)
          CASE DEFAULT
            LOCAL_ERROR="The global derivative index of "//TRIM(NUMBER_TO_VSTRING( &
              & GLOBAL_DERIV_INDEX,"*",ERR,ERROR))// &
              & " is invalid."
            CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
          END SELECT
        CASE DEFAULT
          LOCAL_ERROR="The variable type of "//TRIM(NUMBER_TO_VSTRING(variable_type,"*",ERR,ERROR))// &
            & " is invalid."
          CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
        END SELECT
      ELSE 
        LOCAL_ERROR="The number of components does not correspond to the number of dimensions."
        CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
      END IF
      
    CASE(EQUATIONS_SET_NAVIER_STOKES_EQUATION_THREE_DIM_3)
      IF(NUMBER_OF_DIMENSIONS==3.AND.NUMBER_OF_COMPONENTS==4) THEN
        !Sine/cosine function
        MU_PARAM = MATERIALS_PARAMETERS(1)
        RHO_PARAM = MATERIALS_PARAMETERS(2)
        SELECT CASE(variable_type)
        CASE(FIELD_U_VARIABLE_TYPE)
          SELECT CASE(GLOBAL_DERIV_INDEX)
          CASE(NO_GLOBAL_DERIV)
            IF(componentNumber==1) THEN
              !calculate u
              VALUE=SIN(2.0_DP*PI*X(1)/10.0_DP)*SIN(2.0_DP*PI*X(2)/10.0_DP)*SIN(2.0_DP*PI*X(3)/10.0_DP)
            ELSE IF(componentNumber==2) THEN
              !calculate v
              VALUE=2.0_DP*COS(2.0_DP*PI*x(1)/10.0_DP)*SIN(2.0_DP*PI*X(3)/10.0_DP)*COS(2.0_DP*PI*X(2)/10.0_DP)
            ELSE IF(componentNumber==3) THEN
              !calculate w
              VALUE=-COS(2.0_DP*PI*X(1)/10.0_DP)*SIN(2.0_DP*PI*X(2)/10.0_DP)*COS(2.0_DP*PI*X(3)/10.0_DP)
            ELSE IF(componentNumber==4) THEN
              !calculate p
              VALUE=-COS(2.0_DP*PI*X(1)/10.0_DP)*(-12.0_DP*MU_PARAM*PI*SIN(2.0_DP*PI*X(2)/10.0_DP)* & 
                & SIN(2.0_DP*PI*X(3)/10.0_DP)-RHO_PARAM*COS(2.0_DP*PI*X(1)/10.0_DP)*10.0_DP+ &
                & 2.0_DP*RHO_PARAM*COS(2.0_DP*PI*X(1)/10.0_DP)*10.0_DP*COS(2.0_DP*PI*X(3)/10.0_DP)**2- &
                & RHO_PARAM*COS(2.0_DP*PI*X(1)/10.0_DP)*10.0_DP*COS(2.0_DP*PI*X(2)/10.0_DP)**2)/10.0_DP/2.0_DP
            ELSE
              CALL FlagError("Not implemented.",ERR,ERROR,*999)
            END IF
          CASE(GLOBAL_DERIV_S1)
            CALL FlagError("Not implemented.",ERR,ERROR,*999)
          CASE(GLOBAL_DERIV_S2)
            CALL FlagError("Not implemented.",ERR,ERROR,*999)
          CASE(GLOBAL_DERIV_S1_S2)
            CALL FlagError("Not implemented.",ERR,ERROR,*999)
          CASE DEFAULT
            LOCAL_ERROR="The global derivative index of "//TRIM(NUMBER_TO_VSTRING( &
              & GLOBAL_DERIV_INDEX,"*",ERR,ERROR))// &
              & " is invalid."
            CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
          END SELECT
        CASE(FIELD_DELUDELN_VARIABLE_TYPE)
          SELECT CASE(GLOBAL_DERIV_INDEX)
          CASE(NO_GLOBAL_DERIV)
            IF(componentNumber==1) THEN
              !calculate u
              VALUE=0.0_DP
            ELSE IF(componentNumber==2) THEN
              !calculate v
              VALUE=36*MU_PARAM*PI**2/10.0_DP**2*COS(2.0_DP*PI*X(2)/10.0_DP)*SIN(2.0_DP*PI*X(3)/10.0_DP)* & 
                & COS(2.0_DP*PI*X(1)/10.0_DP)
            ELSE IF(componentNumber==3) THEN
              !calculate w
              VALUE=0.0_DP
            ELSE IF(componentNumber==4) THEN
              !calculate p
              VALUE=0.0_DP
            ELSE
              CALL FlagError("Not implemented.",ERR,ERROR,*999)
            END IF
          CASE(GLOBAL_DERIV_S1)
            CALL FlagError("Not implemented.",ERR,ERROR,*999)
          CASE(GLOBAL_DERIV_S2)
            CALL FlagError("Not implemented.",ERR,ERROR,*999)                                    
          CASE(GLOBAL_DERIV_S1_S2)
            CALL FlagError("Not implemented.",ERR,ERROR,*999)
          CASE DEFAULT
            LOCAL_ERROR="The global derivative index of "//TRIM(NUMBER_TO_VSTRING( &
              & GLOBAL_DERIV_INDEX,"*",ERR,ERROR))// &
              & " is invalid."
            CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
          END SELECT
        CASE DEFAULT
          LOCAL_ERROR="The variable type of "//TRIM(NUMBER_TO_VSTRING(variable_type,"*",ERR,ERROR))// &
            & " is invalid."
          CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
        END SELECT
      ELSE 
        LOCAL_ERROR="The number of components does not correspond to the number of dimensions."
        CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
      END IF
      
    CASE(EQUATIONS_SET_NAVIER_STOKES_EQUATION_THREE_DIM_4,EQUATIONS_SET_NAVIER_STOKES_EQUATION_THREE_DIM_5)
      IF(NUMBER_OF_DIMENSIONS==3.AND.NUMBER_OF_COMPONENTS==4) THEN
        !Taylor-Green vortex solution
        MU_PARAM = MATERIALS_PARAMETERS(1)
        RHO_PARAM = MATERIALS_PARAMETERS(2)
        SELECT CASE(variable_type)
        CASE(FIELD_U_VARIABLE_TYPE)
          SELECT CASE(GLOBAL_DERIV_INDEX)
          CASE(NO_GLOBAL_DERIV)
            IF(componentNumber==1) THEN
              !calculate u
              VALUE=SIN(X(1)/10.0_DP*PI)*COS(X(2)/10.0_DP*PI)*EXP(-2.0_DP*MU_PARAM/RHO_PARAM*CURRENT_TIME)
            ELSE IF(componentNumber==2) THEN
              !calculate v
              VALUE=-COS(X(1)/10.0_DP*PI)*SIN(X(2)/10.0_DP*PI)*EXP(-2.0_DP*MU_PARAM/RHO_PARAM*CURRENT_TIME)
            ELSE IF(componentNumber==3) THEN
              !calculate v
              VALUE=0.0_DP
              !                      VALUE=-COS(X(1))*SIN(X(2))
            ELSE IF(componentNumber==4) THEN
              !calculate p
              VALUE=RHO_PARAM/4.0_DP*(COS(2.0_DP*X(1)/10.0_DP*PI)+COS(2.0_DP*X(2)/10.0_DP*PI))* &
                & EXP(-4.0_DP*MU_PARAM/RHO_PARAM*CURRENT_TIME)                      
              !                      VALUE=RHO_PARAM/4.0_DP*(COS(2.0_DP*X(1))+COS(2.0_DP*X(2)))
            ELSE
              CALL FlagError("Not implemented.",ERR,ERROR,*999)
            END IF
          CASE(GLOBAL_DERIV_S1)
            CALL FlagError("Not implemented.",ERR,ERROR,*999)
          CASE(GLOBAL_DERIV_S2)
            CALL FlagError("Not implemented.",ERR,ERROR,*999)
          CASE(GLOBAL_DERIV_S1_S2)
            CALL FlagError("Not implemented.",ERR,ERROR,*999)
          CASE DEFAULT
            LOCAL_ERROR="The global derivative index of "//TRIM(NUMBER_TO_VSTRING( &
              & GLOBAL_DERIV_INDEX,"*",ERR,ERROR))// &
              & " is invalid."
            CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
          END SELECT
        CASE(FIELD_DELUDELN_VARIABLE_TYPE)
          SELECT CASE(GLOBAL_DERIV_INDEX)
          CASE(NO_GLOBAL_DERIV)
            IF(componentNumber==1) THEN
              !calculate u
              VALUE=0.0_DP
            ELSE IF(componentNumber==2) THEN
              !calculate v
              VALUE=0.0_DP         
            ELSE IF(componentNumber==3) THEN
              !calculate p
              VALUE=0.0_DP
            ELSE IF(componentNumber==4) THEN
              !calculate p
              VALUE=0.0_DP
            ELSE
              CALL FlagError("Not implemented.",ERR,ERROR,*999)
            END IF
          CASE(GLOBAL_DERIV_S1)
            CALL FlagError("Not implemented.",ERR,ERROR,*999)
          CASE(GLOBAL_DERIV_S2)
            CALL FlagError("Not implemented.",ERR,ERROR,*999)                                    
          CASE(GLOBAL_DERIV_S1_S2)
            CALL FlagError("Not implemented.",ERR,ERROR,*999)
          CASE DEFAULT
            LOCAL_ERROR="The global derivative index of "//TRIM(NUMBER_TO_VSTRING( &
              & GLOBAL_DERIV_INDEX,"*",ERR,ERROR))// &
              & " is invalid."
            CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
          END SELECT
        CASE DEFAULT
          LOCAL_ERROR="The variable type of "//TRIM(NUMBER_TO_VSTRING(variable_type,"*",ERR,ERROR))// &
            & " is invalid."
          CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
        END SELECT
      ELSE 
        LOCAL_ERROR="The number of components does not correspond to the number of dimensions."
        CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
      END IF
    CASE DEFAULT
      LOCAL_ERROR="The analytic function type of "// &
        & TRIM(NUMBER_TO_VSTRING(ANALYTIC_FUNCTION_TYPE,"*",ERR,ERROR))// &
        & " is invalid."
      CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
    END SELECT
    
    EXITS("NAVIER_STOKES_ANALYTIC_FUNCTIONS_EVALUATE")
    RETURN
999 ERRORSEXITS("NAVIER_STOKES_ANALYTIC_FUNCTIONS_EVALUATE",ERR,ERROR)
    RETURN 1
   
  END SUBROUTINE NAVIER_STOKES_ANALYTIC_FUNCTIONS_EVALUATE

  !
  !================================================================================================================================
  !

  !>Update SUPG parameters for Navier-Stokes equation
  SUBROUTINE NavierStokes_ResidualBasedStabilisation(equationsSet,elementNumber,gaussNumber,mu,rho,jacobianFlag,err,error,*)

    !Argument variables                               
    TYPE(EQUATIONS_SET_TYPE), POINTER :: equationsSet !<A pointer to the equations set to perform the finite element calculations on
    INTEGER(INTG), INTENT(IN) :: elementNumber !<The element number
    INTEGER(INTG), INTENT(IN) :: gaussNumber !<The gauss point number
    REAL(DP), INTENT(IN) :: mu !<The dynamic viscosity
    REAL(DP), INTENT(IN) :: rho !<The fluid density
    LOGICAL, INTENT(IN) ::  jacobianFlag !<Flag indicating whether this was called from the jacobian or residual evaluation routine
    INTEGER(INTG), INTENT(OUT) :: err !<The error code
    TYPE(VARYING_STRING), INTENT(OUT) :: error !<The error string

    !Local Variables                        
    TYPE(BASIS_TYPE), POINTER :: basisVelocity,basisPressure
    TYPE(EQUATIONS_TYPE), POINTER :: equations
    TYPE(EQUATIONS_MAPPING_TYPE), POINTER :: equationsMapping
    TYPE(EQUATIONS_MAPPING_NONLINEAR_TYPE), POINTER :: nonlinearMapping
    TYPE(EQUATIONS_SET_EQUATIONS_SET_FIELD_TYPE), POINTER :: equationsEquationsSetField
    TYPE(FIELD_TYPE), POINTER :: equationsSetField
    TYPE(QUADRATURE_SCHEME_TYPE), POINTER :: quadratureVelocity,quadraturePressure
    TYPE(FIELD_TYPE), POINTER :: dependentField,geometricField
    TYPE(FIELD_VARIABLE_TYPE), POINTER :: fieldVariable
    TYPE(FIELD_INTERPOLATED_POINT_METRICS_TYPE), POINTER :: pointMetrics
    TYPE(EQUATIONS_MATRICES_TYPE), POINTER :: equationsMatrices
    TYPE(EQUATIONS_MATRICES_NONLINEAR_TYPE), POINTER :: nonlinearMatrices
    TYPE(EQUATIONS_JACOBIAN_TYPE), POINTER :: jacobianMatrix

    INTEGER(INTG) :: fieldVariableType,meshComponent1,meshComponent2
    INTEGER(INTG) :: numberOfDimensions
    INTEGER(INTG) :: i,j,k,l,mhs,nhs,ms,ns,nh,mh,nj,ni,pressureIndex
    INTEGER(INTG) :: numberOfElementParameters(4),stabilisationType
    REAL(DP) :: PHIMS,PHINS
    REAL(DP) :: dPhi_dX_Velocity(27,3),dPhi_dX_Pressure(27,3),DPHINS2_DXI(3,3)
    REAL(DP) :: jacobianMomentum(3),jacobianContinuity
    REAL(DP) :: DXI_DX(3,3)
    REAL(DP) :: velocity(3),velocityPrevious(3),velocityDeriv(3,3),velocity2Deriv(3,3,3),pressure,pressureDeriv(3)
    REAL(DP) :: JGW,SUM,SUM2,SUPG,PSPG,LSIC,crossStress,reynoldsStress,momentumTerm
    REAL(DP) :: uDotGu,doubleDotG,tauSUPS,traceG,nuLSIC,timeIncrement,elementInverse,C1,stabilisationValueDP
    REAL(DP) :: tauC,tauMp,tauMu
    REAL(DP) :: residualMomentum(3),residualContinuity
    TYPE(VARYING_STRING) :: localError
    LOGICAL :: linearElement

    ENTERS("NavierStokes_ResidualBasedStabilisation",err,error,*999)

    ! Nullify all local pointers
    NULLIFY(basisVelocity)
    NULLIFY(basisPressure)
    NULLIFY(equations)
    NULLIFY(equationsMapping)
    NULLIFY(nonlinearMapping)
    NULLIFY(equationsEquationsSetField)
    NULLIFY(equationsSetField)
    NULLIFY(quadratureVelocity)
    NULLIFY(quadraturePressure)
    NULLIFY(dependentField)
    NULLIFY(geometricField)
    NULLIFY(fieldVariable)
    NULLIFY(equationsMatrices)
    NULLIFY(nonlinearMatrices)
    NULLIFY(jacobianMatrix)

    IF(ASSOCIATED(equationsSet))THEN
      IF(.NOT.ALLOCATED(equationsSet%specification)) THEN
        CALL FlagError("Equations set specification is not allocated.",err,error,*999)
      ELSE IF(SIZE(equationsSet%specification,1)/=3) THEN
        CALL FlagError("Equations set specification must have three entries for a Navier-Stokes type equations set.", &
          & err,error,*999)
      END IF
      SELECT CASE(equationsSet%specification(3))
      CASE(EQUATIONS_SET_STATIC_RBS_NAVIER_STOKES_SUBTYPE, &
        &  EQUATIONS_SET_TRANSIENT_RBS_NAVIER_STOKES_SUBTYPE, &
        &  EQUATIONS_SET_MULTISCALE3D_NAVIER_STOKES_SUBTYPE, &
        &  EQUATIONS_SET_CONSTITUTIVE_MU_NAVIER_STOKES_SUBTYPE)
        equations=>equationsSet%EQUATIONS
        IF(ASSOCIATED(equations)) THEN
          !Set general and specific pointers
          equationsMapping=>equations%EQUATIONS_MAPPING
          equationsMatrices=>equations%EQUATIONS_MATRICES
          nonlinearMapping=>equationsMapping%NONLINEAR_MAPPING
          nonlinearMatrices=>equationsMatrices%NONLINEAR_MATRICES
          jacobianMatrix=>nonlinearMatrices%JACOBIANS(1)%PTR
          fieldVariable=>nonlinearMapping%RESIDUAL_VARIABLES(1)%PTR
          fieldVariableType=fieldVariable%VARIABLE_TYPE
          geometricField=>equations%INTERPOLATION%GEOMETRIC_FIELD
          numberOfDimensions=fieldVariable%NUMBER_OF_COMPONENTS - 1
          equationsEquationsSetField=>equationsSet%EQUATIONS_SET_FIELD
          meshComponent1=fieldVariable%COMPONENTS(1)%MESH_COMPONENT_NUMBER
          meshComponent2=fieldVariable%COMPONENTS(fieldVariable%NUMBER_OF_COMPONENTS)%MESH_COMPONENT_NUMBER
          dependentField=>equations%INTERPOLATION%DEPENDENT_FIELD
          basisVelocity=>dependentField%DECOMPOSITION%DOMAIN(meshComponent1)%PTR% &
            & TOPOLOGY%ELEMENTS%ELEMENTS(elementNumber)%BASIS
          basisPressure=>dependentField%DECOMPOSITION%DOMAIN(meshComponent2)%PTR% &
            & TOPOLOGY%ELEMENTS%ELEMENTS(elementNumber)%BASIS

          IF(basisVelocity%INTERPOLATION_ORDER(1).LE.1) THEN
            linearElement = .TRUE.
          ELSE
            ! higher order element type- can calculate 2nd order terms
            linearElement = .FALSE.
          END IF

          quadratureVelocity=>basisVelocity%QUADRATURE%QUADRATURE_SCHEME_MAP(BASIS_DEFAULT_QUADRATURE_SCHEME)%PTR
          quadraturePressure=>basisPressure%QUADRATURE%QUADRATURE_SCHEME_MAP(BASIS_DEFAULT_QUADRATURE_SCHEME)%PTR
          equationsSetField=>equationsEquationsSetField%EQUATIONS_SET_FIELD_FIELD
          IF(ASSOCIATED(equationsSetField)) THEN
            ! Stabilisation type (default 1 for RBS, 2 for RBVM, 0 for none)
            CALL FIELD_PARAMETER_SET_GET_CONSTANT(equationsSetField,FIELD_U1_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE, &
             & 4,stabilisationValueDP,err,error,*999)
            stabilisationType=NINT(stabilisationValueDP)
            ! Skip if type 0
            IF(stabilisationType > 0) THEN
              ! Get time step size and calc time derivative
              CALL FIELD_PARAMETER_SET_GET_CONSTANT(equationsSetField,FIELD_U1_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE, &
               & 3,timeIncrement,err,error,*999)
              ! TODO: put this somewhere more sensible. This is a workaround since we don't have access to the dynamic solver values
              !       at this level in the element loop
              IF(equationsSet%specification(3)/=EQUATIONS_SET_STATIC_RBS_NAVIER_STOKES_SUBTYPE &
                & .AND. timeIncrement < ZERO_TOLERANCE) THEN
                CALL FlagError("Please set the equations set field time increment to a value > 0.",ERR,ERROR,*999)                
              END IF
              ! Stabilisation type (default 1 for RBS)
              CALL FIELD_PARAMETER_SET_GET_CONSTANT(equationsSetField,FIELD_U1_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE, &
               & 4,stabilisationValueDP,err,error,*999)
              stabilisationType=NINT(stabilisationValueDP)
              ! User specified or previously calculated C1
              CALL Field_ParameterSetGetLocalElement(equationsSetField,FIELD_V_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE, &
               & elementNumber,10,elementInverse,err,error,*999)

              ! Get previous timestep values
              velocityPrevious=0.0_DP
              IF(equationsSet%specification(3) /= EQUATIONS_SET_STATIC_RBS_NAVIER_STOKES_SUBTYPE) THEN
                CALL FIELD_INTERPOLATION_PARAMETERS_ELEMENT_GET(FIELD_PREVIOUS_VALUES_SET_TYPE,elementNumber,equations% &
                 & INTERPOLATION%DEPENDENT_INTERP_PARAMETERS(FIELD_U_VARIABLE_TYPE)%PTR,ERR,ERROR,*999)
                CALL FIELD_INTERPOLATE_GAUSS(NO_PART_DERIV,BASIS_DEFAULT_QUADRATURE_SCHEME,gaussNumber,EQUATIONS%INTERPOLATION% &
                 & DEPENDENT_INTERP_POINT(FIELD_U_VARIABLE_TYPE)%PTR,ERR,ERROR,*999)
                velocityPrevious=0.0_DP
                DO i=1,numberOfDimensions
                  velocityPrevious(i)=EQUATIONS%INTERPOLATION%DEPENDENT_INTERP_POINT(fieldVariableType)%PTR%VALUES(i,NO_PART_DERIV)
                END DO
              END IF

              ! Interpolate current solution velocity/pressure field values
              CALL FIELD_INTERPOLATION_PARAMETERS_ELEMENT_GET(FIELD_VALUES_SET_TYPE,elementNumber,EQUATIONS%INTERPOLATION% &
               & DEPENDENT_INTERP_PARAMETERS(FIELD_U_VARIABLE_TYPE)%PTR,ERR,ERROR,*999)              
              IF(linearElement) THEN
                ! Get 1st order derivatives for current timestep value
                CALL FIELD_INTERPOLATE_GAUSS(FIRST_PART_DERIV,BASIS_DEFAULT_QUADRATURE_SCHEME,gaussNumber,EQUATIONS%INTERPOLATION% &
                 & DEPENDENT_INTERP_POINT(FIELD_U_VARIABLE_TYPE)%PTR,ERR,ERROR,*999)
              ELSE
                ! Get 2nd order derivatives for current timestep value
                CALL FIELD_INTERPOLATE_GAUSS(SECOND_PART_DERIV,BASIS_DEFAULT_QUADRATURE_SCHEME,gaussNumber,EQUATIONS%INTERPOLATION%&
                 & DEPENDENT_INTERP_POINT(FIELD_U_VARIABLE_TYPE)%PTR,ERR,ERROR,*999)
              END IF
              velocity=0.0_DP
              velocityDeriv=0.0_DP
              velocity2Deriv=0.0_DP
              pressure=0.0_DP
              pressureDeriv=0.0_DP
              DO i=1,numberOfDimensions
                velocity(i)=EQUATIONS%INTERPOLATION%DEPENDENT_INTERP_POINT(fieldVariableType)%PTR%VALUES(i,NO_PART_DERIV)
                velocityDeriv(i,1)=EQUATIONS%INTERPOLATION%DEPENDENT_INTERP_POINT(fieldVariableType)%PTR%VALUES(i,PART_DERIV_S1)
                velocityDeriv(i,2)=EQUATIONS%INTERPOLATION%DEPENDENT_INTERP_POINT(fieldVariableType)%PTR%VALUES(i,PART_DERIV_S2)
                IF(.NOT. linearElement) THEN
                  velocity2Deriv(i,1,1)=EQUATIONS%INTERPOLATION%DEPENDENT_INTERP_POINT(fieldVariableType)%PTR% &
                   & VALUES(i,PART_DERIV_S1_S1)
                  velocity2Deriv(i,1,2)=EQUATIONS%INTERPOLATION%DEPENDENT_INTERP_POINT(fieldVariableType)%PTR% &
                   & VALUES(i,PART_DERIV_S1_S2)
                  velocity2Deriv(i,2,1)=EQUATIONS%INTERPOLATION%DEPENDENT_INTERP_POINT(fieldVariableType)%PTR% &
                   & VALUES(i,PART_DERIV_S1_S2)
                  velocity2Deriv(i,2,2)=EQUATIONS%INTERPOLATION%DEPENDENT_INTERP_POINT(fieldVariableType)%PTR% &
                   & VALUES(i,PART_DERIV_S2_S2)
                END IF
                IF(numberOfDimensions > 2) THEN
                  velocityDeriv(i,3)=EQUATIONS%INTERPOLATION%DEPENDENT_INTERP_POINT(fieldVariableType)%PTR%VALUES(i,PART_DERIV_S3)
                  IF(.NOT. linearElement) THEN                  
                    velocity2Deriv(i,1,3)=EQUATIONS%INTERPOLATION%DEPENDENT_INTERP_POINT(fieldVariableType)%PTR% &
                     & VALUES(i,PART_DERIV_S1_S3)
                    velocity2Deriv(i,2,3)=EQUATIONS%INTERPOLATION%DEPENDENT_INTERP_POINT(fieldVariableType)%PTR% &
                     & VALUES(i,PART_DERIV_S2_S3)
                    velocity2Deriv(i,3,1)=EQUATIONS%INTERPOLATION%DEPENDENT_INTERP_POINT(fieldVariableType)%PTR% &
                     & VALUES(i,PART_DERIV_S1_S3)
                    velocity2Deriv(i,3,2)=EQUATIONS%INTERPOLATION%DEPENDENT_INTERP_POINT(fieldVariableType)%PTR% &
                     & VALUES(i,PART_DERIV_S2_S3)
                    velocity2Deriv(i,3,3)=EQUATIONS%INTERPOLATION%DEPENDENT_INTERP_POINT(fieldVariableType)%PTR% &
                     & VALUES(i,PART_DERIV_S3_S3)
                  END IF
                END IF
              END DO
              pressureIndex = numberOfDimensions + 1
              pressure=EQUATIONS%INTERPOLATION%DEPENDENT_INTERP_POINT(fieldVariableType)%PTR%VALUES(pressureIndex,NO_PART_DERIV)
              pressureDeriv(1)=EQUATIONS%INTERPOLATION%DEPENDENT_INTERP_POINT(fieldVariableType)% &
               & PTR%VALUES(pressureIndex,PART_DERIV_S1)
              pressureDeriv(2)=EQUATIONS%INTERPOLATION%DEPENDENT_INTERP_POINT(fieldVariableType)% &
               & PTR%VALUES(pressureIndex,PART_DERIV_S2)
              IF(numberOfDimensions > 2) THEN
                pressureDeriv(3)=EQUATIONS%INTERPOLATION%DEPENDENT_INTERP_POINT(fieldVariableType)% &
                 & PTR%VALUES(pressureIndex,PART_DERIV_S3)
              END IF
              DXI_DX=0.0_DP
              DO i=1,numberOfDimensions
                DO j=1,numberOfDimensions
                  DXI_DX(j,i)=equations%INTERPOLATION%GEOMETRIC_INTERP_POINT_METRICS(FIELD_U_VARIABLE_TYPE)%PTR% &
                    & DXI_DX(j,i)
                END DO
              END DO

              ! Get number of element parameters for each dependent component
              numberOfElementParameters=0
              DO i=1,numberOfDimensions
                numberOfElementParameters(i)=basisVelocity%NUMBER_OF_ELEMENT_PARAMETERS              
              END DO
              numberOfElementParameters(numberOfDimensions+1)=basisPressure%NUMBER_OF_ELEMENT_PARAMETERS              
              ! Calculate dPhi/dX
              dPhi_dX_Velocity=0.0_DP
              dPhi_dX_Pressure=0.0_DP
              DO ms=1,numberOfElementParameters(1)
                DO nj=1,numberOfDimensions
                  dPhi_dX_Velocity(ms,nj)=0.0_DP
                  DO ni=1,numberOfDimensions
                    dPhi_dX_Velocity(ms,nj)=dPhi_dX_Velocity(ms,nj) + &
                     & quadratureVelocity%GAUSS_BASIS_FNS(ms,PARTIAL_DERIVATIVE_FIRST_DERIVATIVE_MAP(ni),gaussNumber)* &
                     & DXI_DX(ni,nj)
                  END DO
                END DO
              END DO
              DO ms=1,numberOfElementParameters(numberOfDimensions+1)
                DO nj=1,numberOfDimensions
                  dPhi_dX_Pressure(ms,nj)=0.0_DP
                  DO ni=1,numberOfDimensions
                    dPhi_dX_Pressure(ms,nj)=dPhi_dX_Pressure(ms,nj) + &
                     & quadraturePressure%GAUSS_BASIS_FNS(ms,PARTIAL_DERIVATIVE_FIRST_DERIVATIVE_MAP(ni),gaussNumber)* &
                     & DXI_DX(ni,nj)
                  END DO
                END DO
              END DO
              JGW=EQUATIONS%INTERPOLATION%GEOMETRIC_INTERP_POINT_METRICS(FIELD_U_VARIABLE_TYPE)%PTR%JACOBIAN* &
               & quadratureVelocity%GAUSS_WEIGHTS(gaussNumber)

              !----------------------------------------------------------------------------------
              ! C a l c u l a t e   d i s c r e t e   r e s i d u a l s 
              !----------------------------------------------------------------------------------
              SUM = 0.0_DP
              residualMomentum = 0.0_DP
              residualContinuity = 0.0_DP
              ! Calculate momentum residual
              DO i=1,numberOfDimensions    
                SUM = 0.0_DP
                ! velocity time derivative              
                IF(equationsSet%specification(3) /= EQUATIONS_SET_STATIC_RBS_NAVIER_STOKES_SUBTYPE) THEN
                  SUM = rho*(velocity(i)-velocityPrevious(i))/timeIncrement
                END IF
                DO j=1,numberOfDimensions
                  ! pressure gradient
                  SUM = SUM + pressureDeriv(j)*DXI_DX(j,i)
                  DO k=1,numberOfDimensions
                    !Convective term
                    SUM = SUM +rho*((velocity(j))*(velocityDeriv(i,k)*DXI_DX(k,j)))
                    IF(.NOT. linearElement) THEN
                      DO l=1,numberOfDimensions
                        ! viscous stress: only if quadratic or higher basis defined for laplacian
                        SUM = SUM - mu*(velocity2Deriv(i,k,l)*DXI_DX(k,j)*DXI_DX(l,j))
                      END DO
                    END IF
                  END DO
                END DO
                residualMomentum(i) = SUM
              END DO
              ! Calculate continuity residual
              SUM = 0.0_DP
              DO i=1,numberOfDimensions
                DO j=1,numberOfDimensions
                  SUM= SUM + velocityDeriv(i,j)*DXI_DX(j,i)
                END DO
              END DO
              residualContinuity = SUM

              ! Constant of element inverse inequality
              IF(elementInverse > -ZERO_TOLERANCE) THEN
                ! Use user-defined value if specified (default -1)
                C1 = elementInverse
              ELSE IF(linearElement) THEN
                C1=3.0_DP
              ELSE
                IF(numberOfDimensions==2 .AND. basisVelocity%NUMBER_OF_ELEMENT_PARAMETERS==9 &
                  & .AND. basisVelocity%INTERPOLATION_ORDER(1)==2) THEN
                  C1=24.0_DP
                ELSE IF(numberOfDimensions==3 .AND. basisVelocity%NUMBER_OF_ELEMENT_PARAMETERS==27 &
                  & .AND. basisVelocity%INTERPOLATION_ORDER(1)==2) THEN
                  C1=12.0_DP
                !TODO: Expand C1 for more element types
                ELSE
                  CALL FlagError("Element inverse estimate undefined on element " &
                   & //TRIM(NUMBER_TO_VSTRING(elementNumber,"*",err,error)),err,error,*999)                              
                END IF
              END IF
              ! Update element inverse value if calculated
              IF(ABS(C1-elementInverse) > ZERO_TOLERANCE) THEN
                CALL FIELD_PARAMETER_SET_UPDATE_LOCAL_ELEMENT(equationsSetField,FIELD_V_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE, &
                  & elementNumber,10,C1,err,error,*999)
              END IF

              !----------------------------------------------------------
              ! S t a b i l i z a t i o n    C o n s t a n t s    (Taus)
              !----------------------------------------------------------
              IF(stabilisationType == 1 .OR. stabilisationType == 2) THEN
                ! Bazilevs method for calculating tau
                pointMetrics=>equations%INTERPOLATION%GEOMETRIC_INTERP_POINT_METRICS(FIELD_U_VARIABLE_TYPE)%PTR
                uDotGu = 0.0_DP
                DO i=1,numberOfDimensions
                  DO j=1,numberOfDimensions
                    uDotGu = uDotGu + velocity(i)*pointMetrics%GU(i,j)*velocity(j)
                  END DO
                END DO
                doubleDotG = 0.0_DP
                DO i=1,numberOfDimensions
                  DO j=1,numberOfDimensions
                    doubleDotG = doubleDotG + pointMetrics%GU(i,j)*pointMetrics%GU(i,j)
                  END DO
                END DO
                ! Calculate tauSUPS (used for both PSPG and SUPG weights)
                IF(equationsSet%specification(3) == EQUATIONS_SET_STATIC_RBS_NAVIER_STOKES_SUBTYPE) THEN
                  tauSUPS = (uDotGu + (C1*((mu/rho)**2.0_DP)*doubleDotG))**(-0.5_DP)
                ELSE
                  tauSUPS = ((4.0_DP/(timeIncrement**2.0_DP)) + uDotGu + (C1*((mu/rho)**2.0_DP)*doubleDotG))**(-0.5_DP)
                END IF

                ! Calculate nu_LSIC (Least-squares incompressibility constraint)
                traceG = 0.0_DP
                DO i=1,numberOfDimensions
                  traceG = traceG + pointMetrics%GU(i,i)
                END DO
                nuLSIC = 1.0_DP/(tauSUPS*traceG)            

                tauMp = tauSUPS
                tauMu = tauSUPS
                tauC = nuLSIC

              ELSE 
                CALL FlagError("A tau factor has not been defined for the stabilisation type of " &
                 & //TRIM(NUMBER_TO_VSTRING(stabilisationType,"*",err,error)),err,error,*999)
              END IF

              !-------------------------------------------------------------------------------------------------
              ! A d d   s t a b i l i z a t i o n   f a c t o r s   t o   e l e m e n t   m a t r i c e s
              !-------------------------------------------------------------------------------------------------
              jacobianMomentum = 0.0_DP
              jacobianContinuity = 0.0_DP
              mhs = 0
              DO mh=1,numberOfDimensions+1
                DO ms=1,numberOfElementParameters(mh)
                  mhs = mhs + 1
                  IF(mh <= numberOfDimensions) THEN
                    PHIMS=quadratureVelocity%GAUSS_BASIS_FNS(ms,NO_PART_DERIV,gaussNumber)
                    JGW=EQUATIONS%INTERPOLATION%GEOMETRIC_INTERP_POINT_METRICS(FIELD_U_VARIABLE_TYPE)%PTR%JACOBIAN* &
                      & quadratureVelocity%GAUSS_WEIGHTS(gaussNumber)
                  ELSE
                    PHIMS=quadraturePressure%GAUSS_BASIS_FNS(ms,NO_PART_DERIV,gaussNumber)
                    JGW=EQUATIONS%INTERPOLATION%GEOMETRIC_INTERP_POINT_METRICS(FIELD_U_VARIABLE_TYPE)%PTR%JACOBIAN* &
                      & quadraturePressure%GAUSS_WEIGHTS(gaussNumber)
                  END IF
                  !------------------
                  ! J A C O B I A N 
                  !------------------
                  IF(jacobianFlag) THEN
                    nhs = 0
                    DO nh=1,numberOfDimensions+1
                      DO ns=1,numberOfElementParameters(nh)
                        nhs=nhs+1
                        ! Note that we still need to assemble the vector momentum jacobian for PSPG in the continuity row
                        IF(nh <= numberOfDimensions) THEN
                          PHINS=quadratureVelocity%GAUSS_BASIS_FNS(ns,NO_PART_DERIV,gaussNumber)
                        ELSE
                          PHINS=quadraturePressure%GAUSS_BASIS_FNS(ns,NO_PART_DERIV,gaussNumber)
                        END IF

                        ! Calculate jacobians of the discrete residual terms
                        jacobianMomentum = 0.0_DP
                        IF(nh == numberOfDimensions+1) THEN
                          ! d(Momentum(mh))/d(Pressure)
                          DO i=1,numberOfDimensions
                            jacobianMomentum(i) = dPhi_dX_Pressure(ns,i)
                          END DO
                          jacobianContinuity=0.0_DP
                        ELSE
                          DPHINS2_DXI=0.0_DP
                          IF(.NOT. linearElement) THEN
                            DPHINS2_DXI(1,1)=quadratureVelocity%GAUSS_BASIS_FNS(ns,PART_DERIV_S1_S1,gaussNumber)
                            DPHINS2_DXI(1,2)=quadratureVelocity%GAUSS_BASIS_FNS(ns,PART_DERIV_S1_S2,gaussNumber)
                            DPHINS2_DXI(2,1)=quadratureVelocity%GAUSS_BASIS_FNS(ns,PART_DERIV_S1_S2,gaussNumber)
                            DPHINS2_DXI(2,2)=quadratureVelocity%GAUSS_BASIS_FNS(ns,PART_DERIV_S2_S2,gaussNumber)
                            IF(numberOfDimensions > 2) THEN
                              DPHINS2_DXI(1,3)=quadratureVelocity%GAUSS_BASIS_FNS(ns,PART_DERIV_S1_S3,gaussNumber)
                              DPHINS2_DXI(2,3)=quadratureVelocity%GAUSS_BASIS_FNS(ns,PART_DERIV_S2_S3,gaussNumber)
                              DPHINS2_DXI(3,1)=quadratureVelocity%GAUSS_BASIS_FNS(ns,PART_DERIV_S1_S3,gaussNumber)
                              DPHINS2_DXI(3,2)=quadratureVelocity%GAUSS_BASIS_FNS(ns,PART_DERIV_S2_S3,gaussNumber)
                              DPHINS2_DXI(3,3)=quadratureVelocity%GAUSS_BASIS_FNS(ns,PART_DERIV_S3_S3,gaussNumber)
                            END IF
                          END IF
                          ! d(Momentum)/d(Velocity(nh))
                          jacobianMomentum = 0.0_DP
                          DO i=1,numberOfDimensions 
                            SUM = 0.0_DP
                            !Note: Convective term split using product rule
                            !Convective term 1: applies to all velocity components
                            DO j=1,numberOfDimensions
                              SUM = SUM + rho*PHINS*velocityDeriv(i,j)*DXI_DX(j,nh)
                            END DO
                            !Diagonal terms
                            IF(i==nh) THEN
                              !Transient
                              IF(equationsSet%specification(3) /= EQUATIONS_SET_STATIC_RBS_NAVIER_STOKES_SUBTYPE) THEN
                                SUM = SUM + rho*PHINS/timeIncrement
                              END IF
                              !Convective 2: nh component only
                              DO j=1,numberOfDimensions
                                SUM = SUM + rho*velocity(j)*dPhi_dX_Velocity(ns,j)
                              END DO
                              IF(.NOT. linearElement) THEN
                                !Viscous laplacian term
                                DO j=1,numberOfDimensions
                                  DO k=1,numberOfDimensions
                                    DO l=1,numberOfDimensions
                                      SUM=SUM-mu*DPHINS2_DXI(k,l)*DXI_DX(k,j)*DXI_DX(l,j)
                                    END DO 
                                  END DO 
                                END DO 
                              END IF
                            END IF
                            jacobianMomentum(i)=SUM
                          END DO
                          ! Continuity/velocity
                          jacobianContinuity = dPhi_dX_Velocity(ns,nh)
                        END IF
                        ! Calculate jacobian of discrete residual * RBS factors (apply product rule if neccesary)

                        ! PSPG: Pressure stabilising Petrov-Galerkin
                        IF(mh == numberOfDimensions+1) THEN
                          PSPG = 0.0_DP
                          SUM = 0.0_DP
                          DO i=1,numberOfDimensions
                            SUM = SUM + dPhi_dX_Pressure(ms,i)*jacobianMomentum(i)
                          END DO
                          PSPG = tauMp*SUM/rho*JGW

                          jacobianMatrix%ELEMENT_JACOBIAN%MATRIX(mhs,nhs)=jacobianMatrix%ELEMENT_JACOBIAN%MATRIX(mhs,nhs)+PSPG

                        ! SUPG: Streamline upwind/Petrov-Galerkin
                        ! LSIC: Least-squares incompressibility constraint
                        ELSE
                          SUPG=0.0_DP
                          LSIC=0.0_DP

                          SUM=0.0_DP
                          IF(nh <= numberOfDimensions) THEN
                            SUPG= SUPG + PHINS*dPhi_dX_Velocity(ms,nh)*residualMomentum(mh)                            
                          END IF
                          DO i=1,numberOfDimensions
                            SUM = SUM + velocity(i)*dPhi_dX_Velocity(ms,i)
                          END DO
                          SUPG = tauMu*(SUPG + SUM*jacobianMomentum(mh))

                          SUM=0.0_DP
                          DO i=1,numberOfDimensions
                            SUM = SUM + dPhi_dX_Velocity(ms,i)
                          END DO
                          LSIC = tauC*rho*dPhi_dX_Velocity(ms,mh)*jacobianContinuity                        

                          momentumTerm = (SUPG + LSIC)*JGW

                          IF(stabilisationType == 2) THEN
                            ! Additional terms for RBVM
                            crossStress=0.0_DP
                            reynoldsStress=0.0_DP
                            crossStress = 0.0_DP
                            IF(nh <= numberOfDimensions) THEN
                              IF(mh == nh) THEN
                                DO i=1,numberOfDimensions
                                  crossStress= crossStress + dPhi_dX_Velocity(ns,i)*residualMomentum(i)                            
                                END DO
                              END IF
                            END IF
                            SUM2=0.0_DP
                            DO i=1,numberOfDimensions
                              SUM=0.0_DP
                              ! dU_mh/dX_i
                              DO j=1,numberOfDimensions                        
                                SUM= SUM + velocityDeriv(mh,j)*DXI_DX(j,i)
                              END DO
                              ! Jm_i*dU_mh/dX_i
                              SUM2 = SUM2 + jacobianMomentum(i)*SUM
                            END DO
                            crossStress = -tauMu*(crossStress + SUM2)                          

                            reynoldsStress = 0.0_DP
                            SUM = 0.0_DP
                            !Rm_mh.Rm_i.dPhi/dX_i
                            DO i=1,numberOfDimensions
                              SUM = SUM + jacobianMomentum(mh)*residualMomentum(i)*dPhi_DX_Velocity(ms,i)
                              SUM = SUM + jacobianMomentum(i)*residualMomentum(mh)*dPhi_DX_Velocity(ms,i)
                            END DO
                            reynoldsStress = -tauMu*tauMu*SUM

                            momentumTerm = momentumTerm + (crossStress + reynoldsStress)*JGW
                          END IF
                          
                          ! Add stabilisation to element jacobian
                          jacobianMatrix%ELEMENT_JACOBIAN%MATRIX(mhs,nhs)= &
                           & jacobianMatrix%ELEMENT_JACOBIAN%MATRIX(mhs,nhs)+momentumTerm

                        END IF
                      END DO
                    END DO                    

                  !-----------------
                  ! R E S I D U A L
                  !-----------------
                  ELSE
                    ! PSPG: Pressure stabilising Petrov-Galerkin
                    IF(mh == numberOfDimensions+1) THEN
                      SUM = 0.0_DP
                      DO i=1,numberOfDimensions
                        SUM = SUM + dPhi_dX_Pressure(ms,i)*residualMomentum(i)
                      END DO
                      PSPG = SUM*(tauMp/rho)*JGW
                      nonlinearMatrices%ELEMENT_RESIDUAL%VECTOR(mhs)= &
                       & nonlinearMatrices%ELEMENT_RESIDUAL%VECTOR(mhs) + PSPG

                    ! SUPG: Streamline upwind/Petrov-Galerkin
                    ! LSIC: Least-squares incompressibility constraint
                    ELSE
                      SUPG=0.0_DP
                      LSIC=0.0_DP

                      ! u_i*Rm_mh*dv_mh/dx_i
                      SUM=0.0_DP
                      DO i=1,numberOfDimensions
                        SUM = SUM + velocity(i)*dPhi_dX_Velocity(ms,i)
                      END DO
                      SUPG = tauMu*SUM*residualMomentum(mh)

                      LSIC = tauC*rho*dPhi_dX_Velocity(ms,mh)*residualContinuity                        
                      momentumTerm = (SUPG + LSIC)*JGW

                      IF(stabilisationType ==2) THEN
                        ! Additional terms for RBVM
                        crossStress=0.0_DP
                        reynoldsStress=0.0_DP
                        SUM2 = 0.0_DP
                        DO i=1,numberOfDimensions                        
                          SUM = 0.0_DP
                          ! dU_mh/dX_i
                          DO j=1,numberOfDimensions                        
                            SUM= SUM + velocityDeriv(mh,j)*DXI_DX(j,i)
                          END DO
                          ! Rm_i.dU_mh/dX_i
                          SUM2= SUM2 + residualMomentum(i)*SUM
                        END DO
                        crossStress= -tauMu*PHIMS*SUM2

                        reynoldsStress = 0.0_DP
                        SUM = 0.0_DP
                        !Rm_mh.Rm_i.dPhi/dX_i
                        DO i=1,numberOfDimensions
                          SUM = SUM + dPhi_dX_Velocity(ms,i)*residualMomentum(i)*residualMomentum(mh)
                        END DO
                        reynoldsStress = -SUM*(tauMu*tauMu)/rho
                        momentumTerm = momentumTerm + (crossStress + reynoldsStress)*JGW
                      END IF

                      ! Add stabilisation to element residual
                      nonlinearMatrices%ELEMENT_RESIDUAL%VECTOR(mhs)= &
                       & nonlinearMatrices%ELEMENT_RESIDUAL%VECTOR(mhs) + momentumTerm
                    END IF
                  END IF ! jacobian/residual
                END DO !ms
              END DO !mh

            END IF ! check stabilisation type               
          ELSE
            CALL FlagError("Equations equations set field is not associated.",err,error,*999)
          END IF               
        ELSE
          CALL FlagError("Equations set equations is not associated.",err,error,*999)
        END IF               
      CASE DEFAULT
        localError="Equations set subtype "//TRIM(NUMBER_TO_VSTRING(equationsSet%specification(3),"*",err,error))// &
          & " is not a valid subtype to use SUPG weighting functions."
        CALL FlagError(localError,err,error,*999)
      END SELECT
    ELSE
      CALL FlagError("Equations set is not associated.",err,error,*999)
    END IF
    
    EXITS("NavierStokes_ResidualBasedStabilisation")
    RETURN
999 ERRORSEXITS("NavierStokes_ResidualBasedStabilisation",err,error)
    RETURN 1
    
  END SUBROUTINE NavierStokes_ResidualBasedStabilisation

  !
  !================================================================================================================================
  !

  !>Calculate element-level scale factors: CFL, cell Reynolds number
  SUBROUTINE NavierStokes_CalculateElementMetrics(equationsSet,elementNumber,err,error,*)

    !Argument variables                               
    TYPE(EQUATIONS_SET_TYPE), POINTER :: equationsSet !<A pointer to the equations set to perform the finite element calculations on
    INTEGER(INTG), INTENT(IN) :: elementNumber !<The element number
    INTEGER(INTG), INTENT(OUT) :: err !<The error code
    TYPE(VARYING_STRING), INTENT(OUT) :: error !<The error string

    !Local Variables                        
    TYPE(BASIS_TYPE), POINTER :: basisVelocity
    TYPE(EQUATIONS_TYPE), POINTER :: equations
    TYPE(EQUATIONS_MAPPING_TYPE), POINTER :: equationsMapping
    TYPE(EQUATIONS_MAPPING_NONLINEAR_TYPE), POINTER :: nonlinearMapping
    TYPE(EQUATIONS_SET_EQUATIONS_SET_FIELD_TYPE), POINTER :: equationsEquationsSetField
    TYPE(FIELD_TYPE), POINTER :: equationsSetField
    TYPE(QUADRATURE_SCHEME_TYPE), POINTER :: quadratureVelocity
    TYPE(FIELD_TYPE), POINTER :: dependentField,geometricField
    TYPE(FIELD_VARIABLE_TYPE), POINTER :: fieldVariable

    INTEGER(INTG) :: fieldVariableType,meshComponent1
    INTEGER(INTG) :: numberOfDimensions,mh
    INTEGER(INTG) :: gaussNumber
    INTEGER(INTG) :: i,j,ms
    INTEGER(INTG) :: numberOfElementParameters
    INTEGER(INTG) :: LWORK,INFO
    REAL(DP) :: cellReynoldsNumber,cellCourantNumber,timeIncrement
    REAL(DP) :: dPhi_dX_Velocity(27,3)
    REAL(DP) :: DXI_DX(3,3)
    REAL(DP) :: velocity(3),avgVelocity(3),velocityNorm,velocityPrevious(3),velocityDeriv(3,3)
    REAL(DP) :: PHIMS,JGW,SUM,SUM2,mu,rho,normCMatrix,normKMatrix,normMMatrix,muScale
    REAL(DP) :: CMatrix(27,3),KMatrix(27,3),MMatrix(27,3)
    REAL(DP) :: svd(3),U(27,27),VT(3,3)
    REAL(DP), ALLOCATABLE :: WORK(:)
    TYPE(VARYING_STRING) :: localError

    ENTERS("NavierStokes_CalculateElementMetrics",err,error,*999)

    ! Nullify all local pointers
    NULLIFY(basisVelocity)
    NULLIFY(equations)
    NULLIFY(equationsMapping)
    NULLIFY(nonlinearMapping)
    NULLIFY(equationsEquationsSetField)
    NULLIFY(equationsSetField)
    NULLIFY(quadratureVelocity)
    NULLIFY(dependentField)
    NULLIFY(geometricField)
    NULLIFY(fieldVariable)

    IF(ASSOCIATED(equationsSet))THEN
      SELECT CASE(equationsSet%specification(3))
      CASE(EQUATIONS_SET_STATIC_RBS_NAVIER_STOKES_SUBTYPE, &
        &  EQUATIONS_SET_TRANSIENT_RBS_NAVIER_STOKES_SUBTYPE, &
        &  EQUATIONS_SET_MULTISCALE3D_NAVIER_STOKES_SUBTYPE)
        equations=>equationsSet%EQUATIONS
        IF(ASSOCIATED(equations)) THEN
          !Set general and specific pointers
          equationsMapping=>equations%EQUATIONS_MAPPING
          nonlinearMapping=>equationsMapping%NONLINEAR_MAPPING
          fieldVariable=>nonlinearMapping%RESIDUAL_VARIABLES(1)%PTR
          fieldVariableType=fieldVariable%VARIABLE_TYPE
          geometricField=>equations%INTERPOLATION%GEOMETRIC_FIELD
          numberOfDimensions=fieldVariable%NUMBER_OF_COMPONENTS - 1
          equationsEquationsSetField=>equationsSet%EQUATIONS_SET_FIELD
          meshComponent1=fieldVariable%COMPONENTS(1)%MESH_COMPONENT_NUMBER
          dependentField=>equations%INTERPOLATION%DEPENDENT_FIELD
          basisVelocity=>dependentField%DECOMPOSITION%DOMAIN(meshComponent1)%PTR% &
            & TOPOLOGY%ELEMENTS%ELEMENTS(elementNumber)%BASIS
          quadratureVelocity=>basisVelocity%QUADRATURE%QUADRATURE_SCHEME_MAP(BASIS_DEFAULT_QUADRATURE_SCHEME)%PTR

          IF(ASSOCIATED(equationsEquationsSetField)) THEN
            equationsSetField=>equationsEquationsSetField%EQUATIONS_SET_FIELD_FIELD
            IF(ASSOCIATED(equationsSetField)) THEN

              ! Get time step size
              CALL FIELD_PARAMETER_SET_GET_CONSTANT(equationsSetField,FIELD_U1_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE, &
               & 3,timeIncrement,err,error,*999)

              ! Loop over gauss points
              CMatrix = 0.0_DP
              MMatrix = 0.0_DP
              KMatrix = 0.0_DP
              CALL FIELD_INTERPOLATION_PARAMETERS_ELEMENT_GET(FIELD_VALUES_SET_TYPE,elementNumber,equations%INTERPOLATION% &
                & GEOMETRIC_INTERP_PARAMETERS(FIELD_U_VARIABLE_TYPE)%PTR,err,error,*999)
              CALL FIELD_PARAMETER_SET_GET_CONSTANT(equationsSet%MATERIALS%MATERIALS_FIELD,FIELD_U_VARIABLE_TYPE, &
                & FIELD_VALUES_SET_TYPE,1,mu,err,error,*999)
              CALL FIELD_PARAMETER_SET_GET_CONSTANT(equationsSet%MATERIALS%MATERIALS_FIELD,FIELD_U_VARIABLE_TYPE, &
                & FIELD_VALUES_SET_TYPE,2,rho,err,error,*999)

              avgVelocity = 0.0_DP
              DO gaussNumber = 1,quadratureVelocity%NUMBER_OF_GAUSS

                ! Get the constitutive law (non-Newtonian) viscosity based on shear rate
                IF(equationsSet%specification(3)==EQUATIONS_SET_CONSTITUTIVE_MU_NAVIER_STOKES_SUBTYPE) THEN
                  ! Note the constant from the U_VARIABLE is a scale factor
                  muScale = mu
                  ! Get the gauss point based value returned from the CellML solver
                  CALL Field_ParameterSetGetLocalGaussPoint(equationsSet%MATERIALS%MATERIALS_FIELD,FIELD_V_VARIABLE_TYPE, &
                    & FIELD_VALUES_SET_TYPE,gaussNumber,elementNumber,1,mu,err,error,*999)
                  mu=mu*muScale
                END IF
   
                ! Get previous timestep values
                velocityPrevious=0.0_DP
                CALL FIELD_INTERPOLATION_PARAMETERS_ELEMENT_GET(FIELD_PREVIOUS_VALUES_SET_TYPE,elementNumber,equations% &
                 & INTERPOLATION%DEPENDENT_INTERP_PARAMETERS(FIELD_U_VARIABLE_TYPE)%PTR,ERR,ERROR,*999)
                CALL FIELD_INTERPOLATE_GAUSS(NO_PART_DERIV,BASIS_DEFAULT_QUADRATURE_SCHEME,gaussNumber,EQUATIONS%INTERPOLATION%&
                 & DEPENDENT_INTERP_POINT(FIELD_U_VARIABLE_TYPE)%PTR,ERR,ERROR,*999)
                velocityPrevious=0.0_DP
                DO i=1,numberOfDimensions
                  velocityPrevious(i)=equations%INTERPOLATION%DEPENDENT_INTERP_POINT(FIELD_U_VARIABLE_TYPE)%PTR% &
                   & VALUES(i,NO_PART_DERIV)
                END DO

                ! Interpolate current solution velocity and first deriv field values
                CALL FIELD_INTERPOLATION_PARAMETERS_ELEMENT_GET(FIELD_VALUES_SET_TYPE,elementNumber, &
                 & EQUATIONS%INTERPOLATION%DEPENDENT_INTERP_PARAMETERS(FIELD_U_VARIABLE_TYPE)%PTR,ERR,ERROR,*999)              
                ! Get 1st order derivatives for current timestep value
                CALL FIELD_INTERPOLATE_GAUSS(FIRST_PART_DERIV,BASIS_DEFAULT_QUADRATURE_SCHEME,gaussNumber, &
                 & EQUATIONS%INTERPOLATION%DEPENDENT_INTERP_POINT(FIELD_U_VARIABLE_TYPE)%PTR,ERR,ERROR,*999)
                velocity=0.0_DP
                velocityDeriv=0.0_DP
                DO i=1,numberOfDimensions
                  velocity(i)=EQUATIONS%INTERPOLATION%DEPENDENT_INTERP_POINT(FIELD_U_VARIABLE_TYPE)%PTR%VALUES(i,NO_PART_DERIV)
                  velocityDeriv(i,1)=EQUATIONS%INTERPOLATION%DEPENDENT_INTERP_POINT(FIELD_U_VARIABLE_TYPE)% &
                   & PTR%VALUES(i,PART_DERIV_S1)
                  velocityDeriv(i,2)=EQUATIONS%INTERPOLATION%DEPENDENT_INTERP_POINT(FIELD_U_VARIABLE_TYPE)% &
                   & PTR%VALUES(i,PART_DERIV_S2)
                  IF(numberOfDimensions > 2) THEN
                    velocityDeriv(i,3)=EQUATIONS%INTERPOLATION%DEPENDENT_INTERP_POINT(FIELD_U_VARIABLE_TYPE)% &
                     & PTR%VALUES(i,PART_DERIV_S3)
                  END IF
                END DO

                ! get dXi/dX deriv
                CALL FIELD_INTERPOLATE_GAUSS(FIRST_PART_DERIV,BASIS_DEFAULT_QUADRATURE_SCHEME,gaussNumber,equations%INTERPOLATION%&
                & GEOMETRIC_INTERP_POINT(FIELD_U_VARIABLE_TYPE)%PTR,ERR,ERROR,*999)
                DXI_DX=0.0_DP
                DO i=1,numberOfDimensions
                  DO j=1,numberOfDimensions
                    DXI_DX(j,i)=equations%INTERPOLATION%GEOMETRIC_INTERP_POINT_METRICS(FIELD_U_VARIABLE_TYPE)%PTR% &
                      & DXI_DX(j,i)
                  END DO
                END DO

                numberOfElementParameters=basisVelocity%NUMBER_OF_ELEMENT_PARAMETERS              
                ! Calculate dPhi/dX
                dPhi_dX_Velocity=0.0_DP
                DO ms=1,numberOfElementParameters
                  DO i=1,numberOfDimensions
                    dPhi_dX_Velocity(ms,i)=0.0_DP
                    DO j=1,numberOfDimensions
                      dPhi_dX_Velocity(ms,i)=dPhi_dX_Velocity(ms,i) + &
                       & quadratureVelocity%GAUSS_BASIS_FNS(ms,PARTIAL_DERIVATIVE_FIRST_DERIVATIVE_MAP(j),gaussNumber)* &
                       & DXI_DX(j,i)
                    END DO
                  END DO
                END DO

                JGW=EQUATIONS%INTERPOLATION%GEOMETRIC_INTERP_POINT_METRICS(FIELD_U_VARIABLE_TYPE)%PTR%JACOBIAN* &
                 & quadratureVelocity%GAUSS_WEIGHTS(gaussNumber)
                DO mh=1,numberOfDimensions
                  DO ms=1,numberOfElementParameters
                    PHIMS=quadratureVelocity%GAUSS_BASIS_FNS(ms,NO_PART_DERIV,gaussNumber)

                    ! c_(a,i)
                    SUM=0.0_DP
                    DO i=1,numberOfDimensions
                      DO j=1,numberOfDimensions                        
                        SUM = SUM + velocity(i)*velocityDeriv(mh,j)*DXI_DX(j,i)
                      END DO
                    END DO
                    CMatrix(ms,mh)=CMatrix(ms,mh) + rho*PHIMS*SUM*JGW

                    ! ~k_(a,i)
                    SUM=0.0_DP
                    DO i=1,numberOfDimensions
                      SUM = SUM + velocity(i)*dPhi_dX_Velocity(ms,i)
                    END DO
                    SUM2=0.0_DP
                    DO i=1,numberOfDimensions
                      DO j=1,numberOfDimensions                        
                        SUM2 = SUM2 + velocity(i)*velocityDeriv(mh,j)*DXI_DX(j,i)
                      END DO
                    END DO
                    KMatrix(ms,mh)=KMatrix(ms,mh)+rho*SUM*SUM2*JGW

                    ! m_(a,i)
                    MMatrix(ms,mh)=MMatrix(ms,mh)+rho*PHIMS*(velocity(mh)-velocityPrevious(mh))/timeIncrement*JGW

                  END DO !ms
                END DO !mh

                avgVelocity= avgVelocity + velocity/quadratureVelocity%NUMBER_OF_GAUSS
              END DO ! gauss loop

              LWORK=MAX(1,3*MIN(numberOfElementParameters,numberOfDimensions)+ &
               & MAX(numberOfElementParameters,numberOfDimensions),5*MIN(numberOfElementParameters,numberOfDimensions))
              ALLOCATE(WORK(LWORK))

              ! compute the singular value decomposition (SVD) using LAPACK
              CALL DGESVD('A','A',numberOfElementParameters,numberOfDimensions,CMatrix,numberOfElementParameters,svd, &
               & U,numberOfElementParameters,VT,numberOfDimensions,WORK,LWORK,INFO)
              normCMatrix=svd(1)
              IF(INFO /= 0) THEN
                localError="Error calculating SVD on element "//TRIM(NUMBER_TO_VSTRING(elementNumber,"*",err,error))//"."
                CALL FlagError(localError,err,error,*999)
              END IF

              CALL DGESVD('A','A',numberOfElementParameters,numberOfDimensions,KMatrix,numberOfElementParameters,svd, &
               & U,numberOfElementParameters,VT,numberOfDimensions,WORK,LWORK,INFO)
              normKMatrix=svd(1)
              IF(INFO /= 0) THEN
                localError="Error calculating SVD on element "//TRIM(NUMBER_TO_VSTRING(elementNumber,"*",err,error))//"."
                CALL FlagError(localError,err,error,*999)
              END IF

              CALL DGESVD('A','A',numberOfElementParameters,numberOfDimensions,MMatrix,numberOfElementParameters,svd, &
               & U,numberOfElementParameters,VT,numberOfDimensions,WORK,LWORK,INFO)
              normMMatrix=svd(1)
              IF(INFO /= 0) THEN
                localError="Error calculating SVD on element "//TRIM(NUMBER_TO_VSTRING(elementNumber,"*",err,error))//"."
                CALL FlagError(localError,err,error,*999)
              END IF
              DEALLOCATE(WORK)

              velocityNorm = L2NORM(avgVelocity)
              cellReynoldsNumber = 0.0_DP
              cellCourantNumber = 0.0_DP
              IF(velocityNorm > ZERO_TOLERANCE) THEN
                IF(normKMatrix > ZERO_TOLERANCE) THEN
                  cellReynoldsNumber = velocityNorm**2.0_DP/(mu/rho)*normCMatrix/normKMatrix
                END IF
                IF(normMMatrix > ZERO_TOLERANCE) THEN
                  cellCourantNumber = timeIncrement/2.0_DP*normCMatrix/normMMatrix
                END IF
              END IF
              CALL FIELD_PARAMETER_SET_UPDATE_LOCAL_ELEMENT(equationsSetField,FIELD_V_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE, &
               & elementNumber,2,velocityNorm,err,error,*999)
              CALL FIELD_PARAMETER_SET_UPDATE_LOCAL_ELEMENT(equationsSetField,FIELD_V_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE, &
               & elementNumber,3,cellCourantNumber,err,error,*999)
              CALL FIELD_PARAMETER_SET_UPDATE_LOCAL_ELEMENT(equationsSetField,FIELD_V_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE, &
               & elementNumber,4,cellReynoldsNumber,err,error,*999)

            ELSE
              CALL FlagError("Equations set field field is not associated.",err,error,*999)
            END IF               
          ELSE
            CALL FlagError("Equations equations set field is not associated.",err,error,*999)
          END IF               
        ELSE
          CALL FlagError("Equations set equations is not associated.",err,error,*999)
        END IF               
      CASE DEFAULT
        localError="Equations set subtype "//TRIM(NUMBER_TO_VSTRING(equationsSet%specification(3),"*",err,error))// &
          & " is not a valid subtype to use SUPG weighting functions."
        CALL FlagError(localError,err,error,*999)
      END SELECT
    ELSE
      CALL FlagError("Equations set is not associated.",err,error,*999)
    END IF
    
    EXITS("NavierStokes_CalculateElementMetrics")
    RETURN
999 ERRORSEXITS("NavierStokes_CalculateElementMetrics",err,error)
    RETURN 1
    
  END SUBROUTINE NavierStokes_CalculateElementMetrics

  !
  !================================================================================================================================
  !

  !>Calculates the face integration term of the finite element formulation for Navier-Stokes equation,
  !>required for pressure and multidomain boundary conditions. 
  !>portions based on DarcyEquation_FiniteElementFaceIntegrate by Adam Reeve.
  SUBROUTINE NavierStokes_FiniteElementFaceIntegrate(equationsSet,elementNumber,dependentVariable,err,error,*)

    !Argument variables
    TYPE(EQUATIONS_SET_TYPE), POINTER :: equationsSet !<The equations set to calculate the RHS term for
    INTEGER(INTG), INTENT(IN) :: elementNumber !<The element number to calculate the RHS term for
    TYPE(FIELD_VARIABLE_TYPE), POINTER :: dependentVariable
    INTEGER(INTG), INTENT(OUT) :: err !<The error code
    TYPE(VARYING_STRING), INTENT(OUT) :: error !<The error string
    !Local variables
    TYPE(FIELD_TYPE), POINTER :: geometricField
    TYPE(EQUATIONS_SET_EQUATIONS_SET_FIELD_TYPE), POINTER :: equationsEquationsSetField
    TYPE(FIELD_TYPE), POINTER :: equationsSetField
    TYPE(FIELD_VARIABLE_TYPE), POINTER :: fieldVariable,geometricVariable
    TYPE(DECOMPOSITION_TYPE), POINTER :: decomposition
    TYPE(DECOMPOSITION_ELEMENT_TYPE), POINTER :: decompElement
    TYPE(BASIS_TYPE), POINTER :: dependentBasis
    TYPE(EQUATIONS_TYPE), POINTER :: equations
    TYPE(EQUATIONS_MATRICES_TYPE), POINTER :: equationsMatrices
    TYPE(DECOMPOSITION_FACE_TYPE), POINTER :: face
    TYPE(BASIS_TYPE), POINTER :: faceBasis
    TYPE(FIELD_INTERPOLATED_POINT_TYPE), POINTER :: dependentInterpolatedPoint
    TYPE(FIELD_INTERPOLATION_PARAMETERS_TYPE), POINTER :: dependentInterpolationParameters
    TYPE(QUADRATURE_SCHEME_TYPE), POINTER :: faceQuadratureScheme
    TYPE(FIELD_INTERPOLATED_POINT_TYPE), POINTER :: geometricInterpolatedPoint
    TYPE(FIELD_INTERPOLATION_PARAMETERS_TYPE), POINTER :: geometricInterpolationParameters
    TYPE(FIELD_INTERPOLATED_POINT_METRICS_TYPE), POINTER :: pointMetrics
    TYPE(FIELD_TYPE), POINTER :: dependentField
    TYPE(EQUATIONS_MATRICES_RHS_TYPE), POINTER :: rhsVector
    TYPE(EQUATIONS_MATRICES_NONLINEAR_TYPE), POINTER :: nonlinearMatrices
    INTEGER(INTG) :: faceIdx, faceNumber
    INTEGER(INTG) :: componentIdx, gaussIdx
    INTEGER(INTG) :: elementBaseDofIdx, faceNodeIdx, elementNodeIdx
    INTEGER(INTG) :: faceNodeDerivativeIdx, meshComponentNumber, nodeDerivativeIdx,elementParameterIdx
    INTEGER(INTG) :: faceParameterIdx,elementDof,normalComponentIdx
    INTEGER(INTG) :: numberOfDimensions,boundaryType
    REAL(DP) :: pressure,density,jacobianGaussWeights,beta,normalFlow
    REAL(DP) :: velocity(3),normalProjection(3),unitNormal(3),stabilisationTerm(3),boundaryNormal(3)
    REAL(DP) :: boundaryValue,normalDifference,normalTolerance,boundaryPressure
    REAL(DP) :: dUDXi(3,3)
    TYPE(VARYING_STRING) :: LOCAL_ERROR
    LOGICAL :: integratedBoundary

    REAL(DP), POINTER :: geometricParameters(:)

    ENTERS("NavierStokes_FiniteElementFaceIntegrate",err,error,*999)

    NULLIFY(decomposition)
    NULLIFY(decompElement)
    NULLIFY(dependentBasis)
    NULLIFY(geometricVariable)
    NULLIFY(geometricParameters)
    NULLIFY(equations)
    NULLIFY(equationsSetField)
    NULLIFY(equationsEquationsSetField)
    NULLIFY(equationsMatrices)
    NULLIFY(face)
    NULLIFY(faceBasis)
    NULLIFY(faceQuadratureScheme)
    NULLIFY(dependentInterpolatedPoint)
    NULLIFY(dependentInterpolationParameters)
    NULLIFY(geometricInterpolatedPoint)
    NULLIFY(geometricInterpolationParameters)
    NULLIFY(rhsVector)
    NULLIFY(nonlinearMatrices)
    NULLIFY(dependentField)
    NULLIFY(geometricField)

    ! Get pointers and perform sanity checks
    IF(ASSOCIATED(equationsSet)) THEN
      dependentField=>equationsSet%DEPENDENT%DEPENDENT_FIELD
      IF(.NOT.ASSOCIATED(dependentField)) THEN
        CALL FlagError("Dependent field is not associated.",err,error,*999)
      END IF
      equations=>equationsSet%EQUATIONS
      IF(ASSOCIATED(equations)) THEN
        equationsMatrices=>equations%EQUATIONS_MATRICES
        IF(ASSOCIATED(equationsMatrices)) THEN
          rhsVector=>equationsMatrices%RHS_VECTOR
          nonlinearMatrices=>equationsMatrices%NONLINEAR_MATRICES
          IF(.NOT. ASSOCIATED(nonlinearMatrices)) THEN
            CALL FlagError("Nonlinear Matrices not associated.",err,error,*999)
          END IF
        END IF
      ELSE
        CALL FlagError("Equations set equations is not associated.",err,error,*999)
      END IF
    ELSE
      CALL FlagError("Equations set is not associated.",err,error,*999)
    END IF

    SELECT CASE(equationsSet%specification(3))
    CASE(EQUATIONS_SET_STATIC_RBS_NAVIER_STOKES_SUBTYPE, &
       & EQUATIONS_SET_TRANSIENT_RBS_NAVIER_STOKES_SUBTYPE, &
       & EQUATIONS_SET_MULTISCALE3D_NAVIER_STOKES_SUBTYPE, &
       & EQUATIONS_SET_CONSTITUTIVE_MU_NAVIER_STOKES_SUBTYPE)

      !Check for the equations set field
      equationsEquationsSetField=>equationsSet%EQUATIONS_SET_FIELD
      IF(ASSOCIATED(equationsEquationsSetField)) THEN
        equationsSetField=>equationsEquationsSetField%EQUATIONS_SET_FIELD_FIELD
        IF(.NOT.ASSOCIATED(equationsSetField)) THEN
          CALL FlagError("Equations set field (EQUATIONS_SET_FIELD_FIELD) is not associated.",err,error,*999)
        END IF
      ELSE
        CALL FlagError("Equations set field (EQUATIONS_EQUATIONS_SET_FIELD_FIELD) is not associated.",err,error,*999)
      END IF

      ! Check whether this element contains an integrated boundary type
      CALL Field_ParameterSetGetLocalElement(equationsSetField,FIELD_V_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE, &
       & elementNumber,9,boundaryValue,err,error,*999)
      boundaryType=NINT(boundaryValue)
      integratedBoundary = .FALSE.
      IF(boundaryType == BOUNDARY_CONDITION_PRESSURE) integratedBoundary = .TRUE.

      !Get the mesh decomposition and basis
      decomposition=>dependentVariable%FIELD%DECOMPOSITION
      !Check that face geometric parameters have been calculated
      IF(decomposition%CALCULATE_FACES .AND. integratedBoundary) THEN
        meshComponentNumber=dependentVariable%COMPONENTS(1)%MESH_COMPONENT_NUMBER
        dependentBasis=>decomposition%DOMAIN(meshComponentNumber)%PTR%TOPOLOGY%ELEMENTS% &
          & ELEMENTS(elementNumber)%BASIS

        decompElement=>DECOMPOSITION%TOPOLOGY%ELEMENTS%ELEMENTS(elementNumber)
        !Get the dependent interpolation parameters
        dependentInterpolationParameters=>equations%INTERPOLATION%DEPENDENT_INTERP_PARAMETERS( &
          & dependentVariable%VARIABLE_TYPE)%PTR
        dependentInterpolatedPoint=>equations%INTERPOLATION%DEPENDENT_INTERP_POINT( &
          & dependentVariable%VARIABLE_TYPE)%PTR
        !Get the geometric interpolation parameters
        geometricInterpolationParameters=>equations%INTERPOLATION%GEOMETRIC_INTERP_PARAMETERS( &
          & FIELD_U_VARIABLE_TYPE)%PTR
        geometricInterpolatedPoint=>equations%INTERPOLATION%GEOMETRIC_INTERP_POINT(FIELD_U_VARIABLE_TYPE)%PTR
        geometricField=>equationsSet%GEOMETRY%GEOMETRIC_FIELD
        CALL FIELD_NUMBER_OF_COMPONENTS_GET(geometricField,FIELD_U_VARIABLE_TYPE,numberOfDimensions,ERR,ERROR,*999)
        !Get access to geometric coordinates
        CALL FIELD_VARIABLE_GET(geometricField,FIELD_U_VARIABLE_TYPE,geometricVariable,ERR,ERROR,*999)
        meshComponentNumber=geometricVariable%COMPONENTS(1)%MESH_COMPONENT_NUMBER
        !Get the geometric distributed vector
        CALL FIELD_PARAMETER_SET_DATA_GET(geometricField,FIELD_U_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE, &
          & geometricParameters,ERR,ERROR,*999)
        fieldVariable=>equations%EQUATIONS_MAPPING%NONLINEAR_MAPPING%RESIDUAL_VARIABLES(1)%PTR
        !Get the density
        CALL FIELD_PARAMETER_SET_GET_CONSTANT(equationsSet%MATERIALS%MATERIALS_FIELD,FIELD_U_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE, &
         & 2,density,err,error,*999)

        ! Get the boundary element parameters
        CALL FIELD_PARAMETER_SET_GET_CONSTANT(equationsSetField,FIELD_U1_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE, &
         & 1,beta,err,error,*999)
        boundaryNormal = 0.0_DP
        CALL Field_ParameterSetGetLocalElement(equationsSetField,FIELD_V_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE, &
         & elementNumber,5,boundaryNormal(1),err,error,*999)
        CALL Field_ParameterSetGetLocalElement(equationsSetField,FIELD_V_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE, &
         & elementNumber,6,boundaryNormal(2),err,error,*999)
        CALL Field_ParameterSetGetLocalElement(equationsSetField,FIELD_V_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE, &
         & elementNumber,7,boundaryNormal(3),err,error,*999)

        DO faceIdx=1,dependentBasis%NUMBER_OF_LOCAL_FACES
          !Get the face normal and quadrature information
          IF(ALLOCATED(decompElement%ELEMENT_FACES)) THEN
            faceNumber=decompElement%ELEMENT_FACES(faceIdx)
          ELSE
            CALL FlagError("Decomposition element faces is not allocated.",err,error,*999)
          END IF
          face=>decomposition%TOPOLOGY%FACES%FACES(faceNumber)
          !This speeds things up but is also important, as non-boundary faces have an XI_DIRECTION that might
          !correspond to the other element.
          IF(.NOT.(face%BOUNDARY_FACE)) CYCLE

          SELECT CASE(dependentBasis%TYPE)
          CASE(BASIS_LAGRANGE_HERMITE_TP_TYPE)
            normalComponentIdx=ABS(face%XI_DIRECTION)
          CASE DEFAULT
            LOCAL_ERROR="Face integration for basis type "//TRIM(NUMBER_TO_VSTRING(dependentBasis%TYPE,"*",ERR,ERROR))// &
              & " is not yet implemented for Navier-Stokes."
            CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
          END SELECT

          faceBasis=>decomposition%DOMAIN(meshComponentNumber)%PTR%TOPOLOGY%FACES%FACES(faceNumber)%BASIS
          faceQuadratureScheme=>faceBasis%QUADRATURE%QUADRATURE_SCHEME_MAP(BASIS_DEFAULT_QUADRATURE_SCHEME)%PTR
          DO gaussIdx=1,faceQuadratureScheme%NUMBER_OF_GAUSS
            !Get interpolated geometry
            CALL FIELD_INTERPOLATE_LOCAL_FACE_GAUSS(FIRST_PART_DERIV,BASIS_DEFAULT_QUADRATURE_SCHEME,faceIdx,gaussIdx, &
              & geometricInterpolatedPoint,err,error,*999)
            !Calculate point metrics 
            pointMetrics=>equations%INTERPOLATION%GEOMETRIC_INTERP_POINT_METRICS(FIELD_U_VARIABLE_TYPE)%PTR
            CALL FIELD_INTERPOLATED_POINT_METRICS_CALCULATE(COORDINATE_JACOBIAN_VOLUME_TYPE,pointMetrics,err,error,*999)

            ! TODO: this sort of thing should be moved to a more general Basis_FaceNormalGet (or similar) routine
            !Get face normal projection
            DO componentIdx=1,dependentVariable%NUMBER_OF_COMPONENTS-1
              normalProjection(componentIdx)=DOT_PRODUCT(pointMetrics%GU(normalComponentIdx,:),pointMetrics%DX_DXI(componentIdx,:))
              IF(face%XI_DIRECTION<0) THEN
                normalProjection(componentIdx)=-normalProjection(componentIdx)
              END IF
            END DO
            IF(L2NORM(normalProjection)>ZERO_TOLERANCE) THEN
               unitNormal=normalProjection/L2NORM(normalProjection)
            ELSE
               unitNormal=0.0_DP
            END IF

            ! Stabilisation term to correct for possible retrograde flow divergence.
            ! See: Moghadam et al 2011 “A comparison of outlet boundary treatments for prevention of backflow divergence..." and
            !      Ismail et al 2014 "A stable approach for coupling multidimensional cardiovascular and pulmonary networks..."
            ! Note: beta is a relative scaling factor 0 <= beta <= 1; default 1.0
            stabilisationTerm = 0.0_DP
            normalDifference=L2NORM(boundaryNormal-unitNormal)
            normalTolerance=0.1_DP
            IF(normalDifference < normalTolerance) THEN
              normalFlow = DOT_PRODUCT(velocity,normalProjection)
              !normalFlow = DOT_PRODUCT(velocity,boundaryNormal)
              IF(normalFlow < -ZERO_TOLERANCE) THEN
                DO componentIdx=1,dependentVariable%NUMBER_OF_COMPONENTS-1
                  stabilisationTerm(componentIdx) = 0.5_DP*beta*density*velocity(componentIdx)*(normalFlow - ABS(normalFlow))
                END DO
              ELSE
                stabilisationTerm = 0.0_DP
              END IF
            ELSE
              ! Not the correct boundary face - go to next face
              EXIT
            END IF

            ! Interpolate applied boundary pressure value
            boundaryPressure=0.0_DP
            !Get the pressure value interpolation parameters
            CALL FIELD_INTERPOLATION_PARAMETERS_ELEMENT_GET(FIELD_PRESSURE_VALUES_SET_TYPE,elementNumber,equations% &
             & INTERPOLATION%DEPENDENT_INTERP_PARAMETERS(FIELD_U_VARIABLE_TYPE)%PTR,ERR,ERROR,*999)
            CALL FIELD_INTERPOLATE_LOCAL_FACE_GAUSS(NO_PART_DERIV,BASIS_DEFAULT_QUADRATURE_SCHEME,faceIdx,gaussIdx, &
             & dependentInterpolatedPoint,ERR,ERROR,*999)
            boundaryPressure=EQUATIONS%INTERPOLATION%DEPENDENT_INTERP_POINT(FIELD_U_VARIABLE_TYPE)%PTR%VALUES(4,NO_PART_DERIV)

            ! Interpolate current solution velocity/pressure field values
            pressure=0.0_DP
            velocity=0.0_DP
            dUDXi=0.0_DP
            CALL FIELD_INTERPOLATION_PARAMETERS_ELEMENT_GET(FIELD_VALUES_SET_TYPE,elementNumber,equations%INTERPOLATION% &
             & DEPENDENT_INTERP_PARAMETERS(FIELD_U_VARIABLE_TYPE)%PTR,ERR,ERROR,*999)              
            !Get interpolated velocity and pressure 
            CALL FIELD_INTERPOLATE_LOCAL_FACE_GAUSS(FIRST_PART_DERIV,BASIS_DEFAULT_QUADRATURE_SCHEME,faceIdx,gaussIdx, &
              & dependentInterpolatedPoint,err,error,*999)
            velocity(1)=dependentInterpolatedPoint%values(1,NO_PART_DERIV) 
            velocity(2)=dependentInterpolatedPoint%values(2,NO_PART_DERIV) 
            velocity(3)=dependentInterpolatedPoint%values(3,NO_PART_DERIV) 
            dUDXi(1:3,1)=dependentInterpolatedPoint%VALUES(1:3,PART_DERIV_S1)
            dUDXi(1:3,2)=dependentInterpolatedPoint%VALUES(1:3,PART_DERIV_S2)
            dUDXi(1:3,3)=dependentInterpolatedPoint%VALUES(1:3,PART_DERIV_S3)
            pressure=dependentInterpolatedPoint%values(4,NO_PART_DERIV) 

            ! Keep this here for now: not using for Pressure BC but may want for traction BC
            ! ! Calculate viscous term
            ! dXiDX=0.0_DP
            ! dXiDX=pointMetrics%DXI_DX(:,:)
            ! CALL MATRIX_PRODUCT(dUDXi,dXiDX,gradU,err,error,*999)
            ! DO i=1,numberOfDimensions 
            !   SUM1 = 0.0_DP
            !   SUM2 = 0.0_DP
            !   DO j=1,numberOfDimensions
            !      SUM1 = normalProjection(j)*gradU(i,j)
            !      SUM2 = normalProjection(j)*gradU(j,i)
            !   END DO
            !   normalViscousTerm(i) = viscosity*(SUM1 + SUM2)
            ! END DO

            !Jacobian and Gauss weighting term
            jacobianGaussWeights=pointMetrics%JACOBIAN*faceQuadratureScheme%GAUSS_WEIGHTS(gaussIdx)

            !Loop over field components
            DO componentIdx=1,dependentVariable%NUMBER_OF_COMPONENTS-1
              !Work out the first index of the rhs vector for this element - (i.e. the number of previous)
              elementBaseDofIdx=dependentBasis%NUMBER_OF_ELEMENT_PARAMETERS*(componentIdx-1)
              DO faceNodeIdx=1,faceBasis%NUMBER_OF_NODES
                elementNodeIdx=dependentBasis%NODE_NUMBERS_IN_LOCAL_FACE(faceNodeIdx,faceIdx)
                DO faceNodeDerivativeIdx=1,faceBasis%NUMBER_OF_DERIVATIVES(faceNodeIdx)
                  nodeDerivativeIdx=dependentBasis%DERIVATIVE_NUMBERS_IN_LOCAL_FACE(faceNodeDerivativeIdx,faceNodeIdx,faceIdx)
                  elementParameterIdx=dependentBasis%ELEMENT_PARAMETER_INDEX(nodeDerivativeIdx,elementNodeIdx)
                  faceParameterIdx=faceBasis%ELEMENT_PARAMETER_INDEX(faceNodeDerivativeIdx,faceNodeIdx)
                  elementDof=elementBaseDofIdx+elementParameterIdx

                  rhsVector%ELEMENT_VECTOR%VECTOR(elementDof) = rhsVector%ELEMENT_VECTOR%VECTOR(elementDof) - &
                    &  (boundaryPressure*normalProjection(componentIdx) - stabilisationTerm(componentIdx))* &
                    &  faceQuadratureScheme%GAUSS_BASIS_FNS(faceParameterIdx,NO_PART_DERIV,gaussIdx)* &
                    &  jacobianGaussWeights

                END DO !nodeDerivativeIdx
              END DO !faceNodeIdx
            END DO !componentIdx
          END DO !gaussIdx
        END DO !faceIdx

        !Restore the distributed geometric data used for the normal calculation
        CALL FIELD_PARAMETER_SET_DATA_RESTORE(geometricField,FIELD_U_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE, &
          & geometricParameters,ERR,ERROR,*999)
      END IF !decomposition%calculate_faces

    CASE DEFAULT
      ! Do nothing for other equation set subtypes
    END SELECT

    EXITS("NavierStokes_FiniteElementFaceIntegrate")
    RETURN
999 ERRORSEXITS("NavierStokes_FiniteElementFaceIntegrate",err,error)
    RETURN 1
  END SUBROUTINE

  !
  !================================================================================================================================
  !

  !> Calculate the fluid flux through 3D boundaries for use in problems with coupled solutions (e.g. multidomain)
  SUBROUTINE NavierStokes_CalculateBoundaryFlux(solver,err,error,*)

    !Argument variables

    TYPE(SOLVER_TYPE), POINTER :: solver !<A pointer to the solver
    INTEGER(INTG), INTENT(OUT) :: err !<The error code
    TYPE(VARYING_STRING), INTENT(OUT) :: error !<The error string
    !Local Variables
    TYPE(CONTROL_LOOP_TYPE), POINTER :: controlLoop !<A pointer to the control loop to solve.
    TYPE(SOLVER_EQUATIONS_TYPE), POINTER :: solverEquations  !<A pointer to the solver equations
    TYPE(SOLVER_MAPPING_TYPE), POINTER :: solverMapping !<A pointer to the solver mapping
    TYPE(SOLVERS_TYPE), POINTER :: solvers !<A pointer to the solver mapping
    TYPE(EQUATIONS_SET_TYPE), POINTER :: equationsSet !<A pointer to the equations set
    TYPE(EQUATIONS_TYPE), POINTER :: equations
    TYPE(DOMAIN_MAPPING_TYPE), POINTER :: elementsMapping
    TYPE(VARYING_STRING) :: LOCAL_ERROR
    TYPE(FIELD_TYPE), POINTER :: geometricField
    TYPE(FIELD_VARIABLE_TYPE), POINTER :: dependentVariable
    TYPE(FIELD_VARIABLE_TYPE), POINTER :: fieldVariable,geometricVariable
    TYPE(DECOMPOSITION_TYPE), POINTER :: decomposition
    TYPE(DECOMPOSITION_TYPE), POINTER :: geometricDecomposition
    TYPE(DECOMPOSITION_ELEMENT_TYPE), POINTER :: decompElement
    TYPE(BASIS_TYPE), POINTER :: dependentBasis
    TYPE(BASIS_TYPE), POINTER :: dependentBasis2
    TYPE(BASIS_TYPE), POINTER :: geometricFaceBasis
    TYPE(EQUATIONS_MATRICES_TYPE), POINTER :: equationsMatrices
    TYPE(DECOMPOSITION_FACE_TYPE), POINTER :: face
    TYPE(BASIS_TYPE), POINTER :: faceBasis
    TYPE(FIELD_INTERPOLATED_POINT_TYPE), POINTER :: dependentInterpolatedPoint
    TYPE(FIELD_INTERPOLATION_PARAMETERS_TYPE), POINTER :: dependentInterpolationParameters
    TYPE(QUADRATURE_SCHEME_TYPE), POINTER :: faceQuadratureScheme
    TYPE(FIELD_INTERPOLATED_POINT_TYPE), POINTER :: geometricInterpolatedPoint
    TYPE(FIELD_INTERPOLATION_PARAMETERS_TYPE), POINTER :: geometricInterpolationParameters
    TYPE(FIELD_INTERPOLATED_POINT_METRICS_TYPE), POINTER :: pointMetrics
    TYPE(EQUATIONS_SET_EQUATIONS_SET_FIELD_TYPE), POINTER :: equationsEquationsSetField
    TYPE(FIELD_TYPE), POINTER :: equationsSetField
    TYPE(FIELD_TYPE), POINTER :: dependentField
    TYPE(EQUATIONS_MATRICES_RHS_TYPE), POINTER :: rhsVector
    INTEGER(INTG) :: faceIdx, faceNumber,elementIdx,nodeNumber,versionNumber
    INTEGER(INTG) :: componentIdx,gaussIdx
    INTEGER(INTG) :: elementBaseDofIdx, faceNodeIdx, elementNodeIdx
    INTEGER(INTG) :: faceNodeDerivativeIdx, meshComponentNumber, nodeDerivativeIdx, parameterIdx
    INTEGER(INTG) :: faceParameterIdx, elementDofIdx,normalComponentIdx
    INTEGER(INTG) :: boundaryID
    INTEGER(INTG) :: MPI_IERROR,numberOfComputationalNodes
    REAL(DP) :: gaussWeight, normalProjection,elementNormal(3)
    REAL(DP) :: normalDifference,normalTolerance,faceFlux
    REAL(DP) :: courant,maxCourant,toleranceCourant
    REAL(DP) :: velocityGauss(3),faceNormal(3),unitNormal(3),boundaryValue,faceArea,faceVelocity
    REAL(DP) :: localBoundaryFlux(10),localBoundaryArea(10),globalBoundaryFlux(10),globalBoundaryArea(10)
    LOGICAL :: correctFace

    REAL(DP), POINTER :: geometricParameters(:)

    ENTERS("NavierStokes_CalculateBoundaryFlux",err,error,*999)

    NULLIFY(decomposition)
    NULLIFY(geometricDecomposition)
    NULLIFY(geometricParameters)
    NULLIFY(decompElement)
    NULLIFY(dependentBasis)
    NULLIFY(dependentBasis2)
    NULLIFY(geometricFaceBasis)
    NULLIFY(geometricVariable)
    NULLIFY(equations)
    NULLIFY(equationsMatrices)
    NULLIFY(face)
    NULLIFY(faceBasis)
    NULLIFY(faceQuadratureScheme)
    NULLIFY(fieldVariable)
    NULLIFY(dependentInterpolatedPoint)
    NULLIFY(dependentInterpolationParameters)
    NULLIFY(geometricInterpolatedPoint)
    NULLIFY(geometricInterpolationParameters)
    NULLIFY(rhsVector)
    NULLIFY(dependentField)
    NULLIFY(geometricField)
    NULLIFY(equationsEquationsSetField)
    NULLIFY(equationsSetField)

    ! Some preliminary sanity checks
    IF(ASSOCIATED(SOLVER)) THEN
      solvers=>SOLVER%SOLVERS
      IF(ASSOCIATED(SOLVERS)) THEN
        controlLoop=>solvers%CONTROL_LOOP
        IF(ASSOCIATED(controlLoop%PROBLEM)) THEN
          SELECT CASE(controlLoop%PROBLEM%specification(3))
          CASE(PROBLEM_MULTISCALE_NAVIER_STOKES_SUBTYPE, &
            &  PROBLEM_TRANSIENT_RBS_NAVIER_STOKES_SUBTYPE) 
            solverEquations=>solver%SOLVER_EQUATIONS
            IF(ASSOCIATED(solverEquations)) THEN
              solverMapping=>solverEquations%SOLVER_MAPPING
              IF(ASSOCIATED(solverMapping)) THEN
                equationsSet=>solverMapping%EQUATIONS_SETS(1)%PTR
                IF(ASSOCIATED(equationsSet)) THEN
                  equations=>equationsSet%EQUATIONS
                    IF(ASSOCIATED(equations)) THEN
                      dependentField=>equationsSet%DEPENDENT%DEPENDENT_FIELD
                      IF(.NOT.ASSOCIATED(dependentField)) THEN
                        CALL FlagError("Dependent field is not associated.",err,error,*999)
                      END IF
                    ELSE
                      CALL FlagError("Equations set equations is not associated.",err,error,*999)
                    END IF
                ELSE
                  CALL FlagError("Equations set is not associated.",err,error,*999)
                END IF
                equationsEquationsSetField=>equationsSet%EQUATIONS_SET_FIELD
                IF(ASSOCIATED(equationsEquationsSetField)) THEN
                  equationsSetField=>equationsEquationsSetField%EQUATIONS_SET_FIELD_FIELD
                  IF(.NOT.ASSOCIATED(equationsSetField)) THEN
                    CALL FlagError("Equations set field (EQUATIONS_SET_FIELD_FIELD) is not associated.",err,error,*999)
                  END IF
                ELSE
                  CALL FlagError("Equations set field (EQUATIONS_EQUATIONS_SET_FIELD_FIELD) is not associated.",err,error,*999)
                END IF
              ELSE
                CALL FlagError("Solver mapping is not associated.",err,error,*999)
              END IF
            ELSE
              CALL FlagError("Solver equations is not associated.",err,error,*999)
            END IF
          CASE DEFAULT
            LOCAL_ERROR="Problem subtype "//TRIM(NUMBER_TO_VSTRING(controlLoop%PROBLEM%specification(3),"*",err,error))// &
              & " is not valid for boundary flux calculation."
            CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
          END SELECT
        ELSE
          CALL FlagError("Problem is not associated.",err,error,*999)
        END IF
      ELSE
        CALL FlagError("Solvers is not associated.",err,error,*999)
      END IF
    ELSE
      CALL FlagError("Solver is not associated.",err,error,*999)
    END IF

    localBoundaryArea=0.0_DP
    localBoundaryFlux=0.0_DP
    faceFlux=0.0_DP
    SELECT CASE(equationsSet%specification(3))
    CASE(EQUATIONS_SET_MULTISCALE3D_NAVIER_STOKES_SUBTYPE, &
      & EQUATIONS_SET_CONSTITUTIVE_MU_NAVIER_STOKES_SUBTYPE, &
      & EQUATIONS_SET_STATIC_RBS_NAVIER_STOKES_SUBTYPE, &
      & EQUATIONS_SET_TRANSIENT_RBS_NAVIER_STOKES_SUBTYPE)

      dependentVariable=>equations%EQUATIONS_MAPPING%NONLINEAR_MAPPING%RESIDUAL_VARIABLES(1)%PTR
      !Get the mesh decomposition and mapping
      decomposition=>dependentVariable%FIELD%DECOMPOSITION
      elementsMapping=>decomposition%DOMAIN(decomposition%MESH_COMPONENT_NUMBER)%PTR%MAPPINGS%ELEMENTS
      ! Get constant max Courant (CFL) number (default 1.0)
      CALL FIELD_PARAMETER_SET_GET_CONSTANT(equationsSetField,FIELD_U1_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE, &
       & 2,toleranceCourant,err,error,*999)

      ! Loop over elements to locate boundary elements
      maxCourant = 0.0_DP
      DO elementIdx=1,elementsMapping%TOTAL_NUMBER_OF_LOCAL
        meshComponentNumber=dependentVariable%COMPONENTS(1)%MESH_COMPONENT_NUMBER
        dependentBasis=>decomposition%DOMAIN(meshComponentNumber)%PTR%TOPOLOGY%ELEMENTS% &
          & ELEMENTS(elementIdx)%BASIS
        decompElement=>DECOMPOSITION%TOPOLOGY%ELEMENTS%ELEMENTS(elementIdx)
        ! Calculate element metrics (courant #, cell Reynolds number)
        CALL NavierStokes_CalculateElementMetrics(equationsSet,elementIdx,err,error,*999)            

        ! C F L  c o n d i t i o n   c h e c k
        ! ------------------------------------
        ! Get element metrics
        CALL Field_ParameterSetGetLocalElement(equationsSetField,FIELD_V_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE, &
         & elementIdx,3,courant,err,error,*999)
        IF(courant < -ZERO_TOLERANCE) THEN
          CALL FLAG_WARNING("Negative Courant (CFL) number.",ERR,ERROR,*999)
        END IF
        IF(courant > maxCourant) maxCourant = courant
        ! Check if element CFL number below specified tolerance
        IF(courant > toleranceCourant) THEN
          LOCAL_ERROR="Element "//TRIM(NUMBER_TO_VSTRING(decompElement%user_number, &
            & "*",ERR,ERROR))//" has violated the CFL condition "//TRIM(NUMBER_TO_VSTRING(courant, &
            & "*",ERR,ERROR))//" <= "//TRIM(NUMBER_TO_VSTRING(toleranceCourant,"*",ERR,ERROR))// &
            & ". Decrease timestep or increase CFL tolerance for the 3D Navier-Stokes problem."
          CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
        END IF

        ! B o u n d a r y   n o r m a l   a n d   I D
        ! ----------------------------------------------
        CALL Field_ParameterSetGetLocalElement(equationsSetField,FIELD_V_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE, &
         & elementIdx,5,elementNormal(1),err,error,*999)
        CALL Field_ParameterSetGetLocalElement(equationsSetField,FIELD_V_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE, &
         & elementIdx,6,elementNormal(2),err,error,*999)
        CALL Field_ParameterSetGetLocalElement(equationsSetField,FIELD_V_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE, &
         & elementIdx,7,elementNormal(3),err,error,*999)
        CALL Field_ParameterSetGetLocalElement(equationsSetField,FIELD_V_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE, &
         & elementIdx,8,boundaryValue,err,error,*999)
        !Check if is a non-wall boundary element
        boundaryID=NINT(boundaryValue)
        IF(boundaryID>1) THEN
          faceArea=0.0_DP
          faceVelocity=0.0_DP
          !Get the dependent interpolation parameters
          dependentInterpolationParameters=>equations%INTERPOLATION%DEPENDENT_INTERP_PARAMETERS( &
            & dependentVariable%VARIABLE_TYPE)%PTR
          dependentInterpolatedPoint=>equations%INTERPOLATION%DEPENDENT_INTERP_POINT( &
            & dependentVariable%VARIABLE_TYPE)%PTR
          ! Loop over faces to determine the boundary face contribution
          DO faceIdx=1,dependentBasis%NUMBER_OF_LOCAL_FACES
            !Get the face normal and quadrature information
            IF(ALLOCATED(decompElement%ELEMENT_FACES)) THEN
              faceNumber=decompElement%ELEMENT_FACES(faceIdx)
            ELSE
              CALL FlagError("Decomposition element faces is not allocated.",err,error,*999)
            END IF
            face=>decomposition%TOPOLOGY%FACES%FACES(faceNumber)
            !This speeds things up but is also important, as non-boundary faces have an XI_DIRECTION that might
            !correspond to the other element.
            IF(.NOT.(face%BOUNDARY_FACE)) CYCLE

            SELECT CASE(dependentBasis%TYPE)
            CASE(BASIS_LAGRANGE_HERMITE_TP_TYPE)
              normalComponentIdx=ABS(face%XI_DIRECTION)
            CASE(BASIS_SIMPLEX_TYPE)
              CALL FLAG_WARNING("Boundary flux calculation not yet set up for simplex element types.",ERR,ERROR,*999)
            CASE DEFAULT
              LOCAL_ERROR="Face integration for basis type "//TRIM(NUMBER_TO_VSTRING(dependentBasis%TYPE,"*",ERR,ERROR))// &
                & " is not yet implemented for Navier-Stokes."
              CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
            END SELECT

            CALL FIELD_INTERPOLATION_PARAMETERS_FACE_GET(FIELD_VALUES_SET_TYPE,faceNumber, &
              & dependentInterpolationParameters,err,error,*999)
            faceBasis=>decomposition%DOMAIN(meshComponentNumber)%PTR%TOPOLOGY%FACES%FACES(faceNumber)%BASIS
            faceQuadratureScheme=>faceBasis%QUADRATURE%QUADRATURE_SCHEME_MAP(BASIS_DEFAULT_QUADRATURE_SCHEME)%PTR

            ! Loop over face gauss points
            DO gaussIdx=1,faceQuadratureScheme%NUMBER_OF_GAUSS
              !Use the geometric field to find the face normal and Jacobian for the face integral
              geometricInterpolationParameters=>equations%INTERPOLATION%GEOMETRIC_INTERP_PARAMETERS( &
                & FIELD_U_VARIABLE_TYPE)%PTR
              CALL FIELD_INTERPOLATION_PARAMETERS_ELEMENT_GET(FIELD_VALUES_SET_TYPE,elementIdx, &
                & geometricInterpolationParameters,err,error,*999)
              geometricInterpolatedPoint=>equations%INTERPOLATION%GEOMETRIC_INTERP_POINT(FIELD_U_VARIABLE_TYPE)%PTR
              CALL FIELD_INTERPOLATE_LOCAL_FACE_GAUSS(FIRST_PART_DERIV,BASIS_DEFAULT_QUADRATURE_SCHEME,faceIdx,gaussIdx, &
                & geometricInterpolatedPoint,err,error,*999)
              pointMetrics=>equations%INTERPOLATION%GEOMETRIC_INTERP_POINT_METRICS(FIELD_U_VARIABLE_TYPE)%PTR
              CALL FIELD_INTERPOLATED_POINT_METRICS_CALCULATE(COORDINATE_JACOBIAN_VOLUME_TYPE,pointMetrics,err,error,*999)

              gaussWeight=faceQuadratureScheme%GAUSS_WEIGHTS(gaussIdx)
              !Get interpolated velocity
              CALL FIELD_INTERPOLATE_GAUSS(NO_PART_DERIV,BASIS_DEFAULT_QUADRATURE_SCHEME,gaussIdx, &
                & dependentInterpolatedPoint,err,error,*999)
              !Interpolated values at gauss point
              velocityGauss=dependentInterpolatedPoint%values(1:3,NO_PART_DERIV)

              ! TODO: this sort of thing should be moved to a more general Basis_FaceNormalGet (or similar) routine
              elementBaseDofIdx=0
              SELECT CASE(dependentBasis%TYPE)
              CASE(BASIS_LAGRANGE_HERMITE_TP_TYPE)
                correctFace=.TRUE.
                ! Make sure this is the boundary face that corresponds with boundaryID (could be a wall rather than inlet/outlet)
                DO componentIdx=1,dependentVariable%NUMBER_OF_COMPONENTS-1
                  normalProjection=DOT_PRODUCT(pointMetrics%GU(normalComponentIdx,:),pointMetrics%DX_DXI(componentIdx,:))
                  IF(face%XI_DIRECTION<0) THEN
                    normalProjection=-normalProjection
                  END IF
                  faceNormal(componentIdx)=normalProjection
                END DO !componentIdx
                unitNormal=faceNormal/L2NORM(faceNormal)
                normalDifference=L2NORM(elementNormal-unitNormal)
                normalTolerance=0.1_DP
                IF(normalDifference>normalTolerance) EXIT
              CASE(BASIS_SIMPLEX_TYPE)
                faceNormal=unitNormal
              CASE DEFAULT
                LOCAL_ERROR="Face integration for basis type "//TRIM(NUMBER_TO_VSTRING(dependentBasis%TYPE,"*",ERR,ERROR))// &
                  & " is not yet implemented for Navier-Stokes."
                CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
              END SELECT

              ! Integrate face area and velocity
              DO componentIdx=1,dependentVariable%NUMBER_OF_COMPONENTS-1
                normalProjection=faceNormal(componentIdx)
                IF(ABS(normalProjection)<ZERO_TOLERANCE) CYCLE
                !Work out the first index of the rhs vector for this element - 1
                elementBaseDofIdx=dependentBasis%NUMBER_OF_ELEMENT_PARAMETERS*(componentIdx-1)
                DO faceNodeIdx=1,faceBasis%NUMBER_OF_NODES
                  elementNodeIdx=dependentBasis%NODE_NUMBERS_IN_LOCAL_FACE(faceNodeIdx,faceIdx)
                  DO faceNodeDerivativeIdx=1,faceBasis%NUMBER_OF_DERIVATIVES(faceNodeIdx)
                    ! Integrate
                    nodeDerivativeIdx=1
                    parameterIdx=dependentBasis%ELEMENT_PARAMETER_INDEX(nodeDerivativeIdx,elementNodeIdx)
                    faceParameterIdx=faceBasis%ELEMENT_PARAMETER_INDEX(faceNodeDerivativeIdx,faceNodeIdx)
                    elementDofIdx=elementBaseDofIdx+parameterIdx
                    faceArea=faceArea + normalProjection*gaussWeight*pointMetrics%JACOBIAN* &
                     & faceQuadratureScheme%GAUSS_BASIS_FNS(faceParameterIdx,NO_PART_DERIV,gaussIdx)
                    faceVelocity=faceVelocity+velocityGauss(componentIdx)*normalProjection*gaussWeight* &
                     & pointMetrics%JACOBIAN*faceQuadratureScheme%GAUSS_BASIS_FNS(faceParameterIdx,NO_PART_DERIV,gaussIdx)
                  END DO !nodeDerivativeIdx
                END DO !faceNodeIdx
              END DO !componentIdx
            END DO !gaussIdx
          END DO !faceIdx
          localBoundaryFlux(boundaryID) = localBoundaryFlux(boundaryID) + faceVelocity
          localBoundaryArea(boundaryID) = localBoundaryArea(boundaryID) + faceArea
        END IF !boundaryIdentifier
      END DO !elementIdx                 

      ! Need to add boundary flux for any boundaries split accross computational nodes
      globalBoundaryFlux = 0.0_DP
      globalBoundaryArea = 0.0_DP
      numberOfComputationalNodes=COMPUTATIONAL_ENVIRONMENT%NUMBER_COMPUTATIONAL_NODES
      IF(numberOfComputationalNodes>1) THEN !use mpi
        CALL MPI_ALLREDUCE(localBoundaryFlux,globalBoundaryFlux,10,MPI_DOUBLE_PRECISION,MPI_SUM,   &
	 & COMPUTATIONAL_ENVIRONMENT%MPI_COMM,MPI_IERROR)
        CALL MPI_ERROR_CHECK("MPI_ALLREDUCE",MPI_IERROR,ERR,ERROR,*999)
        CALL MPI_ALLREDUCE(localBoundaryArea,globalBoundaryArea,10,MPI_DOUBLE_PRECISION,MPI_SUM,   &
	 & COMPUTATIONAL_ENVIRONMENT%MPI_COMM,MPI_IERROR)
        CALL MPI_ERROR_CHECK("MPI_ALLREDUCE",MPI_IERROR,ERR,ERROR,*999)
      ELSE
        globalBoundaryFlux = localBoundaryFlux
        globalBoundaryArea = localBoundaryArea
      END IF
      
      ! Loop over elements again to allocate flux terms to boundary nodes
      DO elementIdx=1,elementsMapping%TOTAL_NUMBER_OF_LOCAL!elementsMapping%INTERNAL_START,elementsMapping%INTERNAL_FINISH
        CALL Field_ParameterSetGetLocalElement(equationsSetField,FIELD_V_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE, &
         & elementIdx,5,elementNormal(1),err,error,*999)
        CALL Field_ParameterSetGetLocalElement(equationsSetField,FIELD_V_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE, &
         & elementIdx,6,elementNormal(2),err,error,*999)
        CALL Field_ParameterSetGetLocalElement(equationsSetField,FIELD_V_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE, &
         & elementIdx,7,elementNormal(3),err,error,*999)
        CALL Field_ParameterSetGetLocalElement(equationsSetField,FIELD_V_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE, &
         & elementIdx,8,boundaryValue,err,error,*999)
        boundaryID=NINT(boundaryValue)
        IF(boundaryID>1) THEN
          meshComponentNumber=2
          decompElement=>decomposition%TOPOLOGY%ELEMENTS%ELEMENTS(elementIdx)
          dependentBasis2=>decomposition%DOMAIN(meshComponentNumber)%PTR%TOPOLOGY%ELEMENTS% &
            & ELEMENTS(elementIdx)%BASIS
          DO faceIdx=1,dependentBasis2%NUMBER_OF_LOCAL_FACES
            !Get the face normal and quadrature information
            IF(ALLOCATED(decompElement%ELEMENT_FACES)) THEN
              faceNumber=decompElement%ELEMENT_FACES(faceIdx)
            ELSE
              CALL FlagError("Decomposition element faces is not allocated.",err,error,*999)
            END IF
            face=>decomposition%TOPOLOGY%FACES%FACES(faceNumber)
            IF(.NOT.(face%BOUNDARY_FACE)) CYCLE
            faceBasis=>decomposition%DOMAIN(meshComponentNumber)%PTR%TOPOLOGY%FACES%FACES(faceNumber)%BASIS
            faceQuadratureScheme=>faceBasis%QUADRATURE%QUADRATURE_SCHEME_MAP(BASIS_DEFAULT_QUADRATURE_SCHEME)%PTR

            SELECT CASE(dependentBasis2%TYPE)
            CASE(BASIS_LAGRANGE_HERMITE_TP_TYPE)
              normalComponentIdx=ABS(face%XI_DIRECTION)
              pointMetrics=>equations%INTERPOLATION%GEOMETRIC_INTERP_POINT_METRICS(FIELD_U_VARIABLE_TYPE)%PTR
              CALL FIELD_INTERPOLATED_POINT_METRICS_CALCULATE(COORDINATE_JACOBIAN_VOLUME_TYPE,pointMetrics,err,error,*999)
              DO componentIdx=1,dependentVariable%NUMBER_OF_COMPONENTS-1
                normalProjection=DOT_PRODUCT(pointMetrics%GU(normalComponentIdx,:),pointMetrics%DX_DXI(componentIdx,:))
                IF(face%XI_DIRECTION<0) THEN
                  normalProjection=-normalProjection
                END IF
                faceNormal(componentIdx)=normalProjection
              END DO !componentIdx
              unitNormal=faceNormal/L2NORM(faceNormal)
            CASE(BASIS_SIMPLEX_TYPE)
              !still have faceNormal/unitNormal
            CASE DEFAULT
              LOCAL_ERROR="Face integration for basis type "//TRIM(NUMBER_TO_VSTRING(dependentBasis2%TYPE,"*",ERR,ERROR))// &
                & " is not yet implemented for Navier-Stokes."
              CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)
            END SELECT
            normalDifference=L2NORM(elementNormal-unitNormal)
            normalTolerance=0.1_DP
            IF(normalDifference>normalTolerance) CYCLE

            ! Update local nodes with integrated boundary flow values
            DO faceNodeIdx=1,faceBasis%NUMBER_OF_NODES
              elementNodeIdx=dependentBasis2%NODE_NUMBERS_IN_LOCAL_FACE(faceNodeIdx,faceIdx)
              DO faceNodeDerivativeIdx=1,faceBasis%NUMBER_OF_DERIVATIVES(faceNodeIdx)
                nodeNumber=decomposition%DOMAIN(meshComponentNumber)%PTR% &
                 & TOPOLOGY%ELEMENTS%ELEMENTS(elementIdx)%ELEMENT_NODES(elementNodeIdx)
                versionNumber=1
                CALL FIELD_PARAMETER_SET_UPDATE_LOCAL_NODE(equationsSetField,FIELD_U_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE, &
                  & versionNumber,faceNodeDerivativeIdx,nodeNumber,1,globalBoundaryFlux(boundaryID),err,error,*999) 
              END DO !nodeDerivativeIdx
            END DO !faceNodeIdx

          END DO !faceIdx
        END IF !boundaryIdentifier
      END DO !elementIdx                 

    CASE DEFAULT
      LOCAL_ERROR="Boundary flux calcluation for the third equations set specification of "// &
        & TRIM(NUMBER_TO_VSTRING(equationsSet%specification(3),"*",ERR,ERROR))// &
        & " is not yet implemented for Navier-Stokes."
      CALL FlagError(LOCAL_ERROR,ERR,ERROR,*999)     
    END SELECT

    EXITS("NavierStokes_CalculateBoundaryFlux")
    RETURN
999 ERRORSEXITS("NavierStokes_CalculateBoundaryFlux",err,error)
    RETURN 1
  END SUBROUTINE

  !
  !================================================================================================================================
  !

  !> Update the solution for the 1D solver with boundary conditions from a lumped parameter model defined by CellML.
  !> For more information please see chapter 11 of: L. Formaggia, A. Quarteroni, and A. Veneziani, Cardiovascular mathematics:
  !> modeling and simulation of the circulatory system. Milan; New York: Springer, 2009.
  SUBROUTINE NavierStokes_Couple1D0D(controlLoop,solver,err,error,*)

    !Argument variables
    TYPE(CONTROL_LOOP_TYPE), POINTER :: controlLoop
    TYPE(SOLVER_TYPE), POINTER :: solver
    INTEGER(INTG), INTENT(OUT) :: err
    TYPE(VARYING_STRING), INTENT(OUT) :: error
    !Local Variables
    TYPE(CONTROL_LOOP_WHILE_TYPE), POINTER :: iterativeLoop
    TYPE(EQUATIONS_SET_TYPE), POINTER :: equationsSet
    TYPE(FIELD_TYPE), POINTER :: dependentField,materialsField,independentField
    TYPE(SOLVER_EQUATIONS_TYPE), POINTER :: solverEquations  
    TYPE(SOLVER_MAPPING_TYPE), POINTER :: solverMapping 
    TYPE(SOLVER_TYPE), POINTER :: solver1D
    TYPE(FIELD_VARIABLE_TYPE), POINTER :: fieldVariable
    TYPE(DOMAIN_NODES_TYPE), POINTER :: domainNodes
    TYPE(VARYING_STRING) :: localError
    INTEGER(INTG) :: nodeNumber,nodeIdx,derivativeIdx,versionIdx,componentIdx,numberOfLocalNodes1D
    INTEGER(INTG) :: solver1dNavierStokesNumber,solverNumber,MPI_IERROR,timestep,iteration
    INTEGER(INTG) :: boundaryNumber,numberOfBoundaries,numberOfComputationalNodes
    REAL(DP) :: A0_PARAM,E_PARAM,H_PARAM,beta,pCellML,normalWave(2)
    REAL(DP) :: qPrevious,pPrevious,aPrevious,q1d,a1d,qError,aError,couplingTolerance
    LOGICAL :: boundaryNode,boundaryConverged(30),localConverged,MPI_LOGICAL
    LOGICAL, ALLOCATABLE :: globalConverged(:)

    ENTERS("NavierStokes_Couple1D0D",ERR,ERROR,*999)

    !Get solvers based on the problem type
    SELECT CASE(controlLoop%PROBLEM%specification(3))
    CASE(PROBLEM_COUPLED1D0D_NAVIER_STOKES_SUBTYPE, &
       & PROBLEM_COUPLED1D0D_ADV_NAVIER_STOKES_SUBTYPE, &
       & PROBLEM_STREE1D0D_NAVIER_STOKES_SUBTYPE, &
       & PROBLEM_STREE1D0D_ADV_NAVIER_STOKES_SUBTYPE)
      solverNumber = solver%GLOBAL_NUMBER
      ! In the Navier-Stokes/Characteristic subloop, the Navier-Stokes solver should be the second solver
      solver1dNavierStokesNumber=2
      versionIdx=1
      derivativeIdx=1
      IF(solverNumber == solver1dNavierStokesNumber) THEN
        solver1D=>controlLoop%SUB_LOOPS(2)%PTR%SOLVERS%SOLVERS(solver1dNavierStokesNumber)%PTR
        iterativeLoop=>controlLoop%WHILE_LOOP
        iteration = iterativeLoop%ITERATION_NUMBER
        timestep = controlLoop%PARENT_LOOP%TIME_LOOP%ITERATION_NUMBER
      ELSE 
        localError="The solver number of "//TRIM(NUMBER_TO_VSTRING(solverNumber,"*",err,error))// &
         & " does not correspond with the Navier-Stokes solver number for 1D-0D fluid coupling."
        CALL FlagError(localError,ERR,ERROR,*999)
      END IF
    CASE DEFAULT
      localError="Problem subtype "//TRIM(NUMBER_TO_VSTRING(controlLoop%PROBLEM%specification(3),"*",err,error))// &
        & " is not valid for 1D-0D Navier-Stokes fluid coupling."
      CALL FlagError(localError,ERR,ERROR,*999)
    END SELECT

    couplingTolerance = iterativeLoop%ABSOLUTE_TOLERANCE

    IF(ASSOCIATED(controlLoop)) THEN
      IF(ASSOCIATED(solver1D)) THEN
        IF(ASSOCIATED(controlLoop%PROBLEM)) THEN
          solverEquations=>solver1D%SOLVER_EQUATIONS
          IF(ASSOCIATED(solverEquations)) THEN
            solverMapping=>solverEquations%SOLVER_MAPPING
            IF(ASSOCIATED(solverMapping)) THEN
              equationsSet=>solverMapping%EQUATIONS_SETS(1)%PTR
              IF(ASSOCIATED(equationsSet)) THEN
                materialsField=>equationsSet%MATERIALS%MATERIALS_FIELD
                dependentField=>equationsSet%DEPENDENT%DEPENDENT_FIELD
                independentField=>equationsSet%INDEPENDENT%INDEPENDENT_FIELD
              ELSE
                CALL FlagError("Equations set is not associated.",err,error,*999)
              END IF
            ELSE
              CALL FlagError("Solver mapping is not associated.",err,error,*999)
            END IF
          ELSE
            CALL FlagError("Solver equations is not associated.",err,error,*999)
          END IF
        ELSE
          CALL FlagError("Problem is not associated.",err,error,*999)
        END IF
      ELSE
        CALL FlagError("Solver is not associated.",err,error,*999)
      END IF
    ELSE
      CALL FlagError("Control Loop is not associated.",err,error,*999)
    END IF

    !Get the number of local nodes
    domainNodes=>dependentField%DECOMPOSITION%DOMAIN(dependentField%DECOMPOSITION%MESH_COMPONENT_NUMBER)%PTR% &
      & TOPOLOGY%NODES
    IF(ASSOCIATED(domainNodes)) THEN
      numberOfLocalNodes1D=domainNodes%NUMBER_OF_NODES
    ELSE
      CALL FlagError("Domain nodes are not associated.",err,error,*999)
    END IF

    boundaryNumber = 0
    boundaryConverged = .TRUE.
    !!!--  L o o p   O v e r   L o c a l  N o d e s  --!!!
    DO nodeIdx=1,numberOfLocalNodes1D
      nodeNumber = domainNodes%NODES(nodeIdx)%local_number
      !Check for the boundary node
      boundaryNode=dependentField%DECOMPOSITION%DOMAIN(dependentField%DECOMPOSITION%MESH_COMPONENT_NUMBER)%PTR% &
        & TOPOLOGY%NODES%NODES(nodeNumber)%BOUNDARY_NODE

      !Get node characteristic wave direction (specifies inlet/outlet)
      DO componentIdx=1,2
        CALL Field_ParameterSetGetLocalNode(independentField,FIELD_U_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE, & 
         & versionIdx,derivativeIdx,nodeNumber,componentIdx,normalWave(componentIdx),err,error,*999)
      END DO

      !!!-- F i n d   B o u n d a r y   N o d e s --!!!
      IF(ABS(normalWave(1))>ZERO_TOLERANCE .AND. boundaryNode) THEN

        boundaryNumber = boundaryNumber + 1
        boundaryConverged(boundaryNumber) = .FALSE.
        !Get material parameters
        CALL Field_ParameterSetGetLocalNode(materialsField,FIELD_V_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE, &
          & versionIdx,derivativeIdx,nodeNumber,1,A0_PARAM,err,error,*999)  
        CALL Field_ParameterSetGetLocalNode(materialsField,FIELD_V_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE, &
          & versionIdx,derivativeIdx,nodeNumber,2,E_PARAM,err,error,*999)                
        CALL Field_ParameterSetGetLocalNode(materialsField,FIELD_V_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE, &
          & versionIdx,derivativeIdx,nodeNumber,3,H_PARAM,err,error,*999)                
        beta=(4.0_DP*SQRT(PI)*E_PARAM*H_PARAM)/(3.0_DP*A0_PARAM)     

        ! C u r r e n t   Q 1 D , A 1 D , p C e l l M L   V a l u e s
        ! ------------------------------------------------------------
        !Get Q1D
        CALL Field_ParameterSetGetLocalNode(dependentField,FIELD_U_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE, &
          & versionIdx,derivativeIdx,nodeNumber,1,q1d,err,error,*999)         
        !Get A1D
        CALL Field_ParameterSetGetLocalNode(dependentField,FIELD_U_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE, &
          & versionIdx,derivativeIdx,nodeNumber,2,a1d,err,error,*999)
        !Get pCellML
        CALL Field_ParameterSetGetLocalNode(dependentField,FIELD_U1_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE, &
          & versionIdx,derivativeIdx,nodeNumber,1,pCellML,err,error,*999)

        ! C h e c k  1 D / 0 D   C o n v e r g e n c e   f o r   t h i s   n o d e
        ! -------------------------------------------------------------------------
        IF(iteration == 1 .AND. timestep == 0) THEN
          ! Create the previous iteration field values type on the dependent field if it does not exist
          NULLIFY(fieldVariable)
          CALL FIELD_VARIABLE_GET(dependentField,FIELD_U_VARIABLE_TYPE,fieldVariable,ERR,ERROR,*999)
          IF(.NOT.ASSOCIATED(fieldVariable%PARAMETER_SETS%SET_TYPE(FIELD_PREVIOUS_ITERATION_VALUES_SET_TYPE)%PTR)) THEN
            CALL FIELD_PARAMETER_SET_CREATE(dependentField,FIELD_U_VARIABLE_TYPE, &
             & FIELD_PREVIOUS_ITERATION_VALUES_SET_TYPE,ERR,ERROR,*999)
          END IF
          NULLIFY(fieldVariable)
          CALL FIELD_VARIABLE_GET(dependentField,FIELD_U1_VARIABLE_TYPE,fieldVariable,ERR,ERROR,*999)
          IF(.NOT.ASSOCIATED(fieldVariable%PARAMETER_SETS%SET_TYPE(FIELD_PREVIOUS_ITERATION_VALUES_SET_TYPE)%PTR)) THEN
            CALL FIELD_PARAMETER_SET_CREATE(dependentField,FIELD_U1_VARIABLE_TYPE, &
             & FIELD_PREVIOUS_ITERATION_VALUES_SET_TYPE,ERR,ERROR,*999)
          END IF
        ELSE
          !Get previous Q1D 
          CALL Field_ParameterSetGetLocalNode(dependentField,FIELD_U_VARIABLE_TYPE,FIELD_PREVIOUS_ITERATION_VALUES_SET_TYPE, &
            & versionIdx,derivativeIdx,nodeNumber,1,qPrevious,err,error,*999)         
          !Get previous A1D 
          CALL Field_ParameterSetGetLocalNode(dependentField,FIELD_U_VARIABLE_TYPE,FIELD_PREVIOUS_ITERATION_VALUES_SET_TYPE, &
            & versionIdx,derivativeIdx,nodeNumber,2,aPrevious,err,error,*999)         
          !Get previous pCellML value
          CALL Field_ParameterSetGetLocalNode(dependentField,FIELD_U1_VARIABLE_TYPE,FIELD_PREVIOUS_ITERATION_VALUES_SET_TYPE, &
            & versionIdx,derivativeIdx,nodeNumber,1,pPrevious,err,error,*999)         
          ! Check if the boundary interface values have converged
          qError = ABS(qPrevious - q1d)
          aError = ABS(aPrevious - a1d)
          IF( qError < couplingTolerance .AND. aError < couplingTolerance) THEN
            boundaryConverged(boundaryNumber) = .TRUE.
          END IF
        END IF

        ! store current Q and p Boundary values as previous iteration value
        CALL FIELD_PARAMETER_SET_UPDATE_LOCAL_NODE(dependentField,FIELD_U_VARIABLE_TYPE, &
         & FIELD_PREVIOUS_ITERATION_VALUES_SET_TYPE,versionIdx,derivativeIdx,nodeNumber,1,q1d,err,error,*999)          
        CALL FIELD_PARAMETER_SET_UPDATE_LOCAL_NODE(dependentField,FIELD_U_VARIABLE_TYPE, &
         & FIELD_PREVIOUS_ITERATION_VALUES_SET_TYPE,versionIdx,derivativeIdx,nodeNumber,2,a1d,err,error,*999)          
        CALL FIELD_PARAMETER_SET_UPDATE_LOCAL_NODE(dependentField,FIELD_U1_VARIABLE_TYPE, &
         & FIELD_PREVIOUS_ITERATION_VALUES_SET_TYPE,versionIdx,derivativeIdx,nodeNumber,1,pCellML,err,error,*999)          

      END IF !Find boundary nodes
    END DO !Loop over nodes 
    numberOfBoundaries = boundaryNumber

    IF(solverNumber == solver1dNavierStokesNumber) THEN
      ! ------------------------------------------------------------------
      ! C h e c k   G l o b a l   C o u p l i n g   C o n v e r g e n c e
      ! ------------------------------------------------------------------
      ! Check whether all boundaries on the local process have converged
      IF(numberOfBoundaries == 0 .OR. ALL(boundaryConverged(1:numberOfBoundaries))) THEN
        localConverged = .TRUE.
      ELSE
        localConverged = .FALSE.
      END IF
      ! Need to check that boundaries have converged globally (on all domains) if this is a parallel problem
      numberOfComputationalNodes=COMPUTATIONAL_ENVIRONMENT%NUMBER_COMPUTATIONAL_NODES
      IF(numberOfComputationalNodes>1) THEN !use mpi
        !allocate array for mpi communication
        ALLOCATE(globalConverged(numberOfComputationalNodes),STAT=ERR) 
        IF(ERR/=0) CALL FlagError("Could not allocate global convergence check array.",ERR,ERROR,*999)
        CALL MPI_ALLGATHER(localConverged,1,MPI_LOGICAL,globalConverged,1,MPI_LOGICAL, &
         & COMPUTATIONAL_ENVIRONMENT%MPI_COMM,MPI_IERROR)
        CALL MPI_ERROR_CHECK("MPI_ALLGATHER",MPI_IERROR,ERR,ERROR,*999)
        IF(ALL(globalConverged)) THEN
          !CALL WRITE_STRING_VALUE(DIAGNOSTIC_OUTPUT_TYPE,"1D/0D coupling converged; # iterations: ", &
          !  & iteration,err,error,*999)
          iterativeLoop%CONTINUE_LOOP=.FALSE.
        END IF
        DEALLOCATE(globalConverged)
      ELSE
        IF(localConverged) THEN
          !CALL WRITE_STRING_VALUE(DIAGNOSTIC_OUTPUT_TYPE,"1D/0D coupling converged; # iterations: ", &
          !  & iteration,err,error,*999)
          iterativeLoop%CONTINUE_LOOP=.FALSE.
        END IF
      END IF

      ! If the solution hasn't converged, need to revert field values to pre-solve state
      ! before continued iteration. This will counteract the field updates that occur
      ! in SOLVER_DYNAMIC_MEAN_PREDICTED_CALCULATE. Ignore for initialisation
      IF(timestep == 0) THEN
        iterativeLoop%CONTINUE_LOOP=.FALSE.
      END IF
      IF(iterativeLoop%CONTINUE_LOOP .EQV. .TRUE. ) THEN
        CALL FIELD_PARAMETER_SETS_COPY(dependentField,equationsSet%EQUATIONS%EQUATIONS_MAPPING%DYNAMIC_MAPPING% &
         & DYNAMIC_VARIABLE_TYPE,FIELD_PREVIOUS_VALUES_SET_TYPE,FIELD_VALUES_SET_TYPE,1.0_DP,ERR,ERROR,*999)
        CALL FIELD_PARAMETER_SETS_COPY(dependentField,equationsSet%EQUATIONS%EQUATIONS_MAPPING%DYNAMIC_MAPPING% &
         & DYNAMIC_VARIABLE_TYPE,FIELD_PREVIOUS_RESIDUAL_SET_TYPE,FIELD_RESIDUAL_SET_TYPE,1.0_DP,ERR,ERROR,*999)
      END IF
    END IF

    EXITS("NavierStokes_Couple1D0D")
    RETURN
999 ERRORSEXITS("NavierStokes_Couple1D0D",err,error)
    RETURN 1

  END SUBROUTINE

  !
  !================================================================================================================================
  !

  !> Check convergence of 
  SUBROUTINE NavierStokes_CoupleCharacteristics(controlLoop,solver,err,error,*)

    !Argument variables
    TYPE(CONTROL_LOOP_TYPE), POINTER :: controlLoop
    TYPE(SOLVER_TYPE), POINTER :: solver
    INTEGER(INTG), INTENT(OUT) :: err
    TYPE(VARYING_STRING), INTENT(OUT) :: error
    !Local Variables
    TYPE(CONTROL_LOOP_WHILE_TYPE), POINTER :: iterativeLoop
    TYPE(DOMAIN_NODES_TYPE), POINTER :: domainNodes
    TYPE(EQUATIONS_SET_TYPE), POINTER :: equationsSet
    TYPE(FIELD_TYPE), POINTER :: dependentField,independentField,materialsField
    TYPE(SOLVER_EQUATIONS_TYPE), POINTER :: solverEquations  
    TYPE(SOLVER_MAPPING_TYPE), POINTER :: solverMapping 
    TYPE(SOLVER_TYPE), POINTER :: solver1DNavierStokes
    TYPE(VARYING_STRING) :: localError
    INTEGER(INTG) :: nodeNumber,nodeIdx,derivativeIdx,versionIdx,componentIdx,i
    INTEGER(INTG) :: solver1dNavierStokesNumber,solverNumber
    INTEGER(INTG) :: branchNumber,numberOfBranches,numberOfComputationalNodes,numberOfVersions
    INTEGER(INTG) :: MPI_IERROR,timestep,iteration,outputIteration
    REAL(DP) :: couplingTolerance,l2ErrorW(30),wPrevious(2,4),wNavierStokes(2,4),wCharacteristic(2,4),wError(2,4)
    REAL(DP) :: l2ErrorQ(100),qCharacteristic(4),qNavierStokes(4),wNext(2,4)
    REAL(DP) :: totalErrorWPrevious,startTime,stopTime,currentTime,timeIncrement
    REAL(DP) :: l2ErrorA(100),aCharacteristic(4),aNavierStokes(4),totalErrorW,totalErrorQ,totalErrorA
    REAL(DP) :: totalErrorMass,totalErrorMomentum
    REAL(DP) :: rho,alpha,normalWave,A0_PARAM,E_PARAM,H_PARAM,beta,aNew,penaltyCoeff
    LOGICAL :: branchConverged(100),localConverged,MPI_LOGICAL,boundaryNode,fluxDiverged
    LOGICAL, ALLOCATABLE :: globalConverged(:)

    ENTERS("NavierStokes_CoupleCharacteristics",ERR,ERROR,*999)

    SELECT CASE(controlLoop%PROBLEM%specification(3))
    CASE(PROBLEM_TRANSIENT1D_NAVIER_STOKES_SUBTYPE, &
       & PROBLEM_TRANSIENT1D_ADV_NAVIER_STOKES_SUBTYPE)
      solver1dNavierStokesNumber=2
      solver1DNavierStokes=>controlLoop%SOLVERS%SOLVERS(solver1dNavierStokesNumber)%PTR
      CALL CONTROL_LOOP_TIMES_GET(controlLoop,startTime,stopTime,currentTime,timeIncrement, &
       & timestep,outputIteration,ERR,ERROR,*999)
      iteration = controlLoop%WHILE_LOOP%ITERATION_NUMBER
      iterativeLoop=>controlLoop%WHILE_LOOP
    CASE(PROBLEM_COUPLED1D0D_NAVIER_STOKES_SUBTYPE, &
       & PROBLEM_COUPLED1D0D_ADV_NAVIER_STOKES_SUBTYPE, &
       & PROBLEM_STREE1D0D_NAVIER_STOKES_SUBTYPE, &
       & PROBLEM_STREE1D0D_ADV_NAVIER_STOKES_SUBTYPE)
      solver1dNavierStokesNumber=2
      solver1DNavierStokes=>controlLoop%PARENT_LOOP%SUB_LOOPS(2)%PTR%SOLVERS%SOLVERS(solver1dNavierStokesNumber)%PTR
      iterativeLoop=>controlLoop%WHILE_LOOP
      iteration = iterativeLoop%ITERATION_NUMBER
      timestep = controlLoop%PARENT_LOOP%PARENT_LOOP%TIME_LOOP%ITERATION_NUMBER
    CASE DEFAULT
      localError="Problem subtype "//TRIM(NUMBER_TO_VSTRING(controlLoop%PROBLEM%specification(3),"*",err,error))// &
        & " is not valid for 1D-0D Navier-Stokes fluid coupling."
      CALL FlagError(localError,ERR,ERROR,*999)
    END SELECT

    solverNumber = solver%GLOBAL_NUMBER
    couplingTolerance = iterativeLoop%ABSOLUTE_TOLERANCE

    IF(ASSOCIATED(controlLoop)) THEN
      IF(ASSOCIATED(solver1DNavierStokes)) THEN
        IF(ASSOCIATED(controlLoop%PROBLEM)) THEN
          solverEquations=>solver1DNavierStokes%SOLVER_EQUATIONS
          IF(ASSOCIATED(solverEquations)) THEN
            solverMapping=>solverEquations%SOLVER_MAPPING
            IF(ASSOCIATED(solverMapping)) THEN
              equationsSet=>solverMapping%EQUATIONS_SETS(1)%PTR
              IF(ASSOCIATED(equationsSet)) THEN
                dependentField=>equationsSet%DEPENDENT%DEPENDENT_FIELD
                independentField=>equationsSet%INDEPENDENT%INDEPENDENT_FIELD
                materialsField=>equationsSet%MATERIALS%MATERIALS_FIELD
              ELSE
                CALL FlagError("Equations set is not associated.",err,error,*999)
              END IF
            ELSE
              CALL FlagError("Solver mapping is not associated.",err,error,*999)
            END IF
          ELSE
            CALL FlagError("Solver equations is not associated.",err,error,*999)
          END IF
        ELSE
          CALL FlagError("Problem is not associated.",err,error,*999)
        END IF
      ELSE
        CALL FlagError("Solver is not associated.",err,error,*999)
      END IF
    ELSE
      CALL FlagError("Control Loop is not associated.",err,error,*999)
    END IF

    domainNodes=>dependentField%DECOMPOSITION%DOMAIN(dependentField%DECOMPOSITION%MESH_COMPONENT_NUMBER)%PTR% &
      & TOPOLOGY%NODES
    branchNumber = 0
    branchConverged = .TRUE.
    fluxDiverged = .FALSE.
    totalErrorQ = 0.0_DP
    totalErrorA = 0.0_DP
    totalErrorW = 0.0_DP
    totalErrorMass = 0.0_DP
    totalErrorMomentum = 0.0_DP
    totalErrorWPrevious = 0.0_DP
    l2ErrorQ = 0.0_DP
    l2ErrorA = 0.0_DP
    l2ErrorW = 0.0_DP

    ! Get material constants
    CALL FIELD_PARAMETER_SET_GET_CONSTANT(materialsField,FIELD_U_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE, &
      & 2,rho,err,error,*999)
    CALL FIELD_PARAMETER_SET_GET_CONSTANT(materialsField,FIELD_U_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE, &
      & 3,alpha,err,error,*999)
    CALL FIELD_PARAMETER_SET_GET_CONSTANT(equationsSet%EQUATIONS_SET_FIELD%EQUATIONS_SET_FIELD_FIELD,FIELD_U_VARIABLE_TYPE, &
      & FIELD_VALUES_SET_TYPE,1,penaltyCoeff,err,error,*999)

    !!!--  L o o p   O v e r   L o c a l  N o d e s  --!!!
    DO nodeIdx=1,domainNodes%NUMBER_OF_NODES
      nodeNumber = domainNodes%NODES(nodeIdx)%local_number
      derivativeIdx = 1
      numberOfVersions=domainNodes%NODES(nodeNumber)%DERIVATIVES(derivativeIdx)%numberOfVersions      
      boundaryNode=domainNodes%NODES(nodeNumber)%BOUNDARY_NODE

      !DEBUG
      CALL Field_ParameterSetGetLocalNode(independentField,FIELD_U_VARIABLE_TYPE, &
       & FIELD_VALUES_SET_TYPE,1,1,nodeNumber,1,normalWave,err,error,*999)            
      IF(ABS(normalWave) > ZERO_TOLERANCE) THEN
        branchNumber = branchNumber + 1
        branchConverged(branchNumber) = .FALSE.

        wError = 0.0_DP
        i = 0
        DO componentIdx=1,2
          DO versionIdx=1,numberOfVersions
            i = i +1
            CALL Field_ParameterSetGetLocalNode(independentField,FIELD_U_VARIABLE_TYPE, &
             & FIELD_VALUES_SET_TYPE,versionIdx,derivativeIdx,nodeNumber,componentIdx,normalWave,err,error,*999)            
            IF(ABS(normalWave)>ZERO_TOLERANCE) THEN

              ! Get the previously set characteristic (W) for this timestep-
              !  if this is the first iteration it will be based on extrapolated values
              !  otherwise it will come from the last iteration of this subroutine.
              CALL Field_ParameterSetGetLocalNode(dependentField,FIELD_V_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE, &
               & versionIdx,derivativeIdx,nodeNumber,componentIdx,wPrevious(componentIdx,versionIdx),err,error,*999)         

              !Get material parameters
              CALL Field_ParameterSetGetLocalNode(materialsField,FIELD_V_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE, &
                & versionIdx,derivativeIdx,nodeNumber,1,A0_PARAM,err,error,*999)  
              CALL Field_ParameterSetGetLocalNode(materialsField,FIELD_V_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE, &
                & versionIdx,derivativeIdx,nodeNumber,2,E_PARAM,err,error,*999)                
              CALL Field_ParameterSetGetLocalNode(materialsField,FIELD_V_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE, &
                & versionIdx,derivativeIdx,nodeNumber,3,H_PARAM,err,error,*999)                
              beta=(4.0_DP*SQRT(PI)*E_PARAM*H_PARAM)/(3.0_DP*A0_PARAM)     

              ! Get current Q,A values based on N-S solve
              CALL Field_ParameterSetGetLocalNode(dependentField,FIELD_U_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE, &
               & versionIdx,derivativeIdx,nodeNumber,1,qNavierStokes(versionIdx),err,error,*999)         
              CALL Field_ParameterSetGetLocalNode(dependentField,FIELD_U_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE, &
               & versionIdx,derivativeIdx,nodeNumber,2,aNavierStokes(versionIdx),err,error,*999)

              ! Calculate the characteristic based on the values converged upon by the 
              !  N-S solver at this iteration.
              wNavierStokes(componentIdx,versionIdx)= ((qNavierStokes(versionIdx)/aNavierStokes(versionIdx))+ &
               & normalWave*4.0_DP*SQRT(beta/(2.0_DP*rho))*(aNavierStokes(versionIdx)**(0.25_DP) - (A0_PARAM)**(0.25_DP)))

              IF(boundaryNode) THEN
                aNew = (1.0_DP/(beta/(2.0_DP*rho)))**2.0_DP*((wNavierStokes(componentIdx,versionIdx))/8.0_DP+ &
                 & SQRT(beta/(2.0_DP*rho))*((A0_PARAM)**0.25_DP))**4.0_DP
                CALL FIELD_PARAMETER_SET_UPDATE_LOCAL_NODE(dependentField,FIELD_U_VARIABLE_TYPE, &
                 & FIELD_PREVIOUS_VALUES_SET_TYPE,versionIdx,derivativeIdx,nodeNumber, &
                 & 2,aNew,err,error,*999)
              END IF

              ! Get characteristic (flux conserving) Q,A values
              CALL Field_ParameterSetGetLocalNode(dependentField,FIELD_U_VARIABLE_TYPE,FIELD_UPWIND_VALUES_SET_TYPE, &
               & versionIdx,derivativeIdx,nodeNumber,1,qCharacteristic(versionIdx),err,error,*999)         
              CALL Field_ParameterSetGetLocalNode(dependentField,FIELD_U_VARIABLE_TYPE,FIELD_UPWIND_VALUES_SET_TYPE, &
               & versionIdx,derivativeIdx,nodeNumber,2,aCharacteristic(versionIdx),err,error,*999)         

              ! Calculate the characteristic based on the upwind values
              wCharacteristic(componentIdx,versionIdx)= ((qCharacteristic(versionIdx)/aCharacteristic(versionIdx))+ &
               & normalWave*4.0_DP*SQRT((beta/(2.0_DP*rho)))*(aCharacteristic(versionIdx)**(0.25_DP) - (A0_PARAM)**(0.25_DP)))
            END IF
          END DO
        END DO

        ! Evaluate error between current and previous Q,A values
        IF(numberOfVersions > 1 ) THEN
          l2ErrorQ(branchNumber) = L2NORM(qNavierStokes-qCharacteristic)
          l2ErrorA(branchNumber) = L2NORM(aNavierStokes-aCharacteristic)
        END IF
        ! Check if the branch values have converged
        IF((ABS(l2ErrorQ(branchNumber)) < couplingTolerance) .AND. (ABS(l2ErrorA(branchNumber)) < couplingTolerance)) THEN
          branchConverged(branchNumber) = .TRUE.
        END IF
        totalErrorQ = totalErrorQ + l2ErrorQ(branchNumber)
        totalErrorA = totalErrorA + l2ErrorA(branchNumber)

        wNext = ((wNavierStokes + wCharacteristic)/2.0_DP)
        ! If N-S/C w values did not converge re-solve with new w.
        IF(numberOfVersions > 1) THEN
          DO componentIdx=1,2
            DO versionIdx=1,numberOfVersions
              CALL Field_ParameterSetGetLocalNode(independentField,FIELD_U_VARIABLE_TYPE, &
               & FIELD_VALUES_SET_TYPE,versionIdx,derivativeIdx,nodeNumber,componentIdx,normalWave,err,error,*999)            
              IF(ABS(normalWave)>ZERO_TOLERANCE) THEN
                !Update W value
                CALL FIELD_PARAMETER_SET_UPDATE_LOCAL_NODE(dependentField,FIELD_V_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE, &
                 & versionIdx,derivativeIdx,nodeNumber,componentIdx,wNext(componentIdx,versionIdx),err,error,*999)
              END IF
            END DO
          END DO
        END IF

      END IF !Find boundary nodes
    END DO !Loop over nodes 
    numberOfBranches = branchNumber

    ! ------------------------------------------------------------------
    ! C h e c k   G l o b a l   C o u p l i n g   C o n v e r g e n c e
    ! ------------------------------------------------------------------
    ! Check whether all branches on the local process have converged
    IF(numberOfBranches == 0 .OR. ALL(branchConverged(1:numberOfBranches))) THEN
      localConverged = .TRUE.
    ELSE
      localConverged = .FALSE.
    END IF
    ! Need to check that boundaries have converged globally (on all domains) if this is a parallel problem
    numberOfComputationalNodes=COMPUTATIONAL_ENVIRONMENT%NUMBER_COMPUTATIONAL_NODES
    IF(numberOfComputationalNodes>1) THEN !use mpi
      !allocate array for mpi communication
      ALLOCATE(globalConverged(numberOfComputationalNodes),STAT=ERR) 
      IF(ERR/=0) CALL FlagError("Could not allocate global convergence check array.",ERR,ERROR,*999)
      CALL MPI_ALLGATHER(localConverged,1,MPI_LOGICAL,globalConverged,1,MPI_LOGICAL, &
       & COMPUTATIONAL_ENVIRONMENT%MPI_COMM,MPI_IERROR)
      CALL MPI_ERROR_CHECK("MPI_ALLGATHER",MPI_IERROR,ERR,ERROR,*999)
      IF(ALL(globalConverged)) THEN
        !CALL WRITE_STRING_VALUE(DIAGNOSTIC_OUTPUT_TYPE,"Navier-Stokes/Characteristic converged; # iterations: ", &
        !  & iteration,err,error,*999)
        controlLoop%WHILE_LOOP%CONTINUE_LOOP=.FALSE.
      END IF
      DEALLOCATE(globalConverged)
    ELSE
      IF(localConverged) THEN
        !CALL WRITE_STRING_VALUE(DIAGNOSTIC_OUTPUT_TYPE,"Navier-Stokes/Characteristic converged; # iterations: ", &
        !  & iteration,err,error,*999)
        controlLoop%WHILE_LOOP%CONTINUE_LOOP=.FALSE.
      END IF
    END IF

    EXITS("NavierStokes_CoupleCharacteristics")
    RETURN
999 ERRORSEXITS("NavierStokes_CoupleCharacteristics",err,error)
    RETURN 1

  END SUBROUTINE NavierStokes_CoupleCharacteristics

  !
  !================================================================================================================================
  !

  !>Calculated the rate of deformation (shear rate) for a navier-stokes finite element equations set.
  SUBROUTINE NavierStokes_ShearRateCalculate(equationsSet,ERR,ERROR,*)

    !Argument variables
    TYPE(EQUATIONS_SET_TYPE), POINTER :: equationsSet !<A pointer to the equations set
    INTEGER(INTG), INTENT(OUT) :: err !<The error code
    TYPE(VARYING_STRING), INTENT(OUT) :: error !<The error string
    !Local Variables
    TYPE(EQUATIONS_TYPE), POINTER :: equations
    TYPE(DOMAIN_MAPPING_TYPE), POINTER :: elementsMapping
    TYPE(VARYING_STRING) :: localError
    TYPE(FIELD_VARIABLE_TYPE), POINTER :: dependentVariable
    TYPE(FIELD_VARIABLE_TYPE), POINTER :: fieldVariable
    TYPE(DECOMPOSITION_TYPE), POINTER :: decomposition
    TYPE(BASIS_TYPE), POINTER :: dependentBasis
    TYPE(QUADRATURE_SCHEME_TYPE), POINTER :: quadratureScheme
    TYPE(FIELD_INTERPOLATED_POINT_TYPE), POINTER :: dependentInterpolatedPoint
    TYPE(FIELD_INTERPOLATION_PARAMETERS_TYPE), POINTER :: dependentInterpolationParameters
    TYPE(FIELD_INTERPOLATED_POINT_TYPE), POINTER :: geometricInterpolatedPoint
    TYPE(FIELD_INTERPOLATED_POINT_METRICS_TYPE), POINTER :: pointMetrics
    TYPE(FIELD_TYPE), POINTER :: dependentField
    TYPE(FIELD_TYPE), POINTER :: materialsField
    INTEGER(INTG) :: elementIdx,decompositionLocalElementNumber
    INTEGER(INTG) :: gaussIdx
    INTEGER(INTG) :: meshComponentNumber,numberOfDimensions,i,j,userElementNumber
    INTEGER(INTG) :: localElementNumber,startElement,stopElement
    REAL(DP) :: gaussWeight,shearRate,secondInvariant,strainRate
    REAL(DP) :: dUdXi(3,3),dXidX(3,3),dUdX(3,3),dUdXTrans(3,3),rateOfDeformation(3,3),velocityGauss(3)
    REAL(DP) :: shearRateDefault
    LOGICAL :: ghostElement,elementExists,defaultUpdate

    ENTERS("NavierStokes_ShearRateCalculate",err,error,*999)

    CALL WRITE_STRING(GENERAL_OUTPUT_TYPE,"...Calculating shear rate...",ERR,ERROR,*999)

    NULLIFY(decomposition)
    NULLIFY(dependentBasis)
    NULLIFY(equations)
    NULLIFY(quadratureScheme)
    NULLIFY(fieldVariable)
    NULLIFY(dependentInterpolatedPoint)
    NULLIFY(dependentInterpolationParameters)
    NULLIFY(geometricInterpolatedPoint)
    NULLIFY(dependentField)
    NULLIFY(materialsField)

    ! Some preliminary sanity checks
    IF(ASSOCIATED(equationsSet)) THEN
      equations=>equationsSet%EQUATIONS
        IF(ASSOCIATED(equations)) THEN
          dependentField=>equationsSet%DEPENDENT%DEPENDENT_FIELD
          IF(.NOT.ASSOCIATED(dependentField)) THEN
            CALL FlagError("Dependent field is not associated.",err,error,*999)
          END IF
          materialsField=>equationsSet%MATERIALS%MATERIALS_FIELD
          IF(.NOT.ASSOCIATED(materialsField)) THEN
            CALL FlagError("Materials field is not associated.",err,error,*999)
          END IF
        ELSE
          CALL FlagError("Equations set equations is not associated.",err,error,*999)
        END IF
    ELSE
      CALL FlagError("Equations set is not associated.",err,error,*999)
    END IF

    SELECT CASE(equationsSet%specification(3))
    CASE(EQUATIONS_SET_CONSTITUTIVE_MU_NAVIER_STOKES_SUBTYPE)
      dependentVariable=>equations%EQUATIONS_MAPPING%NONLINEAR_MAPPING%RESIDUAL_VARIABLES(1)%PTR
      meshComponentNumber=dependentVariable%COMPONENTS(1)%MESH_COMPONENT_NUMBER
      !Get the mesh decomposition and mapping
      decomposition=>dependentVariable%FIELD%DECOMPOSITION
      elementsMapping=>decomposition%DOMAIN(decomposition%MESH_COMPONENT_NUMBER)%PTR%MAPPINGS%ELEMENTS
      fieldVariable=>equations%EQUATIONS_MAPPING%NONLINEAR_MAPPING%RESIDUAL_VARIABLES(1)%PTR
      numberOfDimensions=fieldVariable%NUMBER_OF_COMPONENTS - 1
      dependentInterpolatedPoint=>equations%INTERPOLATION%DEPENDENT_INTERP_POINT(dependentVariable%VARIABLE_TYPE)%PTR
      geometricInterpolatedPoint=>equations%INTERPOLATION%GEOMETRIC_INTERP_POINT(FIELD_U_VARIABLE_TYPE)%PTR
      defaultUpdate=.FALSE.

      ! Loop over internal and boundary elements, skipping ghosts
      startElement = elementsMapping%INTERNAL_START
      stopElement = elementsMapping%BOUNDARY_FINISH
      ! Loop over internal and boundary elements 
      DO elementIdx=startElement,stopElement
        localElementNumber=elementsMapping%DOMAIN_LIST(elementIdx)
        userElementNumber = elementsMapping%LOCAL_TO_GLOBAL_MAP(localElementNumber)
        !Check computational node for elementIdx
        elementExists=.FALSE.
        ghostElement=.TRUE.
        CALL DECOMPOSITION_TOPOLOGY_ELEMENT_CHECK_EXISTS(decomposition%TOPOLOGY, &
          & userElementNumber,elementExists,decompositionLocalElementNumber,ghostElement,ERR,ERROR,*999)              
        IF(ghostElement) THEN
          CALL WRITE_STRING_VALUE(DIAGNOSTIC_OUTPUT_TYPE,"Ghost: ",userElementNumber,err,error,*999)            
        END IF

        IF(elementExists) THEN
          dependentBasis=>decomposition%DOMAIN(meshComponentNumber)%PTR%TOPOLOGY%ELEMENTS%ELEMENTS(localElementNumber)%BASIS
          quadratureScheme=>dependentBasis%QUADRATURE%QUADRATURE_SCHEME_MAP(BASIS_DEFAULT_QUADRATURE_SCHEME)%PTR

          CALL FIELD_INTERPOLATION_PARAMETERS_ELEMENT_GET(FIELD_VALUES_SET_TYPE,localElementNumber,equations%INTERPOLATION% &
            & DEPENDENT_INTERP_PARAMETERS(FIELD_U_VARIABLE_TYPE)%PTR,err,error,*999)
          CALL FIELD_INTERPOLATION_PARAMETERS_ELEMENT_GET(FIELD_VALUES_SET_TYPE,localElementNumber,equations%INTERPOLATION% &
            & GEOMETRIC_INTERP_PARAMETERS(FIELD_U_VARIABLE_TYPE)%PTR,err,error,*999)

          ! Loop over gauss points
          DO gaussIdx=1,quadratureScheme%NUMBER_OF_GAUSS
            !Get interpolated velocity
            CALL FIELD_INTERPOLATE_GAUSS(FIRST_PART_DERIV,BASIS_DEFAULT_QUADRATURE_SCHEME,gaussIdx, &
              & dependentInterpolatedPoint,err,error,*999)
            CALL FIELD_INTERPOLATE_GAUSS(FIRST_PART_DERIV,BASIS_DEFAULT_QUADRATURE_SCHEME,gaussIdx, &
              & geometricInterpolatedPoint,err,error,*999)
            pointMetrics=>equations%INTERPOLATION%GEOMETRIC_INTERP_POINT_METRICS(FIELD_U_VARIABLE_TYPE)%PTR
            CALL FIELD_INTERPOLATED_POINT_METRICS_CALCULATE(COORDINATE_JACOBIAN_VOLUME_TYPE,pointMetrics,err,error,*999)
            gaussWeight=quadratureScheme%GAUSS_WEIGHTS(gaussIdx)
            !Interpolated values at gauss point
            dXidX=0.0_DP
            dUdXi=0.0_DP
            velocityGauss=dependentInterpolatedPoint%values(1:3,NO_PART_DERIV)

            dUdXi(1:3,1)=dependentInterpolatedPoint%VALUES(1:3,PART_DERIV_S1)
            dUdXi(1:3,2)=dependentInterpolatedPoint%VALUES(1:3,PART_DERIV_S2)
            IF(numberOfDimensions == 3) THEN
              dUdXi(1:3,3)=dependentInterpolatedPoint%VALUES(1:3,PART_DERIV_S3)
            ELSE
              dUdXi(1:3,3)=0.0_DP
            END IF
            dXidX=pointMetrics%DXI_DX(:,:)
            dUdX=0.0_DP
            dUdXTrans=0.0_DP
            strainRate=0.0_DP

            CALL MATRIX_PRODUCT(dUdXi,dXidX,dUdX,ERR,ERROR,*999) !dU/dX = dU/dxi * dxi/dX (deformation gradient tensor)
            CALL MATRIX_TRANSPOSE(dUdX,dUdXTrans,ERR,ERROR,*999)
            DO i=1,3
              DO j=1,3
                strainRate = strainRate + (dUdX(i,j)*dUdXTrans(i,j))
                rateOfDeformation(i,j) = (dUdX(i,j) + dUdXTrans(i,j))/2.0_DP
              END DO
            END DO            
            secondInvariant= - rateOfDeformation(1,2)**2.0_DP - &
               & rateOfDeformation(2,3)**2.0_DP - rateOfDeformation(1,3)**2.0_DP

            IF(secondInvariant > -1.0E-30_DP) THEN
              CALL WRITE_STRING_VALUE(DIAGNOSTIC_OUTPUT_TYPE, &
               & "WARNING: positive second invariant of rate of deformation tensor: ",secondInvariant,err,error,*999)
              CALL WRITE_STRING_VALUE(DIAGNOSTIC_OUTPUT_TYPE,"   Element number: ",userElementNumber,err,error,*999)
              CALL WRITE_STRING_VALUE(DIAGNOSTIC_OUTPUT_TYPE,"   Gauss point number: ",gaussIdx,err,error,*999)
              defaultUpdate=.TRUE.
              EXIT
            ELSE
              shearRate=SQRT(-4.0_DP*secondInvariant)
            END IF
            CALL Field_ParameterSetUpdateLocalGaussPoint(materialsField,FIELD_V_VARIABLE_TYPE, &
              & FIELD_VALUES_SET_TYPE,gaussIdx,localElementNumber,2,shearRate,ERR,ERROR,*999)

          END DO !gaussIdx
        END IF ! check for ghost element
        IF(defaultUpdate .EQV. .TRUE.) THEN
          EXIT
        END IF
      END DO !elementIdx

      IF(defaultUpdate .EQV. .TRUE.) THEN
        shearRateDefault=1.0E-10_DP
        CALL WRITE_STRING_VALUE(DIAGNOSTIC_OUTPUT_TYPE,"Setting default shear field values...", &
         & shearRateDefault,err,error,*999)
        CALL FIELD_COMPONENT_VALUES_INITIALISE(materialsField,FIELD_V_VARIABLE_TYPE, &
         & FIELD_VALUES_SET_TYPE,1,shearRateDefault,err,error,*999)
      END IF

    CASE DEFAULT
      localError="Equations set subtype "//TRIM(NUMBER_TO_VSTRING(equationsSet%specification(3),"*",ERR,ERROR))// &
        & " is not valid for shear rate calculation in a Navier-Stokes equation type of a classical field equations set class."
      CALL FlagError(localError,ERR,ERROR,*999)
    END SELECT

    EXITS("NavierStokes_ShearRateCalculate")
    RETURN
999 ERRORSEXITS("NavierStokes_ShearRateCalculate",ERR,ERROR)
    RETURN 1

  END SUBROUTINE NavierStokes_ShearRateCalculate

  !
  !================================================================================================================================
  !

  !>Pre-residual evaluation a navier-stokes finite element equations set.
  SUBROUTINE NavierStokes_FiniteElementPreResidualEvaluate(equationsSet,err,error,*)

    !Argument variables
    TYPE(EQUATIONS_SET_TYPE), POINTER :: equationsSet !<A pointer the equations set
    INTEGER(INTG), INTENT(OUT) :: err !<The error code
    TYPE(VARYING_STRING), INTENT(OUT) :: error !<The error string
    !Local Variables
    TYPE(VARYING_STRING) :: LOCAL_ERROR

    ENTERS("NavierStokes_FiniteElementPreResidualEvaluate",err,error,*999)

    IF(ASSOCIATED(equationsSet)) THEN
      SELECT CASE(equationsSet%specification(3))
      CASE(EQUATIONS_SET_CONSTITUTIVE_MU_NAVIER_STOKES_SUBTYPE)
        ! Shear rate should either be calculated here to update at each minor iteration
        ! or during post solve so it is updated once per timestep
        !CALL NavierStokes_ShearRateCalculate(equationsSet,err,error,*999)
      CASE(EQUATIONS_SET_STATIC_NAVIER_STOKES_SUBTYPE, &
         & EQUATIONS_SET_LAPLACE_NAVIER_STOKES_SUBTYPE, &
         & EQUATIONS_SET_TRANSIENT_NAVIER_STOKES_SUBTYPE, &
         & EQUATIONS_SET_OPTIMISED_NAVIER_STOKES_SUBTYPE, &
         & EQUATIONS_SET_ALE_NAVIER_STOKES_SUBTYPE, &
         & EQUATIONS_SET_PGM_NAVIER_STOKES_SUBTYPE, &
         & EQUATIONS_SET_QUASISTATIC_NAVIER_STOKES_SUBTYPE, &
         & EQUATIONS_SET_TRANSIENT_RBS_NAVIER_STOKES_SUBTYPE, &
         & EQUATIONS_SET_STATIC_RBS_NAVIER_STOKES_SUBTYPE, &
         & EQUATIONS_SET_MULTISCALE3D_NAVIER_STOKES_SUBTYPE, &
         & EQUATIONS_SET_TRANSIENT1D_ADV_NAVIER_STOKES_SUBTYPE, &
         & EQUATIONS_SET_TRANSIENT1D_NAVIER_STOKES_SUBTYPE, &
         & EQUATIONS_SET_COUPLED1D0D_NAVIER_STOKES_SUBTYPE, &
         & EQUATIONS_SET_COUPLED1D0D_ADV_NAVIER_STOKES_SUBTYPE)
        !Do nothing
      CASE DEFAULT
        LOCAL_ERROR="The third equations set specification of "// &
          & TRIM(NUMBER_TO_VSTRING(equationsSet%specification(3),"*",err,error))// &
          & " is not valid for a Navier-Stokes fluid mechanics equations set."
        CALL FlagError(LOCAL_ERROR,err,error,*999)
      END SELECT
    ELSE
      CALL FlagError("Equations set is not associated.",err,error,*999)
    END IF

    EXITS("NavierStokes_FiniteElementPreResidualEvaluate")
    RETURN
999 ERRORS("NavierStokes_FiniteElementPreResidualEvaluate",err,error)
    EXITS("NavierStokes_FiniteElementPreResidualEvaluate")
    RETURN 1

  END SUBROUTINE NavierStokes_FiniteElementPreResidualEvaluate

  !
  !================================================================================================================================
  !

  !>Runs after each control loop iteration
  SUBROUTINE NavierStokes_ControlLoopPostLoop(controlLoop,err,error,*)

    !Argument variables
    TYPE(CONTROL_LOOP_TYPE), POINTER :: controlLoop !<A pointer to the control loop.
    INTEGER(INTG), INTENT(OUT) :: err !<The error code
    TYPE(VARYING_STRING), INTENT(OUT) :: error !<The error string
    !Local Variables
    TYPE(SOLVER_TYPE), POINTER :: navierStokesSolver
    TYPE(FIELD_TYPE), POINTER :: dependentField
    TYPE(FIELD_VARIABLE_TYPE), POINTER :: fieldVariable
    TYPE(VARYING_STRING) :: localError

    ENTERS("NavierStokes_ControlLoopPostLoop",err,error,*999)

    NULLIFY(dependentField)
    NULLIFY(fieldVariable)

    IF(ASSOCIATED(controlLoop)) THEN
      SELECT CASE(controlLoop%PROBLEM%specification(3))
      CASE(PROBLEM_STATIC_NAVIER_STOKES_SUBTYPE, &
        &  PROBLEM_LAPLACE_NAVIER_STOKES_SUBTYPE, &
        &  PROBLEM_PGM_NAVIER_STOKES_SUBTYPE, &
        &  PROBLEM_QUASISTATIC_NAVIER_STOKES_SUBTYPE, & 
        &  PROBLEM_TRANSIENT_NAVIER_STOKES_SUBTYPE, &
        &  PROBLEM_TRANSIENT_RBS_NAVIER_STOKES_SUBTYPE, &
        &  PROBLEM_MULTISCALE_NAVIER_STOKES_SUBTYPE, &
        &  PROBLEM_ALE_NAVIER_STOKES_SUBTYPE)
        ! Do nothing
      CASE(PROBLEM_TRANSIENT1D_NAVIER_STOKES_SUBTYPE, &
        &  PROBLEM_TRANSIENT1D_ADV_NAVIER_STOKES_SUBTYPE)
        SELECT CASE(controlLoop%LOOP_TYPE)
        CASE(PROBLEM_CONTROL_SIMPLE_TYPE)
          ! Do nothing
        CASE(PROBLEM_CONTROL_TIME_LOOP_TYPE)
          ! Global time loop - export data
          navierStokesSolver=>controlLoop%SUB_LOOPS(1)%PTR%SOLVERS%SOLVERS(2)%PTR
          CALL NAVIER_STOKES_POST_SOLVE_OUTPUT_DATA(navierStokesSolver,err,error,*999)
        CASE(PROBLEM_CONTROL_WHILE_LOOP_TYPE)
          navierStokesSolver=>controlLoop%SOLVERS%SOLVERS(2)%PTR
          CALL NavierStokes_CoupleCharacteristics(controlLoop,navierStokesSolver,ERR,ERROR,*999)
        CASE DEFAULT
          localError="The control loop type of "//TRIM(NUMBER_TO_VSTRING(controlLoop%LOOP_TYPE,"*",err,error))// &
            & " is invalid for a Coupled 1D0D Navier-Stokes problem."
          CALL FlagError(localError,err,error,*999)
        END SELECT
      CASE(PROBLEM_COUPLED1D0D_NAVIER_STOKES_SUBTYPE, &
         & PROBLEM_COUPLED1D0D_ADV_NAVIER_STOKES_SUBTYPE, &
         & PROBLEM_STREE1D0D_NAVIER_STOKES_SUBTYPE, &
         & PROBLEM_STREE1D0D_ADV_NAVIER_STOKES_SUBTYPE)
        SELECT CASE(controlLoop%LOOP_TYPE)
        CASE(PROBLEM_CONTROL_SIMPLE_TYPE)
          ! CellML simple loop - do nothing 
        CASE(PROBLEM_CONTROL_TIME_LOOP_TYPE)
          ! Global time loop - export data
          navierStokesSolver=>controlLoop%SUB_LOOPS(1)%PTR%SUB_LOOPS(2)%PTR%SOLVERS%SOLVERS(2)%PTR
          CALL NAVIER_STOKES_POST_SOLVE_OUTPUT_DATA(navierStokesSolver,err,error,*999)
        CASE(PROBLEM_CONTROL_WHILE_LOOP_TYPE)
          ! Couple 1D/0D loop
          IF(controlLoop%CONTROL_LOOP_LEVEL==2) THEN
            navierStokesSolver=>controlLoop%SUB_LOOPS(2)%PTR%SOLVERS%SOLVERS(2)%PTR
            ! update 1D/0D coupling parameters and check convergence
            CALL NavierStokes_Couple1D0D(controlLoop,navierStokesSolver,err,error,*999)
          ! Couple Navier-Stokes/Characteristics loop
          ELSE IF(controlLoop%CONTROL_LOOP_LEVEL==3) THEN
            navierStokesSolver=>controlLoop%SOLVERS%SOLVERS(2)%PTR
            CALL NavierStokes_CoupleCharacteristics(controlLoop,navierStokesSolver,ERR,ERROR,*999)
          ELSE
            localError="The while loop level of "//TRIM(NUMBER_TO_VSTRING(controlLoop%CONTROL_LOOP_LEVEL,"*",err,error))// &
              & " is invalid for a Coupled 1D0D Navier-Stokes problem."
            CALL FlagError(localError,err,error,*999)
          END IF
        CASE DEFAULT
          localError="The control loop type of "//TRIM(NUMBER_TO_VSTRING(controlLoop%LOOP_TYPE,"*",err,error))// &
            & " is invalid for a Coupled 1D0D Navier-Stokes problem."
          CALL FlagError(localError,err,error,*999)
        END SELECT
      CASE DEFAULT
        localError="Problem subtype "//TRIM(NUMBER_TO_VSTRING(controlLoop%PROBLEM%specification(3),"*",err,error))// &
          & " is not valid for a Navier-Stokes fluid type of a fluid mechanics problem class."
        CALL FlagError(localError,err,error,*999)
      END SELECT
    ELSE
      CALL FlagError("Control loop is not associated.",err,error,*999)
    END IF

    EXITS("NavierStokes_ControlLoopPostLoop")
    RETURN
999 ERRORSEXITS("NavierStokes_ControlLoopPostLoop",err,error)
    RETURN 1
    
  END SUBROUTINE NavierStokes_ControlLoopPostLoop

  !
  !================================================================================================================================
  !

  !>Updates boundary conditions for multiscale fluid problems
  SUBROUTINE NavierStokes_UpdateMultiscaleBoundary(solver,err,error,*)

    !Argument variables
    TYPE(SOLVER_TYPE), POINTER :: solver
    INTEGER(INTG), INTENT(OUT) :: err
    TYPE(VARYING_STRING), INTENT(OUT) :: error
    !Local Variables
    TYPE(BOUNDARY_CONDITIONS_TYPE), POINTER :: boundaryConditions
    TYPE(BOUNDARY_CONDITIONS_VARIABLE_TYPE), POINTER :: boundaryConditionsVariable
    TYPE(CONTROL_LOOP_TYPE), POINTER :: controlLoop,parentLoop,streeLoop
    TYPE(DOMAIN_TYPE), POINTER :: dependentDomain
    TYPE(EQUATIONS_SET_TYPE), POINTER :: equationsSet,streeEquationsSet
    TYPE(EQUATIONS_TYPE), POINTER :: equations,streeEquations
    TYPE(FIELD_TYPE), POINTER :: dependentField,materialsField,streeMaterialsField,independentField,geometricField
    TYPE(FIELD_VARIABLE_TYPE), POINTER :: fieldVariable
    TYPE(SOLVER_EQUATIONS_TYPE), POINTER :: solverEquations,streeSolverEquations
    TYPE(SOLVER_MAPPING_TYPE), POINTER :: solverMapping,streeSolverMapping
    TYPE(SOLVERS_TYPE), POINTER :: solvers
    TYPE(SOLVER_TYPE), POINTER :: streeSolver
    TYPE(VARYING_STRING) :: localError
    REAL(DP) :: rho,A0,H0,E,beta,pExternal,lengthScale,timeScale,massScale,currentTime,timeIncrement
    REAL(DP) :: pCellml,qCellml,ABoundary,W1,W2,ACellML,normalWave(2,4)
    REAL(DP), POINTER :: Impedance(:),Flow(:)
    INTEGER(INTG) :: nodeIdx,versionIdx,derivativeIdx,componentIdx,numberOfVersions,numberOfLocalNodes
    INTEGER(INTG) :: dependentDof,boundaryConditionType,k

    ENTERS("NavierStokes_UpdateMultiscaleBoundary",err,error,*999)

    NULLIFY(dependentDomain)
    NULLIFY(equationsSet)
    NULLIFY(equations)
    NULLIFY(geometricField)
    NULLIFY(dependentField)
    NULLIFY(independentField)
    NULLIFY(materialsField)
    NULLIFY(fieldVariable)
    NULLIFY(solverEquations)
    NULLIFY(solverMapping)

    ! Preliminary checks; get field and domain pointers
    IF(ASSOCIATED(solver)) THEN
      solvers=>solver%SOLVERS
      IF(ASSOCIATED(solvers)) THEN
        controlLoop=>solvers%CONTROL_LOOP
        parentLoop=>controlLoop%PARENT_LOOP
        streeLoop=>parentLoop%SUB_LOOPS(1)%PTR
        streeSolver=>streeLoop%SOLVERS%SOLVERS(1)%PTR
        CALL CONTROL_LOOP_CURRENT_TIMES_GET(controlLoop, &
          & currentTime,timeIncrement,ERR,ERROR,*999)
        IF(ASSOCIATED(controlLoop%PROBLEM)) THEN
          SELECT CASE(controlLoop%PROBLEM%specification(3))
          CASE(PROBLEM_COUPLED1D0D_NAVIER_STOKES_SUBTYPE, &
             & PROBLEM_COUPLED1D0D_ADV_NAVIER_STOKES_SUBTYPE, &
             & PROBLEM_TRANSIENT1D_NAVIER_STOKES_SUBTYPE, &
             & PROBLEM_TRANSIENT1D_ADV_NAVIER_STOKES_SUBTYPE)
            solverEquations=>solver%SOLVER_EQUATIONS
            IF(ASSOCIATED(solverEquations)) THEN
              solverMapping=>solverEquations%SOLVER_MAPPING
              IF(ASSOCIATED(solverMapping)) THEN
                equationsSet=>solverMapping%EQUATIONS_SETS(1)%PTR
                IF(ASSOCIATED(equationsSet)) THEN
                  equations=>equationsSet%EQUATIONS
                  IF(ASSOCIATED(equations)) THEN
                    geometricField=>equationsSet%GEOMETRY%GEOMETRIC_FIELD
                    independentField=>equationsSet%INDEPENDENT%INDEPENDENT_FIELD
                    dependentField=>equationsSet%DEPENDENT%DEPENDENT_FIELD
                    IF(ASSOCIATED(dependentField)) THEN
                      dependentDomain=>dependentField%DECOMPOSITION%DOMAIN(dependentField% &
                        & DECOMPOSITION%MESH_COMPONENT_NUMBER)%PTR
                      IF(.NOT.ASSOCIATED(dependentDomain)) THEN
                        CALL FlagError("Dependent domain is not associated.",err,error,*999)
                      END IF
                    ELSE
                      CALL FlagError("Geometric field is not associated.",err,error,*999)
                    END IF
                    materialsField=>equations%INTERPOLATION%MATERIALS_FIELD
                    IF(.NOT.ASSOCIATED(materialsField)) THEN
                      CALL FlagError("Materials field is not associated.",err,error,*999)
                    END IF
                  ELSE
                    CALL FlagError("Equations set equations is not associated.",err,error,*999)
                  END IF
                ELSE
                  CALL FlagError("Equations set is not associated.",err,error,*999)
                END IF
              ELSE
                CALL FlagError("Solver mapping is not associated.",err,error,*999)
              END IF
            ELSE
              CALL FlagError("Solver equations is not associated.",err,error,*999)
            END IF
          CASE(PROBLEM_STREE1D0D_NAVIER_STOKES_SUBTYPE, &
             & PROBLEM_STREE1D0D_ADV_NAVIER_STOKES_SUBTYPE)
            solverEquations=>solver%SOLVER_EQUATIONS
            streeSolverEquations=>streeSolver%SOLVER_EQUATIONS
            IF(ASSOCIATED(solverEquations)) THEN
              solverMapping=>solverEquations%SOLVER_MAPPING
              streeSolverMapping=>streeSolverEquations%SOLVER_MAPPING
              IF(ASSOCIATED(solverMapping)) THEN
                equationsSet=>solverMapping%EQUATIONS_SETS(1)%PTR
                streeEquationsSet=>streeSolverMapping%EQUATIONS_SETS(1)%PTR
                IF(ASSOCIATED(equationsSet)) THEN
                  equations=>equationsSet%EQUATIONS
                  streeEquations=>streeEquationsSet%EQUATIONS
                  IF(ASSOCIATED(equations)) THEN
                    geometricField=>equationsSet%GEOMETRY%GEOMETRIC_FIELD
                    independentField=>equationsSet%INDEPENDENT%INDEPENDENT_FIELD
                    dependentField=>equationsSet%DEPENDENT%DEPENDENT_FIELD
                    streeMaterialsField=>streeEquationsSet%MATERIALS%MATERIALS_FIELD
                    IF(ASSOCIATED(dependentField)) THEN
                      dependentDomain=>dependentField%DECOMPOSITION%DOMAIN(dependentField% &
                        & DECOMPOSITION%MESH_COMPONENT_NUMBER)%PTR
                      IF(.NOT.ASSOCIATED(dependentDomain)) THEN
                        CALL FlagError("Dependent domain is not associated.",err,error,*999)
                      END IF
                    ELSE
                      CALL FlagError("Geometric field is not associated.",err,error,*999)
                    END IF
                    materialsField=>equations%INTERPOLATION%MATERIALS_FIELD
                    IF(.NOT.ASSOCIATED(materialsField)) THEN
                      CALL FlagError("Materials field is not associated.",err,error,*999)
                    END IF
                  ELSE
                    CALL FlagError("Equations set equations is not associated.",err,error,*999)
                  END IF
                ELSE
                  CALL FlagError("Equations set is not associated.",err,error,*999)
                END IF
              ELSE
                CALL FlagError("Solver mapping is not associated.",err,error,*999)
              END IF
            ELSE
              CALL FlagError("Solver equations is not associated.",err,error,*999)
            END IF
          CASE DEFAULT
           localError="The third problem specification of "// &
             & TRIM(NUMBER_TO_VSTRING(controlLoop%PROBLEM%specification(3),"*",err,error))// &
             & " is not valid for boundary flux calculation."
           CALL FlagError(localError,ERR,ERROR,*999)
          END SELECT
        ELSE
          CALL FlagError("Problem is not associated.",err,error,*999)
        END IF
      ELSE
        CALL FlagError("Solvers is not associated.",err,error,*999)
      END IF
    ELSE
      CALL FlagError("Solver is not associated.",err,error,*999)
    END IF
              
    SELECT CASE(equationsSet%specification(3))
    !!!-- 1 D    E q u a t i o n s   S e t --!!! 
    CASE(EQUATIONS_SET_TRANSIENT1D_NAVIER_STOKES_SUBTYPE, &
       & EQUATIONS_SET_COUPLED1D0D_NAVIER_STOKES_SUBTYPE, &
       & EQUATIONS_SET_TRANSIENT1D_ADV_NAVIER_STOKES_SUBTYPE, &
       & EQUATIONS_SET_COUPLED1D0D_ADV_NAVIER_STOKES_SUBTYPE)

      independentField=>equationsSet%INDEPENDENT%INDEPENDENT_FIELD
      numberOfLocalNodes=dependentDomain%TOPOLOGY%NODES%NUMBER_OF_NODES
      derivativeIdx=1
      !Get constant material parameters
      CALL FIELD_PARAMETER_SET_GET_CONSTANT(materialsField,FIELD_U_VARIABLE_TYPE, &
        & FIELD_VALUES_SET_TYPE,2,rho,err,error,*999)
      CALL FIELD_PARAMETER_SET_GET_CONSTANT(materialsField,FIELD_U_VARIABLE_TYPE, &
        & FIELD_VALUES_SET_TYPE,4,pExternal,err,error,*999)
      !Get materials scale factors
      CALL FIELD_PARAMETER_SET_GET_CONSTANT(materialsField,FIELD_U_VARIABLE_TYPE, &
        & FIELD_VALUES_SET_TYPE,5,lengthScale,err,error,*999)
      CALL FIELD_PARAMETER_SET_GET_CONSTANT(materialsField,FIELD_U_VARIABLE_TYPE, &
        & FIELD_VALUES_SET_TYPE,6,timeScale,err,error,*999)
      CALL FIELD_PARAMETER_SET_GET_CONSTANT(materialsField,FIELD_U_VARIABLE_TYPE, &
        & FIELD_VALUES_SET_TYPE,7,massScale,err,error,*999)

      !!!--  L o o p   o v e r   l o c a l    n o d e s  --!!!
      DO nodeIdx=1,numberOfLocalNodes
        numberOfVersions=dependentDomain%TOPOLOGY%NODES%NODES(nodeIdx)%DERIVATIVES(derivativeIdx)%numberOfVersions

        !Get normal wave direction
        normalWave=0.0_DP
        DO componentIdx=1,2
          DO versionIdx=1,numberOfVersions
            CALL Field_ParameterSetGetLocalNode(independentField,FIELD_U_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE,versionIdx, &
             & derivativeIdx,nodeIdx,componentIdx,normalWave(componentIdx,versionIdx),err,error,*999)
          END DO
        END DO
        !!!-- F i n d   b o u n d a r y    n o d e s --!!!
        IF(ABS(normalWave(1,1)) > ZERO_TOLERANCE .OR. ABS(normalWave(2,1))> ZERO_TOLERANCE) THEN
          IF(numberOfVersions == 1 .AND. L2NORM(normalWave(:,1)) > ZERO_TOLERANCE) THEN
            versionIdx = 1
            !Get material parameters
            CALL Field_ParameterSetGetLocalNode(materialsField,FIELD_V_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE,versionIdx, &
             & derivativeIdx,nodeIdx,1,A0,err,error,*999) 
            CALL Field_ParameterSetGetLocalNode(materialsField,FIELD_V_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE,versionIdx, &
             & derivativeIdx,nodeIdx,2,E,err,error,*999) 
            CALL Field_ParameterSetGetLocalNode(materialsField,FIELD_V_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE,versionIdx, &
             & derivativeIdx,nodeIdx,3,H0,err,error,*999) 
            beta=(4.0_DP*(SQRT(PI))*E*H0)/(3.0_DP*A0)
            ! Get the boundary condition type for the dependent field primitive variables (Q,A)
            boundaryConditions=>solverEquations%BOUNDARY_CONDITIONS
            NULLIFY(fieldVariable)
            CALL FIELD_VARIABLE_GET(dependentField,FIELD_U_VARIABLE_TYPE,fieldVariable,err,error,*999)
            dependentDof = fieldVariable%COMPONENTS(2)%PARAM_TO_DOF_MAP% &
             & NODE_PARAM2DOF_MAP%NODES(nodeIdx)%DERIVATIVES(derivativeIdx)%VERSIONS(versionIdx)
            CALL BOUNDARY_CONDITIONS_VARIABLE_GET(boundaryConditions, &
             & fieldVariable,boundaryConditionsVariable,err,error,*999)
            boundaryConditionType=boundaryConditionsVariable%CONDITION_TYPES(dependentDof)                       
            SELECT CASE(boundaryConditionType)

            ! N o n - r e f l e c t i n g   B o u n d a r y
            ! ----------------------------------------------------
            CASE(BOUNDARY_CONDITION_FIXED_NONREFLECTING)
              ! Outlet - set W2 to 0, get W1 from the extrapolated value
              IF(normalWave(1,1) > 0.0_DP) THEN
                CALL Field_ParameterSetGetLocalNode(dependentField,FIELD_V_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE, &
                 & versionIdx,derivativeIdx,nodeIdx,1,W1,err,error,*999)                    
                W2 = 0.0_DP
              ! Inlet - set W1 to 0, get W2 from the extrapolated value
              ELSE
                W1 = 0.0_DP
                CALL Field_ParameterSetGetLocalNode(dependentField,FIELD_V_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE, &
                 & versionIdx,derivativeIdx,nodeIdx,2,W2,err,error,*999)                    
              END IF
              ! Calculate new area value based on W1, W2 and update dof
              ABoundary = (((2.0_DP*rho)/(beta))**2.0_DP)* &
               & (((W1-W2)/8.0_DP+SQRT(beta/(2.0_DP*rho))*((A0)**0.25_DP))**4.0_DP)
              CALL FIELD_PARAMETER_SET_UPDATE_LOCAL_NODE(dependentField,FIELD_U_VARIABLE_TYPE, &
               & FIELD_VALUES_SET_TYPE,versionIdx,derivativeIdx,nodeIdx,2,ABoundary,err,error,*999)

            ! C o u p l e d   C e l l M L  ( 0 D )   B o u n d a r y
            ! ------------------------------------------------------------
            CASE(BOUNDARY_CONDITION_FIXED_CELLML)
              !Get qCellML used in pCellML calculation
              CALL Field_ParameterSetGetLocalNode(dependentField,FIELD_U_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE, &
                & versionIdx,derivativeIdx,nodeIdx,1,QCellML,err,error,*999)                    
              !Get pCellML if this is a coupled problem
              CALL Field_ParameterSetGetLocalNode(dependentField,FIELD_U1_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE, &
                & versionIdx,derivativeIdx,nodeIdx,2,pCellml,err,error,*999)                    
              ! Convert pCellML from SI base units specified in CellML file to scaled units (e.g., kg/(m.s^2) --> g/(mm.ms^2))
              pCellml = pCellml*massScale/(lengthScale*(timeScale**2.0_DP))
              ! Convert pCellML --> A0D 
              ACellML=((pCellml-pExternal)/beta+SQRT(A0))**2.0_DP
              !  O u t l e t
              IF(normalWave(1,1) > 0.0_DP) THEN
                CALL Field_ParameterSetGetLocalNode(dependentField,FIELD_V_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE, &
                 & versionIdx,derivativeIdx,nodeIdx,1,W1,err,error,*999)                    
                ! Calculate W2 from 0D domain
                W2 = QCellml/ACellml - 4.0_DP*SQRT(beta/(2.0_DP*rho))*(ACellml**0.25_DP - A0**0.25_DP)
              !  I n l e t
              ELSE
                ! Calculate W1 from 0D domain
                W1 = QCellml/ACellml + 4.0_DP*SQRT(beta/(2.0_DP*rho))*(ACellml**0.25_DP - A0**0.25_DP)
                ! Calculate W2 from 1D domain
                CALL Field_ParameterSetGetLocalNode(dependentField,FIELD_V_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE, &
                 & versionIdx,derivativeIdx,nodeIdx,2,W2,err,error,*999)                    
              END IF
              ! Calculate new area value based on W1,W2 and update dof
              ABoundary = (((2.0_DP*rho)/(beta))**2.0_DP)* &
                & (((W1-W2)/8.0_DP+SQRT(beta/(2.0_DP*rho))*((A0)**0.25_DP))**4.0_DP)
              CALL FIELD_PARAMETER_SET_UPDATE_LOCAL_NODE(dependentField,FIELD_U_VARIABLE_TYPE, &
                & FIELD_VALUES_SET_TYPE,versionIdx,derivativeIdx,nodeIdx,2,ABoundary,err,error,*999)

            ! S t r u c t u r e d   T r e e   B o u n d a r y
            ! ------------------------------------------------------------
            CASE(BOUNDARY_CONDITION_FIXED_STREE)
              NULLIFY(Impedance)
              NULLIFY(Flow)
              !Get qCellML used in pCellML calculation
              CALL Field_ParameterSetGetLocalNode(dependentField,FIELD_U_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE, &
                & versionIdx,derivativeIdx,nodeIdx,1,QCellML,err,error,*999)
              !Get flow function
              CALL FIELD_PARAMETER_SET_DATA_GET(streeMaterialsField,FIELD_U_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE, &
                & Impedance,err,error,*999)
              !Get impedance function
              CALL FIELD_PARAMETER_SET_DATA_GET(streeMaterialsField,FIELD_V_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE, &
                & Flow,err,error,*999)
              pCellml = 0.0_DP
              DO k=1,size(Flow)
                pCellml=pCellml+Flow(k)*Impedance(k)*timeIncrement
              END DO
              ! Convert pCellML --> A0D 
              ACellML=((pCellml-pExternal)/beta+SQRT(A0))**2.0_DP
              !  O u t l e t
              IF(normalWave(1,1) > 0.0_DP) THEN
                CALL Field_ParameterSetGetLocalNode(dependentField,FIELD_V_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE, &
                  & versionIdx,derivativeIdx,nodeIdx,1,W1,err,error,*999)                    
                ! Calculate W2 from 0D domain
                W2 = QCellml/ACellml-4.0_DP*SQRT(beta/(2.0_DP*rho))*(ACellml**0.25_DP-A0**0.25_DP)
              !  I n l e t
              ELSE
                ! Calculate W1 from 0D domain
                W1 = QCellml/ACellml+4.0_DP*SQRT(beta/(2.0_DP*rho))*(ACellml**0.25_DP-A0**0.25_DP)
                ! Calculate W2 from 1D domain
                CALL Field_ParameterSetGetLocalNode(dependentField,FIELD_V_VARIABLE_TYPE,FIELD_VALUES_SET_TYPE, &
                  & versionIdx,derivativeIdx,nodeIdx,2,W2,err,error,*999)                    
              END IF
              ! Calculate new area value based on W1, W2 and update dof
              ABoundary = (((2.0_DP*rho)/(beta))**2.0_DP)* &
               & (((W1-W2)/8.0_DP+SQRT(beta/(2.0_DP*rho))*((A0)**0.25_DP))**4.0_DP)
              CALL FIELD_PARAMETER_SET_UPDATE_LOCAL_NODE(dependentField,FIELD_U_VARIABLE_TYPE, &
               & FIELD_VALUES_SET_TYPE,versionIdx,derivativeIdx,nodeIdx,2,ABoundary,err,error,*999)

            CASE(BOUNDARY_CONDITION_FREE, &
               & BOUNDARY_CONDITION_FIXED, &
               & BOUNDARY_CONDITION_FIXED_INLET, &
               & BOUNDARY_CONDITION_FIXED_OUTLET, &
               & BOUNDARY_CONDITION_FIXED_FITTED)
              ! Do nothing

            CASE DEFAULT
              localError="The boundary conditions type "//TRIM(NUMBER_TO_VSTRING(boundaryConditionType,"*",err,error))// &
               & " is not valid for a coupled characteristic problem."
              CALL FlagError(localError,err,error,*999)
            END SELECT

          END IF ! boundary node
        END IF ! branch or boundary node
      END DO !Loop over nodes

    !!!-- 3 D    E q u a t i o n s   S e t --!!! 
    CASE(EQUATIONS_SET_STATIC_NAVIER_STOKES_SUBTYPE, &
       & EQUATIONS_SET_LAPLACE_NAVIER_STOKES_SUBTYPE, &
       & EQUATIONS_SET_STATIC_RBS_NAVIER_STOKES_SUBTYPE, &
       & EQUATIONS_SET_TRANSIENT_NAVIER_STOKES_SUBTYPE, &
       & EQUATIONS_SET_ALE_NAVIER_STOKES_SUBTYPE, &
       & EQUATIONS_SET_PGM_NAVIER_STOKES_SUBTYPE, &
       & EQUATIONS_SET_QUASISTATIC_NAVIER_STOKES_SUBTYPE, &
       & EQUATIONS_SET_TRANSIENT_RBS_NAVIER_STOKES_SUBTYPE, &
       & EQUATIONS_SET_MULTISCALE3D_NAVIER_STOKES_SUBTYPE)
      ! Do nothing

    CASE DEFAULT
      localError="Equations set subtype "//TRIM(NUMBER_TO_VSTRING(equationsSet%specification(3),"*",err,error))// &
       & " is not valid for a Navier-Stokes equation type of a fluid mechanics equations set class."
      CALL FlagError(localError,err,error,*999)
    END SELECT

    EXITS("NavierStokes_UpdateMultiscaleBoundary")
    RETURN
999 ERRORSEXITS("NavierStokes_UpdateMultiscaleBoundary",err,error)
    RETURN 1
    
  END SUBROUTINE NavierStokes_UpdateMultiscaleBoundary

  !
  !================================================================================================================================
  !

END MODULE NAVIER_STOKES_EQUATIONS_ROUTINES
