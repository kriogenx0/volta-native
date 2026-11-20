/*
 * The Volta controls from plain C. Build and run with `make c-gallery`.
 * Same components, tokens and behaviour as the Swift gallery.
 */
#include <stdio.h>
#include "volta_native.h"

static volta_view status;
static volta_view email;
static volta_view progress;

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

static void on_view(void *context, size_t index) {
    (void)context;
    static const char *names[] = {"List", "Grid", "Columns"};
    printf("View: %s\n", names[index]);
}

/* The radio group drives the progress bar: unknown, half, done. */
static void on_stage(void *context, size_t index) {
    (void)context;
    static const double values[] = {-1, 0.5, 1};
    volta_progress_set(progress, values[index]);
}

static void on_remove(void *context) {
    printf("Remove tag: %s\n", (const char *)context);
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
    add(fields, volta_text_area_create("Notes", 320, 72, NULL, NULL));
    add(page, fields);

    add(page, volta_label_create("Checkbox", VOLTA_LABEL_HEADING));
    add(page, volta_checkbox_create("Enable the fields above", true, on_toggle, fields));

    add(page, volta_label_create("Switches and choices", VOLTA_LABEL_HEADING));
    add(page, volta_switch_create("Play sounds", false, NULL, NULL));
    static const char *views[] = {"List", "Grid", "Columns"};
    add(page, volta_segmented_create(views, 3, 0, on_view, NULL));
    static const char *sorts[] = {"Date", "Name", "Size"};
    add(page, volta_select_create(sorts, 3, 1, 200, NULL, NULL));

    add(page, volta_label_create("Status and progress", VOLTA_LABEL_HEADING));
    volta_view badges = volta_stack_create(false, 8);
    add(badges, volta_badge_create("Draft", VOLTA_TONE_NEUTRAL));
    add(badges, volta_badge_create("Paid", VOLTA_TONE_SUCCESS));
    add(badges, volta_badge_create("Overdue", VOLTA_TONE_DANGER));
    add(badges, volta_status_dot_create(VOLTA_TONE_SUCCESS, "Online"));
    add(badges, volta_spinner_create(0));
    add(page, badges);
    add(page, volta_message_create("Your changes were saved.", VOLTA_TONE_SUCCESS, 320));
    static const char *stages[] = {"Unknown", "Halfway", "Done"};
    add(page, volta_radio_group_create(stages, 3, 0, on_stage, NULL));
    progress = volta_progress_create(320);
    volta_stack_add(page, progress); /* Kept: on_stage updates it. */
    volta_view tags = volta_stack_create(false, 6);
    add(tags, volta_tag_create("design", on_remove, "design"));
    add(tags, volta_tag_create("audio", on_remove, "audio"));
    add(tags, volta_tag_create("read-only", NULL, NULL));
    add(page, tags);

    add(page, volta_label_create("Avatars and chips", VOLTA_LABEL_HEADING));
    volta_view people = volta_stack_create(false, 8);
    add(people, volta_avatar_create("Ada Lovelace", VOLTA_SIZE_AVATAR));
    add(people, volta_avatar_create("Grace Hopper", VOLTA_SIZE_AVATAR));
    add(people, volta_chip_create("Work", "briefcase", true));
    add(people, volta_chip_create("Later", "clock", false));
    add(page, people);

    volta_window window = volta_window_create("Volta C Gallery", 560, 1040);
    volta_window_set_content(window, page);
    volta_window_show(window);
    volta_app_run();

    volta_view_release(fields);
    volta_view_release(email);
    volta_view_release(progress);
    volta_view_release(page);
    volta_window_release(window);
    return 0;
}
