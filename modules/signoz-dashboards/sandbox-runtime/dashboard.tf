# Sandbox Runtime dashboard (SigNoz v2 / Perses schema v6).
#
# Managed by Terragrunt. State is isolated per dashboard unit so a broken panel
# here cannot block the other dashboards.
#
# Series verified against the live store before authoring:
#   k8s.pod.cpu.usage, k8s.pod.memory.usage, k8s.pod.uptime,
#   k8s.pod.network.io, k8s.pod.{cpu,memory}_{request,limit}_utilization,
#   k8s.container.ready, k8s.container.restarts,
#   k8s.node.cpu.usage, k8s.node.memory.usage,
#   system.cpu.load_average.1m, system.filesystem.usage, system.network.io,
#   node_nf_conntrack_entries, node_nf_conntrack_entries_limit,
#   squid logs (k8s.namespace.name = 'squid').
#
# Conntrack series are scraped by node-exporter and carry `k8s_node_name`;
# hostmetrics series carry `host.name`. Both are filtered to `sandbox-node`.

resource "signoz_dashboard" "sandbox_runtime" {
  schema_version = "v6"
  name           = "sandbox-runtime"
  tags = [
    { key = "tag", value = "homelab" },
    { key = "tag", value = "sandbox" },
  ]

  spec = {
    display = {
      name        = "Sandbox Runtime"
      description = "OpenCode agent sandbox health: pod health and resources, the sandbox node's resources, conntrack pressure, and Squid denials."
    }
    links = []

    variables = [
      {
        list_variable = {
          kind = "ListVariable"
          spec = {
            display = {
              name        = "pod"
              description = "Pod in agent-sandbox"
            }
            allow_all_value = true
            allow_multiple  = true
            sort            = "alphabetical-asc"
            name            = "pod"
            plugin = {
              dynamic_variable = {
                kind = "signoz/DynamicVariable"
                spec = {
                  name   = "k8s.pod.name"
                  signal = "metrics"
                }
              }
            }
          }
        }
      },
    ]

    panels = {
      "heartbeat" = {
        kind = "Panel"
        spec = {
          display = {
            name        = "Pod CPU (ingest heartbeat)"
            description = "Latest pod CPU usage. A no-data state means ingest stopped; zero means the sandbox is idle."
          }
          links = []
          plugin = {
            number_panel = {
              kind = "signoz/NumberPanel"
              spec = {
                visualization = {
                  time_preference = "global_time"
                }
                formatting = {
                  unit              = "short"
                  decimal_precision = "2"
                }
                thresholds = [
                  {
                    color = "#ef4444"
                    value = 0
                    label = "No activity"
                    unit  = "short"
                  },
                ]
              }
            }
          }
          queries = [
            {
              kind = "scalar"
              spec = {
                name = "A"
                plugin = {
                  builder_query = {
                    kind = "signoz/BuilderQuery"
                    spec = {
                      metrics = {
                        name          = "A"
                        step_interval = "60"
                        signal        = "metrics"
                        aggregations = [
                          {
                            metric_name       = "k8s.pod.cpu.usage"
                            time_aggregation  = "avg"
                            space_aggregation = "avg"
                            reduce_to         = "last"
                          },
                        ]
                        filter = {
                          expression = "k8s.namespace.name = 'agent-sandbox'"
                        }
                        having = {
                          expression = ""
                        }
                        legend = "Pod CPU"
                      }
                    }
                  }
                }
              }
            },
          ]
        }
      }
      "pod_uptime" = {
        kind = "Panel"
        spec = {
          display = {
            name        = "Pod uptime"
            description = "k8s.pod.uptime per pod in agent-sandbox"
          }
          links = []
          plugin = {
            time_series_panel = {
              kind = "signoz/TimeSeriesPanel"
              spec = {
                visualization = {
                  time_preference = "global_time"
                  fill_spans      = true
                }
                formatting = {
                  unit              = "s"
                  decimal_precision = "0"
                }
                chart_appearance = {
                  line_interpolation = "spline"
                  show_points        = false
                  line_style         = "solid"
                  fill_mode          = "solid"
                  span_gaps = {
                    fill_only_below = false
                    fill_less_than  = "0s"
                  }
                }
                axes = {
                  soft_min     = 0
                  is_log_scale = false
                }
                legend = {
                  position = "bottom"
                  mode     = "list"
                }
              }
            }
          }
          queries = [
            {
              kind = "time_series"
              spec = {
                name = "A"
                plugin = {
                  builder_query = {
                    kind = "signoz/BuilderQuery"
                    spec = {
                      metrics = {
                        name          = "A"
                        step_interval = "60"
                        signal        = "metrics"
                        aggregations = [
                          {
                            metric_name       = "k8s.pod.uptime"
                            time_aggregation  = "max"
                            space_aggregation = "max"
                          },
                        ]
                        filter = {
                          expression = "k8s.namespace.name = 'agent-sandbox' AND k8s.pod.name IN $pod"
                        }
                        group_by = [
                          {
                            name            = "k8s.pod.name"
                            field_context   = "attribute"
                            field_data_type = "string"
                          },
                        ]
                        having = {
                          expression = ""
                        }
                        legend = "{{k8s.pod.name}}"
                      }
                    }
                  }
                }
              }
            },
          ]
        }
      }
      "restarts" = {
        kind = "Panel"
        spec = {
          display = {
            name        = "Container restarts"
            description = "k8s.container.restarts per container in agent-sandbox"
          }
          links = []
          plugin = {
            time_series_panel = {
              kind = "signoz/TimeSeriesPanel"
              spec = {
                visualization = {
                  time_preference = "global_time"
                  fill_spans      = true
                }
                formatting = {
                  unit              = "short"
                  decimal_precision = "0"
                }
                chart_appearance = {
                  line_interpolation = "step_after"
                  show_points        = false
                  line_style         = "solid"
                  fill_mode          = "solid"
                  span_gaps = {
                    fill_only_below = false
                    fill_less_than  = "0s"
                  }
                }
                axes = {
                  soft_min     = 0
                  is_log_scale = false
                }
                legend = {
                  position = "bottom"
                  mode     = "list"
                }
              }
            }
          }
          queries = [
            {
              kind = "time_series"
              spec = {
                name = "A"
                plugin = {
                  builder_query = {
                    kind = "signoz/BuilderQuery"
                    spec = {
                      metrics = {
                        name          = "A"
                        step_interval = "60"
                        signal        = "metrics"
                        aggregations = [
                          {
                            metric_name       = "k8s.container.restarts"
                            time_aggregation  = "max"
                            space_aggregation = "max"
                          },
                        ]
                        filter = {
                          expression = "k8s.namespace.name = 'agent-sandbox' AND k8s.pod.name IN $pod"
                        }
                        group_by = [
                          {
                            name            = "k8s.pod.name"
                            field_context   = "attribute"
                            field_data_type = "string"
                          },
                          {
                            name            = "k8s.container.name"
                            field_context   = "attribute"
                            field_data_type = "string"
                          },
                        ]
                        having = {
                          expression = ""
                        }
                        legend = "{{k8s.pod.name}}/{{k8s.container.name}}"
                      }
                    }
                  }
                }
              }
            },
          ]
        }
      }
      "ready" = {
        kind = "Panel"
        spec = {
          display = {
            name        = "Container readiness"
            description = "k8s.container.ready (1 = ready) per container in agent-sandbox"
          }
          links = []
          plugin = {
            time_series_panel = {
              kind = "signoz/TimeSeriesPanel"
              spec = {
                visualization = {
                  time_preference = "global_time"
                  fill_spans      = true
                }
                formatting = {
                  unit              = "short"
                  decimal_precision = "0"
                }
                chart_appearance = {
                  line_interpolation = "step_after"
                  show_points        = false
                  line_style         = "solid"
                  fill_mode          = "solid"
                  span_gaps = {
                    fill_only_below = false
                    fill_less_than  = "0s"
                  }
                }
                axes = {
                  soft_min     = 0
                  is_log_scale = false
                }
                legend = {
                  position = "bottom"
                  mode     = "list"
                }
                thresholds = [
                  {
                    color = "#ef4444"
                    value = 0
                    label = "Not ready"
                    unit  = "short"
                  },
                ]
              }
            }
          }
          queries = [
            {
              kind = "time_series"
              spec = {
                name = "A"
                plugin = {
                  builder_query = {
                    kind = "signoz/BuilderQuery"
                    spec = {
                      metrics = {
                        name          = "A"
                        step_interval = "60"
                        signal        = "metrics"
                        aggregations = [
                          {
                            metric_name       = "k8s.container.ready"
                            time_aggregation  = "min"
                            space_aggregation = "min"
                          },
                        ]
                        filter = {
                          expression = "k8s.namespace.name = 'agent-sandbox' AND k8s.pod.name IN $pod"
                        }
                        group_by = [
                          {
                            name            = "k8s.pod.name"
                            field_context   = "attribute"
                            field_data_type = "string"
                          },
                          {
                            name            = "k8s.container.name"
                            field_context   = "attribute"
                            field_data_type = "string"
                          },
                        ]
                        having = {
                          expression = ""
                        }
                        legend = "{{k8s.pod.name}}/{{k8s.container.name}}"
                      }
                    }
                  }
                }
              }
            },
          ]
        }
      }
      "pod_cpu" = {
        kind = "Panel"
        spec = {
          display = {
            name        = "Pod CPU vs request and limit"
            description = "k8s.pod.cpu_request_utilization and cpu_limit_utilization"
          }
          links = []
          plugin = {
            time_series_panel = {
              kind = "signoz/TimeSeriesPanel"
              spec = {
                visualization = {
                  time_preference = "global_time"
                  fill_spans      = true
                }
                formatting = {
                  unit              = "percentunit"
                  decimal_precision = "2"
                }
                chart_appearance = {
                  line_interpolation = "spline"
                  show_points        = false
                  line_style         = "solid"
                  fill_mode          = "solid"
                  span_gaps = {
                    fill_only_below = false
                    fill_less_than  = "0s"
                  }
                }
                axes = {
                  soft_min     = 0
                  is_log_scale = false
                }
                legend = {
                  position = "bottom"
                  mode     = "list"
                }
                thresholds = [
                  {
                    color = "#ef4444"
                    value = 1
                    label = "At limit"
                    unit  = "percentunit"
                  },
                ]
              }
            }
          }
          queries = [
            {
              kind = "time_series"
              spec = {
                name = "A"
                plugin = {
                  composite_query = {
                    kind = "signoz/CompositeQuery"
                    spec = {
                      queries = [
                        {
                          builder_query = {
                            type = "builder_query"
                            spec = {
                              metrics = {
                                name          = "A"
                                step_interval = "60"
                                signal        = "metrics"
                                aggregations = [
                                  {
                                    metric_name       = "k8s.pod.cpu_request_utilization"
                                    time_aggregation  = "avg"
                                    space_aggregation = "avg"
                                  },
                                ]
                                filter = {
                                  expression = "k8s.namespace.name = 'agent-sandbox' AND k8s.pod.name IN $pod"
                                }
                                group_by = [
                                  {
                                    name            = "k8s.pod.name"
                                    field_context   = "attribute"
                                    field_data_type = "string"
                                  },
                                ]
                                having = {
                                  expression = ""
                                }
                                legend = "request {{k8s.pod.name}}"
                              }
                            }
                          }
                        },
                        {
                          builder_query = {
                            type = "builder_query"
                            spec = {
                              metrics = {
                                name          = "B"
                                step_interval = "60"
                                signal        = "metrics"
                                aggregations = [
                                  {
                                    metric_name       = "k8s.pod.cpu_limit_utilization"
                                    time_aggregation  = "avg"
                                    space_aggregation = "avg"
                                  },
                                ]
                                filter = {
                                  expression = "k8s.namespace.name = 'agent-sandbox' AND k8s.pod.name IN $pod"
                                }
                                group_by = [
                                  {
                                    name            = "k8s.pod.name"
                                    field_context   = "attribute"
                                    field_data_type = "string"
                                  },
                                ]
                                having = {
                                  expression = ""
                                }
                                legend = "limit {{k8s.pod.name}}"
                              }
                            }
                          }
                        },
                      ]
                    }
                  }
                }
              }
            },
          ]
        }
      }
      "pod_memory" = {
        kind = "Panel"
        spec = {
          display = {
            name        = "Pod memory vs request and limit"
            description = "k8s.pod.memory_request_utilization and memory_limit_utilization"
          }
          links = []
          plugin = {
            time_series_panel = {
              kind = "signoz/TimeSeriesPanel"
              spec = {
                visualization = {
                  time_preference = "global_time"
                  fill_spans      = true
                }
                formatting = {
                  unit              = "percentunit"
                  decimal_precision = "2"
                }
                chart_appearance = {
                  line_interpolation = "spline"
                  show_points        = false
                  line_style         = "solid"
                  fill_mode          = "solid"
                  span_gaps = {
                    fill_only_below = false
                    fill_less_than  = "0s"
                  }
                }
                axes = {
                  soft_min     = 0
                  is_log_scale = false
                }
                legend = {
                  position = "bottom"
                  mode     = "list"
                }
                thresholds = [
                  {
                    color = "#ef4444"
                    value = 1
                    label = "At limit"
                    unit  = "percentunit"
                  },
                ]
              }
            }
          }
          queries = [
            {
              kind = "time_series"
              spec = {
                name = "A"
                plugin = {
                  composite_query = {
                    kind = "signoz/CompositeQuery"
                    spec = {
                      queries = [
                        {
                          builder_query = {
                            type = "builder_query"
                            spec = {
                              metrics = {
                                name          = "A"
                                step_interval = "60"
                                signal        = "metrics"
                                aggregations = [
                                  {
                                    metric_name       = "k8s.pod.memory_request_utilization"
                                    time_aggregation  = "avg"
                                    space_aggregation = "avg"
                                  },
                                ]
                                filter = {
                                  expression = "k8s.namespace.name = 'agent-sandbox' AND k8s.pod.name IN $pod"
                                }
                                group_by = [
                                  {
                                    name            = "k8s.pod.name"
                                    field_context   = "attribute"
                                    field_data_type = "string"
                                  },
                                ]
                                having = {
                                  expression = ""
                                }
                                legend = "request {{k8s.pod.name}}"
                              }
                            }
                          }
                        },
                        {
                          builder_query = {
                            type = "builder_query"
                            spec = {
                              metrics = {
                                name          = "B"
                                step_interval = "60"
                                signal        = "metrics"
                                aggregations = [
                                  {
                                    metric_name       = "k8s.pod.memory_limit_utilization"
                                    time_aggregation  = "avg"
                                    space_aggregation = "avg"
                                  },
                                ]
                                filter = {
                                  expression = "k8s.namespace.name = 'agent-sandbox' AND k8s.pod.name IN $pod"
                                }
                                group_by = [
                                  {
                                    name            = "k8s.pod.name"
                                    field_context   = "attribute"
                                    field_data_type = "string"
                                  },
                                ]
                                having = {
                                  expression = ""
                                }
                                legend = "limit {{k8s.pod.name}}"
                              }
                            }
                          }
                        },
                      ]
                    }
                  }
                }
              }
            },
          ]
        }
      }
      "pod_network" = {
        kind = "Panel"
        spec = {
          display = {
            name        = "Pod network I/O"
            description = "k8s.pod.network.io rate by direction, agent-sandbox"
          }
          links = []
          plugin = {
            time_series_panel = {
              kind = "signoz/TimeSeriesPanel"
              spec = {
                visualization = {
                  time_preference = "global_time"
                  fill_spans      = true
                }
                formatting = {
                  unit              = "bytes"
                  decimal_precision = "2"
                }
                chart_appearance = {
                  line_interpolation = "spline"
                  show_points        = false
                  line_style         = "solid"
                  fill_mode          = "solid"
                  span_gaps = {
                    fill_only_below = false
                    fill_less_than  = "0s"
                  }
                }
                axes = {
                  soft_min     = 0
                  is_log_scale = false
                }
                legend = {
                  position = "bottom"
                  mode     = "list"
                }
              }
            }
          }
          queries = [
            {
              kind = "time_series"
              spec = {
                name = "A"
                plugin = {
                  builder_query = {
                    kind = "signoz/BuilderQuery"
                    spec = {
                      metrics = {
                        name          = "A"
                        step_interval = "60"
                        signal        = "metrics"
                        aggregations = [
                          {
                            metric_name       = "k8s.pod.network.io"
                            time_aggregation  = "rate"
                            space_aggregation = "sum"
                          },
                        ]
                        filter = {
                          expression = "k8s.namespace.name = 'agent-sandbox' AND k8s.pod.name IN $pod"
                        }
                        group_by = [
                          {
                            name            = "direction"
                            field_context   = "attribute"
                            field_data_type = "string"
                          },
                        ]
                        having = {
                          expression = ""
                        }
                        legend = "{{direction}}"
                      }
                    }
                  }
                }
              }
            },
          ]
        }
      }
      "node_cpu" = {
        kind = "Panel"
        spec = {
          display = {
            name        = "Sandbox node CPU"
            description = "k8s.node.cpu.usage on sandbox-node"
          }
          links = []
          plugin = {
            time_series_panel = {
              kind = "signoz/TimeSeriesPanel"
              spec = {
                visualization = {
                  time_preference = "global_time"
                  fill_spans      = true
                }
                formatting = {
                  unit              = "short"
                  decimal_precision = "2"
                }
                chart_appearance = {
                  line_interpolation = "spline"
                  show_points        = false
                  line_style         = "solid"
                  fill_mode          = "solid"
                  span_gaps = {
                    fill_only_below = false
                    fill_less_than  = "0s"
                  }
                }
                axes = {
                  soft_min     = 0
                  is_log_scale = false
                }
                legend = {
                  position = "bottom"
                  mode     = "list"
                }
              }
            }
          }
          queries = [
            {
              kind = "time_series"
              spec = {
                name = "A"
                plugin = {
                  builder_query = {
                    kind = "signoz/BuilderQuery"
                    spec = {
                      metrics = {
                        name          = "A"
                        step_interval = "60"
                        signal        = "metrics"
                        aggregations = [
                          {
                            metric_name       = "k8s.node.cpu.usage"
                            time_aggregation  = "avg"
                            space_aggregation = "avg"
                          },
                        ]
                        filter = {
                          expression = "k8s.node.name = 'sandbox-node'"
                        }
                        having = {
                          expression = ""
                        }
                        legend = "CPU"
                      }
                    }
                  }
                }
              }
            },
          ]
        }
      }
      "node_memory" = {
        kind = "Panel"
        spec = {
          display = {
            name        = "Sandbox node memory"
            description = "k8s.node.memory.usage on sandbox-node"
          }
          links = []
          plugin = {
            time_series_panel = {
              kind = "signoz/TimeSeriesPanel"
              spec = {
                visualization = {
                  time_preference = "global_time"
                  fill_spans      = true
                }
                formatting = {
                  unit              = "bytes"
                  decimal_precision = "2"
                }
                chart_appearance = {
                  line_interpolation = "spline"
                  show_points        = false
                  line_style         = "solid"
                  fill_mode          = "solid"
                  span_gaps = {
                    fill_only_below = false
                    fill_less_than  = "0s"
                  }
                }
                axes = {
                  soft_min     = 0
                  is_log_scale = false
                }
                legend = {
                  position = "bottom"
                  mode     = "list"
                }
              }
            }
          }
          queries = [
            {
              kind = "time_series"
              spec = {
                name = "A"
                plugin = {
                  builder_query = {
                    kind = "signoz/BuilderQuery"
                    spec = {
                      metrics = {
                        name          = "A"
                        step_interval = "60"
                        signal        = "metrics"
                        aggregations = [
                          {
                            metric_name       = "k8s.node.memory.usage"
                            time_aggregation  = "avg"
                            space_aggregation = "avg"
                          },
                        ]
                        filter = {
                          expression = "k8s.node.name = 'sandbox-node'"
                        }
                        having = {
                          expression = ""
                        }
                        legend = "Memory"
                      }
                    }
                  }
                }
              }
            },
          ]
        }
      }
      "node_load" = {
        kind = "Panel"
        spec = {
          display = {
            name        = "Sandbox node load (1m)"
            description = "system.cpu.load_average.1m on sandbox-node"
          }
          links = []
          plugin = {
            time_series_panel = {
              kind = "signoz/TimeSeriesPanel"
              spec = {
                visualization = {
                  time_preference = "global_time"
                  fill_spans      = true
                }
                formatting = {
                  unit              = "short"
                  decimal_precision = "2"
                }
                chart_appearance = {
                  line_interpolation = "spline"
                  show_points        = false
                  line_style         = "solid"
                  fill_mode          = "solid"
                  span_gaps = {
                    fill_only_below = false
                    fill_less_than  = "0s"
                  }
                }
                axes = {
                  soft_min     = 0
                  is_log_scale = false
                }
                legend = {
                  position = "bottom"
                  mode     = "list"
                }
              }
            }
          }
          queries = [
            {
              kind = "time_series"
              spec = {
                name = "A"
                plugin = {
                  builder_query = {
                    kind = "signoz/BuilderQuery"
                    spec = {
                      metrics = {
                        name          = "A"
                        step_interval = "60"
                        signal        = "metrics"
                        aggregations = [
                          {
                            metric_name       = "system.cpu.load_average.1m"
                            time_aggregation  = "avg"
                            space_aggregation = "avg"
                          },
                        ]
                        filter = {
                          expression = "host.name = 'sandbox-node'"
                        }
                        having = {
                          expression = ""
                        }
                        legend = "Load 1m"
                      }
                    }
                  }
                }
              }
            },
          ]
        }
      }
      "node_filesystem" = {
        kind = "Panel"
        spec = {
          display = {
            name        = "Sandbox node filesystem"
            description = "system.filesystem.usage (state=used) by mountpoint on sandbox-node"
          }
          links = []
          plugin = {
            time_series_panel = {
              kind = "signoz/TimeSeriesPanel"
              spec = {
                visualization = {
                  time_preference = "global_time"
                  fill_spans      = true
                }
                formatting = {
                  unit              = "bytes"
                  decimal_precision = "2"
                }
                chart_appearance = {
                  line_interpolation = "spline"
                  show_points        = false
                  line_style         = "solid"
                  fill_mode          = "solid"
                  span_gaps = {
                    fill_only_below = false
                    fill_less_than  = "0s"
                  }
                }
                axes = {
                  soft_min     = 0
                  is_log_scale = false
                }
                legend = {
                  position = "bottom"
                  mode     = "list"
                }
              }
            }
          }
          queries = [
            {
              kind = "time_series"
              spec = {
                name = "A"
                plugin = {
                  builder_query = {
                    kind = "signoz/BuilderQuery"
                    spec = {
                      metrics = {
                        name          = "A"
                        step_interval = "60"
                        signal        = "metrics"
                        aggregations = [
                          {
                            metric_name       = "system.filesystem.usage"
                            time_aggregation  = "avg"
                            space_aggregation = "sum"
                          },
                        ]
                        filter = {
                          expression = "host.name = 'sandbox-node' AND state = 'used'"
                        }
                        group_by = [
                          {
                            name            = "mountpoint"
                            field_context   = "attribute"
                            field_data_type = "string"
                          },
                        ]
                        having = {
                          expression = ""
                        }
                        legend = "{{mountpoint}}"
                      }
                    }
                  }
                }
              }
            },
          ]
        }
      }
      "node_network" = {
        kind = "Panel"
        spec = {
          display = {
            name        = "Sandbox node network I/O"
            description = "system.network.io rate by direction on sandbox-node"
          }
          links = []
          plugin = {
            time_series_panel = {
              kind = "signoz/TimeSeriesPanel"
              spec = {
                visualization = {
                  time_preference = "global_time"
                  fill_spans      = true
                }
                formatting = {
                  unit              = "bytes"
                  decimal_precision = "2"
                }
                chart_appearance = {
                  line_interpolation = "spline"
                  show_points        = false
                  line_style         = "solid"
                  fill_mode          = "solid"
                  span_gaps = {
                    fill_only_below = false
                    fill_less_than  = "0s"
                  }
                }
                axes = {
                  soft_min     = 0
                  is_log_scale = false
                }
                legend = {
                  position = "bottom"
                  mode     = "list"
                }
              }
            }
          }
          queries = [
            {
              kind = "time_series"
              spec = {
                name = "A"
                plugin = {
                  builder_query = {
                    kind = "signoz/BuilderQuery"
                    spec = {
                      metrics = {
                        name          = "A"
                        step_interval = "60"
                        signal        = "metrics"
                        aggregations = [
                          {
                            metric_name       = "system.network.io"
                            time_aggregation  = "rate"
                            space_aggregation = "sum"
                          },
                        ]
                        filter = {
                          expression = "host.name = 'sandbox-node'"
                        }
                        group_by = [
                          {
                            name            = "direction"
                            field_context   = "attribute"
                            field_data_type = "string"
                          },
                        ]
                        having = {
                          expression = ""
                        }
                        legend = "{{direction}}"
                      }
                    }
                  }
                }
              }
            },
          ]
        }
      }
      "conntrack" = {
        kind = "Panel"
        spec = {
          display = {
            name        = "Connection table entries vs limit"
            description = "node_nf_conntrack_entries against node_nf_conntrack_entries_limit on sandbox-node; the reference line is 80% of the current limit (104858 of 131072)."
          }
          links = []
          plugin = {
            time_series_panel = {
              kind = "signoz/TimeSeriesPanel"
              spec = {
                visualization = {
                  time_preference = "global_time"
                  fill_spans      = true
                }
                formatting = {
                  unit              = "short"
                  decimal_precision = "0"
                }
                chart_appearance = {
                  line_interpolation = "spline"
                  show_points        = false
                  line_style         = "solid"
                  fill_mode          = "solid"
                  span_gaps = {
                    fill_only_below = false
                    fill_less_than  = "0s"
                  }
                }
                axes = {
                  soft_min     = 0
                  is_log_scale = false
                }
                legend = {
                  position = "bottom"
                  mode     = "list"
                }
                thresholds = [
                  {
                    color = "#eab308"
                    value = 104858
                    label = "80% of limit"
                    unit  = "short"
                  },
                ]
              }
            }
          }
          queries = [
            {
              kind = "time_series"
              spec = {
                name = "A"
                plugin = {
                  composite_query = {
                    kind = "signoz/CompositeQuery"
                    spec = {
                      queries = [
                        {
                          builder_query = {
                            type = "builder_query"
                            spec = {
                              metrics = {
                                name          = "A"
                                step_interval = "60"
                                signal        = "metrics"
                                aggregations = [
                                  {
                                    metric_name       = "node_nf_conntrack_entries"
                                    time_aggregation  = "avg"
                                    space_aggregation = "avg"
                                  },
                                ]
                                filter = {
                                  expression = "k8s_node_name = 'sandbox-node'"
                                }
                                having = {
                                  expression = ""
                                }
                                legend = "entries"
                              }
                            }
                          }
                        },
                        {
                          builder_query = {
                            type = "builder_query"
                            spec = {
                              metrics = {
                                name          = "B"
                                step_interval = "60"
                                signal        = "metrics"
                                aggregations = [
                                  {
                                    metric_name       = "node_nf_conntrack_entries_limit"
                                    time_aggregation  = "max"
                                    space_aggregation = "max"
                                  },
                                ]
                                filter = {
                                  expression = "k8s_node_name = 'sandbox-node'"
                                }
                                having = {
                                  expression = ""
                                }
                                legend = "limit"
                              }
                            }
                          }
                        },
                      ]
                    }
                  }
                }
              }
            },
          ]
        }
      }
      "squid_denied" = {
        kind = "Panel"
        spec = {
          display = {
            name        = "Squid denied requests"
            description = "Log records containing TCP_DENIED in the Squid namespace"
          }
          links = []
          plugin = {
            time_series_panel = {
              kind = "signoz/TimeSeriesPanel"
              spec = {
                visualization = {
                  time_preference = "global_time"
                  fill_spans      = true
                }
                formatting = {
                  unit              = "short"
                  decimal_precision = "0"
                }
                chart_appearance = {
                  line_interpolation = "step_after"
                  show_points        = false
                  line_style         = "solid"
                  fill_mode          = "solid"
                  span_gaps = {
                    fill_only_below = false
                    fill_less_than  = "0s"
                  }
                }
                axes = {
                  soft_min     = 0
                  is_log_scale = false
                }
                legend = {
                  position = "bottom"
                  mode     = "list"
                }
              }
            }
          }
          queries = [
            {
              kind = "time_series"
              spec = {
                name = "A"
                plugin = {
                  builder_query = {
                    kind = "signoz/BuilderQuery"
                    spec = {
                      logs = {
                        name          = "A"
                        step_interval = "60"
                        signal        = "logs"
                        aggregations = [
                          {
                            expression = "countIf(body LIKE '%TCP_DENIED%')"
                          },
                        ]
                        filter = {
                          expression = "k8s.namespace.name = 'squid'"
                        }
                        having = {
                          expression = ""
                        }
                        legend = "denied"
                      }
                    }
                  }
                }
              }
            },
          ]
        }
      }
      "squid_volume" = {
        kind = "Panel"
        spec = {
          display = {
            name        = "Squid log volume"
            description = "All log records in the Squid namespace. A no-data state means log ingest stopped; zero denied requests with a healthy volume is a good outcome."
          }
          links = []
          plugin = {
            number_panel = {
              kind = "signoz/NumberPanel"
              spec = {
                visualization = {
                  time_preference = "global_time"
                }
                formatting = {
                  unit              = "short"
                  decimal_precision = "0"
                }
              }
            }
          }
          queries = [
            {
              kind = "scalar"
              spec = {
                name = "A"
                plugin = {
                  builder_query = {
                    kind = "signoz/BuilderQuery"
                    spec = {
                      logs = {
                        name          = "A"
                        step_interval = "60"
                        signal        = "logs"
                        aggregations = [
                          {
                            expression = "count()"
                          },
                        ]
                        filter = {
                          expression = "k8s.namespace.name = 'squid'"
                        }
                        having = {
                          expression = ""
                        }
                        legend = "Squid logs"
                      }
                    }
                  }
                }
              }
            },
          ]
        }
      }
    }

    layouts = [
      {
        grid = {
          kind = "Grid"
          spec = {
            display = {
              title = "Runtime"
              collapse = {
                open = true
              }
            }
            items = [
              {
                x      = 0
                y      = 0
                width  = 3
                height = 6
                content = {
                  ref = "#/spec/panels/heartbeat"
                }
              },
              {
                x      = 3
                y      = 0
                width  = 5
                height = 6
                content = {
                  ref = "#/spec/panels/pod_uptime"
                }
              },
              {
                x      = 8
                y      = 0
                width  = 2
                height = 6
                content = {
                  ref = "#/spec/panels/restarts"
                }
              },
              {
                x      = 10
                y      = 0
                width  = 2
                height = 6
                content = {
                  ref = "#/spec/panels/ready"
                }
              },
              {
                x      = 0
                y      = 6
                width  = 6
                height = 6
                content = {
                  ref = "#/spec/panels/pod_cpu"
                }
              },
              {
                x      = 6
                y      = 6
                width  = 6
                height = 6
                content = {
                  ref = "#/spec/panels/pod_memory"
                }
              },
              {
                x      = 0
                y      = 12
                width  = 12
                height = 6
                content = {
                  ref = "#/spec/panels/pod_network"
                }
              },
              {
                x      = 0
                y      = 18
                width  = 4
                height = 6
                content = {
                  ref = "#/spec/panels/node_cpu"
                }
              },
              {
                x      = 4
                y      = 18
                width  = 4
                height = 6
                content = {
                  ref = "#/spec/panels/node_memory"
                }
              },
              {
                x      = 8
                y      = 18
                width  = 4
                height = 6
                content = {
                  ref = "#/spec/panels/node_load"
                }
              },
              {
                x      = 0
                y      = 24
                width  = 6
                height = 6
                content = {
                  ref = "#/spec/panels/node_filesystem"
                }
              },
              {
                x      = 6
                y      = 24
                width  = 6
                height = 6
                content = {
                  ref = "#/spec/panels/node_network"
                }
              },
              {
                x      = 0
                y      = 30
                width  = 12
                height = 6
                content = {
                  ref = "#/spec/panels/conntrack"
                }
              },
              {
                x      = 0
                y      = 36
                width  = 9
                height = 6
                content = {
                  ref = "#/spec/panels/squid_denied"
                }
              },
              {
                x      = 9
                y      = 36
                width  = 3
                height = 6
                content = {
                  ref = "#/spec/panels/squid_volume"
                }
              },
            ]
          }
        }
      },
    ]
  }
}
