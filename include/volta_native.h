/*
 * Volta-Native C API.
 *
 * Gives C programs the same Volta controls that Swift apps get from the VoltaNative module.
 * Link against libVoltaNativeC.dylib (built with `make c-lib`). macOS 14 or later.
 *
 * Rules:
 *  - Call every function on the main thread.
 *  - Functions that return volta_view or volta_window hand you one reference. Release it with
 *    volta_view_release / volta_window_release when you no longer need it. Adding a view to a stack
 *    or window keeps it alive there, so you can release your reference right after adding it.
 *  - Strings you pass in are copied. Strings passed to your callbacks are only valid during the call.
 */
#ifndef VOLTA_NATIVE_H
#define VOLTA_NATIVE_H

#include <stdbool.h>
#include <stddef.h>
#include "volta_tokens.h"

#ifdef __cplusplus
extern "C" {
#endif

typedef void *volta_view;
typedef void *volta_window;

typedef void (*volta_action_fn)(void *context);
typedef void (*volta_toggle_fn)(void *context, bool is_on);
typedef void (*volta_text_fn)(void *context, const char *text);
typedef void (*volta_index_fn)(void *context, size_t index);

typedef enum {
    VOLTA_BUTTON_STANDARD = 0,
    VOLTA_BUTTON_PROMINENT = 1,
    VOLTA_BUTTON_LINK = 2,
    VOLTA_BUTTON_DESTRUCTIVE = 3
} volta_button_kind;

typedef enum {
    VOLTA_LABEL_BODY = 0,
    VOLTA_LABEL_TITLE = 1,
    VOLTA_LABEL_HEADING = 2,
    VOLTA_LABEL_SECONDARY = 3
} volta_label_style;

typedef enum {
    VOLTA_TONE_NEUTRAL = 0,
    VOLTA_TONE_INFO = 1,     /* Uses the accent. */
    VOLTA_TONE_SUCCESS = 2,
    VOLTA_TONE_WARNING = 3,
    VOLTA_TONE_DANGER = 4
} volta_tone;

/* App */
void volta_app_init(const char *app_name);          /* Call first. Sets up the app and its menu bar. */
void volta_app_run(void);                            /* Runs until the last window closes or the user quits. */
void volta_set_accent(double red, double green, double blue); /* Applies to controls created afterwards. */

/* Windows */
volta_window volta_window_create(const char *title, double width, double height);
void volta_window_set_content(volta_window window, volta_view content); /* Inset by 20pt so text never meets the edge. */
void volta_window_show(volta_window window);
void volta_window_release(volta_window window);

/* Layout */
volta_view volta_stack_create(bool vertical, double spacing);
void volta_stack_add(volta_view stack, volta_view child);
volta_view volta_divider_create(void);

/* Controls */
volta_view volta_label_create(const char *text, volta_label_style style);
volta_view volta_button_create(const char *title, volta_button_kind kind, volta_action_fn on_click, void *context);
volta_view volta_checkbox_create(const char *label, bool is_on, volta_toggle_fn on_change, void *context);
volta_view volta_switch_create(const char *label, bool is_on, volta_toggle_fn on_change, void *context);
bool volta_checkbox_is_on(volta_view checkbox);      /* Works on checkboxes and switches. */
volta_view volta_text_field_create(const char *placeholder, double width, volta_text_fn on_change, void *context);
volta_view volta_search_field_create(const char *placeholder, double width, volta_text_fn on_change, void *context);
volta_view volta_text_area_create(const char *placeholder, double width, double height, volta_text_fn on_change, void *context);
/* Works on text fields, search fields and text areas. Copies at most size - 1 bytes plus a terminator and returns the full length in bytes. */
size_t volta_field_get_text(volta_view field, char *buffer, size_t size);
void volta_field_set_text(volta_view field, const char *text);

/* Choices. `titles` holds `count` strings, which are copied. `selected` is an index into it. */
volta_view volta_segmented_create(const char *const *titles, size_t count, size_t selected, volta_index_fn on_change, void *context);
volta_view volta_radio_group_create(const char *const *titles, size_t count, size_t selected, volta_index_fn on_change, void *context);
volta_view volta_select_create(const char *const *titles, size_t count, size_t selected, double width, volta_index_fn on_change, void *context);
size_t volta_selection_get(volta_view choice);       /* Works on all three. */
void volta_selection_set(volta_view choice, size_t index); /* Does not call on_change. Out-of-range indexes are ignored. */

/* Display */
volta_view volta_avatar_create(const char *name, double size);
volta_view volta_chip_create(const char *title, const char *sf_symbol_or_null, bool is_applied);
volta_view volta_badge_create(const char *title, volta_tone tone);
volta_view volta_status_dot_create(volta_tone tone, const char *label_or_null);
volta_view volta_message_create(const char *text, volta_tone tone, double width);
/* With on_remove, the tag shows a remove button. Removing the view is up to you. */
volta_view volta_tag_create(const char *title, volta_action_fn on_remove_or_null, void *context);

/* Progress */
volta_view volta_progress_create(double width);      /* Starts indeterminate. */
void volta_progress_set(volta_view progress, double value); /* 0 to 1, or negative for indeterminate. */
volta_view volta_spinner_create(double size);        /* 0 uses VOLTA_SIZE_SPINNER. */

/* Any view */
void volta_view_set_enabled(volta_view view, bool enabled);
void volta_view_release(volta_view view);

#ifdef __cplusplus
}
#endif

#endif /* VOLTA_NATIVE_H */
