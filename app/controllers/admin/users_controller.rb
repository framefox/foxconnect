class Admin::UsersController < Admin::ApplicationController
  before_action :set_user, only: [ :show, :edit, :update, :destroy, :impersonate ]
  skip_before_action :require_admin!, only: [ :stop_impersonating ], if: :impersonating?

  def index
    @pagy, @users = pagy(User.includes(:stores, :shopify_customers).order(created_at: :desc))
  end

  def show
    @stores = @user.stores
    @shopify_customers = @user.shopify_customers
  end

  def impersonate
    # Store the admin user's ID before impersonating
    session[:admin_user_id] = current_user.id
    session[:impersonating] = true
    session[:impersonated_user_id] = @user.id

    # Use Devise's sign_in to properly authenticate as the user
    sign_in(@user)

    redirect_to connections_root_path, notice: "Now viewing as #{@user.full_name}"
  end

  def stop_impersonating
    impersonated_user_id = session[:impersonated_user_id]
    admin_user_id = session[:admin_user_id]

    # Clear impersonation session
    session[:impersonating] = nil
    session[:impersonated_user_id] = nil
    session[:admin_user_id] = nil

    # Sign out the impersonated user and sign back in as admin
    sign_out(current_user) if current_user

    # Log back in as the admin user
    if admin_user_id
      admin_user = User.find_by(id: admin_user_id)
      sign_in(admin_user) if admin_user&.admin?
    end

    if impersonated_user_id
      redirect_to admin_user_path(impersonated_user_id), notice: "Stopped impersonating user"
    else
      redirect_to admin_users_path, notice: "Stopped impersonating user"
    end
  end

  def new
    @user = User.new
  end

  def create
    @user = User.new(user_params)
    if @user.save
      redirect_to admin_user_path(@user), notice: "User created successfully"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @user.update(user_params)
      redirect_to admin_user_path(@user), notice: "User updated successfully"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @user.destroy
    redirect_to admin_users_path, notice: "User deleted successfully"
  end

  private

  def set_user
    @user = User.find(params[:id])
  end

  def user_params
    params.require(:user).permit(:email, :first_name, :last_name, :admin, :password, :password_confirmation)
  end
end
