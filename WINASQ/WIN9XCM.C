/* WIN9XCM.C:  memory ranges of the devices under Windows 9x, from the
 * Configuration Manager (HKEY_DYN_DATA\Config Manager\Enum\<node>:
 * HardWareKey, Allocation), their names from HKEY_LOCAL_MACHINE\Enum\
 * <HardWareKey> DeviceDesc.  WINASQ is a Win16 program:  it calls the
 * Win32 registry functions of ADVAPI32 through the generic thunks of
 * KERNEL (LoadLibraryEx32W, GetProcAddress32W, CallProcEx32W), looked up
 * at run time; Windows 3.x has none of it.
 *
 * Allocation (the allocated logical configuration, as in configmg.h):
 *	DWORD	version (0x400)
 *	DWORD	priority
 *	records:  DWORD length (with this header), DWORD type, data;
 *		  length 0 ends them
 *	type 1 (ResType_Mem), MEM_DES:  WORD count, WORD size of MEM_RANGE,
 *		  DWORD base, DWORD end (inclusive), WORD flags, WORD reserved
 *
 * Open 386MAX - GNU General Public License version 3.
 */

#include <windows.h>
#include <string.h>

#include "winasq.h"

#define HKEY_LOCAL_MACHINE32	0x80000002L
#define HKEY_DYN_DATA32 	0x80000006L
#define KEY_READ32		0x00020019L
#define CPEX_DEST_STDCALL	0x00000000L

typedef DWORD (FAR PASCAL *LOADLIB32)(LPCSTR, DWORD, DWORD);
typedef BOOL (FAR PASCAL *FREELIB32)(DWORD);
typedef DWORD (FAR PASCAL *GETPROC32)(DWORD, LPCSTR);
typedef DWORD (FAR _cdecl *CALLPROCEX32)(DWORD, DWORD, DWORD, ...);

static LOADLIB32 pLoadLib32;
static FREELIB32 pFreeLib32;
static GETPROC32 pGetProc32;
static CALLPROCEX32 pCallProc32;
static DWORD hAdvapi;			/* ADVAPI32.DLL */
static DWORD pOpen, pEnum, pQuery, pClose;	/* Its functions */

DEVMEM DevMem[MAXDEVMEM];		/* The ranges found */
int nDevMem;

/* CallProcEx32W:  number of parameters, the mask of the 16:16 pointers
 * to make flat (bit 0:  the first parameter), the function */
static long reg_open(DWORD key, LPCSTR sub, DWORD FAR *res)
{
	return pCallProc32(5 | CPEX_DEST_STDCALL, 0x12L, pOpen,
			   key, sub, 0L, KEY_READ32, res);
}

static long reg_enum(DWORD key, DWORD i, LPSTR name, DWORD n)
{
	return pCallProc32(4 | CPEX_DEST_STDCALL, 0x04L, pEnum,
			   key, i, name, n);
}

static long reg_query(DWORD key, LPCSTR name, LPVOID data, DWORD FAR *n)
{
	DWORD type;

	return pCallProc32(6 | CPEX_DEST_STDCALL, 0x3AL, pQuery,
			   key, name, 0L, (DWORD FAR *) &type, data, n);
}

static void reg_close(DWORD key)
{
	pCallProc32(1 | CPEX_DEST_STDCALL, 0L, pClose, key);
}


int cm_init(void)
/* The thunks and ADVAPI32; 0 if there */
{
	HMODULE hk;

	if (hAdvapi) return 0;
	if ((GetVersion() & 0xFFFF) < 0x5F03) return -1;	/* < 3.95 */
	hk = GetModuleHandle("KERNEL");
	pLoadLib32 = (LOADLIB32) GetProcAddress(hk, "LoadLibraryEx32W");
	pFreeLib32 = (FREELIB32) GetProcAddress(hk, "FreeLibrary32W");
	pGetProc32 = (GETPROC32) GetProcAddress(hk, "GetProcAddress32W");
	pCallProc32 = (CALLPROCEX32) GetProcAddress(hk, "_CallProcEx32W");
	if (!pCallProc32)
		pCallProc32 = (CALLPROCEX32) GetProcAddress(hk, "CallProcEx32W");
	if (!pLoadLib32 || !pFreeLib32 || !pGetProc32 || !pCallProc32)
		return -1;
	hAdvapi = pLoadLib32("ADVAPI32.DLL", 0L, 0L);
	if (!hAdvapi) return -1;
	pOpen = pGetProc32(hAdvapi, "RegOpenKeyExA");
	pEnum = pGetProc32(hAdvapi, "RegEnumKeyA");
	pQuery = pGetProc32(hAdvapi, "RegQueryValueExA");
	pClose = pGetProc32(hAdvapi, "RegCloseKey");
	if (!pOpen || !pEnum || !pQuery || !pClose) {
		pFreeLib32(hAdvapi);
		hAdvapi = 0;
		return -1;
	}
	return 0;
}


void cm_done(void)
{
	if (hAdvapi) pFreeLib32(hAdvapi);
	hAdvapi = 0;
}


static void device_name(char *hwkey, char *name, int nname)
/* DeviceDesc of HKLM\Enum\hwkey, else hwkey */
{
	char path[200];
	DWORD key, n = nname;

	lstrcpyn(name, hwkey, nname);
	wsprintf(path, "Enum\\%s", (LPSTR) hwkey);
	if (reg_open(HKEY_LOCAL_MACHINE32, path, &key) != 0) return;
	if (reg_query(key, "DeviceDesc", name, &n) != 0 || !name[0])
		lstrcpyn(name, hwkey, nname);
	reg_close(key);
}


int cm_read(void)
/* All memory ranges of the devices into DevMem[]; their number, -1
 * without the Configuration Manager */
{
	static BYTE alloc[1024];
	char node[20], path[80], hwkey[120];
	DWORD enumkey, key, i, n;
	unsigned off, len;
	DWORD type;

	nDevMem = 0;
	if (cm_init() != 0) return -1;
	if (reg_open(HKEY_DYN_DATA32, "Config Manager\\Enum", &enumkey) != 0)
		return -1;
	for (i = 0; reg_enum(enumkey, i, node, sizeof(node)) == 0; i++) {
		wsprintf(path, "Config Manager\\Enum\\%s", (LPSTR) node);
		if (reg_open(HKEY_DYN_DATA32, path, &key) != 0) continue;
		n = sizeof(hwkey);
		if (reg_query(key, "HardWareKey", hwkey, &n) != 0) hwkey[0] = '\0';
		n = sizeof(alloc);
		if (reg_query(key, "Allocation", alloc, &n) != 0) n = 0;
		reg_close(key);

		for (off = 8; off + 8 <= (unsigned) n; off += len) {
			len = *(WORD *) (alloc + off);
			type = *(DWORD *) (alloc + off + 4);
			if (len < 8 || off + len > (unsigned) n) break;
			if (type != 1 || len < 8 + 12) continue;
			if (nDevMem >= MAXDEVMEM) break;
			DevMem[nDevMem].base = *(DWORD *) (alloc + off + 12);
			DevMem[nDevMem].end = *(DWORD *) (alloc + off + 16);
			device_name(hwkey, DevMem[nDevMem].name,
				    sizeof(DevMem[0].name));
			nDevMem++;
		}
	}
	reg_close(enumkey);
	return nDevMem;
}
