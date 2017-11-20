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
            ems = $evm.vmdb(:ExtManagementSystem).find_by(:name => ems_name)

            miq_templates = ems.miq_templates unless ems.blank?

            list = {}
            if miq_templates
              miq_templates.each do |img|
                # image_list[img.guid] = img.name if img.name.match(/(rhel7|windows)/i)
                list[img.name] = img.name if img.name.match(/(rhel7|windows)/i)
              end
            end

            return nil => "<none>" if list.blank?

            list[nil] = "<select>" if list.length > 1
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
        end
      end
    end
  end
end

$evm.root.attributes.sort.each { |k, v| $evm.log(:info, "\t Attribute: #{k} = #{v}")}

if __FILE__ == $PROGRAM_NAME
  TigerIQ::Automate::Integration::Methods::DoStuff.new.main
end
