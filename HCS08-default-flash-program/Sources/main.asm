;*******************************************************************************
; Target flash programs for HCS08
;
; HCS08-small-flash-program.abs.s19   - for small targets (for restricted RAM targets, no paging support)
; HCS08-default-flash-program.abs.s19 - other targets (supports usual EEPAGE/PPAGE paging)

; defined on command line
; PAGED_ADDRESSES    - support for paged addresses (use of ppage register)

; export symbols
; XDEF infoBlock,entry,selectiveErase,massErase,program
; xref __SEG_END_SSTACK

; These error numbers are just for debugging
FLASH_ERR_OK        equ       0
FLASH_ERR_LOCKED    equ       1                   ; Flash is still locked
FLASH_ERR_ILLEGAL_PARAMS equ  2                   ; Parameters illegal
FLASH_ERR_PROG_FAILED equ     3                   ; STM - Programming operation failed - general
FLASH_ERR_PROG_WPROT equ      4                   ; STM - Programming operation failed - write protected
FLASH_ERR_VERIFY_FAILED equ   5                   ; Verify failed
FLASH_ERR_ERASE_FAILED equ    6                   ; Erase or Blank Check failed
FLASH_ERR_TRAP      equ       7                   ; Program trapped (illegal instruction/location etc.)
FLASH_ERR_PROG_ACCERR equ     8                   ; Kinetis/CFVx - Programming operation failed - ACCERR
FLASH_ERR_PROG_FPVIOL equ     9                   ; Kinetis/CFVx - Programming operation failed - FPVIOL
FLASH_ERR_PROG_MGSTAT0 equ    10                  ; Kinetis - Programming operation failed - MGSTAT0
FLASH_ERR_CLKDIV    equ       11                  ; CFVx - Clock divider not set
FLASH_ERR_ILLEGAL_SECURITY equ 12                 ; Kinetis - Illegal value for security location
FLASH_BUSY          equ       1<7                 ; Command complete

; typedef struct {
; volatile uint8_t  fcdiv;     ; 0
; volatile uint8_t  fopt;      ; 1
; volatile uint8_t  reserved;  ; 2
; volatile uint8_t  fcnfg;     ; 3
; volatile uint8_t  fprot;     ; 4
; volatile uint8_t  fstat;     ; 5
; volatile uint8_t  fcmd;      ; 6
; } controller;
FCDIV_O             equ       0
FSTAT_O             equ       5
FCMD_O              equ       6

fclkdiv_FDIVLD      equ       1<7
FSTAT_FCBEF         equ       1<7                 ; Command buffer empty
FSTAT_FCCF          equ       1<6                 ; Command complete
FSTAT_FPVIOL        equ       1<5                 ; Protection violation
FSTAT_FACCERR       equ       1<4                 ; Access error
FSTAT_FBLANK        equ       1<2                 ; Blank check OK
CFMCLKD_DIVLD       equ       1<7
CFMCLKD_PRDIV8      equ       1<6
CFMCLKD_FDIV        equ       $3F

; commands
FCMD_PAGE_ERASE_VERIFY equ    $05
FCMD_BYTE_PROGRAM   equ       $20
FCMD_BURST_PROGRAM  equ       $25
FCMD_PAGE_ERASE     equ       $40
FCMD_MASS_ERASE     equ       $41

; Used to indicate to program loader capabilities or requirements
OPT_SMALL_CODE      equ       $80
OPT_PAGED_ADDRESSES equ       $40
OPT_WDOG_ADDRESS    equ       $20

; typedef struct {
; uint8_t  flags;
; uint8_t  program;
; uint8_t  massErase;
; uint8_t  blankCheck;
; uint8_t  selectiveErase;
; uint8_t  verify;
; } infoBlock;

                    #ROM      *
          #ifdef PAGED_ADDRESSES
OPTIONS             equ       OPT_SMALL_CODE|OPT_PAGED_ADDRESSES
          #else
