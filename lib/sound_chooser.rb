# frozen_string_literal: true

require 'adwaita'
require_relative 'sound'
require_relative 'sound_chooser_row'
require_relative 'utils'

# SoundChooser is the "Alarm Sound" page: a Silent row, then one row per
# bundled alarm sound, where activating a row previews it and selects it as
# the alarm's current sound.
#
# Ported from Clocks.SoundChooser in src/sound-chooser.vala and
# data/ui/sound-chooser.ui. Upstream is an Adw.NavigationPage itself; this
# port, like the rest of this codebase's dialogs, builds the page's content
# as a plain widget tree and leaves wrapping it in an
# Adwaita::NavigationPage to whoever pushes it (AlarmSetupDialog), the way
# Window#push_standalone already wraps WorldStandalone.
#
# The silent sound has no bundled file — upstream ships it as a GResource
# that has no on-disk path, which this port does not bundle — so its Sound
# is built from a uri that never resolves to a real file, and #ring_bell
# only plays a sound whose uri differs from SILENT_SOUND_URI, exactly as
# upstream's own check does.
#
# Upstream only rings the bell from `row_activated`; its `sound` property
# setter is a plain GObject property with no override, so loading an alarm's
# existing sound into the dialog (AlarmSetupDialog#set_from_alarm) never
# previews it. #sound= mirrors that: it sets the value and updates the rows
# without touching the bell, and only #row_activated's own path rings one.
class SoundChooser < Adwaita::Bin
  SILENT_SOUND_URI = 'resource:///org/gnome/clocks/sounds/silent'

  def initialize(model)
    super()
    @model = model
    @sound = nil
    @bell = nil
    @sound_listeners = []
    @rows = {}
  end

  attr_reader :sound

  def silent_sound = @silent_sound ||= Sound.new(Gio::File.new_for_uri(SILENT_SOUND_URI), 'Silent')

  def sound=(value)
    unless value == @sound
      @sound = value
      update_rows
      @sound_listeners.each { |listener| listener.call(value) }
    end
  end

  def on_sound_changed(&block)
    @sound_listeners << block
    self
  end

  # Upstream's `hiding`/`notify::parent` handlers: leaving the page stops
  # whatever preview was ringing.
  def stop_preview
    stop_bell
    update_rows
    self
  end

  def build
    tap do |chooser|
      chooser.child = toolbar_view

      toolbar_view.tap do |view|
        view.add_top_bar(header_bar)
        view.content = preferences_page
      end

      preferences_page.tap do |page|
        page.add(silent_group)
        page.add(sound_group)

        silent_group.add(silent_row.build)
        @model.each { |item| sound_group.add(row_for(item).build) }
      end

      silent_row.signal_connect('activated') { row_activated(silent_row) }
      @rows.each_value { |row| row.signal_connect('activated') { row_activated(row) } }

      update_rows
    end
  end

  # Memoized widget methods

  def toolbar_view = @toolbar_view ||= Adwaita::ToolbarView.new
  def header_bar = @header_bar ||= Adwaita::HeaderBar.new
  def preferences_page = @preferences_page ||= Adwaita::PreferencesPage.new
  def silent_group = @silent_group ||= Adwaita::PreferencesGroup.new
  def sound_group = @sound_group ||= Adwaita::PreferencesGroup.new

  def silent_row = @silent_row ||= SoundChooserRow.new(silent_sound)

  # Upstream's model.find_by_file, reached through the SoundChooser's own
  # AlarmSoundModel the same way SetupDialog's set_from_alarm does.
  def find_by_file(file) = @model.find_by_file(file)

  private

    def row_for(item)
      @rows[item] ||= SoundChooserRow.new(item)
    end

    def row_activated(row)
      if @sound == row.sound
        # Toggle ringing the already-selected sound.
        ring_bell unless stop_bell
      else
        self.sound = row.sound
        stop_bell
        ring_bell
      end
      update_rows
    end

    def ring_bell
      @bell = Utils::Bell.new(sound.file.path).tap(&:ring) if sound && sound.uri != SILENT_SOUND_URI
    end

    def stop_bell
      if @bell
        @bell.stop
        @bell = nil
        true
      else
        false
      end
    end

    def update_rows
      silent_row.selected = (sound == silent_sound)
      silent_row.ringing = silent_row.selected? && !@bell.nil?
      @rows.each_value do |row|
        row.selected = (sound == row.sound)
        row.ringing = row.selected? && !@bell.nil?
      end
      self
    end
end
