/*-
 * Copyright (c) 1991 Regents of the University of California.
 * All rights reserved.
 *
 * This code is derived from software contributed to Berkeley by
 * the Systems Programming Group of the University of Utah Computer
 * Science Department and William Jolitz of UUNET Technologies Inc.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. All advertising materials mentioning features or use of this software
 *    must display the following acknowledgement:
 *      This product includes software developed by the University of
 *      California, Berkeley and its contributors.
 * 4. Neither the name of the University nor the names of its contributors
 *    may be used to endorse or promote products derived from this software
 *    without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE REGENTS AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE REGENTS OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 *
 * Derived from hp300 version by Mike Hibler, this version by William
 * Jolitz uses a recursive map [a pde points to the page directory] to
 * map the page tables using the pagetables themselves. This is done to
 * reduce the impact on kernel virtual memory for lots of sparse address
 * space, and to reduce the cost of memory to each process.
 *
 *      from: hp300: @(#)pmap.h 7.2 (Berkeley) 12/16/90
 *      from: @(#)pmap.h        7.4 (Berkeley) 5/12/91
 * 	from: FreeBSD: src/sys/i386/include/pmap.h,v 1.70 2000/11/30
 *
 * $FreeBSD$
 */
 #include <machine/acle-compat.h>

#if __ARM_ARCH >= 6
#include <machine/pmap-v6.h>
#else /* __ARM_ARCH >= 6 */

#ifndef _MACHINE_PMAP_H_
#define _MACHINE_PMAP_H_

#include <machine/pte.h>
#include <machine/cpuconf.h>
/*
 * Pte related macros
 */
#if ARM_ARCH_6 || ARM_ARCH_7A
#ifdef SMP
#define PTE_NOCACHE	2
#else
#define PTE_NOCACHE	1
#endif
#define PTE_CACHE	6
#define PTE_DEVICE	2
#define PTE_PAGETABLE	6
#else
#define PTE_NOCACHE	1
#define PTE_CACHE	2
#define PTE_DEVICE	PTE_NOCACHE
#define PTE_PAGETABLE	3
#endif

enum mem_type {
	STRONG_ORD = 0,
	DEVICE_NOSHARE,
	DEVICE_SHARE,
	NRML_NOCACHE,
	NRML_IWT_OWT,
	NRML_IWB_OWB,
	NRML_IWBA_OWBA
};

#ifndef LOCORE

#include <sys/queue.h>
#include <sys/_cpuset.h>
#include <sys/_lock.h>
#include <sys/_mutex.h>

#define PDESIZE		sizeof(pd_entry_t)	/* for assembly files */
#define PTESIZE		sizeof(pt_entry_t)	/* for assembly files */

#ifdef _KERNEL

#define vtophys(va)	pmap_kextract((vm_offset_t)(va))

#endif

#define	pmap_page_get_memattr(m)	((m)->md.pv_memattr)
#define	pmap_page_is_write_mapped(m)	(((m)->aflags & PGA_WRITEABLE) != 0)
#if (ARM_MMU_V6 + ARM_MMU_V7) > 0
boolean_t pmap_page_is_mapped(vm_page_t);
#else
#define	pmap_page_is_mapped(m)	(!TAILQ_EMPTY(&(m)->md.pv_list))
#endif
void pmap_page_set_memattr(vm_page_t m, vm_memattr_t ma);

/*
 * Pmap stuff
 */

/*
 * This structure is used to hold a virtual<->physical address
 * association and is used mostly by bootstrap code
 */
struct pv_addr {
	SLIST_ENTRY(pv_addr) pv_list;
	vm_offset_t	pv_va;
	vm_paddr_t	pv_pa;
};

struct	pv_entry;
struct	pv_chunk;

struct	md_page {
	int pvh_attrs;
	vm_memattr_t	 pv_memattr;
#if (ARM_MMU_V6 + ARM_MMU_V7) == 0
	vm_offset_t pv_kva;		/* first kernel VA mapping */
#endif
	TAILQ_HEAD(,pv_entry)	pv_list;
};

struct l1_ttable;
struct l2_dtable;


/*
 * The number of L2 descriptor tables which can be tracked by an l2_dtable.
 * A bucket size of 16 provides for 16MB of contiguous virtual address
 * space per l2_dtable. Most processes will, therefore, require only two or
 * three of these to map their whole working set.
 */
