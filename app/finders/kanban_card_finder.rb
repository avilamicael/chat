class KanbanCardFinder
  attr_reader :board, :params

  DEFAULT_PER_PAGE = 50
  MAX_PER_PAGE = 200

  def initialize(board, params)
    @board = board
    @params = params || {}
  end

  def perform
    scope = base_scope
    scope = filter_by_column(scope)
    scope = filter_by_assignees(scope)
    scope = filter_by_teams(scope)
    scope = filter_by_priority(scope)
    scope = filter_by_task_status(scope)
    scope = filter_by_period(scope)
    scope = filter_by_inboxes(scope)
    scope = filter_by_labels(scope)
    scope = filter_by_text(scope)
    paginate(scope)
  end

  private

  def base_scope
    @board.kanban_cards.active.includes(
      :kanban_card_conversations,
      :assignee,
      conversation: [:assignee, :inbox, :contact, :taggings]
    )
  end

  def filter_by_column(scope)
    return scope if params[:column_id].blank?

    scope.where(kanban_column_id: params[:column_id].to_i)
  end

  def filter_by_assignees(scope)
    ids = Array(params[:assignee_ids].presence || params[:assignee_id]).map(&:to_i).reject(&:zero?)
    return scope if ids.empty?

    # OR dentro do mesmo campo (D-07) — assignee_ids é Postgres int[] (default []).
    # Operador && retorna true se há intersecção entre os arrays.
    scope.where('kanban_cards.assignee_ids && ARRAY[?]::integer[]', ids)
  end

  def filter_by_teams(scope)
    ids = Array(params[:team_ids]).map(&:to_i).reject(&:zero?)
    return scope if ids.empty?

    scope.where('kanban_cards.team_ids && ARRAY[?]::integer[]', ids)
  end

  def filter_by_priority(scope)
    values = Array(params[:priority]).map(&:to_s).reject(&:blank?)
    return scope if values.empty?

    scope.where(priority: values)
  end

  def filter_by_task_status(scope)
    values = Array(params[:task_status]).map(&:to_s).reject(&:blank?)
    return scope if values.empty?

    scope.where(task_status: values)
  end

  def filter_by_period(scope)
    scope = scope.where('kanban_cards.created_at >= ?', params[:created_at_gte]) if params[:created_at_gte].present?
    scope = scope.where('kanban_cards.created_at <= ?', params[:created_at_lte]) if params[:created_at_lte].present?
    scope
  end

  def filter_by_inboxes(scope)
    ids = Array(params[:inbox_ids]).map(&:to_i).reject(&:zero?)
    return scope if ids.empty?

    # Card pode estar ligado a uma conversation primária (kanban_cards.conversation_id) OU via
    # kanban_card_conversations (many-to-many em linked_conversations). Card standalone (sem
    # conversation_id E sem linked_conversations) NÃO passa neste filtro — semanticamente
    # tasks soltas não pertencem a inbox alguma. Decisão técnica documentada (Claude's
    # Discretion D-09; ver 01-RESEARCH.md Pattern 2 linhas 466-470).
    card_ids_via_primary = scope.joins(:conversation).where(conversations: { inbox_id: ids }).select('kanban_cards.id')
    card_ids_via_link    = scope.joins(:linked_conversations).where(conversations: { inbox_id: ids }).select('kanban_cards.id')
    scope.where(id: card_ids_via_primary).or(scope.where(id: card_ids_via_link))
  end

  def filter_by_labels(scope)
    labels = Array(params[:label_list]).map(&:to_s).reject(&:blank?)
    return scope if labels.empty?

    # Conversation tem acts_as_taggable_on :labels. Card herda via Conversation linkada
    # (primária ou linked_conversations). Tags próprias no card são deferred.
    convo_ids = Conversation.tagged_with(labels, any: true).select(:id)
    scope.where(id: scope.joins(:conversation).where(conversations: { id: convo_ids }).select('kanban_cards.id'))
         .or(scope.where(id: scope.joins(:linked_conversations).where(conversations: { id: convo_ids }).select('kanban_cards.id')))
  end

  def filter_by_text(scope)
    return scope if params[:q].blank?

    # text_search por ÚLTIMO preserva ranking do pg_search (Anti-Pattern 01-RESEARCH.md:656).
    scope.text_search(params[:q])
  end

  def paginate(scope)
    page = params[:page].to_i
    page = 1 if page < 1
    per = [(params[:per_page] || DEFAULT_PER_PAGE).to_i, MAX_PER_PAGE].min
    per = DEFAULT_PER_PAGE if per < 1

    scope.page(page).per(per)
  end
end
