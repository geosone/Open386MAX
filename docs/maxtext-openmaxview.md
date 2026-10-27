<!-- SPDX-License-Identifier: GPL-3.0-only -->
<!-- Copyright (C) 2026 Open386MAX contributors -->

# MAXTEXT integration review: Open MaxView

This review describes the released beta4 baseline. Current MAXTEXT additions
are described in [the main guide](maxtext.md); Open MaxView integration is
scheduled after native SVGA and MAXLOAD.

Source review: 2026-10-24, Open MaxView checkout
`35164b820d87002a5fced7f8c8429a2abfda6be5` and MAXTEXT API 1.1 as released
in Open386MAX `v9.00-beta4`. This is an integration plan, not an implemented
or tested Open MaxView feature. No Open MaxView files were changed.

MAXTEXT is useful as an optional physical text-mode service. Open MaxView
must retain its ordinary BIOS path when the driver is absent. QUILIB's
geometry fixes do not carry over automatically: Open MaxView uses its own
renderer. Its README still describes the single-child 0.8 milestone, while
the reviewed source also contains a QPI-based multitasking kernel. Both
the foreground child path and the multitasking path need consideration.

## Findings in the reviewed source

| Component | Current source behaviour | Required integration work |
| --- | --- | --- |
| Shared UI (`include/mvui.h:5`, `src/mvui.c:9`) | Constant 80 columns and 25 rows; direct text writes. `mvui_restore` resets BIOS mode 3. | Obtain bounded geometry, active-page offset and font height; clip writes; define an exit-mode policy instead of silently losing the selected geometry. |
| Launcher (`src/opendesq.c:20`, `:203`, `:215`) | Separate renderer with the same constants. Initialization only selects B000h/B800h and hides the cursor. Child preparation clears 25 rows and uses a fixed cursor shape. | Share geometry discovery, clear the actual viewport and select a cursor appropriate to the font. Revalidate mode, page and geometry after child return. |
| Window composition (`src/opendesq.c:686`, `:746`) | Screen and task-preview arrays contain 2000 cells; clipping and source stride assume 80x25. | Separate physical desktop geometry from each task's geometry. Size and bound both buffers and clip each task independently. |
| Task preview (`include/mvkern.h`, `kernel/mvkern.asm:3410`) | `mvk_peek` explicitly copies 2000 words and returns only the cursor. | Add a bounded preview interface carrying columns, rows, page offset and capacity. Keep the old entry point's 2000-cell contract for existing callers. |
| Kernel mode switching (`kernel/mvkern.asm:1038`, `:1073`, `:2692`) | Saves mode and row count; restores BIOS 25/43/50-row text modes; BIOS emulation derives row count but selects 40/80-column layouts. Eight private 4 KiB pages cover the colour text aperture. | Preserve this existing behaviour and verify physical mode changes. The 4 KiB copy buffer is a memory-page transfer buffer, not evidence that every screen must fit in 4 KiB. 132-column layouts need additional work. |
| ANSI console (`kernel/maxvansi.asm:255`, `:267`, `:405`) | Cursor bounds, erase rectangle, wrapping and scrolling contain fixed 80x25 limits. | Refresh validated geometry and active-page information; use the actual bottom row and last column throughout. |
| Compatibility TSR (`kernel/odqtsr.asm:1010`, `:4250`) | Some physical-screen operations already read BIOS columns/rows/page offset. Own-window resizing still clamps to 25x80. | Audit object creation, resizing, alternate buffers and pool bounds together. Keep guest-window limits distinct from physical display dimensions. |

The kernel's existing 43-row path requests a BIOS 350-line mode and loads
the 8-pixel font. MAXTEXT's verified 43-row fallback must not be assumed to
apply to this independent path. Test actual rows after foreground changes,
including on firmware that acknowledges the scan-line request without
applying it.

## Interface and ownership

Use the [public handle IOCTL API](maxtext.md#public-api-12), rather than
walking DOS device chains or inventing another interrupt hook. The supplied
`INCLUDE/MAXTEXT.H` and `MAXTEXT/MTEXAPI.C` describe detection, status and
control packets. Validate the device handle, signatures, lengths and ABI;
use the capability bitmap to offer only supported modes. Version 1.1 offers
80x25, 80x43 and 80x50, not VBE, 132-column or 60-row modes.

A bitmap bit does not guarantee that a switch is permitted in the current
context. Handle the returned error, retain a usable display after failure,
and report rollback failure separately. A switch needs at least 104 KiB of
temporary conventional-memory scratch space; budget that before allocating
child memory. Free scratch after the transaction.

Perform DOS open/IOCTL/allocation calls from the launcher's normal DOS
execution path with task switching appropriately coordinated. Do not call
them from timer interrupts, DOS hooks or an arbitrary scheduler callback.
MAXTEXT is a global hardware service without a task identifier or per-task
font/state store. It cannot itself virtualize a different hardware mode for
each background task. Background work must not change the physical desktop
mode behind the foreground owner's back.

Open MaxView's `AGENTS.md` additionally requires the standard/root 386MAX
context before starting Windows, with success verified and launch aborted
if it cannot be established. Preserve that invariant. MAXTEXT rejects mode
changes while Windows owns the display. Windows launch and return need
explicit mode ownership and context tests; the ordinary `system()` path is
not proof that those transitions are safe.

`RESTORE` means the driver's boot geometry, not the geometry that an
individual application saved on entry. Store the launcher's selected mode
separately. Applications that need 80x25 should have an explicit per-program
policy, followed by revalidation and restoration of the desktop on return.
Child applications may change modes independently of MAXTEXT.

## Implementation sequence and acceptance criteria

1. Add an optional client and status/settings display; preserve startup
   without MAXTEXT. Offer only modes present in the validated API bitmap.
2. Make both renderers and their buffers geometry-aware. Initially limit
   selectable desktop modes to the supported 80-column family. Test the
   lowest visible row, clipping, page offsets, font-dependent cursors and
   child mode changes at 25, 43 and 50 rows.
3. Extend the bounded task-preview interface, ANSI console and compatibility
   window/buffer operations. Test mixed task geometries, repeated foreground
   changes, output on the last row and constrained memory. Test direct BIOS
   mode changes as well as MAXTEXT-controlled ones.
4. Enable persistent desktop/per-program mode selection only after ownership
   is enforced in both launch paths. Test missing/old driver, malformed API
   responses, unsupported contexts, allocation failure, rollback and Windows
   root-context transitions. Keep test programs in the target repository's
   test-source tree and host shell runners in its established host-test tree.

The published Open386MAX tests validate MAXTEXT and Open386MAX's DOS tools;
they do not establish Open MaxView compatibility. No runtime Open MaxView
test was performed for this review. Physical graphics cards and additional
VBE/SVGA modes remain separate validation targets.
