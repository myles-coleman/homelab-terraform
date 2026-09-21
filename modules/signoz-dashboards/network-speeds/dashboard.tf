# Network Speeds dashboard (SigNoz v2 / Perses schema v6).
#
# Managed by Terragrunt. Internet speed tests come from the speedtest exporter
# (homelab-cluster/manifests/cluster/speedtest); node and pod throughput come
# from the k8s-infra hostMetrics / kubeletstats presets.

resource "signoz_dashboard" "network_speeds" {
  schema_version = "v6"
  name           = "network-speeds"
  tags = [
    { key = "tag", value = "homelab" },
    { key = "tag", value = "network" },
  ]

  spec = {
    display = {
      name        = "Network Speeds"
      description = "Internet speed tests (download/upload/latency/jitter/packet loss) plus per-node and per-namespace network throughput."
    }
    links = []

    variables = [
      {
        list_variable = {
          kind = "ListVariable"
          spec = {
            display = {
              name        = "host_name"
              description = "Host sending network metrics"
            }
            allow_all_value = true
            allow_multiple  = true
            sort            = "alphabetical-asc"
            name            = "host_name"
            plugin = {
              dynamic_variable = {
                kind = "signoz/DynamicVariable"
                spec = {
                  name   = "host.name"
                  signal = "metrics"
                }
              }
            }
          }
        }
      },
      {
        list_variable = {
          kind = "ListVariable"
          spec = {
            display = {
              name        = "namespace"
              description = "Kubernetes namespace"
            }
            allow_all_value = true
            allow_multiple  = true
            sort            = "alphabetical-asc"
            name            = "namespace"
            plugin = {
              dynamic_variable = {
                kind = "signoz/DynamicVariable"
                spec = {
                  name   = "k8s.namespace.name"
                  signal = "metrics"
                }
              }
            }
          }
        }
      },
    ]

    panels = {
      "download" = {
        kind = "Panel"
        spec = {
          display = {
            name        = "Download speed"
            description = "speedtest_download_bits_per_second (latest)"
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
                  unit              = "bps"
                  decimal_precision = "2"
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
                      metrics = {
                        name          = "A"
                        step_interval = "60"
                        signal        = "metrics"
                        aggregations = [
                          {
                            metric_name       = "speedtest_download_bits_per_second"
                            time_aggregation  = "latest"
                            space_aggregation = "avg"
                            reduce_to         = "last"
                          },
                        ]
                        filter = {
                          expression = ""
                        }
                        having = {
                          expression = ""
                        }
                        legend = "Download"
                      }
                    }
                  }
                }
              }
            },
          ]
        }
      }
      "upload" = {
        kind = "Panel"
        spec = {
          display = {
            name        = "Upload speed"
            description = "speedtest_upload_bits_per_second (latest)"
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
                  unit              = "bps"
                  decimal_precision = "2"
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
                      metrics = {
                        name          = "A"
                        step_interval = "60"
                        signal        = "metrics"
                        aggregations = [
                          {
                            metric_name       = "speedtest_upload_bits_per_second"
                            time_aggregation  = "latest"
                            space_aggregation = "avg"
                            reduce_to         = "last"
                          },
                        ]
                        filter = {
                          expression = ""
                        }
                        having = {
                          expression = ""
                        }
                        legend = "Upload"
                      }
                    }
                  }
                }
              }
            },
          ]
        }
      }
      "ping" = {
        kind = "Panel"
        spec = {
          display = {
            name        = "Ping latency"
            description = "speedtest_ping_latency_milliseconds (latest)"
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
                  unit              = "ms"
                  decimal_precision = "2"
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
                      metrics = {
                        name          = "A"
                        step_interval = "60"
                        signal        = "metrics"
                        aggregations = [
                          {
                            metric_name       = "speedtest_ping_latency_milliseconds"
                            time_aggregation  = "latest"
                            space_aggregation = "avg"
                            reduce_to         = "last"
                          },
                        ]
                        filter = {
                          expression = ""
                        }
                        having = {
                          expression = ""
                        }
                        legend = "Ping"
                      }
                    }
                  }
                }
              }
            },
          ]
        }
      }
      "jitter" = {
        kind = "Panel"
        spec = {
          display = {
            name        = "Jitter"
            description = "speedtest_jitter_latency_milliseconds (latest)"
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
                  unit              = "ms"
                  decimal_precision = "2"
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
                      metrics = {
                        name          = "A"
                        step_interval = "60"
                        signal        = "metrics"
                        aggregations = [
                          {
                            metric_name       = "speedtest_jitter_latency_milliseconds"
                            time_aggregation  = "latest"
                            space_aggregation = "avg"
                            reduce_to         = "last"
                          },
                        ]
                        filter = {
                          expression = ""
                        }
                        having = {
                          expression = ""
                        }
                        legend = "Jitter"
                      }
                    }
                  }
                }
              }
            },
          ]
        }
      }
      "packet-loss" = {
        kind = "Panel"
        spec = {
          display = {
            name        = "Packet loss"
            description = "speedtest_packet_loss_percent (latest)"
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
                  unit              = "percent"
                  decimal_precision = "2"
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
                      metrics = {
                        name          = "A"
                        step_interval = "60"
                        signal        = "metrics"
                        aggregations = [
                          {
                            metric_name       = "speedtest_packet_loss_percent"
                            time_aggregation  = "latest"
                            space_aggregation = "avg"
                            reduce_to         = "last"
                          },
                        ]
                        filter = {
                          expression = ""
                        }
                        having = {
                          expression = ""
                        }
                        legend = "Packet loss"
                      }
                    }
                  }
                }
              }
            },
          ]
        }
      }
      "download-history" = {
        kind = "Panel"
        spec = {
          display = {
            name        = "Download speed over time"
            description = "speedtest download bits per second"
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
                  unit              = "bps"
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
                            metric_name       = "speedtest_download_bits_per_second"
                            time_aggregation  = "latest"
                            space_aggregation = "avg"
                            reduce_to         = "avg"
                          },
                        ]
                        filter = {
                          expression = ""
                        }
                        having = {
                          expression = ""
                        }
                        legend = "Download"
                      }
                    }
                  }
                }
              }
            },
          ]
        }
      }
      "upload-history" = {
        kind = "Panel"
        spec = {
          display = {
            name        = "Upload speed over time"
            description = "speedtest upload bits per second"
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
                  unit              = "bps"
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
                            metric_name       = "speedtest_upload_bits_per_second"
                            time_aggregation  = "latest"
                            space_aggregation = "avg"
                            reduce_to         = "avg"
                          },
                        ]
                        filter = {
                          expression = ""
                        }
                        having = {
                          expression = ""
                        }
                        legend = "Upload"
                      }
                    }
                  }
                }
              }
            },
          ]
        }
      }
      "node-throughput" = {
        kind = "Panel"
        spec = {
          display = {
            name        = "Node network throughput"
            description = "system.network.io rate per host and direction"
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
                  unit              = "Bps"
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
                            reduce_to         = "sum"
                          },
                        ]
                        filter = {
                          expression = "host.name IN $host_name"
                        }
                        group_by = [
                          {
                            name            = "host.name"
                            field_context   = "attribute"
                            field_data_type = "string"
                          },
                        ]
                        having = {
                          expression = ""
                        }
                        legend = "{{host.name}} {{direction}}"
                      }
                    }
                  }
                }
              }
            },
          ]
        }
      }
      "pod-throughput" = {
        kind = "Panel"
        spec = {
          display = {
            name        = "Pod network throughput"
            description = "k8s.pod.network.io rate by namespace"
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
                  unit              = "Bps"
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
                            reduce_to         = "sum"
                          },
                        ]
                        filter = {
                          expression = "k8s.namespace.name IN $namespace"
                        }
                        group_by = [
                          {
                            name            = "k8s.namespace.name"
                            field_context   = "attribute"
                            field_data_type = "string"
                          },
                        ]
                        having = {
                          expression = ""
                        }
                        legend = "{{k8s.namespace.name}}"
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
              title = "Overview"
              collapse = {
                open = true
              }
            }
            items = [
              {
                x      = 0
                y      = 0
                width  = 4
                height = 5
                content = {
                  ref = "#/spec/panels/download"
                }
              },
              {
                x      = 4
                y      = 0
                width  = 4
                height = 5
                content = {
                  ref = "#/spec/panels/upload"
                }
              },
              {
                x      = 8
                y      = 0
                width  = 4
                height = 5
                content = {
                  ref = "#/spec/panels/ping"
                }
              },
              {
                x      = 0
                y      = 5
                width  = 4
                height = 5
                content = {
                  ref = "#/spec/panels/jitter"
                }
              },
              {
                x      = 4
                y      = 5
                width  = 4
                height = 5
                content = {
                  ref = "#/spec/panels/packet-loss"
                }
              },
              {
                x      = 0
                y      = 10
                width  = 12
                height = 6
                content = {
                  ref = "#/spec/panels/download-history"
                }
              },
              {
                x      = 0
                y      = 16
                width  = 12
                height = 6
                content = {
                  ref = "#/spec/panels/upload-history"
                }
              },
              {
                x      = 0
                y      = 22
                width  = 12
                height = 6
                content = {
                  ref = "#/spec/panels/node-throughput"
                }
              },
              {
                x      = 0
                y      = 28
                width  = 12
                height = 6
                content = {
                  ref = "#/spec/panels/pod-throughput"
                }
              },
            ]
          }
        }
      },
    ]
  }
}
