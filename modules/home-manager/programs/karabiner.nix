{ config, lib, pkgs, ... }:

let
  inherit (lib) mkEnableOption mkIf mkOption types;

  cfg = config.ddd.programs.karabiner;

  inherit (cfg) modifier;

  variable = "SpaceFn";

  swap = x: y: [ (fromTo x y) (fromTo y x) ];

  fromTo = from: to: {
    from = { key_code = from; };
    to = [{ key_code = to; }];
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

  launchApp = modifiers: key_code:
    fromToShellCommand {
      inherit key_code;
      modifiers = { mandatory = modifiers; };
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
        simultaneous = [{ key_code = modifier; } { key_code = from; }];
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
    profiles = [ defaultProfile customProfile ];
  };

  defaultProfile = {
    name = "Default profile";
    selected = false;
    virtual_hid_keyboard = {
      country_code = 0;
      keyboard_type_v2 = "ansi";
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
        (mkRule "Start terminal" [
          (launchApp [ "left_option" ] "return_or_enter"
            "open -n ${config.ddd.programs.wezterm.package}/Applications/WezTerm.app")
        ])
      ];
    };
    devices = [ appleInternalKeyboardIso ];
    selected = true;
  };

  deviceDefaults = {
    identifiers = {
      is_keyboard = true;
    };
    manipulate_caps_lock_led = true;
    simple_modifications = [ ];
  };

  appleInternalKeyboardIso = lib.recursiveUpdate deviceDefaults {
    identifiers = {
      product_id = 835;
      vendor_id = 1452;
    };
    simple_modifications = lib.flatten [
      (swap "non_us_backslash" "grave_accent_and_tilde")
    ];
  };

in
{
  options.ddd.programs.karabiner = {
    enable = mkEnableOption "karabiner";

    modifier = mkOption {
      type = types.str;
      default = "spacebar";
    };
  };

  config = mkIf cfg.enable {
    xdg.configFile."karabiner/karabiner.json".text =
      builtins.toJSON karabinerConfig;
  };
}
