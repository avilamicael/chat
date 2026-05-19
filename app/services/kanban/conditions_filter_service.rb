require 'json'

# Sibling filter service para conditions Kanban.
# D6 do PROJECT.md / D-A2 do CONTEXT: NÃO herda de AutomationRules::ConditionsFilterService
# para que mudanças no engine de filter principal não afetem Kanban e vice-versa.
# Duplica conversation_query_string/contact_query_string/build_label_query_string/filter_operation
# conscientemente — tradeoff: ~60 LOC duplicadas em troca de blast radius zero.
# rubocop:disable Metrics/ClassLength -- sibling explícito (D6 do PROJECT.md) duplica intencionalmente helpers do principal
class Kanban::ConditionsFilterService < FilterService
  ATTRIBUTE_MODEL = 'kanban_card_attribute'.freeze

  def initialize(rule, card, conversation: nil, options: {})
    super([], nil)
    @rule = rule
    @card = card
    @conversation = conversation
    @account = card.account || card.kanban_board.account

    file = File.read('./lib/filters/filter_keys.yml')
    @filters = YAML.safe_load(file)

    @kanban_card_filters = @filters['kanban_cards'] || {}
    @conversation_filters = @filters['conversations']
    @contact_filters = @filters['contacts']
    @message_filters = @filters['messages']

    @options = options
    @changed_attributes = nil
  end

  def perform
    return false unless rule_valid?

    @rule.conditions.each_with_index do |query_hash, current_index|
      apply_filter(query_hash, current_index)
    end

    base_relation.where(@query_string, @filter_values.with_indifferent_access).any?
  rescue StandardError => e
    Rails.logger.error "Error in Kanban::ConditionsFilterService: #{e.message}"
    Rails.logger.info "Kanban::ConditionsFilterService failed while processing rule #{@rule.id} for card #{@card.id}"
    false
  end

  def rule_valid?
    is_valid = AutomationRules::ConditionValidationService.new(@rule).perform
    Rails.logger.info "Automation rule condition validation failed for rule id: #{@rule.id}" unless is_valid
    @rule.authorization_error! unless is_valid

    is_valid
  end

  # Override estendido vs FilterService base — espelha o pattern do AutomationRules::ConditionsFilterService
  # com +2 operators novos (ends_with, matches_regex) introduzidos nesta fase (D-C1).
  def filter_operation(query_hash, current_index)
    case query_hash[:filter_operator]
    when 'starts_with'
      @filter_values["value_#{current_index}"] = "#{string_filter_values(query_hash)}%"
      like_filter_string(query_hash[:filter_operator], current_index)
    when 'ends_with'
      @filter_values["value_#{current_index}"] = "%#{string_filter_values(query_hash)}"
      like_filter_string(query_hash[:filter_operator], current_index)
    when 'matches_regex'
      @filter_values["value_#{current_index}"] = string_filter_values(query_hash)
      "~* :value_#{current_index}"
    else
      super
    end
  end

  def apply_filter(query_hash, current_index)
    key = query_hash['attribute_key']
    hash = query_hash.with_indifferent_access
    fragment = filter_fragment_for(key, hash, current_index)
    @query_string += fragment if fragment
  end

  # Mapeia attribute_keys da seção `kanban_cards` (filter_keys.yml) para colunas reais em `kanban_cards`.
  # `target_column_id` → coluna `kanban_column_id` (target = coluna ATUAL do card após a movimentação).
  KANBAN_CARD_COLUMNS = {
    'target_column_id' => 'kanban_column_id',
    'kanban_board_id' => 'kanban_board_id',
    'task_status' => 'task_status',
    'assignee_id' => 'assignee_id'
  }.freeze

  def kanban_card_query_string(_current_filter, query_hash, current_index)
    key = query_hash['attribute_key']
    return kanban_source_column_query(query_hash, current_index) if key == 'source_column_id'
    return kanban_priority_query(query_hash, current_index) if key == 'priority'

    column = KANBAN_CARD_COLUMNS[key]
    return nil if column.blank?

    " kanban_cards.#{column} #{filter_operation(query_hash, current_index)} #{query_hash['query_operator']} "
  end

  def kanban_custom_attribute_query(query_hash, current_index)
    attribute_key = query_hash['attribute_key']
    query_operator = query_hash['query_operator']
    filter_operator_value = filter_operation(query_hash, current_index)
    " kanban_cards.custom_attributes ->> '#{attribute_key}' #{filter_operator_value} #{query_operator} "
  end

  def custom_attribute_kanban?(key)
    return false if key.blank?

    @account.custom_attribute_definitions
            .where(attribute_model: 'kanban_card_attribute')
            .exists?(attribute_key: key)
  end

  # Copiado do AutomationRules::ConditionsFilterService (linhas 130-142) — sibling independente.
  def contact_query_string(current_filter, query_hash, current_index)
    attribute_key = query_hash['attribute_key']
    query_operator = query_hash['query_operator']
    filter_operator_value = filter_operation(query_hash, current_index)

    case current_filter['attribute_type']
    when 'additional_attributes'
      " contacts.additional_attributes ->> '#{attribute_key}' #{filter_operator_value} #{query_operator} "
    when 'standard'
      " contacts.#{attribute_key} #{filter_operator_value} #{query_operator} "
    end
  end

  # Copiado/adaptado do AutomationRules::ConditionsFilterService (linhas 144-159).
  # Adiciona branch channel_type que traduz display name → class name via Channel::TypeNormalizer
  # antes de comparar contra inboxes.channel_type (D-B4 + D-C4).
  def conversation_query_string(table_name, current_filter, query_hash, current_index)
    attribute_key = query_hash['attribute_key']
    query_operator = query_hash['query_operator']

    if attribute_key == 'channel_type'
      normalized = Array(query_hash['values']).map { |v| Channel::TypeNormalizer.normalize(v) || v }
      @filter_values["value_#{current_index}"] = normalized
      filter_operator_value = equals_to_filter_string(query_hash[:filter_operator], current_index)
      return " inboxes.channel_type #{filter_operator_value} #{query_operator} "
    end

    filter_operator_value = filter_operation(query_hash, current_index)

    case current_filter['attribute_type']
    when 'additional_attributes'
      " #{table_name}.additional_attributes ->> '#{attribute_key}' #{filter_operator_value} #{query_operator} "
    when 'standard'
      if attribute_key == 'labels'
        build_label_query_string(query_hash, current_index, query_operator)
      else
        " #{table_name}.#{attribute_key} #{filter_operator_value} #{query_operator} "
      end
    end
  end

  # Copiado do AutomationRules::ConditionsFilterService (linhas 161-182).
  def build_label_query_string(query_hash, current_index, query_operator)
    case query_hash['filter_operator']
    when 'equal_to'
      return " 1=0 #{query_operator} " if query_hash['values'].blank?

      value_placeholder = "value_#{current_index}"
      @filter_values[value_placeholder] = query_hash['values'].first
      " tags.name = :#{value_placeholder} #{query_operator} "
    when 'not_equal_to'
      return " 1=0 #{query_operator} " if query_hash['values'].blank?

      value_placeholder = "value_#{current_index}"
      @filter_values[value_placeholder] = query_hash['values'].first
      " tags.name != :#{value_placeholder} #{query_operator} "
    when 'is_present'
      " tags.id IS NOT NULL #{query_operator} "
    when 'is_not_present'
      " tags.id IS NULL #{query_operator} "
    else
      " tags.id #{filter_operation(query_hash, current_index)} #{query_operator} "
    end
  end

  private

  def filter_fragment_for(key, query_hash, current_index)
    standard_fragment_for(key, query_hash, current_index) ||
      custom_attribute_fragment_for(key, query_hash, current_index)
  end

  def standard_fragment_for(key, query_hash, current_index)
    if @kanban_card_filters[key]
      kanban_card_query_string(@kanban_card_filters[key], query_hash, current_index)
    elsif @conversation_filters[key] && @conversation.present?
      conversation_query_string('conversations', @conversation_filters[key], query_hash, current_index)
    elsif @contact_filters[key] && @conversation&.contact.present?
      contact_query_string(@contact_filters[key], query_hash, current_index)
    end
    # @message_filters[key]: Kanban events não carregam message context — skip silencioso (D-A2).
  end

  def custom_attribute_fragment_for(key, query_hash, current_index)
    return kanban_custom_attribute_query(query_hash, current_index) if custom_attribute_kanban?(key)
    return nil unless @conversation.present? && custom_attribute(key, @account, query_hash['custom_attribute_type'])

    custom_attribute_query(query_hash, query_hash['custom_attribute_type'], current_index)
  end

  def kanban_source_column_query(query_hash, current_index)
    # Transient — não há coluna persistida; vem de event.data[:source_column_id] no listener.
    return ' 1=0 ' if @options[:source_column_id].blank?

    @filter_values["value_#{current_index}"] = Array(@options[:source_column_id])
    " :value_#{current_index} #{filter_operation(query_hash, current_index)} #{query_hash['query_operator']} "
  end

  def kanban_priority_query(query_hash, current_index)
    # KanbanCard.priority é enum INTEGER. UI manda strings "high"/etc — mapeia para int via enum.
    mapped = Array(query_hash['values']).map { |v| KanbanCard.priorities[v.to_s] || v }
    mapped_hash = query_hash.merge('values' => mapped)
    " kanban_cards.priority #{filter_operation(mapped_hash, current_index)} #{query_hash['query_operator']} "
  end

  def base_relation
    records = KanbanCard.where(id: @card.id)

    if @conversation.present?
      records = records.joins('LEFT OUTER JOIN conversations ON kanban_cards.conversation_id = conversations.id')
                       .joins('LEFT OUTER JOIN inboxes ON conversations.inbox_id = inboxes.id')
                       .joins('LEFT OUTER JOIN contacts ON conversations.contact_id = contacts.id')

      if label_conditions?
        records = records.joins("LEFT OUTER JOIN taggings ON taggings.taggable_id = conversations.id AND taggings.taggable_type = 'Conversation'")
                         .joins('LEFT OUTER JOIN tags ON taggings.tag_id = tags.id')
      end
    end

    records
  end

  def label_conditions?
    @rule.conditions.any? { |condition| condition['attribute_key'] == 'labels' }
  end
end
# rubocop:enable Metrics/ClassLength
