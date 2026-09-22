# This only sets up the schedule and the templates,
# each machine declares its own datasets
{
  services.sanoid = {
    enable = true;

    # sanoid takes a snapshot only when the newest one is older than
    # frequent_period, so it must run more often than that period,
    # otherwise timer jitter makes the gaps twice as long
    interval = "minutely";

    templates.frequent = {
      frequent_period = 5;
      frequently = 288; # 288 * 5 minutes = 1 day
      hourly = 0;
      daily = 7;
      weekly = 4; # ~1 month
      monthly = 0;
      yearly = 0;
      autosnap = true;
      autoprune = true;
    };

    # sanoid applies the settings of a recursive section to every child dataset,
    # and a section for the child itself then overrides them again
    templates.excluded = {
      autosnap = false;
      autoprune = false;
    };
  };
}
