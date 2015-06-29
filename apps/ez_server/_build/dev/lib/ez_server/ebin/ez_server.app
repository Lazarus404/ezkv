{application,ez_server,
             [{registered,[]},
              {description,"ez_server"},
              {applications,[kernel,stdlib,elixir,logger]},
              {mod,{'Elixir.EZServer',[]}},
              {vsn,"0.0.1"},
              {modules,['Elixir.EZ.Transport.Supervisor',
                        'Elixir.EZ.Transport.TCP.Client',
                        'Elixir.EZ.Transport.TCP.Listener',
                        'Elixir.EZ.Transport.TCP.Supervisor',
                        'Elixir.EZ.Transport.UDP.Listener',
                        'Elixir.EZServer']}]}.