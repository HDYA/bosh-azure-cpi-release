require 'spec_helper'

describe Bosh::AzureCloud::VMManager do
  let(:vm_name) { "fake-vm-name" }
  let(:resource_group_name) { "fake-resource-group-name" }
  let(:storage_account_name) { "fake-storage-acount-name" }
  let(:instance_id) { instance_double(Bosh::AzureCloud::InstanceId) }
  let(:instance_id_string) { "fake-instance-id" }
  let(:os_disk_name) { "fake-os-disk-name" }
  let(:ephemeral_disk_name) { "fake-ephemeral-disk-name" }
  let(:location) { "fake-location" }
  let(:vip_network) { instance_double(Bosh::AzureCloud::VipNetwork) }
  let(:manual_network) { instance_double(Bosh::AzureCloud::ManualNetwork) }
  let(:dynamic_network) { instance_double(Bosh::AzureCloud::DynamicNetwork) }

  let(:registry_endpoint) { mock_registry.endpoint }
  let(:disk_manager) { instance_double(Bosh::AzureCloud::DiskManager) }
  let(:disk_manager2) { instance_double(Bosh::AzureCloud::DiskManager2) }
  let(:client2) { instance_double(Bosh::AzureCloud::AzureClient2) }
  let(:storage_account_manager) { instance_double(Bosh::AzureCloud::StorageAccountManager) }

  # VM manager for unmanaged disks
  let(:azure_properties) { mock_azure_properties }
  let(:vm_manager) { Bosh::AzureCloud::VMManager.new(azure_properties, registry_endpoint, disk_manager, disk_manager2, client2, storage_account_manager) }

  # VM manager for managed disks
  let(:azure_properties_managed) {
    mock_azure_properties_merge({
      'use_managed_disks' => true
    })
  }
  let(:vm_manager2) { Bosh::AzureCloud::VMManager.new(azure_properties_managed, registry_endpoint, disk_manager, disk_manager2, client2, storage_account_manager) }

  describe "#create" do
    # Stroage Account
    let(:storage_account) {
      {
        :id                 => "foo",
        :name               => MOCK_DEFAULT_STORAGE_ACCOUNT_NAME,
        :location           => "bar",
        :provisioning_state => "bar",
        :account_type       => "foo",
        :primary_endpoints  => "bar"
      }
    }

    # Network
    let(:load_balancer) {
      {
        :name => "fake-lb-name"
      }
    }
    let(:security_group) {
      {
        :name => MOCK_DEFAULT_SECURITY_GROUP,
        :id   => "fake-nsg-id"
      }
    }
    let(:subnet) { double("subnet") }

    # Disk
    let(:disk_id) { double("fake-disk-id") }
    let(:os_disk) {
      {
        :disk_name    => "fake-disk-name",
        :disk_uri     => "fake-disk-uri",
        :disk_size    => "fake-disk-size",
        :disk_caching => "fake-disk-caching"
      }
    }
    let(:ephemeral_disk) {
      {
        :disk_name    => 'fake-disk-name',
        :disk_uri     => 'fake-disk-uri',
        :disk_size    => 'fake-disk-size',
        :disk_caching => 'fake-disk-caching'
      }
    }
    let(:os_disk_managed) {
      {
        :disk_name    => 'fake-disk-name',
        :disk_size    => 'fake-disk-size',
        :disk_caching => 'fake-disk-caching'
      }
    }
    let(:ephemeral_disk_managed) {
      {
        :disk_name    => 'fake-disk-name',
        :disk_size    => 'fake-disk-size',
        :disk_caching => 'fake-disk-caching'
      }
    }

    # Stemcell
    let(:stemcell_uri) { "fake-uri" }
    let(:os_type) { "fake-os-type" }

    # Parameters of create_vm
    let(:stemcell_info) { instance_double(Bosh::AzureCloud::Helpers::StemcellInfo) }
    let(:resource_pool) {
      {
        'instance_type'                => 'Standard_D1',
        'storage_account_name'         => 'dfe03ad623f34d42999e93ca',
        'caching'                      => 'ReadWrite',
        'load_balancer'                => 'fake-lb-name'
      }
    }
    let(:network_configurator) { instance_double(Bosh::AzureCloud::NetworkConfigurator) }
    let(:env) { {} }

    before do
      allow(instance_id).to receive(:resource_group_name).
        and_return(resource_group_name)
      allow(instance_id).to receive(:vm_name).
        and_return(vm_name)
      allow(instance_id).to receive(:storage_account_name).
        and_return(storage_account_name)
      allow(instance_id).to receive(:to_s).
        and_return(instance_id_string)

      allow(stemcell_info).to receive(:uri).
        and_return(stemcell_uri)
      allow(stemcell_info).to receive(:os_type).
        and_return(os_type)
      allow(stemcell_info).to receive(:is_windows?).
        and_return(false)
      allow(stemcell_info).to receive(:image_size).
        and_return(nil)
      allow(stemcell_info).to receive(:is_light_stemcell?).
        and_return(false)

      allow(Bosh::AzureCloud::AzureClient2).to receive(:new).
        and_return(client2)
      allow(client2).to receive(:get_network_subnet_by_name).
        with(MOCK_RESOURCE_GROUP_NAME, "fake-virtual-network-name", "fake-subnet-name").
        and_return(subnet)
      allow(client2).to receive(:get_network_security_group_by_name).
        with(MOCK_RESOURCE_GROUP_NAME, MOCK_DEFAULT_SECURITY_GROUP).
        and_return(security_group)
      allow(client2).to receive(:get_public_ip_by_name).
        with(resource_group_name, vm_name).
        and_return(nil)
      allow(client2).to receive(:get_resource_group).
        and_return({})

      allow(network_configurator).to receive(:vip_network).
        and_return(vip_network)
      allow(network_configurator).to receive(:networks).
        and_return([manual_network, dynamic_network])
      allow(network_configurator).to receive(:default_dns).
        and_return("fake-dns")

      allow(vip_network).to receive(:resource_group_name).
        and_return('fake-resource-group')
      allow(vip_network).to receive(:public_ip).
        and_return('public-ip')

      allow(manual_network).to receive(:resource_group_name).
        and_return(MOCK_RESOURCE_GROUP_NAME)
      allow(manual_network).to receive(:security_group).
        and_return(nil)
      allow(manual_network).to receive(:virtual_network_name).
        and_return("fake-virtual-network-name")
      allow(manual_network).to receive(:subnet_name).
        and_return("fake-subnet-name")
      allow(manual_network).to receive(:private_ip).
        and_return('private-ip')

      allow(dynamic_network).to receive(:resource_group_name).
        and_return(MOCK_RESOURCE_GROUP_NAME)
      allow(dynamic_network).to receive(:security_group).
        and_return(nil)
      allow(dynamic_network).to receive(:virtual_network_name).
        and_return("fake-virtual-network-name")
      allow(dynamic_network).to receive(:subnet_name).
        and_return("fake-subnet-name")

      allow(disk_manager).to receive(:delete_disk).
        and_return(nil)
      allow(disk_manager).to receive(:generate_os_disk_name).
        and_return(os_disk_name)
      allow(disk_manager).to receive(:generate_ephemeral_disk_name).
        and_return(ephemeral_disk_name)
      allow(disk_manager).to receive(:resource_pool=)
      allow(disk_manager).to receive(:os_disk).
        and_return(os_disk)
      allow(disk_manager).to receive(:ephemeral_disk).
        and_return(ephemeral_disk)
      allow(disk_manager).to receive(:delete_vm_status_files).
        and_return(nil)

      allow(disk_manager2).to receive(:resource_pool=)
      allow(disk_manager2).to receive(:os_disk).
        and_return(os_disk_managed)
      allow(disk_manager2).to receive(:ephemeral_disk).
        and_return(ephemeral_disk_managed)
      allow(disk_manager2).to receive(:generate_os_disk_name).
        and_return(os_disk_name)
      allow(disk_manager2).to receive(:generate_ephemeral_disk_name).
        and_return(ephemeral_disk_name)
    end

    context "when instance_type is not provided" do
      let(:resource_pool) { {} }

      it "should raise an error" do
        expect(client2).not_to receive(:delete_virtual_machine)
        expect(client2).not_to receive(:delete_network_interface)
        expect(client2).to receive(:list_network_interfaces_by_keyword).with(resource_group_name, vm_name).and_return([])
        expect(client2).to receive(:get_public_ip_by_name).
          with(resource_group_name, vm_name).
          and_return({ :ip_address => "public-ip" })
        expect(client2).to receive(:delete_public_ip).with(resource_group_name, vm_name)

        expect {
          vm_manager.create(instance_id, location, stemcell_info, resource_pool, network_configurator, env)
        }.to raise_error /missing required cloud property `instance_type'/
      end
    end

    context "when an error is thrown during cleanup" do
      let(:resource_pool) { {} }

      before do
        allow(client2).to receive(:get_public_ip_by_name).
          with(resource_group_name, vm_name).
          and_return({ :ip_address => "public-ip" })
        allow(client2).to receive(:delete_public_ip).with(resource_group_name, vm_name).and_raise("Error during cleanup")
      end

      it "should raise an error" do
        expect(client2).not_to receive(:delete_virtual_machine)
        expect(client2).not_to receive(:delete_network_interface)
        expect(client2).to receive(:list_network_interfaces_by_keyword).with(resource_group_name, vm_name).and_return([])

        expect {
          vm_manager.create(instance_id, location, stemcell_info, resource_pool, network_configurator, env)
        }.to raise_error /Error during cleanup/
      end
    end

    context "when the resource group name is not specified in the network spec" do
      context "when subnet is not found in the default resource group" do
        before do
          allow(client2).to receive(:list_network_interfaces_by_keyword).
            with(resource_group_name, vm_name).
            and_return([])
          allow(client2).to receive(:get_load_balancer_by_name).
            with(resource_pool['load_balancer'])
            .and_return(load_balancer)
          allow(client2).to receive(:list_public_ips).
            and_return([{
              :ip_address => "public-ip"
            }])
          allow(client2).to receive(:get_network_subnet_by_name).
            with(MOCK_RESOURCE_GROUP_NAME, "fake-virtual-network-name", "fake-subnet-name").
            and_return(nil)
        end

        it "should raise an error" do
          expect {
            vm_manager.create(instance_id, location, stemcell_info, resource_pool, network_configurator, env)
          }.to raise_error /Cannot find the subnet `fake-virtual-network-name\/fake-subnet-name' in the resource group `#{MOCK_RESOURCE_GROUP_NAME}'/
        end
      end

      context "when network security group is not found in the default resource group" do
        before do
          allow(client2).to receive(:list_network_interfaces_by_keyword).
            with(resource_group_name, vm_name).
            and_return([])
          allow(client2).to receive(:get_load_balancer_by_name).
            with(resource_pool['load_balancer'])
            .and_return(load_balancer)
          allow(client2).to receive(:list_public_ips).
            and_return([{
              :ip_address => "public-ip"
            }])
          allow(client2).to receive(:get_network_security_group_by_name).
            with(MOCK_RESOURCE_GROUP_NAME, MOCK_DEFAULT_SECURITY_GROUP).
            and_return(nil)
        end

        it "should raise an error" do
          expect {
            vm_manager.create(instance_id, location, stemcell_info, resource_pool, network_configurator, env)
          }.to raise_error /Cannot find the network security group `fake-default-nsg-name'/
        end
      end
    end

    context "when the resource group name is specified in the network spec" do
      before do
        allow(client2).to receive(:get_network_security_group_by_name).
          with("fake-resource-group-name", MOCK_DEFAULT_SECURITY_GROUP).
          and_return(security_group)
        allow(manual_network).to receive(:resource_group_name).
          and_return("fake-resource-group-name")
        allow(client2).to receive(:get_load_balancer_by_name).
          with(resource_pool['load_balancer'])
          .and_return(load_balancer)
        allow(client2).to receive(:list_public_ips).
          and_return([{
            :ip_address => "public-ip"
          }])
      end

      context "when subnet is not found in the specified resource group" do
        it "should raise an error" do
          allow(client2).to receive(:list_network_interfaces_by_keyword).
            with(resource_group_name, vm_name).
            and_return([])
          allow(client2).to receive(:get_network_subnet_by_name).
            with("fake-resource-group-name", "fake-virtual-network-name", "fake-subnet-name").
            and_return(nil)
          expect {
            vm_manager.create(instance_id, location, stemcell_info, resource_pool, network_configurator, env)
          }.to raise_error /Cannot find the subnet `fake-virtual-network-name\/fake-subnet-name' in the resource group `fake-resource-group-name'/
        end
      end

      context "when network security group is not found in the specified resource group nor the default resource group" do
        before do
          allow(client2).to receive(:list_network_interfaces_by_keyword).
            with(resource_group_name, vm_name).
            and_return([])
          allow(client2).to receive(:get_network_security_group_by_name).
            with(MOCK_RESOURCE_GROUP_NAME, MOCK_DEFAULT_SECURITY_GROUP).
            and_return(nil)
          allow(client2).to receive(:get_network_security_group_by_name).
            with("fake-resource-group-name", MOCK_DEFAULT_SECURITY_GROUP).
            and_return(nil)
        end

        it "should raise an error" do
          expect {
            vm_manager.create(instance_id, location, stemcell_info, resource_pool, network_configurator, env)
          }.to raise_error /Cannot find the network security group `fake-default-nsg-name'/
        end
      end
    end

    context "when public ip is not found" do
      before do
        allow(client2).to receive(:get_load_balancer_by_name).
          with(resource_pool['load_balancer'])
          .and_return(load_balancer)
      end

      context "when the public ip list azure returns is empty" do
        it "should raise an error" do
          allow(client2).to receive(:list_network_interfaces_by_keyword).
            with(resource_group_name, vm_name).
            and_return([])
          allow(client2).to receive(:list_public_ips).
            and_return([])

          expect(client2).not_to receive(:delete_virtual_machine)
          expect(client2).not_to receive(:delete_network_interface)
          expect {
            vm_manager.create(instance_id, location, stemcell_info, resource_pool, network_configurator, env)
          }.to raise_error /Cannot find the public IP address/
        end
      end

      context "when the public ip list azure returns does not match the configured one" do
        let(:public_ips) {
          [
            {
              :ip_address => "public-ip"
            },
            {
              :ip_address => "not-public-ip"
            }
          ]
        }

        it "should raise an error" do
          allow(client2).to receive(:list_network_interfaces_by_keyword).
            with(resource_group_name, vm_name).
            and_return([])
          allow(client2).to receive(:list_public_ips).
            and_return(public_ips)
          allow(vip_network).to receive(:public_ip).
            and_return("not-exist-public-ip")

          expect(client2).not_to receive(:delete_virtual_machine)
          expect(client2).not_to receive(:delete_network_interface)
          expect {
            vm_manager.create(instance_id, location, stemcell_info, resource_pool, network_configurator, env)
          }.to raise_error /Cannot find the public IP address/
        end
      end
    end

    context "when load balancer can not be found" do
      before do
        allow(client2).to receive(:list_network_interfaces_by_keyword).
          with(resource_group_name, vm_name).
          and_return([])
      end

      it "should raise an error" do
        allow(client2).to receive(:get_load_balancer_by_name).
          with(resource_pool['load_balancer']).
          and_return(nil)

        expect(client2).not_to receive(:delete_virtual_machine)
        expect(client2).not_to receive(:delete_network_interface)

        expect {
          vm_manager.create(instance_id, location, stemcell_info, resource_pool, network_configurator, env)
        }.to raise_error /Cannot find the load balancer/
      end
    end

    context "when network interface is not created" do
      before do
        allow(client2).to receive(:get_network_subnet_by_name).
          and_return(subnet)
        allow(client2).to receive(:get_load_balancer_by_name).
          with(resource_pool['load_balancer']).
          and_return(load_balancer)
        allow(client2).to receive(:list_public_ips).
          and_return([{
            :ip_address => "public-ip"
          }])
        allow(client2).to receive(:create_network_interface).
          and_raise("network interface is not created")
      end

      context "when none of network interface is created" do
        before do
          allow(client2).to receive(:list_network_interfaces_by_keyword).
            with(resource_group_name, vm_name).
            and_return([])
        end

        it "should raise an error and do not delete any network interface" do
          expect(client2).not_to receive(:delete_virtual_machine)
          expect(client2).not_to receive(:delete_network_interface)
          expect {
            vm_manager.create(instance_id, location, stemcell_info, resource_pool, network_configurator, env)
          }.to raise_error /network interface is not created/
        end
      end

      context "when one network interface is created and the another one is not" do
        let(:network_interface) {
          {
            :id   => "/subscriptions/fake-subscription/resourceGroups/fake-resource-group/providers/Microsoft.Network/networkInterfaces/#{vm_name}-x",
            :name => "#{vm_name}-x"
          }
        }

        before do
          allow(client2).to receive(:list_network_interfaces_by_keyword).
            with(resource_group_name, vm_name).
            and_return([network_interface])
          allow(client2).to receive(:get_network_subnet_by_name).
            and_return(subnet)
          allow(client2).to receive(:get_load_balancer_by_name).
            with(resource_pool['load_balancer']).
            and_return(load_balancer)
          allow(client2).to receive(:list_public_ips).
            and_return([{
              :ip_address => "public-ip"
            }])
        end

        it "should delete the (possible) existing network interface and raise an error" do
          expect(client2).to receive(:delete_network_interface).once
          expect {
            vm_manager.create(instance_id, location, stemcell_info, resource_pool, network_configurator, env)
          }.to raise_error /network interface is not created/
        end
      end

      context "when dynamic public IP is created" do
        let(:dynamic_public_ip) { 'fake-dynamic-public-ip' }

        before do
          resource_pool['assign_dynamic_public_ip'] = true
          allow(client2).to receive(:get_public_ip_by_name).
            with(resource_group_name, vm_name).and_return(dynamic_public_ip)
          allow(client2).to receive(:list_network_interfaces_by_keyword).
            with(resource_group_name, vm_name).
            and_return([])
        end

        it "should delete the dynamic public IP" do
          expect(client2).to receive(:delete_public_ip).with(resource_group_name, vm_name)
          expect {
            vm_manager.create(instance_id, location, stemcell_info, resource_pool, network_configurator, env)
          }.to raise_error /network interface is not created/
        end
      end
    end

    context "when creating virtual machine" do
      let(:load_balancer) {
        {
          :name => "lb-name"
        }
      }
      let(:network_interface) {
        {
          :name => "foo"
        }
      }
      let(:storage_account) {
        {
          :id                 => "foo",
          :name               => MOCK_DEFAULT_STORAGE_ACCOUNT_NAME,
          :location           => "bar",
          :provisioning_state => "bar",
          :account_type       => "foo",
          :storage_blob_host  => "fake-blob-endpoint",
          :storage_table_host => "fake-table-endpoint"
        }
      }

      before do
        allow(client2).to receive(:get_network_subnet_by_name).
          and_return(subnet)
        allow(client2).to receive(:get_load_balancer_by_name).
          with(resource_pool['load_balancer']).
          and_return(load_balancer)
        allow(client2).to receive(:list_public_ips).
          and_return([{
            :ip_address => "public-ip"
          }])
        allow(client2).to receive(:create_network_interface)
        allow(client2).to receive(:get_network_interface_by_name).
          and_return(network_interface)
        allow(client2).to receive(:get_availability_set_by_name).
          and_return(nil)
        allow(client2).to receive(:get_storage_account_by_name).
          and_return(storage_account)

        allow(network_configurator).to receive(:default_dns).
          and_return("fake-dns")
        allow(disk_manager).to receive(:get_disk_uri).
          and_return("fake-disk-uri")
      end

      context "when VM is not created" do
        context " and client2.create_virtual_machine raises an normal error" do
          context " and no more error occurs" do
            before do
              allow(client2).to receive(:create_virtual_machine).
                and_raise('virtual machine is not created')
            end

            it "should delete vm and nics and then raise an error" do
              expect(client2).to receive(:delete_virtual_machine).once
              expect(disk_manager).to receive(:delete_disk).with(storage_account_name, os_disk_name).once
              expect(disk_manager).to receive(:delete_disk).with(storage_account_name, ephemeral_disk_name).once
              expect(disk_manager).to receive(:delete_vm_status_files).
                with(storage_account_name, vm_name).once
              expect(client2).to receive(:delete_network_interface).twice

              expect {
                vm_manager.create(instance_id, location, stemcell_info, resource_pool, network_configurator, env)
              }.to raise_error /virtual machine is not created/
            end
          end

          context "and an error occurs when deleting nic" do
            before do
              allow(client2).to receive(:create_virtual_machine).
                and_raise('virtual machine is not created')
              allow(client2).to receive(:delete_network_interface).
                and_raise('cannot delete nic')
            end

            it "should delete vm and nics and then raise an error" do
              expect(client2).to receive(:delete_virtual_machine).once
              expect(disk_manager).to receive(:delete_disk).with(storage_account_name, os_disk_name).once
              expect(disk_manager).to receive(:delete_disk).with(storage_account_name, ephemeral_disk_name).once
              expect(disk_manager).to receive(:delete_vm_status_files).
                with(storage_account_name, vm_name).once
              expect(client2).to receive(:delete_network_interface).once

              expect {
                vm_manager.create(instance_id, location, stemcell_info, resource_pool, network_configurator, env)
              }.to raise_error /cannot delete nic/
            end
          end
        end

        context " and client2.create_virtual_machine raises an AzureAsynchronousError" do
          context " and AzureAsynchronousError.status is not Failed" do
            before do
              allow(client2).to receive(:create_virtual_machine).
                and_raise(Bosh::AzureCloud::AzureAsynchronousError)
            end

            it "should delete vm and nics and then raise an error" do
              expect(client2).to receive(:delete_virtual_machine).once
              expect(disk_manager).to receive(:delete_disk).with(storage_account_name, os_disk_name).once
              expect(disk_manager).to receive(:delete_disk).with(storage_account_name, ephemeral_disk_name).once
              expect(disk_manager).to receive(:delete_vm_status_files).
                with(storage_account_name, vm_name).once
              expect(client2).to receive(:delete_network_interface).twice

              expect {
                vm_manager.create(instance_id, location, stemcell_info, resource_pool, network_configurator, env)
              }.to raise_error { |error|
                expect(error.inspect).to match(/Bosh::AzureCloud::AzureAsynchronousError/)
                expect(error.inspect).not_to match(/This VM fails in provisioning after multiple retries/)
              }
            end
          end

          context " and AzureAsynchronousError.status is Failed" do
            before do
              allow(client2).to receive(:create_virtual_machine).
                and_raise(Bosh::AzureCloud::AzureAsynchronousError.new('Failed'))
            end

            context " and use_managed_disks is false" do
              context " and ephemeral_disk does not exist" do
                before do
                  allow(disk_manager).to receive(:ephemeral_disk).
                    and_return(nil)
                end

                it "should not delete vm and then raise an error" do
                  expect(client2).to receive(:create_virtual_machine).exactly(3).times
                  expect(client2).to receive(:delete_virtual_machine).twice
                  expect(disk_manager).to receive(:delete_disk).with(storage_account_name, os_disk_name).twice
                  expect(disk_manager).to receive(:delete_vm_status_files).
                    with(storage_account_name, vm_name).twice
                  expect(disk_manager).not_to receive(:delete_disk).with(storage_account_name, ephemeral_disk_name)
                  expect(client2).not_to receive(:delete_network_interface)

                  expect {
                    vm_manager.create(instance_id, location, stemcell_info, resource_pool, network_configurator, env)
                  }.to raise_error { |error|
                    expect(error.inspect).to match(/Bosh::AzureCloud::AzureAsynchronousError/)
                    expect(error.inspect).to match(/This VM fails in provisioning after multiple retries/)
                  }
                end
              end

              context " and ephemeral_disk exists" do
                context " and no more error occurs" do
                  it "should not delete vm and then raise an error" do
                    expect(client2).to receive(:create_virtual_machine).exactly(3).times
                    expect(client2).to receive(:delete_virtual_machine).twice
                    expect(disk_manager).to receive(:delete_disk).with(storage_account_name, os_disk_name).twice
                    expect(disk_manager).to receive(:delete_disk).with(storage_account_name, ephemeral_disk_name).twice
                    expect(disk_manager).to receive(:delete_vm_status_files).
                      with(storage_account_name, vm_name).twice
                    expect(client2).not_to receive(:delete_network_interface)

                    expect {
                      vm_manager.create(instance_id, location, stemcell_info, resource_pool, network_configurator, env)
                    }.to raise_error { |error|
                      expect(error.inspect).to match(/Bosh::AzureCloud::AzureAsynchronousError/)
                      expect(error.inspect).to match(/This VM fails in provisioning after multiple retries/)
                    }
                  end
                end

                context "and an error occurs when deleting vm" do
                  before do
                    allow(client2).to receive(:delete_virtual_machine).
                      and_raise('cannot delete the vm')
                  end

                  it "should not delete vm and then raise an error" do
                    expect(client2).to receive(:create_virtual_machine).once
                    expect(client2).to receive(:delete_virtual_machine).once
                    expect(disk_manager).not_to receive(:delete_disk).with(storage_account_name, os_disk_name)
                    expect(disk_manager).not_to receive(:delete_disk).with(storage_account_name, ephemeral_disk_name)
                    expect(disk_manager).not_to receive(:delete_vm_status_files).
                      with(storage_account_name, vm_name)
                    expect(client2).not_to receive(:delete_network_interface)

                    expect {
                      vm_manager.create(instance_id, location, stemcell_info, resource_pool, network_configurator, env)
                    }.to raise_error /cannot delete the vm/
                  end
                end
              end
            end

            context " and use_managed_disks is true" do
              context " and ephemeral_disk does not exist" do
                before do
                  allow(disk_manager2).to receive(:ephemeral_disk).
                    and_return(nil)
                end

                it "should not delete vm and then raise an error" do
                  expect(client2).to receive(:create_virtual_machine).exactly(3).times
                  expect(client2).to receive(:delete_virtual_machine).twice
                  expect(disk_manager2).to receive(:delete_disk).with(resource_group_name, os_disk_name).twice
                  expect(disk_manager2).not_to receive(:delete_disk).with(resource_group_name, ephemeral_disk_name)
                  expect(client2).not_to receive(:delete_network_interface)

                  expect {
                    vm_manager2.create(instance_id, location, stemcell_info, resource_pool, network_configurator, env)
                  }.to raise_error { |error|
                    expect(error.inspect).to match(/Bosh::AzureCloud::AzureAsynchronousError/)
                    expect(error.inspect).to match(/This VM fails in provisioning after multiple retries/)
                  }
                end
              end

              context " and ephemeral_disk exists" do
                it "should not delete vm and then raise an error" do
                  expect(client2).to receive(:create_virtual_machine).exactly(3).times
                  expect(client2).to receive(:delete_virtual_machine).twice
                  expect(disk_manager2).to receive(:delete_disk).with(resource_group_name, os_disk_name).twice
                  expect(disk_manager2).to receive(:delete_disk).with(resource_group_name, ephemeral_disk_name).twice
                  expect(client2).not_to receive(:delete_network_interface)

                  expect {
                    vm_manager2.create(instance_id, location, stemcell_info, resource_pool, network_configurator, env)
                  }.to raise_error { |error|
                    expect(error.inspect).to match(/Bosh::AzureCloud::AzureAsynchronousError/)
                    expect(error.inspect).to match(/This VM fails in provisioning after multiple retries/)
                  }
                end
              end
            end
          end
        end
      end

      context "when VM is created" do
        before do
          allow(client2).to receive(:create_virtual_machine)
        end

        # Resource group
        context "when resource group does not exist" do
          let(:resource_pool) {
            {
              'instance_type'                 => 'Standard_D1',
              'storage_account_name'          => 'dfe03ad623f34d42999e93ca',
              'caching'                       => 'ReadWrite',
            }
          }

          before do
            allow(client2).to receive(:get_resource_group).
              with(resource_group_name).
              and_return(nil)
            allow(client2).to receive(:create_network_interface)
          end

          it "should create the resource group" do
            expect(client2).to receive(:create_resource_group).
              with(resource_group_name, location)

            vm_params = vm_manager.create(instance_id, location, stemcell_info, resource_pool, network_configurator, env)
            expect(vm_params[:name]).to eq(vm_name)
          end
        end

        # Network Security Group
        context "#network_security_group" do
          context "with the network security group provided in resource_pool" do
            let(:resource_pool) {
              {
                'instance_type'                 => 'Standard_D1',
                'storage_account_name'          => 'dfe03ad623f34d42999e93ca',
                'caching'                       => 'ReadWrite',
                'load_balancer'                 => 'fake-lb-name',
                'security_group'                => 'fake-nsg-name'
              }
            }

            before do
              allow(client2).to receive(:get_network_security_group_by_name).
                with(MOCK_RESOURCE_GROUP_NAME, MOCK_DEFAULT_SECURITY_GROUP).
                and_return(nil)
              allow(client2).to receive(:get_network_security_group_by_name).
                with(MOCK_RESOURCE_GROUP_NAME, "fake-nsg-name").
                and_return(security_group)
            end

            context "and a heavy stemcell is used" do
              it "should succeed" do
                expect(client2).not_to receive(:delete_virtual_machine)
                expect(client2).not_to receive(:delete_network_interface)

                expect(client2).to receive(:create_network_interface).twice
                vm_params = vm_manager.create(instance_id, location, stemcell_info, resource_pool, network_configurator, env)
                expect(vm_params[:name]).to eq(vm_name)
                expect(vm_params[:image_uri]).to eq(stemcell_uri)
                expect(vm_params[:os_type]).to eq(os_type)
              end
            end

            context "and a light stemcell is used" do
              let(:platform_image) {
                {
                  'instance_type'                 => 'Standard_D1',
                  'storage_account_name'          => 'dfe03ad623f34d42999e93ca',
                  'caching'                       => 'ReadWrite',
                  'load_balancer'                 => 'fake-lb-name',
                  'security_group'                => 'fake-nsg-name'
                }
              }

              before do
                allow(client2).to receive(:get_network_security_group_by_name).
                  with(MOCK_RESOURCE_GROUP_NAME, MOCK_DEFAULT_SECURITY_GROUP).
                  and_return(nil)
                allow(client2).to receive(:get_network_security_group_by_name).
                  with(MOCK_RESOURCE_GROUP_NAME, "fake-nsg-name").
                  and_return(security_group)
              end

              it "should succeed" do
                expect(client2).not_to receive(:delete_virtual_machine)
                expect(client2).not_to receive(:delete_network_interface)

                expect(client2).to receive(:create_network_interface).twice
                vm_params = vm_manager.create(instance_id, location, stemcell_info, resource_pool, network_configurator, env)
                expect(vm_params[:name]).to eq(vm_name)
              end
            end
          end

          context "with the network security group provided in network spec" do
            let(:nsg_name) { "fake-nsg-name-specified-in-network-spec" }
            let(:security_group) {
              {
                :name => nsg_name
              }
            }

            before do
              allow(manual_network).to receive(:security_group).and_return(nsg_name)
              allow(dynamic_network).to receive(:security_group).and_return(nsg_name)
              allow(client2).to receive(:get_network_security_group_by_name).
                with(MOCK_RESOURCE_GROUP_NAME, MOCK_DEFAULT_SECURITY_GROUP).
                and_return(nil)
              allow(client2).to receive(:get_network_security_group_by_name).
                with(MOCK_RESOURCE_GROUP_NAME, nsg_name).
                and_return(security_group)
            end

            it "should succeed" do
              expect(client2).not_to receive(:delete_virtual_machine)
              expect(client2).not_to receive(:delete_network_interface)

              expect(client2).to receive(:create_network_interface).
                with(resource_group_name, hash_including(:security_group => security_group), any_args).twice
              vm_params = vm_manager.create(instance_id, location, stemcell_info, resource_pool, network_configurator, env)
              expect(vm_params[:name]).to eq(vm_name)
            end
          end

          context "with the default network security group" do
            it "should succeed" do
              expect(client2).not_to receive(:delete_virtual_machine)
              expect(client2).not_to receive(:delete_network_interface)

              vm_params = vm_manager.create(instance_id, location, stemcell_info, resource_pool, network_configurator, env)
              expect(vm_params[:name]).to eq(vm_name)
            end
          end

          context "with the resource group name not provided in the network spec" do
            before do
              allow(client2).to receive(:get_network_subnet_by_name).
                with(MOCK_RESOURCE_GROUP_NAME, "fake-virtual-network-name", "fake-subnet-name").
                and_return(subnet)
            end

            context "when network security group is found in the default resource group" do
              before do
                allow(client2).to receive(:get_network_security_group_by_name).
                  with(MOCK_RESOURCE_GROUP_NAME, MOCK_DEFAULT_SECURITY_GROUP).
                  and_return(security_group)
              end

              it "should succeed" do
                expect(client2).not_to receive(:delete_virtual_machine)
                expect(client2).not_to receive(:delete_network_interface)
                expect(client2).to receive(:create_network_interface).twice
                vm_params = vm_manager.create(instance_id, location, stemcell_info, resource_pool, network_configurator, env)
                expect(vm_params[:name]).to eq(vm_name)
              end
            end
          end

          context "with the resource group name provided in the network spec" do
            before do
              allow(client2).to receive(:get_network_subnet_by_name).
                with("fake-resource-group-name", "fake-virtual-network-name", "fake-subnet-name").
                and_return(subnet)
            end

            context "when network security group is not found in the specified resource group and found in the default resource group" do
              before do
                allow(client2).to receive(:get_network_security_group_by_name).
                  with(MOCK_RESOURCE_GROUP_NAME, MOCK_DEFAULT_SECURITY_GROUP).
                  and_return(security_group)
                allow(client2).to receive(:get_network_security_group_by_name).
                  with("fake-resource-group-name", MOCK_DEFAULT_SECURITY_GROUP).
                  and_return(nil)
              end

              it "should succeed" do
                expect(client2).not_to receive(:delete_virtual_machine)
                expect(client2).not_to receive(:delete_network_interface)
                expect(client2).to receive(:create_network_interface).exactly(2).times
                vm_params = vm_manager.create(instance_id, location, stemcell_info, resource_pool, network_configurator, env)
                expect(vm_params[:name]).to eq(vm_name)
              end
            end

            context "when network security group is found in the specified resource group" do
              before do
                allow(client2).to receive(:get_network_security_group_by_name).
                  with("fake-resource-group-name", MOCK_DEFAULT_SECURITY_GROUP).
                  and_return(security_group)
              end

              it "should succeed" do
                expect(client2).not_to receive(:delete_virtual_machine)
                expect(client2).not_to receive(:delete_network_interface)
                expect(client2).to receive(:create_network_interface).twice
                vm_params = vm_manager.create(instance_id, location, stemcell_info, resource_pool, network_configurator, env)
                expect(vm_params[:name]).to eq(vm_name)
              end
            end
          end
        end

        # Stemcell
        context "#stemcell" do
          context "with the network security group provided in resource_pool" do
            let(:resource_pool) {
              {
                'instance_type'                 => 'Standard_D1',
                'storage_account_name'          => 'dfe03ad623f34d42999e93ca',
                'caching'                       => 'ReadWrite',
                'load_balancer'                 => 'fake-lb-name'
              }
            }

            context "and a heavy stemcell is used" do
              it "should succeed" do
                expect(client2).not_to receive(:delete_virtual_machine)
                expect(client2).not_to receive(:delete_network_interface)

                expect(client2).to receive(:create_network_interface).exactly(2).times
                vm_params = vm_manager.create(instance_id, location, stemcell_info, resource_pool, network_configurator, env)
                expect(vm_params[:name]).to eq(vm_name)
                expect(vm_params[:image_uri]).to eq(stemcell_uri)
                expect(vm_params[:os_type]).to eq(os_type)
              end
            end

            context "and a light stemcell is used" do
              let(:platform_image) {
                {
                  'publisher' => 'fake-publisher',
                  'offer'     => 'fake-offer',
                  'sku'       => 'fake-sku',
                  'version'   => 'fake-version'
                }
              }

              before do
                allow(stemcell_info).to receive(:is_light_stemcell?).
                  and_return(true)
                allow(stemcell_info).to receive(:image_reference).
                  and_return(platform_image)
              end

              it "should succeed" do
                expect(client2).not_to receive(:delete_virtual_machine)
                expect(client2).not_to receive(:delete_network_interface)

                expect(client2).to receive(:create_network_interface).twice
                vm_params = vm_manager.create(instance_id, location, stemcell_info, resource_pool, network_configurator, env)
                expect(vm_params[:name]).to eq(vm_name)
                expect(vm_params[:os_type]).to eq(os_type)
              end
            end
          end
        end

        # Availability Set
        context "#availability_set" do
          context "when availability set is not created" do
            let(:env) { nil }
            let(:availability_set_name) { "#{SecureRandom.uuid}" }
            let(:resource_pool) {
              {
                'instance_type' => 'Standard_D1',
                'availability_set' => availability_set_name,
                'platform_update_domain_count' => 5,
                'platform_fault_domain_count' => 3,
              }
            }

            before do
              allow(client2).to receive(:get_availability_set_by_name).
                with(resource_group_name, availability_set_name).
                and_return(nil)
              allow(client2).to receive(:create_availability_set).
                and_raise("availability set is not created")
            end

            it "should delete nics and then raise an error" do
              expect(client2).not_to receive(:delete_virtual_machine)
              expect(client2).to receive(:delete_network_interface).exactly(2).times

              expect {
                vm_manager.create(instance_id, location, stemcell_info, resource_pool, network_configurator, env)
              }.to raise_error /availability set is not created/
            end
          end

          context "with env is nil and availability_set is specified in resource_pool" do
            let(:env) { nil }
            let(:availability_set_name) { "#{SecureRandom.uuid}" }
            let(:resource_pool) {
              {
                'instance_type'                => 'Standard_D1',
                'availability_set'             => availability_set_name,
                'platform_update_domain_count' => 5,
                'platform_fault_domain_count'  => 3,
              }
            }
            let(:avset_params) {
              {
                :name                         => resource_pool['availability_set'],
                :location                     => location,
                :tags                         => {'user-agent' => 'bosh'},
                :platform_update_domain_count => resource_pool['platform_update_domain_count'],
                :platform_fault_domain_count  => resource_pool['platform_fault_domain_count'],
                :managed                      => false
              }
            }

            before do
              allow(client2).to receive(:get_availability_set_by_name).
                with(resource_group_name, resource_pool['availability_set']).
                and_return(nil)
            end

            it "should create availability set and use value of availability_set as its name" do
              expect(client2).to receive(:create_availability_set).
                with(resource_group_name, avset_params)
              expect(client2).to receive(:create_network_interface).twice

              vm_params = vm_manager.create(instance_id, location, stemcell_info, resource_pool, network_configurator, env)
              expect(vm_params[:name]).to eq(vm_name)
            end
          end

          context "with bosh.group specified in env" do
            context "when availability_set is specified in resource_pool" do
              let(:env) {
                {
                  'bosh' => {
                    'group' => "bosh-group-#{SecureRandom.uuid}"
                  }
                }
              }
              let(:availability_set_name) { "#{SecureRandom.uuid}" }
              let(:resource_pool) {
                {
                  'instance_type' => 'Standard_D1',
                  'availability_set' => availability_set_name,
                  'platform_update_domain_count' => 5,
                  'platform_fault_domain_count' => 3,
                }
              }
              let(:avset_params) {
                {
                  :name                         => resource_pool['availability_set'],
                  :location                     => location,
                  :tags                         => {'user-agent' => 'bosh'},
                  :platform_update_domain_count => resource_pool['platform_update_domain_count'],
                  :platform_fault_domain_count  => resource_pool['platform_fault_domain_count'],
                  :managed                      => false
                }
              }

              before do
                allow(client2).to receive(:get_availability_set_by_name).
                  with(resource_group_name, resource_pool['availability_set']).
                  and_return(nil)
              end

              it "should create availability set and use value of availability_set as its name" do
                expect(client2).to receive(:create_availability_set).
                  with(resource_group_name, avset_params)

                vm_params = vm_manager.create(instance_id, location, stemcell_info, resource_pool, network_configurator, env)
                expect(vm_params[:name]).to eq(vm_name)
              end
            end

            context "when availability_set is not specified in resource_pool" do
              let(:resource_pool) {
                {
                  'instance_type' => 'Standard_D1'
                }
              }
              let(:avset_params) {
                {
                  :location                     => location,
                  :tags                         => {'user-agent' => 'bosh'},
                  :platform_update_domain_count => 5,
                  :platform_fault_domain_count  => 3,
                  :managed                      => false
                }
              }

              context "when the length of availability_set name equals to 80" do
                let(:env) {
                  {
                    'bosh' => {'group' => 'group' * 16}
                  }
                }

                before do
                  avset_params[:name] = env['bosh']['group']
                  allow(client2).to receive(:get_availability_set_by_name).
                    with(resource_group_name, env['bosh']['group']).
                    and_return(nil)
                end

                it "should create availability set and use value of env.bosh.group as its name" do
                  expect(client2).to receive(:create_availability_set).
                    with(resource_group_name, avset_params)

                  vm_params = vm_manager.create(instance_id, location, stemcell_info, resource_pool, network_configurator, env)
                  expect(vm_params[:name]).to eq(vm_name)
                end
              end

              context "when the length of availability_set name is greater than 80" do
                let(:env) {
                  {
                    'bosh' => {'group' => 'a' * 80 + 'group' * 8}
                  }
                }

                before do
                  # 21d9858fb04d8ba39cdacdc926c5415e is MD5 of the availability_set name ('a' * 80 + 'group' * 8)
                  avset_params[:name] = "az-21d9858fb04d8ba39cdacdc926c5415e-#{'group' * 8}"
                  allow(client2).to receive(:get_availability_set_by_name).
                    and_return(nil)
                end

                it "should create availability set with a truncated value of env.bosh.group as its name" do
                  expect(client2).to receive(:create_availability_set).with(resource_group_name, avset_params)

                  vm_params = vm_manager.create(instance_id, location, stemcell_info, resource_pool, network_configurator, env)
                  expect(vm_params[:name]).to eq(vm_name)
                end
              end
            end
          end

          context "When the availability set exists, and doesn't need to update the managed property" do
            let(:env) { nil }
            let(:availability_set_name) { "#{SecureRandom.uuid}" }
            let(:availability_set) {
              {
                :name => availability_set_name,
                :virtual_machines => [
                  "fake-vm-id-1",
                  "fake-vm-id-2"
                ]
              }
            }
            let(:resource_pool) {
              {
                'instance_type' => 'Standard_D1',
                'availability_set' => availability_set_name,
                'platform_update_domain_count' => 5,
                'platform_fault_domain_count' => 3,
              }
            }

            before do
              allow(client2).to receive(:get_availability_set_by_name).
                with(resource_group_name, resource_pool['availability_set']).
                and_return(availability_set)
            end

            it "should not create availability set" do
              expect(client2).not_to receive(:create_availability_set)

              vm_params = vm_manager.create(instance_id, location, stemcell_info, resource_pool, network_configurator, env)
              expect(vm_params[:name]).to eq(vm_name)
            end
          end

          context "when the availability set doesn't exist" do
            let(:availability_set_name) { "#{SecureRandom.uuid}" }

            context "when the availability is unmanaged" do
              let(:resource_pool) {
                {
                  'instance_type' => 'Standard_D1',
                  'availability_set' => availability_set_name
                }
              }

              let(:avset_params) {
                {
                  :name                         => resource_pool['availability_set'],
                  :location                     => location,
                  :tags                         => {'user-agent' => 'bosh'},
                  :platform_update_domain_count => 5,
                  :platform_fault_domain_count  => 3,
                  :managed                      => false
                }
              }

              before do
                allow(client2).to receive(:get_availability_set_by_name).
                  with(resource_group_name, resource_pool['availability_set']).
                  and_return(nil)
              end

              it "should create the unmanaged availability set" do
                expect(client2).to receive(:create_availability_set).with(resource_group_name, avset_params)
                expect(client2).to receive(:create_network_interface).twice

                vm_params = vm_manager.create(instance_id, location, stemcell_info, resource_pool, network_configurator, env)
                expect(vm_params[:name]).to eq(vm_name)
              end
            end

            context "when the availability is managed" do
              let(:resource_pool) {
                {
                  'instance_type' => 'Standard_D1',
                  'availability_set' => availability_set_name
                }
              }

              let(:avset_params) {
                {
                  :name                         => resource_pool['availability_set'],
                  :location                     => location,
                  :tags                         => {'user-agent' => 'bosh'},
                  :platform_update_domain_count => 5,
                  :platform_fault_domain_count  => 2,
                  :managed                      => true
                }
              }

              before do
                allow(client2).to receive(:get_availability_set_by_name).
                  with(resource_group_name, resource_pool['availability_set']).
                  and_return(nil)
              end

              it "should create the managed availability set" do
                expect(client2).to receive(:create_availability_set).with(resource_group_name, avset_params)
                expect(client2).to receive(:create_network_interface).twice

                vm_params = vm_manager2.create(instance_id, location, stemcell_info, resource_pool, network_configurator, env)
                expect(vm_params[:name]).to eq(vm_name)
              end
            end

            context "when platform_update_domain_count and platform_fault_domain_count are not set" do
              let(:resource_pool) {
                {
                  'instance_type' => 'Standard_D1',
                  'availability_set' => availability_set_name
                }
              }

              let(:avset_params) {
                {
                  :name                         => resource_pool['availability_set'],
                  :location                     => location,
                  :tags                         => {'user-agent' => 'bosh'},
                  :platform_update_domain_count => 5,
                  :platform_fault_domain_count  => 2, # The default value of fault domains in managed availability set is 2
                  :managed                      => true
                }
              }

              before do
                allow(client2).to receive(:get_availability_set_by_name).
                  with(resource_group_name, resource_pool['availability_set']).
                  and_return(nil)
              end

              it "should create the availability set with the default values" do
                expect(client2).to receive(:create_availability_set).with(resource_group_name, avset_params)

                vm_params = vm_manager2.create(instance_id, location, stemcell_info, resource_pool, network_configurator, env)
                expect(vm_params[:name]).to eq(vm_name)
              end
            end

            context "when platform_update_domain_count and platform_fault_domain_count are set" do
              let(:resource_pool) {
                {
                  'instance_type' => 'Standard_D1',
                  'availability_set' => availability_set_name,
                  'platform_update_domain_count' => 4,
                  'platform_fault_domain_count' => 1
                }
              }

              let(:avset_params) {
                {
                  :name                         => resource_pool['availability_set'],
                  :location                     => location,
                  :tags                         => {'user-agent' => 'bosh'},
                  :platform_update_domain_count => 4,
                  :platform_fault_domain_count  => 1,
                  :managed                      => true # It does NOT matter whether it is managed or not for this case
                }
              }

              before do
                allow(client2).to receive(:get_availability_set_by_name).
                  with(resource_group_name, resource_pool['availability_set']).
                  and_return(nil)
              end

              it "should create the availability set with the specified values" do
                expect(client2).to receive(:create_availability_set).with(resource_group_name, avset_params)
                expect(client2).to receive(:create_network_interface).twice

                vm_params = vm_manager2.create(instance_id, location, stemcell_info, resource_pool, network_configurator, env)
                expect(vm_params[:name]).to eq(vm_name)
              end
            end
          end

          context "when the availability set exists and the managed property is not aligned with @use_managed_disks" do
            let(:availability_set_name) { "#{SecureRandom.uuid}" }
            let(:resource_pool) {
              {
                'instance_type' => 'Standard_D1',
                'availability_set' => availability_set_name,
              }
            }

            let(:existing_avset) {
              {
                :name                         => resource_pool['availability_set'],
                :location                     => location,
                :tags                         => {'user-agent' => 'bosh'},
                :platform_update_domain_count => 5,
                :platform_fault_domain_count  => 3,
                :managed                      => false
              }
            }
            let(:avset_params) {
              {
                :name                         => existing_avset[:name],
                :location                     => existing_avset[:location],
                :tags                         => existing_avset[:tags],
                :platform_update_domain_count => existing_avset[:platform_update_domain_count],
                :platform_fault_domain_count  => existing_avset[:platform_fault_domain_count],
                :managed                      => true
              }
            }

            before do
              allow(client2).to receive(:get_availability_set_by_name).
                with(resource_group_name, resource_pool['availability_set']).
                and_return(existing_avset)
            end

            it "should update the managed property of the availability set" do
              expect(client2).to receive(:create_availability_set).with(resource_group_name, avset_params)
              expect(client2).to receive(:create_network_interface).twice

              vm_params = vm_manager2.create(instance_id, location, stemcell_info, resource_pool, network_configurator, env)
              expect(vm_params[:name]).to eq(vm_name)
            end
          end
        end

        context "with assign dynamic public IP enabled" do
          let(:dynamic_public_ip) { 'fake-dynamic-public-ip' }
          let(:nic0_params) {
            {
              :name            => "#{vm_name}-0",
              :location        => location,
              :private_ip      => nil,
              :public_ip       => dynamic_public_ip,
              :security_group  => security_group,
              :ipconfig_name   => "ipconfig0"
            }
          }
          let(:tags) { {'user-agent' => 'bosh'} }

          before do
            resource_pool['assign_dynamic_public_ip'] = true
            allow(network_configurator).to receive(:vip_network).
              and_return(nil)
            allow(client2).to receive(:get_public_ip_by_name).
              with(resource_group_name, vm_name).and_return(dynamic_public_ip)
          end

          context "and pip_idle_timeout_in_minutes is set" do
            let(:vm_manager_for_pip) { Bosh::AzureCloud::VMManager.new(
              mock_azure_properties_merge({
                'pip_idle_timeout_in_minutes' => 20
              }), registry_endpoint, disk_manager, disk_manager2, client2, storage_account_manager)
            }

            it "creates a public IP and assigns it to the NIC" do
              expect(client2).to receive(:create_public_ip).
                with(resource_group_name, vm_name, location, false, 20)
              expect(client2).to receive(:create_network_interface).
                with(resource_group_name, nic0_params, subnet, tags, load_balancer)

              vm_params = vm_manager_for_pip.create(instance_id, location, stemcell_info, resource_pool, network_configurator, env)
              expect(vm_params[:name]).to eq(vm_name)
            end
          end

          context "and pip_idle_timeout_in_minutes is not set" do
            it "creates a public IP and assigns it to the NIC" do
              expect(client2).to receive(:create_public_ip).
                with(resource_group_name, vm_name, location, false, 4)
              expect(client2).to receive(:create_network_interface).
                with(resource_group_name, nic0_params, subnet, tags, load_balancer)

              vm_params = vm_manager.create(instance_id, location, stemcell_info, resource_pool, network_configurator, env)
              expect(vm_params[:name]).to eq(vm_name)
            end
          end
        end

        context "with use_managed_disks enabled" do
          let(:availability_set_name) { "#{SecureRandom.uuid}" }

          let(:network_interfaces) {
            [
              {:name => "foo"},
              {:name => "foo"}
            ]
          }

          context "when os type is linux" do
            let(:user_data) {
              {
                :registry          => { :endpoint   => registry_endpoint },
                :server            => { :name       => instance_id_string },
                :dns               => { :nameserver => 'fake-dns'}
              }
            }
            let(:vm_params) {
              {
                :name                => vm_name,
                :location            => location,
                :tags                => { 'user-agent' => 'bosh' },
                :vm_size             => "Standard_D1",
                :ssh_username        => azure_properties_managed['ssh_user'],
                :ssh_cert_data       => azure_properties_managed['ssh_public_key'],
                :custom_data         => Base64.strict_encode64(JSON.dump(user_data)),
                :os_disk             => os_disk_managed,
                :ephemeral_disk      => ephemeral_disk_managed,
                :os_type             => "linux",
                :managed             => true,
                :image_id            => "fake-uri"
              }
            }

            before do
              allow(stemcell_info).to receive(:os_type).and_return('linux')
            end

            it "should succeed" do
              expect(client2).not_to receive(:delete_virtual_machine)
              expect(client2).not_to receive(:delete_network_interface)
              expect(client2).to receive(:create_virtual_machine).
                with(resource_group_name, vm_params, network_interfaces, nil)
              result = vm_manager2.create(instance_id, location, stemcell_info, resource_pool, network_configurator, env)
              expect(result[:name]).to eq(vm_name)
            end
          end

          context "when os type is windows" do
            let(:uuid) { '25900ee5-1215-433c-8b88-f1eaaa9731fe' }
            let(:computer_name) { 'fake-server-name' }
            let(:user_data) {
              {
                :registry          => { :endpoint   => registry_endpoint },
                :'instance-id'     => instance_id_string,
                :server            => { :name       => computer_name },
                :dns               => { :nameserver => 'fake-dns'}
              }
            }
            let(:vm_params) {
              {
                :name                => vm_name,
                :location            => location,
                :tags                => { 'user-agent' => 'bosh' },
                :vm_size             => "Standard_D1",
                :windows_username    => uuid.delete('-')[0,20],
                :windows_password    => 'fake-array',
                :custom_data         => Base64.strict_encode64(JSON.dump(user_data)),
                :os_disk             => os_disk_managed,
                :ephemeral_disk      => ephemeral_disk_managed,
                :os_type             => "windows",
                :managed             => true,
                :image_id            => "fake-uri",
                :computer_name       => computer_name
              }
            }

            before do
              allow(SecureRandom).to receive(:uuid).and_return(uuid)
              expect_any_instance_of(Array).to receive(:shuffle).and_return(['fake-array'])
              allow(stemcell_info).to receive(:os_type).and_return('windows')
              allow(vm_manager2).to receive(:generate_windows_computer_name).and_return(computer_name)
            end

            it "should succeed" do
              expect(client2).to receive(:create_virtual_machine).
                with(resource_group_name, vm_params, network_interfaces, nil)
              expect(SecureRandom).to receive(:uuid).exactly(3).times
              expect {
               vm_manager2.create(instance_id, location, stemcell_info, resource_pool, network_configurator, env)
              }.not_to raise_error
            end
          end
        end

        context "when AzureAsynchronousError is raised once and AzureAsynchronousError.status is Failed" do
          context " and use_managed_disks is false" do
            it "should succeed" do
              count = 0
              allow(client2).to receive(:create_virtual_machine) do
                  count += 1
                  count == 1 ? raise(Bosh::AzureCloud::AzureAsynchronousError.new('Failed')) : nil
              end

              expect(client2).to receive(:create_virtual_machine).twice
              expect(client2).to receive(:delete_virtual_machine).once
              expect(disk_manager).to receive(:generate_os_disk_name).with(vm_name).once
              expect(disk_manager).to receive(:delete_disk).with(storage_account_name, os_disk_name).once
              expect(disk_manager).to receive(:generate_ephemeral_disk_name).with(vm_name).once
              expect(disk_manager).to receive(:delete_disk).with(storage_account_name, ephemeral_disk_name).once
              expect(disk_manager).to receive(:delete_vm_status_files).
                with(storage_account_name, vm_name).once
              expect(client2).not_to receive(:delete_network_interface)

              expect {
                vm_manager.create(instance_id, location, stemcell_info, resource_pool, network_configurator, env)
              }.not_to raise_error
            end
          end

          context " and use_managed_disks is true" do
            it "should succeed" do
              count = 0
              allow(client2).to receive(:create_virtual_machine) do
                  count += 1
                  count == 1 ? raise(Bosh::AzureCloud::AzureAsynchronousError.new('Failed')) : nil
              end

              expect(client2).to receive(:create_virtual_machine).twice
              expect(client2).to receive(:delete_virtual_machine).once
              expect(disk_manager2).to receive(:generate_os_disk_name).with(vm_name).once
              expect(disk_manager2).to receive(:delete_disk).with(resource_group_name, os_disk_name).once
              expect(disk_manager2).to receive(:generate_ephemeral_disk_name).with(vm_name).once
              expect(disk_manager2).to receive(:delete_disk).with(resource_group_name, ephemeral_disk_name).once
              expect(client2).not_to receive(:delete_network_interface)

              expect {
                vm_manager2.create(instance_id, location, stemcell_info, resource_pool, network_configurator, env)
              }.not_to raise_error
            end
          end
        end

        context "when debug mode is on" do
          let(:azure_properties_debug) {
            mock_azure_properties_merge({
              'debug_mode' => true
            })
          }
          let(:vm_manager) { Bosh::AzureCloud::VMManager.new(azure_properties_debug, registry_endpoint, disk_manager, disk_manager2, client2, storage_account_manager) }

          context 'when vm and default storage account are in different locations' do
            let(:vm_location) { 'fake-vm-location' }
            let(:default_storage_account) {
              {
                :location          => 'fake-storage-account-location',
                :storage_blob_host => 'fake-storage-blob-host'
              }
            }

            before do
              allow(storage_account_manager).to receive(:default_storage_account).
                and_return(default_storage_account)
            end

            it "should not enable diagnostics" do
              vm_params = vm_manager.create(instance_id, vm_location, stemcell_info, resource_pool, network_configurator, env)
              expect(vm_params[:diag_storage_uri]).to be(nil)
            end
          end

          context 'when vm and default storage account are in same location' do
            let(:vm_location) { location }
            let(:diag_storage_uri) { 'fake-diag-storage-uri' }
            let(:default_storage_account) {
              {
                :location          => location,
                :storage_blob_host => diag_storage_uri
              }
            }

            before do
              allow(storage_account_manager).to receive(:default_storage_account).
                and_return(default_storage_account)
            end

            it "should enable diagnostics" do
              vm_params = vm_manager.create(instance_id, vm_location, stemcell_info, resource_pool, network_configurator, env)
              expect(vm_params[:diag_storage_uri]).to eq(diag_storage_uri)
            end
          end
        end
      end
    end
  end
end
