// VoltaLookAndFeel: the Volta-Native look for JUCE plugins (Violent, Stacker), drawn from the same
// tokens as the SwiftUI components (include/volta_tokens.h, generated from tokens/tokens.json).
//
// Header-only. Link the `volta_native_juce` CMake target, then:
//
//     VoltaLookAndFeel lnf;                       // a member of your editor, declared before its children
//     setLookAndFeel (&lnf);                      // in the editor constructor
//     lnf.onAppearanceChanged = [this] { sendLookAndFeelChange(); };
//     ...
//     setLookAndFeel (nullptr);                   // in the editor destructor
//
// It follows the system light or dark mode where JUCE can read it (macOS, Windows) and is dark
// elsewhere. A `volta::Theme` can force light or dark and replace the accent and the canvas,
// surface and text colours; it saves as the same JSON as the Swift `VoltaTheme`:
//
//     lnf.setTheme (volta::Theme::fromJSON (savedJSON));
//     savedJSON = lnf.getTheme().toJSON();
//
// `volta::ThemeEditor` is a small component that lets a person pick these.
//
// It follows macOS light and dark mode by default. Mark the one primary action in a view with
// `VoltaLookAndFeel::makeProminent (button)`. Rotary sliders draw as knobs; bipolar ranges
// (min < 0 < max) fill from the centre. A slider with its own `rotarySliderFillColourId`
// draws its value in that colour instead of the accent.
//
// JUCE paints without implicit animation, so hover and press changes are immediate rather than
// the 150 ms fade the SwiftUI components use.

#pragma once

#include <juce_gui_basics/juce_gui_basics.h>
#include <functional>
#include <optional>

#include "volta_tokens.h"

namespace volta
{

inline juce::Colour tokenColour (double r, double g, double b)
{
    return juce::Colour::fromFloatRGBA ((float) r, (float) g, (float) b, 1.0f);
}

/// Appearance-dependent colours, from the light and dark tokens (tokens/tokens.json). Those mirror
/// AppKit's textBackgroundColor, controlBackgroundColor, labelColor and secondaryLabelColor, which
/// the SwiftUI side uses directly when it follows the system.
struct Palette
{
    juce::Colour canvas;    // window background
    juce::Colour surface;   // fields, knob discs, popup menus
    juce::Colour text;      // primary text
    juce::Colour secondary; // labels, units, borders are drawn from this at token opacities

    static Palette light()
    {
        return { tokenColour (VOLTA_COLOR_LIGHT_CANVAS_RED, VOLTA_COLOR_LIGHT_CANVAS_GREEN, VOLTA_COLOR_LIGHT_CANVAS_BLUE),
                 tokenColour (VOLTA_COLOR_LIGHT_SURFACE_RED, VOLTA_COLOR_LIGHT_SURFACE_GREEN, VOLTA_COLOR_LIGHT_SURFACE_BLUE),
                 tokenColour (VOLTA_COLOR_LIGHT_TEXT_RED, VOLTA_COLOR_LIGHT_TEXT_GREEN, VOLTA_COLOR_LIGHT_TEXT_BLUE),
                 tokenColour (VOLTA_COLOR_LIGHT_SECONDARY_RED, VOLTA_COLOR_LIGHT_SECONDARY_GREEN, VOLTA_COLOR_LIGHT_SECONDARY_BLUE) };
    }

