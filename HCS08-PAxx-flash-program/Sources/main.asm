;*******************************************************************************
; Target flash programs for HCS08
;
; HCS08-small-flash-program.abs.s19   - for small targets (for restricted RAM targets, no paging support)
; HCS08-default-flash-program.abs.s19 - other targets (supports usual EEPAGE/PPAGE paging)
;
; Specific to PA2 & PA4 targets
;
; =========================================================================
; WARNING  WARNING  WARNING  WARNING  WARNING  WARNING  WARNING   WARNING
;
; The WDOG address is hard-coded in this routine due to size constraints
;
; =========================================================================
; WARNING  WARNING  WARNING  WARNING  WARNING  WARNING  WARNING   WARNING
;
; defined on command line
; FLASH_PROGRAMMING  - build for Flash programming
; EEPROM_PROGRAMMING - build for EEPROM programming
;
; export symbols
; XDEF infoBlock,entry,selectiveErase,massErase,program
; xref __SEG_END_SSTACK

; Used to flag EEPROM in mass erase command etc
EEPROM_ADDRESS_FLAG equ       1<7

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
; volatile uint8_t  cs1;    // 0
; volatile uint8_t  cs2;    // 1
; volatile uint16_t cnt;    // 2
; volatile uint16_t toval;  // 4
; volatile uint16_t win;    // 6
; } WatchDog;

WATCHDOG            equ       $3030
WATCHDOG_CS1_OFF    equ       0
WATCHDOG_CS2_OFF    equ       1
WATCHDOG_CNT_OFF    equ       2
WATCHDOG_TOVAL_OFF  equ       4
WATCHDOG_WIN_OFF    equ       6

; typedef struct {
; volatile uint8_t fclkdiv;
; volatile uint8_t fsec;
; volatile uint8_t fccobix;
; volatile uint8_t res;
; volatile uint8_t fcnfg;
; volatile uint8_t fercnfg;
; volatile uint8_t fstat;   ; 6 :
; volatile uint8_t ferstat;
; volatile uint8_t fprot;   ; Flash protection
; volatile uint8_t eeprot;  ; EEprom protection
; union {
; volatile uint16_t w;
; volatile uint8_t  b[2];
; } fccob;
; volatile uint8_t  fopt;
; } FlashController;

FCLKDIV_OFF         equ       0
FSEC_OFF            equ       1
FCCOBIX_OFF         equ       2
FCNFG_OFF           equ       4
FERCNFG_OFF         equ       5
FSTAT_OFF           equ       6
FERSTAT_OFF         equ       7
FPROT_OFF           equ       8
EEPROT_OFF          equ       9
FCCOBH_OFF          equ       10
FCCOBL_OFF          equ       11
FOPT_OFF            equ       12

fclkdiv_FDIVLD      equ       1<7

FSTAT_CCIF          equ       1<7                 ; Command complete
FSTAT_ACCERR        equ       1<5                 ; Access error
FSTAT_FPVIOL        equ       1<4                 ; Protection violation
FSTAT_MGBUSY        equ       1<3                 ; Memory controller busy
FSTAT_MGSTAT1       equ       1<1                 ; Command completion status
FSTAT_MGSTAT0       equ       1<0

FSTAT_CCIF_BIT      equ       7
FSTAT_ACCERR_BIT    equ       5
FSTAT_FPVIOL_BIT    equ       4
FSTAT_MGBUSY_BIT    equ       3
FSTAT_MGSTAT1_BIT   equ       1
FSTAT_MGSTAT0_BIT   equ       0

; Flash commands
FCMD_ERASE_ALL_BLOCKS equ     $08
FCMD_ERASE_FLASH_BLOCK equ    $09

FCMD_PROGRAM_FLASH  equ       $06
FCMD_PROGRAM_EEPROM equ       $11

FCMD_ERASE_FLASH_SECTOR equ   $0A
FCMD_ERASE_EEPROM_SECTOR equ  $12

          #ifdef    EEPROM_PROGRAMMING
FCMD_PROGRAM        equ       FCMD_PROGRAM_EEPROM
HIGH_BYTE_ADDRESS   equ       EEPROM_ADDRESS_FLAG
FCMD_ERASE_SECTOR   equ       FCMD_ERASE_EEPROM_SECTOR
          #else ifdef    FLASH_PROGRAMMING
