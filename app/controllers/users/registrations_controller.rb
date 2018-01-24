class Users::RegistrationsController < Devise::RegistrationsController
  # POST /resource
  def create
    build_resource(sign_up_params)
    resource.save
    yield resource if block_given?
    if resource.persisted?
      @@subscription_service = SubscriptionService.new(resource, params)
      @@subscription_service.create_subscription
      if resource.active_for_authentication?
        set_flash_message! :notice, :signed_up
        sign_up(resource_name, resource)
        respond_with resource, location: after_sign_up_path_for(resource)
      else
        set_flash_message! :notice, :"signed_up_but_#{resource.inactive_message}"
        expire_data_after_sign_in!
        respond_with resource, location: after_inactive_sign_up_path_for(resource)
      end
    else
      clean_up_passwords resource
      set_minimum_password_length
      respond_with resource
    end
  end

  def destroy
    @@subscription_service = SubscriptionService.new(current_user, params)
    if @@subscription_service.destroy_subscription
      resource.discard
      resource.role = :removed
      Devise.sign_out_all_scopes ? sign_out : sign_out(resource_name)
      set_flash_message! :notice, :destroyed
      yield resource if block_given?
      redirect_to cancelled_path
    else
      set_flash_message! :error, :stripe_communication_error
      redirect_to edit_user_registration_path
    end
  end

  protected

  def after_update_path_for(resource)
    edit_user_registration_path
  end

  def after_sign_up_path_for(resource)
    if resource.subscribed?
      dashboard_path
    else
      billing_path
    end
  end
end
