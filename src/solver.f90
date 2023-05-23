module solver_mod

    ! This module contains all the procedures for the setup of the solver.
    ! The subroutine advance_solution is a general subroutine which will point
    ! to the requested solver.

    use precision_mod, only : dp
    use grid_mod     , only : grid

    implicit none

    interface
        subroutine advance_solver(comp_grid, step, dt)
            use precision_mod, only : dp
            use grid_mod     , only : grid
            type(grid), intent(in   ) :: comp_grid
            integer   , intent(in   ) :: step
            real(dp)  , intent(inout) :: dt
        end subroutine advance_solver

        subroutine solver_status(log_id, step, time, dt)
            use precision_mod, only : dp
            integer , intent(in) :: log_id, step
            real(dp), intent(in) :: time, dt
        end subroutine solver_status
    end interface

    procedure(advance_solver), pointer :: advance_solution => Null()
    procedure(solver_status) , pointer :: print_solver_status => Null()

contains

    !==============================================================================================
    subroutine init_solver(comp_grid)

        ! Perform all preliminary operations before start the simulation

        use poisson_mod      , only : init_poisson_solver
        use navier_stokes_mod, only : allocate_navier_stokes_fields, phi, navier_stokes_solver
        use navier_stokes_mod, only : print_navier_stokes_solver_status
#if defined(MF) || defined(NN)
        use navier_stokes  , only : constant_viscosity
#endif
#ifdef MF
        use navier_stokes  , only : rho, mu
        use multiphase     , only : allocate_multiphase_fields, update_material_properties
        use multiphase     , only : rho_0, rho_1, rhomin, irhomin, advect_interface
        use volume_of_fluid, only : allocate_vof_fields, get_vof_from_distance, vof, advect_vof
#endif
#ifdef IBM
        use ibm
#endif
#ifdef FSI
        use navier_stokes  , only : g
        use fsi
#endif
        ! In/out variables
        type(grid), intent(in   ) :: comp_grid

        ! Allocate fields for solving Navier-Stokes equation
        call allocate_navier_stokes_fields(comp_grid)

        ! Initialize the Poisson solver
        call init_Poisson_Solver(phi)

        ! Select the solver
#ifdef FSI      
        ! Point to the weak coupling FSI solver
        advance_solution => weak_coupling_solver

        ! Point the Navier-Stokes solver print status
        print_solver_status => print_navier_stokes_solver_status

#else
        ! Point to the Navier-Stokes solver
        advance_solution => navier_stokes_solver

        ! Point the Navier-Stokes solver print status
        print_solver_status => print_navier_stokes_solver_status
#endif

#if defined(MF) || defined(NN)
        constant_viscosity = .false.
#endif

#ifdef MF
        call allocate_vof_fields
        call allocate_multiphase_fields
        call get_vof_from_distance
        call update_material_properties(rho, mu, vof)
        ! set the minimum density for the Dodd & Ferrante method
        rhomin = min(rho_0, rho_1)
        irhomin = 1.0_dp/rhomin
        advect_interface => advect_vof
#endif
#ifdef IBM
        block
            integer :: i
            if (allocated(Eulerian_Solid_list)) then
                do i = 1,size(Eulerian_Solid_list)
                    call Eulerian_Solid_list(i)%pS%setup()
                end do
            end if
        end block
        call init_ibm
#endif

    end subroutine init_solver
    !==============================================================================================

    !==============================================================================================
    subroutine save_fields(step)

        ! This subroutine save the fields of the simulation at timestep step
        use navier_stokes_mod, only : v, p
#ifdef MF
        use volume_of_fluid, only : vof
#endif

        ! In/Out variables
        integer, intent(in) :: step

        ! Local variables
        character(len=7 ) :: sn
        character(len=20) :: filename

        write(sn,'(I0.7)') step
        filename = 'data/vx_'//sn//'.raw'
        call v%x%write(filename)
        filename = 'data/vy_'//sn//'.raw'
        call v%y%write(filename)
#if DIM==3
        filename = 'data/vz_'//sn//'.raw'
        call v%z%write(filename)
#endif
        filename = 'data/p_'//sn//'.raw'
        call p%write(filename)
#ifdef MF
        filename = 'data/vof_'//sn//'.raw'
        call vof%write(filename)
#endif

    end subroutine save_fields
    !==============================================================================================

    !==============================================================================================
    subroutine destroy_solver

        use poisson_mod      , only : destroy_poisson_solver
        use navier_stokes_mod, only : phi, destroy_navier_stokes_solver
#ifdef MF
        use volume_of_fluid, only : destroy_vof
        use multiphase     , only : p_o, p_hat, grad_p_hat 
#endif

        call destroy_poisson_solver(phi)
        call destroy_navier_stokes_solver
#ifdef MF
        call destroy_vof
        call p_hat%destroy()
        call grad_p_hat%destroy()
        call p_o%destroy()
#endif

    end subroutine destroy_solver
    !==============================================================================================

end module