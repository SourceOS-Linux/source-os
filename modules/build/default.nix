{ lib, config, ... }:
{
  options.sourceos.build = {
    role = lib.mkOption {
      type = lib.types.str;
      default = "generic-builder";
      description = "Logical build role for the realized SourceOS host.";
    };

    channel = lib.mkOption {
      type = lib.types.enum [ "dev" "candidate" "stable" ];
      default = "dev";
      description = "Shared control-plane channel realized by this host profile.";
    };
  };

  config = {
    assertions = [
      {
        assertion = builtins.elem config.sourceos.build.channel [ "dev" "candidate" "stable" ];
        message = "sourceos.build.channel must be one of dev, candidate, or stable.";
      }
    ];
  };
}
