# frozen_string_literal: true

require 'adwaita'
require_relative 'clock'
require_relative 'settings'
require_relative 'utils'
require_relative 'header_bar'
require_relative 'shortcuts_dialog'
require_relative 'alarm_face'
require_relative 'stopwatch_face'
require_relative 'timer_face'
require_relative 'world_face'
require_relative 'world_standalone'

# Window is the application window: a navigation view whose main page carries
# the header bar, the view stack of panels and the view switcher bar, with the
# toast overlay over all of it.
#
# Ported from Clocks.Window in src/window.vala and data/ui/window.ui.
#
# The panel list is a constant, so a panel arriving later is added in one
# place, and everything keyed off it — the view stack pages, the Alt+N
# accelerators, the shortcuts dialog's sections, navigate-forward and the
# restored panel — follows from it.
#
class Window < Adwaita::ApplicationWindow
  NARROW_CONDITION = 'max-width: 600sp'

  # The window actions of upstream's ACTION_ENTRIES, and the accelerators
  # upstream's Application.startup sets for them.
  ACTIONS = {
    'new'                => ['<Control>n'],
    'help'               => ['F1'],
    'navigate-forward'   => ['<Control><Alt>Page_Down'],
    'navigate-backward'  => ['<Control><Alt>Page_Up'],
    'about'              => [],
  }.freeze

  # Each panel's view stack page: its title, with upstream's mnemonic, and its
  # icon.
  PANELS = {
    PanelId::WORLD     => ['_World', 'world-clocks-symbolic', WorldFace],
    PanelId::ALARM     => ['_Alarm', 'alarm-symbolic', AlarmFace],
    PanelId::STOPWATCH => ['_Stopwatch', 'stopwatch-symbolic', StopwatchFace],
    PanelId::TIMER     => ['_Timer', 'timer-symbolic', TimerFace],
  }.freeze

  COPYRIGHT = "© 2011 Collabora Ltd.\n" \
              "© 2012-2013 Collabora Ltd., Seif Lotfy, Emily Gonyer, " \
              "Eslam Mostafa, Paolo Borelli, Volker Sobek\n" \
              '© 2019-2020 Bilal Elmoussaoui & Zander Brown et al'

  DEVELOPERS = [
    'Alex Anthony', 'Paolo Borelli', 'Allan Day', 'Piotr Drąg', 'Emily Gonyer',
    'Evgeny Bobkin', 'Maël Lavault', 'Seif Lotfy', 'William Jon McCann',
    'Eslam Mostafa', 'Bastien Nocera', 'Volker Sobek', 'Jakub Steiner',
    'Bilal Elmoussaoui', 'Zander Brown',
  ].freeze

  HELP_URI = 'help:gnome-clocks'
  ISSUE_URL = 'https://gitlab.gnome.org/GNOME/gnome-clocks/-/issues/'

  def initialize(app, settings: nil, version: nil)
    super(app)
    @settings = settings || Settings.new
    @version = version
    self.title = 'Clocks'
    self.hide_on_close = true
    self.width_request = 360
    self.height_request = 294
  end

  attr_reader :settings, :panels

  def build
    tap do |window|
      window.content = toast_overlay
      window.add_breakpoint(narrow_breakpoint)
      window.add_controller(key_controller)
      window.add_controller(panel_shortcuts)

      toast_overlay.child = navigation_view
      navigation_view.add(main_page)
      main_toolbar_view.tap do |view|
        view.add_top_bar(header_bar.build)
        view.content = stack
        view.add_bottom_bar(switcher_bar)
      end

      stack.tap do |view_stack|
        PANELS.each do |panel_id, (title, icon_name, _klass)|
          view_stack.add_titled_with_icon(panel(panel_id).build, panel_id.to_s, title, icon_name)
                    .tap { |page| page.use_underline = true }
        end
        view_stack.signal_connect('notify::visible-child') { pane_changed }
      end

      navigation_view.signal_connect('notify::visible-page') { visible_page_changed }
      window.signal_connect('notify::is-active') { on_window_active }
      window.signal_connect('close-request') { save_window_state.then { false } }

      install_actions
      watch_panels

      # GSettings gives us the nick, which matches the stack page name.
      stack.visible_child_name = restored_panel.to_s

      pane_changed
      @settings.apply_to(window)
    end
  end

  # Upstream's add_toast, which the alarm panel's toast travels through.
  def add_toast(toast)
    toast_overlay.add_toast(toast)
    self
  end

  # Upstream's show_world: back out of any subpage and show a given panel.
  def show_panel(panel_id)
    close_standalone
    stack.visible_child_name = panel_id.to_s
    self
  end

  def visible_panel = panel(PanelId::ALL.find { |panel_id| panel_id.to_s == stack.visible_child_name })

  # Memoized widget methods

  def toast_overlay = @toast_overlay ||= Adwaita::ToastOverlay.new
  def navigation_view = @navigation_view ||= Adwaita::NavigationView.new

  def main_page = @main_page ||= Adwaita::NavigationPage.new(main_toolbar_view, 'Clocks')
  def main_toolbar_view = @main_toolbar_view ||= Adwaita::ToolbarView.new

  def stack
    @stack ||= Adwaita::ViewStack.new.tap do |view_stack|
      view_stack.hexpand = true
      view_stack.vexpand = true
    end
  end

  def header_bar = @header_bar ||= HeaderBar.new(stack: stack, switcher_bar: switcher_bar)

  def switcher_bar = @switcher_bar ||= Adwaita::ViewSwitcherBar.new

  # One instance per panel, built once and kept, so the panel keeps its state
  # while the user switches away from it and back.
  #
  # Every panel that persists anything (World and Timer, so far) is handed
  # this window's own Settings instance rather than building a default one
  # of its own. Settings#[]= rewrites the whole JSON file from its instance's
  # in-memory copy, so two panels each holding a separate Settings object
  # would each overwrite the other's key with its own stale snapshot on every
  # save — World adding a clock would silently erase whatever Timer had just
  # written, and vice versa.
  def panel(panel_id)
    panels[panel_id] ||= build_panel(PANELS.fetch(panel_id).last)
  end

  def panels = @panels ||= {}

  # Upstream's breakpoint: under 600sp the view switcher moves out of the
  # header bar and into the bottom bar.
  #
  # Only the first setter goes through Adw.Breakpoint's own add_setter:
  # `switcher_bar` is a real Gtk::Widget with a GObject `reveal-child`-style
  # boolean property add_setter can box into a GValue. `header_bar` is this
  # port's own HeaderBar class, which has no GObject `title-widget` property
  # of its own (only the plain Ruby accessor below) — add_setter asserts
  # trying to box that, and a nil target would not box into a GValue either
  # way. The swap happens by hand on apply/unapply instead, the way
  # WorldStandalone's own breakpoint already works around the same gap.
  def narrow_breakpoint
    @narrow_breakpoint ||= Adwaita::Breakpoint.new(
      Adwaita::BreakpointCondition.parse(NARROW_CONDITION),
    ).tap do |breakpoint|
      breakpoint.add_setter(switcher_bar, 'reveal', true)
      breakpoint.signal_connect('apply') { header_bar.title_widget = nil }
      breakpoint.signal_connect('unapply') { header_bar.title_widget = header_bar.view_switcher }
    end
  end

  def key_controller
    @key_controller ||= Gtk::EventControllerKey.new.tap do |controller|
      controller.signal_connect('key-pressed') do |_controller, keyval, _keycode, state|
        key_pressed(keyval, state)
      end
    end
  end

  # Upstream installs a `set-page` widget action and binds Alt+1 … Alt+4 to it
  # with the page name as the argument. The Ruby bindings have no
  # add_binding_action, so the same four accelerators arrive through a
  # shortcut controller.
  def panel_shortcuts
    @panel_shortcuts ||= Gtk::ShortcutController.new.tap do |controller|
      controller.scope = :global
      PANELS.each_key do |panel_id|
        controller.add_shortcut(
          Gtk::Shortcut.new(
            Gtk::KeyvalTrigger.new(Gdk::Keyval.const_get(:"KEY_#{PanelId.index(panel_id) + 1}"), :alt_mask),
            Gtk::CallbackAction.new { show_panel(panel_id).then { true } },
          ),
        )
      end
    end
  end

  def shortcuts_dialog = ShortcutsDialog.new(PANELS.keys).build

  def about_dialog
    Adwaita::AboutDialog.new.tap do |about|
      about.application_name = 'Clocks'
      about.application_icon = 'org.rubygtkproject.GnomeClocks'
      about.developer_name = 'The GNOME Project'
      about.version = @version.to_s
      about.copyright = COPYRIGHT
      about.developers = DEVELOPERS
      about.issue_url = ISSUE_URL
      about.license_type = Gtk::License::GPL_2_0
    end
  end

  private

    def install_actions
      ACTIONS.each_key do |name|
        add_action(
          Gio::SimpleAction.new(name).tap do |action|
            action.signal_connect('activate') { activate_window_action(name) }
          end,
        )
      end
      self
    end

    def activate_window_action(name)
      case name
      when 'new' then visible_panel.activate_new
      when 'help' then show_help
      when 'about' then about_dialog.present(self)
      when 'navigate-forward' then navigate(PanelId.method(:after))
      when 'navigate-backward' then navigate(PanelId.method(:before))
      end
    end

    # Upstream walks the four panels in a loop; this walks the panels the
    # window has, in the same order.
    def navigate(step)
      next_available(visible_panel.panel_id, step).then { |panel_id| show_panel(panel_id) }
    end

    # The next panel the window actually has, following upstream's order: step
    # along PanelId::ALL until a panel other than the current one turns up,
    # which takes at most one full lap.
    def next_available(current, step)
      PanelId::ALL.length.times.reduce(current) do |panel_id, _index|
        if PANELS.key?(panel_id) && panel_id != current
          panel_id
        else
          step.call(panel_id)
        end
      end
    end

    # Upstream's key_press_cb: Escape is offered to the panel while the main
    # page is up, and pops the navigation view otherwise.
    def key_pressed(keyval, state)
      (state & (Gdk::ModifierType::CONTROL_MASK | Gdk::ModifierType::ALT_MASK)).then do |modifiers|
        if keyval == Gdk::Keyval::KEY_Escape && modifiers.to_i.zero?
          escape_pressed
        else
          false
        end
      end
    end

    def escape_pressed
      if navigation_view.visible_page == main_page
        visible_panel.escape_pressed
      else
        navigation_view.pop
        true
      end
    end

    # Upstream's pane_changed: record the panel, point the header bar at it,
    # and give it the focus.
    def pane_changed
      visible_panel.then do |panel|
        if panel
          @settings['panel-id'] = panel.panel_id.to_s
          header_bar.new_label = panel.new_label
          panel.on_button_mode_changed { |mode| header_bar.button_mode = mode }
          panel.grab_focus_start
        end
      end
      self
    end

    # Upstream's visible_page_changed: the title follows the subpage, and a
    # ringing alarm's page cannot be closed out from under the user.
    def visible_page_changed
      self.title = navigation_view.visible_page == main_page ? 'Clocks' : navigation_view.visible_page.title
      self.deletable = navigation_view.visible_page == main_page
      self
    end

    # Upstream puts the needs-attention dot on a panel's page while its
    # stopwatch runs or its timer counts down.
    def watch_panels
      panel(PanelId::WORLD).on_show_standalone { |item| push_standalone(item) }
      panel(PanelId::STOPWATCH).on_state_changed do |state|
        needs_attention(PanelId::STOPWATCH, state == StopwatchFace::RUNNING)
      end
      panel(PanelId::TIMER).on_is_running_changed do |running|
        needs_attention(PanelId::TIMER, running)
      end
      self
    end

    # Upstream's show_standalone: activating a world clock's row pushes a
    # subpage with the big clock face for that one location.
    def push_standalone(item)
      navigation_view.push(
        Adwaita::NavigationPage.new(WorldStandalone.new(item).build, item.city_name),
      )
      self
    end

    def needs_attention(panel_id, value)
      stack.get_page(panel(panel_id)).needs_attention = value
    end

    def close_standalone
      navigation_view.pop
      self
    end

    def build_panel(klass)
      klass.instance_method(:initialize).parameters.any? { |_type, name| name == :settings } ? klass.new(settings: @settings) : klass.new
    end

    def restored_panel
      @settings['panel-id'].to_sym.then do |panel_id|
        PANELS.key?(panel_id) ? panel_id : PANELS.keys.first
      end
    end

    def save_window_state
      @settings.remember(self)
      self
    end

    # Upstream withdraws the notifications it sent as soon as the window has
    # the focus again, so a timer that rang while the window was hidden does
    # not leave a notification behind.
    def on_window_active
      Gio::Application.default.then { |app| app.withdraw_notifications if active? && app.respond_to?(:withdraw_notifications) }
      self
    end

    def show_help
      Gio::AppInfo.launch_default_for_uri(HELP_URI, display.app_launch_context)
    rescue GLib::Error => e
      warn "Could not open help: #{e.message}"
    end
end
