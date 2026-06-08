/*
 * hid-stub.c — LD_PRELOAD shim for Omnissa Horizon Client Next
 *
 * libclientSdkCPrimitive.so crashes in CdkClientInfo_GetHIDInfo with a
 * null-deref when iterating HID devices for the broker `addClientInfo`
 * payload. The call chain (confirmed via gdb on PID 238218):
 *
 *   CdkClientInfo_AddHidInfo
 *   -> CdkClientInfo_GetHIDInfo
 *   -> udev_enumerate (subsystem varies by SDK build)
 *   -> udev_device_get_parent_with_subsystem_devtype  (returns NULL)
 *   -> caller doesn't NULL-check, derefs => SIGSEGV
 *
 * The 2512.0-era SDK enumerated subsystem "input" or "hid"; the 2603
 * SDK enumerates "usb_device" and "video" instead (verified via
 * `strings libclientSdkCPrimitive.so`). Either way the crash is the
 * same: the SDK walks devices looking for an `input` devtype parent
 * and doesn't handle the NULL case.
 *
 * Mitigation: intercept udev_enumerate_scan_devices and return an
 * empty list whenever the enumeration was filtered to a subsystem the
 * SDK uses for HID enrichment. AddHidInfo then sends an empty HID
 * descriptor to the broker, which is harmless - the broker's
 * <add-client-info><client-info-usb>...</client-info-usb> payload is
 * advisory and the session does not depend on it.
 *
 * USB redirection during an actual session is unaffected: that runs in
 * a separate process (horizon-UsbRedirectionClient) and goes through
 * libusb / the USB arbitrator socket, not through the client's
 * pre-launch addClientInfo udev enumeration.
 *
 * On load the shim writes a one-line breadcrumb to $HORIZON_HID_STUB_LOG
 * (if set) so we can verify from outside that LD_PRELOAD reached the
 * bundled .NET binary.
 */
#define _GNU_SOURCE
#include <dlfcn.h>
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>
#include <libudev.h>

/* Subsystems the SDK has been observed to enumerate from within the
 * HID-info call path. Anything listed here gets its scan_devices()
 * result replaced with an empty list. The 2603 SDK uses usb_device
 * and video; earlier SDK builds used input/hid; keep all of them so
 * the shim survives upstream SDK code-path changes. */
static const char *const HID_PATH_SUBSYSTEMS[] = {
    "input",
    "hid",
    "usb_device",
    "video",
    NULL,
};

static int is_hid_path_subsystem(const char *subsystem)
{
    if (!subsystem) return 0;
    for (const char *const *p = HID_PATH_SUBSYSTEMS; *p; ++p) {
        if (strcmp(subsystem, *p) == 0) return 1;
    }
    return 0;
}

/* We track up to 16 concurrent enumerates tagged as HID-path. */
#define MAX_TAGGED 16
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
    if (is_hid_path_subsystem(subsystem))
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

/* Load breadcrumb. If $HORIZON_HID_STUB_LOG points to a writable path,
 * append one line per process so we can verify LD_PRELOAD actually
 * reached the bundled .NET binary. */
__attribute__((constructor))
static void horizon_hid_stub_init(void)
{
    const char *path = getenv("HORIZON_HID_STUB_LOG");
    if (!path || !*path) return;
    FILE *f = fopen(path, "a");
    if (!f) return;
    fprintf(f, "%ld hid-stub loaded pid=%d argv0=%s\n",
            (long)time(NULL), getpid(),
            program_invocation_short_name ? program_invocation_short_name : "?");
    fclose(f);
}