FCMD_PROGRAM        equ       FCMD_PROGRAM_FLASH
HIGH_BYTE_ADDRESS   equ       0
FCMD_ERASE_SECTOR   equ       FCMD_ERASE_FLASH_SECTOR
          #endif

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

                    #DATA     *
infoBlock           fcb       OPT_SMALL_CODE|OPT_WDOG_ADDRESS
params              fcb       program-infoBlock
                    fcb       massErase-infoBlock
                    fcb       blankCheck-infoBlock
                    fcb       selectiveErase-infoBlock
                    fcb       0
reserved            rmb       11-6

; typedef struct {
; volatile uint16_t  flashAddress;
; volatile uint16_t  controller;
; volatile uint16_t  dataAddress_sectorSize;
; volatile uint16_t  dataSize_sectorCount;
; -----------------------------------
; volatile uint16_t  scratch;
; volatile uint8_t   pageNum;
; } controlBlock;

; ENTRY                                                        ;   | mass | erase | prog  | ver |
flashAddress        equ       infoBlock+0         ; flash address being accessed | X | X | X | X |
controller          equ       infoBlock+2         ; address of flash controller | X | X | X | X |

dataAddress         equ       infoBlock+4         ; ram data buffer address / | | | X | X |
sectorSize          equ       infoBlock+4         ; size of sector for stride | | X | | |

dataSize            equ       infoBlock+6         ; size of ram buffer / | | | X | X |
sectorCount         equ       infoBlock+6         ; number of sectors to erase | | X | | |
scratch             equ       infoBlock+8         ; scratch / | | | X | |
watchDog            equ       infoBlock+8         ; watchdog | X | X | X | X |
scratchH            equ       scratch
scratchL            equ       scratch+1
pageNum             equ       infoBlock+10        ; page number | X | X | X | |

; typedef struct {
; volatile uint16_t   status;
; } controlBlock;

; RETURN
status              equ       infoBlock+0         ; status | X | X | X | X |

; code sections

;*******************************************************************************
; Program flash

program             proc
          ;-------------------------------------- ; Refresh watchdog
MainLoop@@          ldhx      #$A602
                    sthx      WATCHDOG+WATCHDOG_CNT_OFF  ; write the 1st refresh word
                    ldhx      #$B480
                    sthx      WATCHDOG+WATCHDOG_CNT_OFF  ; write the 2nd refresh word
          ;--------------------------------------
                    ldhx      dataSize            ; complete?
                    beq       SaveStatus@@
          #ifdef EEPROM_PROGRAMMING
                    aix       #-1                 ; dataSize-=1, 1 bytes=1 phrase, written each cycle
          #else ifdef FLASH_PROGRAMMING
                    aix       #-4                 ; dataSize-=4, 4 bytes=1 phrase, written each cycle
          #endif
                    sthx      dataSize
          ;-------------------------------------- ; Clear protection
                    ldhx      controller
                    lda       #$FF
                    sta       FPROT_OFF,X
                    sta       EEPROT_OFF,X
          ;-------------------------------------- ; Clear any existing error
                    lda       #FSTAT_ACCERR|FSTAT_FPVIOL
                    sta       FSTAT_OFF,X
          ;-------------------------------------- ; Write command & address
                    clra
                    sta       FCCOBIX_OFF,X
                    lda       #FCMD_PROGRAM
                    sta       FCCOBH_OFF,X
                    lda       pageNum
                    sta       FCCOBL_OFF,X

                    inc       FCCOBIX_OFF,X
                    lda       flashAddress+0
                    sta       FCCOBH_OFF,X
                    lda       flashAddress+1
                    sta       FCCOBL_OFF,X
          ;-------------------------------------- ; Advance write address
                    ldhx      flashAddress
          #ifdef EEPROM_PROGRAMMING
                    aix       #1
          #else ifdef FLASH_PROGRAMMING
                    aix       #4
          #endif
                    sthx      flashAddress
          ;-------------------------------------- ; Write data bytes 0 (+1 for Flash)
                    ldhx      dataAddress
                    mov       x+,scratchH
          #ifdef FLASH_PROGRAMMING
                    mov       x+,scratchL
          #endif
                    sthx      dataAddress

                    ldhx      controller
                    inc       FCCOBIX_OFF,X
                    lda       scratchH
          #ifdef FLASH_PROGRAMMING
                    sta       FCCOBH_OFF,X
                    lda       scratchL
          #endif
                    sta       FCCOBL_OFF,X

          #ifdef FLASH_PROGRAMMING
          ;-------------------------------------- ; Write data bytes 2,3 (for Flash)
                    ldhx      dataAddress
                    mov       x+,scratchH
                    mov       x+,scratchL
                    sthx      dataAddress

                    ldhx      controller
                    inc       FCCOBIX_OFF,X
                    lda       scratchH
                    sta       FCCOBH_OFF,X
                    lda       scratchL
                    sta       FCCOBL_OFF,X
          #endif
          ;-------------------------------------- ; Launch command
                    lda       #FSTAT_CCIF
                    sta       FSTAT_OFF,x
          ;-------------------------------------- ; Wait for command complete
