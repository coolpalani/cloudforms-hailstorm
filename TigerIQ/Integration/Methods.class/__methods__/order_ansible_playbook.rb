#
# Description:
#

def service_template
  pb    = play_book
  stap  = $evm.vmdb(:ServiceTemplate).find_by(:name => pb, :type => "ServiceTemplateAnsiblePlaybook")
  stap.nil? ? raise "ServiceTemplateAnsiblePlaybook <#{pb}> not found" : pb
  # 'Apache'
end

def extra_vars
  # key_list = $evm.root.attributes.keys.select { |k| k.start_with?('dialog_param') }
  key_list = {}
  key_list.each_with_object({}) do |key, hash|
    match_data = ANSIBLE_DIALOG_VAR_REGEX.match(key)
    hash["param_#{match_data[1]}"] = $evm.root[key] if match_data
  end
end

def machine_credential
  image      = @prov.source.name
  credential = $evm.vmdb(AUTH_CLASS).find_by(:name => image) || nil
  credential.nil? ? raise "Credential match image <#{image} not found" : credential.id
end

def hosts
  vm = @prov.vm
  
  ip_list = vm.ipaddresses
  $evm.log(:info, "Current Power State: #{vm.power_state}")
  $evm.log(:info, "IP addresses for VM: #{ip_list}")
  
  if ip_list.empty?
    $evm.log(:warn, "No IP addresses found, retry")
    vm.refresh
    $evm.root['ae_result'] = 'retry'
    $evm.root['ae_retry_interval'] = 1.minute
    exit MIQ_RETRY
  else
    # vm.ipaddresses.find_all{|ip|ip.match(/^10./)}
    vm.ipaddresses.first
  end
end

def order_playbook
  request = $evm.execute('create_service_provision_request',
    service_template,
    extra_vars.merge(:credential => machine_credential, :hosts => hosts)
  )
  $evm.log(:info, "Submitted provision request #{request.id} for service template #{service_template}")
end

def play_book
  @prov.options[:ws_values][:ansible_inside]
end

# Do stuff

AUTH_CLASS = "ManageIQ_Providers_AutomationManager_Authentication".freeze
ANSIBLE_DIALOG_VAR_REGEX = Regexp.new(/dialog_param_(.*)/)

@prov = $evm.root["miq_provision"]

order_playbook unless play_book.nil?
