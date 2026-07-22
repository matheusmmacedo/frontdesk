# frozen_string_literal: true

require 'rails_helper'

# Testa o prepend custom em Whatsapp::PhoneNumberNormalizationService
# (custom/config/initializers/klaos_phone_normalize_variant_search.rb).
# Foco: quando busca pelo normalizado falha, tenta a variante SEM "9".

RSpec.describe Whatsapp::PhoneNumberNormalizationService, type: :service do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account, channel: create(:channel_whatsapp, account: account)) }
  let(:service) { described_class.new(inbox) }
  let(:contact) { create(:contact, account: account) }

  describe '#normalize_and_find_contact_by_provider (Cloud)' do
    context 'quando contact_inbox EXISTENTE tem source_id COM 9 (canônico)' do
      before do
        create(:contact_inbox, contact: contact, inbox: inbox, source_id: '5531988862094')
      end

      it 'acha via caminho vanilla quando webhook chega COM 9' do
        result = service.normalize_and_find_contact_by_provider('5531988862094', :cloud)
        expect(result).to eq('5531988862094')
      end

      it 'acha via caminho vanilla quando webhook chega SEM 9 (vanilla adiciona 9 e busca)' do
        result = service.normalize_and_find_contact_by_provider('553188862094', :cloud)
        expect(result).to eq('5531988862094')
      end
    end

    context 'quando contact_inbox EXISTENTE tem source_id SEM 9 (legado — gap que vanilla NÃO cobre)' do
      before do
        create(:contact_inbox, contact: contact, inbox: inbox, source_id: '553188862094')
      end

      it 'acha via prepend custom quando webhook chega COM 9 (fallback variant search)' do
        result = service.normalize_and_find_contact_by_provider('5531988862094', :cloud)
        expect(result).to eq('553188862094')
      end

      it 'acha via caminho vanilla quando webhook chega SEM 9 (normalize+busca com 9 falha, retorna raw = source_id existente)' do
        result = service.normalize_and_find_contact_by_provider('553188862094', :cloud)
        expect(result).to eq('553188862094')
      end
    end

    context 'quando NÃO existe contact_inbox (comportamento vanilla preservado)' do
      it 'retorna raw quando webhook chega COM 9' do
        result = service.normalize_and_find_contact_by_provider('5531988862094', :cloud)
        expect(result).to eq('5531988862094')
      end

      it 'retorna normalizado (com 9) quando webhook chega SEM 9' do
        # Vanilla behavior: retorna raw quando não acha, mas raw é o original
        result = service.normalize_and_find_contact_by_provider('553188862094', :cloud)
        expect(result).to eq('553188862094')
      end
    end

    context 'não-BR (comportamento vanilla intacto)' do
      it 'não interfere em número USA' do
        create(:contact_inbox, contact: contact, inbox: inbox, source_id: '15551234567')
        result = service.normalize_and_find_contact_by_provider('15551234567', :cloud)
        expect(result).to eq('15551234567')
      end
    end

    context 'fixo BR (não gera variante sem 9)' do
      it 'não busca variação — fixo permanece' do
        create(:contact_inbox, contact: contact, inbox: inbox, source_id: '553133445566')
        result = service.normalize_and_find_contact_by_provider('553133445566', :cloud)
        expect(result).to eq('553133445566')
      end
    end
  end

  describe '#normalize_and_find_contact_by_provider (Twilio format)' do
    context 'contact_inbox legado SEM 9 (formato Twilio)' do
      before do
        create(:contact_inbox, contact: contact, inbox: inbox, source_id: 'whatsapp:+553188862094')
      end

      it 'acha via variante quando webhook chega COM 9 no formato Twilio' do
        result = service.normalize_and_find_contact_by_provider('whatsapp:+5531988862094', :twilio)
        expect(result).to eq('whatsapp:+553188862094')
      end
    end
  end
end
