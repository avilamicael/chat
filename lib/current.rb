module Current
  thread_mattr_accessor :user
  thread_mattr_accessor :account
  thread_mattr_accessor :account_user
  thread_mattr_accessor :executed_by
  thread_mattr_accessor :contact
  thread_mattr_accessor :automation_depth
  # AUT-04 Plan C: cadeia de rule_ids visitados ao longo de uma cascata.
  # ActionService push no perform; abort_loop_and_disable! lê a cadeia para
  # gravar em last_execution_error e enviar no meta da notificação ao admin.
  thread_mattr_accessor :automation_chain

  def self.reset
    Current.user = nil
    Current.account = nil
    Current.account_user = nil
    Current.executed_by = nil
    Current.contact = nil
    Current.automation_depth = nil
    Current.automation_chain = nil
  end
end
