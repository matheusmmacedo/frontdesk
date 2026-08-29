# frozen_string_literal: true

require 'rails_helper'

# (18/08/2026) ELLEN, conv 2455 da conta 9.
#
# A cobranca criou o contact_inbox com o numero do espelho da Tenex,
# "5531925348364" — um numero que nao existe no WhatsApp. Seis mensagens
# voltaram 131026 (template d0, cobrar-agora, duas saudacoes e os DOIS blocos
# com o material do aplicativo que o atendente mandou). No meio disso a cliente
# escreveu "Oiii" do wa_id real, "553125348364", e a resposta dentro da janela
# de 24h foi de novo pro endereco morto.
#
# Sem o fix, o primeiro exemplo falha: o source_id continua o antigo e a
# proxima resposta do atendente morre igual.
RSpec.describe 'KLaOS — o wa_id do webhook manda no source_id' do
  let(:account) { create(:account) }
  let(:inbox) do
    create(:channel_whatsapp, account: account, provider: 'whatsapp_cloud',
                              sync_templates: false, validate_provider_config: false).inbox
  end
  let(:contact) { create(:contact, account: account) }
  let!(:contact_inbox) { create(:contact_inbox, contact: contact, inbox: inbox, source_id: '5531925348364') }

  let(:waid_real) { '553125348364' }

  def enviar(status:, erro: nil)
    conversa = create(:conversation, account: account, inbox: inbox, contact: contact, contact_inbox: contact_inbox)
    create(:message, account: account, inbox: inbox, conversation: conversa,
                     message_type: :outgoing, private: false, status: status,
                     content_attributes: erro ? { external_error: erro } : {})
  end

  def waid_resolvido(entrada)
    Whatsapp::PhoneNumberNormalizationService.new(inbox).normalize_and_find_contact_by_provider(entrada, :cloud)
  end

  it 'reaponta o contact_inbox quando o ultimo envio morreu com 131026' do
    enviar(status: :failed, erro: 'code=131026 | Message undeliverable | details=Message Undeliverable.')

    expect(waid_resolvido(waid_real)).to eq(waid_real)
    expect(contact_inbox.reload.source_id).to eq(waid_real)
  end

  it 'nao encosta em contato que esta entregando (blindagem do vizinho)' do
    enviar(status: :delivered)

    expect(waid_resolvido(waid_real)).to eq('5531925348364')
    expect(contact_inbox.reload.source_id).to eq('5531925348364')
  end

  it 'nao encosta quando a falha foi por outro motivo' do
    enviar(status: :failed, erro: 'code=470 | Re-engagement message')

    expect(contact_inbox.reload.source_id).to eq('5531925348364')
    expect(waid_resolvido(waid_real)).to eq('5531925348364')
  end

  it 'nao reaponta para um numero que nao e o mesmo variando o nono digito' do
    enviar(status: :failed, erro: 'code=131026 | Message undeliverable')

    # DDD diferente: seria a conversa de outra pessoa.
    expect(contact_inbox.reload.source_id).to eq('5531925348364')
    expect(waid_resolvido('553225348364')).to eq('553225348364')
  end

  it 'nao reaponta se outro contact_inbox da caixa ja ocupa o wa_id real' do
    enviar(status: :failed, erro: 'code=131026 | Message undeliverable')
    outro = create(:contact, account: account)
    create(:contact_inbox, contact: outro, inbox: inbox, source_id: waid_real)

    expect(waid_resolvido(waid_real)).to eq('5531925348364')
    expect(contact_inbox.reload.source_id).to eq('5531925348364')
  end

  # O que decide e o ULTIMO envio, nao "algum envio ja falhou". Sem `reorder`,
  # o `default_scope { order(created_at: :asc) }` do Message faria o `.first`
  # devolver a mensagem MAIS ANTIGA — e um 131026 velho autorizaria repontar
  # para sempre, mesmo com o numero entregando hoje.
  it 'o que vale e o ultimo envio: 131026 antigo + entrega recente nao reaponta' do
    enviar(status: :failed, erro: 'code=131026 | Message undeliverable')
    travel_to(2.hours.from_now) { enviar(status: :delivered) }

    expect(waid_resolvido(waid_real)).to eq('5531925348364')
    expect(contact_inbox.reload.source_id).to eq('5531925348364')
  end

  it 'mensagem de contato sem historico de envio nao muda nada' do
    expect(waid_resolvido(waid_real)).to eq('5531925348364')
    expect(contact_inbox.reload.source_id).to eq('5531925348364')
  end

  # BLINDAGEM DO VIZINHO — o fallback que este initializer ja tinha (mensagem
  # COM o nono digito chegando num contato gravado SEM ele) tem que seguir
  # achando o contato em vez de criar duplicata. E a regra do 131026 vale nos
  # dois sentidos: quem diz qual e o endereco certo e o WhatsApp.
  context 'quando o contato gravado e o SEM o nono digito' do
    let!(:contact_inbox) { create(:contact_inbox, contact: contact, inbox: inbox, source_id: '553125348364') }

    it 'acha o contato pela variacao, sem repontar nada' do
      enviar(status: :delivered)

      expect(waid_resolvido('5531925348364')).to eq('553125348364')
      expect(contact_inbox.reload.source_id).to eq('553125348364')
    end

    it 'reaponta quando o ultimo envio morreu com 131026' do
      enviar(status: :failed, erro: 'code=131026 | Message undeliverable')

      expect(waid_resolvido('5531925348364')).to eq('5531925348364')
      expect(contact_inbox.reload.source_id).to eq('5531925348364')
    end
  end
end
