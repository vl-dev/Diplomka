! program main
! (c) Vladislav Matus
! last edit: 22. 09. 2018
! TODO: file manipulation error handling
! TODO: check all ierr  
      
      program main
      use mydepend
      use mydepend90
      use myroutines90      
      use gvroutines 
      use auxroutines 
      use testing
      use raggedmultiarray
      use metis_interface
      
      implicit none

!--------------------------------------------------------------------
! 
! constants
      
!     
! -- unit numbers for file handling            
      integer, parameter :: metunit = 1  
      integer, parameter :: graphvizunit = 2      
      integer, parameter :: metpartunit = 3
	integer, parameter :: infileunit = 4	  
! -- constants for calling METIS
      character(len=*), parameter :: metpath = "./METIS/metis.exe"
      character(len=*), parameter :: metfilename = "metgraph"               
      character(len=*), parameter :: metarguments = ">nul 2>&1"
      
      integer, parameter :: METIS_OPTION_NUMBERING = 17
      integer, parameter :: metisncon = 1      
! -- constants for Graphviz file
      character(len=*), parameter :: graphvizfilename = "GVgraph.txt"  
! -- miscelaneous      
      character(len=*), parameter :: sp = " " ! alias for space    
      integer, parameter :: partsch_max_len = 100 !length of string partsch
      integer, parameter :: matrixpath_max_len = 100 !length of string matrixpath      
      integer, parameter :: matrixtype_max_len = 100 !length of string matrixpath         

!--------------------------------------------------------------------      
!      
! work variables
!
! -- number of parts in partition
      integer :: parts          
! -- dimension of the matrix
      integer :: n
! -- number of edges in corresponding graph
!      integer :: ne      
! -- matrix in CSR format      
      integer, allocatable, dimension(:) :: ia, ja
      double precision, allocatable, dimension(:) :: aa
! -- obtained partitioning, vertex separator is denoted by (parts +1)
      integer, allocatable, dimension(:) :: part     
! -- multidimensional ragged arrays corresponding to partitions 
!    containing matrices in CSR format
      type(intRaggedArr) :: iap, jap
      type(dpRaggedArr) :: aap
      type(logicalRaggedArr) :: nvs
      ! Corresponding permutations from original to partitioned and back
      integer, allocatable, dimension(:) :: np, perm
      type(intRaggedArr) :: invperm      
! -- permutations from original to ordered matrix and back      
      integer, allocatable, dimension(:) :: ordperm, invordperm
! -- command line arguments
      character*(matrixtype_max_len) matrixtype
      character*(matrixpath_max_len) :: matrixpath
! -- work variables for calling METIS  
      integer, allocatable, dimension(:) :: iaNoLoops, jaNoLoops
      double precision, allocatable, dimension(:) :: aaNoLoops
      integer, dimension(0:40) :: metisoptions 
      integer :: metisobjval    
      integer :: metis_call_status  
      
      integer :: sepsize
! -- miscelaneous 
      integer :: nfull ! one dimension of matrix, "nfull = sqrt(n)"
      integer :: m
      integer :: ierr, info, statio      
      integer :: chsize ! size of the fill      
      integer, allocatable, dimension(:) :: wn01, wn02 !auxiliary vectors
      integer, allocatable, dimension(:) :: colcnt !TODO understand                       
      ! -- conversions of numbers to strings
      integer :: ndigits      
      !number of parts as string, use partsch(1:ndigits)
      character*(partsch_max_len) :: partsch       
      integer :: mformat ! matrix format for loading             
      integer :: testGraphNumber ! which matrix should be loaded in test mode
!--------------------------------------------------------------------
!
! program start
!
! -- various initializations
!            
! -- TODO load command line arguments, at the moment hardcoded:
!	  
     parts = 2
     matrixtype = 'T' !possible values: T ... Test, P ... Poisson, RSA ... from file     
     matrixpath = "./matrices/bcsstk01.rsa"
     testGraphNumber = 4
     nfull = 5
