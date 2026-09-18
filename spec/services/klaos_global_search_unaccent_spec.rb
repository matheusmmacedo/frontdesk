# frozen_string_literal: true

require 'rails_helper'

# (18/09/2026) A BUSCA GLOBAL TEM QUE ACHAR COM ACENTO OU SEM ACENTO.
#
# Vídeo do cliente de hoje, 10:51: ele buscou "Édson AndrE da Silva" e a tela
# devolveu vazio; tirou o acento do É e apareceu "Contatos (2) — EDSON ANDRE DA
# SILVA". Palavras dele: "tem que achar com acento ou sem acento". Ele lembrou
# que é pedido repetido, e é: o fix de 29/05 (klaos_contact_search_unaccent)
# tratou a TELA DE CONTATOS, e o vídeo mostra a URL /search?q=..., que é a busca
# global da lupa — outro caminho, no SearchService.
#
# Os dois sentidos importam, porque a base tem os dois casos: paciente cadastrado
# SEM acento (EDSON ANDRE) e paciente cadastrado COM acento (CÁSSIA).
RSpec.describe 'KLaOS — busca global sem acentuação', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let!(:inbox) { create(:inbox, account: account) }

  # O caso do vídeo: cadastro SEM acento.
  let!(:edson) { create(:contact, account: account, name: 'EDSON ANDRE DA SILVA') }
  # O caso do fix de maio: cadastro COM acento.
  let!(:cassia) { create(:contact, account: account, name: 'MARIA CÁSSIA DE SOUZA') }

  before { create(:inbox_member, user: admin, inbox: inbox) }

  def buscar(termo)
    get "/api/v1/accounts/#{account.id}/search",
        params: { q: termo },
        headers: admin.create_new_auth_token,
        as: :json
    JSON.parse(response.body)['payload']['contacts'].map { |c| c['name'] }
  end

  it 'o caso do vídeo: busca COM acento acha cadastro SEM acento' do
    expect(buscar('Édson')).to include('EDSON ANDRE DA SILVA')
  end

  it 'o nome inteiro como ele digitou também acha' do
    expect(buscar('Édson AndrE da Silva')).to include('EDSON ANDRE DA SILVA')
  end

  it 'VIZINHO: busca SEM acento acha cadastro COM acento (o fix de maio)' do
    expect(buscar('cassia')).to include('MARIA CÁSSIA DE SOUZA')
  end

  it 'busca COM acento acha cadastro COM acento' do
    expect(buscar('Cássia')).to include('MARIA CÁSSIA DE SOUZA')
  end

  it 'VIZINHO: continua não achando quem não tem nada a ver' do
    expect(buscar('Joaquim Nabuco')).to be_empty
  end

  it 'VIZINHO: busca sem acento segue achando o cadastro sem acento' do
    expect(buscar('edson')).to include('EDSON ANDRE DA SILVA')
  end
end
