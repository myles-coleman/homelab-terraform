# Agent Traces dashboard (SigNoz v2 / Perses schema v6).
#
# Managed by Terragrunt. State is isolated per dashboard unit.
#
# Series verified against the live store before authoring (24-hour span-name
# inventory, 4507 spans): Plugin.load, FileSystem.resolve, http.server GET,
# State.notify, FileSystem.readFileStringSafe, Integration.list, Credential.all,
# Provider.snapshot, FileSystem.isDir, Model.snapshot, ...
#
# Deliberately omitted, because the data does not exist:
#   - a Tool.execute duration distribution: the pinned agent build emits no
#     Tool.execute span (and no model-call span), so there is nothing to chart.
#   - a model-call vs tool-call latency split: the same absence.
#   - p50/p95 spans per trace: the provider's builder has no two-stage
#     aggregation over trace_id, and grouping a time series by trace_id is
#     forbidden by the spec's cardinality rule.

resource "signoz_dashboard" "agent_traces" {
  schema_version = "v6"
  name           = "agent-traces"
  tags = [
    { key = "tag", value = "homelab" },
    { key = "tag", value = "traces" },
  ]

  spec = {
    display = {
      name        = "Agent Traces"
      description = "OpenCode agent behaviour: span volume and latency by name, uncaught failures, correlated error logs, and the slowest recent traces."
    }
    links = []

    variables = []

    panels = {
      "heartbeat" = {
        kind = "Panel"
        spec = {
          display = {
            name        = "Span ingest heartbeat"
            description = "Span count for deployment.environment = agent-sandbox. A no-data state means ingest stopped; zero means the agent was idle."
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
                      traces = {
                        name          = "A"
                        step_interval = "60"
                        signal        = "traces"
                        aggregations = [
                          {
                            expression = "count()"
                          },
                        ]
                        filter = {
                          expression = "deployment.environment = 'agent-sandbox'"
                        }
                        having = {
                          expression = ""
                        }
                        legend = "spans"
                      }
                    }
                  }
                }
              }
            },
          ]
        }
      }
      "span_volume" = {
        kind = "Panel"
        spec = {
          display = {
            name        = "Span volume per minute"
            description = "count() by span name, top 10 in the window"
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
                      traces = {
                        name          = "A"
                        step_interval = "60"
                        signal        = "traces"
                        aggregations = [
                          {
                            expression = "count()"
                          },
                        ]
                        filter = {
                          expression = "deployment.environment = 'agent-sandbox'"
                        }
                        group_by = [
                          {
                            name            = "name"
                            field_context   = "span"
                            field_data_type = "string"
                          },
                        ]
                        order = [
                          {
                            key = {
                              name = "count()"
                            }
                            direction = "desc"
                          },
                        ]
                        limit = 10
                        having = {
                          expression = ""
                        }
                        legend = "{{name}}"
                      }
                    }
                  }
                }
              }
            },
          ]
        }
      }
      "span_p95" = {
        kind = "Panel"
        spec = {
          display = {
            name        = "p95 duration by span name"
            description = "p95(duration_nano) by span name, top 10 by p95 in the window"
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
                  unit              = "ns"
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
                      traces = {
                        name          = "A"
                        step_interval = "60"
                        signal        = "traces"
                        aggregations = [
                          {
                            expression = "p95(duration_nano)"
                          },
                        ]
                        filter = {
                          expression = "deployment.environment = 'agent-sandbox'"
                        }
                        group_by = [
                          {
                            name            = "name"
                            field_context   = "span"
                            field_data_type = "string"
                          },
                        ]
                        order = [
                          {
                            key = {
                              name = "p95(duration_nano)"
                            }
                            direction = "desc"
                          },
                        ]
                        limit = 10
                        having = {
                          expression = ""
                        }
                        legend = "{{name}}"
                      }
                    }
                  }
                }
              }
            },
          ]
        }
      }
      "error_rate" = {
        kind = "Panel"
        spec = {
          display = {
            name        = "Uncaught error-span rate by name"
            description = "countIf(has_error = true) / count() per span name, top 10 by volume. Handled tool errors are not included."
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
                  soft_max     = 100
                  is_log_scale = false
                }
                legend = {
                  position = "bottom"
                  mode     = "list"
                }
                thresholds = [
                  {
                    color = "#eab308"
                    value = 1
                    label = "Errors present"
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
                      traces = {
                        name          = "A"
                        step_interval = "60"
                        signal        = "traces"
                        aggregations = [
                          {
                            expression = "count()"
                          },
                        ]
                        filter = {
                          expression = "deployment.environment = 'agent-sandbox'"
                        }
                        group_by = [
                          {
                            name            = "name"
                            field_context   = "span"
                            field_data_type = "string"
                          },
                        ]
                        order = [
                          {
                            key = {
                              name = "count()"
                            }
                            direction = "desc"
                          },
                        ]
                        limit = 10
                        having = {
                          expression = ""
                        }
                        legend = "total {{name}}"
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
                      traces = {
                        name          = "B"
                        step_interval = "60"
                        signal        = "traces"
                        aggregations = [
                          {
                            expression = "countIf(has_error = true)"
                          },
                        ]
                        filter = {
                          expression = "deployment.environment = 'agent-sandbox'"
                        }
                        group_by = [
                          {
                            name            = "name"
                            field_context   = "span"
                            field_data_type = "string"
                          },
                        ]
                        order = [
                          {
                            key = {
                              name = "countIf(has_error = true)"
                            }
                            direction = "desc"
                          },
                        ]
                        limit = 10
                        having = {
                          expression = ""
                        }
                        legend = "errors {{name}}"
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
                      expression = "B / A * 100"
                      legend     = "{{name}}"
                    }
                  }
                }
              }
            },
          ]
        }
      }
      "error_logs" = {
        kind = "Panel"
        spec = {
          display = {
            name        = "Error logs"
            description = "severity ERROR records in agent-sandbox; each record carries trace_id for drill-down"
          }
          links = []
          plugin = {
            list_panel = {
              kind = "signoz/ListPanel"
              spec = {
                select_fields = [
                  {
                    name            = "timestamp"
                    field_context   = "log"
                    field_data_type = ""
                  },
                  {
                    name            = "severity_text"
                    field_context   = "log"
                    field_data_type = "string"
                  },
                  {
                    name            = "body"
                    field_context   = "body"
                    field_data_type = "string"
                  },
                  {
                    name            = "trace_id"
                    field_context   = "log"
                    field_data_type = "string"
                  },
                ]
              }
            }
          }
          queries = [
            {
              kind = "raw"
              spec = {
                name = "A"
                plugin = {
                  builder_query = {
                    kind = "signoz/BuilderQuery"
                    spec = {
                      logs = {
                        name   = "A"
                        signal = "logs"
                        filter = {
                          expression = "k8s.namespace.name = 'agent-sandbox' AND severity_text = 'ERROR'"
                        }
                        order = [
                          {
                            key = {
                              name = "timestamp"
                            }
                            direction = "desc"
                          },
                        ]
                        limit = 50
                        select_fields = [
                          {
                            name            = "timestamp"
                            field_context   = "log"
                            field_data_type = ""
                          },
                          {
                            name            = "severity_text"
                            field_context   = "log"
                            field_data_type = "string"
                          },
                          {
                            name            = "body"
                            field_context   = "body"
                            field_data_type = "string"
                          },
                          {
                            name            = "trace_id"
                            field_context   = "log"
                            field_data_type = "string"
                          },
                        ]
                      }
                    }
                  }
                }
              }
            },
          ]
        }
      }
      "slowest_traces" = {
        kind = "Panel"
        spec = {
          display = {
            name        = "Slowest recent traces"
            description = "Trace spans in agent-sandbox ordered by duration, for one-click drill-down"
          }
          links = []
          plugin = {
            list_panel = {
              kind = "signoz/ListPanel"
              spec = {
                select_fields = [
                  {
                    name            = "timestamp"
                    field_context   = "span"
                    field_data_type = ""
                  },
                  {
                    name            = "name"
                    field_context   = "span"
                    field_data_type = "string"
                  },
                  {
                    name            = "duration_nano"
                    field_context   = "span"
                    field_data_type = "int64"
                  },
                  {
                    name            = "trace_id"
                    field_context   = "span"
                    field_data_type = "string"
                  },
                  {
                    name            = "has_error"
                    field_context   = "span"
                    field_data_type = "bool"
                  },
                ]
              }
            }
          }
          queries = [
            {
              kind = "trace"
              spec = {
                name = "A"
                plugin = {
                  builder_query = {
                    kind = "signoz/BuilderQuery"
                    spec = {
                      traces = {
                        name   = "A"
                        signal = "traces"
                        filter = {
                          expression = "deployment.environment = 'agent-sandbox'"
                        }
                        order = [
                          {
                            key = {
                              name = "duration_nano"
                            }
                            direction = "desc"
                          },
                        ]
                        limit = 20
                        select_fields = [
                          {
                            name            = "timestamp"
                            field_context   = "span"
                            field_data_type = ""
                          },
                          {
                            name            = "name"
                            field_context   = "span"
                            field_data_type = "string"
                          },
                          {
                            name            = "duration_nano"
                            field_context   = "span"
                            field_data_type = "int64"
                          },
                          {
                            name            = "trace_id"
                            field_context   = "span"
                            field_data_type = "string"
                          },
                          {
                            name            = "has_error"
                            field_context   = "span"
                            field_data_type = "bool"
                          },
                        ]
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
              title = "Agent"
              collapse = {
                open = true
              }
            }
            items = [
              {
                x      = 0
                y      = 0
                width  = 12
                height = 6
                content = {
                  ref = "#/spec/panels/heartbeat"
                }
              },
              {
                x      = 0
                y      = 6
                width  = 6
                height = 8
                content = {
                  ref = "#/spec/panels/span_volume"
                }
              },
              {
                x      = 6
                y      = 6
                width  = 6
                height = 8
                content = {
                  ref = "#/spec/panels/span_p95"
                }
              },
              {
                x      = 0
                y      = 14
                width  = 6
                height = 7
                content = {
                  ref = "#/spec/panels/error_rate"
                }
              },
              {
                x      = 6
                y      = 14
                width  = 6
                height = 7
                content = {
                  ref = "#/spec/panels/error_logs"
                }
              },
              {
                x      = 0
                y      = 21
                width  = 12
                height = 7
                content = {
                  ref = "#/spec/panels/slowest_traces"
                }
              },
            ]
          }
        }
      },
    ]
  }
}
