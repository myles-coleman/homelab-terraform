# Strata Endpoint dashboard (SigNoz v2 / Perses schema v6).
#
# Managed by Terragrunt. State is isolated per dashboard unit.
#
# Series verified against the live store before authoring (Prometheus receiver,
# colon-containing names preserved):
#   strata:gpu_util, strata:gpu_mem_used_bytes, strata:gpu_mem_total_bytes,
#   strata:gpu_temp_celsius, strata:gpu_power_watts,
#   strata:live_tok_s, strata:last_decode_tok_s, strata:last_hit_rate,
#   strata:live_state, strata:ram_used_bytes, strata:ram_total_bytes,
#   vllm:num_requests_running, vllm:num_requests_waiting,
#   vllm:request_success_total, vllm:prompt_tokens_total,
#   vllm:generation_tokens_total, vllm:kv_cache_usage_perc,
#   vllm:prefix_cache_{hits,queries}_total,
#   vllm:spec_decode_num_{accepted,draft}_tokens_total,
#   vllm:e2e_request_latency_seconds.bucket,
#   vllm:time_to_first_token_seconds.bucket,
#   vllm:inter_token_latency_seconds.bucket.
#
# Deliberately omitted, because the data cannot isolate a consumer or does not
# exist: per-consumer views (`strata_consumer` is always "shared"), a
# finish-reason breakdown, and a 401 counter.

