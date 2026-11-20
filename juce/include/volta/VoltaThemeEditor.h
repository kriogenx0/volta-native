// ThemeEditor: lets a person pick the appearance and colours of a VoltaLookAndFeel's theme.
//
//     volta::ThemeEditor editor (lnf);
//     editor.onThemeChanged = [] (const volta::Theme& t) { saveSomewhere (t.toJSON()); };
//
// Appearance is a segmented System / Light / Dark row. Each colour is a swatch that opens a colour
// picker in a callout. Needs juce_gui_extra (plugin targets already link it). Reset returns to the default theme. Changes apply to the look and feel at once.

#pragma once

#include "VoltaLookAndFeel.h"
#include <juce_gui_extra/juce_gui_extra.h> // ColourSelector
#include <array>

namespace volta
{

class ThemeEditor : public juce::Component
{
public:
    /// Called after every change, with the theme now applied.
    std::function<void (const Theme&)> onThemeChanged;

    explicit ThemeEditor (VoltaLookAndFeel& lookAndFeelToEdit)
        : lnf (lookAndFeelToEdit)
    {
        const char* names[] = { "System", "Light", "Dark" };
        for (int i = 0; i < 3; ++i)
        {
            auto& b = appearanceButtons[(size_t) i];
            b.setButtonText (names[i]);
            b.setClickingTogglesState (true);
            b.setRadioGroupId (appearanceGroup);
            b.setConnectedEdges ((i > 0 ? juce::Button::ConnectedOnLeft : 0) | (i < 2 ? juce::Button::ConnectedOnRight : 0));
            b.onClick = [this, i]
            {
                if (! appearanceButtons[(size_t) i].getToggleState())
                    return;
                auto t = lnf.getTheme();
                t.appearance = static_cast<Theme::Appearance> (i);
                apply (t);
            };
            addAndMakeVisible (b);
        }

        for (auto* s : { &accentSwatch, &canvasSwatch, &surfaceSwatch, &textSwatch })
            addAndMakeVisible (*s);

        accentSwatch.onPick  = [this] (juce::Colour c) { auto t = lnf.getTheme(); t.accent = c;  apply (t); };
        canvasSwatch.onPick  = [this] (juce::Colour c) { auto t = lnf.getTheme(); t.canvas = c;  apply (t); };
        surfaceSwatch.onPick = [this] (juce::Colour c) { auto t = lnf.getTheme(); t.surface = c; apply (t); };
        textSwatch.onPick    = [this] (juce::Colour c) { auto t = lnf.getTheme(); t.text = c;    apply (t); };

        resetButton.setTooltip ("Use the default appearance and colours");
        resetButton.onClick = [this] { apply (Theme {}); };
        addAndMakeVisible (resetButton);

        refresh();
        setSize (320, 220);
    }

    /// Re-reads the look and feel's theme, for when something else changed it.
    void refresh()
    {
        const auto& t = lnf.getTheme();
        const auto& p = lnf.palette();
        appearanceButtons[(size_t) static_cast<int> (t.appearance)].setToggleState (true, juce::dontSendNotification);
        accentSwatch.setSwatchColour (t.accent);
        canvasSwatch.setSwatchColour (p.canvas);
        surfaceSwatch.setSwatchColour (p.surface);
        textSwatch.setSwatchColour (p.text);
        resetButton.setEnabled (t != Theme {});
        repaint();
    }

    void paint (juce::Graphics& g) override
    {
        g.setColour (lnf.palette().secondary);
        g.setFont (lnf.labelFont (true));
        g.drawText ("APPEARANCE", appearanceLabel, juce::Justification::centredLeft);
        g.drawText ("COLORS", coloursLabel, juce::Justification::centredLeft);
    }

    void resized() override
    {
        auto area = getLocalBounds();
        appearanceLabel = area.removeFromTop (18);
        auto row = area.removeFromTop ((int) VOLTA_SIZE_FIELD_HEIGHT);
        const int w = row.getWidth() / 3;
        for (auto& b : appearanceButtons)
            b.setBounds (row.removeFromLeft (w));

        area.removeFromTop (12);
        coloursLabel = area.removeFromTop (18);
        for (auto* s : { &accentSwatch, &canvasSwatch, &surfaceSwatch, &textSwatch })
            s->setBounds (area.removeFromTop (26));

        area.removeFromTop (8);
        resetButton.setBounds (area.removeFromTop ((int) VOLTA_SIZE_FIELD_HEIGHT).removeFromRight (80));
    }