#define	L2_BUCKET_LOG2	4
#define	L2_BUCKET_SIZE	(1 << L2_BUCKET_LOG2)
/*
 * Given the above "L2-descriptors-per-l2_dtable" constant, the number
 * of l2_dtable structures required to track all possible page descriptors
 * mappable by an L1 translation table is given by the following constants:
 */
#define	L2_LOG2		((32 - L1_S_SHIFT) - L2_BUCKET_LOG2)
#define	L2_SIZE		(1 << L2_LOG2)

struct	pmap {
	struct mtx		pm_mtx;
	u_int8_t		pm_domain;
	struct l1_ttable	*pm_l1;
	struct l2_dtable	*pm_l2[L2_SIZE];
	cpuset_t		pm_active;	/* active on cpus */
	struct pmap_statistics	pm_stats;	/* pmap statictics */
#if (ARM_MMU_V6 + ARM_MMU_V7) != 0
	TAILQ_HEAD(,pv_chunk)	pm_pvchunk;	/* list of mappings in pmap */
#else
	TAILQ_HEAD(,pv_entry)	pm_pvlist;	/* list of mappings in pmap */
#endif
};

typedef struct pmap *pmap_t;

#ifdef _KERNEL
extern struct pmap	kernel_pmap_store;
#define kernel_pmap	(&kernel_pmap_store)

#define	PMAP_ASSERT_LOCKED(pmap) \
				mtx_assert(&(pmap)->pm_mtx, MA_OWNED)
#define	PMAP_LOCK(pmap)		mtx_lock(&(pmap)->pm_mtx)
#define	PMAP_LOCK_DESTROY(pmap)	mtx_destroy(&(pmap)->pm_mtx)
#define	PMAP_LOCK_INIT(pmap)	mtx_init(&(pmap)->pm_mtx, "pmap", \
				    NULL, MTX_DEF | MTX_DUPOK)
#define	PMAP_OWNED(pmap)	mtx_owned(&(pmap)->pm_mtx)
#define	PMAP_MTX(pmap)		(&(pmap)->pm_mtx)
#define	PMAP_TRYLOCK(pmap)	mtx_trylock(&(pmap)->pm_mtx)
#define	PMAP_UNLOCK(pmap)	mtx_unlock(&(pmap)->pm_mtx)
#endif


/*
 * For each vm_page_t, there is a list of all currently valid virtual
 * mappings of that page.  An entry is a pv_entry_t, the list is pv_list.
 */
typedef struct pv_entry {
	vm_offset_t     pv_va;          /* virtual address for mapping */
	TAILQ_ENTRY(pv_entry)   pv_list;
	int		pv_flags;	/* flags (wired, etc...) */
#if (ARM_MMU_V6 + ARM_MMU_V7) == 0
	pmap_t          pv_pmap;        /* pmap where mapping lies */
	TAILQ_ENTRY(pv_entry)	pv_plist;
#endif
} *pv_entry_t;

/*
 * pv_entries are allocated in chunks per-process.  This avoids the
 * need to track per-pmap assignments.
 */
#define	_NPCM	8
#define	_NPCPV	252

struct pv_chunk {
	pmap_t			pc_pmap;
	TAILQ_ENTRY(pv_chunk)	pc_list;
	uint32_t		pc_map[_NPCM];	/* bitmap; 1 = free */
	uint32_t		pc_dummy[3];	/* aligns pv_chunk to 4KB */
	TAILQ_ENTRY(pv_chunk)	pc_lru;
	struct pv_entry		pc_pventry[_NPCPV];
};

#ifdef _KERNEL

boolean_t pmap_get_pde_pte(pmap_t, vm_offset_t, pd_entry_t **, pt_entry_t **);

/*
 * virtual address to page table entry and
 * to physical address. Likewise for alternate address space.
 * Note: these work recursively, thus vtopte of a pte will give
 * the corresponding pde that in turn maps it.
 */

/*
 * The current top of kernel VM.
 */
extern vm_offset_t pmap_curmaxkvaddr;

struct pcb;