resource "signoz_dashboard" "strata_endpoint" {
  schema_version = "v6"
  name           = "strata-endpoint"
  tags = [
    { key = "tag", value = "homelab" },
    { key = "tag", value = "strata" },
  ]

  spec = {
    display = {
      name        = "Strata Endpoint"
      description = "GPU, Strata engine, and vLLM health for the model endpoint the sandbox talks to."
    }
    links = []

    variables = [
      {
        list_variable = {
          kind = "ListVariable"
          spec = {
            display = {
              name        = "model"
              description = "Model served by the endpoint"
            }
            allow_all_value = true
            allow_multiple  = true
            sort            = "alphabetical-asc"
            name            = "model"
            plugin = {
              dynamic_variable = {
                kind = "signoz/DynamicVariable"
                spec = {
                  name   = "model_name"
                  signal = "metrics"
                }
              }
            }
          }
        }
      },
    ]

    panels = {
      "gpu_util" = {
        kind = "Panel"
        spec = {
          display = {
            name        = "GPU utilisation"
            description = "strata:gpu_util per GPU"
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
                  unit              = "percent"
                  decimal_precision = "1"
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
                    value = 90
                    label = "Saturated"
                    unit  = "percent"
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
                            metric_name       = "strata:gpu_util"
                            time_aggregation  = "avg"
                            space_aggregation = "avg"
                          },
                        ]
                        filter = {
                          expression = "host.name = 'bee-gpu-server' AND model_name IN $model"
                        }
                        group_by = [
                          {
                            name            = "gpu"
                            field_context   = "attribute"
                            field_data_type = "string"
                          },
                        ]
                        having = {
                          expression = ""
                        }
                        legend = "GPU {{gpu}}"
                      }
                    }
                  }
                }
              }
            },
          ]
        }
      }
      "gpu_memory" = {
        kind = "Panel"
        spec = {
          display = {
            name        = "GPU memory used and total"
            description = "strata:gpu_mem_used_bytes against strata:gpu_mem_total_bytes"
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
                  decimal_precision = "1"
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
                            metric_name       = "strata:gpu_mem_used_bytes"
                            time_aggregation  = "avg"
                            space_aggregation = "avg"
                          },
                        ]
                        filter = {
                          expression = "host.name = 'bee-gpu-server' AND model_name IN $model"
                        }
                        group_by = [
                          {
                            name            = "gpu"
                            field_context   = "attribute"
                            field_data_type = "string"
                          },
                        ]
                        having = {
                          expression = ""
                        }
                        legend = "used GPU {{gpu}}"
                      }
                    }
                  }
                }
              }
            },
            {
              kind = "time_series"
              spec = {
                name = "B"
                plugin = {
                  builder_query = {
                    kind = "signoz/BuilderQuery"
                    spec = {
                      metrics = {
                        name          = "B"
                        step_interval = "60"
                        signal        = "metrics"
                        aggregations = [
                          {
                            metric_name       = "strata:gpu_mem_total_bytes"
                            time_aggregation  = "avg"
                            space_aggregation = "avg"
                          },
                        ]
                        filter = {
                          expression = "host.name = 'bee-gpu-server' AND model_name IN $model"
                        }
                        group_by = [
                          {
                            name            = "gpu"
                            field_context   = "attribute"
                            field_data_type = "string"
                          },
                        ]
                        having = {
                          expression = ""
                        }
                        legend = "total GPU {{gpu}}"
                      }
                    }
                  }
                }
              }
            },
          ]
        }
      }
      "gpu_temp" = {
        kind = "Panel"
        spec = {
          display = {
            name        = "GPU temperature"
            description = "strata:gpu_temp_celsius per GPU"
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
                  unit              = "celsius"
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
                    value = 80
                    label = "Warm"
                    unit  = "celsius"
                  },
                  {
                    color = "#ef4444"
                    value = 90
                    label = "Hot"
                    unit  = "celsius"
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
                            metric_name       = "strata:gpu_temp_celsius"
                            time_aggregation  = "avg"
                            space_aggregation = "avg"
                          },
                        ]
                        filter = {
                          expression = "host.name = 'bee-gpu-server' AND model_name IN $model"
                        }
                        group_by = [
                          {
                            name            = "gpu"
                            field_context   = "attribute"
                            field_data_type = "string"
                          },
                        ]
                        having = {
                          expression = ""
                        }
                        legend = "GPU {{gpu}}"
                      }
                    }
                  }
                }
              }
            },
          ]
        }
      }
      "gpu_power" = {
        kind = "Panel"
        spec = {
          display = {
            name        = "GPU power draw"
            description = "strata:gpu_power_watts per GPU"
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
                  unit              = "watt"
                  decimal_precision = "1"
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
                            metric_name       = "strata:gpu_power_watts"
                            time_aggregation  = "avg"
                            space_aggregation = "avg"
                          },
                        ]
                        filter = {
                          expression = "host.name = 'bee-gpu-server' AND model_name IN $model"
                        }
                        group_by = [
                          {
                            name            = "gpu"
                            field_context   = "attribute"
                            field_data_type = "string"
                          },
                        ]
                        having = {
                          expression = ""
                        }
                        legend = "GPU {{gpu}}"
                      }
                    }
                  }
                }
              }
            },
          ]
        }
      }
      "live_tok_s" = {
        kind = "Panel"
        spec = {
          display = {
            name        = "Live tokens/s"
            description = "strata:live_tok_s"
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
                  unit              = "ops"
                  decimal_precision = "1"
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
                            metric_name       = "strata:live_tok_s"
                            time_aggregation  = "avg"
                            space_aggregation = "avg"
                          },
                        ]
                        filter = {
                          expression = "host.name = 'bee-gpu-server' AND model_name IN $model"
                        }
                        having = {
                          expression = ""
                        }
                        legend = "tok/s"
                      }
                    }
                  }
                }
              }
            },
          ]
        }
      }
      "last_decode_tok_s" = {
        kind = "Panel"
        spec = {
          display = {
            name        = "Last decode tokens/s"
            description = "strata:last_decode_tok_s"
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
                  unit              = "ops"
                  decimal_precision = "1"
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
                            metric_name       = "strata:last_decode_tok_s"
                            time_aggregation  = "avg"
                            space_aggregation = "avg"
                          },
                        ]
                        filter = {
                          expression = "host.name = 'bee-gpu-server' AND model_name IN $model"
                        }
                        having = {
                          expression = ""
                        }
                        legend = "decode tok/s"
                      }
                    }
                  }
                }
              }
            },
          ]
        }
      }
      "last_hit_rate" = {
        kind = "Panel"
        spec = {
          display = {
            name        = "Last prefix-cache hit rate"
            description = "strata:last_hit_rate"
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
                  decimal_precision = "3"
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
                  soft_max     = 1
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
                            metric_name       = "strata:last_hit_rate"
                            time_aggregation  = "avg"
                            space_aggregation = "avg"
                          },
                        ]
                        filter = {
                          expression = "host.name = 'bee-gpu-server' AND model_name IN $model"
                        }
                        having = {
                          expression = ""
                        }
                        legend = "hit rate"
                      }
                    }
                  }
                }
              }
            },
          ]
        }
      }
      "live_state" = {
        kind = "Panel"
        spec = {
          display = {
            name        = "Engine state"
            description = "strata:live_state grouped by state label"
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
                            metric_name       = "strata:live_state"
                            time_aggregation  = "max"
                            space_aggregation = "max"
                          },
                        ]
                        filter = {
                          expression = "host.name = 'bee-gpu-server' AND model_name IN $model"
                        }
                        group_by = [
                          {
                            name            = "state"
                            field_context   = "attribute"
                            field_data_type = "string"
                          },
                        ]
                        having = {
                          expression = ""
                        }
                        legend = "{{state}}"
                      }
                    }
                  }
                }
              }
            },
          ]
        }
      }
      "ram" = {
        kind = "Panel"
        spec = {
          display = {
            name        = "Strata RAM used and total"
            description = "strata:ram_used_bytes against strata:ram_total_bytes"
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
                  decimal_precision = "1"
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
                            metric_name       = "strata:ram_used_bytes"
                            time_aggregation  = "avg"
                            space_aggregation = "avg"
                          },
                        ]
                        filter = {
                          expression = "host.name = 'bee-gpu-server' AND model_name IN $model"
                        }
                        having = {
                          expression = ""
                        }
                        legend = "used"
                      }
                    }
                  }
                }
              }
            },
            {
              kind = "time_series"
              spec = {
                name = "B"
                plugin = {
                  builder_query = {
                    kind = "signoz/BuilderQuery"
                    spec = {
                      metrics = {
                        name          = "B"
                        step_interval = "60"
                        signal        = "metrics"
                        aggregations = [
                          {
                            metric_name       = "strata:ram_total_bytes"
                            time_aggregation  = "avg"
                            space_aggregation = "avg"
                          },
                        ]
                        filter = {
                          expression = "host.name = 'bee-gpu-server' AND model_name IN $model"
                        }
                        having = {
                          expression = ""
                        }
                        legend = "total"
                      }
                    }
                  }
                }
              }
            },
          ]
        }
      }
      "requests_running" = {
        kind = "Panel"
        spec = {
          display = {
            name        = "vLLM requests running"
            description = "vllm:num_requests_running"
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
                            metric_name       = "vllm:num_requests_running"
                            time_aggregation  = "avg"
                            space_aggregation = "avg"
                          },
                        ]
                        filter = {
                          expression = "host.name = 'bee-gpu-server' AND model_name IN $model"
                        }
                        having = {
                          expression = ""
                        }
                        legend = "running"
                      }
                    }
                  }
                }
              }
            },
          ]
        }
      }
      "requests_waiting" = {
        kind = "Panel"
        spec = {
          display = {
            name        = "vLLM requests waiting"
            description = "vllm:num_requests_waiting"
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
                            metric_name       = "vllm:num_requests_waiting"
                            time_aggregation  = "avg"
                            space_aggregation = "avg"
                          },
                        ]
                        filter = {
                          expression = "host.name = 'bee-gpu-server' AND model_name IN $model"
                        }
                        having = {
                          expression = ""
                        }
                        legend = "waiting"
                      }
                    }
                  }
                }
              }
            },
          ]
        }
      }
      "success_rate" = {
        kind = "Panel"
        spec = {
          display = {
            name        = "vLLM successful requests/s"
            description = "vllm:request_success_total rate"
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
                  unit              = "ops"
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
                            metric_name       = "vllm:request_success_total"
                            time_aggregation  = "rate"
                            space_aggregation = "sum"
                          },
                        ]
                        filter = {
                          expression = "host.name = 'bee-gpu-server' AND model_name IN $model"
                        }
                        having = {
                          expression = ""
                        }
                        legend = "success/s"
                      }
                    }
                  }
                }
              }
            },
          ]
        }
      }
      "prompt_tokens" = {
        kind = "Panel"
        spec = {
          display = {
            name        = "Prompt tokens/s"
            description = "vllm:prompt_tokens_total rate"
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
                  unit              = "ops"
                  decimal_precision = "1"
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
                            metric_name       = "vllm:prompt_tokens_total"
                            time_aggregation  = "rate"
                            space_aggregation = "sum"
                          },
                        ]
                        filter = {
                          expression = "host.name = 'bee-gpu-server' AND model_name IN $model"
                        }
                        having = {
                          expression = ""
                        }
                        legend = "prompt tok/s"
                      }
                    }
                  }
                }
              }
            },
          ]
        }
      }
      "generation_tokens" = {
        kind = "Panel"
        spec = {
          display = {
            name        = "Generation tokens/s"
            description = "vllm:generation_tokens_total rate"
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
                  unit              = "ops"
                  decimal_precision = "1"
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
                            metric_name       = "vllm:generation_tokens_total"
                            time_aggregation  = "rate"
                            space_aggregation = "sum"
                          },
                        ]
                        filter = {
                          expression = "host.name = 'bee-gpu-server' AND model_name IN $model"
                        }
                        having = {
                          expression = ""
                        }
                        legend = "generation tok/s"
                      }
                    }
                  }
                }
              }
            },
          ]
        }
      }
      "kv_cache" = {
        kind = "Panel"
        spec = {
          display = {
            name        = "vLLM KV-cache usage"
            description = "vllm:kv_cache_usage_perc"
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
                  soft_max     = 1
                  is_log_scale = false
                }
                legend = {
                  position = "bottom"
                  mode     = "list"
                }
                thresholds = [
                  {
                    color = "#eab308"
                    value = 0.8
                    label = "80%"
                    unit  = "percentunit"
                  },
                  {
                    color = "#ef4444"
                    value = 0.95
                    label = "95%"
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
                  builder_query = {
                    kind = "signoz/BuilderQuery"
                    spec = {
                      metrics = {
                        name          = "A"
                        step_interval = "60"
                        signal        = "metrics"
                        aggregations = [
                          {
                            metric_name       = "vllm:kv_cache_usage_perc"
                            time_aggregation  = "avg"
                            space_aggregation = "avg"
                          },
                        ]
                        filter = {
                          expression = "host.name = 'bee-gpu-server' AND model_name IN $model"
                        }
                        having = {
                          expression = ""
                        }
                        legend = "KV cache"
                      }
                    }
                  }
                }
              }
            },
          ]
        }
      }
      "prefix_hit_ratio" = {
        kind = "Panel"
        spec = {
          display = {
            name        = "Prefix-cache hit ratio"
            description = "vllm:prefix_cache_hits_total / vllm:prefix_cache_queries_total"
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
                  decimal_precision = "3"
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
                  soft_max     = 1
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
                            metric_name       = "vllm:prefix_cache_hits_total"
                            time_aggregation  = "rate"
                            space_aggregation = "sum"
                          },
                        ]
                        filter = {
                          expression = "host.name = 'bee-gpu-server' AND model_name IN $model"
                        }
                        having = {
                          expression = ""
                        }
                        legend = "hits"
                      }
                    }
                  }
                }
              }
            },
            {
              kind = "time_series"
              spec = {
                name = "B"
                plugin = {
                  builder_query = {
                    kind = "signoz/BuilderQuery"
                    spec = {
                      metrics = {
                        name          = "B"
                        step_interval = "60"
                        signal        = "metrics"
                        aggregations = [
                          {
                            metric_name       = "vllm:prefix_cache_queries_total"
                            time_aggregation  = "rate"
                            space_aggregation = "sum"
                          },
                        ]
                        filter = {
                          expression = "host.name = 'bee-gpu-server' AND model_name IN $model"
                        }
                        having = {
                          expression = ""
                        }
                        legend = "queries"
                      }
                    }
                  }
                }
              }
            },
            {
              kind = "time_series"
              spec = {
                name = "C"
                plugin = {
                  formula = {
                    kind = "signoz/Formula"
                    spec = {
                      name       = "C"
                      expression = "A / B"
                      legend     = "hit ratio"
                    }
                  }
                }
              }
            },
          ]
        }
      }
      "spec_decode" = {
        kind = "Panel"
        spec = {
          display = {
            name        = "Spec-decode acceptance"
            description = "vllm:spec_decode_num_accepted_tokens_total / vllm:spec_decode_num_draft_tokens_total"
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
                  decimal_precision = "3"
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
                  soft_max     = 1
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
                            metric_name       = "vllm:spec_decode_num_accepted_tokens_total"
                            time_aggregation  = "rate"
                            space_aggregation = "sum"
                          },
                        ]
                        filter = {
                          expression = "host.name = 'bee-gpu-server' AND model_name IN $model"
                        }
                        having = {
                          expression = ""
                        }
                        legend = "accepted"
                      }
                    }
                  }
                }
              }
            },
            {
              kind = "time_series"
              spec = {
                name = "B"
                plugin = {
                  builder_query = {
                    kind = "signoz/BuilderQuery"
                    spec = {
                      metrics = {
                        name          = "B"
                        step_interval = "60"
                        signal        = "metrics"
                        aggregations = [
                          {
                            metric_name       = "vllm:spec_decode_num_draft_tokens_total"
                            time_aggregation  = "rate"
                            space_aggregation = "sum"
                          },
                        ]
                        filter = {
                          expression = "host.name = 'bee-gpu-server' AND model_name IN $model"
                        }
                        having = {
                          expression = ""
                        }
                        legend = "draft"
                      }
                    }
                  }
                }
              }
            },
            {
              kind = "time_series"
              spec = {
                name = "C"
                plugin = {
                  formula = {
                    kind = "signoz/Formula"
                    spec = {
                      name       = "C"
                      expression = "A / B"
                      legend     = "acceptance"
                    }
                  }
                }
              }
            },
          ]
        }
      }
      "e2e_latency" = {
        kind = "Panel"
        spec = {
          display = {
            name        = "End-to-end latency"
            description = "vllm:e2e_request_latency_seconds percentiles from the histogram buckets"
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
                  decimal_precision = "3"
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
                            metric_name       = "vllm:e2e_request_latency_seconds.bucket"
                            time_aggregation  = "rate"
                            space_aggregation = "p50"
                          },
                        ]
                        filter = {
                          expression = "host.name = 'bee-gpu-server' AND model_name IN $model"
                        }
                        having = {
                          expression = ""
                        }
                        legend = "p50"
                      }
                    }
                  }
                }
              }
            },
            {
              kind = "time_series"
              spec = {
                name = "B"
                plugin = {
                  builder_query = {
                    kind = "signoz/BuilderQuery"
                    spec = {
                      metrics = {
                        name          = "B"
                        step_interval = "60"
                        signal        = "metrics"
                        aggregations = [
                          {
                            metric_name       = "vllm:e2e_request_latency_seconds.bucket"
                            time_aggregation  = "rate"
                            space_aggregation = "p95"
                          },
                        ]
                        filter = {
                          expression = "host.name = 'bee-gpu-server' AND model_name IN $model"
                        }
                        having = {
                          expression = ""
                        }
                        legend = "p95"
                      }
                    }
                  }
                }
              }
            },
            {
              kind = "time_series"
              spec = {
                name = "C"
                plugin = {
                  builder_query = {
                    kind = "signoz/BuilderQuery"
                    spec = {
                      metrics = {
                        name          = "C"
                        step_interval = "60"
                        signal        = "metrics"
                        aggregations = [
                          {
                            metric_name       = "vllm:e2e_request_latency_seconds.bucket"
                            time_aggregation  = "rate"
                            space_aggregation = "p99"
                          },
                        ]
                        filter = {
                          expression = "host.name = 'bee-gpu-server' AND model_name IN $model"
                        }
                        having = {
                          expression = ""
                        }
                        legend = "p99"
                      }
                    }
                  }
                }
              }
            },
          ]
        }
      }
      "ttft" = {
        kind = "Panel"
        spec = {
          display = {
            name        = "Time to first token"
            description = "vllm:time_to_first_token_seconds percentiles"
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
                  decimal_precision = "3"
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
                            metric_name       = "vllm:time_to_first_token_seconds.bucket"
                            time_aggregation  = "rate"
                            space_aggregation = "p50"
                          },
                        ]
                        filter = {
                          expression = "host.name = 'bee-gpu-server' AND model_name IN $model"
                        }
                        having = {
                          expression = ""
                        }
                        legend = "p50"
                      }
                    }
                  }
                }
              }
            },
            {
              kind = "time_series"
              spec = {
                name = "B"
                plugin = {
                  builder_query = {
                    kind = "signoz/BuilderQuery"
                    spec = {
                      metrics = {
                        name          = "B"
                        step_interval = "60"
                        signal        = "metrics"
                        aggregations = [
                          {
                            metric_name       = "vllm:time_to_first_token_seconds.bucket"
                            time_aggregation  = "rate"
                            space_aggregation = "p95"
                          },
                        ]
                        filter = {
                          expression = "host.name = 'bee-gpu-server' AND model_name IN $model"
                        }
                        having = {
                          expression = ""
                        }
                        legend = "p95"
                      }
                    }
                  }
                }
              }
            },
            {
              kind = "time_series"
              spec = {
                name = "C"
                plugin = {
                  builder_query = {
                    kind = "signoz/BuilderQuery"
                    spec = {
                      metrics = {
                        name          = "C"
                        step_interval = "60"
                        signal        = "metrics"
                        aggregations = [
                          {
                            metric_name       = "vllm:time_to_first_token_seconds.bucket"
                            time_aggregation  = "rate"
                            space_aggregation = "p99"
                          },
                        ]
                        filter = {
                          expression = "host.name = 'bee-gpu-server' AND model_name IN $model"
                        }
                        having = {
                          expression = ""
                        }
                        legend = "p99"
                      }
                    }
                  }
                }
              }
            },
          ]
        }
      }
      "inter_token_latency" = {
        kind = "Panel"
        spec = {
          display = {
            name        = "Inter-token latency"
            description = "vllm:inter_token_latency_seconds percentiles"
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
                  decimal_precision = "4"
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
                            metric_name       = "vllm:inter_token_latency_seconds.bucket"
                            time_aggregation  = "rate"
                            space_aggregation = "p50"
                          },
                        ]
                        filter = {
                          expression = "host.name = 'bee-gpu-server' AND model_name IN $model"
                        }
                        having = {
                          expression = ""
                        }
                        legend = "p50"
                      }
                    }
                  }
                }
              }
            },
            {
              kind = "time_series"
              spec = {
                name = "B"
                plugin = {
                  builder_query = {
                    kind = "signoz/BuilderQuery"
                    spec = {
                      metrics = {
                        name          = "B"
                        step_interval = "60"
                        signal        = "metrics"
                        aggregations = [
                          {
                            metric_name       = "vllm:inter_token_latency_seconds.bucket"
                            time_aggregation  = "rate"
                            space_aggregation = "p95"
                          },
                        ]
                        filter = {
                          expression = "host.name = 'bee-gpu-server' AND model_name IN $model"
                        }
                        having = {
                          expression = ""
                        }
                        legend = "p95"
                      }
                    }
                  }
                }
              }
            },
            {
              kind = "time_series"
              spec = {
                name = "C"
                plugin = {
                  builder_query = {
                    kind = "signoz/BuilderQuery"
                    spec = {
                      metrics = {
                        name          = "C"
                        step_interval = "60"
                        signal        = "metrics"
                        aggregations = [
                          {
                            metric_name       = "vllm:inter_token_latency_seconds.bucket"
                            time_aggregation  = "rate"
                            space_aggregation = "p99"
                          },
                        ]
                        filter = {
                          expression = "host.name = 'bee-gpu-server' AND model_name IN $model"
                        }
                        having = {
                          expression = ""
                        }
                        legend = "p99"
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
              title = "Endpoint"
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
                  ref = "#/spec/panels/gpu_util"
                }
              },
              {
                x      = 3
                y      = 0
                width  = 3
                height = 6
                content = {
                  ref = "#/spec/panels/gpu_memory"
                }
              },
              {
                x      = 6
                y      = 0
                width  = 3
                height = 6
                content = {
                  ref = "#/spec/panels/gpu_temp"
                }
              },
              {
                x      = 9
                y      = 0
                width  = 3
                height = 6
                content = {
                  ref = "#/spec/panels/gpu_power"
                }
              },
              {
                x      = 0
                y      = 6
                width  = 3
                height = 6
                content = {
                  ref = "#/spec/panels/live_tok_s"
                }
              },
              {
                x      = 3
                y      = 6
                width  = 3
                height = 6
                content = {
                  ref = "#/spec/panels/last_decode_tok_s"
                }
              },
              {
                x      = 6
                y      = 6
                width  = 3
                height = 6
                content = {
                  ref = "#/spec/panels/last_hit_rate"
                }
              },
              {
                x      = 9
                y      = 6
                width  = 3
                height = 6
                content = {
                  ref = "#/spec/panels/live_state"
                }
              },
              {
                x      = 0
                y      = 12
                width  = 4
                height = 6
                content = {
                  ref = "#/spec/panels/ram"
                }
              },
              {
                x      = 4
                y      = 12
                width  = 4
                height = 6
                content = {
                  ref = "#/spec/panels/requests_running"
                }
              },
              {
                x      = 8
                y      = 12
                width  = 4
                height = 6
                content = {
                  ref = "#/spec/panels/requests_waiting"
                }
              },
              {
                x      = 0
                y      = 18
                width  = 4
                height = 6
                content = {
                  ref = "#/spec/panels/success_rate"
                }
              },
              {
                x      = 4
                y      = 18
                width  = 4
                height = 6
                content = {
                  ref = "#/spec/panels/prompt_tokens"
                }
              },
              {
                x      = 8
                y      = 18
                width  = 4
                height = 6
                content = {
                  ref = "#/spec/panels/generation_tokens"
                }
              },
              {
                x      = 0
                y      = 24
                width  = 4
                height = 6
                content = {
                  ref = "#/spec/panels/kv_cache"
                }
              },
              {
                x      = 4
                y      = 24
                width  = 4
                height = 6
                content = {
                  ref = "#/spec/panels/prefix_hit_ratio"
                }
              },
              {
                x      = 8
                y      = 24
                width  = 4
                height = 6
                content = {
                  ref = "#/spec/panels/spec_decode"
                }
              },
              {
                x      = 0
                y      = 30
                width  = 4
                height = 6
                content = {
                  ref = "#/spec/panels/e2e_latency"
                }
              },
              {
                x      = 4
                y      = 30
                width  = 4
                height = 6
                content = {
                  ref = "#/spec/panels/ttft"
                }
              },
              {
                x      = 8
                y      = 30
                width  = 4
                height = 6
                content = {
                  ref = "#/spec/panels/inter_token_latency"
                }
              },
            ]
          }
        }
      },
    ]
  }
}
