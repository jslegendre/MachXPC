//
//  SymRez.h
//  SymRez
//
//  Created by Jeremy Legendre on 4/14/20.
//  Copyright © 2020 Jeremy Legendre. All rights reserved.
//

#ifndef SymRez_h
#define SymRez_h

#ifdef __cplusplus
extern "C" {
#endif


#include <stdio.h>
#include <stdbool.h>

#define SR_DYLD_HDR ((void *) -1)

typedef const struct mach_header_64 mach_header;
typedef const struct mach_header_64* mach_header_t;

// return true to stop loop
typedef bool (*symrez_function_t)(const char *symbol, void *ptr);

typedef struct symrez* symrez_t;

/*! @function symrez_new
    @abstract Create new symrez object. Caller must free.
    @param image_name Name or full path of the library to symbolicate. Pass NULL for current executable  */
symrez_t symrez_new(const char *image_name);

/*! @function symrez_new
    @abstract Create new symrez object. Caller must free.
    @param header  Pointer to the mach_header_64 to symbolicate. Pass NULL for current executable */
symrez_t symrez_new_mh(mach_header_t header);

/*! @function sr_resolve_symbol
    @abstract Find symbol address
    @param symrez symrez object created by symrez_new
    @param symbol Mangled symbol name
    @return Pointer to symbol location or NULL if not found */
void * sr_resolve_symbol(symrez_t symrez, const char *symbol);

/*! @function sr_for_each
    @abstract Loop through all symbols with a callback
    @param symrez symrez object created by symrez_new
    @param callback callback for processing each iteration. Return true to stop loop. */
void sr_for_each(symrez_t symrez, symrez_function_t callback);

/*! @function sr_free
    @abstract Release all resources allocated for this symrez object */
void sr_free(symrez_t);

/*! @function symrez_resolve_once
    @abstract Lookup a single symbol. Does not allocate memory but not recommended for multiple lookups
    @param image_name Name or full path of the library to symbolicate. Pass NULL for current executable
    @return Pointer to symbol location or NULL if not found */
void * symrez_resolve_once(const char *image_name, const char *symbol);

/*! @function symrez_resolve_once_mh
    @abstract Lookup a single symbol. Does not allocate memory but not recommended for multiple lookups
    @param header  Pointer to the mach_header_64 to symbolicate. Pass NULL for current executable
    @return Pointer to symbol location or NULL if not found */
void * symrez_resolve_once_mh(mach_header_t header, const char *symbol);

#ifdef __cplusplus
}
#endif
#endif /* SymRez_h */
