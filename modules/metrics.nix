{ config, ... }:
let
  ports = {
    grafana = 3010;
    prometheus = 3020;
    prometheus-systemd = 3021;
    loki = 3030;
    promtail = 3031;
  };
in
{
  services.prometheus = {
    enable = true;
    port = ports.prometheus;

    exporters = {
      node = {
        enable = true;
        port = ports.prometheus-systemd;
        enabledCollectors = [ "systemd" ];
      };
    };

    scrapeConfigs = [{
      job_name = "nodes";
      static_configs = [{
        targets = [
          "127.0.0.1:${toString config.services.prometheus.exporters.node.port}"
        ];
      }];
    }];
  };

  services.loki = {
    enable = true;
    configuration = {
      server.http_listen_port = ports.loki;
      auth_enabled = false;

      ingester = {
        lifecycler = {
          address = "127.0.0.1";
          ring = {
            kvstore.store = "inmemory";
            replication_factor = 1;
          };
        };
        chunk_idle_period = "1h";
        max_chunk_age = "1h";
        chunk_target_size = 999999;
        chunk_retain_period = "30s";
        # max_transfer_retries = 0;
      };

      schema_config.configs = [{
        from = "2025-03-05";
        index = {
          period = "24h";
          prefix = "index_";
        };
        object_store = "filesystem";
        schema = "v13";
        store = "tsdb";
      }];

      storage_config.tsdb_shipper = {
        active_index_directory = "/var/lib/loki/tsdb-shipper-active";
        cache_location = "/var/lib/loki/tsdb-shipper-cache";
      };

      limits_config.reject_old_samples = true;

      # chunk_store_config = {
      #   max_look_back_period = "0s";
      # };

      table_manager = {
        retention_deletes_enabled = false;
        retention_period = "0s";
      };

      compactor = {
        working_directory = "/var/lib/loki";
        # shared_store = "filesystem";
        compactor_ring.kvstore.store = "inmemory";
      };
    };
  };

  services.promtail = {
    enable = true;
    configuration = {
      server = {
        http_listen_port = ports.promtail;
        grpc_listen_port = 0;
      };
      positions.filename = "/tmp/positions.yaml";
      clients = [{
        url = "http://127.0.0.1:${toString config.services.loki.configuration.server.http_listen_port}/loki/api/v1/push";
      }];
      scrape_configs = [
        {
          job_name = "journal";
          journal = {
            max_age = "12h";
            labels = {
              job = "systemd-journal";
              host = config.networking.hostName;
            };
          };
          relabel_configs = [{
            source_labels = [ "__journal__systemd_unit" ];
            target_label = "unit";
          }];
        }
        {
          job_name = "nginx";
          static_configs = [{
            targets = [ "localhost" ];
            labels = {
              job = "nginx";
              __path__ = "/var/log/nginx/*log";
              host = config.networking.hostName;
            };
          }];
          pipeline_stages = [
            {
              match = {
                selector = "{job=\"nginx\"}";
                stages = [
                  {
                    regex.expression = "^(?P<host>[\\w\\.]+) - (?P<user>[^ ]*) \\[(?P<timestamp>.*)\\] \"(?P<method>[^ ]*) (?P<request_url>[^ ]*) (?P<request_http_protocol>[^ ]*)\" (?P<status>[\\d]+) (?P<bytes_out>[\\d]+) \"(?P<http_referer>[^\"]*)\" \"(?P<user_agent>[^\"]*)\"?";
                  }
                  {
                    labels = {
                      host = "";
                      method = "";
                      request_url = "";
                      status = "";
                      user_agent = "";
                    };
                  }
                ];
              };
            }
          ];
        }
      ];
    };
  };

  users.users.promtail.extraGroups = [ "nginx" ];

  services.grafana = {
    enable = true;

    settings = {
      server = {
        root_url = "https://grafana.home.necauq.ua";
        protocol = "http";
        http_addr = "127.0.0.1";
        http_port = ports.grafana;
      };
      analytics.reporting_enabled = true;
    };
    provision = {
      enable = true;
      datasources.settings.datasources = [
        {
          name = "Prometheus";
          type = "prometheus";
          access = "proxy";
          url = "http://127.0.0.1:${toString config.services.prometheus.port}";
        }
        {
          name = "Loki";
          type = "loki";
          access = "proxy";
          url = "http://127.0.0.1:${toString config.services.loki.configuration.server.http_listen_port}";
        }
      ];
    };
  };

  custom.services = [
    { name = "grafana"; port = config.services.grafana.settings.server.http_port; }
    { name = "prometheus"; port = config.services.prometheus.port; }
    { name = "loki"; port = config.services.loki.configuration.server.http_listen_port; }
    { name = "promtail"; port = config.services.promtail.configuration.server.http_listen_port; }
  ];
}
