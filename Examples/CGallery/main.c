/*
 * The Volta controls from plain C. Build and run with `make c-gallery`.
 * Same components, tokens and behaviour as the Swift gallery.
 */
#include <stdio.h>
#include "volta_native.h"

static volta_view status;
static volta_view email;

static void add(volta_view stack, volta_view child) {
    volta_stack_add(stack, child);
    volta_view_release(child); /* The stack keeps it alive. */
}

static void on_save(void *context) {
    (void)context;
    char text[256];
    volta_field_get_text(email, text, sizeof text);
    printf("Saved %s\n", text[0] ? text : "(no email)");
}

static void on_toggle(void *context, bool is_on) {
    volta_view_set_enabled((volta_view)context, is_on);
}

static void on_search(void *context, const char *text) {
    (void)context;
    printf("Search: %s\n", text);
}

int main(void) {
    volta_app_init("Volta C Gallery");

    volta_view page = volta_stack_create(true, 14);
    add(page, volta_label_create("Volta controls from C", VOLTA_LABEL_TITLE));
    add(page, volta_label_create("Every control here is the same component Swift apps use.", VOLTA_LABEL_SECONDARY));
    add(page, volta_divider_create());

    add(page, volta_label_create("Buttons", VOLTA_LABEL_HEADING));
    volta_view buttons = volta_stack_create(false, 10);
    add(buttons, volta_button_create("Save", VOLTA_BUTTON_PROMINENT, on_save, NULL));
    add(buttons, volta_button_create("Cancel", VOLTA_BUTTON_STANDARD, NULL, NULL));
    add(buttons, volta_button_create("Delete", VOLTA_BUTTON_DESTRUCTIVE, NULL, NULL));
    add(buttons, volta_button_create("Learn more", VOLTA_BUTTON_LINK, NULL, NULL));
    add(page, buttons);

    add(page, volta_label_create("Fields", VOLTA_LABEL_HEADING));
    volta_view fields = volta_stack_create(true, 10);
    add(fields, volta_text_field_create("Name", 320, NULL, NULL));
    email = volta_text_field_create("Email", 320, NULL, NULL);
    volta_stack_add(fields, email); /* Kept: on_save reads it. */
    add(fields, volta_search_field_create("Search", 320, on_search, NULL));
    add(page, fields);

    add(page, volta_label_create("Checkbox", VOLTA_LABEL_HEADING));
    add(page, volta_checkbox_create("Enable the fields above", true, on_toggle, fields));

    add(page, volta_label_create("Avatars and chips", VOLTA_LABEL_HEADING));
    volta_view people = volta_stack_create(false, 8);
    add(people, volta_avatar_create("Ada Lovelace", VOLTA_SIZE_AVATAR));
    add(people, volta_avatar_create("Grace Hopper", VOLTA_SIZE_AVATAR));
    add(people, volta_chip_create("Work", "briefcase", true));
    add(people, volta_chip_create("Later", "clock", false));
    add(page, people);

    volta_window window = volta_window_create("Volta C Gallery", 560, 620);
    volta_window_set_content(window, page);
    volta_window_show(window);
    volta_app_run();

    volta_view_release(fields);
    volta_view_release(email);
    volta_view_release(page);
    volta_window_release(window);
    return 0;
}
