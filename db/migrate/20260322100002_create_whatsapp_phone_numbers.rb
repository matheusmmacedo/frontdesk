# frozen_string_literal: true

class CreateWhatsappPhoneNumbers < ActiveRecord::Migration[7.0]
  def change
    create_table :whatsapp_phone_numbers do |t|
      t.references :whatsapp_connection, null: false, foreign_key: true, index: true
      t.references :account, null: false, foreign_key: true, index: true
      t.string :phone_number, null: false
      t.string :phone_number_id # Meta phone_number_id or Evolution instance_name
      t.string :display_name
      t.string :status, default: 'available', null: false # available, linked, error, pending
      t.jsonb :provider_info, default: {}
      t.references :inbox, null: true, foreign_key: true
      t.bigint :channel_whatsapp_id, null: true

      t.timestamps
    end

    add_index :whatsapp_phone_numbers, :channel_whatsapp_id
    add_index :whatsapp_phone_numbers, [:whatsapp_connection_id, :phone_number], unique: true, name: 'idx_wa_phone_numbers_on_connection_and_phone'
    add_foreign_key :whatsapp_phone_numbers, :channel_whatsapp, column: :channel_whatsapp_id
  end
end
