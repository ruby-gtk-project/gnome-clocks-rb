# frozen_string_literal: true

require 'adwaita'
require_relative 'sound'

# SoundChooserRow is one row of the sound chooser: the sound's label, a
# pause icon while it previews, and a checkmark while it is the alarm's
# current sound.
#
# Ported from Clocks.SoundChooserRow in src/sound-chooser-row.vala and
# data/ui/sound-chooser-row.ui. Upstream's `ringing`/`selected` properties
# drive two bound GtkImage visibilities and an accessible state update
# through Gtk.AccessibleState; `update_state`/`reset_state` have no
# equivalent in this binding, so this port leaves the accessible state
# alone and keeps the two images in sync by hand instead.
class SoundChooserRow < Adwaita::ActionRow
  def initialize(sound)
    super()
    @sound = sound
    self.title = sound.label
    self.activatable = true
  end

  attr_reader :sound

  def build
    tap do |row|
      row.add_prefix(pause_image)
      row.add_suffix(checkmark_image)
    end
  end

  def ringing? = @ringing || false

  def ringing=(value)
    @ringing = value
    pause_image.visible = value
  end

  def selected? = @selected || false

  def selected=(value)
    @selected = value
    checkmark_image.visible = value
  end

  # Memoized widget methods

  def pause_image
    @pause_image ||= Gtk::Image.new(icon_name: 'media-playback-pause-symbolic').tap { |image| image.visible = false }
  end

  def checkmark_image
    @checkmark_image ||= Gtk::Image.new(icon_name: 'object-select-symbolic').tap { |image| image.visible = false }
  end
end