void	pmap_set_pcb_pagedir(pmap_t, struct pcb *);
/* Virtual address to page table entry */
static __inline pt_entry_t *
vtopte(vm_offset_t va)
{
	pd_entry_t *pdep;
	pt_entry_t *ptep;

	if (pmap_get_pde_pte(kernel_pmap, va, &pdep, &ptep) == FALSE)
		return (NULL);
	return (ptep);
}

extern vm_paddr_t phys_avail[];
extern vm_offset_t virtual_avail;
extern vm_offset_t virtual_end;

void	pmap_bootstrap(vm_offset_t firstaddr, struct pv_addr *l1pt);
int	pmap_change_attr(vm_offset_t, vm_size_t, int);
void	pmap_kenter(vm_offset_t va, vm_paddr_t pa);
void	pmap_kenter_nocache(vm_offset_t va, vm_paddr_t pa);
void	pmap_kenter_device(vm_offset_t, vm_size_t, vm_paddr_t);
void	pmap_kremove_device(vm_offset_t, vm_size_t);
void	*pmap_kenter_temporary(vm_paddr_t pa, int i);
void 	pmap_kenter_user(vm_offset_t va, vm_paddr_t pa);
vm_paddr_t pmap_kextract(vm_offset_t va);
vm_paddr_t pmap_dump_kextract(vm_offset_t, pt2_entry_t *);
void	pmap_kremove(vm_offset_t);
void	*pmap_mapdev(vm_offset_t, vm_size_t);
void	pmap_unmapdev(vm_offset_t, vm_size_t);
vm_page_t	pmap_use_pt(pmap_t, vm_offset_t);
void	pmap_debug(int);
#if (ARM_MMU_V6 + ARM_MMU_V7) == 0
void	pmap_map_section(vm_offset_t, vm_offset_t, vm_offset_t, int, int);
#endif
void	pmap_link_l2pt(vm_offset_t, vm_offset_t, struct pv_addr *);
vm_size_t	pmap_map_chunk(vm_offset_t, vm_offset_t, vm_offset_t, vm_size_t, int, int);
void
pmap_map_entry(vm_offset_t l1pt, vm_offset_t va, vm_offset_t pa, int prot,
    int cache);
int pmap_fault_fixup(pmap_t, vm_offset_t, vm_prot_t, int);

/*
 * Definitions for MMU domains
 */
#define	PMAP_DOMAINS		15	/* 15 'user' domains (1-15) */
#define	PMAP_DOMAIN_KERNEL	0	/* The kernel uses domain #0 */

/*
 * The new pmap ensures that page-tables are always mapping Write-Thru.
 * Thus, on some platforms we can run fast and loose and avoid syncing PTEs
 * on every change.
 *
 * Unfortunately, not all CPUs have a write-through cache mode.  So we
 * define PMAP_NEEDS_PTE_SYNC for C code to conditionally do PTE syncs,
 * and if there is the chance for PTE syncs to be needed, we define
 * PMAP_INCLUDE_PTE_SYNC so e.g. assembly code can include (and run)
 * the code.
 */
extern int pmap_needs_pte_sync;

/*
 * These macros define the various bit masks in the PTE.
 *
 * We use these macros since we use different bits on different processor
 * models.
 */

#define	L1_S_CACHE_MASK_generic	(L1_S_B|L1_S_C)
#define	L1_S_CACHE_MASK_xscale	(L1_S_B|L1_S_C|L1_S_XSCALE_TEX(TEX_XSCALE_X)|\
    				L1_S_XSCALE_TEX(TEX_XSCALE_T))

#define	L2_L_CACHE_MASK_generic	(L2_B|L2_C)
#define	L2_L_CACHE_MASK_xscale	(L2_B|L2_C|L2_XSCALE_L_TEX(TEX_XSCALE_X) | \
    				L2_XSCALE_L_TEX(TEX_XSCALE_T))

#define	L2_S_PROT_U_generic	(L2_AP(AP_U))
#define	L2_S_PROT_W_generic	(L2_AP(AP_W))
#define	L2_S_PROT_MASK_generic	(L2_S_PROT_U|L2_S_PROT_W)

#define	L2_S_PROT_U_xscale	(L2_AP0(AP_U))
#define	L2_S_PROT_W_xscale	(L2_AP0(AP_W))
#define	L2_S_PROT_MASK_xscale	(L2_S_PROT_U|L2_S_PROT_W)

