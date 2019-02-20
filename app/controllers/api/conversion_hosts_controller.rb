module Api
  class ConversionHostsController < BaseController
    include Subcollections::Tags

    # Whitelist of valid resource types
    VALID_TYPES = {
      'ManageIQ::Providers::Openstack::CloudManager::Vm' => ManageIQ::Providers::Openstack::CloudManager::Vm,
      'ManageIQ::Providers::Redhat::InfraManager::Host'  => ManageIQ::Providers::Redhat::InfraManager::Host
    }.freeze

    # Create a conversion host and enable it. This operation will run as an
    # MiqTask.
    #
    # Both the 'resource_type' and 'resource_id' are mandatory arguments,
    # and the 'resource_type' must be either 'Host' or 'VmOrTemplate'.
    #
    # You may optionally pass in 'param_v2v_vddk_package_url' or 'auth_user'
    # arguments as well.
    #
    # POST /api/conversion_hosts {
    #   "name": "some_name",
    #   "resource_type": "ManageIQ::Providers::Redhat::InfraManager::Host",
    #   "resource_id": "7"
    #   "param_v2v_vddk_package_url": "some_url"
    #   "auth_user": "some_user"
    # }
    #
    def create_resource(type, id, data)
      raise BadRequestError, "resource_id must be specified" unless data['resource_id']
      raise BadRequestError, "resource_type must be specified" unless data['resource_type']
      raise BadRequestError, "invalid resource_type #{data['resource_type']}" unless VALID_TYPES[data['resource_type']]

      resource_type = VALID_TYPES[data['resource_type']]
      collection_type = resource_type.table_name

      # The 'auth_user' param must be deleted since the model will otherwise
      # pass the data hash directly as params to ConversionHost.new.
      auth_user = data.delete('auth_user')
      resource = resource_search(data['resource_id'], resource_type.to_s, collection_class(collection_type))

      data['resource'] = resource

      api_action(type, id) do
        begin
          message = "Enabling resource id:#{resource.id} type:#{resource.type}"
          task_id = ConversionHost.enable_queue(data, auth_user)
          action_result(true, message, :task_id => task_id)
        rescue => err
          action_result(false, err.to_s)
        end
      end
    end

    # Disable the conversion host role by installing the conversion host module
    # and running the conversion host playbook that disables it, then delete
    # the conversion host record. This operation run as an MiqTask.
    #
    # You may optionally provide an 'auth_user' parameter.
    #
    # DELETE /api/conversion_hosts/:id
    # DELETE /api/conversion_hosts/:id { "auth_user": "someone" }
    #
    # Note that you can also delete via a POST action using "action: delete" as
    # a parameter, which will include a response body.
    #
    def delete_resource(type, id, data = {})
      delete_action_handler do
        conversion_host = resource_search(id, type, collection_class(type))
        message = "Disabling and deleting ConversionHost id:#{conversion_host.id} name:#{conversion_host.name}"
        begin
          task_id = conversion_host.disable_queue(data['auth_user']) # Ok if nil
          action_result(true, message, :task_id => task_id)
        rescue => err
          action_result(false, err.to_s)
        end
      end
    end
  end
end