!
! -- matrix loading
!    TODO improve matrix loading, now it's just generating matrix using poisson1
!      
      info = 0
  !loading of the matrix in RB format      
      select case (TRIM(matrixtype))
        case ('RSA')
          open(unit=infileunit, file=matrixpath, action='read', iostat=statio)        
          if(statio .ne. 0) then
            stop 'specified matrix file cannot be opened.'
          end if   
          !allocate ia, ja, aa
          call imhb2(infileunit, m, n, mformat, ia, ja, aa, info) ! read a matrix in a RB format
          allocate(wn01(n+1), wn02(n+1), stat=ierr)
          
          !TODO konzultace, symtr7 nedela to, co bych cekal
          !write(*,*) ia
          !write(*,*) ja
          call symtr7(n, ia, ja, aa, wn01, wn02)
          deallocate(wn01, wn02, stat=ierr)
          !write(*,*) "symtr"
          !write(*,*) ia
          !write(*,*) ja
          !end konzultace          
          
        case ('P')
          !allocate ia, ja, aa
          call poisson1(nfull, n, ia, ja, aa, info)
          mformat = 11  

        case ('T')
            write(*,*) "Running in test mode"
            call loadTestGraph(ia, ja, aa, n, testGraphNumber)

        case default
          stop 'Unrecognised matrix format!'
      end select   

      
!
! -- calling Graph partitioner METIS embeded into program
!    TODO miscelaneous error handling    
!     
    
      call remloops(n, ia, ja, iaNoLoops, jaNoLoops, ierr, aa, aaNoLoops)
      allocate(part(n), stat=ierr)      
      metis_call_status=METIS_SetDefaultOptions(metisoptions)
      call shiftnumbering(-1, n, iaNoLoops, jaNoLoops)  ! transform graph into C++ notation (starting from 0)    
            
      metis_call_status=METIS_ComputeVertexSeparator(n, iaNoLoops, jaNoLoops, C_NULL_PTR, metisoptions, sepsize, part)

      call shiftnumbering(1, n, iaNoLoops, jaNoLoops, part)  ! transform graph back into Fortran notation (starting from 1)
!
! -- Create subgraphs
!
      call createSubgraphs(ia, ja, aa, n, part, parts, iap, jap, aap, np, nvs, perm, invperm, ierr)
!
! -- Find best ordering of vertices
!     TODO order vertices in all parts      
!            
      ! call orderByDistance(iap%vectors(1)%elements, jap%vectors(1)%elements, np(1), &
      !   logical2intArr(nvs%vectors(1)%elements) + 1, 1, ordperm, invordperm, ierr)

      ! call orderByMD(iap%vectors(1)%elements, jap%vectors(1)%elements, np(1), &
      !    ordperm, invordperm, ierr)

      ! call orderMixed(iap%vectors(1)%elements, jap%vectors(1)%elements, np(1), &
      !    logical2intArr(nvs%vectors(1)%elements) + 1, 1, ordperm, invordperm, ierr)      

      call orderMixed(ia, ja, n, [1,1,1,2], 1, ordperm, invordperm, ierr)      

      write(*,'(30I3)') ordperm

!
! -- Write out partitioned graph in Graphviz format
!    TODO miscelaneous error handling          
!      
      open(unit=graphvizunit, file=graphvizfilename)                  
      ! call  gvColorGraph (ia, ja, n, part, graphvizunit, ierr)  
      call  gvColorGraph (iap%vectors(1)%elements, jap%vectors(1)%elements, np(1), &
        logical2intArr(nvs%vectors(1)%elements) + 1, graphvizunit, ierr)  
      close(graphvizunit)  
      
      ! open(unit=15, file="GVgraph1.txt")   
      ! call graphvizcr(iap%vectors(1)%elements, jap%vectors(1)%elements, np(1), part, 15, ierr, .true., .false., .false.,)
      ! close(15)  
      
!      
! -- write out matlab format for displaying this matrix
!      call ommatl4(n, ia, ja, aa, mformat)

!      allocate(colcnt(nfull), stat=ierr)
!      call chfill2(nfull, ia, ja, mformat, colcnt, chsize, info)


!
! -- final tests in test mode
!            
      ! if(TRIM(matrixtype) = 'T') then
      !   !TODO tests
      ! end if
!
! -- deallocate all allocated fields
!
      deallocate(ia, stat=ierr)
      deallocate(ja, stat=ierr)
      deallocate(aa, stat=ierr)
      deallocate(part, stat=ierr)	  
      call subgraphCleanup(iap, jap, aap, np, nvs, perm, invperm, parts, ierr)
!
!--------------------------------------------------------------------          
!
! program end
!      
      end program 

