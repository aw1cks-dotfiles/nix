/*
 * hid-stub.c — LD_PRELOAD shim for Omnissa Horizon Client Next 2512.0
 *
 * libclientSdkCPrimitive.so 2512.0 crashes in CdkClientInfo_GetHIDInfo with a
 * general protection fault / null-deref.  The call chain is:
 *
 *   CdkClientInfo_GetHIDInfo
 *   -> udev_enumerate (subsystem "input" or "hid")
 *   -> udev_device_get_parent_with_subsystem_devtype
 *   -> null-deref (device has no parent of that type)
 *
 * We intercept at two levels:
 *
 * 1. udev_enumerate_scan_devices: return empty list when the enumerate was
 *    filtered to "input" or "hid", so there are no devices to walk.
 *
 * 2. udev_device_get_parent_with_subsystem_devtype: already safe (returns
 *    NULL), but the caller doesn't check.  We can't fix the caller, so we
 *    focus on approach 1.
 *
 * This is a workaround for the 2512.0 release bug; the fix is to upgrade to
 * 2512.1+ when the tarball becomes publicly available.
 */
#define _GNU_SOURCE
#include <dlfcn.h>
#include <string.h>
#include <libudev.h>

/* We track up to 8 concurrent enumerates tagged as input/hid. */
#define MAX_TAGGED 8
static struct udev_enumerate *tagged[MAX_TAGGED];
static int tagged_count = 0;

static void tag_enum(struct udev_enumerate *e)
{
    for (int i = 0; i < tagged_count; i++)
        if (tagged[i] == e) return;
    if (tagged_count < MAX_TAGGED)
        tagged[tagged_count++] = e;
}

static int is_tagged(struct udev_enumerate *e)
{
    for (int i = 0; i < tagged_count; i++)
        if (tagged[i] == e) return 1;
    return 0;
}

static void untag_enum(struct udev_enumerate *e)
{
    for (int i = 0; i < tagged_count; i++) {
        if (tagged[i] == e) {
            tagged[i] = tagged[--tagged_count];
            return;
        }
    }
}

int udev_enumerate_add_match_subsystem(struct udev_enumerate *e,
                                       const char *subsystem)
{
    static int (*real)(struct udev_enumerate *, const char *) = NULL;
    if (!real)
        real = dlsym(RTLD_NEXT, "udev_enumerate_add_match_subsystem");
    if (subsystem &&
        (strcmp(subsystem, "input") == 0 || strcmp(subsystem, "hid") == 0))
        tag_enum(e);
    return real(e, subsystem);
}

int udev_enumerate_scan_devices(struct udev_enumerate *e)
{
    static int (*real)(struct udev_enumerate *) = NULL;
    if (!real)
        real = dlsym(RTLD_NEXT, "udev_enumerate_scan_devices");
    if (e != NULL && is_tagged(e)) {
        untag_enum(e);
        return 0; /* success, empty list */
    }
    return real(e);
}

/* Also intercept unref to clean up our tag table. */
struct udev_enumerate *udev_enumerate_unref(struct udev_enumerate *e)
{
    static struct udev_enumerate *(*real)(struct udev_enumerate *) = NULL;
    if (!real)
        real = dlsym(RTLD_NEXT, "udev_enumerate_unref");
    if (e != NULL)
        untag_enum(e);
    return real ? real(e) : NULL;
}
