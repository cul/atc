# frozen_string_literal: true

class Ability
  include CanCan::Ability

  ACCESS_S3_BROWSER_UI = :access_s3_browser
  ACCESS_API_READ_METHODS = :access_api_read_methods

  def initialize(user)
    # Define abilities for the user here. For example:
    #
    #   return unless user.present?
    #   can :read, :all
    #   return unless user.admin?
    #   can :manage, :all
    #
    # The first argument to `can` is the action you are giving the user
    # permission to do.
    # If you pass :manage it will apply to every action. Other common actions
    # here are :read, :create, :update and :destroy.
    #
    # The second argument is the resource the user can perform the action on.
    # If you pass :all it will apply to every resource. Otherwise pass a Ruby
    # class of the resource.
    #
    # The third argument is an optional hash of conditions to further filter the
    # objects.
    # For example, here the user can only update published articles.
    #
    #   can :update, Article, published: true
    #
    # See the wiki for details:
    # https://github.com/CanCanCommunity/cancancan/blob/develop/docs/define_check_abilities.md

    #
    # Currently, this ability file enforces 0 restrictions based on the current user
    # In the future, we will want to restrict certain users from accessing certain
    # APIs/endpoints, while allowing others to use those features. That will be implemented
    # here.
    #
    return if user.blank?

    can ACCESS_S3_BROWSER_UI, UiController

    # We can add more Api Controllers and restrict access based on the current user
    # Right now, any authenticated user can access any API
    can ACCESS_API_READ_METHODS, Api::S3BrowserController
    can ACCESS_API_READ_METHODS, Api::UsersController

    if user.admin?
      can :manage, CsvExport
    else
      # Includes index and show actions
      can :read, CsvExport, user_id: user.id
    end
  end
end
