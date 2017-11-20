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
      'addr_mode'                   => "dhcp",
      'cloud_network'               => cloud_network,
      'cloud_tenant'                => cloud_tenant,
      'floating_ip_address'         => floating_ip_address,
      # 'guest_access_key_pair'  => nil,
      'instance_type'               => instance_type,
      'placement_auto'              => false,
      'placement_availability_zone' => placement_availability_zone,
      'retirement'                  => 2592000,
      'retirement_warn'             => 604800,
      'schedule_type'               => "immediately",
      'security_groups'             => security_group,
      'vm_name'                     => vm_name
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
      'ansible_inside'    => get_software
    }
  
    # arg7 = emsCustomAttributes
    args << nil
  
    # arg8 = miqCustomAttributes
    args << nil

    $evm.log(:info, args)
  
    request_id = $evm.execute('create_provision_request', *args)
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
    Ems.cloud_tenants.find_all{|i| i.name == CloudTenant}.first.id rescue nil
  end

  def placement_availability_zone
    Ems.availability_zones.find_all{|i| i.name == Environment}.first.id rescue nil
  end

  def instance_type
    $evm.root['dialog_size']
  end
  
  def floating_ip_address
    $evm.root['dialog_floating_ip_address']
  end

  def security_group
    Ems.security_groups.find_all{|i| i.name == SecurityGroup}.first.id rescue nil
  end
  
  # def check_tag(tag)
  #   category = "ansible_inside"
  #   unless $evm.execute('category_exists?', category)
  #     $evm.execute('category_create', :name => category, :single_value => false, :perf_by_tag => false, :description => "Ansible Inside Playbooks")
  #   end
  
  #   unless $evm.execute('tag_exists?', category, tag)
  #     $evm.execute('tag_create', category, :name => tag, :description => tag.capitalize)
  #   end
  # end
  
  def get_software
    $evm.root['dialog_software']
  end

  # Do stuff
  
  require 'rest-client'
  
  user = $evm.root['user']
  
  task = $evm.root['service_template_provision_task']
  task ? parent_service_id = task.destination.id : parent_service_id = nil
  
  AppNetwork = 'app network'
  DbNetwork  = 'db network'
  WebNetwork = 'web network'
  
  CloudTenant   = "demo-vms"
  SecurityGroup = "default-demo-vms"
  
  Region      = $evm.root['dialog_region']        # OSP provider
  Environment = $evm.root['dialog_environment']   # Availability Zone??
  elastic     = $evm.root['dialog_elastic']       # TBC, OSP provider capability
  
  Ems = $evm.vmdb(:ExtManagementSystem).find_by(:name => Region)
  raise "Unknown EMS #{Region}" if Ems.nil?
  
  exec_provision_request(user, parent_service_id)
  