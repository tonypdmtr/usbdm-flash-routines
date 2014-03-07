//=======================================================================================
// Flash code for Kinetis FTFA memory (MKL flash devices)
//=======================================================================================
// History
//---------------------------------------------------------------------------------------------
// 17 Aug 2013 - Fixed regression that prevented programming DFLASH  (A23 changes)    | V4.10.6 
//             - Fixed MCM_PLACR value (Disabling cache properly)                     | V4.10.4
//---------------------------------------------------------------------------------------------

#include <cstdint>

#ifndef NULL
#define NULL ((void*)0)
#endif

//#define DEBUG

//==========================================================================================================
// Target defines

// Vector Table Offset Register
#define SCB_VTOR (*(volatile uint32_t *)0xE000ED08)

#define NV_SECURITY_ADDRESS        (0x00000400)
#define NV_FSEC_ADDRESS            (NV_SECURITY_ADDRESS+0x0C)
#define FTFA_FSEC_KEY_MASK              0xC0
#define FTFA_FSEC_KEY_ENABLE            0x80
#define FTFA_FSEC_KEY_DISABLE           0xC0
#define FTFA_FSEC_MEEN_MASK             0x30
#define FTFA_FSEC_MEEN_ENABLE           0x30
#define FTFA_FSEC_MEEN_DISABLE          0x20
#define FTFA_FSEC_FSLACC                0x0C
#define FTFA_FSEC_SEC_MASK              0x03
#define FTFA_FSEC_UNSEC                 0x02
#define FTFA_FSEC_SEC                   0x03

#ifdef DEBUG
#define FTFA_BASE_ADDRESS               ((volatile FlashController *)0x40020000)
#endif

#define MCM_PLACR_CFCC  (1<<10) // Clear Flash Controller Cache 
#define MCM_PLACR_DFCDA (1<<11) // Disable Flash Controller Data Caching
#define MCM_PLACR_DFCC  (1<<13) // Disable Flash Controller Cache
#define MCM_PLACR_DFCS  (1<<13) // Disable Flash Controller Speculation

// Cache control
#define MCM_PLACR                  (*(volatile uint32_t *)0xF000300C)

#pragma pack(1)
typedef struct {
   uint8_t  fstat;
   uint8_t  fcnfg;
   uint8_t  fsec;
   uint8_t  fopt;
   uint32_t fccob0_3;
   uint32_t fccob4_7;
   uint32_t fccob8_B;
   uint32_t fprot0_3;
   uint8_t  feprot;
   uint8_t  fdprot;
} FlashController;
#pragma pack(0)

#define FTFA_FSTAT_CCIF                 0x80
#define FTFA_FSTAT_RDCOLLERR            0x40
#define FTFA_FSTAT_ACCERR               0x20
#define FTFA_FSTAT_FPVIOL               0x10
#define FTFA_FSTAT_MGSTAT0              0x01

#define FTFA_FCNFG_CCIE                 0x80
#define FTFA_FCNFG_RDCOLLIE             0x40
#define FTFA_FCNFG_ERSAREQ              0x20
#define FTFA_FCNFG_ERSSUSP              0x10
#define FTFA_FCNFG_SWAP                 0x08
#define FTFA_FCNFG_PFLSH                0x04
#define FTFA_FCNFG_RAMRDY               0x02
#define FTFA_FCNFG_EEERDY               0x01

#define FOPT_LPBOOTn                    0x01
#define FOPT_EZPORT                     0x02
   
// Flash commands
#define F_RD1SEC                        0x01
#define F_PGMCHK                        0x02
#define F_RDRSRC                        0x03
#define F_PGM4                          0x06
#define F_ERSSCR                        0x09
#define F_RD1ALL                        0x40
#define F_RDONCE                        0x41
#define F_PGMONCE                       0x43
#define F_ERSALL                        0x44
#define F_VFYKEY                        0x45

#define F_USER_MARGIN                   0x01 // Use 'user' margin on flash verify
#define F_FACTORY_MARGIN                0x02 // Use 'factory' margin on flash verify

#define CRC_CRC                         (*(volatile uint32_t *)0x40032000)
#define CRC_GPOLY                       (*(volatile uint32_t *)0x40032004)
#define CRC_CTRL                        (*(volatile uint32_t *)0x40032008)
#define CRC_CTRL_WAS                    (1<<25)
#define CRC_CTRL_TCRC                   (1<<24)

