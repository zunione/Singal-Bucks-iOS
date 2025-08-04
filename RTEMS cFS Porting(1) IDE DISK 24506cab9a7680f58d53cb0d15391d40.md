# RTEMS/cFS Porting(1): IDE DISK

**💡 Alan Cudmore’s advice:** 
As a first step, you could try commenting out the IDE disk code in the OSAL BSP and the network initialization code in the PSP to see if you can create a cFE core binary that will load and run on your LEON3. It will report that it cannot find the cFE startup script to load apps, but that would be a good first goal.

→ IDE 파일 시스템을 주석 처리한 후 실행이 되는지 확인한다. cFE startup script를 찾을 수 없다고 뜨지만, 1차적으로는 성공이다.

# 1. Toolchain

> `cfe/cmake/sample_defs` 디렉토리를 복사하여 cfs 바로 밑에 붙여넣기한다.
> 

## 1.1 `toolchain-gr740-rtems6.cmake` 추가

```c
/* i686 vs gr740 */

/* 변경점 */
SET(CMAKE_SYSTEM_PROCESSOR sparc)
SET(RTEMS_BSP              "gr740")
SET(CFE_SYSTEM_PSPNAME     generic-rtems)
SET(OSAL_SYSTEM_BSPTYPE    generic-rtems)
SET(RTEMS_BSP_C_FLAGS      "-mcpu=leon3 -fno-common -B${RTEMS_BSP_ROOT}/lib")
SET(LINK_LIBRARIES         "-lrtemsdefaultconfig")
SET(RTEMS_TOOLS_PREFIX     "/opt/rtems/rtems-6-sparc-gr740-smp-6" CACHE PATH
    "RTEMS tools install directory")

/* 추가점 */
SET(RTEMS_INCLUDE_TARFS    FALSE)
SET(RTEMS_NO_CMDLINE       TRUE)

if (NOT DEFINED ENV{RTEMS_NO_SHELL})
  SET(RTEMS_NO_SHELL TRUE)
else ()
  SET(RTEMS_NO_SHELL $ENV{RTEMS_NO_SHELL})
endif ()

if (RTEMS_INCLUDE_TARFS)
    ADD_DEFINITIONS(-DRTEMS_INCLUDE_TARFS)
endif ()

SET(RTEMS_BSP_ROOT              "${RTEMS_TOOLS_PREFIX}/sparc-rtems6/gr740-extra")
SET(CMAKE_EXE_LINKER_FLAGS_INIT "-B${RTEMS_BSP_ROOT}/lib -qrtems -mcpu=leon3")
SET(CMAKE_SIZE                  "${RTEMS_TOOLS_PREFIX}/bin/${TARGETPREFIX}size")
```

## 1.2 `targets.cmake` 수정

```c
/* 변경점 */
SET(cpu1_SYSTEM gr740-rtems6)
```

# 2. OSAL

> NASA CFS Github 최신 main 브랜치를 clone하면, `osal/src/bsp`에 `generic-rtems` 디렉토리가 있다.
> 

## 2.1 `default_bsp_rtems_cfg` 수정

```c
/* 
 * 아래 항목 주석 처리
 * DOSFS: Windows DOS File System
 * IDE/ATA: Not needed for GR740
 */
#define CONFIGURE_FILESYSTEM_DOSFS
#define CONFIGURE_APPLICATION_NEEDS_IDE_DRIVER
#define CONFIGURE_APPLICATION_NEEDS_ATA_DRIVER
#define CONFIGURE_ATA_DRIVER_TASK_PRIORITY 9
```

## 2.2 `bsp_mount_setupfs.c` 수정

```c
/* 
 * 아래 항목 주석 처리
 * Block Device: Some functions deprecated in RTEMS 6
 * IDE/ATA: Not needed for GR740
 */
#include <rtems/bdbuf.h>
#include <rtems/blkdev.h>
#include <rtems/diskdevs.h>
#include <rtems/bdpart.h>

extern rtems_status_code rtems_ide_part_table_initialize(const char *);
/* Line 89-109: Register the IDE partition table */
```

# 3. PSP

> `psp/fsw` 디렉토리에서 `pc-rtems`를 복사해 `generic-rtems` 디렉토리를 생성한다. 이후 https://github.com/nasa/PSP/pull/376을 참고해 수정한다.
> 

## 3.1 `build_options.cmake` 수정

```c
/* 변경점 */
SET(INSTALL_SUBDIR "nonvol")

/* 추가점 */
# Disable networking for RTEMS 6
SET(OSAL_CONFIG_INCLUDE_NETWORK FALSE CACHE BOOL "Include networking")

# Alternative approach: Undefine problematic macros and redefine them as disabled
add_definitions("-UCONFIGURE_APPLICATION_NEEDS_IDE_DRIVER")  
add_definitions("-UCONFIGURE_APPLICATION_NEEDS_ATA_DRIVER")

# IMFS 활성화 (RAMDISK 대신)
ADD_DEFINITIONS(-DUSE_IMFS_AS_BASE_FILESYSTEM)
```

## 3.2 `cfe_psp_start.c` 수정

