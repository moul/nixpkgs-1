final: super: {
  myloon = super.pkgs.silicon.buildGo118Module rec {
    pname = "loon";
    version = "1.4.0";
    vendorSha256 = "sha256-GyBD1Wl7HFP1jwjUPh7mC8e6SS2ppSpAyZvo4XRjn/U=";
    src = super.pkgs.fetchurl {
      url = "https://github.com/gfanton/loon/archive/refs/tags/v${version}.tar.gz";
      sha256 = "sha256-7LXGI7qMhezc9fv40f1R3ALcU/eZxE7XgESsTsSwJV0=";
    };

    meta = with super.lib; {
      description = "dynamic realtime pager";
      maintainers = [ maintainers.gfanton ];
    };
  };
}