/* Address of Watchdog Status and Control Register (32 bits) */
#define SIM_COPC (*(volatile uint32_t *)0x40048100)

/* Word to be written in in SIM_COPC to disable the Watchdog */
#define COP_DISABLE  0x0

//==========================================================================================================
// Operation masks
//
//  The following combinations (amongst others) are sensible:
//  DO_PROGRAM_RANGE|DO_VERIFY_RANGE program & verify range assuming previously erased
//  DO_ERASE_RANGE|DO_BLANK_CHECK_RANGE|DO_PROGRAM_RANGE|DO_VERIFY_RANGE do all steps
//
#define DO_INIT_FLASH         (1<<0) // Do initialisation of flash
#define DO_ERASE_BLOCK        (1<<1) // Erase entire flash block e.g. Flash, FlexNVM etc
#define DO_ERASE_RANGE        (1<<2) // Erase range (including option region)
#define DO_BLANK_CHECK_RANGE  (1<<3) // Blank check region
#define DO_PROGRAM_RANGE      (1<<4) // Program range (including option region)
#define DO_VERIFY_RANGE       (1<<5) // Verify range
#define DO_PARTITION_FLEXNVM  (1<<7) // Program FlexNVM DFLASH/EEPROM partitioning
#define DO_TIMING_LOOP        (1<<8) // Counting loop to determine clock speed

#define IS_COMPLETE           (1<<31)
                             
// Capability masks
#define CAP_ERASE_BLOCK        (1<<1)
#define CAP_ERASE_RANGE        (1<<2)
#define CAP_BLANK_CHECK_RANGE  (1<<3)
#define CAP_PROGRAM_RANGE      (1<<4)
#define CAP_VERIFY_RANGE       (1<<5)
#define CAP_UNLOCK_FLASH       (1<<6)
#define CAP_PARTITION_FLEXNVM  (1<<7)
#define CAP_TIMING             (1<<8)

#define CAP_DSC_OVERLAY        (1<<11) // Indicates DSC code in pMEM overlays xRAM
#define CAP_DATA_FIXED         (1<<12) // Indicates TargetFlashDataHeader is at fixed address
                               
#define CAP_RELOCATABLE        (1<<31)

#define ADDRESS_LINEAR (1UL<<31) // Indicate address is linear
#define ADDRESS_EEPROM (1UL<<30) // Indicate address lies within EEPROM

// These error numbers are just for debugging
typedef enum {
     FLASH_ERR_OK                = (0),
     FLASH_ERR_LOCKED            = (1),  // Flash is still locked
     FLASH_ERR_ILLEGAL_PARAMS    = (2),  // Parameters illegal
     FLASH_ERR_PROG_FAILED       = (3),  // STM - Programming operation failed - general
     FLASH_ERR_PROG_WPROT        = (4),  // STM - Programming operation failed - write protected
     FLASH_ERR_VERIFY_FAILED     = (5),  // Verify failed
     FLASH_ERR_ERASE_FAILED      = (6),  // Erase or Blank Check failed
     FLASH_ERR_TRAP              = (7),  // Program trapped (illegal instruction/location etc.)
     FLASH_ERR_PROG_ACCERR       = (8),  // Kinetis/CFVx - Programming operation failed - ACCERR
     FLASH_ERR_PROG_FPVIOL       = (9),  // Kinetis/CFVx - Programming operation failed - FPVIOL
     FLASH_ERR_PROG_MGSTAT0      = (10), // Kinetis - Programming operation failed - MGSTAT0
     FLASH_ERR_CLKDIV            = (11), // CFVx - Clock divider not set
     FLASH_ERR_ILLEGAL_SECURITY  = (12), // Kinetis/CFV1+ - Illegal value for security location
     FLASH_ERR_UNKNOWN           = (13)  // Unspecified error
} FlashDriverError_t;

// This is the smallest unit of Flash that can be erased
#define FLASH_SECTOR_SIZE  (1*(1<<10)) // 1K block size (used for stride in erase)

