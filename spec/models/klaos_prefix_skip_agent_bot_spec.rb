# frozen_string_literal: true

require 'rails_helper'

# OPT-OUT DE PREFIXO POR AGENT_BOT
#
# Contexto: custom/config/initializers/human_message_prefix.rb assina TODA
# mensagem outgoing de User e de AgentBot com o template da conta
# ("**Atendente SOFIA:**\n..."). A Sofia (agendamento) ja se identifica sozinha
# dentro do proprio texto, entao a assinatura do canal ficava em duplicidade.
#
# A saida foi uma lista por conta — custom_attributes['klaos_prefix_skip_agent_bot_ids'] —
# em vez de desligar o prefixo da conta inteira. Lara e ANA fazem COBRANCA e a
# assinatura delas e o que diz ao paciente quem esta falando: derrubar o prefixo
# das duas junto com o da Sofia seria regressao em cima de dinheiro.
#
# Por isso este arquivo trava os dois lados: o bot da lista NAO recebe, e todo o
# resto (o outro bot da mesma conta, o atendente humano, o opt-out por mensagem
# que ja existia) continua exatamente como estava.
RSpec.describe 'KLaOS — opt-out de prefixo por agent_bot' do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:contact) { create(:contact, account: account) }
  let(:contact_inbox) { create(:contact_inbox, contact: contact, inbox: inbox) }
  let(:conversation) do
    create(:conversation, account: account, inbox: inbox, contact: contact, contact_inbox: contact_inbox)
  end

  # Mesmo template que roda hoje na Mais Saude (dev acc 10) e na Blue Care (dev acc 12).
  let(:template) { "**Atendente {FIRST_NAME_UPPER}:**\n" }

  let(:sofia) { create(:agent_bot, name: 'Sofia', account: account) }
  let(:lara) { create(:agent_bot, name: 'lara', account: account) }
  let(:atendente) { create(:user, account: account, role: :agent, name: 'Yasmin Silva') }

  def configurar(attrs)
    account.update!(custom_attributes: attrs)
    conversation.reload
  end

  def enviar(sender, texto: 'Bom dia, tudo certo?', content_attributes: nil)
    create(:message, account: account, inbox: inbox, conversation: conversation,
                     message_type: :outgoing, private: false, sender: sender,
                     content: texto, content_attributes: content_attributes || {})
  end

  describe 'bot listado em klaos_prefix_skip_agent_bot_ids' do
    it 'nao recebe prefixo' do
      configurar('klaos_human_message_template' => template,
                 'klaos_prefix_skip_agent_bot_ids' => [sofia.id])

      expect(enviar(sofia).content).to eq('Bom dia, tudo certo?')
    end

    it 'aceita a lista com id em string (jsonb gravado a mao)' do
      configurar('klaos_human_message_template' => template,
                 'klaos_prefix_skip_agent_bot_ids' => [sofia.id.to_s])

      expect(enviar(sofia).content).to eq('Bom dia, tudo certo?')
    end

    it 'aceita a lista como string separada por virgula' do
      configurar('klaos_human_message_template' => template,
                 'klaos_prefix_skip_agent_bot_ids' => "#{sofia.id}, 999999")

      expect(enviar(sofia).content).to eq('Bom dia, tudo certo?')
    end
  end

  # ---------------------------------------------------------------------------
  # VIZINHOS — o que ja funcionava e nao pode mudar
  # ---------------------------------------------------------------------------
  describe 'vizinho: o outro bot da mesma conta continua assinado' do
    it 'bot fora da lista RECEBE o prefixo, mesmo com a lista configurada' do
      configurar('klaos_human_message_template' => template,
                 'klaos_prefix_skip_agent_bot_ids' => [sofia.id])

      expect(enviar(lara).content).to eq("**Atendente LARA:**\nBom dia, tudo certo?")
    end

    it 'a lista vazia nao desliga ninguem' do
      configurar('klaos_human_message_template' => template,
                 'klaos_prefix_skip_agent_bot_ids' => [])

      expect(enviar(sofia).content).to eq("**Atendente SOFIA:**\nBom dia, tudo certo?")
    end
  end

  describe 'vizinho: atendente humano' do
    it 'continua recebendo o prefixo com a lista configurada' do
      configurar('klaos_human_message_template' => template,
                 'klaos_prefix_skip_agent_bot_ids' => [sofia.id])

      expect(enviar(atendente).content).to eq("**Atendente YASMIN:**\nBom dia, tudo certo?")
    end

    it 'nao e desligado por coincidencia de id com um bot da lista' do
      # A lista e de agent_bots.id. users.id e outra sequencia — um user com o
      # mesmo numero NAO pode perder a assinatura.
      configurar('klaos_human_message_template' => template,
                 'klaos_prefix_skip_agent_bot_ids' => [atendente.id])

      expect(enviar(atendente).content).to eq("**Atendente YASMIN:**\nBom dia, tudo certo?")
    end
  end

  describe 'vizinho: config ausente ou invalida nao muda nada' do
    it 'sem a chave, o bot segue assinado (comportamento de hoje)' do
      configurar('klaos_human_message_template' => template)

      expect(enviar(sofia).content).to eq("**Atendente SOFIA:**\nBom dia, tudo certo?")
    end

    it 'chave nula nao quebra o envio' do
      configurar('klaos_human_message_template' => template,
                 'klaos_prefix_skip_agent_bot_ids' => nil)

      expect(enviar(sofia).content).to eq("**Atendente SOFIA:**\nBom dia, tudo certo?")
    end

    it 'chave com lixo (hash) nao quebra o envio nem desliga o prefixo' do
      configurar('klaos_human_message_template' => template,
                 'klaos_prefix_skip_agent_bot_ids' => { 'sofia' => true })

      expect(enviar(sofia).content).to eq("**Atendente SOFIA:**\nBom dia, tudo certo?")
    end

    it 'conta sem template nenhum segue sem prefixo' do
      configurar('klaos_prefix_skip_agent_bot_ids' => [sofia.id])

      expect(enviar(lara).content).to eq('Bom dia, tudo certo?')
    end
  end

  describe 'vizinho: opt-out por mensagem (content_attributes.skip_klaos_prefix)' do
    it 'continua valendo pro humano' do
      configurar('klaos_human_message_template' => template,
                 'klaos_prefix_skip_agent_bot_ids' => [sofia.id])

      msg = enviar(atendente, content_attributes: { 'skip_klaos_prefix' => true })
      expect(msg.content).to eq('Bom dia, tudo certo?')
    end
  end

  # ---------------------------------------------------------------------------
  # UNIDADE — o predicado, sem tocar no banco
  # ---------------------------------------------------------------------------
  describe KlaosHumanMessagePrefix do
    describe '.skip_bot_ids' do
      it 'normaliza array misto de int e string' do
        expect(described_class.skip_bot_ids([15, '98'])).to eq(%w[15 98])
      end

      it 'normaliza string com virgula e espacos' do
        expect(described_class.skip_bot_ids(' 15 , 98 ')).to eq(%w[15 98])
      end

      it 'normaliza id solto' do
        expect(described_class.skip_bot_ids(15)).to eq(['15'])
      end

      it 'devolve lista vazia pra nil, hash e string vazia' do
        expect(described_class.skip_bot_ids(nil)).to eq([])
        expect(described_class.skip_bot_ids({ 'a' => 1 })).to eq([])
        expect(described_class.skip_bot_ids('')).to eq([])
      end
    end

    describe '.skip_bot?' do
      it 'e true so pro AgentBot que esta na lista' do
        expect(described_class.skip_bot?([15], 'AgentBot', 15)).to be(true)
        expect(described_class.skip_bot?(['15'], 'AgentBot', 15)).to be(true)
      end

      it 'e false pro AgentBot fora da lista' do
        expect(described_class.skip_bot?([15], 'AgentBot', 98)).to be(false)
      end

      it 'e false pro humano, mesmo com o id na lista' do
        expect(described_class.skip_bot?([15], 'User', 15)).to be(false)
      end

      it 'e false sem config' do
        expect(described_class.skip_bot?(nil, 'AgentBot', 15)).to be(false)
      end
    end
  end
end
