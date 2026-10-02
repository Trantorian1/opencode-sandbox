{
  pkgs,
  lib,
  ...
}: let
  modules = lib.evalModules {
    modules = [../module/options.nix];
    specialArgs = {inherit pkgs;};
  };

  isPackage = value:
    value ? type
    && value ? pname
    && value.type == "derivation";

  packageName = value:
    if isPackage value
    then "pkgs.${value.pname}"
    else value;

  humanReadable = default:
    if builtins.isList default
    then "[${lib.concatStringsSep " " (builtins.map packageName default)}]"
    else let
      value = packageName default;
    in
      if builtins.isBool value
      then lib.boolToString value
      else builtins.toString value;

  optionInfo = option:
    {
      description = option.description;
      type = option.type.description;
    }
    // lib.optionalAttrs (option ? default) {default = humanReadable option.default;}
    // lib.optionalAttrs (option ? example) {example = option.example;};

  flatten = path: options:
    builtins.concatMap (option: let
      value = options.${option};
      name =
        if path == ""
        then option
        else "${path}.${option}";
    in
      if value ? internal && value.internal == true
      then []
      else let
        children =
          if value.type.name == "submodule"
          then flatten name (builtins.removeAttrs value.valueMeta.configuration.options ["_module"])
          else [];
      in
        [(lib.nameValuePair name (optionInfo value))] ++ children)
    (builtins.attrNames options);

  options = lib.listToAttrs (flatten "" modules.options.opencode-sandbox);

  renderDefault = default:
    if builtins.length (lib.splitString "\n" default) > 1
    then ''

      _default_:
      ```
      ${default}
      ```''
    else ''

      _default_: `${default}`'';

  renderExample = name: example: let
    lines = lib.splitString "\n" example;
    value =
      if lib.tail lines == []
      then lib.head lines
      else "${lib.head lines}\n${lib.concatStringsSep "\n" (builtins.map (l: "  " + l) (lib.tail lines))}";
  in ''

    ### Example

    ```nix
    opencode-sandbox = {
      ${name} = ${value};
    };
    ```
  '';

  renderOption = name: info: ''
    ## `${name}`

    _type_: `${info.type}`${lib.optionalString (info ? default) (renderDefault info.default)}

    ${info.description}${lib.optionalString (info ? example) (renderExample name info.example)}'';

  md = lib.concatMapStringsSep "\n" (name: renderOption name options.${name}) (builtins.attrNames options);
in
  pkgs.writeText "docs.md" md