typedef void (*EntryPoint_t)(void);
#pragma pack(2)
// Describes a block to be programmed & result
typedef struct {
   uint32_t                  flags;             // Controls actions of routine
   volatile FlashController *controller;        // Pointer to flash controller
   uint32_t                  frequency;         // Target frequency (kHz)
   uint16_t                  errorCode;         // Error code from action
   uint16_t                  sectorSize;        // Size of flash sectors (minimum erase size)
   uint32_t                  address;           // Memory address being accessed
   uint32_t                  dataSize;          // Size of memory range being accessed
   const uint32_t           *dataAddress;       // Pointer to data to program
} FlashData_t;

//! Describe the flash programming code
typedef struct {
   uint32_t        *loadAddress;       // Address where to load this image
   EntryPoint_t     entry;             // Pointer to entry routine
   uint32_t         capabilities;      // Capabilities of routine
   uint32_t         reserved1;
   uint32_t         reserved2;
   FlashData_t     *flashData;         // Pointer to information about operation
} FlashProgramHeader_t;

#pragma pack(0)

extern uint32_t __loadAddress[];

void asm_entry(void);

//! Flash programming command table
//!
volatile const FlashProgramHeader_t gFlashProgramHeader = {
     /* loadAddress  */ __loadAddress,     // load address of image
     /* entry        */ asm_entry,         // entry point for code
     /* capabilities */ CAP_BLANK_CHECK_RANGE|CAP_ERASE_RANGE|CAP_ERASE_BLOCK|CAP_PROGRAM_RANGE|CAP_VERIFY_RANGE|CAP_PARTITION_FLEXNVM,
     /* Reserved1    */ 0,
     /* Reserved2    */ 0,
     /* flashData    */ NULL,
};

void setErrorCode(int errorCode) __attribute__ ((noreturn));
void initFlash(FlashData_t *flashData);
void eraseFlashBlock(FlashData_t *flashData);
void programRange(FlashData_t *flashData);
void verifyRange(FlashData_t *flashData);
void eraseRange(FlashData_t *flashData);
void blankCheckRange(FlashData_t *flashData);
void entry(void);
void isr_default(void);
void testApp(void);
void asm_testApp(void);
void executeCommand(volatile FlashController *controller);

//! Set error code to return to BDM & halts
//!
void setErrorCode(int errorCode) {
   FlashData_t *flashData = gFlashProgramHeader.flashData;
   flashData->errorCode   = (uint16_t)errorCode;
   flashData->flags      |= IS_COMPLETE; 
   for(;;) {
	   asm("bkpt  0");
   }
}

//! Does any initialisation required before accessing the Flash
//!
void initFlash(FlashData_t *flashData) {
   // Do init flash every time
   
   // Unprotect flash
   flashData->controller->fprot0_3 = 0xFFFFFFFF;
   flashData->controller->fdprot   = 0xFF;
   
   // Disable flash caching
   MCM_PLACR = MCM_PLACR_DFCC|MCM_PLACR_DFCS;

   flashData->flags &= ~DO_INIT_FLASH;
}

//! Launch & wait for Flash command to complete
//!
void executeCommand(volatile FlashController *controller) {
   // Clear any existing errors
   controller->fstat = FTFA_FSTAT_ACCERR|FTFA_FSTAT_FPVIOL;

   // Launch command
   controller->fstat = FTFA_FSTAT_CCIF;

   // Wait for command complete
   while ((controller->fstat & FTFA_FSTAT_CCIF) == 0) {
   }
   // Handle any errors
   if ((controller->fstat & FTFA_FSTAT_FPVIOL ) != 0) {
      setErrorCode(FLASH_ERR_PROG_FPVIOL);
   }
   if ((controller->fstat & FTFA_FSTAT_ACCERR ) != 0) {
      setErrorCode(FLASH_ERR_PROG_ACCERR);
   }
   if ((controller->fstat & FTFA_FSTAT_MGSTAT0 ) != 0) {
      setErrorCode(FLASH_ERR_PROG_MGSTAT0);
   }
}

//! Erase entire flash block
//!
void eraseFlashBlock(FlashData_t *flashData) {

   if ((flashData->flags&DO_ERASE_BLOCK) == 0) {
      return;
   }
   
   flashData->controller->fccob0_3 = (F_ERSALL << 24) ;
   executeCommand(flashData->controller);
   flashData->flags &= ~DO_ERASE_BLOCK;
}

