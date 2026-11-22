// volta::Knob: a labelled knob for one continuous parameter, the JUCE twin of SwiftUI's VoltaKnob.
//
//     volta::Knob gain { "Gain" };
//     addAndMakeVisible (gain);
//     attachment = std::make_unique<SliderAttachment> (apvts, "gain", gain.slider);
//
// - Name above, value below. Size it with `Knob::preferredWidth` x `Knob::preferredHeight`.
// - Drag up or down to change it; hold Option (Alt) for fine control.
// - Use the arrow keys when it has focus. Scrolling over it doesn't change the value, so a
//   scrolling view still scrolls; call `knob.slider.setScrollWheelEnabled (true)` to opt in.
// - Double-click resets to the default (a SliderAttachment sets the default for you).
// - Click the value to type one. Return or clicking away commits, Escape cancels. Units in the text
//   are accepted when the parameter's text-to-value function accepts them; out-of-range values clamp,
//   and text with no number leaves the value unchanged.
//
// Draws with VoltaLookAndFeel: the arc shows the value and bipolar ranges fill from the centre.

#pragma once

#include "VoltaLookAndFeel.h"

namespace volta
{

class Knob : public juce::Component
{
public:
    static constexpr int preferredWidth  = 76;
    static constexpr int preferredHeight = 14 + 4 + (int) VOLTA_SIZE_KNOB + 4 + 18;

    /// The parameter control. Attach it to a parameter; don't change its style.
    class Dial : public juce::Slider
    {
    public:
        Dial() : juce::Slider (RotaryVerticalDrag, TextBoxBelow)
        {
            setTextBoxIsEditable (true);
            setScrollWheelEnabled (false);   // opt in per knob; see the header comment
            setRepaintsOnMouseActivity (true);
            setWantsKeyboardFocus (true);
            // Holding Option switches to velocity mode at a low sensitivity: fine adjustment.
            setVelocityModeParameters (0.15, 1, 0.0, true, juce::ModifierKeys::altModifier);
        }

        bool keyPressed (const juce::KeyPress& key) override
        {
            const auto code = key.getKeyCode();
            const int direction = (code == juce::KeyPress::upKey || code == juce::KeyPress::rightKey) ? 1
                                : (code == juce::KeyPress::downKey || code == juce::KeyPress::leftKey) ? -1 : 0;
            if (direction == 0)
                return juce::Slider::keyPressed (key);

            // One step per press, or 1% of the travel when the parameter has no step.
            const auto normalised = valueToProportionOfLength (getValue());
            const auto interval = getInterval();
            if (interval > 0.0)
                setValue (getValue() + direction * interval, juce::sendNotificationSync);
            else
                setValue (proportionOfLengthToValue (juce::jlimit (0.0, 1.0, normalised + direction * 0.01)),
                          juce::sendNotificationSync);
            return true;
        }
    };

    Dial slider;

    explicit Knob (const juce::String& name)
    {
        nameLabel.setText (name, juce::dontSendNotification);
        nameLabel.setJustificationType (juce::Justification::centred);
        nameLabel.setInterceptsMouseClicks (false, false);
        addAndMakeVisible (nameLabel);

        slider.setTitle (name);
        slider.setTextBoxStyle (juce::Slider::TextBoxBelow, false, preferredWidth, 18);
        slider.setTooltip ("Click the value to type one");
        addAndMakeVisible (slider);
    }

    void resized() override
    {
        auto area = getLocalBounds();
        nameLabel.setBounds (area.removeFromTop (14));
        area.removeFromTop (4);
        slider.setBounds (area);
    }

    void lookAndFeelChanged() override
    {
        if (auto* laf = dynamic_cast<VoltaLookAndFeel*> (&getLookAndFeel()))
        {
            nameLabel.setFont (laf->labelFont());
            nameLabel.setColour (juce::Label::textColourId, laf->palette().secondary);
        }
    }

    void parentHierarchyChanged() override { lookAndFeelChanged(); }

private:
    juce::Label nameLabel;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR (Knob)
};

} // namespace volta
