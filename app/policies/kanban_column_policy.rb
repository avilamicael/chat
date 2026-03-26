class KanbanColumnPolicy < ApplicationPolicy
  def index?
    @account_user.present?
  end

  def create?
    @account_user.administrator?
  end

  def update?
    @account_user.administrator?
  end

  def destroy?
    @account_user.administrator?
  end

  def reorder?
    @account_user.administrator?
  end
end