//! Program a range of flash from buffer
//!
//! Returns an error if the security location is to be programmed
//! to permanently lock the device
//!
void programRange(FlashData_t *flashData) {
   uint32_t         address    = flashData->address;
   const uint32_t  *data       = flashData->dataAddress;
   uint32_t         numWords   = flashData->dataSize>>2;
   
   if ((flashData->flags&DO_PROGRAM_RANGE) == 0) {
      return;
   }
//   if ((address & 0x03) != 0) {
//      setErrorCode(FLASH_ERR_ILLEGAL_PARAMS);
//   }
   // Program words
   while (numWords-- > 0) {
      if (address == (NV_FSEC_ADDRESS&~3)) {
         // Check for permanent secure value
         if ((*data & (FTFA_FSEC_MEEN_MASK)) == (FTFA_FSEC_MEEN_DISABLE)) {
            setErrorCode(FLASH_ERR_ILLEGAL_SECURITY);
         }
      }
      flashData->controller->fccob0_3 = (F_PGM4 << 24) | address;
      flashData->controller->fccob4_7 = *data++;
      executeCommand(flashData->controller);
      address += 4;
   }
   flashData->flags &= ~DO_PROGRAM_RANGE;
}

//! Verify a range of flash against buffer
//!
void verifyRange(FlashData_t *flashData) {
   uint32_t        address       = flashData->address;
   const uint32_t *data          = flashData->dataAddress;
   uint32_t        numLongwords  = flashData->dataSize>>2;
   
   if ((flashData->flags&DO_VERIFY_RANGE) == 0) {
      return;
   }
   // Verify words
   while (numLongwords-- > 0) {
      flashData->controller->fccob0_3 = (F_PGMCHK << 24) | address;
      flashData->controller->fccob4_7 = (F_USER_MARGIN<<24) | 0;
      flashData->controller->fccob8_B = *data;
      executeCommand(flashData->controller);
      address += 4;
      data++;
   }
   flashData->flags &= ~DO_VERIFY_RANGE;
}

//! Erase a range of flash
//!
void eraseRange(FlashData_t *flashData) {
   uint32_t   address     = flashData->address;
   uint32_t   endAddress  = address + flashData->dataSize - 1; // Inclusive
   uint32_t   pageMask    = flashData->sectorSize-1U;
   
   if ((flashData->flags&DO_ERASE_RANGE) == 0) {
      return;
   }
   // Check for empty range before block rounding
   if (flashData->dataSize == 0) {
      return;
   }
   // Round start address to start of block (inclusive)
   address &= ~pageMask;
   
   // Round end address to end of block (inclusive)
   endAddress |= pageMask;
   
   // Erase each sector
   while (address <= endAddress) {
      flashData->controller->fccob0_3 = (F_ERSSCR << 24) | address;
      executeCommand(flashData->controller);
      // Advance to start of next sector
      address += flashData->sectorSize;
   }
   flashData->flags &= ~DO_ERASE_RANGE;
}

#if 1
//! Check that a range of flash is blank (=0xFFFF)
//!
void blankCheckRange(FlashData_t *flashData) {
   const int  itemSize  = 4;
   uint32_t  *address   = (uint32_t *)(flashData->address);
   uint32_t   numItems  = (flashData->dataSize+itemSize-1)/itemSize;
   
   if ((flashData->flags&DO_BLANK_CHECK_RANGE) == 0) {
      return;
   }
//   if (((int)address & (itemSize-1)) != 0) {
//      setErrorCode(FLASH_ERR_ILLEGAL_PARAMS);
//   }
   while (numItems>0) {
      if (*address != 0xFFFFFFFFUL) {
         setErrorCode(FLASH_ERR_ERASE_FAILED);
      }
      numItems--;
      address++;
   }
   flashData->flags &= ~DO_BLANK_CHECK_RANGE;
}
#else
//! Check that a range of flash is blank (=0xFFFF)
//!
void blankCheckRange(FlashData_t *flashData) {
   static const uint32_t  elementSize = 8; // Size of element verified
   uint32_t                   address     = fixAddress(flashData->address);
   uint32_t                   numElements = (flashData->dataSize+elementSize-1)/elementSize;

   if ((flashData->flags&DO_BLANK_CHECK_RANGE) == 0) {
      return;
   }
   if ((address & (elementSize-1)) != 0) {
      setErrorCode(FLASH_ERR_ILLEGAL_PARAMS);
   }
   while (numElements>0) {
      int rc;
      uint16_t num = 0x8000;
      if (num>numElements) {
         num = numElements;
      }
      flashData->controller->fccob0_3 = (F_RD1SEC << 24) | address;
      flashData->controller->fccob4_7 = (num <<16) | (F_USER_MARGIN<<8) | 0;
      rc = executeCommand(flashData->controller);
      if (rc != FLASH_ERR_OK) {
         if (rc == FLASH_ERR_PROG_MGSTAT0) {
            rc = FLASH_ERR_ERASE_FAILED;
         }
//         flashData->frequency = controller->fccob0_3; // debug
//         flashData->address   = controller->fccob4_7;
         setErrorCode(rc);         
      }
      numElements -= num;
      address     += elementSize*num;
   }
   flashData->flags &= ~DO_BLANK_CHECK_RANGE;
}
#endif

