/*
 * Link-time shims (build.sh passes -Wl,--wrap=swapcontext -Wl,--wrap=__asan_handle_no_return) that keep ASan's
 * stderr warnings about RIOT's ucontext threads out of every execution. Without them each run prints
 *   "ASan doesn't fully support makecontext/swapcontext ..."   (ASan's swapcontext interceptor, first call)
 *   "ASan is ignoring requested __asan_handle_no_return ..."   (noreturn call made on a makecontext() stack)
 * and Mayhem files every input as a defect with no app frame. Neither shim touches RIOT code: the first calls
 * libc's swapcontext directly, the second skips an ASan stack-unpoisoning hook that is meaningless off the
 * main thread stack (use-after-return fake stacks are disabled, see build.sh).
 */
#define _GNU_SOURCE
#include <dlfcn.h>
#include <ucontext.h>

int __wrap_swapcontext(ucontext_t *oucp, const ucontext_t *ucp)
{
    static int (*libc_swapcontext)(ucontext_t *, const ucontext_t *);
    if (!libc_swapcontext) {
        libc_swapcontext = (int (*)(ucontext_t *, const ucontext_t *))dlsym(RTLD_NEXT, "swapcontext");
    }
    return libc_swapcontext(oucp, ucp);
}

void __wrap___asan_handle_no_return(void)
{
}
