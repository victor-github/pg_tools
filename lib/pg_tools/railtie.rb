module PgTools
  class Railtie < Rails::Railtie
    railtie_name :pg_tools

    rake_tasks do
      load "tasks/tenants.rake"
    end
  end
end
