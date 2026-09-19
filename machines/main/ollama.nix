{ config, lib, pkgs, ... }:
let
  nvidia = lib.elem "nvidia" config.services.xserver.videoDrivers;
in
{
  services.ollama = {
    enable = true;
    package = pkgs.ollama-cuda;
    # /var/lib/ollama is a zfs dataset, dont do the whole `private` symlink thing with DynamicUser
    user = "ollama";

    environmentVariables = {
      # flash attention is required for a quantized KV cache, and it also cuts
      # the attention scratch buffers a lot at long context
      OLLAMA_FLASH_ATTENTION = "1";
      # qwen3-coder:30b has 48 layers with 4 KV heads of 128, which is 96 KiB
      # per token of f16 KV cache - 3 GiB at 32k. q8_0 halves that
      OLLAMA_KV_CACHE_TYPE = "q8_0";
      # default is 4k, which is useless for code
      OLLAMA_CONTEXT_LENGTH = "32768";
      # each parallel slot gets its own copy of the KV cache
      OLLAMA_NUM_PARALLEL = "1";
      # a second resident model would push the first one out of VRAM
      OLLAMA_MAX_LOADED_MODELS = "1";
      # 30b takes ~40s to load from disk, keep it warm for longer
      OLLAMA_KEEP_ALIVE = "30m";
      # MiB of VRAM that llama.cpp leaves free per device when it decides how
      # many layers to offload - headroom for the compositor and the browser
      LLAMA_ARG_FIT_TARGET = "1024";
    };
  };
  # same
  systemd.services.ollama.serviceConfig.DynamicUser = lib.mkForce false;

  # ollama enumerates GPUs once, during startup. The nvidia kernel modules are
  # loaded by udev and can appear after that point, in which case ollama finds
  # no GPU and runs every model on the CPU until it is restarted
  systemd.services.ollama.serviceConfig.ExecStartPre = lib.mkIf nvidia (
    pkgs.writeShellScript "wait-for-nvidia-uvm" ''
      for _ in $(${pkgs.coreutils}/bin/seq 150); do
        [ -e /dev/nvidia-uvm ] && exit 0
        ${pkgs.coreutils}/bin/sleep 0.2
      done
      echo "timed out waiting for /dev/nvidia-uvm, ollama will likely be CPU-only" >&2
    ''
  );
}