#define	L2_S_CACHE_MASK_generic	(L2_B|L2_C)
#define	L2_S_CACHE_MASK_xscale	(L2_B|L2_C|L2_XSCALE_T_TEX(TEX_XSCALE_X)| \
    				 L2_XSCALE_T_TEX(TEX_XSCALE_X))

#define	L1_S_PROTO_generic	(L1_TYPE_S | L1_S_IMP)
#define	L1_S_PROTO_xscale	(L1_TYPE_S)

#define	L1_C_PROTO_generic	(L1_TYPE_C | L1_C_IMP2)
#define	L1_C_PROTO_xscale	(L1_TYPE_C)

#define	L2_L_PROTO		(L2_TYPE_L)

#define	L2_S_PROTO_generic	(L2_TYPE_S)
#define	L2_S_PROTO_xscale	(L2_TYPE_XSCALE_XS)

/*
 * User-visible names for the ones that vary with MMU class.
 */
#if (ARM_MMU_V6 + ARM_MMU_V7) != 0
#define	L2_AP(x)	(L2_AP0(x))
#else
#define	L2_AP(x)	(L2_AP0(x) | L2_AP1(x) | L2_AP2(x) | L2_AP3(x))
#endif

#if (ARM_MMU_V6 + ARM_MMU_V7) != 0
/*
 * AP[2:1] access permissions model:
 *
 * AP[2](APX)	- Write Disable
 * AP[1]	- User Enable
 * AP[0]	- Reference Flag
 *
 * AP[2]     AP[1]     Kernel     User
 *  0          0        R/W        N
 *  0          1        R/W       R/W
 *  1          0         R         N
 *  1          1         R         R
 *
 */
#define	L2_S_PROT_R		(0)		/* kernel read */
#define	L2_S_PROT_U		(L2_AP0(2))	/* user read */
#define L2_S_REF		(L2_AP0(1))	/* reference flag */

#define	L2_S_PROT_MASK		(L2_S_PROT_U|L2_S_PROT_R|L2_APX)
#define	L2_S_EXECUTABLE(pte)	(!(pte & L2_XN))
#define	L2_S_WRITABLE(pte)	(!(pte & L2_APX))
#define	L2_S_REFERENCED(pte)	(!!(pte & L2_S_REF))

#ifndef SMP
#define	L1_S_CACHE_MASK		(L1_S_TEX_MASK|L1_S_B|L1_S_C)
#define	L2_L_CACHE_MASK		(L2_L_TEX_MASK|L2_B|L2_C)
#define	L2_S_CACHE_MASK		(L2_S_TEX_MASK|L2_B|L2_C)
#else
#define	L1_S_CACHE_MASK		(L1_S_TEX_MASK|L1_S_B|L1_S_C|L1_SHARED)
#define	L2_L_CACHE_MASK		(L2_L_TEX_MASK|L2_B|L2_C|L2_SHARED)
#define	L2_S_CACHE_MASK		(L2_S_TEX_MASK|L2_B|L2_C|L2_SHARED)
#endif  /* SMP */

#define	L1_S_PROTO		(L1_TYPE_S)
#define	L1_C_PROTO		(L1_TYPE_C)
#define	L2_S_PROTO		(L2_TYPE_S)

/*
 * Promotion to a 1MB (SECTION) mapping requires that the corresponding
 * 4KB (SMALL) page mappings have identical settings for the following fields:
 */
#define	L2_S_PROMOTE		(L2_S_REF | L2_SHARED | L2_S_PROT_MASK | \
				 L2_XN | L2_S_PROTO)

/*
 * In order to compare 1MB (SECTION) entry settings with the 4KB (SMALL)
 * page mapping it is necessary to read and shift appropriate bits from
 * L1 entry to positions of the corresponding bits in the L2 entry.
 */
#define L1_S_DEMOTE(l1pd)	((((l1pd) & L1_S_PROTO) >> 0) | \
				(((l1pd) & L1_SHARED) >> 6) | \
				(((l1pd) & L1_S_REF) >> 6) | \
				(((l1pd) & L1_S_PROT_MASK) >> 6) | \
				(((l1pd) & L1_S_XN) >> 4))

