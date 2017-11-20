#
# Description:
#
prov = $evm.root["miq_provision"]

# $evm.root.attributes.sort.each { |k, v| $evm.log(:info, "\t Attribute: #{k} = #{v}")}

unless prov.options[:ws_values].nil?
  parent_service_id = prov.options[:ws_values][:service_id]

  unless parent_service_id.nil?

    # parent_service = $evm.vmdb(:Service).find_by_id(parent_service_id)
    parent_service = $evm.vmdb(:Service).find_by(:id => parent_service_id)

    prov.vm.add_to_service(parent_service) unless parent_service.nil?
  end
end