Loop@@              lda       FSTAT_OFF,x
                    and       #FSTAT_CCIF|FSTAT_ACCERR|FSTAT_FPVIOL
                    beq       Loop@@
          ;-------------------------------------- ; Check errors
                    ldhx      #FLASH_ERR_PROG_ACCERR
                    bit       #FSTAT_ACCERR_BIT
                    bne       SaveStatus@@
                    ldhx      #FLASH_ERR_PROG_FPVIOL
                    bit       #FSTAT_FPVIOL_BIT
                    jeq       MainLoop@@

SaveStatus@@        sthx      status
                    !bgnd

;*******************************************************************************
; Mass erase flash

massErase           proc
          ;-------------------------------------- ; Refresh watchdog
                    ldhx      #$A602
                    sthx      WATCHDOG+WATCHDOG_CNT_OFF  ; write the 1st refresh word
                    ldhx      #$B480
                    sthx      WATCHDOG+WATCHDOG_CNT_OFF  ; write the 2nd refresh word
          ;--------------------------------------
                    ldhx      controller
          ;-------------------------------------- ; Clear protection
                    lda       #$FF
                    sta       FPROT_OFF,X
                    sta       EEPROT_OFF,X
          ;-------------------------------------- ; Clear any existing error
                    lda       #FSTAT_ACCERR|FSTAT_FPVIOL
                    sta       FSTAT_OFF,X
          ;-------------------------------------- ; Write command & address
                    clra
                    sta       FCCOBIX_OFF,X
                    lda       #FCMD_ERASE_FLASH_BLOCK
                    sta       FCCOBH_OFF,X
                    lda       #HIGH_BYTE_ADDRESS
                    ora       pageNum
                    sta       FCCOBL_OFF,X

                    inc       FCCOBIX_OFF,X
                    lda       flashAddress+0
                    sta       FCCOBH_OFF,X
                    lda       flashAddress+1
                    sta       FCCOBL_OFF,X
          ;-------------------------------------- ; Launch command
                    lda       #FSTAT_CCIF
                    sta       FSTAT_OFF,x
          ;-------------------------------------- ; Wait for command complete
Loop@@              lda       FSTAT_OFF,x
                    and       #FSTAT_CCIF|FSTAT_ACCERR|FSTAT_FPVIOL
                    beq       Loop@@
          ;-------------------------------------- ; Check errors
                    ldhx      #FLASH_ERR_PROG_ACCERR
                    bit       #FSTAT_ACCERR_BIT
                    bne       SaveStatus@@
                    ldhx      #FLASH_ERR_PROG_FPVIOL
                    bit       #FSTAT_FPVIOL_BIT
                    bne       SaveStatus@@

                    clrx
SaveStatus@@        sthx      status
                    !bgnd

;*******************************************************************************
; Blank check flash

blankCheck          proc
          ;-------------------------------------- ; Disable watchdog
;                   ldhx      watchDog
;                   stx       WATCHDOG_TOVAL_OFF,X
;                   stx       WATCHDOG_TOVAL_OFF+1,X
;                   clr       WATCHDOG_CS2_OFF,x
;                   clr       WATCHDOG_CS1_OFF,x
          ;-------------------------------------- ; Refresh watchdog
