#
# Description:
#
module TigerIQ
  module Automate
    module Integration
      module Methods
        class DoStuff
          def initialize(handle = $evm)
            @handle = handle
          end

          def main
            fill_dialog_field(fetch_list_data)
          end

          private
          
          def fetch_list_data
            ems_name = $evm.root['dialog_region']
            ems = $evm.vmdb(:ExtManagementSystem).find_by(:name=>ems_name)

            if ems.blank?
              return "ATTENTION: Selected Region ExtManagementSystem not valid"
            else
              return "SUCCESS: Region ExtManagementSystem valid"
            end
          end

          def fill_dialog_field(status)
            dialog_field = @handle.object

            dialog_field["value"] = status
          end
        end
      end
    end
  end
end

$evm.root.attributes.sort.each { |k, v| $evm.log(:info, "\t Attribute: #{k} = #{v}")}

if __FILE__ == $PROGRAM_NAME
  TigerIQ::Automate::Integration::Methods::DoStuff.new.main
end

