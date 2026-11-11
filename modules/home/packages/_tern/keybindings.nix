{
  lib,
  primary,
  prefix,
  isDarwin,
}:
let
  bind = key: action: lib.nameValuePair "${primary}+${key}" action;
  sequence = key: action: lib.nameValuePair "${prefix}>${key}" action;
  directions = [
    "left"
    "right"
    "up"
    "down"
  ];
  digits = lib.range 1 9;
  tabAction = n: if n == 9 then "last_tab" else "goto_tab:${toString n}";
in
builtins.listToAttrs (
  [
    (bind "bracket_left" "split_right")
    (bind "bracket_right" "split_down")
    (bind "key_t" "new_tab")
    (sequence "bracket_left" "previous_pane")
    (sequence "bracket_right" "next_pane")
    (sequence "," "previous_tab")
    (sequence "." "next_tab")
    (sequence "k" [
      "reply_start"
      "previous_prompt"
    ])
    (sequence "j" "next_prompt")
    (sequence "b" "browser.back")
    (sequence "f" "browser.forward")
    (sequence "p" "park_pane")
    (sequence "u" "parked_panes")
    (sequence "s" "switch_session")
    (sequence "t" "new_shell_block")
  ]
  ++ map (dir: bind dir "focus_pane:${dir}") directions
  ++ map (dir: sequence dir "resize_split:${dir}") directions
  ++ map (n: bind "digit_${toString n}" (tabAction n)) digits
  # Keep the physical Ctrl+Shift digit aliases from the WezTerm configuration.
  ++ lib.optionals isDarwin (
    map (n: lib.nameValuePair "ctrl+shift+digit_${toString n}" (tabAction n)) digits
  )
)
