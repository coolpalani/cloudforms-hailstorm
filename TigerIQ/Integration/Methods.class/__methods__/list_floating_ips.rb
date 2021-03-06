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
            ems = $evm.vmdb(:ExtManagementSystem).find_by(:name => ems_name)
            
            list={}
            ems.floating_ips.each{|i| list[i.id] = i.name if i.cloud_tenant.id == cloud_tenant and i.status == "DOWN" } unless ems.nil?

            return nil => "<none>" if list.blank?

            # list[nil] = "<select>" if list.length > 1
            list
          end

          def fill_dialog_field(list)
            dialog_field = @handle.object

            # sort_by: value / description / none
            dialog_field["sort_by"] = "description"

            # sort_order: ascending / descending
            dialog_field["sort_order"] = "ascending"

            # data_type: string / integer
            dialog_field["data_type"] = "string"

            # required: true / false
            dialog_field["required"] = "true"

            dialog_field["values"] = list
            dialog_field["default_value"] = list.length == 1 ? list.keys.first : nil
          end

          def ems_name
            $evm.root['dialog_region']
          end

          def cloud_tenant
            $evm.root['dialog_tenant'].to_i
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

