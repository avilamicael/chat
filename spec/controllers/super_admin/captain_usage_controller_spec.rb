require 'rails_helper'

RSpec.describe 'Super Admin Captain Usage', type: :request do
  let(:super_admin) { create(:super_admin) }
  let(:account) { create(:account) }

  # Administrate's base controller raises on missing CSRF token regardless of the global
  # test setting; the production form uses form_with (token included), so we disable forgery
  # protection for the POST examples to exercise the action logic directly.
  around do |example|
    original = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = false
    example.run
    ActionController::Base.allow_forgery_protection = original
  end

  def create_event(account:, feature:, cost_usd_micros:, created_at:, model: 'gpt-4o-mini')
    Captain::UsageEvent.create!(
      account: account, feature: feature, model: model,
      input_tokens: 0, output_tokens: 0,
      cost_micros: 0, cost_usd_micros: cost_usd_micros, created_at: created_at
    )
  end

  describe 'GET /super_admin/captain_usage' do
    context 'when unauthenticated' do
      it 'redirects' do
        get '/super_admin/captain_usage'
        expect(response).to have_http_status(:redirect)
      end
    end

    context 'when authenticated' do
      before { sign_in(super_admin, scope: :super_admin) }

      it 'renders only the selected month and changes with the month param (SPEC req 7)' do
        create_event(account: account, feature: 'task', cost_usd_micros: 1_000_000, created_at: Time.zone.parse('2026-03-15'))
        create_event(account: account, feature: 'task', cost_usd_micros: 2_000_000, created_at: Time.zone.parse('2026-04-15'))

        get '/super_admin/captain_usage', params: { month: '2026-03' }
        expect(response).to have_http_status(:success)
        expect(response.body).to include('US$ 1')

        get '/super_admin/captain_usage', params: { month: '2026-04' }
        expect(response.body).to include('US$ 2')
      end

      it 'falls back to the current month when the month param is malformed (T-07D-05)' do
        get '/super_admin/captain_usage', params: { month: 'garbage' }
        expect(response).to have_http_status(:success)
      end

      it 'derives the paid rate from the month-wide USD total, not each account slice (CR-01 / D-01a)' do
        account_b = create(:account)
        # Invoice R$540 for the whole month; account A used $1, account B used $99 → effective rate 5.40 for BOTH.
        create_event(account: account, feature: 'task', cost_usd_micros: 1_000_000, created_at: Time.zone.parse('2026-04-10'))
        create_event(account: account_b, feature: 'task', cost_usd_micros: 99_000_000, created_at: Time.zone.parse('2026-04-10'))
        Captain::BillingMonth.create!(account_id: nil, period: '2026-04', total_brl_pago_micros: 540_000_000, taxa_atual: 1)

        get '/super_admin/captain_usage', params: { month: '2026-04' }
        rows = controller.view_assigns['rows']
        account_a_row = rows.find { |row| row[:account_id] == account.id }
        account_b_row = rows.find { |row| row[:account_id] == account_b.id }

        # base_paga = cost_usd * 5.40, NOT cost_usd * (540 / own_usd)
        expect(account_a_row[:base_paga]).to be_within(0.01).of(1.0 * 5.40)
        expect(account_b_row[:base_paga]).to be_within(0.01).of(99.0 * 5.40)
      end
    end
  end

  describe 'per-account override inherits global price params (WR-03)' do
    before { sign_in(super_admin, scope: :super_admin) }

    it 'uses the global mensalidade/unidades/excedente when the account override only sets a rate' do
      create_event(account: account, feature: 'task', cost_usd_micros: 1_000_000, created_at: Time.zone.parse('2026-04-10'))
      Captain::BillingMonth.create!(account_id: nil, period: '2026-04', mensalidade_micros: 200_000_000,
                                    unidades_inclusas: 1000, preco_excedente_micros: 200_000, taxa_atual: 5.4)
      Captain::BillingMonth.create!(account_id: account.id, period: '2026-04', taxa_paga: 6.0)

      get '/super_admin/captain_usage', params: { month: '2026-04' }
      row = controller.view_assigns['rows'].find { |entry| entry[:account_id] == account.id }

      # mensalidade inherited from global (R$200), not silently zeroed by the rate-only override.
      expect(row[:preco_venda]).to be_within(0.01).of(200.0)
    end
  end

  describe 'POST /super_admin/captain_usage/update_billing' do
    before { sign_in(super_admin, scope: :super_admin) }

    it 'saves a global default billing row when account_id is absent (D-03)' do
      post '/super_admin/captain_usage/update_billing',
           params: { period: '2026-04', billing: { taxa_paga: '5.50', taxa_atual: '5.90' } }

      expect(response).to have_http_status(:redirect)
      global = Captain::BillingMonth.find_by(account_id: nil, period: '2026-04')
      expect(global.taxa_paga).to eq(5.50)
      expect(global.taxa_atual).to eq(5.90)
    end

    it 'saves a per-account billing override when account_id is present (D-03)' do
      post '/super_admin/captain_usage/update_billing',
           params: { period: '2026-04', account_id: account.id, billing: { taxa_paga: '6.00' } }

      override = Captain::BillingMonth.find_by(account_id: account.id, period: '2026-04')
      expect(override.taxa_paga).to eq(6.00)
    end

    it 'persists total_brl_pago_micros submitted without taxa_paga (D-01a form a)' do
      post '/super_admin/captain_usage/update_billing',
           params: { period: '2026-04', billing: { total_brl_pago_micros: '540000000' } }

      global = Captain::BillingMonth.find_by(account_id: nil, period: '2026-04')
      expect(global.total_brl_pago_micros).to eq(540_000_000)
      expect(global.taxa_paga).to be_nil
    end

    it 'rejects negative values without persisting garbage (T-07D-03)' do
      post '/super_admin/captain_usage/update_billing',
           params: { period: '2026-04', billing: { taxa_paga: '-5.0' } }

      expect(Captain::BillingMonth.find_by(account_id: nil, period: '2026-04')).to be_nil
    end
  end
end
