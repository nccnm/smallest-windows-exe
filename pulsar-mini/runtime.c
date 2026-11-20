#include <stddef.h>
/* Compiler-generated structure copies/zeroing still need these without the CRT. */
void *__cdecl memcpy(void *dst, const void *src, size_t n) {
    volatile unsigned char *d = dst;
    const volatile unsigned char *s = src;
    while (n--) *d++ = *s++;
    return dst;
}
void *__cdecl memset(void *dst, int value, size_t n) {
    volatile unsigned char *d = dst;
    while (n--) *d++ = (unsigned char)value;
    return dst;
}
