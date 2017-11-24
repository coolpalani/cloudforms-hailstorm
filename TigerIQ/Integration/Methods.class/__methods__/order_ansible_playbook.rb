#
# Description:
#

def service_template
  stap  = $evm.vmdb(:ServiceTemplate).find_by(:name => playbook, :type => "ServiceTemplateAnsiblePlaybook")
  stap.nil? ? (raise "ServiceTemplateAnsiblePlaybook <#{playbook}> not found") : stap
end

def extra_vars
  playbook_extra_vars = {}
  playbook_and_vars.select{|pb, vars|
    match_data = EXTRA_VAR_REGEX.match(vars)
    playbook_extra_vars["param_#{match_data[1]}"] = match_data[2].downcase if match_data
  }
  playbook_extra_vars
end

def machine_credential
  image_name = @prov.source.name
  credential = $evm.vmdb(AUTH_CLASS).find_by(:name => image_name) || nil
  credential.nil? ? (raise "Credential matching image <#{image_name}> not found") : credential.id
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
    exit MIQ_OK
  else
    required_ip = vm.ipaddresses.find_all{|ip|ip.match(/^10./)}.first
    # required_ip = vm.ipaddresses.first
    required_ip.nil? ? (raise "Valid IP not found") : required_ip
  end
end

def order_playbook
  request = $evm.execute('create_service_provision_request',
    service_template,
    extra_vars.merge(:credential => machine_credential, :hosts => hosts)
  )
  playbook_stpr_id = request.id # ServiceTemplateProvisionRequest
  $evm.log(:info, "Submitted provision request #{playbook_stpr_id} for service template #{service_template}")
  $evm.set_state_var("playbook_stpr_id", playbook_stpr_id)
end

def playbook_and_vars
  # "ansible_inside"=>{"lamp_simple_rhel7"=>"roles=Apache,TomCat"}
  # {"lamp_simple_rhel7"=>"roles=Apache,TomCat"}
  @prov.options[:ws_values][:ansible_inside]
end

def playbook
  playbook_and_vars.keys.first
end

def add_playbook_service(playbook_stpr_id)
  $evm.log(:info, "add_playbook_service")

  playbook_stpr = $evm.vmdb(:ServiceTemplateProvisionRequest).find_by(:id => playbook_stpr_id)

  unless playbook_stpr.nil?
    $evm.log(:info, "playbook_stpr: #{playbook_stpr.inspect}")
    $evm.log(:info, "playbook_stpr_id: #{playbook_stpr.id}")
    $evm.log(:info, "miq_request_tasks: #{playbook_stpr.miq_request_tasks.count}")

    if playbook_stpr.miq_request_tasks.count == 0
      $evm.root['ae_result'] = 'retry'
      $evm.root['ae_retry_interval'] = 1.minute
      exit MIQ_OK
    end

    playbook_service = playbook_stpr.miq_request_tasks.first.destination

    unless playbook_service.nil?
      $evm.log(:info, "playbook_service_id: #{playbook_service.id}")
      $evm.log(:info, "playbook_service: #{playbook_service.inspect}")
      parent_service_id = @prov.options[:ws_values][:service_id]
      $evm.log(:info, "parent_service_id: #{parent_service_id}")
      parent_service    = $evm.vmdb(:Service).find_by(:id => parent_service_id)

      unless parent_service.nil?
        $evm.log(:info, "Setting parent service")
        playbook_service.parent_service = parent_service
      end

      $evm.set_state_var("playbook_service_association", "executed")
    end
  end
end

# Do stuff

AUTH_CLASS = "ManageIQ_Providers_AutomationManager_Authentication".freeze
EXTRA_VAR_REGEX = Regexp.new(/(.*)=(.*)/)

@prov = $evm.root["miq_provision"]

if $evm.state_var_exist?("playbook_service_association")
  $evm.log(:info, "Phase 3 - Then check the request status")

  playbook_stpr_id = $evm.get_state_var("playbook_stpr_id")
  playbook_stpr = $evm.vmdb(:ServiceTemplateProvisionRequest).find_by(:id => playbook_stpr_id)

  unless playbook_stpr.nil?
    $evm.log(:info, "playbook_stpr Status:#{playbook_stpr.status} State:#{playbook_stpr.state}")

    if playbook_stpr.status == "Error"
      exit MIQ_ERROR
    elsif playbook_stpr.state == "finished"
      exit MIQ_OK
    else
      $evm.root['ae_result'] = 'retry'
      $evm.root['ae_retry_interval'] = 1.minute
      exit MIQ_OK
    end
  end
  
elsif $evm.state_var_exist?("playbook_stpr_id")
  $evm.log(:info, "Phase 2 - Associate the playbook service with the parent service")

  playbook_stpr_id = $evm.get_state_var("playbook_stpr_id")
  add_playbook_service(playbook_stpr_id)

  # Retry to enter next phase 
  $evm.root['ae_result'] = 'retry'
  $evm.root['ae_retry_interval'] = 1.minute
  exit MIQ_OK

else
  $evm.log(:info, "Phase 1 - Order the playbook service")
  order_playbook
  # Retry to enter next phase 
  $evm.root['ae_result'] = 'retry'
  $evm.root['ae_retry_interval'] = 1.minute
  exit MIQ_OK
end
