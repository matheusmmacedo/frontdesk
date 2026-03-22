# frozen_string_literal: true

# == Schema Information
#
# Table name: whatsapp_phone_numbers
#
#  id                       :bigint           not null, primary key
#  whatsapp_connection_id   :bigint           not null
#  account_id               :bigint           not null
#  phone_number             :string           not null
#  phone_number_id          :string
#  display_name             :string
#  status                   :string           default("available"), not null
#  provider_info            :jsonb            default({})
#  inbox_id                 :bigint
#  channel_whatsapp_id      :bigint
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#

class WhatsappPhoneNumber < ApplicationRecord
  STATUSES = %w[available linked error pending].freeze

  belongs_to :whatsapp_connection
  belongs_to :account
  belongs_to :inbox, optional: true
  belongs_to :channel_whatsapp, class_name: 'Channel::Whatsapp', optional: true

  validates :phone_number, presence: true
  validates :phone_number, uniqueness: { scope: :whatsapp_connection_id }
  validates :status, presence: true, inclusion: { in: STATUSES }

  scope :available, -> { where(status: 'available') }
  scope :linked, -> { where(status: 'linked') }

  def linked?
    status == 'linked' && inbox_id.present? && channel_whatsapp_id.present?
  end

  def available?
    status == 'available'
  end

  def mark_linked!(inbox:, channel:)
    update!(
      status: 'linked',
      inbox_id: inbox.id,
      channel_whatsapp_id: channel.id
    )
  end

  def mark_available!
    update!(
      status: 'available',
      inbox_id: nil,
      channel_whatsapp_id: nil
    )
  end
end