    void lookAndFeelChanged() override { refresh(); }

private:
    /// A labelled colour swatch. Clicking it opens a ColourSelector in a callout.
    class Swatch : public juce::Component
    {
    public:
        std::function<void (juce::Colour)> onPick;

        explicit Swatch (juce::String labelText) : label (std::move (labelText))
        {
            setMouseCursor (juce::MouseCursor::PointingHandCursor);
            setTitle (label);
            setWantsKeyboardFocus (true);
        }

        void setSwatchColour (juce::Colour c) { colour = c; repaint(); }

        void paint (juce::Graphics& g) override
        {
            auto* laf = dynamic_cast<VoltaLookAndFeel*> (&getLookAndFeel());
            const auto p = laf != nullptr ? laf->palette() : Palette::dark();
            auto bounds = getLocalBounds().toFloat();

            if (isMouseOver())
            {
                g.setColour (hover (p));
                g.drawRoundedRectangle (bounds.reduced (0.5f), VoltaLookAndFeel::cornerRadius, 1.0f);
            }

            auto chip = bounds.removeFromRight (40.0f).reduced (4.0f);
            g.setColour (colour);
            g.fillRoundedRectangle (chip, VoltaLookAndFeel::smallCornerRadius);
            g.setColour (boundary (p).withMultipliedAlpha (2.0f));
            g.drawRoundedRectangle (chip.reduced (0.5f), VoltaLookAndFeel::smallCornerRadius, 1.0f);

            g.setColour (p.text);
            g.setFont (juce::FontOptions (13.0f));
            g.drawText (label, bounds.reduced (6.0f, 0.0f), juce::Justification::centredLeft);
        }

        void mouseEnter (const juce::MouseEvent&) override { repaint(); }
        void mouseExit (const juce::MouseEvent&) override  { repaint(); }
        void mouseUp (const juce::MouseEvent& e) override
        {
            if (e.mouseWasClicked() && getLocalBounds().contains (e.getPosition()))
                open();
        }

        bool keyPressed (const juce::KeyPress& key) override
        {
            if (key == juce::KeyPress::returnKey || key == juce::KeyPress::spaceKey) { open(); return true; }
            return false;
        }

    private:
        juce::String label;
        juce::Colour colour;

        void open()
        {
            auto picker = std::make_unique<Picker> (*this);
            picker->setCurrentColour (colour, juce::dontSendNotification);
            picker->setSize (260, 300);
            juce::CallOutBox::launchAsynchronously (std::move (picker), getScreenBounds(), nullptr);
        }

        void picked (juce::Colour c)
        {
            colour = c.withAlpha (1.0f);
            repaint();
            if (onPick)
                onPick (colour);
        }

        /// Reports to its swatch only while the swatch exists, since the callout can outlive it.
        class Picker : public juce::ColourSelector, private juce::ChangeListener
        {
        public:
            explicit Picker (Swatch& s)
                : juce::ColourSelector (showColourspace | showSliders | showColourAtTop), swatch (&s)
            {
                addChangeListener (this);
            }

            ~Picker() override { removeChangeListener (this); }

        private:
            juce::Component::SafePointer<Swatch> swatch;

            void changeListenerCallback (juce::ChangeBroadcaster*) override
            {
                if (swatch != nullptr)
                    swatch->picked (getCurrentColour());
            }
        };
    };

    static constexpr int appearanceGroup = 0x766f6c74;

    VoltaLookAndFeel& lnf;
    std::array<juce::TextButton, 3> appearanceButtons;
    Swatch accentSwatch { "Accent" }, canvasSwatch { "Background" }, surfaceSwatch { "Surface" }, textSwatch { "Text" };
    juce::TextButton resetButton { "Reset" };
    juce::Rectangle<int> appearanceLabel, coloursLabel;

    void apply (const Theme& t)
    {
        lnf.setTheme (t);
        refresh();
        if (onThemeChanged)
            onThemeChanged (lnf.getTheme());
    }
};

} // namespace volta
