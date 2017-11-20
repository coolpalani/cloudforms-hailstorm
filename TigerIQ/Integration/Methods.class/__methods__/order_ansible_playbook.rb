#
# Description:
#
def get_credential(prov)
  image      = prov.source.name
  # credential = $evm.vmdb(AUTH_CLASS).find_all{|c| c.name.downcase == image.downcase}
  # return credential.id unless credential.nil?
  credential = nil
  $evm.vmdb(AUTH_CLASS).all.each do |c|
    credential = c if c.name.downcase == image.downcase
  end
  return credential.id unless credential.nil?
end

def service_template_name(prov)
  # prov.options[:ws_values][:ansible_inside]
  'Apache'
end

AUTH_CLASS = "ManageIQ_Providers_AutomationManager_Authentication".freeze

prov = $evm.root["miq_provision"]
vm = prov.vm

ip_list = vm.ipaddresses
$evm.log(:info, "Current Power State: #{vm.power_state}")
$evm.log(:info, "IP addresses for VM: #{ip_list}")

if ip_list.empty?
  $evm.log(:warn, "No IP addresses found")
  vm.refresh
  $evm.root['ae_result'] = 'retry'
  $evm.root['ae_retry_interval'] = 1.minute

else
  # valid_ip = vm.ipaddresses.find_all{|ip|ip.match(/^10./)}
  valid_ip = vm.ipaddresses.first
  $evm.log(:info, "Valid IP: #{valid_ip}")

  # vm.floating_ip
  # vm.floating_ips

  if valid_ip
    # Set Service (playbook)
    $evm.root['service_template_name'] = service_template_name(prov)

    # Set credential (credential name must match image name)
    $evm.root['dialog_credential'] = get_credential(prov)

    # Set limit
    $evm.root['dialog_hosts'] = valid_ip

    # Set extra vars
    $evm.root['dialog_param_something'] = 'something interesting'

    $evm.root.attributes.sort.each { |k, v| $evm.log(:info, "\t Attribute: #{k} = #{v}")}

    if $evm.root['service_template_name'].nil? || $evm.root['dialog_credential'].nil? || $evm.root['dialog_hosts'].nil?
      $evm.log(:warn, "Required $evm.root dialogue variable missing")
    else
      $evm.instantiate('/System/Request/Order_Ansible_Playbook')

      sleep 2.minute
      # $evm.set_state_var("Ansible job request", request.id)
      if $evm.state_var_exist?("Ansible job request")
        10.times { $evm.log(:info, $evm.get_state_var("Ansible job request")) }
      else
        10.times { $evm.log(:info, "'Ansible job request' missing") }
      end
    end
  else
    $evm.log(:warn, "No public IP address found")
  end
end