```c
/* 변경점 */
#ifdef __rtems__
  #if __RTEMS_MAJOR__ >= 6
    // RTEMS 6+ doesn't use rtems_bsdnet
    // Networking disabled for RTEMS 6
  #else
    #include <rtems/rtems_bsdnet.h>
    extern int rtems_fxp_attach(struct rtems_bsdnet_ifconfig *config, int attaching);
  #endif
#endif

#if RTEMS_INCLUDE_TARFS
Status = OS_FileSysAddFixedMap(&fs_id, "/nonvol", "/cf");

/* 추가점 */
/* Line 95-154: Enable networking when using TARFS */

/* 삭제점 */
#include <rtems/rtems_dhcp_failsafe.h>
#include <bsp.h>
/* Line 72-93: Ethernet and BSD Network codes, libbsd is the more recommended library */
```

# 4. cFE

## 4.1 arch_build.cmake

`Sample_def` 디렉토리의 Startup script 파일에 모듈 이름이 붙어 있는데, 주석에는 모듈 이름이 제거되어 저장된다고 적혀 있으나 실제로 제거 로직이 구현되어 있지 않다. 파일 이름이 달라 생기는 문제를 방지하기 위해 해당 로직을 추가했다.

빌드 시, `cpu1_cfe_ec_startup.scr` → `cfe_ec_startup.scr` 로 `build/exe/cpu1/nonvol` 에 저장

```c
string(REGEX REPLACE "^${TGTNAME}_" "" FINAL_INSTFILE "${INSTFILE}")
message(STATUS "NOTE: Selected ${FILESRC} as source for ${INSTFILE} on ${TGTNAME}")
install(FILES ${FILESRC} DESTINATION ${TGTNAME}/${INSTALL_SUBDIR} RENAME ${FINAL_INSTFILE})  # ← FINAL_INSTFILE 사용!
```

# 5. 실행

위 변경사항을 적용하고 다음 명령어를 실행한다.

```bash
$ sis -gr740 build/exe/cpu1/core-cpu1.exe 
sis> run
...
1980-012-14:03:20.52303 CFE_ES_StartApplications: Error, Can't Open ES App Startup file: /RAM/cfe_es_startup.scr, EC = -108
...
EVS Port1 1980-012-14:03:21.00265 66/1/CFE_TIME 21: Stop FLYWHEEL
```

Alan의 설명대로, startup script를 열 수 없다는 에러 메시지가 출력된다.

# 5. Static File System

## 5.1 **STATIC_APPLIST**

> **Jesus Zurera:** In its native build configuration cFS is configured to create different executables for the core and the applications. So, when running cFS in a different platform from the one compiled in you need to include, alongside with the main executable, the startup script and the other executable files .obj of the applications you desire in the project and allocate them in a known location.
> 
- cFS는 Core과 Application을 분리된 실행 파일로 빌드하도록 설계되어 있다.
- 따라서 cFS를 컴파일된 환경과 다른 플랫폼에서 실행하기 위해서는, 메인 실행 파일, startup script, 그리고 사용자가 원하는 그 외 .obj 실행 파일들을 프로젝트에 넣고 명시적 위치에 배치해야 한다.

> **Jesus Zurera (Continued):** This could be inadequate in case the hardware required only one binary file. That’s why cFS has the option of building the applications together with the main core executable in only one binary. It is done using the static app list instead of the in the targets.cmake config file.
> 
- 이 방식은 하드웨어가 단일 바이너리 파일만을 필요로 할 경우 부적절할 수 있다.
- 그래서 cFS는 메인 코어 실행 파일과 application들을 하나의 바이너리 파일로 빌드할 수 있는 옵션을 가지고 있다.
- 이를 위해서는 `targets.cmake` 파일에서 static app list를 사용하면 된다.

> **Jesus Zurera (Continued):** However, it does not exist, or I have not been able to find a guide or tutorial that explains how to indicate to cFS that the applications that it must add and run are not found as files in a certain directory but included in the binary file itself. Applications added to this list of static applications should be initialized automatically, like dynamic ones, but cFS seems not to be designed this way.
> 
- 그러나 cFS에게 application들이 특정한 디렉토리에 있는 것이 아니라 바이너리 파일 자체에 들어있다는 사실을 지시하는 방법을 찾지 못했다.
- 이 static application 리스트에 추가된 어플리케이션들은 dynamic처럼 자동으로 초기화되어야 하는데, cFS는 이 방향으로 설계되지 않은 것 같다.
- 이 static application 리스트에 추가된 어플리케이션들은 dynamic처럼 자동으로 초기화되어야 하는데, cFS는 이 방향으로 설계되지 않은 것 같다.

### 5.1.1 `targets.cmake` 수정

```c
SET(cpu1_STATIC_APPLIST ci_lab to_lab sch_lab sample_app sample_lib)
SET(cpu1_STATIC_SYMLIST 
    CI_LAB_AppMain,ci_lab
    TO_LAB_AppMain,to_lab  
    SCH_LAB_AppMain,sch_lab
    SAMPLE_APP_Main,sample_app
    SAMPLE_LIB_Init,sample_lib
)
```