    static Palette dark()
    {
        return { tokenColour (VOLTA_COLOR_DARK_CANVAS_RED, VOLTA_COLOR_DARK_CANVAS_GREEN, VOLTA_COLOR_DARK_CANVAS_BLUE),
                 tokenColour (VOLTA_COLOR_DARK_SURFACE_RED, VOLTA_COLOR_DARK_SURFACE_GREEN, VOLTA_COLOR_DARK_SURFACE_BLUE),
                 tokenColour (VOLTA_COLOR_DARK_TEXT_RED, VOLTA_COLOR_DARK_TEXT_GREEN, VOLTA_COLOR_DARK_TEXT_BLUE),
                 tokenColour (VOLTA_COLOR_DARK_SECONDARY_RED, VOLTA_COLOR_DARK_SECONDARY_GREEN, VOLTA_COLOR_DARK_SECONDARY_BLUE) };
    }
};

/// True when the system can report light or dark mode. Elsewhere Volta uses dark.
inline bool systemAppearanceAvailable()
{
   #if JUCE_MAC || JUCE_WINDOWS
    return true;
   #else
    return false;
   #endif
}

/// The system's dark mode, or true where it can't be read.
inline bool systemIsDark()
{
    return systemAppearanceAvailable() ? juce::Desktop::getInstance().isDarkModeActive() : true;
}

inline juce::Colour defaultAccent()
{
    return juce::Colour::fromFloatRGBA ((float) VOLTA_COLOR_ACCENT_RED, (float) VOLTA_COLOR_ACCENT_GREEN,
                                        (float) VOLTA_COLOR_ACCENT_BLUE, 1.0f);
}

/// Opacity helpers so call sites read like the Swift code.
inline juce::Colour boundary (const Palette& p) { return p.secondary.withAlpha ((float) VOLTA_OPACITY_BOUNDARY); }
inline juce::Colour divider  (const Palette& p) { return p.secondary.withAlpha ((float) VOLTA_OPACITY_DIVIDER); }
inline juce::Colour hover    (const Palette& p) { return p.text.withAlpha ((float) VOLTA_OPACITY_HOVER); }

/// The colours a person can choose, plus light or dark. Unset colours keep the appearance's own,
/// so a theme can change only the accent. Saves to the same JSON as the Swift `VoltaTheme`.
struct Theme
{
    enum class Appearance { system, light, dark };

    Appearance appearance = Appearance::system;
    juce::Colour accent = defaultAccent();
    std::optional<juce::Colour> canvas, surface, text;

    bool hasCustomColours() const noexcept { return canvas || surface || text; }

    /// Whether this theme draws dark, given the system's current setting.
    bool isDark (bool systemDark) const noexcept
    {
        switch (appearance)
        {
            case Appearance::light: return false;
            case Appearance::dark:  return true;
            case Appearance::system: break;
        }
        return systemDark;
    }

    /// The colours to draw with. A custom text colour also sets secondary: the text at 60% over the canvas.
    Palette resolve (bool systemDark) const
    {
        auto p = isDark (systemDark) ? Palette::dark() : Palette::light();
        if (canvas)  p.canvas = *canvas;
        if (surface) p.surface = *surface;
        if (text)
        {
            p.text = *text;
            p.secondary = p.canvas.interpolatedWith (*text, 0.6f);
        }
        return p;
    }

    bool operator== (const Theme& other) const noexcept
    {
        return appearance == other.appearance && accent == other.accent
            && canvas == other.canvas && surface == other.surface && text == other.text;
    }
    bool operator!= (const Theme& other) const noexcept { return ! operator== (other); }

    //==============================================================================
    // Saving: {"appearance":"dark","accent":{"red":1,"green":0.4,"blue":0.2},"canvas":{...}}

    static juce::var colourToVar (juce::Colour c)
    {
        auto* o = new juce::DynamicObject();
        o->setProperty ("red", (double) c.getFloatRed());
        o->setProperty ("green", (double) c.getFloatGreen());
        o->setProperty ("blue", (double) c.getFloatBlue());
        return juce::var (o);
    }

    static std::optional<juce::Colour> colourFromVar (const juce::var& v)
    {
        if (! v.isObject() || ! v.hasProperty ("red") || ! v.hasProperty ("green") || ! v.hasProperty ("blue"))
            return std::nullopt;
        auto channel = [&v] (const char* name) { return juce::jlimit (0.0, 1.0, (double) v.getProperty (name, 0.0)); };
        return tokenColour (channel ("red"), channel ("green"), channel ("blue"));
    }

