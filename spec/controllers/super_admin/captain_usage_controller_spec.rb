require 'rails_helper'

RSpec.describe 'Super Admin Captain Usage', type: :request do
  let(:super_admin) { create(:super_admin) }
  let(:account) { create(:account) }

  before { sign_in(super_admin, scope: :super_admin) }

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
        sign_out(super_admin)
        get '/super_admin/captain_usage'
        expect(response).to have_http_status(:redirect)
      end
    end

    it 'aggregates only events of the selected month (SPEC req 7)' do
      create_event(account: account, feature: 'task', cost_usd_micros: 1_000_000, created_at: Time.zone.parse('2026-03-15'))
      create_event(account: account, feature: 'task', cost_usd_micros: 2_000_000, created_at: Time.zone.parse('2026-04-15'))

      get '/super_admin/captain_usage', params: { month: '2026-03' }
      march_row = assigns(:rows).find { |r| r[:account_id] == account.id }
      expect(march_row[:cost_usd]).to eq(1.0)

      get '/super_admin/captain_usage', params: { month: '2026-04' }
      april_row = assigns(:rows).find { |r| r[:account_id] == account.id }
      expect(april_row[:cost_usd]).to eq(2.0)
    end

    it 'falls back to current month when month param is malformed (T-07D-05)' do
      get '/super_admin/captain_usage', params: { month: 'garbage' }
      expect(response).to have_http_status(:success)
      expect(assigns(:period)).to eq(Date.current.strftime('%Y-%m'))
    end

    context 'with two bases (SPEC req 4)' do
      before do
        create_event(account: account, feature: 'task', cost_usd_micros: 10_000_000, created_at: Time.zone.parse('2026-04-10'))
      end

      it 'flags the current rate base as suggested when it is higher' do
        Captain::BillingMonth.create!(period: '2026-04', taxa_paga: 5.00, taxa_atual: 5.80)
        get '/super_admin/captain_usage', params: { month: '2026-04' }
        row = assigns(:rows).find { |r| r[:account_id] == account.id }

        expect(row[:base_paga]).to be_within(0.001).of(50.0)
        expect(row[:base_atual]).to be_within(0.001).of(58.0)
        expect(row[:base_sugerida]).to eq(:atual)
      end

      it 'flags the paid rate base as suggested when it is higher' do
        Captain::BillingMonth.create!(period: '2026-04', taxa_paga: 5.80, taxa_atual: 5.00)
        get '/super_admin/captain_usage', params: { month: '2026-04' }
        row = assigns(:rows).find { |r| r[:account_id] == account.id }

        expect(row[:base_sugerida]).to eq(:paga)
      end

      it 'uses the 5.4 fallback for both bases when no billing exists (D-06)' do
        get '/super_admin/captain_usage', params: { month: '2026-04' }
        row = assigns(:rows).find { |r| r[:account_id] == account.id }

        expect(row[:base_paga]).to be_within(0.001).of(54.0)
        expect(row[:base_atual]).to be_within(0.001).of(54.0)
      end
    end

    context 'with sale price and margin (SPEC req 6)' do
      before do
        1200.times do
          Captain::UsageEvent.create!(
            account: account, feature: 'task', model: 'gpt-4o-mini',
            input_tokens: 0, output_tokens: 0, cost_micros: 0, cost_usd_micros: 0,
            created_at: Time.zone.parse('2026-04-10')
          )
        end
        Captain::BillingMonth.create!(
          period: '2026-04', taxa_paga: 5.40, taxa_atual: 5.40,
          mensalidade_micros: 200_000_000, unidades_inclusas: 1000, preco_excedente_micros: 200_000
        )
      end

      it 'computes preco_venda = mensalidade + excedente x max(0, uso - X)' do
        get '/super_admin/captain_usage', params: { month: '2026-04' }
        row = assigns(:rows).find { |r| r[:account_id] == account.id }

        expect(row[:uso]).to eq(1200)
        expect(row[:preco_venda]).to be_within(0.001).of(240.0)
        expect(row[:margem]).to be_within(0.001).of(240.0 - row[:custo_base])
      end

      it 'has zero overage when uso is below X' do
        Captain::UsageEvent.where(account: account).delete_all
        500.times do
          Captain::UsageEvent.create!(
            account: account, feature: 'task', model: 'gpt-4o-mini',
            input_tokens: 0, output_tokens: 0, cost_micros: 0, cost_usd_micros: 0,
            created_at: Time.zone.parse('2026-04-10')
          )
        end
        get '/super_admin/captain_usage', params: { month: '2026-04' }
        row = assigns(:rows).find { |r| r[:account_id] == account.id }

        expect(row[:uso]).to eq(500)
        expect(row[:preco_venda]).to be_within(0.001).of(200.0)
      end
    end

    it 'separates composition by feature bucket' do
      create_event(account: account, feature: 'task', cost_usd_micros: 0, created_at: Time.zone.parse('2026-04-10'))
      create_event(account: account, feature: 'agent', cost_usd_micros: 0, created_at: Time.zone.parse('2026-04-10'))
      create_event(account: account, feature: 'audio_transcription', cost_usd_micros: 0, created_at: Time.zone.parse('2026-04-10'),
                   model: 'whisper-1')
      create_event(account: account, feature: 'ocr', cost_usd_micros: 0, created_at: Time.zone.parse('2026-04-10'), model: 'gpt-4o')

      get '/super_admin/captain_usage', params: { month: '2026-04' }
      row = assigns(:rows).find { |r| r[:account_id] == account.id }

      expect(row[:text_count]).to eq(2)
      expect(row[:audio_count]).to eq(1)
      expect(row[:ocr_count]).to eq(1)
    end
  end

  describe 'POST /super_admin/captain_usage/update_billing' do
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
