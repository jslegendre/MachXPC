//
//  SymRez.c
//  SymRez
//
//  Created by Jeremy Legendre on 4/14/20.
//  Copyright © 2020 Jeremy Legendre. All rights reserved.
//

#include "SymRez.h"
#include <stdlib.h>
#include <dlfcn.h>
#include <mach-o/dyld.h>
#include <mach-o/dyld_images.h>
#include <mach-o/getsect.h>
#include <mach-o/nlist.h>
#include <mach-o/getsect.h>
#include <mach/mach_vm.h>

#if __has_feature(ptrauth_calls)
#include <ptrauth.h>
#endif

extern const struct mach_header_64 _mh_execute_header;
typedef struct load_command* load_command_t;
typedef struct segment_command_64* segment_command_t;
typedef struct dyld_all_image_infos* dyld_all_image_infos_t;
typedef struct nlist_64 nlist_64;
typedef void* symtab_t;
typedef void* strtab_t;

static dyld_all_image_infos_t _g_all_image_infos = NULL;

struct symrez {
    mach_header_t header;
    intptr_t slide;
    symtab_t symtab;
    strtab_t strtab;
    uint32_t nsyms;
};

static int _strncmp_fast(const char *ptr0, const char *ptr1, size_t len) {
    size_t fast = len/sizeof(size_t) + 1;
    size_t offset = (fast-1)*sizeof(size_t);
    int current_block = 0;
    
    if( len <= sizeof(size_t)){ fast = 0; }
    
    
    size_t *lptr0 = (size_t*)ptr0;
    size_t *lptr1 = (size_t*)ptr1;
    
    while( current_block < fast ){
        if( (lptr0[current_block] ^ lptr1[current_block] )){
            int pos;
            for(pos = current_block*sizeof(size_t); pos < len ; ++pos ){
                if( (ptr0[pos] ^ ptr1[pos]) || (ptr0[pos] == 0) || (ptr1[pos] == 0) ){
                    return  (int)((unsigned char)ptr0[pos] - (unsigned char)ptr1[pos]);
                }
            }
        }
        
        ++current_block;
    }
    
    while( len > offset ){
        if( (ptr0[offset] ^ ptr1[offset] )){
            return (int)((unsigned char)ptr0[offset] - (unsigned char)ptr1[offset]);
        }
        ++offset;
    }
    
    
    return 0;
}

static dyld_all_image_infos_t _get_all_image_infos(void) {
    if (!_g_all_image_infos) {
        task_dyld_info_data_t dyld_info;
        mach_msg_type_number_t count = TASK_DYLD_INFO_COUNT;
        kern_return_t kr = task_info(mach_task_self(), TASK_DYLD_INFO, (task_info_t)&dyld_info, &count);
        if (kr != KERN_SUCCESS) {
            return NULL;
        }
        
        _g_all_image_infos = (void*)(dyld_info.all_image_info_addr);
    }
    
    return _g_all_image_infos;
}

static segment_command_t _find_segment_64(mach_header_t mh, const char *segname) {
    load_command_t lc;
    segment_command_t seg, foundseg = NULL;
    
    lc = (load_command_t)((uint64_t)mh + sizeof(struct mach_header_64));
    while ((uint64_t)lc < (uint64_t)mh + (uint64_t)mh->sizeofcmds) {
        if (lc->cmd == LC_SEGMENT_64) {
            seg = (segment_command_t)lc;
            if (strcmp(seg->segname, segname) == 0) {
                foundseg = seg;
                break;
            }
        }
        
        lc = (load_command_t)((uint64_t)lc + (uint64_t)lc->cmdsize);
    }
    
    return foundseg;
}

static load_command_t _find_load_command(mach_header_t mh, uint32_t cmd) {
    load_command_t lc, foundlc = NULL;
    
    lc = (load_command_t)((uint64_t)mh + sizeof(struct mach_header_64));
    while ((uint64_t)lc < (uint64_t)mh + (uint64_t)mh->sizeofcmds) {
        if (lc->cmd == cmd) {
            foundlc = (load_command_t)lc;
            break;
        }
        
        lc = (load_command_t)((uint64_t)lc + (uint64_t)lc->cmdsize);
    }
    
    return foundlc;
}