    juce::var toVar() const
    {
        auto* o = new juce::DynamicObject();
        o->setProperty ("appearance", appearance == Appearance::light ? "light" : appearance == Appearance::dark ? "dark" : "system");
        o->setProperty ("accent", colourToVar (accent));
        if (canvas)  o->setProperty ("canvas", colourToVar (*canvas));
        if (surface) o->setProperty ("surface", colourToVar (*surface));
        if (text)    o->setProperty ("text", colourToVar (*text));
        return juce::var (o);
    }

    /// Missing or unreadable values fall back to the defaults, so older or newer saves still load.
    static Theme fromVar (const juce::var& v)
    {
        Theme t;
        const auto a = v.getProperty ("appearance", "system").toString();
        t.appearance = a == "light" ? Appearance::light : a == "dark" ? Appearance::dark : Appearance::system;
        if (auto c = colourFromVar (v.getProperty ("accent", {}))) t.accent = *c;
        t.canvas  = colourFromVar (v.getProperty ("canvas", {}));
        t.surface = colourFromVar (v.getProperty ("surface", {}));
        t.text    = colourFromVar (v.getProperty ("text", {}));
        return t;
    }

    juce::String toJSON() const { return juce::JSON::toString (toVar(), true); }
    static Theme fromJSON (const juce::String& json) { return fromVar (juce::JSON::parse (json)); }
};

class VoltaLookAndFeel : public juce::LookAndFeel_V4,
                         private juce::DarkModeSettingListener
{
public:
    static constexpr float cornerRadius      = (float) VOLTA_RADIUS_CONTROL;
    static constexpr float smallCornerRadius = (float) VOLTA_RADIUS_CHECKBOX;
    static constexpr float knobTrackWidth    = (float) VOLTA_SIZE_KNOB_TRACK;
    static constexpr float labelFontSize     = 11.0f;
    static constexpr float buttonFontSize    = 13.0f;

    /// Called after the appearance flips between light and dark. Editors use it to
    /// `sendLookAndFeelChange()` and repaint.
    std::function<void()> onAppearanceChanged;

    explicit VoltaLookAndFeel (juce::Colour accentColour = defaultAccent())
    {
        theme.accent = accentColour;
        juce::Desktop::getInstance().addDarkModeSettingListener (this);
        applyTheme();
    }

    explicit VoltaLookAndFeel (const Theme& initialTheme)
        : theme (initialTheme)
    {
        juce::Desktop::getInstance().addDarkModeSettingListener (this);
        applyTheme();
    }

    ~VoltaLookAndFeel() override
    {
        juce::Desktop::getInstance().removeDarkModeSettingListener (this);
    }

    const Palette& palette() const noexcept { return colours; }
    juce::Colour getAccent() const noexcept  { return accent; }

    void setAccent (juce::Colour newAccent)
    {
        auto t = theme;
        t.accent = newAccent;
        setTheme (t);
    }

    /// Forces light or dark instead of following the system.
    void setDarkMode (bool shouldBeDark)
    {
        auto t = theme;
        t.appearance = shouldBeDark ? Theme::Appearance::dark : Theme::Appearance::light;
        setTheme (t);
    }

    bool isDark() const noexcept { return dark; }

    const Theme& getTheme() const noexcept { return theme; }

    /// Applies `newTheme`, refreshes every window and calls `onAppearanceChanged`.
    void setTheme (const Theme& newTheme)
    {
        if (newTheme == theme)
            return;
        theme = newTheme;
        applyTheme();
        refreshComponents();
    }

    /// Draws `button` as the view's one primary action: accent fill, white semibold text.
    static void makeProminent (juce::Button& button, bool prominent = true)
    {
        button.getProperties().set (prominentProperty, prominent);
        button.repaint();
    }

    static bool isProminent (const juce::Button& button)
    {
        return (bool) button.getProperties().getWithDefault (prominentProperty, false);
    }

    /// The colour a slider's value is drawn in: the accent, unless that slider has its own
    /// `Slider::rotarySliderFillColourId` (for example a per-module colour).
    juce::Colour valueColour (const juce::Slider& slider) const
    {
        return slider.isColourSpecified (juce::Slider::rotarySliderFillColourId)
            ? slider.findColour (juce::Slider::rotarySliderFillColourId) : accent;
    }

    juce::Font labelFont (bool semibold = false) const
    {
        return juce::Font (juce::FontOptions (labelFontSize, semibold ? juce::Font::bold : juce::Font::plain));
    }

    //==============================================================================
    // Knobs

    void drawRotarySlider (juce::Graphics& g, int x, int y, int width, int height, float sliderPos,
                           float startAngle, float endAngle, juce::Slider& slider) override
    {
        const auto bounds = juce::Rectangle<int> (x, y, width, height).toFloat().reduced (knobTrackWidth);
        const auto diameter = juce::jmin (bounds.getWidth(), bounds.getHeight());
        const auto centre = bounds.getCentre();
        const auto radius = diameter * 0.5f - knobTrackWidth * 0.5f;
        const bool enabled = slider.isEnabled();
        const bool active = enabled && (slider.isMouseOverOrDragging());
        const float alpha = enabled ? 1.0f : (float) VOLTA_OPACITY_DISABLED;

        const auto stroke = juce::PathStrokeType (knobTrackWidth, juce::PathStrokeType::curved, juce::PathStrokeType::rounded);

        juce::Path track;
        track.addCentredArc (centre.x, centre.y, radius, radius, 0.0f, startAngle, endAngle, true);
        g.setColour (colours.secondary.withAlpha ((float) (active ? VOLTA_OPACITY_DIVIDER : VOLTA_OPACITY_CONTROL_FILL_HOVER) * alpha));
        g.strokePath (track, stroke);

        // Bipolar parameters fill from the centre, others from the minimum.
        const auto range = slider.getRange();
        const bool bipolar = range.getStart() < 0.0 && range.getEnd() > 0.0;
        const float originPos = bipolar ? (float) slider.valueToProportionOfLength (0.0) : 0.0f;
        const float originAngle = startAngle + originPos * (endAngle - startAngle);
        const float valueAngle  = startAngle + sliderPos * (endAngle - startAngle);

        if (std::abs (valueAngle - originAngle) > 0.001f)
        {
            juce::Path value;
            value.addCentredArc (centre.x, centre.y, radius, radius, 0.0f,
                                 juce::jmin (originAngle, valueAngle), juce::jmax (originAngle, valueAngle), true);
            g.setColour (valueColour (slider).withMultipliedAlpha (alpha));
            g.strokePath (value, stroke);
        }

        // Flat disc with a hairline edge; no shadow, no gradient.
        const auto discRadius = radius - 8.0f + knobTrackWidth * 0.5f;
        const auto disc = juce::Rectangle<float> (discRadius * 2.0f, discRadius * 2.0f).withCentre (centre);
        g.setColour (colours.surface.withMultipliedAlpha (alpha));
        g.fillEllipse (disc);
        g.setColour (colours.secondary.withAlpha ((float) VOLTA_OPACITY_BOUNDARY * 2.0f * alpha));
        g.drawEllipse (disc.reduced (0.5f), 1.0f);

        // Thin pointer in the text colour.
        const auto pointerLength = diameter * 0.18f;
        const auto pointerInner = discRadius - 3.0f - pointerLength;
        juce::Path pointer;
        pointer.addRoundedRectangle (-1.0f, -(pointerInner + pointerLength), 2.0f, pointerLength, 1.0f);
        g.setColour (colours.text.withAlpha (0.8f * alpha));
        g.fillPath (pointer, juce::AffineTransform::rotation (valueAngle).translated (centre));

        if (slider.hasKeyboardFocus (false))
        {
            g.setColour (accent.withAlpha (0.5f));
            g.drawEllipse (disc.reduced (1.5f), 2.0f);
        }
    }

    //==============================================================================
    // Linear sliders

    void drawLinearSlider (juce::Graphics& g, int x, int y, int width, int height, float sliderPos,
                           float minSliderPos, float maxSliderPos, juce::Slider::SliderStyle style,
                           juce::Slider& slider) override
    {
        if (style != juce::Slider::LinearHorizontal && style != juce::Slider::LinearVertical)
        {
            LookAndFeel_V4::drawLinearSlider (g, x, y, width, height, sliderPos, minSliderPos, maxSliderPos, style, slider);
            return;
        }

        const bool horizontal = style == juce::Slider::LinearHorizontal;
        const bool enabled = slider.isEnabled();
        const float alpha = enabled ? 1.0f : (float) VOLTA_OPACITY_DISABLED;
        const auto area = juce::Rectangle<int> (x, y, width, height).toFloat();
        constexpr float trackThickness = 3.0f;
        constexpr float thumbSize = 12.0f;

        const auto track = horizontal
            ? juce::Rectangle<float> (area.getX(), area.getCentreY() - trackThickness * 0.5f, area.getWidth(), trackThickness)
            : juce::Rectangle<float> (area.getCentreX() - trackThickness * 0.5f, area.getY(), trackThickness, area.getHeight());

        g.setColour (colours.secondary.withAlpha ((float) VOLTA_OPACITY_CONTROL_FILL_HOVER * alpha));
        g.fillRoundedRectangle (track, trackThickness * 0.5f);

        const auto range = slider.getRange();
        const bool bipolar = range.getStart() < 0.0 && range.getEnd() > 0.0;
        const float origin = horizontal
            ? (bipolar ? area.getX() + (float) slider.valueToProportionOfLength (0.0) * area.getWidth() : area.getX())
            : (bipolar ? area.getBottom() - (float) slider.valueToProportionOfLength (0.0) * area.getHeight() : area.getBottom());

        const auto filled = horizontal
            ? juce::Rectangle<float>::leftTopRightBottom (juce::jmin (origin, sliderPos), track.getY(), juce::jmax (origin, sliderPos), track.getBottom())
            : juce::Rectangle<float>::leftTopRightBottom (track.getX(), juce::jmin (origin, sliderPos), track.getRight(), juce::jmax (origin, sliderPos));
        g.setColour (valueColour (slider).withMultipliedAlpha (alpha));
        g.fillRoundedRectangle (filled, trackThickness * 0.5f);

        const auto thumbCentre = horizontal ? juce::Point<float> (sliderPos, area.getCentreY())
                                            : juce::Point<float> (area.getCentreX(), sliderPos);
        const auto thumb = juce::Rectangle<float> (thumbSize, thumbSize).withCentre (thumbCentre);
        g.setColour (colours.surface.withMultipliedAlpha (alpha));
        g.fillEllipse (thumb);
        const bool active = enabled && slider.isMouseOverOrDragging();
        g.setColour (colours.secondary.withAlpha ((active ? 0.5f : (float) VOLTA_OPACITY_DIVIDER) * alpha));
        g.drawEllipse (thumb.reduced (0.5f), 1.0f);
    }

    int getSliderThumbRadius (juce::Slider& slider) override
    {
        return slider.isRotary() ? LookAndFeel_V4::getSliderThumbRadius (slider) : 6;
    }

    juce::Label* createSliderTextBox (juce::Slider& slider) override
    {
        auto* label = LookAndFeel_V4::createSliderTextBox (slider);
        label->setFont (juce::Font (juce::FontOptions (labelFontSize, juce::Font::plain)));
        return label;
    }

    //==============================================================================
    // Buttons

    void drawButtonBackground (juce::Graphics& g, juce::Button& button, const juce::Colour&,
                               bool highlighted, bool down) override
    {
        const auto area = button.getLocalBounds().toFloat().reduced (0.5f);
        const bool enabled = button.isEnabled();
        const bool active = enabled && highlighted;
        const float alpha = enabled ? 1.0f : (float) VOLTA_OPACITY_DISABLED;

        if (isProminent (button))
        {
            const float level = down ? 0.70f : active ? 0.88f : 1.0f;
            g.setColour (accent.withAlpha (level * alpha));
            g.fillRoundedRectangle (area, cornerRadius);
            return;
        }

        const bool on = button.getToggleState() && button.getClickingTogglesState();
        const double fill = down ? VOLTA_OPACITY_CONTROL_FILL_PRESSED : active ? VOLTA_OPACITY_CONTROL_FILL_HOVER : VOLTA_OPACITY_CONTROL_FILL;
        g.setColour (on ? accent.withAlpha ((float) VOLTA_OPACITY_CONTROL_FILL_HOVER * alpha)
                        : colours.secondary.withAlpha ((float) fill * alpha));
        g.fillRoundedRectangle (area, cornerRadius);

        g.setColour (colours.secondary.withAlpha ((active ? 0.5f : (float) VOLTA_OPACITY_DIVIDER) * alpha));
        g.drawRoundedRectangle (area, cornerRadius, 1.0f);
    }

    juce::Font getTextButtonFont (juce::TextButton& button, int) override
    {
        return juce::Font (juce::FontOptions (buttonFontSize, isProminent (button) ? juce::Font::bold : juce::Font::plain));
    }

    void drawButtonText (juce::Graphics& g, juce::TextButton& button, bool, bool) override
    {
        const bool on = button.getToggleState() && button.getClickingTogglesState();
        auto colour = isProminent (button) ? juce::Colours::white : on ? accent : colours.text;
        if (! button.isEnabled())
            colour = colour.withMultipliedAlpha ((float) VOLTA_OPACITY_DISABLED);

        g.setFont (getTextButtonFont (button, button.getHeight()));
        g.setColour (colour);
        g.drawFittedText (button.getButtonText(), button.getLocalBounds().reduced ((int) VOLTA_SPACING_CONTROL_HORIZONTAL, 0),
                          juce::Justification::centred, 1);
    }

    //==============================================================================
    // Checkboxes (ToggleButton)

    void drawToggleButton (juce::Graphics& g, juce::ToggleButton& button, bool highlighted, bool) override
    {
        const bool enabled = button.isEnabled();
        const float alpha = enabled ? 1.0f : (float) VOLTA_OPACITY_DISABLED;
        const auto bounds = button.getLocalBounds().toFloat();

        // The whole row is the click target, so the whole row gets the hover background.
        if (enabled && highlighted)
        {
            g.setColour (colours.secondary.withAlpha ((float) VOLTA_OPACITY_CONTROL_FILL));
            g.fillRoundedRectangle (bounds, cornerRadius);
        }

        const float boxSize = (float) VOLTA_SIZE_CHECKBOX;
        const auto box = juce::Rectangle<float> (boxSize, boxSize)
                             .withPosition (bounds.getX() + 6.0f, bounds.getCentreY() - boxSize * 0.5f);
        const bool on = button.getToggleState();

        if (on)
        {
            g.setColour (accent.withMultipliedAlpha (alpha));
            g.fillRoundedRectangle (box, smallCornerRadius);

            juce::Path tick;
            tick.startNewSubPath (box.getX() + boxSize * 0.27f, box.getCentreY());
            tick.lineTo (box.getX() + boxSize * 0.43f, box.getY() + boxSize * 0.68f);
            tick.lineTo (box.getX() + boxSize * 0.74f, box.getY() + boxSize * 0.32f);
            g.setColour (juce::Colours::white.withAlpha (alpha));
            g.strokePath (tick, juce::PathStrokeType (1.6f, juce::PathStrokeType::curved, juce::PathStrokeType::rounded));
        }
        else
        {
            g.setColour (colours.secondary.withAlpha (0.6f * alpha));
            g.drawRoundedRectangle (box.reduced (0.5f), smallCornerRadius, 1.0f);
        }

        g.setColour (colours.text.withAlpha (alpha));
        g.setFont (juce::Font (juce::FontOptions (buttonFontSize - 1.0f)));
        g.drawFittedText (button.getButtonText(),
                          button.getLocalBounds().withTrimmedLeft ((int) (box.getRight() + 8.0f)).withTrimmedRight (6),
                          juce::Justification::centredLeft, 1);
    }

    //==============================================================================
    // Combo boxes and menus

    void drawComboBox (juce::Graphics& g, int width, int height, bool down, int, int, int, int, juce::ComboBox& box) override
    {
        const auto area = juce::Rectangle<int> (width, height).toFloat().reduced (0.5f);
        const bool enabled = box.isEnabled();
        const bool active = enabled && box.isMouseOver (true);
        const float alpha = enabled ? 1.0f : (float) VOLTA_OPACITY_DISABLED;
        const double fill = down ? VOLTA_OPACITY_CONTROL_FILL_PRESSED : active ? VOLTA_OPACITY_CONTROL_FILL_HOVER : VOLTA_OPACITY_CONTROL_FILL;

        g.setColour (colours.secondary.withAlpha ((float) fill * alpha));
        g.fillRoundedRectangle (area, cornerRadius);
        g.setColour (box.hasKeyboardFocus (true) ? accent : colours.secondary.withAlpha ((active ? 0.5f : (float) VOLTA_OPACITY_DIVIDER) * alpha));
        g.drawRoundedRectangle (area, cornerRadius, 1.0f);

        // A small chevron, secondary colour.
        const auto arrowArea = juce::Rectangle<float> ((float) width - 20.0f, 0.0f, 12.0f, (float) height);
        juce::Path chevron;
        chevron.startNewSubPath (arrowArea.getCentreX() - 3.5f, arrowArea.getCentreY() - 1.5f);
        chevron.lineTo (arrowArea.getCentreX(), arrowArea.getCentreY() + 2.0f);
        chevron.lineTo (arrowArea.getCentreX() + 3.5f, arrowArea.getCentreY() - 1.5f);
        g.setColour (colours.secondary.withAlpha (alpha));
        g.strokePath (chevron, juce::PathStrokeType (1.4f, juce::PathStrokeType::curved, juce::PathStrokeType::rounded));
    }

    juce::Font getComboBoxFont (juce::ComboBox&) override       { return juce::Font (juce::FontOptions (12.0f)); }
    juce::Font getPopupMenuFont() override                      { return juce::Font (juce::FontOptions (13.0f)); }

    void positionComboBoxText (juce::ComboBox& box, juce::Label& label) override
    {
        label.setBounds (8, 1, box.getWidth() - 30, box.getHeight() - 2);
        label.setFont (getComboBoxFont (box));
    }

    void drawPopupMenuBackground (juce::Graphics& g, int width, int height) override
    {
        g.fillAll (colours.surface);
        g.setColour (boundary (colours));
        g.drawRect (0, 0, width, height, 1);
    }

    //==============================================================================
    // Text editors and labels

    void fillTextEditorBackground (juce::Graphics& g, int width, int height, juce::TextEditor&) override
    {
        g.setColour (colours.surface);
        g.fillRoundedRectangle (juce::Rectangle<int> (width, height).toFloat(), cornerRadius);
    }

    void drawTextEditorOutline (juce::Graphics& g, int width, int height, juce::TextEditor& editor) override
    {
        if (! editor.isEnabled())
            return;

        const auto area = juce::Rectangle<int> (width, height).toFloat();
        if (editor.hasKeyboardFocus (true) && ! editor.isReadOnly())
        {
            g.setColour (accent);
            g.drawRoundedRectangle (area.reduced (1.0f), cornerRadius, 2.0f);
        }
        else
        {
            g.setColour (editor.isMouseOver (true) ? colours.secondary.withAlpha (0.5f) : divider (colours));
            g.drawRoundedRectangle (area.reduced (0.5f), cornerRadius, 1.0f);
        }
    }

    juce::Font getLabelFont (juce::Label& label) override
    {
        return label.getFont().withHeight (juce::jmin (label.getFont().getHeight(), 13.0f));
    }

    /// A section panel: hairline border, faint fill, no shadow. Call from a component's paint().
    void drawPanel (juce::Graphics& g, juce::Rectangle<float> area) const
    {
        g.setColour (colours.secondary.withAlpha ((float) VOLTA_OPACITY_PANEL_FILL));
        g.fillRoundedRectangle (area, cornerRadius);
        g.setColour (boundary (colours));
        g.drawRoundedRectangle (area.reduced (0.5f), cornerRadius, 1.0f);
    }

    /// A section heading: 11 pt semibold, secondary.
    void drawSectionLabel (juce::Graphics& g, const juce::String& text, juce::Rectangle<int> area) const
    {
        g.setColour (colours.secondary);
        g.setFont (labelFont (true));
        g.drawText (text, area, juce::Justification::centredLeft, true);
    }

private:
    static constexpr const char* prominentProperty = "volta-prominent";

    Theme theme;
    Palette colours = Palette::dark();
    juce::Colour accent = defaultAccent();
    bool dark = true;

    void darkModeSettingChanged() override
    {
        if (theme.appearance != Theme::Appearance::system)
            return;
        applyTheme();
        refreshComponents();
    }

    void refreshComponents()
    {
        auto& desktop = juce::Desktop::getInstance();
        for (int i = 0; i < desktop.getNumComponents(); ++i)
            if (auto* c = desktop.getComponent (i))
                c->sendLookAndFeelChange();

        if (onAppearanceChanged)
            onAppearanceChanged();
    }

    void applyTheme()
    {
        const bool systemDark = systemIsDark();
        dark = theme.isDark (systemDark);
        colours = theme.resolve (systemDark);
        accent = theme.accent;

        setColourScheme (dark ? getDarkColourScheme() : getLightColourScheme());

        using namespace juce;
        const auto transparent = Colours::transparentBlack;

        setColour (ResizableWindow::backgroundColourId, colours.canvas);
        setColour (DocumentWindow::textColourId, colours.text);

        setColour (Label::textColourId, colours.text);
        setColour (Label::backgroundColourId, transparent);
        setColour (Label::outlineColourId, transparent);
        setColour (Label::textWhenEditingColourId, colours.text);
        setColour (Label::backgroundWhenEditingColourId, colours.surface);
        setColour (Label::outlineWhenEditingColourId, accent);

        setColour (Slider::textBoxTextColourId, colours.text);
        setColour (Slider::textBoxBackgroundColourId, transparent);
        setColour (Slider::textBoxOutlineColourId, transparent);
        setColour (Slider::textBoxHighlightColourId, accent.withAlpha (0.3f));
        setColour (Slider::thumbColourId, accent);
        setColour (Slider::rotarySliderFillColourId, accent);
        setColour (Slider::trackColourId, accent);

        setColour (TextButton::buttonColourId, transparent);
        setColour (TextButton::buttonOnColourId, transparent);
        setColour (TextButton::textColourOffId, colours.text);
        setColour (TextButton::textColourOnId, accent);
        setColour (ToggleButton::textColourId, colours.text);
        setColour (ToggleButton::tickColourId, Colours::white);
        setColour (ToggleButton::tickDisabledColourId, colours.secondary);

        setColour (ComboBox::backgroundColourId, transparent);
        setColour (ComboBox::textColourId, colours.text);
        setColour (ComboBox::outlineColourId, divider (colours));
        setColour (ComboBox::arrowColourId, colours.secondary);
        setColour (ComboBox::focusedOutlineColourId, accent);

        setColour (PopupMenu::backgroundColourId, colours.surface);
        setColour (PopupMenu::textColourId, colours.text);
        setColour (PopupMenu::highlightedBackgroundColourId, accent.withAlpha (0.16f));
        setColour (PopupMenu::highlightedTextColourId, colours.text);
        setColour (PopupMenu::headerTextColourId, colours.secondary);

        setColour (TextEditor::backgroundColourId, colours.surface);
        setColour (TextEditor::textColourId, colours.text);
        setColour (TextEditor::highlightColourId, accent.withAlpha (0.3f));
        setColour (TextEditor::highlightedTextColourId, colours.text);
        setColour (TextEditor::outlineColourId, divider (colours));
        setColour (TextEditor::focusedOutlineColourId, accent);
        setColour (CaretComponent::caretColourId, accent);

        setColour (ScrollBar::thumbColourId, colours.secondary.withAlpha (0.4f));
        setColour (TooltipWindow::backgroundColourId, colours.surface);
        setColour (TooltipWindow::textColourId, colours.text);
        setColour (TooltipWindow::outlineColourId, boundary (colours));
    }
};

} // namespace volta
