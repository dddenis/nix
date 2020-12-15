{ config, lib, pkgs, ... }:

let
  inherit (lib) mkEnableOption mkIf mkOption types;

  cfg = config.services.karabiner;

  inherit (cfg) modifier;

  variable = "SpaceFn";

  swap = x: y: [ (fromTo x y) (fromTo y x) ];

  fromTo = from: to: {
    from = { key_code = from; };
    to = { key_code = to; };
  };

  fromToConsumer = from: to: {
    from = { key_code = from; };
    to = { consumer_key_code = to; };
  };

  fromToShellCommand = from: to: {
    inherit from;
    to = [{ shell_command = to; }];
  };

  mkRule = description: manipulators: {
    inherit description;
    manipulators = map (m: { type = "basic"; } // m) manipulators;
  };

  whenPressed = from: to: to_if_alone: {
    from = {
      key_code = from;
      modifiers = { optional = [ "any" ]; };
    };
    to = [{ key_code = to; }];
    to_if_alone = [{ key_code = to_if_alone; }];
  };

  launchApp = key_code:
    fromToShellCommand {
      inherit key_code;
      modifiers = { mandatory = [ "left_option" "left_shift" ]; };
    };

  setVariable = name: value: { set_variable = { inherit name value; }; };

  mapWithModifier = from: to: modifier: variable: [
    {
      conditions = [{
        name = variable;
        type = "variable_if";
        value = 1;
      }];
      from = {
        key_code = from;
        modifiers = { optional = [ "any" ]; };
      };
      to = [{ key_code = to; }];
    }
    {
      from = {
        simultaneous = [ { key_code = modifier; } { key_code = from; } ];
        simultaneous_options = {
          key_down_order = "strict";
          key_up_order = "strict_inverse";
          to_after_key_up = [ (setVariable variable 0) ];
        };
        modifiers = { optional = [ "any" ]; };
      };
      to = [ (setVariable variable 1) { key_code = to; } ];
      parameters = { "basic.simultaneous_threshold_milliseconds" = 500; };
    }
  ];

  karabinerConfig = {
    global = {
      check_for_updates_on_startup = true;
      show_in_menu_bar = true;
      show_profile_name_in_menu_bar = false;
    };
    profiles = [ defaultProfile customProfile ];
  };

  defaultProfile = {
    name = "Default profile";
    complex_modifications = {
      parameters = {
        "basic.simultaneous_threshold_milliseconds" = 50;
        "basic.to_delayed_action_delay_milliseconds" = 500;
        "basic.to_if_alone_timeout_milliseconds" = 1000;
        "basic.to_if_held_down_threshold_milliseconds" = 500;
        "mouse_motion_to_scroll.speed" = 100;
      };
      rules = [ ];
    };
    devices = [ ];
    fn_function_keys = [
      (fromToConsumer "f1" "display_brightness_decrement")
      (fromToConsumer "f2" "display_brightness_increment")
      (fromTo "f3" "mission_control")
      (fromTo "f4" "launchpad")
      (fromTo "f5" "illumination_decrement")
      (fromTo "f6" "illumination_increment")
      (fromToConsumer "f7" "rewind")
      (fromToConsumer "f8" "play_or_pause")
      (fromToConsumer "f9" "fastforward")
      (fromToConsumer "f10" "mute")
      (fromToConsumer "f11" "volume_decrement")
      (fromToConsumer "f12" "volume_increment")
    ];
    parameters = { delay_milliseconds_before_open_device = 1000; };
    selected = false;
    simple_modifications = [ ];
    virtual_hid_keyboard = {
      country_code = 0;
      mouse_key_xy_scale = 100;
    };
  };

  customProfile = lib.recursiveUpdate defaultProfile {
    name = "Custom Profile";
    complex_modifications = {
      parameters = { "basic.to_if_alone_timeout_milliseconds" = 300; };
      rules = [
        (mkRule "SpaceFn Layer" (lib.flatten [
          (mapWithModifier "h" "left_arrow" modifier variable)
          (mapWithModifier "j" "down_arrow" modifier variable)
          (mapWithModifier "k" "up_arrow" modifier variable)
          (mapWithModifier "l" "right_arrow" modifier variable)
        ]))
        (mkRule "Caps to ctrl/esc"
          [ (whenPressed "caps_lock" "left_control" "escape") ])
        (mkRule "HHKB: Ctrl to esc"
          [ (whenPressed "left_control" "left_control" "escape") ])
        (mkRule "Launch Alacritty" [
          (launchApp "return_or_enter"
            "open -n ${pkgs.alacritty}/Applications/Alacritty.app")
        ])
        (mkRule "Launch Emacs"
          [ (launchApp "e" "open -n ${pkgs.emacs}/Applications/Emacs.app") ])
      ];
    };
    devices = [ hhkb ];
    selected = true;
  };

  deviceDefaults = {
    disable_built_in_keyboard_if_exists = false;
    fn_function_keys = [ ];
    identifiers = {
      is_keyboard = true;
      is_pointing_device = false;
    };
    ignore = false;
    manipulate_caps_lock_led = true;
    simple_modifications = [ ];
  };

  hhkb = lib.recursiveUpdate deviceDefaults {
    identifiers = {
      product_id = 32;
      vendor_id = 1278;
    };
    manipulate_caps_lock_led = false;
    simple_modifications = lib.flatten [
      (fromTo "escape" "grave_accent_and_tilde")
      (swap "left_option" "left_command")
    ];
  };

in {
  options.services.karabiner = {
    enable' = mkEnableOption "karabiner";

    modifier = mkOption {
      type = types.str;
      default = "spacebar";
    };
  };

  config = mkIf cfg.enable' {
    xdg.configFile."karabiner/karabiner.json".text =
      builtins.toJSON karabinerConfig;
  };
}
