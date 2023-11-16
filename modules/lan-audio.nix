let
  ports = {
    sap = 9875;
    rtp = 46454; # the port that the client blasts with udp audio
  };
in
{
  environment.etc."pipewire/pipewire.conf.d/rtp-source.conf".text = builtins.toJSON {
    "context.modules" = [
      {
        name = "libpipewire-module-rtp-sap";
        args = {
          # stream targeted directly at us, not a broadcast
          # (important, default is some udp broadcard ip)
          "sap.ip" = "0.0.0.0";
          # actually not important, default is 9875,
          # but here its explicit to match the port added to the firewall
          "sap.port" = ports.sap;
          # stream rules at https://docs.pipewire.org/page_module_rtp_sap.html
          # also matches default, but explicit just to see what it does
          "stream.rules" = [
            { matches = [{ "sess.sap.announce" = true; }]; actions = { announce-stream = { }; }; }
            # ~ prefix means regex
            { matches = [{ "rtp.session" = "~.*"; }]; actions = { create-stream = { }; }; }
          ];
        };
      }
    ];
  };

  networking.firewall.allowedUDPPorts = builtins.attrValues ports;
}