static intptr_t _compute_image_slide(mach_header_t mh) {
    intptr_t res = 0;
    uint64_t mh_addr = (uint64_t)(void*)mh;
    segment_command_t seg = _find_segment_64(mh, SEG_TEXT);
    res = mh_addr - (seg->vmaddr);
    return res;
}

static int _find_linkedit_commands(symrez_t symrez) {
    mach_header_t mh = symrez->header;
    intptr_t slide = symrez->slide;
    
    struct symtab_command *symtab = NULL;
    segment_command_t linkedit = NULL;
    
    linkedit = _find_segment_64(mh, SEG_LINKEDIT);
    if (!linkedit) {
        return 0;
    }
    
    symtab = (symtab_t)_find_load_command(mh, LC_SYMTAB);
    if (!symtab) {
        return 0;
    }
    
    symrez->nsyms = symtab->nsyms;
    symrez->strtab = (strtab_t)(linkedit->vmaddr - linkedit->fileoff) + symtab->stroff + slide;
    symrez->symtab = (symtab_t)(linkedit->vmaddr - linkedit->fileoff) + symtab->symoff + slide;
    
    return 1;
}

int _find_image(const char *image_name, mach_header_t *hdr) {
    int found = -1;
    *hdr = NULL;
    int i = 0;
    
    dyld_all_image_infos_t dyld_all_image_infos = _get_all_image_infos();
    const struct dyld_image_info *info_array = dyld_all_image_infos->infoArray;
    for(; i < dyld_all_image_infos->infoArrayCount; i++) {
        const char *p = info_array[i].imageFilePath;
        if (_strncmp_fast(p, image_name, strlen(p)) == 0) {
            found = i;
            break;
        }
        
        char *img = strrchr(p, '/');
        img = (char *)&img[1];
        if(_strncmp_fast(img, image_name, strlen(image_name)) == 0) {
            found = i;
            break;
        }
    }

    if (found >= 0) {
        *hdr = (mach_header_t)(info_array[i].imageLoadAddress);
        return 1;
    }
    
//    uint32_t imagecount = _dyld_image_count();
//    for(int i = 0; i < imagecount; i++) {
//        const char *p = _dyld_get_image_name(i);
//        if (_strncmp_fast(p, image_name, strlen(p)) == 0) {
//            found = i;
//            break;
//        }
//
//        char *img = strrchr(p, '/');
//        img = (char *)&img[1];
//        if(strcmp(img, image_name) == 0) {
//            *hdr = (const struct mach_header_64 *)_dyld_get_image_header(i);
//            return 1;
//        }
//    }
//
//    if (found >= 0) {
//        *hdr = (mach_header_t)_dyld_get_image_header(found);
//        return 1;
//    }
    
    return 0;
}

mach_header_t _get_base_addr(void) {
    dyld_all_image_infos_t dyld_all_image_infos = _get_all_image_infos();
    if (dyld_all_image_infos) {
        return (mach_header_t)(dyld_all_image_infos->infoArray[0].imageLoadAddress);
    }
    
    // Fallback
    kern_return_t kr = KERN_FAILURE;
    vm_region_basic_info_data_t info = { 0 };
    mach_vm_size_t size = 0;
    mach_port_t object_name = MACH_PORT_NULL;
    mach_msg_type_number_t count = VM_REGION_BASIC_INFO_COUNT_64;
    mach_vm_address_t address = 0x100000000;

    while (kr != KERN_SUCCESS) {
        address += size;
        kr = mach_vm_region(current_task(), &address, &size, VM_REGION_BASIC_INFO, (vm_region_info_t) &info, &count, &object_name);
    }

    return (mach_header_t)address;
}

