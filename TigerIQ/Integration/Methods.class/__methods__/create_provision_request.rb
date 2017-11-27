#
# Description: <Method description here>
#

def exec_provision_request(requester, parent_service_id)

  template = Ems.miq_templates.find_all{|i| i.name == get_image}
  raise "Source Template or Image <#{get_image}> not found" if template.nil?
  template = template.first 

  vm_name = nil
  if $evm.root['dialog_vm_name']
    vm_name = $evm.root['dialog_vm_name'].gsub(/\s+/, "")
    vm_name.empty? ? vm_name = nil : vm_name = get_vm_name(vm_name)
  end
  vm_name = get_vm_name("#{get_image}_001") if vm_name.nil?

  # arg1 = version
  args = ['1.1']

  # arg2 = templateFields
  args << {
    'name'         => template.name,
    'request_type' => 'template',
    'guid'         => template.guid
  }

  # arg3 = vmFields
  args << {
    'addr_mode'                     => "dhcp",
    'cloud_network'                 => cloud_network,
    'cloud_tenant'                  => cloud_tenant,
    'floating_ip_address'           => floating_ip_address,
    'customization_template_id'     => customization_template_id,
    'customization_template_script' => customization_template_script,
    'customize_enabled'             => "enabled",
    # 'guest_access_key_pair'  => nil,
    'instance_type'                 => instance_type,
    'placement_auto'                => false,
    'placement_availability_zone'   => placement_availability_zone,
    'retirement'                    => 2592000,
    'retirement_warn'               => 604800,
    'schedule_type'                 => "immediately",
    'security_groups'               => security_group,
    'vm_name'                       => vm_name
  }

  # arg4 = requester
  args << {
    'user_name'         => requester.userid,
    'owner_email'       => (requester.userid == 'admin' ? 'admin@org.com' : requester.userid),
    'auto_approve'      => true
  }

  # arg5 = tags
  # args << get_software
  args << nil

  # arg6 = additionalValues (ws_values)
  args << {
    'service_id'        => parent_service_id,
    'ansible_inside'    => get_software,
    'ssh_public_key'    => ssh_public_key # injected into customization_template_script
  }

  # arg7 = emsCustomAttributes
  args << nil

  # arg8 = miqCustomAttributes
  args << nil

  $evm.log(:info, args)

  $evm.execute('create_provision_request', *args)
end

def get_vm_name(vm_name)
  vm_name = vm_name.gsub(/\s+/, "")
  vm_name = vm_name.gsub(/template_/,"")
  vm = $evm.vmdb(:Vm).find_by(:name=>vm_name)
  while vm
    vm_name = vm_name.succ
    vm = $evm.vmdb(:Vm).find_by(:name=>vm_name)
  end
  $evm.log(:info, "VM Name: #{vm_name}")
  vm_name
end

def get_image
  $evm.root['dialog_image']
end

def cloud_network
  case $evm.root['dialog_role']
    when 'app'
    network = AppNetwork
    when 'db'
    network = DbNetwork
    when 'web'
    network = WebNetwork
  end
  network = "internal_demo-vms"
  Ems.cloud_networks.find_all{|i| i.name == network}.first.id rescue nil
end

def cloud_tenant
  $evm.root['dialog_tenant'].to_i
end

def customization_template_id
  $evm.vmdb(:CustomizationTemplate).where("lower(name) like '#{operating_system_type}'").first.id rescue nil
end

def customization_template_script
  $evm.vmdb(:CustomizationTemplate).where("lower(name) like '#{operating_system_type}'").first.script rescue nil
end

def placement_availability_zone
  # Ems.availability_zones.find_all{|i| i.name == Environment}.first.id rescue nil
  Ems.availability_zones.find_all{|i| i.name == "nova"}.first.id rescue nil
end

def instance_type
  $evm.root['dialog_size']
end

def floating_ip_address
  $evm.root['dialog_floating_ip_address']
end

def operating_system_type
  match = get_image.match(/(rhel|windows).*/i)
  match[1].downcase unless match.nil?
end

def security_group
  Ems.security_groups.find_all{|i| i.name == SecurityGroup}.first.id rescue nil
end

def get_software
  # { $evm.root['dialog_ansible_inside_play_book'] => "rolescfme=#{$evm.root['dialog_software'].join(",")}" }
  extra_vars = []
  extra_vars << "rolescfme=#{$evm.root['dialog_software'].join(",")}"
  extra_vars << "local_role=#{$evm.root['dialog_flavour']}"
  extra_vars << "local_user=#{$evm.root['dialog_local_password']}"
  extra_vars << "local_password=#{$evm.root['dialog_local_password']}"

  case operating_system_type
  when 'rhel'
    { "lamp_simple_rhel7"   => extra_vars.join(":") }
  when 'windows'
    { "lamp_simple_windows" => extra_vars.join(":") }
  end
end

def ssh_public_key
  match = get_image.match(/(rhel|windows).*/i)
  unless match.nil?
    operating_system_type = match[1].downcase
    case operating_system_type
    when 'rhel'
      # $evm.object['rhel_public_key']
      $evm.object.decrypt('rhel_public_key')
    when 'windows'
      # $evm.object['windows_admin_password']
      $evm.object.decrypt('windows_admin_password')
    end
  end
end

# Do stuff

if $evm.state_var_exist?("stpr_id")
  $evm.log(:info, "Phase 2 - Check provision request")

  stpr_id = $evm.get_state_var("stpr_id")
  stpr = $evm.vmdb(:ServiceTemplateProvisionRequest).find_by(:id => stpr_id)

  unless stpr.nil?
    $evm.log(:info, "Request Status:#{stpr.status} State:#{stpr.state}")

    if stpr.status == "Error"
      exit MIQ_ERROR
    elsif stpr.state == "finished"
      exit MIQ_OK
    else
      $evm.root['ae_result'] = 'retry'
      $evm.root['ae_retry_interval'] = 1.minute
      exit MIQ_OK
    end
  end

else
  $evm.log(:info, "Phase 1 - Create provision request")

  require 'rest-client'

  user = $evm.root['user']
  task = $evm.root['service_template_provision_task']
  task ? parent_service_id = task.destination.id : parent_service_id = nil

  AppNetwork = 'app network'
  DbNetwork  = 'db network'
  WebNetwork = 'web network'

  SecurityGroup = "default-demo-vms"

  Region      = $evm.root['dialog_region']        # OSP provider
  # Environment = $evm.root['dialog_environment']   # Availability Zone??
  elastic     = $evm.root['dialog_elastic']       # TBC, OSP provider capability

  Ems = $evm.vmdb(:ExtManagementSystem).find_by(:name => Region)
  raise "Unknown EMS #{Region}" if Ems.nil?

  request = exec_provision_request(user, parent_service_id)

  $evm.set_state_var("stpr_id", request.id)
  $evm.root['ae_result'] = 'retry'
  $evm.root['ae_retry_interval'] = 1.minute
end
