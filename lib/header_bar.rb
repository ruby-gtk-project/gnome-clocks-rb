# frozen_string_literal: true

require 'adwaita'
require_relative 'clock'

# HeaderBar is the window's header bar: the view switcher in the middle, the
# panel's "new" button at the start, and the primary menu at the end.
#
# Ported from Clocks.HeaderBar in src/header-bar.vala and
# data/ui/header-bar.ui, including the primary menu that file defines and the
# start_button_stack that shows either the + button or nothing, depending on
# the panel's button mode.
#
class HeaderBar < Adwaita::Bin
  # The primary-menu section of data/ui/header-bar.ui.
  MENU_ITEMS = [
    ['_Keyboard Shortcuts', 'app.shortcuts'],
    ['_Help', 'win.help'],
    ['_About Clocks', 'win.about'],
  ].freeze

  def initialize(stack: nil, switcher_bar: nil)
    super()
    @stack = stack
    @switcher_bar = switcher_bar
    @button_mode = ButtonMode::NONE
  end

  attr_reader :stack, :switcher_bar, :button_mode, :new_label

  def build
    tap do |bin|
      bin.child = header_bar

      header_bar.tap do |bar|
        bar.title_widget = view_switcher
        bar.pack_start(start_button_stack)
        bar.pack_end(menu_button)

        start_button_stack.tap do |stack|
          stack.add_named(new_button, 'new')
          stack.add_named(Adwaita::Bin.new, 'empty')
        end
      end

      view_switcher.stack = @stack
      @switcher_bar&.stack = @stack

      self.button_mode = @button_mode
    end
  end

  # Upstream's button_mode property: NEW shows the + button, NONE shows an
  # empty page in its place.
  def button_mode=(mode)
    @button_mode = mode
    start_button_stack.visible_child_name = mode == ButtonMode::NEW ? 'new' : 'empty'
    mode
  end

  # Upstream binds the panel's new-label to the + button's tooltip.
  def new_label=(label)
    @new_label = label
    new_button.tooltip_text = label
    label
  end

  # Upstream's title_widget property, which the window's breakpoint clears so
  # the switcher moves down into the bottom bar on a narrow window.
  def title_widget = header_bar.title_widget

  def title_widget=(widget)
    header_bar.title_widget = widget
    widget
  end

  # Memoized widget methods

  def header_bar = @header_bar ||= Adwaita::HeaderBar.new

  def view_switcher
    @view_switcher ||= Adwaita::ViewSwitcher.new.tap { |switcher| switcher.policy = :wide }
  end

  def start_button_stack = @start_button_stack ||= Adwaita::ViewStack.new

  def new_button
    @new_button ||= Gtk::Button.new.tap do |button|
      button.action_name = 'win.new'
      button.icon_name = 'list-add-symbolic'
    end
  end

  def menu_button
    @menu_button ||= Gtk::MenuButton.new.tap do |button|
      button.menu_model = primary_menu
      button.icon_name = 'open-menu-symbolic'
      button.tooltip_text = 'Main Menu'
      button.primary = true
    end
  end

  def primary_menu
    @primary_menu ||= Gio::Menu.new.tap do |menu|
      Gio::Menu.new.tap do |section|
        MENU_ITEMS.each { |label, action| section.append(label, action) }
        menu.append_section(nil, section)
      end
    end
  end
end