void sr_for_each(symrez_t symrez, symrez_function_t work) {
    
    strtab_t strtab = symrez->strtab;
    symtab_t symtab = symrez->symtab;
    intptr_t slide = symrez->slide;
    uintptr_t nl_addr = (uintptr_t)symtab;
    uint64_t i = 0;
    void *addr = NULL;
    
    for (i = 0; i < symrez->nsyms; i++, nl_addr += sizeof(struct nlist_64)) {
        struct nlist_64 *nl = (struct nlist_64 *)nl_addr;
        if (nl->n_sect == 0) continue; // External symbol
        const char *str = (const char *)strtab + nl->n_un.n_strx;
        addr = (void *)(nl->n_value + slide);
        if (work(str, addr)) {
            break;
        }
    }
}

void * sr_resolve_symbol(symrez_t symrez, const char *symbol) {
    strtab_t strtab = symrez->strtab;
    symtab_t symtab = symrez->symtab;
    intptr_t slide = symrez->slide;
    uintptr_t nl_addr = (uintptr_t)symtab;
    uint64_t i = 0;
    void *addr = NULL;
    size_t sym_len = strlen(symbol);
    
    for (i = 0; i < symrez->nsyms; i++, nl_addr += sizeof(struct nlist_64)) {
        struct nlist_64 *nl = (struct nlist_64 *)nl_addr;
        const char *str = (const char *)strtab + nl->n_un.n_strx;
        if (strlen(str) != sym_len) {
            continue;
        }
        
        if (_strncmp_fast(str, symbol, strlen(symbol)) == 0) {
            addr = (void *)(nl->n_value + slide);
            break;
        }
    }
    
#if __has_feature(ptrauth_calls)
    addr = ptrauth_sign_unauthenticated(addr, ptrauth_key_function_pointer, 0);
#endif
    
    return addr;
}

void sr_free(symrez_t symrez) {
    free(symrez);
}

void * symrez_resolve_once_mh(mach_header_t header, const char *symbol) {
    mach_header_t hdr = header;
    if (!hdr) {
        hdr = _get_base_addr();
    }
    
    if (header == SR_DYLD_HDR) {
        dyld_all_image_infos_t aii = _get_all_image_infos();
        hdr = (mach_header_t)(aii->dyldImageLoadAddress);
    }
    
    intptr_t slide = _compute_image_slide(hdr);
    
    struct symrez sr = { 0 };
    sr.header = hdr;
    sr.slide = slide;
    
    if (!_find_linkedit_commands(&sr)) {
        return NULL;
    }
    
    return sr_resolve_symbol(&sr, symbol);
}

void * symrez_resolve_once(const char *image_name, const char *symbol) {
    mach_header_t hdr = NULL;
    
    if(image_name != NULL && !_find_image(image_name, &hdr)) {
        return NULL;
    }
    
    return symrez_resolve_once_mh(hdr, symbol);
}

int symrez_init_mh(symrez_t symrez, mach_header_t mach_header) {
    symrez->header = NULL;
    symrez->slide = 0;
    symrez->nsyms = 0;
    symrez->symtab = NULL;
    symrez->strtab = NULL;
    
    mach_header_t hdr = mach_header;
    if (hdr == NULL) {
        hdr = _get_base_addr();
    }
    
    intptr_t slide = _compute_image_slide(hdr);
    
    symrez->header = hdr;
    symrez->slide = slide;
    
    if (!_find_linkedit_commands(symrez)) {
        return 0;
    }
    
    return 1;
}

symrez_t symrez_new_mh(mach_header_t mach_header) {
    symrez_t symrez = NULL;
    if ((symrez = malloc(sizeof(*symrez))) == NULL) {
        return NULL;
    }
    
    if (!symrez_init_mh(symrez, mach_header)) {
        free(symrez);
        symrez = NULL;
        return NULL;
    }
    
    return symrez;
}

symrez_t symrez_new(const char *image_name) {
    
    mach_header_t hdr = NULL;
    if(image_name != NULL && !_find_image(image_name, &hdr)) {
        return NULL;
    }
    
    return symrez_new_mh(hdr);
}
