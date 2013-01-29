module PgTools
  module ActsAsTenantAware
    def acts_as_tenant_aware
      class_eval do
        after_create :prepare_tenant 

        private
        def prepare_tenant
          unless PgTools.schemas.include?(id.to_s)
            create_schema
            load_tables
          end
        end

        def create_schema
          PgTools.create_schema id
        end

        def load_tables
          PgTools.in_search_path(id) { 
            load "#{Rails.root}/db/private/schema.rb"
          }
        end
      end
    end
  end
end
ActiveRecord::Base.extend PgTools::ActsAsTenantAware

