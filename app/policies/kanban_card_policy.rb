class KanbanCardPolicy < ApplicationPolicy
  def index?
    @account_user.present?
  end

  def create?
    @account_user.present?
  end

  def update?
    @account_user.present?
  end

  def destroy?
    @account_user.present?
  end

  def move?
    @account_user.present?
  end

  def archived?
    @account_user.present?
  end

  def activities?
    @account_user.present?
  end
end