//! Minimal vector table
extern uint32_t __vector_table[];

//! Some stack space
extern uint32_t __stacktop[];

//! Main C entry point
//! 
//! Assumes ramBuffer is set up beforehand
//!
void entry(void) {
   FlashData_t *flashData;  // Handle on programming data

   // Set the interrupt vector table position
   SCB_VTOR = (uint32_t)__vector_table;
   
   // Disable watchdog
   SIM_COPC = COP_DISABLE;
   
   // Handle on programming data
   flashData = gFlashProgramHeader.flashData;

   initFlash(flashData);
   eraseFlashBlock(flashData);
   eraseRange(flashData);
   blankCheckRange(flashData);
   programRange(flashData);
   verifyRange(flashData);
   
#ifndef DEBUG
   // Indicate completed & stop
   setErrorCode(FLASH_ERR_OK);
#endif
}

//! Default unexpected interrupt handler
//!
void isr_default(void) {
   setErrorCode(FLASH_ERR_TRAP);
}

//! Low level entry point
//! 
__attribute__((naked))
void asm_entry(void) {
#ifndef DEBUG
   // Setup the stack before we attempt anything else
   asm (
   "mov   r0,%[stacktop]\n\t"
   "mov   sp,r0\n\t"
   "b     entry\n\t"
   "bkpt  0\n\t"::[stacktop] "r" (__stacktop));
#else
   asm (
   "b     entry\n\t");
#endif
}

#ifndef DEBUG
void asm_testApp(void) {
}
#else
#define TEST 1
#if TEST == 1
// Programming general flash
static const uint8_t buffer[] = {0x00,0x11,0x22,0x33,0x44,0x55,0x66,0x77,0x88,0x99,0xAA,0xBB,0xCC,0xDD,0xEE,0xFF,
                                 0x00,0x11,0x22,0x33,0x44,0x55,0x66,0x77,0x88,0x99,0xAA,0xBB,0xCC,0xDD,0xEE,0xFF}; 