#ifndef SMP
#define ARM_L1S_STRONG_ORD	(0)
#define ARM_L1S_DEVICE_NOSHARE	(L1_S_TEX(2))
#define ARM_L1S_DEVICE_SHARE	(L1_S_B)
#define ARM_L1S_NRML_NOCACHE	(L1_S_TEX(1))
#define ARM_L1S_NRML_IWT_OWT	(L1_S_C)
#define ARM_L1S_NRML_IWB_OWB	(L1_S_C|L1_S_B)
#define ARM_L1S_NRML_IWBA_OWBA	(L1_S_TEX(1)|L1_S_C|L1_S_B)

#define ARM_L2L_STRONG_ORD	(0)
#define ARM_L2L_DEVICE_NOSHARE	(L2_L_TEX(2))
#define ARM_L2L_DEVICE_SHARE	(L2_B)
#define ARM_L2L_NRML_NOCACHE	(L2_L_TEX(1))
#define ARM_L2L_NRML_IWT_OWT	(L2_C)
#define ARM_L2L_NRML_IWB_OWB	(L2_C|L2_B)
#define ARM_L2L_NRML_IWBA_OWBA	(L2_L_TEX(1)|L2_C|L2_B)

#define ARM_L2S_STRONG_ORD	(0)
#define ARM_L2S_DEVICE_NOSHARE	(L2_S_TEX(2))
#define ARM_L2S_DEVICE_SHARE	(L2_B)
#define ARM_L2S_NRML_NOCACHE	(L2_S_TEX(1))
#define ARM_L2S_NRML_IWT_OWT	(L2_C)
#define ARM_L2S_NRML_IWB_OWB	(L2_C|L2_B)
#define ARM_L2S_NRML_IWBA_OWBA	(L2_S_TEX(1)|L2_C|L2_B)
#else
#define ARM_L1S_STRONG_ORD	(0)
#define ARM_L1S_DEVICE_NOSHARE	(L1_S_TEX(2))
#define ARM_L1S_DEVICE_SHARE	(L1_S_B)
#define ARM_L1S_NRML_NOCACHE	(L1_S_TEX(1)|L1_SHARED)
#define ARM_L1S_NRML_IWT_OWT	(L1_S_C|L1_SHARED)
#define ARM_L1S_NRML_IWB_OWB	(L1_S_C|L1_S_B|L1_SHARED)
#define ARM_L1S_NRML_IWBA_OWBA	(L1_S_TEX(1)|L1_S_C|L1_S_B|L1_SHARED)

#define ARM_L2L_STRONG_ORD	(0)
#define ARM_L2L_DEVICE_NOSHARE	(L2_L_TEX(2))
#define ARM_L2L_DEVICE_SHARE	(L2_B)
#define ARM_L2L_NRML_NOCACHE	(L2_L_TEX(1)|L2_SHARED)
#define ARM_L2L_NRML_IWT_OWT	(L2_C|L2_SHARED)
#define ARM_L2L_NRML_IWB_OWB	(L2_C|L2_B|L2_SHARED)
#define ARM_L2L_NRML_IWBA_OWBA	(L2_L_TEX(1)|L2_C|L2_B|L2_SHARED)

#define ARM_L2S_STRONG_ORD	(0)
#define ARM_L2S_DEVICE_NOSHARE	(L2_S_TEX(2))
#define ARM_L2S_DEVICE_SHARE	(L2_B)
#define ARM_L2S_NRML_NOCACHE	(L2_S_TEX(1)|L2_SHARED)
#define ARM_L2S_NRML_IWT_OWT	(L2_C|L2_SHARED)
#define ARM_L2S_NRML_IWB_OWB	(L2_C|L2_B|L2_SHARED)
#define ARM_L2S_NRML_IWBA_OWBA	(L2_S_TEX(1)|L2_C|L2_B|L2_SHARED)
#endif /* SMP */

#elif ARM_NMMUS > 1
/* More than one MMU class configured; use variables. */
#define	L2_S_PROT_U		pte_l2_s_prot_u
#define	L2_S_PROT_W		pte_l2_s_prot_w
#define	L2_S_PROT_MASK		pte_l2_s_prot_mask

#define	L1_S_CACHE_MASK		pte_l1_s_cache_mask
#define	L2_L_CACHE_MASK		pte_l2_l_cache_mask
#define	L2_S_CACHE_MASK		pte_l2_s_cache_mask

