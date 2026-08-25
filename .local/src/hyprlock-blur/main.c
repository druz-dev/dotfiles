// hyprlock-blur: a fullscreen, input-transparent layer surface whose only job is
// to give Hyprland something to hang `layerrule { blur = true }` on, so the live
// desktop below a session lock gets blurred every frame.
//
// Pair it with misc:session_lock_xray = true and a transparent hyprlock
// background; the lock surface renders on top of us, so its widgets stay sharp.

#define _GNU_SOURCE
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <unistd.h>
#include <wayland-client.h>

#include "wlr-layer-shell-unstable-v1-client-protocol.h"

// The layer-shell protocol references xdg_popup in get_popup, which we never
// call. Stub the interface symbol so we don't have to link all of xdg-shell.
const struct wl_interface xdg_popup_interface = {"xdg_popup", 6, 0, NULL, 0, NULL};

#define MAX_OUTPUTS 16

struct pane {
    struct wl_output             *output;
    struct wl_surface            *surface;
    struct zwlr_layer_surface_v1 *layer;
    struct wl_buffer             *buffer;
    void                         *data;
    size_t                        size;
    int32_t                       w, h;
};

static struct wl_compositor        *compositor;
static struct wl_shm               *shm;
static struct zwlr_layer_shell_v1  *layer_shell;
static struct wl_output            *pending_outputs[MAX_OUTPUTS];
static int                          npending;
static struct pane                  panes[MAX_OUTPUTS];
static int                          npanes;
static const char                  *ns = "lockblur";
static uint32_t                     pixel;  // premultiplied ARGB, black + dim alpha
static bool                         ready;
static bool                         running = true;

static struct wl_buffer *make_buffer(int32_t w, int32_t h, void **out_data, size_t *out_size) {
    const size_t stride = (size_t)w * 4;
    const size_t size   = stride * (size_t)h;

    int fd = memfd_create("hyprlock-blur", MFD_CLOEXEC);
    if (fd < 0 || ftruncate(fd, (off_t)size) < 0) {
        if (fd >= 0)
            close(fd);
        return NULL;
    }

    uint32_t *data = mmap(NULL, size, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);
    if (data == MAP_FAILED) {
        close(fd);
        return NULL;
    }
    for (size_t i = 0; i < size / 4; i++)
        data[i] = pixel;

    struct wl_shm_pool *pool = wl_shm_create_pool(shm, fd, (int32_t)size);
    struct wl_buffer   *buf  = wl_shm_pool_create_buffer(pool, 0, w, h, (int32_t)stride, WL_SHM_FORMAT_ARGB8888);
    wl_shm_pool_destroy(pool);
    close(fd);

    *out_data = data;
    *out_size = size;
    return buf;
}

static void layer_configure(void *data, struct zwlr_layer_surface_v1 *ls, uint32_t serial, uint32_t w, uint32_t h) {
    struct pane *p = data;
    zwlr_layer_surface_v1_ack_configure(ls, serial);

    if (w == 0 || h == 0)
        return;

    if (!p->buffer || (int32_t)w != p->w || (int32_t)h != p->h) {
        if (p->buffer) {
            wl_buffer_destroy(p->buffer);
            munmap(p->data, p->size);
            p->buffer = NULL;
        }
        p->buffer = make_buffer((int32_t)w, (int32_t)h, &p->data, &p->size);
        p->w      = (int32_t)w;
        p->h      = (int32_t)h;
    }
    if (!p->buffer) {
        fprintf(stderr, "hyprlock-blur: could not allocate a %dx%d buffer\n", (int)w, (int)h);
        return;
    }
    // Click/keypress-through: everything goes to the lock surface underneath us.
    struct wl_region *empty = wl_compositor_create_region(compositor);
    wl_surface_set_input_region(p->surface, empty);
    wl_region_destroy(empty);

    wl_surface_attach(p->surface, p->buffer, 0, 0);
    wl_surface_damage_buffer(p->surface, 0, 0, p->w, p->h);
    wl_surface_commit(p->surface);
}

static void layer_closed(void *data, struct zwlr_layer_surface_v1 *ls) {
    (void)data;
    (void)ls;
    running = false;
}

static const struct zwlr_layer_surface_v1_listener layer_listener = {
    .configure = layer_configure,
    .closed    = layer_closed,
};