static const FlashData_t flashdataA = {
   /* flags      */ DO_INIT_FLASH|DO_ERASE_RANGE,
   /* controller */ FTFA_BASE_ADDRESS,
   /* frequency  */ 0,
   /* errorCode  */ 0xAA55,
   /* sectorSize */ FLASH_SECTOR_SIZE,
   /* address    */ 0x00000040,
   /* size       */ sizeof(buffer),
   /* data       */ (uint32_t *)buffer,
};
#define DO_B
static const FlashData_t flashdataB = {
   /* flags      */ DO_BLANK_CHECK_RANGE|DO_PROGRAM_RANGE|DO_VERIFY_RANGE,
   /* controller */ FTFA_BASE_ADDRESS,
   /* frequency  */ 0,
   /* errorCode  */ 0xAA55,
   /* sectorSize */ FLASH_SECTOR_SIZE,
   /* address    */ 0x000000040,
   /* size       */ sizeof(buffer),
   /* data       */ (uint32_t *)buffer,
};
#define DO_C
static const FlashData_t flashdataC = {
   /* flags      */ DO_INIT_FLASH|DO_ERASE_RANGE|DO_BLANK_CHECK_RANGE|DO_PROGRAM_RANGE|DO_VERIFY_RANGE,
   /* controller */ FTFA_BASE_ADDRESS,
   /* frequency  */ 0,
   /* errorCode  */ 0xAA55,
   /* sectorSize */ FLASH_SECTOR_SIZE,
   /* address    */ 0x00000840,
   /* size       */ sizeof(buffer),
   /* data       */ (uint32_t *)buffer,
};
#define DO_D
static const FlashData_t flashdataD = {
   /* flags      */ DO_INIT_FLASH|DO_ERASE_RANGE|DO_BLANK_CHECK_RANGE|DO_PROGRAM_RANGE|DO_VERIFY_RANGE,
   /* controller */ FTFA_BASE_ADDRESS,
   /* frequency  */ 0,
   /* errorCode  */ 0xAA55,
   /* sectorSize */ FLASH_SECTOR_SIZE,
   /* address    */ 0x00000C40,
   /* size       */ sizeof(buffer),
   /* data       */ (uint32_t *)buffer,
};
#define DO_E
static const FlashData_t flashdataE = {
   /* flags      */ DO_INIT_FLASH,
   /* controller */ FTFA_BASE_ADDRESS,
   /* frequency  */ 0,
   /* errorCode  */ 0xAA55,
};
#elif TEST == 2
// Unlock flash
static const FlashData_t flashdataA = {
   /* flags      */ DO_INIT_FLASH|DO_ERASE_RANGE|DO_UNLOCK_FLASH|DO_VERIFY_RANGE,
   /* controller */ FTFA_BASE_ADDRESS,
   /* frequency  */ 0,
   /* errorCode  */ 0xAA55,
   /* sectorSize */ FLASH_SECTOR_SIZE,
};
#elif TEST == 3
// Lock Flash 
static const FlashData_t flashdataA = {
   /* flags      */ DO_INIT_FLASH|DO_ERASE_RANGE|DO_LOCK_FLASH|DO_VERIFY_RANGE,
   /* controller */ FTFA_BASE_ADDRESS,
   /* frequency  */ 0,
   /* errorCode  */ 0xAA55,
   /* sectorSize */ FLASH_SECTOR_SIZE,
};
#elif TEST == 4
// Not used
static const FlashData_t flashdataA = {
   /* flags      */ DO_TIMING_LOOP,
   /* controller */ FTFA_BASE_ADDRESS,
   /* frequency  */ 0,
   /* errorCode  */ 0xAA55,
   /* sectorSize */ FLASH_SECTOR_SIZE,
};
#elif TEST == 5
// Set erasing ranges
static const FlashData_t flashdataA = {
   /* flags      */ DO_INIT_FLASH|DO_ERASE_RANGE|DO_BLANK_CHECK_RANGE,
   /* controller */ FTFA_BASE_ADDRESS,
   /* frequency  */ 0,
   /* errorCode  */ 0xAA55,
   /* sectorSize */ FLASH_SECTOR_SIZE,
   /* address    */ 0x00000045,
   /* size       */ 0x312-0x45,
};
#define DO_B
// Set erasing ranges
static const FlashData_t flashdataB = {
   /* flags      */ DO_ERASE_RANGE|DO_BLANK_CHECK_RANGE,
   /* controller */ FTFA_BASE_ADDRESS,
   /* frequency  */ 0,
   /* errorCode  */ 0xAA55,
   /* sectorSize */ FLASH_SECTOR_SIZE,
   /* address    */ 0x00001235,
   /* size       */ 0x1C3A-0x1235,
};
#elif TEST == 6
static const uint8_t buffer[] = {0x00,0x11,0x22,0x33,0x44,0x55,0x66,0x77,0x88,0x99,0xAA,0xBB,0xCC,0xDD,0xEE,0xFF}; 
// Mass erase + Unlock flash
static const FlashData_t flashdataA = {
   /* flags      */ DO_INIT_FLASH|DO_UNLOCK_FLASH|DO_ERASE_BLOCK,
   /* controller */ FTFA_BASE_ADDRESS,
   /* frequency  */ 0,
   /* errorCode  */ 0xAA55,
   /* sectorSize */ FLASH_SECTOR_SIZE,
};
#define DO_B
static const FlashData_t flashdataB = {
   /* flags      */ DO_INIT_FLASH|DO_BLANK_CHECK_RANGE|DO_PROGRAM_RANGE|DO_VERIFY_RANGE,
   /* controller */ FTFA_BASE_ADDRESS,
   /* frequency  */ 0,
   /* errorCode  */ 0xAA55,
   /* sectorSize */ FLASH_SECTOR_SIZE,
   /* address    */ 0x00000800,
   /* size       */ sizeof(buffer),
   /* data       */ (uint32_t *)buffer,
};
#define DO_C
static const FlashData_t flashdataC = {
   /* flags      */ DO_INIT_FLASH|DO_BLANK_CHECK_RANGE|DO_PROGRAM_RANGE|DO_VERIFY_RANGE,
   /* controller */ FTFA_BASE_ADDRESS,
   /* frequency  */ 0,
   /* errorCode  */ 0xAA55,
   /* sectorSize */ FLASH_SECTOR_SIZE,
   /* address    */ 0x00000900,
   /* size       */ sizeof(buffer),
   /* data       */ (uint32_t *)buffer,
};
#elif TEST == 7
// Checking security region actions
// Program region overlapping security area
static const uint8_t buffer[] = {0x00,0x11,0x22,0x33,0x44,0x55,0x66,0x77,0x88,0x99,0xAA,0xBB,0xFF,0xFF,0xFF,0xFF,
                                 0x00,0x11,0x22,0x33,0x44,0x55,0x66,0x77,0x88,0x99,0xAA,0xBB,0xFF,0xFF,0xFF,0xFF}; 

