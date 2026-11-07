# frozen_string_literal: true

require 'gio2'

# Sound is one alarm sound: the file it plays and the label it shows in the
# sound chooser.
#
# Ported from Clocks.Sound in src/sound.vala.
class Sound
  def initialize(file, label)
    @file = file
    @label = label
    warn "Sound file '#{uri}' not found." unless file.query_exists
  end

  attr_reader :file, :label

  def uri = @uri ||= file.uri
end
