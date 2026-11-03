# frozen_string_literal: true

require 'adwaita'
require_relative 'clock'

# ShortcutsDialog lists the keyboard shortcuts.
#
# Ported from data/ui/shortcuts-dialog.ui: an Adw.ShortcutsDialog with a
# General section and one section per panel. Items that name an action show
# whatever accelerator the application set for it; the rest carry their
# accelerator directly, as upstream's do.
#
# The dialog is built from the panels the window actually has, so the panel
# sections and the General section's Alt+N rows list the panels on screen
# rather than a fixed four.
#
class ShortcutsDialog < Adwaita::ShortcutsDialog
  # Upstream's General section, in its order. An item is [title, accelerator,
  # action name]; exactly one of the last two is set, as in the .ui file.
  GENERAL_ITEMS = [
    ['Show Help', nil, 'win.help'],
    ['Open Menu', 'F10', nil],
    ['Keyboard Shortcuts', nil, 'app.shortcuts'],
    ['Quit', nil, 'app.quit'],
    ['Go to the Next Section', nil, 'win.navigate-forward'],
    ['Go to the Previous Section', nil, 'win.navigate-backward'],
  ].freeze

  # The Alt+N row for each panel, and the section upstream gives it.
  PANEL_SECTIONS = {
    PanelId::WORLD     => ['Go to the World Section', 'World Clocks',
                           [['Add a World Clock', nil, 'win.new']],],
    PanelId::ALARM     => ['Go to the Alarms Section', 'Alarm',
                           [['Add an Alarm', nil, 'win.new']],],
    PanelId::STOPWATCH => ['Go to the Stopwatch Section', 'Stopwatch',
                           [['Pause All', 'Escape', nil]],],
    PanelId::TIMER     => ['Go to the Timer Section', 'Timer',
                           [['Reset', 'Escape', nil], ['New Timer', nil, 'win.new']],],
  }.freeze

  def initialize(panel_ids)
    super()
    @panel_ids = Array(panel_ids)
    self.title = 'Keyboard Shortcuts'
  end

  attr_reader :panel_ids

  def build
    tap do |dialog|
      dialog.add(general_section)
      @panel_ids.each { |panel_id| dialog.add(panel_section(panel_id)) }
    end
  end

  # Memoized widget methods

  def general_section
    @general_section ||= section('General', GENERAL_ITEMS + panel_navigation_items)
  end

  def panel_section(panel_id)
    PANEL_SECTIONS.fetch(panel_id).then { |_row, title, items| section(title, items) }
  end

  private

    # The Alt+1 … Alt+4 rows, numbered by the panel's place in PanelId::ALL so
    # a panel keeps its own accelerator whichever panels are present.
    def panel_navigation_items
      @panel_ids.map do |panel_id|
        [PANEL_SECTIONS.fetch(panel_id).first, "<alt>#{PanelId.index(panel_id) + 1}", nil]
      end
    end

    def section(title, items)
      Adwaita::ShortcutsSection.new.tap do |group|
        group.title = title
        items.each { |item_title, accelerator, action| group.add(item(item_title, accelerator, action)) }
      end
    end

    # Positional, not keyword, arguments, and an accelerator of '' rather than
    # nil: the Ruby binding rejects both keywords and a nil accelerator.
    def item(title, accelerator, action)
      Adwaita::ShortcutsItem.new(title, accelerator.to_s).tap do |shortcut|
        shortcut.action_name = action if action
      end
    end
end
