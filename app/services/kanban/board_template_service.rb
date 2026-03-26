class Kanban::BoardTemplateService
  TEMPLATES = {
    'sales_funnel' => {
      'en' => [
        { name: 'New Lead', color: '#3B82F6' },
        { name: 'Qualifying', color: '#F59E0B' },
        { name: 'Proposal Sent', color: '#8B5CF6' },
        { name: 'Negotiation', color: '#F97316' },
        { name: 'Lost', color: '#EF4444', column_type: 'lost' },
        { name: 'Won', color: '#10B981', column_type: 'won' }
      ],
      'pt_BR' => [
        { name: 'Novo Lead', color: '#3B82F6' },
        { name: 'Qualificando', color: '#F59E0B' },
        { name: 'Proposta Enviada', color: '#8B5CF6' },
        { name: 'Negociação', color: '#F97316' },
        { name: 'Perdido', color: '#EF4444', column_type: 'lost' },
        { name: 'Ganho', color: '#10B981', column_type: 'won' }
      ]
    },
    'support_funnel' => {
      'en' => [
        { name: 'New', color: '#6B7280' },
        { name: 'In Progress', color: '#3B82F6' },
        { name: 'Waiting for Customer', color: '#F59E0B' },
        { name: 'Resolved', color: '#10B981', column_type: 'won' }
      ],
      'pt_BR' => [
        { name: 'Novo', color: '#6B7280' },
        { name: 'Em Andamento', color: '#3B82F6' },
        { name: 'Aguardando Cliente', color: '#F59E0B' },
        { name: 'Resolvido', color: '#10B981', column_type: 'won' }
      ]
    }
  }.freeze

  def initialize(board:, template:, locale: 'en')
    @board = board
    @template = template
    @locale = locale.to_s
  end

  def perform
    template_data = TEMPLATES[@template] || {}
    # Fallback: try exact locale, then base language, then 'en'
    columns = template_data[@locale] ||
              template_data[@locale.split('_').first] ||
              template_data['en'] ||
              []
    # Also keep backward compat alias
    columns = TEMPLATES.dig('sales_funnel', 'en') || [] if @template == 'sales_pipeline' && columns.empty?
    columns.each_with_index do |col, idx|
      @board.kanban_columns.create!(name: col[:name], color: col[:color], position: idx + 1, column_type: col[:column_type] || 'normal')
    end
  end
end