Loop@@              ldhx      #$A602
                    sthx      WATCHDOG+WATCHDOG_CNT_OFF  ; write the 1st refresh word
                    ldhx      #$B480
                    sthx      WATCHDOG+WATCHDOG_CNT_OFF  ; write the 2nd refresh word
          ;--------------------------------------
                    ldhx      dataSize            ; complete?
                    beq       SaveStatus@@
                    aix       #-1                 ; dataSize--
                    sthx      dataSize

                    ldhx      flashAddress        ; *flashAddress++ = *dataAddress++;
                    lda       ,x
                    aix       #1
                    sthx      flashAddress
                    cmp       #$FF
                    beq       Loop@@

                    ldhx      #FLASH_ERR_ERASE_FAILED
SaveStatus@@        sthx      status
                    !bgnd

;*******************************************************************************
; Selective erase flash

selectiveErase      proc
          ;-------------------------------------- ; Disable watchdog
;                   ldhx      watchDog
;                   stx       WATCHDOG_TOVAL_OFF,X
;                   stx       WATCHDOG_TOVAL_OFF+1,X
;                   clra
;                   sta       WATCHDOG_CS2_OFF,x
;                   sta       WATCHDOG_CS1_OFF,x
          ;-------------------------------------- ; Refresh watchdog
MainLoop@@          ldhx      #$A602
                    sthx      WATCHDOG+WATCHDOG_CNT_OFF  ; write the 1st refresh word
                    ldhx      #$B480
                    sthx      WATCHDOG+WATCHDOG_CNT_OFF  ; write the 2nd refresh word
          ;--------------------------------------
                    ldhx      sectorCount         ; complete?
                    beq       SaveStatus@@
                    aix       #-1                 ; count this sector
                    sthx      sectorCount

                    ldhx      controller
          ;-------------------------------------- ; Clear protection
                    lda       #$FF
                    sta       FPROT_OFF,X
                    sta       EEPROT_OFF,X
          ;-------------------------------------- ; Clear any existing error
                    lda       #FSTAT_ACCERR|FSTAT_FPVIOL
                    sta       FSTAT_OFF,X
          ;-------------------------------------- ; Write command & address
                    clra
                    sta       FCCOBIX_OFF,X
                    lda       #FCMD_ERASE_SECTOR
                    sta       FCCOBH_OFF,X
                    lda       pageNum
                    sta       FCCOBL_OFF,X

                    inc       FCCOBIX_OFF,X

                    lda       flashAddress+0
                    sta       FCCOBH_OFF,X
                    adc       sectorSize
                    sta       flashAddress

                    lda       flashAddress+1
                    sta       FCCOBL_OFF,X
                    add       sectorSize+1
                    sta       flashAddress+1
          ;-------------------------------------- ; Launch command
                    lda       #FSTAT_CCIF
                    sta       FSTAT_OFF,x
          ;-------------------------------------- ; Wait for command complete
Loop@@              lda       FSTAT_OFF,x
                    and       #FSTAT_CCIF|FSTAT_ACCERR|FSTAT_FPVIOL
                    beq       Loop@@
          ;-------------------------------------- ; Check errors
                    ldhx      #FLASH_ERR_PROG_ACCERR
                    bit       #FSTAT_ACCERR_BIT
                    bne       SaveStatus@@
                    ldhx      #FLASH_ERR_PROG_FPVIOL
                    bit       #FSTAT_FPVIOL_BIT
                    beq       MainLoop@@
          ;--------------------------------------
SaveStatus@@        sthx      status
                    !bgnd
#ifdef
;*******************************************************************************
; Verify flash

verify              proc
          ;-------------------------------------- ; Disable watchdog
                    ldhx      watchDog
                    stx       WATCHDOG_TOVAL_OFF,X
                    stx       WATCHDOG_TOVAL_OFF+1,X
                    clra
                    sta       WATCHDOG_CS2_OFF,x
                    sta       WATCHDOG_CS1_OFF,x
          ;--------------------------------------
Loop@@              ldhx      dataSize            ; complete?
                    beq       SaveStatus@@
                    aix       #-1                 ; dataSize--
                    sthx      dataSize

                    ldhx      dataAddress         ; *flashAddress++ == *dataAddress ?
                    lda       ,x
                    aix       #1
                    sthx      dataAddress
                    ldhx      flashAddress
                    cmp       ,x
                    bne       Fail@@
                    aix       #1
                    sthx      flashAddress
                    bra       Loop@@

Fail@@              ldhx      #FLASH_ERR_VERIFY_FAILED
SaveStatus@@        sthx      status
                    !bgnd
#endif