static const FlashData_t flashdataA = {
   /* flags      */ DO_INIT_FLASH|DO_ERASE_RANGE|DO_BLANK_CHECK_RANGE|DO_PROGRAM_RANGE|DO_VERIFY_RANGE,
   /* controller */ FTFA_BASE_ADDRESS,
   /* frequency  */ 0,
   /* errorCode  */ 0xAA55,
   /* sectorSize */ FLASH_SECTOR_SIZE,
   /* address    */ 0x000003F0,
   /* size       */ sizeof(buffer),
   /* data       */ (uint32_t *)buffer,
};
#elif TEST == 8
// Checking security anti-lockup
//static const uint8_t buffer[] = {0x00,0x11,0x22,0x33,0x44,0x55,0x66,0x77,0x88,0x99,0xAA,0xBB,
//                                 (FTFA_FSEC_KEY_ENABLE|FTFA_FSEC_MEEN_DISABLE|FTFA_FSEC_FSLACC|FTFA_FSEC_UNSEC),0xFF,0xFF,0xFF,}; 

static const FlashData_t flashdataA = {
   /* flags      */ DO_INIT_FLASH|DO_ERASE_RANGE|DO_BLANK_CHECK_RANGE|DO_PROGRAM_RANGE|DO_VERIFY_RANGE,
   /* controller */ FTFA_BASE_ADDRESS,
   /* frequency  */ 0,
   /* errorCode  */ 0xAA55,
   /* sectorSize */ FLASH_SECTOR_SIZE,
   /* address    */ 0x00000400,
   /* size       */ sizeof(buffer),
   /* data       */ (uint32_t *)buffer,
};
#endif

//! Dummy test program for debugging
void testApp(void) {
	FlashProgramHeader_t *fph = (FlashProgramHeader_t*) &gFlashProgramHeader;

   // Set the interrupt vector table position
   SCB_VTOR = (uint32_t)__vector_table;
   
   // Disable watchdog
   SIM_COPC = COP_DISABLE;
      
   fph->flashData = (FlashData_t *)&flashdataA;
   fph->entry();
#ifdef DO_B
   fph->flashData = (FlashData_t *)&flashdataB;
   fph->entry();
#endif
#ifdef DO_C
   fph->flashData = (FlashData_t *)&flashdataC;
   fph->entry();
#endif
#ifdef DO_D
   fph->flashData = (FlashData_t *)&flashdataD;
   fph->entry();
#endif
#ifdef DO_E
   fph->flashData = (FlashData_t *)&flashdataE;
   fph->entry();
#endif
}

//!
//!
__attribute__((naked))
void asm_testApp(void) {
   asm (
   // Setup the stack before we attempt anything else
   "mov   r0,%[stacktop]\n\t"
   "mov   sp,r0\n\t"
   // execute testApp	   
   "bl    testApp\n\t"
   // 
   "bkpt  0\n\t"::[stacktop] "r" (__stacktop));
}
#endif