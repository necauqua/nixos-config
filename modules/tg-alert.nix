{ config, pkgs, ... }: {

  secrets.tg-bot.mode = "644";

  environment.systemPackages = [
    (pkgs.writeShellApplication {
      name = "tg-alert";
      runtimeInputs = with pkgs; [ jq curl ];
      excludeShellChecks = [ "SC1091" "SC2154" ];
      text = ''
        source "${config.age.secrets.tg-bot.path}"
        message=$1
        curl -s "https://api.telegram.org/bot$token/sendMessage" \
          -d "chat_id=$chat" \
          -d "parse_mode=markdown" \
          --data-urlencode "text=$message"
      '';
    })
  ];
}
