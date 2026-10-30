# frozen_string_literal: true

require 'rails_helper'

# (30/10/2026) Pedido do Gustavo, Blue Care, conversa da ELAINE: a resposta
# pronta de cancelamento passa de 4096 caracteres (limite da Meta para texto) e
# o composer travava em "536 characters over". O Qualizap mandava inteira.
#
# Agora o MessageBuilder divide em N mensagens numa transacao e o SendReplyJob
# so solta a parte k+1 depois que a Meta aceitou a parte k.
#
# Sem o fix: o primeiro exemplo do builder cria UMA mensagem de 6000 caracteres
# (que a Meta recusa) e os exemplos do job nao encontram parte nenhuma.
RSpec.describe 'KLaOS — texto longo no WhatsApp Cloud vira varias mensagens, na ordem' do
  let(:account) { create(:account) }
  let(:user) { create(:user, account: account, name: 'Gustavo Henrique') }
  let(:wa_inbox) do
    create(:channel_whatsapp, account: account, provider: 'whatsapp_cloud',
                              sync_templates: false, validate_provider_config: false).inbox
  end
  let(:contact) { create(:contact, account: account) }
  let(:contact_inbox) { create(:contact_inbox, contact: contact, inbox: wa_inbox, source_id: '5521964798660') }
  let(:conversa) { create(:conversation, account: account, inbox: wa_inbox, contact: contact, contact_inbox: contact_inbox) }

  let(:prefixo) { "**Atendente GUSTAVO:**\n" }

  # Formato das respostas de cancelamento: paragrafos curtos, emoji no comeco.
  let(:texto_longo) do
    (1..45).map do |n|
      "👉 #{n} - VOCÊ CONCORDA COM A FRASE: o plano tem carência de 30 dias e a multa de " \
        'cancelamento é calculada sobre as parcelas restantes do contrato.'
    end.join("\n\n")
  end

  before do
    account.update!(custom_attributes: { 'klaos_human_message_template' => "**Atendente {FIRST_NAME_UPPER}:**\n" })
  end

  def enviar(conversation, content:, **extra)
    params = ActionController::Parameters.new({ content: content, private: false, echo_id: 'eco-1' }.merge(extra))
    Messages::MessageBuilder.new(user, conversation, params).perform
  end

  def partes_de(conversation)
    conversation.messages.where(message_type: :outgoing).order(:id).to_a
  end

  def marca(mensagem)
    mensagem.reload.content_attributes[Klaos::WhatsappTextoLongo::CHAVE]
  end

  describe 'regra de divisao' do
    it 'mensagem curta volta intacta' do
      expect(Klaos::WhatsappTextoLongo.dividir('Olá, tudo bem?')).to eq(['Olá, tudo bem?'])
    end

    it 'conta como o composer (UTF-16): ate 3996 + 100 de prefixo nao divide' do
      expect(Klaos::WhatsappTextoLongo.tamanho('👋 OLÁ')).to eq(6)
      expect(Klaos::WhatsappTextoLongo.dividir('a' * 3996).size).to eq(1)
      expect(Klaos::WhatsappTextoLongo.dividir('a' * 3997).size).to eq(2)
    end

    it 'quebra em paragrafo, sem perder texto, nenhuma parte acima de 3900' do
      partes = Klaos::WhatsappTextoLongo.dividir(texto_longo)

      expect(partes.size).to eq(2)
      expect(partes.join("\n\n")).to eq(texto_longo)
      expect(Klaos::WhatsappTextoLongo.tamanho(partes.first)).to be <= 3800
      expect(partes.map { |p| Klaos::WhatsappTextoLongo.tamanho(p) }).to all(be <= 3900)
    end
  end

  describe 'MessageBuilder' do
    it 'cria as partes em ordem, prefixo e citacao so na primeira, e devolve a primeira' do
      citada = create(:message, account: account, inbox: wa_inbox, conversation: conversa, message_type: :incoming,
                                source_id: 'wamid.citada')

      primeira = enviar(conversa, content: texto_longo, content_attributes: { in_reply_to: citada.id })
      partes = partes_de(conversa)
      esperado = Klaos::WhatsappTextoLongo.dividir(texto_longo)

      expect(partes.size).to eq(2)
      expect(primeira).to eq(partes.first)
      expect(primeira.echo_id).to eq('eco-1')
      expect(partes.first.content).to eq("#{prefixo}#{esperado.first}")
      expect(partes.second.content).to eq(esperado.second)
      expect(partes.first.content_attributes['in_reply_to']).to eq(citada.id)
      expect(partes.second.content_attributes['in_reply_to']).to be_nil
      expect(partes.map { |p| marca(p)['parte'] }).to eq([1, 2])
      expect(partes.map { |p| marca(p)['grupo'] }.uniq.size).to eq(1)
      expect(Klaos::WhatsappTextoLongo.tamanho(partes.first.content)).to be <= 3900
      expect(partes.second.created_at).to be > partes.first.created_at
    end

    it 'so a primeira parte entra na fila de envio' do
      enviar(conversa, content: texto_longo)
      primeira, segunda = partes_de(conversa)

      expect(SendReplyJob).to have_been_enqueued.with(primeira.id)
      expect(SendReplyJob).not_to have_been_enqueued.with(segunda.id)
    end

    it 'vizinho: mensagem curta segue uma mensagem so, sem marca' do
      mensagem = enviar(conversa, content: 'Olá, tudo bem?')

      expect(partes_de(conversa).size).to eq(1)
      expect(mensagem.content).to eq("#{prefixo}Olá, tudo bem?")
      expect(mensagem.content_attributes[Klaos::WhatsappTextoLongo::CHAVE]).to be_nil
      expect(SendReplyJob).to have_been_enqueued.with(mensagem.id)
    end

    it 'vizinho: nota privada longa nao e dividida' do
      params = ActionController::Parameters.new(content: texto_longo, private: true)
      Messages::MessageBuilder.new(user, conversa, params).perform

      expect(partes_de(conversa).size).to eq(1)
      expect(partes_de(conversa).first.content).to eq(texto_longo)
    end

    it 'vizinho: outro canal (API) nao e dividido' do
      api_inbox = create(:inbox, account: account, channel: create(:channel_api, account: account))
      conversa_api = create(:conversation, account: account, inbox: api_inbox)

      enviar(conversa_api, content: texto_longo)

      expect(partes_de(conversa_api).size).to eq(1)
    end
  end

  describe 'SendReplyJob em cadeia' do
    def meta_aceita!
      allow(Whatsapp::SendOnWhatsappService).to receive(:new) do |message:|
        instance_double(Whatsapp::SendOnWhatsappService).tap do |svc|
          allow(svc).to receive(:perform) { message.update!(source_id: "wamid.#{message.id}") }
        end
      end
    end

    def meta_recusa!
      allow(Whatsapp::SendOnWhatsappService).to receive(:new) do |message:|
        instance_double(Whatsapp::SendOnWhatsappService).tap do |svc|
          allow(svc).to receive(:perform) { message.update!(status: :failed, external_error: 'code=131047 | Re-engagement') }
        end
      end
    end

    it 'parte 2 que ainda nao foi liberada nao sai, mesmo se alguem enfileirar' do
      meta_aceita!
      enviar(conversa, content: texto_longo)
      _primeira, segunda = partes_de(conversa)

      SendReplyJob.perform_now(segunda.id)

      expect(segunda.reload.source_id).to be_nil
    end

    it 'depois que a Meta aceita a parte 1, libera e enfileira a parte 2' do
      meta_aceita!
      enviar(conversa, content: texto_longo)
      primeira, segunda = partes_de(conversa)

      SendReplyJob.perform_now(primeira.id)

      expect(primeira.reload.source_id).to eq("wamid.#{primeira.id}")
      expect(marca(segunda)['liberada']).to be(true)
      expect(SendReplyJob).to have_been_enqueued.with(segunda.id)

      SendReplyJob.perform_now(segunda.id)
      expect(segunda.reload.source_id).to eq("wamid.#{segunda.id}")
    end

    it 'se a parte 1 falha, as seguintes ficam como falha em vez de sair fora de ordem' do
      meta_recusa!
      enviar(conversa, content: texto_longo)
      primeira, segunda = partes_de(conversa)

      SendReplyJob.perform_now(primeira.id)

      expect(segunda.reload.status).to eq('failed')
      expect(segunda.external_error).to include('parte 1 de 2')
      expect(SendReplyJob).not_to have_been_enqueued.with(segunda.id)
    end

    it 'vizinho: mensagem comum passa pelo job como antes' do
      meta_aceita!
      mensagem = enviar(conversa, content: 'Olá, tudo bem?')

      SendReplyJob.perform_now(mensagem.id)

      expect(mensagem.reload.source_id).to eq("wamid.#{mensagem.id}")
    end
  end
end
