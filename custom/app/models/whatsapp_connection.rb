# frozen_string_literal: true

# == Schema Information
#
# Table name: whatsapp_connections
#
#  id                             :bigint           not null, primary key
#  account_id                     :bigint           not null
#  provider                       :string           not null (meta_cloud, evolution)
#  name                           :string           not null
#  credentials                    :jsonb            default({})
#  message_templates              :jsonb            default([])
#  message_templates_last_updated :datetime
#  status                         :string           default("active"), not null
#  created_at                     :datetime         not null
#  updated_at                     :datetime         not null
#

class WhatsappConnection < ApplicationRecord
  PROVIDERS = %w[meta_cloud evolution].freeze
  STATUSES = %w[active disconnected error].freeze

  belongs_to :account
  has_many :whatsapp_phone_numbers, dependent: :destroy

  before_destroy :cleanup_evolution_instances

  validates :provider, presence: true, inclusion: { in: PROVIDERS }
  validates :name, presence: true
  validates :status, presence: true, inclusion: { in: STATUSES }

  scope :meta_cloud, -> { where(provider: 'meta_cloud') }
  scope :evolution, -> { where(provider: 'evolution') }
  scope :active, -> { where(status: 'active') }

  # --- Credential accessors (Meta Cloud) ---

  def access_token
    credentials['access_token']
  end

  def waba_id
    credentials['waba_id']
  end

  def business_id
    credentials['business_id']
  end

  # --- Meta Cloud helpers ---

  def meta_cloud?
    provider == 'meta_cloud'
  end

  def evolution?
    provider == 'evolution'
  end

  def mark_templates_updated
    update_column(:message_templates_last_updated, Time.zone.now) # rubocop:disable Rails/SkipsModelValidations
  end

  def linked_phone_numbers
    whatsapp_phone_numbers.where(status: 'linked')
  end

  def available_phone_numbers
    whatsapp_phone_numbers.where(status: 'available')
  end

  private

  def cleanup_evolution_instances
    return unless evolution?

    api_client = WhatsappConnections::Evolution::ApiClient.new
    whatsapp_phone_numbers.where.not(phone_number_id: nil).find_each do |phone|
      api_client.delete_instance(phone.phone_number_id)
    rescue StandardError => e
      Rails.logger.warn("[WHATSAPP_POOL] Failed to cleanup Evolution instance #{phone.phone_number_id}: #{e.message}")
    end
  rescue WhatsappConnections::Evolution::ApiClient::EvolutionApiError => e
    Rails.logger.warn("[WHATSAPP_POOL] Evolution API not available for cleanup: #{e.message}")
  end
end