static void add_pane(struct wl_output *output) {
    if (npanes >= MAX_OUTPUTS)
        return;

    struct pane *p = &panes[npanes++];
    p->output      = output;
    p->surface     = wl_compositor_create_surface(compositor);
    p->layer       = zwlr_layer_shell_v1_get_layer_surface(layer_shell, p->surface, output, ZWLR_LAYER_SHELL_V1_LAYER_OVERLAY, ns);

    zwlr_layer_surface_v1_add_listener(p->layer, &layer_listener, p);
    zwlr_layer_surface_v1_set_anchor(p->layer,
                                     ZWLR_LAYER_SURFACE_V1_ANCHOR_TOP | ZWLR_LAYER_SURFACE_V1_ANCHOR_BOTTOM | ZWLR_LAYER_SURFACE_V1_ANCHOR_LEFT |
                                         ZWLR_LAYER_SURFACE_V1_ANCHOR_RIGHT);
    zwlr_layer_surface_v1_set_size(p->layer, 0, 0);
    zwlr_layer_surface_v1_set_exclusive_zone(p->layer, -1);  // cover bars too
    zwlr_layer_surface_v1_set_keyboard_interactivity(p->layer, 0);
    wl_surface_commit(p->surface);
}

static void handle_global(void *data, struct wl_registry *registry, uint32_t name, const char *iface, uint32_t version) {
    (void)data;
    if (!strcmp(iface, wl_compositor_interface.name))
        compositor = wl_registry_bind(registry, name, &wl_compositor_interface, 4);
    else if (!strcmp(iface, wl_shm_interface.name))
        shm = wl_registry_bind(registry, name, &wl_shm_interface, 1);
    else if (!strcmp(iface, zwlr_layer_shell_v1_interface.name))
        layer_shell = wl_registry_bind(registry, name, &zwlr_layer_shell_v1_interface, version < 4 ? version : 4);
    else if (!strcmp(iface, wl_output_interface.name)) {
        struct wl_output *output = wl_registry_bind(registry, name, &wl_output_interface, 1);
        if (ready)
            add_pane(output);  // hotplug
        else if (npending < MAX_OUTPUTS)
            pending_outputs[npending++] = output;
    }
}

static void handle_global_remove(void *data, struct wl_registry *registry, uint32_t name) {
    (void)data;
    (void)registry;
    (void)name;
}

static const struct wl_registry_listener registry_listener = {
    .global        = handle_global,
    .global_remove = handle_global_remove,
};

int main(int argc, char **argv) {
    double dim = 0.0;

    for (int i = 1; i < argc; i++) {
        if (!strcmp(argv[i], "--dim") && i + 1 < argc)
            dim = atof(argv[++i]);
        else if (!strcmp(argv[i], "--namespace") && i + 1 < argc)
            ns = argv[++i];
        else {
            fprintf(stderr, "usage: %s [--dim 0.0-1.0] [--namespace NAME]\n", argv[0]);
            return 1;
        }
    }
    if (dim < 0.0)
        dim = 0.0;
    if (dim > 1.0)
        dim = 1.0;

    // Black, premultiplied: rgb stays 0 whatever the alpha. Keep alpha >= 1 so
    // the compositor never has a reason to skip the surface (and thus the blur).
    uint32_t alpha = (uint32_t)(dim * 255.0 + 0.5);
    if (alpha < 1)
        alpha = 1;
    pixel = alpha << 24;

    struct wl_display *display = wl_display_connect(NULL);
    if (!display) {
        fprintf(stderr, "hyprlock-blur: cannot connect to the wayland display\n");
        return 1;
    }

    struct wl_registry *registry = wl_display_get_registry(display);
    wl_registry_add_listener(registry, &registry_listener, NULL);
    wl_display_roundtrip(display);

    if (!compositor || !shm || !layer_shell) {
        fprintf(stderr, "hyprlock-blur: compositor is missing wl_shm or zwlr_layer_shell_v1\n");
        return 1;
    }

    for (int i = 0; i < npending; i++)
        add_pane(pending_outputs[i]);
    ready = true;

    if (npanes == 0) {
        fprintf(stderr, "hyprlock-blur: no outputs\n");
        return 1;
    }

    while (running && wl_display_dispatch(display) != -1)
        ;

    return 0;
}