OPTIONS             equ       OPT_SMALL_CODE
          #endif
infoBlock           fcb       OPTIONS
params              fcb       program-infoBlock,massErase-infoBlock,blankCheck-infoBlock,selectiveErase-infoBlock,0
          #ifdef PAGED_ADDRESSES
reserved            ds        11-6
          #else
reserved            ds        8-6
          #endif
; typedef struct {
; volatile uint16_t  flashAddressL;
; volatile uint16_t  controller;
; volatile uint16_t  dataAddress_sectorSize;
; volatile uint16_t  dataSize_sectorCount;
; -----------------------------------
; volatile uint16_t  ppageAddress;
; volatile uint8_t   pageNum;
; } controlBlock;

; ENTRY                                                        ;   | mass | erase | prog  | ver |
flashAddressL       equ       infoBlock+0         ; flash address being accessed | X | X | X | X |
controller          equ       infoBlock+2         ; address of flash controller | X | X | X | X |

dataAddress         equ       infoBlock+4         ; ram data buffer address / | | | X | X |
sectorSize          equ       infoBlock+4         ; size of sector for stride | | X | | |

dataSize            equ       infoBlock+6         ; size of ram buffer / | | | X | X |
sectorCount         equ       infoBlock+6         ; number of sectors to erase | | X | | |
          #ifdef PAGED_ADDRESSES
ppageAddress        equ       infoBlock+8         ; address of PPAGE/EPAGE reg | X | X | X | X |
pageNum             equ       infoBlock+10        ; page number | X | X | X | X |
          #endif

; typedef struct {
; volatile uint16_t   status;
; } controlBlock;

; RETURN
status              equ       infoBlock+0         ; status | X | X | X | X |

;*******************************************************************************
                    #ROM
;*******************************************************************************
; Program flash

program             proc
          #ifdef PAGED_ADDRESSES
                    ldhx      ppageAddress
                    lda       pageNum
                    sta       ,x
          #endif
Loop@@              ldhx      dataSize            ; complete?
                    beq       Done@@
                    aix       #-1                 ; dataSize--
                    sthx      dataSize

                    ldhx      dataAddress         ; *flashAddressL++ = *dataAddress++;
                    lda       ,x
                    aix       #1
                    sthx      dataAddress
                    ldhx      flashAddressL
                    sta       ,x
                    aix       #1
                    sthx      flashAddressL

                    ldhx      controller
          ;-------------------------------------- ; Write command
                    lda       #FCMD_BURST_PROGRAM
                    sta       FCMD_O,X
          ;-------------------------------------- ; Start execution
                    lda       #FSTAT_FCBEF
                    sta       FSTAT_O,X

                    lda       ,x                  ; waste 3 cycles
          ;-------------------------------------- ; Wait for command buffer empty or error
_1@@                lda       #FSTAT_FCBEF|FSTAT_FACCERR|FSTAT_FPVIOL
                    and       FSTAT_O,X
                    beq       _1@@
          ;-------------------------------------- ; Check for errors
                    bit       #FSTAT_FACCERR|FSTAT_FPVIOL
                    beq       Loop@@
                    ldhx      #FLASH_ERR_PROG_FAILED
Done@@              sthx      status

                    ldhx      controller
                    lda       #FSTAT_FCCF
_2@@                bit       FSTAT_O,x           ; wait for last command to complete
                    beq       _2@@
                    !bgnd

;*******************************************************************************
; Mass erase flash

massErase           proc
          #ifdef PAGED_ADDRESSES
                    ldhx      ppageAddress
                    lda       pageNum
                    sta       ,x
          #endif
                    ldhx      flashAddressL       ; *flashAddess = dummyValue;
                    sta       ,x

                    ldhx      controller
          ;-------------------------------------- ; Write command
                    lda       #FCMD_MASS_ERASE
                    sta       FCMD_O,X
          ;-------------------------------------- ; Start execution
                    lda       #FSTAT_FCBEF
                    sta       FSTAT_O,X

                    lda       ,X                  ; waste 3 cycles
          ;-------------------------------------- ; Wait for command complete