#define	L1_S_PROTO		pte_l1_s_proto
#define	L1_C_PROTO		pte_l1_c_proto
#define	L2_S_PROTO		pte_l2_s_proto

#elif ARM_MMU_GENERIC != 0
#define	L2_S_PROT_U		L2_S_PROT_U_generic
#define	L2_S_PROT_W		L2_S_PROT_W_generic
#define	L2_S_PROT_MASK		L2_S_PROT_MASK_generic

#define	L1_S_CACHE_MASK		L1_S_CACHE_MASK_generic
#define	L2_L_CACHE_MASK		L2_L_CACHE_MASK_generic
#define	L2_S_CACHE_MASK		L2_S_CACHE_MASK_generic

#define	L1_S_PROTO		L1_S_PROTO_generic
#define	L1_C_PROTO		L1_C_PROTO_generic
#define	L2_S_PROTO		L2_S_PROTO_generic

#elif ARM_MMU_XSCALE == 1
#define	L2_S_PROT_U		L2_S_PROT_U_xscale
#define	L2_S_PROT_W		L2_S_PROT_W_xscale
#define	L2_S_PROT_MASK		L2_S_PROT_MASK_xscale

#define	L1_S_CACHE_MASK		L1_S_CACHE_MASK_xscale
#define	L2_L_CACHE_MASK		L2_L_CACHE_MASK_xscale
#define	L2_S_CACHE_MASK		L2_S_CACHE_MASK_xscale

#define	L1_S_PROTO		L1_S_PROTO_xscale
#define	L1_C_PROTO		L1_C_PROTO_xscale
#define	L2_S_PROTO		L2_S_PROTO_xscale

#endif /* ARM_NMMUS > 1 */

#if defined(CPU_XSCALE_81342) || ARM_ARCH_6 || ARM_ARCH_7A
#define PMAP_NEEDS_PTE_SYNC	1
#define PMAP_INCLUDE_PTE_SYNC
#else
#define	PMAP_NEEDS_PTE_SYNC	0
#endif

/*
 * These macros return various bits based on kernel/user and protection.
 * Note that the compiler will usually fold these at compile time.
 */
#if (ARM_MMU_V6 + ARM_MMU_V7) == 0

#define	L1_S_PROT_U		(L1_S_AP(AP_U))
#define	L1_S_PROT_W		(L1_S_AP(AP_W))
#define	L1_S_PROT_MASK		(L1_S_PROT_U|L1_S_PROT_W)
#define	L1_S_WRITABLE(pd)	((pd) & L1_S_PROT_W)

#define	L1_S_PROT(ku, pr)	((((ku) == PTE_USER) ? L1_S_PROT_U : 0) | \
				 (((pr) & VM_PROT_WRITE) ? L1_S_PROT_W : 0))

#define	L2_L_PROT_U		(L2_AP(AP_U))
#define	L2_L_PROT_W		(L2_AP(AP_W))
#define	L2_L_PROT_MASK		(L2_L_PROT_U|L2_L_PROT_W)

#define	L2_L_PROT(ku, pr)	((((ku) == PTE_USER) ? L2_L_PROT_U : 0) | \
				 (((pr) & VM_PROT_WRITE) ? L2_L_PROT_W : 0))

#define	L2_S_PROT(ku, pr)	((((ku) == PTE_USER) ? L2_S_PROT_U : 0) | \
				 (((pr) & VM_PROT_WRITE) ? L2_S_PROT_W : 0))
#else
#define	L1_S_PROT_U		(L1_S_AP(AP_U))
#define	L1_S_PROT_W		(L1_S_APX)		/* Write disable */
#define	L1_S_PROT_MASK		(L1_S_PROT_W|L1_S_PROT_U)
#define	L1_S_REF		(L1_S_AP(AP_REF))	/* Reference flag */
#define	L1_S_WRITABLE(pd)	(!((pd) & L1_S_PROT_W))
#define	L1_S_EXECUTABLE(pd)	(!((pd) & L1_S_XN))
#define	L1_S_REFERENCED(pd)	((pd) & L1_S_REF)

#define	L1_S_PROT(ku, pr)	(((((ku) == PTE_KERNEL) ? 0 : L1_S_PROT_U) | \
				 (((pr) & VM_PROT_WRITE) ? 0 : L1_S_PROT_W) | \
				 (((pr) & VM_PROT_EXECUTE) ? 0 : L1_S_XN)))

