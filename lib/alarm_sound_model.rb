# frozen_string_literal: true

require 'gio2'
require_relative 'sound'

# AlarmSoundModel is the sorted list of alarm sounds the sound chooser shows,
# built once as the labelled files in data/sounds/alarms plus the built-in
# fallback.
#
# Ported from Clocks.Alarm.SoundModel in src/alarm-sound-model.vala. Upstream
# implements GListModel over a GLib.ListStore; this port keeps a plain Ruby
# array instead, the way ContentStore in lib/widgets.rb does, and the sound
# chooser enumerates it directly.
#
# The bundled files below are upstream's own data/sounds/alarms/*.flac,
# copied in from origin/master (git ls-tree -r --name-only origin/master --
# data/sounds/alarms) now that AlarmSetupDialog's sound chooser is the first
# thing in this port to actually open them — an earlier round of this file
# named them `.oga`, which built a Sound for a file that never existed on
# disk, warning once per bundled sound every time this class was built.
class AlarmSoundModel
  include Enumerable

  # Upstream's construct: one Sound per bundled alarm file, translators'
  # names included, sorted by label with strcmp.
  #
  # Translators: An alarm sound name
  NAMES = {
    'bird' => 'Bird',
    'bonfire' => 'Bonfire',
    'boudoir' => 'Boudoir',
    'bouncing' => 'Bouncing',
    'cautious-steps' => 'Cautious Steps',
    'chirping' => 'Chirping',
    'class-act' => 'Class Act',
    'crossing-bell' => 'Crossing Bell',
    'daydreaming' => 'Daydreaming',
    'digitone' => 'Digitone',
    'enchanting' => 'Enchanting',
    'glass-bell' => 'Glass Bell',
    'guitar' => 'Guitar',
    'jolly' => 'Jolly',
    'mystery' => 'Mystery',
    'ping-ping' => 'Ping Ping',
    'school-bell' => 'School Bell',
    'sonar' => 'Sonar',
    'sparkling' => 'Sparkling',
    'tingling' => 'Tingling',
    'toys' => 'Toys',
  }.freeze

  # Where the bundled alarm sounds live: data/sounds/alarms next to this
  # gem's lib directory, mirroring upstream's Config.DATADIR/sounds/gnome/default/alarms.
  def self.alarms_dir = File.expand_path('../data/sounds/alarms', __dir__)

  def self.build_default_file = Gio::File.new_for_path(File.join(alarms_dir, 'toys.flac'))

  # Prior to 50 alarms only used the "alarm-clock-elapsed" sound; beep-beep
  # is the same sound without the forced repetition, and is the one shipped
  # outside the alarms directory so it always exists even without the rest.
  def self.build_fallback_file = Gio::File.new_for_path(File.join(alarms_dir, 'beep-beep.flac'))

  def initialize
    @sounds = [Sound.new(self.class.build_fallback_file, 'Beep-Beep')] +
              NAMES.map { |file, label| Sound.new(Gio::File.new_for_path(File.join(self.class.alarms_dir, "#{file}.flac")), label) }
    @sounds.sort_by!(&:label)
  end

  def each(&) = @sounds.each(&)
  def length = @sounds.length

  # Upstream compares with GFile.equal, which is content equality rather
  # than object identity; the uri is that same comparison in this binding.
  def find_by_file(file)
    @sounds.find { |sound| sound.uri == file.uri }
  end
end
