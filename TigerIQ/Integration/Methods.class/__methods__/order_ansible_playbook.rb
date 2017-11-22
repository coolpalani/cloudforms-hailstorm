#
# Description:
#

def service_template
  stap  = $evm.vmdb(:ServiceTemplate).find_by(:name => play_book, :type => "ServiceTemplateAnsiblePlaybook")
  stap.nil? ? (raise "ServiceTemplateAnsiblePlaybook <#{play_book}> not found") : play_book
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
  @playbook_stpr_id = request.id # ServiceTemplateProvisionRequest
  $evm.log(:info, "Submitted provision request #{@playbook_stpr_id} for service template #{service_template}")
end

def play_book
  @prov.options[:ws_values][:ansible_inside]
end

def add_playbook_service
  sleep 1.minute

  # ServiceTemplateProvisionRequest => ServiceTemplateProvisionTask (.miq_request_tasks) => .destination ([my_]service)
  # ServiceTemplateProvisionRequest.last.miq_request_tasks.first
  playbook_stpr = $evm.vmdb(:ServiceTemplateProvisionRequest).find_by(:id => @playbook_stpr_id)
  playbook_service = playbook_stpr.miq_request_tasks.first

  unless playbook_service.nil?
    parent_service_id = @prov.options[:ws_values][:service_id]
    parent_service = $evm.vmdb(:Service).find_by(:id => parent_service_id)

    parent_service.add_resource(playbook_service) unless parent_service.nil?
  end
end

# Do stuff

AUTH_CLASS = "ManageIQ_Providers_AutomationManager_Authentication".freeze
ANSIBLE_DIALOG_VAR_REGEX = Regexp.new(/dialog_param_(.*)/)

@prov = $evm.root["miq_provision"]
@playbook_stpr_id = nil

unless play_book.nil?
  begin
    order_playbook
  ensure   
    add_playbook_service unless @playbook_stpr_id.nil?
  end
end

# To DO: Wait and check playbook_stpr status