#define	L2_L_PROT_MASK		(L2_APX|L2_AP0(0x3))
#define	L2_L_PROT(ku, pr)	(L2_L_PROT_MASK & ~((((ku) == PTE_KERNEL) ? L2_S_PROT_U : 0) | \
				 (((pr) & VM_PROT_WRITE) ? L2_APX : 0)))

#define	L2_S_PROT(ku, pr)	(L2_S_PROT_MASK & ~((((ku) == PTE_KERNEL) ? L2_S_PROT_U : 0) | \
				 (((pr) & VM_PROT_WRITE) ? L2_APX : 0)))

#endif

/*
 * Macros to test if a mapping is mappable with an L1 Section mapping
 * or an L2 Large Page mapping.
 */
#define	L1_S_MAPPABLE_P(va, pa, size)					\
	((((va) | (pa)) & L1_S_OFFSET) == 0 && (size) >= L1_S_SIZE)

#define	L2_L_MAPPABLE_P(va, pa, size)					\
	((((va) | (pa)) & L2_L_OFFSET) == 0 && (size) >= L2_L_SIZE)

/*
 * Provide a fallback in case we were not able to determine it at
 * compile-time.
 */
#ifndef PMAP_NEEDS_PTE_SYNC
#define	PMAP_NEEDS_PTE_SYNC	pmap_needs_pte_sync
#define	PMAP_INCLUDE_PTE_SYNC
#endif

#ifdef ARM_L2_PIPT
#define _sync_l2(pte, size) 	cpu_l2cache_wb_range(vtophys(pte), size)
#else
#define _sync_l2(pte, size) 	cpu_l2cache_wb_range(pte, size)
#endif

#define	PTE_SYNC(pte)							\
do {									\
	if (PMAP_NEEDS_PTE_SYNC) {					\
		cpu_dcache_wb_range((vm_offset_t)(pte), sizeof(pt_entry_t));\
		cpu_drain_writebuf();					\
		_sync_l2((vm_offset_t)(pte), sizeof(pt_entry_t));\
	} else								\
		cpu_drain_writebuf();					\
} while (/*CONSTCOND*/0)

#define	PTE_SYNC_RANGE(pte, cnt)					\
do {									\
	if (PMAP_NEEDS_PTE_SYNC) {					\
		cpu_dcache_wb_range((vm_offset_t)(pte),			\
		    (cnt) << 2); /* * sizeof(pt_entry_t) */		\
		cpu_drain_writebuf();					\
		_sync_l2((vm_offset_t)(pte),		 		\
		    (cnt) << 2); /* * sizeof(pt_entry_t) */		\
	} else								\
		cpu_drain_writebuf();					\
} while (/*CONSTCOND*/0)

extern pt_entry_t		pte_l1_s_cache_mode;
extern pt_entry_t		pte_l1_s_cache_mask;

extern pt_entry_t		pte_l2_l_cache_mode;
extern pt_entry_t		pte_l2_l_cache_mask;

extern pt_entry_t		pte_l2_s_cache_mode;
extern pt_entry_t		pte_l2_s_cache_mask;

extern pt_entry_t		pte_l1_s_cache_mode_pt;
extern pt_entry_t		pte_l2_l_cache_mode_pt;
extern pt_entry_t		pte_l2_s_cache_mode_pt;

extern pt_entry_t		pte_l2_s_prot_u;
extern pt_entry_t		pte_l2_s_prot_w;
extern pt_entry_t		pte_l2_s_prot_mask;

extern pt_entry_t		pte_l1_s_proto;
extern pt_entry_t		pte_l1_c_proto;
extern pt_entry_t		pte_l2_s_proto;

extern void (*pmap_copy_page_func)(vm_paddr_t, vm_paddr_t);
extern void (*pmap_copy_page_offs_func)(vm_paddr_t a_phys,
    vm_offset_t a_offs, vm_paddr_t b_phys, vm_offset_t b_offs, int cnt);
extern void (*pmap_zero_page_func)(vm_paddr_t, int, int);

