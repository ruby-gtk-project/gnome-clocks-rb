# frozen_string_literal: true

require_relative "main"

# The gem's namespace. The port itself is written as top-level classes, one per
# upstream source file, the way the pilot port is; this module is what the
# launcher in exe/ reaches them through.
module GnomeClocks
  Application = ::App
end