## 5.2 EMBED_FILELIST

> **Joseph Hickey:** You are correct in that the "static" app linkage is intended to address those use cases where the entire system needs to be contained in a single binary package, and/or where apps cannot be loaded from separate module files at runtime as usual. This permits all of the code to be loaded on the target as a single binary file.
> 
- Static app linkage는 전체 시스템이 하나의 바이너리 패키지에 포함되어 있어야 하거나 앱들이 분리된 모듈에서 로드될 수 없는 환경일 때 사용되는 것이 맞다.
- 이는 모든 코드가 단일 바이너리 파일로서 타겟에 로드될 수 있도록 한다.

> **Joseph Hickey (continued):** The startup script is a bit of a problem, as it still (typically) must be loaded from a filesystem. To address this, there is an option to link the file directly with the executable via the EMBED_FILELIST directive in targets.cmake. This takes an arbitrary file from the dev host, and wraps the entire content into a C structure which is then linked into the binary. The idea is that during boot, this file can then be written to a RAM disk by the PSP, to be opened by CFE when needed. It works to get around the cfe_es_startup.scr problem if you do not have persistent storage.
> 
- Startup script가 여전히 파일 시스템으로부터 로드되어야 하기 때문에 여전히 문제가 된다.
- 이를 위해 targets.cmake 파일에서 EMBED_FILELIST 선언을 사용해 startup script를 실행 파일과 바로 연결할 수 있는 옵션이 있다.
- EMBED_FILELIST는 개발자의 컴퓨터로부터 임의의 파일을 가져가, 모든 내용을 C 구조로 만든 다음 이를 바이너리와 연결한다.
- 부팅 과정에서 PSP가 이 바이너리를 RAM에 쓰고, cFE는 필요 시 이를 읽는다.
- 이렇게 하면 영구 저장소 없이도 cfe_es_startup.scr 문제를 해결할 수 있다.

### 5.2.1 `targets.cmake` 수정

```c
SET(cpu1_EMBED_FILELIST CFE_ES_STARTUP_DATA,cpu1_cfe_es_startup.scr)
```

### 5.2.2 생성되는 파일

cpu1_EMBED_FILELIST 옵션을 사용하면 다음과 같은 파일이 생긴다.

```c
/* build/gr740-rtems6/default_cpu1/cpu1/embed/CRE_ES_STARTUP_DATA.c */
const unsigned char CFE_ES_STARTUP_DATA_DATA[] = {
#include "CFE_ES_STARTUP_DATA.inc"
};
const unsigned long CFE_ES_STARTUP_DATA_SIZE = sizeof(CFE_ES_STARTUP_DATA_DATA);
```

```c
/* build/gr740-rtems6/default_cpu1/cpu1/embed/CRE_ES_STARTUP_DATA.inc */
0x43, 0x46, 0x45, 0x5f, 0x4c, 0x49, 0x42, 0x2c, 0x20, 0x63, 0x66, 0x65,
...
```

### 5.2.1 `cfe_psp_start` 수정

```c
/* 
 * 아래 항목 주석 처리
 * LEON/GR740 시뮬레이터: 비휘발성 저장소가 시뮬레이션되지 않음
 * SIS 시뮬레이터: RAM만 제공, nonvol 지원 없음
 * 따라서 RAM 메모리를 직접적으로 액세스하고 /cf는 접근하지 않는다.
 */
 Status = OS_FileSysAddFixedMap(&fs_id, "/nonvol", "/cf");
if (Status != OS_SUCCESS)
{
	/* Print for informational purposes --
	 * startup can continue, but loads may fail later, depending on config. */
	OS_printf("CFE_PSP: OS_FileSysAddFixedMap() failure: %d\n", (int)Status);
}
```

## 5.3 cfe_psp_start 수정

파일을 찾고 읽어오는 과정에서 startup script를 아예 찾지 못 하고 있다.

파일 시스템을 사용하지 않기 때문으로 추정되어 MAIN_FUNCTION에서 startup script를 전달하는 인자를 빈 문자열로 변경했다.

NULL을 전달하는 것이 나을지 빈 문자열이 나을지 실험이 필요하다.

```c
CFE_PSP_MAIN_FUNCTION(reset_type, reset_subtype, 1, "");
```

# 6. 실행

SIS(Simple Instruction Simulator)를 설치한 후 다음 명령어를 실행한다.

```bash
$ sis -gr740 build/exe/cpu1/core-cpu1.exe
sis> run
...
1980-012-14:03:20.52318 CFE_ES_StartApplications: CFE_FS_ParseInputFileName() RC=c6000002 parsing StartFilePath.
```

- **시스템 초기화는 성공** - CFE core 모듈들(ES, EVS, SB, TIME, TBL 등)이 모두 정상적으로 초기화됨
- **StartFilePath 파싱 실패** - `cfe_es_startup.scr` 파일을 찾을 수 없음
- **시스템은 OPERATIONAL 상태로 진행** - 하지만 애플리케이션들이 시작되지 않음