#if (ARM_MMU_GENERIC + ARM_MMU_V6 + ARM_MMU_V7) != 0 || defined(CPU_XSCALE_81342)
void	pmap_copy_page_generic(vm_paddr_t, vm_paddr_t);
void	pmap_zero_page_generic(vm_paddr_t, int, int);

void	pmap_pte_init_generic(void);
#if (ARM_MMU_V6 + ARM_MMU_V7) != 0
void	pmap_pte_init_mmu_v6(void);
#endif /* (ARM_MMU_V6 + ARM_MMU_V7) != 0 */
#endif /* (ARM_MMU_GENERIC + ARM_MMU_V6 + ARM_MMU_V7) != 0 */

#if ARM_MMU_XSCALE == 1
void	pmap_copy_page_xscale(vm_paddr_t, vm_paddr_t);
void	pmap_zero_page_xscale(vm_paddr_t, int, int);

void	pmap_pte_init_xscale(void);

void	xscale_setup_minidata(vm_offset_t, vm_offset_t, vm_offset_t);

void	pmap_use_minicache(vm_offset_t, vm_size_t);
#endif /* ARM_MMU_XSCALE == 1 */
#if defined(CPU_XSCALE_81342)
#define ARM_HAVE_SUPERSECTIONS
#endif

#define PTE_KERNEL	0
#define PTE_USER	1
#define	l1pte_valid(pde)	((pde) != 0)
#define	l1pte_section_p(pde)	(((pde) & L1_TYPE_MASK) == L1_TYPE_S)
#define	l1pte_page_p(pde)	(((pde) & L1_TYPE_MASK) == L1_TYPE_C)
#define	l1pte_fpage_p(pde)	(((pde) & L1_TYPE_MASK) == L1_TYPE_F)

#define l2pte_index(v)		(((v) & L2_ADDR_BITS) >> L2_S_SHIFT)
#define	l2pte_valid(pte)	((pte) != 0)
#define	l2pte_pa(pte)		((pte) & L2_S_FRAME)
#define l2pte_minidata(pte)	(((pte) & \
				 (L2_B | L2_C | L2_XSCALE_T_TEX(TEX_XSCALE_X)))\
				 == (L2_C | L2_XSCALE_T_TEX(TEX_XSCALE_X)))

/* L1 and L2 page table macros */
#define pmap_pde_v(pde)		l1pte_valid(*(pde))
#define pmap_pde_section(pde)	l1pte_section_p(*(pde))
#define pmap_pde_page(pde)	l1pte_page_p(*(pde))
#define pmap_pde_fpage(pde)	l1pte_fpage_p(*(pde))

#define	pmap_pte_v(pte)		l2pte_valid(*(pte))
#define	pmap_pte_pa(pte)	l2pte_pa(*(pte))

/*
 * Flags that indicate attributes of pages or mappings of pages.
 *
 * The PVF_MOD and PVF_REF flags are stored in the mdpage for each
 * page.  PVF_WIRED, PVF_WRITE, and PVF_NC are kept in individual
 * pv_entry's for each page.  They live in the same "namespace" so
 * that we can clear multiple attributes at a time.
 *
 * Note the "non-cacheable" flag generally means the page has
 * multiple mappings in a given address space.
 */
#define	PVF_MOD		0x01		/* page is modified */
#define	PVF_REF		0x02		/* page is referenced */
#define	PVF_WIRED	0x04		/* mapping is wired */
#define	PVF_WRITE	0x08		/* mapping is writable */
#define	PVF_EXEC	0x10		/* mapping is executable */
#define	PVF_NC		0x20		/* mapping is non-cacheable */
#define	PVF_MWC		0x40		/* mapping is used multiple times in userland */
#define	PVF_UNMAN	0x80		/* mapping is unmanaged */

void vector_page_setprot(int);

#define SECTION_CACHE	0x1
#define SECTION_PT	0x2
void	pmap_kenter_section(vm_offset_t, vm_paddr_t, int flags);
#ifdef ARM_HAVE_SUPERSECTIONS
void	pmap_kenter_supersection(vm_offset_t, uint64_t, int flags);
#endif

extern char *_tmppt;

void	pmap_postinit(void);

extern vm_paddr_t dump_avail[];
#endif	/* _KERNEL */

#endif	/* !LOCORE */

#endif	/* !_MACHINE_PMAP_H_ */
#endif	/* __ARM_ARCH >= 6 */