Loop@@              lda       #FSTAT_FCCF|FSTAT_FACCERR|FSTAT_FPVIOL
                    and       FSTAT_O,X
                    beq       Loop@@
          ;-------------------------------------- ; Check errors
                    ldhx      #FLASH_ERR_PROG_ACCERR
                    bit       #FSTAT_FACCERR
                    bne       Fail@@
                    ldhx      #FLASH_ERR_PROG_FPVIOL
                    bit       #FSTAT_FPVIOL
                    bne       Fail@@

                    clrx
Fail@@              sthx      status
                    !bgnd

;*******************************************************************************
; Blank check flash

blankCheck          proc
          #ifdef PAGED_ADDRESSES
                    ldhx      ppageAddress
                    lda       pageNum
                    sta       ,x
          #endif
Loop@@              ldhx      dataSize            ; complete?
                    beq       Done@@
                    aix       #-1                 ; dataSize--
                    sthx      dataSize

                    ldhx      flashAddressL       ; *flashAddressL++ = *dataAddress++;
                    lda       ,x
                    aix       #1
                    sthx      flashAddressL
                    cmpa      #$FF
                    beq       Loop@@

                    ldhx      #FLASH_ERR_ERASE_FAILED
Done@@              sthx      status
                    !bgnd

;*******************************************************************************
; Selective erase flash

selectiveErase      proc
          #ifdef PAGED_ADDRESSES
                    ldhx      ppageAddress
                    lda       pageNum
                    sta       ,x
          #endif
Loop@@              ldhx      sectorCount         ; complete?
                    beq       Done@@
                    aix       #-1                 ; count this byte
                    sthx      sectorCount

                    ldhx      flashAddressL       ; *flashAddess++ = dummyValue;
                    sta       ,x
                    txa                           ; flashAddess += sectorSize;
                    add       sectorSize+1
                    sta       flashAddressL+1
                    lda       flashAddressL
                    adc       sectorSize
                    sta       flashAddressL

                    ldhx      controller
          ;-------------------------------------- ; Write command
                    lda       #FCMD_PAGE_ERASE
                    sta       FCMD_O,X
          ;-------------------------------------- ; Start execution
                    lda       #FSTAT_FCBEF
                    sta       FSTAT_O,X

                    lda       ,x                  ; waste 3 cycles
          ;-------------------------------------- ; Wait for command complete
_1@@                lda       #FSTAT_FCCF|FSTAT_FACCERR|FSTAT_FPVIOL
                    and       FSTAT_O,X
                    beq       _1@@
          ;-------------------------------------- ; Check errors
                    ldhx      #FLASH_ERR_PROG_ACCERR
                    bit       #FSTAT_FACCERR
                    bne       Done@@
                    ldhx      #FLASH_ERR_PROG_FPVIOL
                    bit       #FSTAT_FPVIOL
                    beq       Loop@@

Done@@              sthx      status
                    !bgnd

#ifdef
;*******************************************************************************
; Verify flash

verify              proc
          #ifdef PAGED_ADDRESSES
                    ldhx      ppageAddress
                    lda       pageNum
                    sta       ,x
          #endif
Loop@@              ldhx      dataSize            ; complete?
                    beq       Done@@
                    aix       #-1                 ; dataSize--
                    sthx      dataSize

                    ldhx      dataAddress         ; *flashAddressL++ == *dataAddress ?
                    lda       ,x
                    aix       #1
                    sthx      dataAddress
                    ldhx      flashAddressL
                    cmpa      ,x
                    bne       Fail@@
                    aix       #1
                    sthx      flashAddressL
                    bra       Loop@@

Fail@@              ldhx      #FLASH_ERR_VERIFY_FAILED
Done@@              sthx      status
                    !bgnd
#endif
