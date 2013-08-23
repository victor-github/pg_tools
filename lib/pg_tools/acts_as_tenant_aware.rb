module PgTools
  module ActsAsTenantAware
    def acts_as_tenant_aware(options = {schema_attribute: :id})

      class_attribute :acts_as_tenant_aware_options
      self.acts_as_tenant_aware_options = options

      class_eval do
        after_create :prepare_tenant 

        private
        def prepare_tenant
          unless PgTools.schemas.include?(tenant_schema_name)
            create_schema
            load_tables
          end
        end

        def create_schema
          PgTools.create_schema tenant_schema_name
        end

        def load_tables
          PgTools.in_search_path(tenant_schema_name) {
            load "#{Rails.root}/db/private/schema.rb"
          }
        end

        def tenant_schema_name
          send acts_as_tenant_aware_options[:schema_attribute].to_s
        end
      end
    end
  end
end
ActiveRecord::Base.extend PgTools::ActsAsTenantAware

